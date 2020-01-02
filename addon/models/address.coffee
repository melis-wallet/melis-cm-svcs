import { inject as service } from '@ember/service'
import { alias, notEmpty } from '@ember/object/computed'
import { A }  from '@ember/array'

import { attr, Model } from 'ember-cli-simple-store/model'

Address = Model.extend(
  cm: service('cm-session')
  coinsvc: service('cm-coin')

  account: attr()
  cmo: attr()

  active: false

  usedIn: null

  coin: alias('account.unit')

  format: 'standard'

  time: ( ->
    @get('cmo.meta.requested') || @get('cmo.lastRequested') || @get('cmo.cd')
  ).property('cmo.meta.requested', 'cmo.lastRequested', 'cmo.cd')

  addressURL: (->
    if address = @get('displayAddress')
      if address.includes(':')
        address
      else if (scheme = @get('coin.scheme'))
        ''.concat(scheme, ':', address)
      else
        address
  ).property('displayAddress', 'coin.scheme')


  displayAddress: (->
    if address = @get('cmo.address')
      @get('coinsvc').formatAddress(@get('account'), address, format: @get('format'))
  ).property('cmo.address', 'account', 'format')

  # ptx will show on the stream
  display: notEmpty('cmo.meta')

  #
  urgent: ( ->
    @get('display') && !@get('usedIn.length')
  ).property('display', 'usedIn.length')

  setup: ( ->
    @set('usedIn', A())
  ).on('init')
)

export default Address