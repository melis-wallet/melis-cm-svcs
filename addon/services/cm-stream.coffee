import Ember from 'ember'
import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'

DELAY = 5000
INITED_SVCS = 4

Stream= Ember.Service.extend(Ember.Evented,

  cm: Ember.inject.service('cm-session')
  store: Ember.inject.service('simple-store')

  initedSvcs: Ember.A()

  # TODO kind of naive I know
  inited: Ember.computed.gte('initedSvcs.length', INITED_SVCS)

  #
  #
  #
  serviceInited: (svc) ->
    @get('initedSvcs').pushObject(svc)

  #
  #
  #
  observeInited: ( ->
    @trigger('init-finished')
    Ember.Logger.info('[STREAM] All subservices inited.') if @get('inited')
  ).observes('inited').on('init')

  #
  #
  #
  findByAccount: (account) ->
    if account
      store = @get('store')
      store.find('stream-entry', {'account.pubId': Ember.get(account, 'pubId')})

  #
  # a new account has been created
  #
  newAccount: ( ->
    @get('cm.accounts').forEach((account) => @pushAccount(account) if Ember.isNone(account.get('stream.list')))
  ).observes('cm.accounts.[]')

  #
  #
  #
  pushAccounts: ->
    accounts = @get('cm.accounts')
    accounts.forEach((account) =>  @pushAccount(account))

  #
  #
  #
  pushAccount: (account) ->
    account.set('stream.list', @findByAccount(account))
    @setHighWater(account, moment.now(), account)


  setHighWater: (target, time, account=null) ->
    target.set('stream.highWater', time)
    id =
      if account && (pubId = Ember.get(account, 'pubId'))
        'hwm-' + account.get('pubId')
      else
        'hwm-w'
    @push(id: id, account: account, subclass: 'hwm', content: {display: true},  created: time, updated: time)


  setLowWater: (target, time, account=null) ->
    target.set('stream.lowWater', time)
    id =
      if account && (pubId = Ember.get(account, 'pubId'))
        'lwm-' + account.get('pubId')
      else
        'lwm-w'
    @push(id: id, account: account, subclass: 'lwm', content: {display: true},  created: time, updated: time)


  push: (data) ->
    store = @get('store')
    entry = store.push('stream-entry', data)
    @trigger('entry', entry)
    if Ember.get(entry, 'notifiable')
      @trigger('notifiable-entry', entry)


  pushEvent: (event, data) ->
    @trigger('notifiable-event', event, data)


  setup: ( ->
    @pushAccounts()
  ).on('init')

)

export default Stream
