`import Ember from 'ember'`
`import getOwner from "ember-getowner-polyfill"`

SimpleModelFactory = Ember.Mixin.create

  createSimpleModel: (type, data) ->
    containerKey = "model:" + type
    factory = getOwner(this).factoryFor(containerKey)
    Ember.assert("No model was found for type: " + type, factory)
    record = factory.create(data)

`export default SimpleModelFactory`