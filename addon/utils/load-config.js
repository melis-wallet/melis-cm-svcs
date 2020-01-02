import EmberObject from '@ember/object'
import { typeOf } from '@ember/utils'

export default function(defaults, callback) {
  return function(container, config) {
    var wrappedConfig = EmberObject.create(config);
    for (var property in this) {
      if (this.hasOwnProperty(property) && typeOf(this[property]) !== 'function') {
        this[property] = wrappedConfig.getWithDefault(property, defaults[property]);
      }
    }
    if (callback) {
      callback.apply(this, [container, config]);
    }
  };
}