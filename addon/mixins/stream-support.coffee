import EmberObject from '@ember/object'
import Mixin from '@ember/object/mixin'
import { sort, filterBy, filter } from '@ember/object/computed'

import CMCore from 'melis-api-js'

C = CMCore.C


StreamContext = EmberObject.extend(

  list: null

  sorting: ['updated:desc']
  sorted: sort('list', 'sorting')

  displayed: filterBy('sorted', 'display', true)

  urgent:  filterBy('sorted', 'urgent', true)

  newer: filter('displayed', (entry, index, array) ->
    entry.get('updated') > @get('highWater')
  )

  current: filter('displayed', (entry, index, array) ->
    entry.get('updated') <= @get('highWater')
  )

  urgentCurrent: filterBy('current', 'urgent', true)
  urgentNewer:  filterBy('newer', 'urgent', true)

  highWater: null
  lowWater: null

)

StreamSupport = Mixin.create(

  init: ->
    @_super(arguments...)
    @set 'stream', StreamContext.create()
)


export default StreamSupport
