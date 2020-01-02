import Mixin from '@ember/object/mixin'
import { getOwner } from '@ember/application'
import { assert } from '@ember/debug'

SimpleModelFactory = Mixin.create

  createSimpleModel: (type, data) ->
    containerKey = "model:" + type
    factory = getOwner(this).factoryFor(containerKey)
    assert("No model was found for type: " + type, factory)
    record = factory.create(data)

export default SimpleModelFactory