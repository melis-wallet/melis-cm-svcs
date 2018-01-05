import StorageObject from 'ember-local-storage/local/object'

STORE_VERSION = '1.1'

CredentialsStore = StorageObject.extend()

CredentialsStore.reopenClass
  VERSION: STORE_VERSION

  initialState: ->
    return {
      deviceId: null
      deviceName: 'My Wallet'
      encryptedSeed: null
      encryptedGenerator: null
      pinAttemptsLeft: null
      version: STORE_VERSION
    }

export default CredentialsStore