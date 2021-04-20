import Service, { inject as service } from '@ember/service'
import Evented from '@ember/object/evented'
import { get, set, getProperties } from '@ember/object'
import { isBlank } from '@ember/utils'
import RSVP from 'rsvp'

import CMCore from 'melis-api-js'
import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'
import Logger from 'melis-cm-svcs/utils/logger'

C = CMCore.C

DELAY = 4000
LABELS_DELAY = 3000
STORAGE_ACCOUNT_PTR = /^storage\:account-state\:account\:(.+)$/

CmAccountInfo = Service.extend(Evented,

  cm: service('cm-session')


  #
  #
  #
  getAllAccountsInfo: ->
    if (accounts = @get('cm.accounts'))
      RSVP.all(accounts.map((account) =>
        @accountGetInfo(account)
      )).then( =>
        @trigger('load-all-finished')
      )

  #
  #
  #
  accountGetInfo: (account, refresh) ->

    if refresh || isBlank(account.get('info'))
      api = @get('cm.api')
      api.accountRefresh(account.get('cmo')).then((res) =>
        Logger.debug("Account info for #{account.pubId}: ", res)
        account.set('info', api.peekAccountInfo(account.get('cmo')))

      ).catch((err) ->
        Logger.error("[Account Info], failed getting info", err)
        throw err
      )

  #
  # track when currentAccount changes
  #
  accountChanged: (->
    if @get('cm.ready') && (account = @get('cm.currentAccount'))
      @accountGetInfo(account)
  ).observes('cm.currentAccount')


  #
  #
  #
  refreshCmo: (account) ->
    if account
      api = @get('cm.api')
      api.accountRefresh(account.get('cmo')).then((res) ->
        Logger.debug("Account refresh for #{account.pubId}: ", res)
        account.setProperties(
          cmo: res.account
          info: api.peekAccountInfo(account.get('cmo'))
          balance: res.balance
        )
      ).catch((err) ->
        Logger.error("[Account Info], failed refresh: ", err)
        throw err
      )

  #
  #
  #
  dispatchJoinEvt: (event) ->
    accounts = @get('cm.accounts')
    accounts.forEach( (acc) =>
      pubId = acc.get('cmo.masterPubId') || acc.get('cmo.pubId')
      if pubId == get(event, 'masterPubId')
        Logger.debug 'Account has changed:', acc
        waitIdleTime(1000).then( => @refreshCmo(acc))
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
            Logger.warn('[Account Info] deleting stored data for stale account: ', accountId)
            localStorage.removeItem(key)
    catch err
      Logger.error '[Account Info] Stale account wiper: ', err
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
      hasServer} = getProperties(account, 'totalSignatures', 'minSignatures', 'hasServer')

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
        hasServer} = getProperties(account, 'totalSignatures', 'minSignatures', 'hasServer')
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
    Logger.info "[Account Info] Started."

    @setupListeners()

    self = @
    @get('cm').waitForReady().then( -> waitIdleTime(DELAY)).then( ->
      self.prepareAccounts() unless self.get('isDestroyed')
    ).then( =>
      self.trigger('init-finished')
    ).catch((err) ->
      Logger.error('[Account Info] Error during init: '. err)
      throw err
    )

  ).on('init')

)

export default CmAccountInfo
