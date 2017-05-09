`import { attr, Model } from 'ember-cli-simple-store/model'`
`import CMCore from 'npm:melis-api-js'`

C = CMCore.C

Event = Model.extend(

  type: attr()
  account: attr()
  cmo: attr()
  time: attr()

  isGlobal: ( ->
    Ember.isBlank(@get('account'))
  ).property('account')

  data: (->

    if @get('type') == C.EVENT_JOINED
      return(
        identifier: @get('cmo.activationCode.name')
        date: @get('cmo.activationCode.activationDate')
      )
    else
      {}
  ).property('cmo')

  display: true
  urgent: false
)

`export default Event`