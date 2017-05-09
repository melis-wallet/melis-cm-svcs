`import Ember from 'ember'`
`import CMCore from 'npm:melis-api-js'`
`import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'`

DELAY = 2000
SVCID = 'account-events'

C = CMCore.C

CmAccountEventsService = Ember.Service.extend(Ember.Evented,
  cm:  Ember.inject.service('cm-session')
  stream: Ember.inject.service('cm-stream')
  store: Ember.inject.service('simple-store')

  inited: false

  #
  #
  #
  fetchAllAccEvents: (fromDate) ->
    if accounts = @get('cm.accounts')
      accounts.forEach((account) =>
        @fetchAccEvents(account, fromDate)
      )


  #
  #
  #
  pushToStream: (evt, notifiable=false) ->
    id = 'evt-' + evt.get('id')
    account = evt.get('account')
    time = evt.get('data.date')
    @get('stream').push(id: id, subclass: 'evt', account: account, content: evt, created: time, updated: time, notifiable: notifiable)


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
  fetchAccEvents: (account, fromDate) ->
    if account

      # TODO, remember when
      fromDate ||= moment().subtract(35, 'days').unix() * 1000

      Ember.Logger.debug('= Getting account events for account', account.get('cmo.meta.name'))

      api = @get('cm.api')
      store = @get('store')

      self =  @
      api.accountGetNotifications(account.get('cmo'), fromDate).then((events) ->
        events.list.forEach((data) ->
          id = "#{data.type}-#{data.params.activationCode.code}"
          self.addEvt(id: id, type: data.type, account: account, cmo: data.params)
        )
      )

  #
  #
  #
  dispatchEventJoined: (data) ->
    accounts = @get('cm.accounts')
    self =  @
    accounts.forEach( (acc) =>
      if acc.get('cmo.pubId') == data.masterPubId
        id = "#{C.EVENT_JOINED}-#{data.activationCode.code}"
        self.newEvt(id: id, account: acc, type: C.EVENT_JOINED, cmo: data)
    )


  doneInit: ->
    @set('inited', true)
    @trigger('init-finished')
    @get('stream').serviceInited(SVCID)

  prefetchEvents: ->
    self = @
    @get('cm').waitForReady().then( ->
      waitIdleTime(DELAY)
    ).then( ->
      self.fetchAllAccEvents()
    ).then( ->  self.doneInit() unless self.get('isDestroyed') )

  setup: (->
    Ember.Logger.info  "== Starting account-events service"
    api = @get('cm.api')

    @prefetchEvents()
    @setupListeners()
  ).on('init')

  refreshEvents: ->
    if @get('cm.connected') && @get('inited')
      Ember.Logger.debug('- Refreshing events')
      waitIdleTime(DELAY).then( => @fetchAllAccEvents(@get('cm.lastRefresh')))

  setupListeners: ->
    api = @get('cm.api')
    @_eventLJoined = (data) => @dispatchEventJoined(data)
    api.on(C.EVENT_JOINED, @_eventLJoined)

    @get('cm').on('net-restored', this, @refreshEvents)

  teardownListener: ( ->
    @get('cm.api').removeListener(C.EVENT_JOINED, @_eventLJoined) if @_eventLJoined
    @get('cm').off('net-restored', this, @refreshEvents)
  ).on('willDestroy')

)

`export default CmAccountEventsService`
