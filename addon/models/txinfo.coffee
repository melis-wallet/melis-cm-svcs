import { attr, Model } from 'ember-cli-simple-store/model'

TxInfo = Model.extend(
  cm:  Ember.inject.service('cm-session')

  account: attr()
  cmo: attr()

  negative: Ember.computed.lt('cmo.amount', 0)
  positive: Ember.computed.not('negative')
  time: Ember.computed.alias('cmo.cd')

  unconfirmed: Ember.computed.not('confirmations')

  confirmations: ( ->
    if @get('cmo.blockMature')
      (@get('cm.block.height') - @get('cmo.blockMature')) + 1
  ).property('cm.block.height', 'cmo.blockMature')

  # display in stream
  display: true
  urgent: false
)

export default TxInfo