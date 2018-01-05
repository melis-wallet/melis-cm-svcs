import Ember from 'ember'

SimpleModelFactory = Ember.Mixin.create

  createSimpleModel: (type, data) ->
    containerKey = "model:" + type
    factory = Ember.getOwner(this).factoryFor(containerKey)
    Ember.assert("No model was found for type: " + type, factory)
    record = factory.create(data)

export default SimpleModelFactory