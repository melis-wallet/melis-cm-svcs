`import Ember from 'ember'`
`import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'`
`import ScheduledEvent from '../mixins/scheduled-event'`

DELAY = 2000
STORAGE_ACCOUNT_PTR = /^storage\:recovery-info\:cm-account\:(.+)$/

CmRecoveryInfo = Ember.Service.extend(ScheduledEvent, Ember.Evented,
  cm:  Ember.inject.service('cm-session')

  useTimestamps: true

  #
  #
  #
  getRecoveryInfo: (account, fromDate) ->
    Ember.Logger.debug "[Rinfo] Getting recovery for: ", account.get('uniqueId')
    api = @get('cm.api')
    api.getRecoveryInfo(account.get('cmo'), fromDate).then((res) =>
      if Ember.get(res, 'recoveryData')
        account.set('recoveryInfo.current', res)
        @getExpiringUnspents(account)
    ).catch((error) ->
      Ember.Logger.error('Failed fetching recovery info for account: ', {account, error})
    )


  getExpiringUnspents: (account) ->
    Ember.Logger.debug "[Rinfo] Getting expiring unspents for: ", account.get('uniqueId')
    api = @get('cm.api')
    api.getExpiringUnspents(account.get('cmo')).then((res) =>
      if res && (list = Ember.get(res, 'list'))
        account.set('recoveryInfo.expiring', @reviewExpiring(list))
    ).catch((error) ->
      Ember.Logger.error('Failed fetching recovery info for account: ', {account, error})
    )

  reviewExpiring: (list) ->
    try
      cm = @get('cm')
      list.forEach((e) -> Ember.set(e, 'timeExpire', cm.estimateBlockTime(e.blockExpire)) if e.blockExpire)
      list
    catch error
      Ember.Logger.error('Failed processing unspents for: ', {account, error})

  #
  #
  #
  onScheduledEvent: ->
    Ember.Logger.debug('[Rinfo] scheduler.')
    accounts = @get('cm.accounts')
    accounts.forEach( (acc) =>
      if acc.get('needsRecovery') && (acc.get('recentTxs') || Ember.isBlank(acc.get('recoveryInfo.current')) || @get('useTimestamps'))
        current = acc.get('recoveryInfo.current')
        ts = (if current then Ember.get(current, 'ts') else null)
        acc.set('recentTxs', false)
        waitIdle().then( => @getRecoveryInfo(acc, ts))
    )
    @set('useTimestamps', false)


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
            Ember.Logger.warn('[Recovey Info] deleting stored data for stale account: ', accountId)
            localStorage.removeItem(key)
    catch err
      Ember.Logger.error '[Recovery Info] Stale account wiper: ', err
  #

  setup: (->
    Ember.Logger.info "[Recovery Info] Started."
    @startScheduling()

    self = @
    @get('cm').waitForReady().then( -> waitIdleTime(DELAY)).then( ->
      self.wipeStaleAccounts() unless self.get('isDestroyed')
    ).then( ->
      self.trigger('init-finished')
    ).catch((err) ->
      Ember.Logger.error('[Accunt Info] Error during init: '. err)
      throw err
    )
  ).on('init')

  tearOff: (->
    @stopScheduling()
  ).on('willDestroy')

)


`export default CmRecoveryInfo`