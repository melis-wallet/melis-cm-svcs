import Service, { inject as service } from '@ember/service'
import Evented from "@ember/object/evented"
import { get, set, getProperties } from "@ember/object"
import { isBlank, isNone, isEmpty } from "@ember/utils"
import RSVP from 'rsvp'

import CMCore from 'melis-api-js'
import Ptx from 'melis-cm-svcs/models/ptx'
import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'
import { mergeProperty } from 'melis-cm-svcs/utils/misc'

import Logger from 'melis-cm-svcs/utils/logger'

C = CMCore.C
SVCID = 'ptxs'
DELAY = 500

CmPreparedTxService = Service.extend(Evented,

  cm: service('cm-session')
  stream: service('cm-stream')
  store: service('simple-store')

  inited: false

  #
  #
  #
  fetchAllPtx: (fromDate) ->
    if (accounts = @get('cm.accounts'))

      RSVP.all(accounts.map((account) =>
        @fetchPtxs(account, fromDate)
      )).then( =>
        @trigger('load-all-finished', fromDate)
      )


  #
  #
  #
  fetchPtxs: (account, fromDate) ->
    if account

      Logger.debug('= Getting PTX for account', account.get('cmo.meta.name'))

      api = @get('cm.api')
      store = @get('store')

      self = @
      api.ptxsGet(account.get('cmo'), fromDate).then((txs) =>
        txs.list.forEach((ptx) -> self.addPtx(id: ptx.id, account: account, cmo: ptx))
        account.set('ptxs.list', @findByAccount(account))
        @trigger('load-finished', account, fromDate)
      ).catch((err) ->
        Logger.error('[PTX] Error fetching PTXs for account: ', err)
      )

  #
  #
  #
  getPtxByHash: (hash, account) ->
    @get('cm.api').ptxGetByHash(account.get('cmo'), hash).then((res) =>
      if ptx = get(res, 'ptx')
        @pushPtx(id: ptx.id, account: account, cmo: ptx)
    ).catch((err) ->
      Logger.error('[PTX] Error PTX by hash ', err)
      throw err
    )


  #
  #
  #
  ptxFromState: (state, account) ->
    if state
      account ||= @get('cm.currentAccount')
      if ptxData = get(state, 'ptx')
        res = @addPtx(id: ptxData.id, account: account, cmo: ptxData, currentState: state)
    return res

  #
  # finds by id _including_ the server side
  #
  findById: (id , account) ->
    store = @get('store')
    if ptx = store.find('ptx', id).get('content')
      RSVP.resolve(ptx)
    else
      @get('cm.api').ptxGetById(id).then((res) =>
        if ptx = get(res, 'ptx')
          @addPtx(id: ptx.id, account: account, cmo: ptx)
      )

  #
  #
  #
  findByAccount: (account) ->
    if account
      store = @get('store')
      store.find('ptx', {'account.pubId': get(account, 'pubId')})

  #
  # a new account has been created
  #
  newAccount: ( ->
    @get('cm.accounts').forEach((account) => fetchPtxs(account) if isNone(account.get('ptxs')))
  ).observes('cm.accounts')

  #
  #
  #
  findAll: ->
     @get('store').find('ptx')

  #
  # fetch the discussion for a ptx now
  #
  fetchDiscussion: (ptx, force) ->
    RSVP.reject('no cmo') unless (tx = get(ptx, 'cmo'))

    if isEmpty(ptx.get('discussion')) || force
      @get('cm.api').msgGetAllToPtx(tx).then((res) =>
        ptx.set('discussion', res.list)
        return res.list
      ).catch((err) ->
        Logger.error '[PTX] Error fetching discussion for ptx: ', tx
        throw err
      )
    else
      RSVP.resolve(ptx.get('discussion'))

  #
  #
  #
  idleFetchDiscussion: (ptx) ->
    waitIdle().then( => @fetchDiscussion(ptx) )


  # Ops

  #
  #
  #
  ptxCancel: (ptx) ->
    if ptx.get('accountIsOwner')
      @get('cm.api').ptxCancel(ptx.get('cmo')).then( =>
        @trigger('cancelled-ptx', ptx)
      ).catch((err)->
        Logger.error('[PTX] Cancel ptx failed: ', err)
        throw err
      )
    else
      RSVP.reject('not owner')


  #
  #
  #
  ptxPropose: (ptx) ->
    { state, account } = ptx.getProperties('state', 'account')

    if (acctCmo = ptx.get('account.cmo')) && (ptxCmo = ptx.get('cmo'))
      @get('cm.api').ptxSignFields(acctCmo, ptxCmo).then((data) =>
        res = @pushPtx(id: data.ptx.id, account: account, cmo: data.ptx)
        @trigger('proposed-ptx', ptx, res)
        return res
      ).catch((err) ->
        Logger.error('[PTX] Propose ptx failed: ', err)
        throw err
      )
    else
      RSVP.reject('improper state')


  #
  #
  #
  ptxSign: (ptx) ->
    if (state = ptx.get('state'))
      waitTime(200).then( =>
        @get('cm.api').payConfirm(state)
      ).then((data) ->
        @trigger('signed-ptx', ptx, data)
        return data
      ).catch((err) ->
        Logger.error('[PTX] Sign ptx failed: ', err)
        throw err
      )
    else
      RSVP.reject('no state')


  #
  #
  #
  getUnspents: (account) ->
    if cmo = get(account, 'cmo')
      @get('cm.api').getUnspents(cmo).then((res) =>
        account.set('unspents', res.list)
      )


  # Events

  newMeta: (info) ->
    store = @get('store')
    if (ptx = store.find('ptx', info.id)) && (!isBlank(ptx.get('cmo')))
      mergeProperty(ptx, 'cmo.meta', info.meta)
      @pushToStream(ptx, 'upd')
    return ptx

  newSignature: (info) ->
    store = @get('store')
    if ptx = store.find('ptx', info.id)
      ptx.set('cmo.signatures', info.signatures)
      @pushToStream(ptx, 'upd')
    else
      Logger.error '[PTX] ptx-update for a ptx we do not know', info

  newMessage: (msg, account) ->
    store = @get('store')
    if ptxId = msg.toPtx
      if ptx = store.find('ptx', ptxId)
        ptx.get('discussion').unshiftObject(msg)
        @trigger 'msg-to-ptx', msg, ptx

        { type, date } = getProperties(msg, 'type', 'date')

        # kind of kludgy
        if type == C.CHAT_MSG_TYPE_SIG
          signer = get(msg, 'payload.signerPubId ')
          enough = get(msg, 'payload.enoughSigners ')
          @trigger('new-sig', signer, enough, ptx, date)

        @pushMsgToStream(msg, ptx, date)


  # Store ops
  pushMsgToStream: (msg, ptx, date) ->
    account = ptx.get('account')

    if get(msg, 'fromPubId') == get(account, 'uniqueId')
      Logger.debug '-- ptx own message', get(account, 'uniqueId')
    else
      Logger.debug '-- ptx pushing new message', get(msg, 'fromPubId'), get(account, 'uniqueId')
      id = 'txm-' + ptx.get('id')
      set(msg, 'display', true)
      @get('stream').push(id: id, subclass: 'txm', account: account, content: msg, ptx: ptx, created: date, updated: date, notifiable: true)


  #
  #
  #
  pushToStream: (ptx, notifiable=false) ->
    id = 'ptx-' + ptx.get('id')
    account = ptx.get('account')
    time = ptx.get('cmo.cd')
    @get('stream').push(id: id, subclass: 'ptx', account: account, content: ptx, created: time, updated: time, notifiable: notifiable)


  #
  #
  #
  pushPtx: (info) ->
    store = @get('store')
    store.push('ptx', info)

  #
  #
  #
  addPtx: (info) ->
    ptx = @pushPtx(info)
    @pushToStream(ptx)
    @trigger('add-ptx', ptx)
    # @idleFetchDiscussion(ptx)
    return ptx

  #
  #
  #
  updatePtx: (info) ->
    store = @get('store')
    if store.find('ptx', info.id).get('content')
      ptx = store.push('ptx', info)
      @pushToStream(ptx, 'upd')
      @trigger('update-ptx', ptx)
    else
      Logger.error '[PTX] ptx-update for a ptx we do not know', info

  #
  #
  #
  insertPtx: (info) ->
    store = @get('store')
    if store.find('ptx', info.id).get('content')
      ptx = store.push('ptx', info)
      @pushToStream(ptx, 'upd')
      @trigger('update-ptx', ptx)
    else
      ptx = store.push('ptx', info)
      @pushToStream(ptx, 'new')
      @trigger('new-ptx', ptx)
      if !ptx.get('accountIsOwner')
        @trigger('new-ptx-request', ptx)

    return ptx


  # Dispatchers

  #
  #
  #
  dispatchNewPtx:  (data) ->
    Logger.debug "*New PTX: ", data
    accounts = @get('cm.accounts')
    accounts.some( (acc) =>
      if acc.get('cmo.pubId') == data.masterPubId || acc.get('cmo.masterPubId') == data.masterPubId
        @insertPtx(id: data.ptx.id, account: acc, cmo: data.ptx)
    )

  #
  #
  #
  dispatchUpdatePtx: (data) ->
    Logger.debug "*Updated PTX: ", data
    accounts = @get('cm.accounts')
    accounts.some( (acc) =>
      if acc.get('cmo.pubId') == data.masterPubId || acc.get('cmo.masterPubId') == data.masterPubId
        Logger.debug "--- found master", acc
        if data.ptx # a real update
          @updatePtx(id: data.ptxId, account: acc, cmo: data.ptx)
        if data.msg # a chat message or a signature event
          @newMessage(data.msg, acc)
        if data.meta # updated meta signer info
          @newMeta(id: data.ptxId, account: acc, meta: data.meta)
        if data.signatures # new signature data
          @newSignature(id: data.ptxId, account: acc, signatures: data.signatures)

    )

  doneInit: ->
    @set('inited', true)
    @trigger('init-finished')
    @get('stream').serviceInited(SVCID)

  refreshPtxs: ->
    if @get('cm.connected') && @get('inited')
      Logger.debug('- Refreshing ptxs')
      waitIdleTime(DELAY).then( => @fetchAllPtx(@get('cm.lastRefresh')))

  setup: ( ->

    Logger.debug  "== Starting ptx service"
    api = @get('cm.api')

    @setupListeners()

    self = @
    @get('cm').waitForReady().then( ->
      self.fetchAllPtx()
    ).then( ->
      self.doneInit() unless self.get('isDestroyed')
    ).catch((err) ->
      Logger.error('[PTX] Error fetching PTXs: ', err)
    )
  ).on('init')

  setupListeners: ->
    api = @get('cm.api')
    @_newPtx = (data) => @dispatchNewPtx(data)
    @_updatePtx = (data) => @dispatchUpdatePtx(data)

    api.on(C.EVENT_PTX_NEW, @_newPtx)
    api.on(C.EVENT_PTX_UPDATED, @_updatePtx)

    @get('cm').on('net-restored', this, @refreshPtxs)

  teardownListener: ( ->
    @get('cm.api').removeListener(C.EVENT_PTX_NEW, @_newPtx) if @_newPtx
    @get('cm.api').removeListener(C.EVENT_PTX_UPDATED, @_updatePtx) if @_updatePtx
    @get('cm').off('net-restored', this, @refreshPtxs)
  ).on('willDestroy')
)

export default CmPreparedTxService