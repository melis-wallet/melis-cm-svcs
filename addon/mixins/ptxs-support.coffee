import EmberObject from '@ember/object'
import Mixin from '@ember/object/mixin'
import { sort, filterBy, alias } from '@ember/object/computed'

import CMCore from 'npm:melis-api-js'

C = CMCore.C

PtxsContext = EmberObject.extend(
  list: null

  sorting: ['cmo.cd:desc']
  sorted:  sort('list', 'sorting')

  active: filterBy('sorted', 'isActive', true)
  waiting: filterBy('sorted', 'isWaiting', true)

  signable: filterBy('sorted', 'accountCanSign', true)

  # might change: "relevant" means show them in summaries where it's not important if you can sign them or not
  relevant: alias('waiting')
)


PtxsSupport = Mixin.create(

  init: ->
    @_super(arguments...)

    @set 'ptxs', PtxsContext.create()
)


export default PtxsSupport
