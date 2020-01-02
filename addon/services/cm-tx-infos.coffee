import Service, { inject as service } from '@ember/service'
import Evented from "@ember/object/evented"
import { get, set, getProperties } from "@ember/object"
import { isBlank, isNone, isEmpty } from "@ember/utils"
import RSVP from 'rsvp'

import CMCore from 'npm:melis-api-js'
import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'

import Logger from 'melis-cm-svcs/utils/logger'


DELAY = 4000
PREFETCH_PG_SIZE= 1000

C = CMCore.C
SVCID = 'tx-infos'



CmTxInfoService = Service.extend(Evented,
  cm:  service('cm-session')
  stream: service('cm-stream')
  store: service('simple-store')
  recovery : service('cm-recovery-info')

  inited: false


  #
  #
  #
  prefetchTxInfos: ->
    accounts = @get('cm.accounts')

    fromDate = moment().subtract(15, 'days').unix() * 1000

    RSVP.all(accounts.map((account) =>
      @prefetch(account, fromDate)
    )).then( =>
      @trigger('prefetch-finished')
    )


  #
  #
  #
  getPage: (account, fromDate, page = 0) ->
    api = @get('cm.api')
    self = @
    Logger.debug('[txi] - Getting page: ', page,  account.get('name'), moment(fromDate).toDate())
    api.txInfosGet(account.get('cmo'), {
        fromDate: fromDate
        direction:  C.DIR_ASCENDING
      }, {
        page: page
        size: PREFETCH_PG_SIZE
        sortField: C.FIELD_LAST_UPDATED
        sortDir: C.DIR_DESCENDING
      }
    ).then((txs) =>
      txs.list.forEach((txinfo) ->
        self.addTx(id: txinfo.id, account: account, cmo: txinfo)
      )
      txs
    ).catch((err) ->
      Logger.error('Failed getting tx infos', err)
      throw err
    )



  prefetch: (account, fromDate) ->
    Logger.debug('[txi] - Prefetching account: ', account.get('name'), moment(fromDate).toDate())
    @getPage(account, fromDate, 0).then((txs) =>
      account.set('sstate.lastTxinfoFetch', txs.ts)
      @trigger('load-finished', account, fromDate)
    )


  #
  #
  #
  txiFetchMore: (account) ->
    page = account.incrementProperty('txPrefetchPage') || 0
    @getPage(account, @get('txPrefetchDate'), page).then((txs) =>
      account.setProperties
        txiFetchPage: page
        txiFetchNext: txs.hasNext
    )


  #
  #
  #
  txiFetch: (account, fromDate) ->
    Logger.debug('[txi] - Fetching account: ', account.get('name'), moment(fromDate).toDate())
    @getPage(account, fromDate, 0).then((txs) =>
      account.setProperties
        txiFetchDate: fromDate
        txiFetchPage: 0
        txiFetchNext: txs.hasNext
        txiFetchDone: true
    )


  #
  #
  #
  trigAcctPrefetch: (->
    days =15
    fromDate = moment().subtract(days, 'days').unix() * 1000
    if (acct = @get('cm.currentAccount')) && !acct.get('txInfoFetched')
      @prefetch(acct, fromDate).then( => acct.set('txInfoFetched', true))
  ).observes('cm.currentAccount')


  #
  #
  #
  fetchAllTx: (fromDate) ->
    fromDate ||= (moment().subtract(1, 'days').unix() * 1000)
    if (accounts = @get('cm.accounts'))
      RSVP.all(accounts.map((account) =>
        @prefetch(account, fromDate)
      )).then( =>
        @trigger('load-all-finished', fromDate)
      )


  #
  #
  #
  updTx: (info) -> @newTx(info)

  #
  #
  #
  newTx: (info) ->
    store = @get('store')
    # TODO, check this 'content' thing
    if store.find('txinfo', info.id).get('content')
      tx = store.push('txinfo', info)
      @pushToStream(tx, 'upd')
      @trigger('update-tx', tx)
    else
      tx = store.push('txinfo', info)
      @pushToStream(tx, 'new')
      @trigger('new-tx', tx)
      tx.get('account').set('recentTxs', true)
    return tx

  #
  #
  #
  addTx: (info) ->
    store = @get('store')
    tx = store.push('txinfo', info)
    @pushToStream(tx)
    @trigger('add-tx', tx)
    return tx


  #
  #
  #
  findById: (id) ->
    store = @get('store')
    tx = store.find('txinfo', id)
    if tx
      RSVP.resolve(tx)
    else
      @get('cm.api').txInfoGet(id).then((res) =>
        @addTx(res)
      )

  #
  #
  #
  findByAcct: (account)->
     @get('store').find('txinfo', {account: account})


  #
  #
  #
  pushToStream: (txinfo, notifiable=false) ->
    id = 'tx-' + txinfo.get('id')
    {time, account} = txinfo.getProperties('time', 'account')
    @get('stream').push(id: id, subclass: 'tx', account: account, content: txinfo, created: time, updated: time, notifiable: notifiable)

  #
  #
  #
  doneInit: ->
    @set('inited', true)
    @trigger('init-finished')
    @get('stream').serviceInited(SVCID)

  #
  #
  #
  initPrefetch: ->
    self = @
    @get('cm').waitForReady().then( ->
      waitIdleTime(DELAY)
    ).then( ->
      self.trigAcctPrefetch() unless self.get('isDestroyed')
    ).then( -> self.doneInit() unless self.get('isDestroyed'))


  #
  #
  #
  dispatchNewTx: (data) ->
    accounts = @get('cm.accounts')
    accounts.forEach( (acc) =>
      if acc.get('cmo.pubId') == data.accountPubId
        @newTx(id: data.txInfo.id, account: acc, cmo: data.txInfo)
    )


  #
  #
  #
  dispatchUpdTx: (data) ->
    accounts = @get('cm.accounts')
    accounts.forEach( (acc) =>
      if acc.get('cmo.pubId') == data.accountPubId
        @updTx(id: data.txInfo.id, account: acc, cmo: data.txInfo)
    )


  #
  #
  #
  refreshTxs: ->
    if @get('cm.connected') && @get('inited')
      Logger.debug('- Refreshing txs in', DELAY)
      # tentatively go two hours back, to fetch modifications (vs new txs) that happened while we were asleep
      fromDate = (@get('cm.lastRefresh') || (moment.now() * 1000)) - 7200000
      waitIdleTime(DELAY).then( => @fetchAllTx(fromDate))


  #
  #
  #
  setup: ( ->
    Logger.info  "== Starting tx-info service"
    @setupListeners()
    @initPrefetch()
  ).on('init')


  #
  #
  setupListeners: ->
    @get('recovery')
    api = @get('cm.api')
    @_evtNewTx = (data) => @dispatchNewTx(data)
    @_evtUpdTx = (data) => @dispatchUpdTx(data)

    api.on(C.EVENT_TX_INFO_NEW, @_evtNewTx)
    api.on(C.EVENT_TX_INFO_UPDATED, @_evtUpdTx)
    @get('cm').on('net-restored', this, @refreshTxs)

  #
  #
  teardownListener: ( ->
    @get('cm.api').removeListener(C.EVENT_TX_INFO_NEW, @_eventListener) if @_evtNewTx
    @get('cm.api').removeListener(C.EVENT_TX_INFO_UPDATED, @_eventListener) if @_evtUpdTx
    @get('cm').off('net-restored', this, @refreshTxs)

  ).on('willDestroy')


)

export default CmTxInfoService
