import { computed } from "@ember/object"
import { isNone } from "@ember/utils"

import { attr, Model } from 'ember-cli-simple-store/model'
import CMCore from 'npm:melis-api-js'

C = CMCore.C


AbEntry = Model.extend(

  type: attr()

  val: attr()
  labels: attr()
  meta: attr()
  coin: attr()

  avatarUrl: null

  identifier: ( ->
    (@get('name') || '?').charAt(0).toUpperCase()
  ).property('name')

  isAddress: computed.equal('type', C.AB_TYPE_ADDRESS)
  isCm: computed.equal('type', C.AB_TYPE_MELIS)

  address: computed('val',
    get: (key) ->
      if @get('isAddress')
        @get 'val'
    set: (key, value) ->
      if @get('isAddress')
        @set 'val', value
  )

  pubId: computed('val',
    get: (key) ->
      @get 'val' if @get('isCm')
    set: (key, value) ->
      @set 'val', value if @get('isCm')

  )

  name: computed('meta',
    get: (key) ->
      @get('meta.name')

    set: (key, value) ->
      @set('meta', {}) if isNone(@get('meta'))
      @set 'meta.name', value
      value
  )

  alias: computed('meta',
    get: (key) ->
      @get('meta.alias')

    set: (key, value) ->
      @set('meta', {}) if isNone(@get('meta'))
      @set 'meta.alias', value
      value
  )

  serialized: ( -> @getProperties('id', 'type', 'labels', 'meta', 'val', 'coin')).property().volatile()


)

export default AbEntry