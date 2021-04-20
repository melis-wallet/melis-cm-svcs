
import Mixin from '@ember/object/mixin'
import { get, set, getProperties } from '@ember/object'
import Logger from 'melis-cm-svcs/utils/logger'
import CMCore from 'melis-api-js'
import { copy } from 'ember-copy'

C = CMCore.C

SessionEvents = Mixin.create

  setUpEvents: (->

    api = @get('api')
    self = @

    api.on C.EVENT_DISCONNECT, =>
      Logger.warn '[CM Session] Disconnected from network'
      # in connection tests sometimes the service can be destroyed when these come back FIXME
      # maybe melis-js-api should have a way to disable retyring?
      unless @isDestroyed
        @set('connected', false)
        @set('ready', false)
        @trigger('net-disconnect', this)


    api.on C.EVENT_CONNECT, =>
      Logger.info '[CM Session] Connected to network'
      @set('connectFailed', null)
      @set('connected', true)
      @trigger('net-connect', this)


    api.on C.EVENT_SESSION_RESTORED, (data) =>
      Logger.info '[CM Session] Session restored after disconnection'
      #@refreshAccounts() if @get('connectSucceeded')
      @restoreAccounts(data) if @get('connectSucceeded')
      if @get('currentWallet') && @get('currentAccount')
        @set('ready', true)
      @trigger('net-restored', this)


    # this is fired after reconnect has finished
    api.on C.EVENT_WALLET_OPENED, =>
      Logger.info '[CM Session] (Re)connected'
      if @get('currentWallet') && @get('currentAccount')
        @set('ready', true)


    api.on C.EVENT_CONFIG, (config) =>
      Logger.info '[CM Session] Config Updated', config
      @set('config', config)


    api.on C.EVENT_ACCOUNT_UPDATED, (data) =>
      Logger.info '[CM Session] Account Updated', data

      acct = @get('accounts').findBy('pubId', data.account.pubId)
      if acct
        if get(data, 'account.hidden') && !@get('currentWallet.info.isPrimaryDevice')
          # account has been hidden and we're not the primary device, consider it gone
          @get('accounts').removeObject(acct)
        else
          acct.setProperties
            cmo: data.account
            balance: data.balance
      else if (master = @findMasterFor(data.account.pubId))
        # FIXME FIXME
        # this is a Q&D fix for the server sometimes sending the wrong balance update for the master of a multisig
        # account to a co-signer. We find its master
        Logger.warn "[CM Session] Got an update for master account '#{data.account.pubId}' instead of '#{master.get('pubId')}'"
        master.set('balance', data.balance)
      else
        # can happen on account unhide
        Logger.info '[CM Session] New Account in update event', data
        @accountPush(data)

    api.on C.EVENT_ACCOUNT_DELETED, (data) =>
      Logger.info '[CM Session] Account Deleted', data

      if (acct = get(data, 'accountPubId'))
        @accountRemove(acct)


    api.on C.EVENT_NEW_ACCOUNT, (data) =>
      if !@get('accounts').findBy('pubId', data.account.pubId)
        Logger.info '[CM Session] New Account', data
        if (acc  = @accountPush(data))
          @refreshAccount(acc)
      else
        Logger.warn '[CM Session] New Account event for non-new account', data


    api.on C.EVENT_BLOCK, (data) =>
      Logger.info('[CM Session] New block: ', data)
      @trigger('new-block', data)


    api.on C.EVENT_DEVICE_DELETED, (data) =>
      Logger.info('[CM Session] Device deleted: ', data)
      if (get(data, 'id') == @get('credentials.deviceId'))
        Logger.warn('[CM Session] THIS device was deleted ')
        @trigger('device-gone', data)


    api.on C.EVENT_NEW_PRIMARY_DEVICE, (data) =>
      Logger.info('[CM Session] New primary device: ', data)
      # just refresh the info
      api.walletGetInfo().then((res) ->
        Logger.debug("wallet get info: ", res)
        self.set('currentWallet.info', copy(res))
      ).catch((e) -> Logger.error("Error: ", e))


    api.on C.EVENT_CLOSE_SESSION, (event) =>
      Logger.info('[CM Session] Close Session: ', event)
      deviceId = @get('credentials.deviceId')
      if event.deviceId == deviceId
        Logger.warn "Sessions on this device should close."
        @walletClose().then( (res)->
          window.location.reload()
        )

  ).on('client-init')



export default SessionEvents
