import { inject as service } from '@ember/service'
import { computed } from '@ember/object'
import { alias } from '@ember/object/computed'
import { attr, Model } from 'ember-cli-simple-store/model'

TxInfo = Model.extend(
  cm:  service('cm-session')

  account: attr()
  cmo: attr()

  negative: computed.lt('cmo.amount', 0)
  positive: computed.not('negative')
  time: alias('cmo.cd')

  unconfirmed: computed.not('confirmations')

  confirmations: ( ->
    if @get('cmo.blockMature')
      (@get('account.unit.block.height') - @get('cmo.blockMature')) + 1
  ).property('account.unit.block.height', 'cmo.blockMature')

  # display in stream
  display: true
  urgent: false
)

export default TxInfo