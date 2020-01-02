import { get, set, getProperties, getWithDefault, setProperties } from "@ember/object"


filterProperties = (source, keys...) ->
  dest = {}
  keys.forEach((k) -> dest[k] = d if !(typeof(d = get(source, k)) == 'undefined'))
  return dest

mergedProperty = (target, prop, updates) ->
  orig = getWithDefault(target, prop, {})
  setProperties(orig, updates)
  return orig

mergeProperty = (target, prop, updates) ->
  set(target, prop, mergedProperty(target, prop, updates))


export { filterProperties, mergedProperty, mergeProperty }