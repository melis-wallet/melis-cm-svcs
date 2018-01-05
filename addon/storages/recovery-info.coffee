import StorageObject from 'ember-local-storage/local/object'

STORE_VERSION = '1.0'

RecoveryInfo = StorageObject.extend()

RecoveryInfo.reopenClass
  VERSION: STORE_VERSION

  initialState: ->
    return {
      version: STORE_VERSION
      current: null
    }

  # destroy this entry
  destroy: ->
    this._clear();
    @_clear();
    @_storage().removeItem([get(this, '_storageKey')])

export default RecoveryInfo