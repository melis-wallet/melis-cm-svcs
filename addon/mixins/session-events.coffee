`import Ember from 'ember'`
`import CMCore from 'npm:melis-api-js'`

C = CMCore.C

SessionEvents = Ember.Mixin.create

  setUpEvents: (->

    api = @get('api')
    self = @

    api.on C.EVENT_DISCONNECT, =>
      Ember.Logger.warn '[CM Session] Disconnected from network'
      # in connection tests sometimes the service can be destroyed when these come back FIXME
      # maybe melis-js-api should have a way to disable retyring?
      unless @isDestroyed
        @set('connected', false)
        @set('ready', false)
        @trigger('net-disconnect', this)


    api.on C.EVENT_CONNECT, =>
      Ember.Logger.info '[CM Session] Connected to network'
      @set('connectFailed', null)
      @set('connected', true)
      @trigger('net-connect', this)


    api.on C.EVENT_SESSION_RESTORED, =>
      Ember.Logger.info '[CM Session] Session restored after disconnection'
      @refreshAccounts() if @get('connectSucceeded')
      if @get('currentWallet') && @get('currentAccount')
        @set('ready', true)
      @trigger('net-restored', this)


    # this is fired after reconnect has finished
    api.on C.EVENT_WALLET_OPENED, =>
      Ember.Logger.info '[CM Session] (Re)connected'
      if @get('currentWallet') && @get('currentAccount')
        @set('ready', true)


    api.on C.EVENT_CONFIG, (config) =>
      Ember.Logger.info '[CM Session] Config Updated', config
      @set('config', config)


    api.on C.EVENT_ACCOUNT_UPDATED, (data) =>
      Ember.Logger.info '[CM Session] Account Updated', data

      acct = @get('accounts').findBy('pubId', data.account.pubId)
      if acct
        if Ember.get(data, 'account.hidden') && !@get('currentWallet.info.isPrimaryDevice')
          # account has been hidden and we're not the primary device, consider it gone
          @get('accounts').removeObject(acct)
        else
          acct.set('cmo', data.account)
          acct.set('balance', data.balance)
      else if (master = @findMasterFor(data.account.pubId))
        # FIXME FIXME
        # this is a Q&D fix for the server sometimes sending the wrong balance update for the master of a multisig
        # account to a co-signer. We find its master
        Ember.Logger.warn "[CM Session] Got an update for master account '#{data.account.pubId}' instead of '#{master.get('pubId')}'"
        master.set('balance', data.balance)
      else
        # can happen on account unhide
        Ember.Logger.info '[CM Session] New Account in update event', data
        @accountPush(data)

    api.on C.EVENT_ACCOUNT_DELETED, (data) =>
      Ember.Logger.info '[CM Session] Account Deleted', data

      if (acct = Ember.get(data, 'accountPubId'))
        @accountRemove(acct)


    api.on C.EVENT_NEW_ACCOUNT, (data) =>
      if !@get('accounts').findBy('pubId', data.account.pubId)
        Ember.Logger.info '[CM Session] New Account', data
        @accountPush(data)
      else
        # TBD when we have the event for unhide


    api.on C.EVENT_BLOCK, (data) =>
      Ember.Logger.info('[CM Session] New block: ', data)
      @trigger('new-block', data)


    api.on C.EVENT_DEVICE_DELETED, (data) =>
      Ember.Logger.info('[CM Session] Device deleted: ', data)
      if (Ember.get(data, 'id') == @get('credentials.deviceId'))
        Ember.Logger.warn('[CM Session] THIS device was deleted ')
        @trigger('device-gone', data)


    api.on C.EVENT_NEW_PRIMARY_DEVICE, (data) =>
      Ember.Logger.info('[CM Session] New primary device: ', data)
      # just refresh the info
      api.walletGetInfo().then((res) ->
        Ember.Logger.debug("wallet get info: ", res)
        self.set('currentWallet.info', Ember.copy(res))
      ).catch((e) -> Ember.Logger.error("Error: ", e))


    api.on C.EVENT_CLOSE_SESSION, (event) =>
      Ember.Logger.info('[CM Session] Close Session: ', event)
      deviceId = @get('credentials.deviceId')
      if event.deviceId == deviceId
        Ember.Logger.warn "Sessions on this device should close."
        @walletClose().then( (res)->
          window.location.reload()
        )

  ).on('client-init')



export default SessionEvents
