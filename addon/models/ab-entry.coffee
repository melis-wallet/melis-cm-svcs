`import { attr, Model } from 'ember-cli-simple-store/model'`
`import CMCore from 'npm:melis-api-js'`

C = CMCore.C


AbEntry = Model.extend(

  type: attr()

  val: attr()
  labels: attr()
  meta: attr()

  avatarUrl: null

  identifier: ( ->
    (@get('name') || '?').charAt(0).toUpperCase()
  ).property('name')

  isAddress: Ember.computed.equal('type', C.AB_TYPE_ADDRESS)
  isCm: Ember.computed.equal('type', C.AB_TYPE_CM)

  address: Ember.computed('val',
    get: (key) ->
      if @get('isAddress')
        @get 'val'
    set: (key, value) ->
      if @get('isAddress')
        @set 'val', value
  )

  pubId: Ember.computed('val',
    get: (key) ->
      if @get('isCm')
        @get 'val'
    set: (key, value) ->
      if @get('isCm')
        @set 'val', value
  )

  name: Ember.computed('meta',
    get: (key) ->
      @get('meta.name')

    set: (key, value) ->
      @set('meta', {}) if Ember.isNone(@get('meta'))
      @set 'meta.name', value
      value
  )

  alias: Ember.computed('meta',
    get: (key) ->
      @get('meta.alias')

    set: (key, value) ->
      @set('meta', {}) if Ember.isNone(@get('meta'))
      @set 'meta.alias', value
      value
  )

  serialized: ( ->
    @getProperties('id', 'type', 'label', 'meta', 'val')
  ).property().volatile()


)

`export default AbEntry`