import Service, { inject as service } from '@ember/service'
import Evented from '@ember/object/evented'
import { get, set, getProperties } from "@ember/object"
import { isBlank } from "@ember/utils"
import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'

import ScheduledEvent from '../mixins/scheduled-event'

import Logger from 'melis-cm-svcs/utils/logger'

DELAY = 2000
STORAGE_ACCOUNT_PTR = /^storage\:recovery-info\:cm-account\:(.+)$/

CmRecoveryInfo =Service.extend(ScheduledEvent, Evented,
  cm:  service('cm-session')

  useTimestamps: true

  #
  #
  #
  getRecoveryInfo: (account, fromDate) ->
    Logger.debug "[Rinfo] Getting recovery for: ", account.get('uniqueId')
    api = @get('cm.api')
    api.getRecoveryInfo(account.get('cmo'), fromDate).then((res) =>
      if get(res, 'recoveryData')
        account.set('recoveryInfo.current', res)
        @getExpiringUnspents(account)
    ).catch((error) ->
      Logger.error('Failed fetching recovery info for account: ', {account, error})
    )


  getExpiringUnspents: (account) ->
    Logger.debug "[Rinfo] Getting expiring unspents for: ", account.get('uniqueId')
    api = @get('cm.api')
    api.getExpiringUnspents(account.get('cmo')).then((res) =>
      Logger.debug("Expiring unspents: ", res)
      if res && (list = get(res, 'list'))
        account.set('recoveryInfo.expiring', @reviewExpiring(list, account.get('coin')))
    ).catch((error) ->
      Logger.error('Failed fetching recovery info for account: ', {account, error})
    )

  reviewExpiring: (list, coin) ->
    try
      cm = @get('cm')
      list.forEach((e) -> set(e, 'timeExpire', cm.estimateBlockTime(e.blockExpire, coin)) if e.blockExpire)
      list
    catch error
      Logger.error('Failed processing unspents: ', error)

  #
  #
  #
  onScheduledEvent: ->
    return if @isDestroyed

    Logger.debug('[Rinfo] scheduler.')

    accounts = @get('cm.accounts')
    accounts?.forEach( (acc) =>
      if acc.get('needsRecovery') && (acc.get('recentTxs') || isBlank(acc.get('recoveryInfo.current')) || @get('useTimestamps'))
        current = acc.get('recoveryInfo.current')
        ts = (if current then get(current, 'ts') else null)
        acc.set('recentTxs', false)
        @set('useTimestamps', false)
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
            Logger.warn('[Recovey Info] deleting stored data for stale account: ', accountId)
            localStorage.removeItem(key)
    catch err
      Logger.error '[Recovery Info] Stale account wiper: ', err
  #

  setup: (->
    Logger.info "[Recovery Info] Started."
    @startScheduling()

    self = @
    @get('cm').waitForReady().then( -> waitIdleTime(DELAY)).then( ->
      self.wipeStaleAccounts() unless self.get('isDestroyed')
    ).then( ->
      self.trigger('init-finished')
    ).catch((err) ->
      Logger.error('[Accunt Info] Error during init: '. err)
      throw err
    )
  ).on('init')

  tearOff: (->
    @stopScheduling()
  ).on('willDestroy')

)


export default CmRecoveryInfo