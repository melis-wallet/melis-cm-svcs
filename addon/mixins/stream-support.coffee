`import Ember from 'ember'`
`import CMCore from 'npm:melis-api-js'`

C = CMCore.C


StreamContext = Ember.Object.extend(

  list: null

  sorting: ['updated:desc']
  sorted: Ember.computed.sort('list', 'sorting')

  displayed: Ember.computed.filterBy('sorted', 'display', true)

  urgent:  Ember.computed.filterBy('sorted', 'urgent', true)

  newer: Ember.computed.filter('displayed', (entry, index, array) ->
    entry.get('updated') > @get('highWater')
  )

  current: Ember.computed.filter('displayed', (entry, index, array) ->
    entry.get('updated') <= @get('highWater')
  )

  urgentCurrent:  Ember.computed.filterBy('current', 'urgent', true)
  urgentNewer:  Ember.computed.filterBy('newer', 'urgent', true)

  highWater: null
  lowWater: null

)

StreamSupport = Ember.Mixin.create(

  init: ->
    @_super(arguments...)
    @set 'stream', StreamContext.create()
)


`export default StreamSupport`
