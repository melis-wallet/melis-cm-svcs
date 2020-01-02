import EmberObject, { computed, get, set, getProperties, getWithDefault } from '@ember/object'
import Service, { inject as service } from '@ember/service'
import Evented from '@ember/object/evented'
import { alias, bool } from '@ember/object/computed'
import { isBlank, isNone, isEmpty, isEqual } from '@ember/utils'
import RSVP from 'rsvp'
import CMCore from 'npm:melis-api-js'

import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'
import { filterProperties, mergedProperty } from 'melis-cm-svcs/utils/misc'
import PerAccountCtx from 'melis-cm-svcs/mixins/per-account-ctx'

import Logger from 'melis-cm-svcs/utils/logger'


C = CMCore.C
SVCID = 'address-provider'
DELAY = 2000

AccountCtx = EmberObject.extend(

  fetched: false

  account: null
  storedAddress: alias('account.sstate.receiveAddr')
  _currentAddress: null


  currentAddress: computed('_currentAddress',
    get: (key) ->
      @get('_currentAddress')

    set: (key, val) ->
      if val && (cmo = get(val, 'cmo'))
        @set('storedAddress', cmo)
      @set('_currentAddress', val)
  )
)



#
# provides addresses to the current account
#
AddressSvc = Service.extend(PerAccountCtx, Evented,
  ctxContainer: AccountCtx

  cm: service('cm-session')
  stream: service('cm-stream')

  store: service('simple-store')
  txsvc: service('cm-tx-infos')

  inited: false

  #
  # make sure every account has an address ready
  #
  prefetchAddrs: true

  #
  #
  #
  lazyRefreshCurrent: (account) ->
    account ?= @get('current.account')
    ctx = @forAccount(account)

    return unless account

    if isBlank(address = ctx.get('storedAddress')) || !get(address, 'address')
      if @get('prefetchAddrs')
        waitIdleTime(200).then( => @getCurrentAddress(account))
      else RSVP.resolve()
    else
      if (addr = ctx.get('currentAddress'))
        RSVP.resolve(addr)
      else
        waitIdle().then( => @refreshCurrentAddress(account, address))

  #
  #
  #
  getCurrentAddress: (account) ->
    account ?= @get('current.account')
    @requestNewAddress(account, {}).then((addr) =>
      @forAccount(account).set('currentAddress', addr)
    )

  #
  #
  #
  refreshCurrentAddress: (account, current) ->
    account ?= @get('current.account')
    current ?= @forAccount(account).get('currentAddress')
    @refreshAddress(account, current).then((addr) =>
      @forAccount(account).set('currentAddress', addr)
    )

  #
  #
  #
  updateCurrentAddress: (account, updates) ->
    account ?= @get('current.account')
    current = @forAccount(account).get('currentAddress')
    Logger.info '[Addr] update: ', current

    if current && (address = get(current, 'cmo.address'))
      meta = mergedProperty(current, 'meta', filterProperties(updates, 'info', 'amount'))
      labels = get(updates, 'labels') || get(address, 'labels')
      @getUnusedAddress(account, address, labels, meta).then((addr) =>
        @forAccount(account).set('currentAddress', addr)
      )
    else
      RSVP.resolve()

  #
  #
  #
  refreshAddress: (account, current) ->
    account ?= @get('current.account')
    {address, labels, meta} = val = getProperties(current, 'address', 'labels', 'meta')
    Logger.debug '[Addr] refresh: ', val
    @getUnusedAddress(account, address, labels, meta)


  #
  #
  #
  requestNewAddress: (account, data =  {}) ->
    account ?= @get('current.account')

    {labels, info, amount} = val = getProperties(data, 'labels', 'info', 'amount')
    Logger.debug '[Addr] request new: ', val
    @getUnusedAddress(account, null, labels, {info: info, amount: amount})


  #
  #
  #
  getUnusedAddress: (account, address, labels, meta) ->
    account ?= @get('current.account')

    return RSVP.resolve() unless account.get('isComplete')

    if(acct = account.get('cmo'))
      Logger.debug "[Addr] Requesting: ", {address: address, labels: labels, meta: meta}
      @get('cm.api').getUnusedAddress(acct, address, labels, meta).then((res) =>
        newaddr = getProperties(res, 'address', 'meta', 'labels', 'lastRequested', 'cd')
        Logger.debug "[Addr] got address: ", newaddr
        if newaddr && newaddr.address
          @updateAddr(id: newaddr.address, account: account, cmo: newaddr)
      ).catch((err) ->
        if err.ex == 'CmMissingCosignerException'
          Logger.error  '[Addr] error getting an address: account is incomplete'
        else
          Logger.error  '[Addr] error getting an address: ', err
          throw err
      )
    else
      RSVP.reject('invalid account')

  #
  #
  #
  clearAddress: (account) ->
    account ?= @get('current.account')
    @forAccount(account).set('currentAddress', null)


  #
  #
  #
  ensureCurrent: (account) ->
    return unless @get('inited')

    account ?= @get('current.account')
    return if account.get('refreshingAddress')

    ctx = @forAccount(account)
    if isBlank(address = ctx.get('currentAddress'))
      account.set('refreshingAddress', true)
      @lazyRefreshCurrent(account).finally( => account.set('refreshingAddress', false))
    else
      RSVP.resolve(address)

  #
  #
  #
  releaseAddress: (address) ->
    { account, cmo } = getProperties(address, 'account', 'cmo')
    if(acct = account.get('cmo'))
      @get('cm.api').addressRelease(acct, cmo.address).then((res) =>
        newaddr = getProperties(res, 'address', 'meta', 'labels', 'cd')
        Logger.debug "[Addr] released address: ", newaddr
        if newaddr && newaddr.address
          @updateAddr(id: newaddr.address, account: account, cmo: newaddr)
      ).catch((err) ->
        Logger.error '[Addr] Address release error', err
      )
    else
      RSVP.reject('invalid account')

  #
  #
  #
  updateAddress: (address, updates) ->
    { account, cmo } = getProperties(address, 'account', 'cmo')
    Logger.info '[Addr] update address: ', cmo, updates
    meta = mergedProperty(cmo, 'meta', filterProperties(updates, 'info', 'amount'))

    Logger.debug "[Addr] meta: ", meta, filterProperties(updates, 'info', 'amount')
    labels = get(updates, 'labels') || get(cmo, 'labels')

    if(acct = account.get('cmo'))
      meta.requested ||= moment.now()
      @get('cm.api').addressUpdate(acct, cmo.address, labels, meta).then((res) =>

        newaddr = getProperties(res, 'address', 'meta', 'labels', 'cd')
        Logger.debug "[Addr] updated address: ", newaddr
        if newaddr && newaddr.address
          @updateAddr(id: newaddr.address, account: account, cmo: newaddr)

      ).catch((err) ->
        Logger.error '[Addr] Address update error', err
      )
    else
      RSVP.reject('invalid account')


  #
  #
  #
  requestFromCurrent: (account, updates) ->
    account ?= @get('current.account')
    ctx = @forAccount(account)

    if current = get(ctx, 'currentAddress')
      @requestNewAddress(account, {}).then( (addr) =>
        @forAccount(account).set('currentAddress', addr)
        @updateAddress(current, updates)
      )
    else
      @requestNewAddress(account, updates)

  #
  #
  #
  pushToStream: (addr) ->
    id = 'addr-' + addr.get('id')
    account = addr.get('account')
    time = addr.get('time')
    @get('stream').push(id: id, subclass: 'address', account: account, content: addr, created: time, updated: time)


  #
  #
  #
  updateAddr: (info) ->
    store = @get('store')
    addr = store.push('address', info)
    @pushToStream(addr) if info.active
    @trigger('update-addr', addr)
    return addr


  #
  #
  #
  findAddr: (id) ->
    store = @get('store')
    store.find('address', id).get('content')

  #
  #
  #
  fetchActiveAddrs: (account, force) ->
    ctx = @forAccount(account)
    if force || !ctx.get('fetched')
      acc = get(account, 'cmo')
      api = @get('cm.api')

      self = @
      addresses = api.addressesGet(acc, onlyActives: true).then((res) ->
        res.list.forEach((a) ->  self.updateAddr(id: a.address, account: account, cmo: a, active: true))
        ctx.set('fetched', true)
      ).catch((err) ->
        Logger.error '[Addr] error getting addresses for address', err
      )
    else
      RSVP.resolve()


  #
  #
  #
  dispatchAddressUpd: (data) ->
    accounts = @get('cm.accounts')
    accounts.some( (acc) =>
      if acc.get('cmo.pubId') == data.accountPubId || acc.get('cmo.masterPubId') == data.accountPubId
        Logger.debug "[Addr] updated", data
        @updateAddr(id: data.aa.address, account: acc, cmo: data.aa, active: !isBlank(data.aa?.meta))
    )


  #
  #
  #
  accountHasChanged: ( ->
    if (account = @get('current.account')) && get(account, 'isComplete')
      @ensureCurrent(account)
      @fetchActiveAddrs(account)
  ).observes('current.account')


  #
  #
  #
  newTx: (tx) ->
    account = get(tx, 'account')
    txaddress = get(tx, 'cmo.address')
    address = @forAccount(account).get('currentAddress')
    if addr = @findAddr(txaddress)
      Logger.debug "[Addr] found an address matching this tx."
      addr.get('usedIn').pushObject(tx)

    if address && isEqual(get(address, 'cmo.address'), txaddress)
      Logger.debug "[Addr] current address of account #{account.get('pubId')} was used."
      @clearAddress(account)
      @ensureCurrent(account)

  #
  #
  #
  doneInit: ->
    @set('inited', true)
    @trigger('init-finished')
    @get('stream').serviceInited(SVCID)

  setup: ( ->
    Logger.info "- Starting Address Service"
    api = @get('cm.api')

    @_updateAddress = (data) => @dispatchAddressUpd(data)
    api.on(C.EVENT_ADDRESS_UPDATED, @_updateAddress)

    @get('txsvc').on('new-tx', this, @newTx)

    self = @
    self.get('cm').waitForReady().then( ->
      waitIdleTime(DELAY)
    ).then( ->
      if account = self.get('current.account')
        self.lazyRefreshCurrent(account)
        self.fetchActiveAddrs(account)
    ).then( ->  self.doneInit() unless self.get('isDestroyed') )
  ).on('init')


  teardownListener: ( ->
    @get('cm.api').removeListener(C.EVENT_ADDRESS_UPDATED, @_updateAddress) if @_updateAddress
    @get('txsvc').off('new-tx', this, @newTx)
  ).on('willDestroy')


)

export default AddressSvc
