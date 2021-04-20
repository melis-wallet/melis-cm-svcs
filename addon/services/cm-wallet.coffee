#import Ember from 'ember'
import Service, { inject as service } from '@ember/service'
import Evented from "@ember/object/evented"
import { get, set } from "@ember/object"
import { isBlank } from "@ember/utils"
import RSVP from 'rsvp'
import CMCore from 'melis-api-js'
import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'
import StreamSupport from 'melis-cm-svcs/mixins/stream-support'
import Logger from 'melis-cm-svcs/utils/logger'

DELAY = 2000
REFRESH_DELAY = 8000
SVCID = 'wallet'

C = CMCore.C

CmWalletService = Service.extend(Evented, StreamSupport,
  cm: service('cm-session')
  streamsvc: service('cm-stream')
  store: service('simple-store')

  inited: false

  labels: []

  getLabels: (force) ->

    api = @get('cm.api')

    if force || isBlank(@get('labels'))
      api.getAllLabels().then((res) =>
        @set('labels', l) if (l = get(res, 'labels'))
      ).catch((err) ->
        Logger.error("[Wallet], failed getting labels", err)
        throw err
      )
    else
      RSVP.resolve(@get('labels'))


  cancelPendingTfad: ->
    @get('store').find('stream-entry', {account: null})?.forEach((evt) ->
      if evt.get('content.type') ==  C.EVENT_TFA_DISABLE_PROPOSAL
        evt.set('isCanceled', true)
    )

  eventDeviceDeleted: (data) ->
    if get(data, 'lastUsedInLogin')
      id = "#{C.EVENT_DEVICE_DELETED}-#{data.ts}"
      @newEvt(id: id, type: C.EVENT_DEVICE_DELETED, cmo: data, time: data.ts)

  eventTfaDisable: (data, date) ->
    id = "#{C.EVENT_TFA_DISABLE_PROPOSAL}-#{data.id}"
    date ||= data.ts

    if data.canceled
      @cancelPendingTfad()
    @newEvt(id: id, type: C.EVENT_TFA_DISABLE_PROPOSAL, cmo: data, time: date)

  eventDeviceLogin: (data) ->
    id = "#{C.EVENT_DEVICE_LOGIN}-#{data.id}"
    @newEvt(id: id, type: C.EVENT_DEVICE_LOGIN, cmo: data, time: data.ts)

  eventDevicePrimary: (data) ->
    id = "#{C.EVENT_NEW_PRIMARY_DEVICE}-#{data.id}"
    @newEvt(id: id, type: C.EVENT_NEW_PRIMARY_DEVICE, cmo: data, time: data.ts)


  handleWall: (data) ->
    id = "#{C.EVENT_PUBLIC_MESSAGE}-#{data.date}"
    @newEvt(id: id, type: C.EVENT_PUBLIC_MESSAGE, cmo: data.params, time: data.date)



  #
  #
  #
  pushToStream: (evt, notifiable=false) ->
    id = 'evt-' + evt.get('id')
    time = evt.get('time')
    @get('streamsvc').push(id: id, subclass: 'evt', content: evt, created: time, updated: time, notifiable: notifiable)


  #
  #
  #
  addEvt: (info) ->
    store = @get('store')
    evt = store.push('event', info)
    @pushToStream(evt)
    @trigger('add-evt', evt)

  #
  #
  #
  newEvt: (info) ->
    store = @get('store')
    evt = store.push('event', info)
    @pushToStream(evt, 'new')
    @trigger('new-evt', evt)

  #

  #
  #
  #
  fetchAllEvents: (fromDate) ->

    # TODO, remember when
    fromDate ||= moment().subtract(35, 'days').unix() * 1000

    Logger.debug('= Getting wallet events')

    api = @get('cm.api')
    store = @get('store')

    self =  @
    api.walletGetNotifications(fromDate).then((events) ->
      Logger.debug "Wallet Events: ", events
      events.list.forEach((data) ->
        switch data.type
          when C.EVENT_TFA_DISABLE_PROPOSAL
            self.eventTfaDisable(data.params, data.date)
          else
           id = "#{data.type}-#{data.params.id}"
           self.addEvt(id: id, type: data.type, cmo: data.params, time: data.date)
      )
    )


  initStream: ->
    store = @get('store')
    @get('streamsvc').setHighWater(this, moment.now())
    entries = store.find('stream-entry', {'account': null})
    @set('stream.list', entries)


  doneInit: ->
    @set('inited', true)
    @trigger('init-finished')
    @get('streamsvc').serviceInited(SVCID)

  prefetchEvents: ->
    self = @
    fromDate = moment().subtract(40, 'days').unix() * 1000

    @get('cm').waitForReady().then( ->
      waitIdleTime(DELAY)
    ).then( ->
      self.fetchAllEvents(fromDate)
      self.getLabels()
    ).then( ->  self.doneInit() unless self.get('isDestroyed'))

  setup: (->
    Logger.info  "== Starting wallet-events service"
    api = @get('cm.api')

    @initStream()
    @prefetchEvents()
    @setupListeners()
    @set('cm.lastRefresh', (moment.now() * 1000))
  ).on('init')

  refreshEvents: ->
    if @get('cm.connected') && @get('inited')
      Logger.debug('- Refreshing events in', REFRESH_DELAY)
      waitIdleTime(REFRESH_DELAY).then( =>
        @fetchAllEvents(@get('cm.lastRefresh'))
        @set('cm.lastRefresh', (moment.now() * 1000))
      )

  setupListeners: ->
    api = @get('cm.api')

    @_eventDeviceDeleted = (data) => @eventDeviceDeleted(data)
    @_eventTfaDisable = (data) => @eventTfaDisable(data)
    @_eventDeviceLogin = (data) => @eventDeviceLogin(data)
    @_eventDevicePrimary = (data) => @eventDevicePrimary(data)
    @_eventWall = (data) => @handleWall(data)

    api.on(C.EVENT_PUBLIC_MESSAGE, @_eventWall)
    api.on(C.EVENT_DEVICE_DELETED, @_eventDeviceDeleted)
    api.on(C.EVENT_TFA_DISABLE_PROPOSAL, @_eventTfaDisable)
    api.on(C.EVENT_DEVICE_LOGIN, @_eventDeviceLogin)
    api.on(C.EVENT_NEW_PRIMARY_DEVICE, @_eventDevicePrimary)

    @get('cm').on('net-restored', this, @refreshEvents)

  teardownListener: ( ->
    @get('cm.api').removeListener(C.EVENT_PUBLIC_MESSAGE, @_eventWall) if @_eventWall
    @get('cm.api').removeListener(C.EVENT_DEVICE_DELETED, @_eventDeviceDeleted) if @_eventDeviceDeleted
    @get('cm.api').removeListener(C.EVENT_TFA_DISABLE_PROPOSAL, @_eventTfaDisable) if @_eventTfaDisable
    @get('cm.api').removeListener(C.EVENT_DEVICE_LOGIN, @_eventDeviceLogin) if @_eventDeviceLogin
    @get('cm.api').removeListener(C.EVENT_NEW_PRIMARY_DEVICE, @_eventDevicePrimary) if @_eventDevicePrimary
    @get('cm').off('net-restored', this, @refreshEvents)
  ).on('willDestroy')

)

export default CmWalletService
