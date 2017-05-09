`import StorageObject from 'ember-local-storage/local/object'`

STORE_VERSION = '1.0'
DEFAULT_LANGUAGE='en'

WalletState = StorageObject.extend()

WalletState.reopenClass
  VERSION: STORE_VERSION

  initialState: ->
    return {
      version: STORE_VERSION
      locale: (navigator.language || navigator.userLanguage || DEFAULT_LANGUAGE).split('-')[0]
      currency: 'EUR'
      btcUnit: 'mBTC'
      blockExplorer: null
      nnenable: false
      ianenable: false
      pushenabled: false
      telemetryEnabled: true
    }


`export default WalletState`