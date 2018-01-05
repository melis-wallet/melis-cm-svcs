import Ember from 'ember'
import CMCore from 'npm:melis-api-js'
import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'

C = CMCore.C

DELAY = 4000
LABELS_DELAY = 3000
STORAGE_ACCOUNT_PTR = /^storage\:account-state\:account\:(.+)$/

CmAccountInfo = Ember.Service.extend(Ember.Evented,

  cm: Ember.inject.service('cm-session')

  #
  #
  #
  currentLabels: (->
    @get('cm.currentAccount.labels')
  ).property('cm.currentAccount.labels')

  #
  #
  #
  setupCurrentLabels: (account) ->
    account ||= @get('cm.currentAccount')
    @getLabelsFor(account) if account

  #
  #
  #
  getLabelsFor: (account, force) ->

    api = @get('cm.api')

    if force || Ember.isBlank(account.get('labels'))
      api.getAllLabels(account.get('cmo')).then((res) =>
        account.set('labels', res)
      ).catch((err) ->
        Ember.Logger.error("[Account Info], failed getting labels", err)
        throw err
      )
    else
      Ember.RSVP.resolve(account.get('labels'))

  #
  #
  #
  getAllAccountsInfo: ->
    if (accounts = @get('cm.accounts'))
      Ember.RSVP.all(accounts.map((account) =>
        @accountGetInfo(account)
      )).then( =>
        @trigger('load-all-finished')
      )

  #
  #
  #
  accountGetInfo: (account) ->
    account.set('info', @get('cm.api').peekAccountInfo(account.get('cmo')))

    return

    if force || Ember.isBlank(account.get('info'))
      api = @get('cm.api')
      api.accountGetInfo(account.get('cmo')).then((res) =>
        Ember.Logger.debug("Account info for #{account.pubId}: ", res)
        account.set('info', res)

      ).catch((err) ->
        Ember.Logger.error("[Account Info], failed getting info", err)
        throw err
      )

  #
  # track when currentAccount changes
  #
  accountChanged: (->
    if @get('cm.ready') && (account = @get('cm.currentAccount'))
      waitIdleTime(LABELS_DELAY).then( => @getLabelsFor(account, true) unless @get('isDestroyed'))
      @accountGetInfo(account)
  ).observes('cm.currentAccount')


  #
  #
  #
  refreshCmo: (account) ->
    if account
      api = @get('cm.api')
      api.accountRefresh(account.cmo).then((res) ->
        account.set('cmo', res.account)
        account.set('balance', res.balance)
      ).catch((err) ->
        Ember.Logger.error("[Account Info], failed refresh: ", err)
        throw err
      )

  #
  #
  #
  dispatchJoinEvt: (event) ->
    accounts = @get('cm.accounts')
    accounts.forEach( (acc) =>
      pubId = acc.get('cmo.masterPubId') || acc.get('cmo.pubId')
      if pubId == Ember.get(event, 'masterPubId')
        Ember.Logger.debug 'this account has changed', acc
        @accountGetInfo(acc, true)
        # Is there a better way to refresh the account only when the LAST co-signer has joined?
        @refreshCmo(acc)
    )

  #
  # admittedly a patch
  #
  wipeStaleAccounts: ->
    accounts = @get('cm.accounts')
    return unless accounts

    try
      for i in [0...localStorage.length] by 1
        key =  localStorage.key(i)
        if key && res = key.match(STORAGE_ACCOUNT_PTR)
          accountId = res[1]
          unless accounts.findBy('uniqueId', accountId)
            Ember.Logger.warn('[Account Info] deleting stored data for stale account: ', accountId)
            localStorage.removeItem(key)
    catch err
      Ember.Logger.error '[Account Info] Stale account wiper: ', err
  #
  #
  #
  prepareAccounts: ->
    @wipeStaleAccounts()
    if @get('cm.ready')
      @getAllAccountsInfo()


  #
  #
  #
  setupListeners: ->
    api = @get('cm.api')
    @_joinEvent = (data) => @dispatchJoinEvt(data)

    api.on(C.EVENT_JOINED, @_joinEvent)

  #
  #
  #
  teardownListener: ( ->
    @get('cm.api').removeListener(C.EVENT_JOINED, @_joinEvent) if @_joinEvent
  ).on('willDestroy')



  #
  #
  #
  estimateTxSizeFor: (account, numInputs=1, numOutputs=2) ->
    cm =  @get('cm.api')

    { totalSignatures,
      minSignatures,
      hasServer} = Ember.getProperties(account, 'totalSignatures', 'minSignatures', 'hasServer')

    plus = if hasServer then 1 else 0
    numPubKeys = totalSignatures + plus
    minSigs = minSignatures + plus
    cm.estimateTxSize(numInputs, numOutputs, cm.estimateInputSigSize(numPubKeys, minSigs))


  #
  #
  #
  estimateFeesFor: (account) ->
    if account
      { totalSignatures,
        minSignatures,
        hasServer} = Ember.getProperties(account, 'totalSignatures', 'minSignatures', 'hasServer')
      @estimateFees(totalSignatures, minSignatures, hasServer)


  #
  #
  #
  estimateFees: (numSigners, minSignatures, serverSignature) ->
    cm =  @get('cm.api')

    numInputs = 1
    numOutputs = 2

    base = cm.estimateTxSize(numInputs, numOutputs, cm.estimateInputSigSize(1, 1))

    plus = if serverSignature then 1 else 0
    numPubKeys = numSigners + plus
    minSigs = minSignatures + plus
    size = cm.estimateTxSize(numInputs, numOutputs, cm.estimateInputSigSize(numPubKeys, minSigs))

    (size/base).toFixed(2)
  #
  #
  #
  setup: (->
    Ember.Logger.info "[Account Info] Started."

    @setupListeners()

    self = @
    @get('cm').waitForReady().then( -> waitIdleTime(DELAY)).then( ->
      self.prepareAccounts() unless self.get('isDestroyed')
    ).then( =>
      @setupCurrentLabels()
      self.trigger('init-finished')
    ).catch((err) ->
      Ember.Logger.error('[Account Info] Error during init: '. err)
      throw err
    )

  ).on('init')

)

export default CmAccountInfo
