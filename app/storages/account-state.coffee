`import StorageObject from 'ember-local-storage/local/object'`

STORE_VERSION = '1.0'

AccountState = StorageObject.extend()

AccountState.reopenClass
  VERSION: STORE_VERSION

  initialState: ->
    return {
      version: STORE_VERSION
      invisible: false
    }

  # destroy this entry
  destroy: ->
    this._clear();
    @_clear();
    @_storage().removeItem([get(this, '_storageKey')])

`export default AccountState`