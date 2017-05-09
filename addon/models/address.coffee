`import { attr, Model } from 'ember-cli-simple-store/model'`

Address = Model.extend(
  cm:  Ember.inject.service('cm-session')

  account: attr()
  cmo: attr()

  active: false

  usedIn: null

  time: ( ->
    @get('cmo.meta.requested') || @get('cmo.cd')
  ).property('cmo.meta.requested', 'cmo.cd')

  addressURL: (->
    if address = @get('cmo.address')
      "bitcoin:#{address}"
  ).property('cmo.address')

  # ptx will show on the stream
  display: Ember.computed.notEmpty('cmo.meta')

  #
  urgent: ( ->
    @get('display') && !@get('usedIn.length')
  ).property('display', 'usedIn.length')

  setup: ( ->
    @set('usedIn', Ember.A())
  ).on('init')
)

`export default Address`