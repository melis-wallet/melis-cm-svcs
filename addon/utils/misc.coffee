import Ember from 'ember'


filterProperties = (source, keys...) ->
  dest = {}
  keys.forEach((k) -> dest[k] = d if !(typeof(d = Ember.get(source, k)) == 'undefined'))
  return dest

mergedProperty = (target, prop, updates) ->
  orig = Ember.getWithDefault(target, prop, {})
  Ember.setProperties(orig, updates)
  return orig

mergeProperty = (target, prop, updates) ->
  Ember.set(target, prop, mergedProperty(target, prop, updates))


export { filterProperties, mergedProperty, mergeProperty }