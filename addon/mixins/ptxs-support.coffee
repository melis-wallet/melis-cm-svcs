import Ember from 'ember'
import CMCore from 'npm:melis-api-js'

C = CMCore.C

PtxsContext = Ember.Object.extend(
  list: null

  sorting: ['cmo.cd:desc']
  sorted:  Ember.computed.sort('list', 'sorting')

  active: Ember.computed.filterBy('sorted', 'isActive', true)
  waiting: Ember.computed.filterBy('sorted', 'isWaiting', true)

  signable: Ember.computed.filterBy('sorted', 'accountCanSign', true)

  # might change: "relevant" means show them in summaries where it's not important if you can sign them or not
  relevant: Ember.computed.alias('waiting')
)


PtxsSupport = Ember.Mixin.create(

  init: ->
    @_super(arguments...)

    @set 'ptxs', PtxsContext.create()
)


export default PtxsSupport
