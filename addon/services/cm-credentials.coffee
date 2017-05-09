`import Ember from 'ember'`
`import { storageFor } from 'ember-local-storage'`

`import Melis from 'npm:melis-credentials-seed'`

`import CMCore from 'npm:melis-api-js'`

`import wordlist_IT from 'melis-cm-svcs/utils/wordlists/it'`

sjcl = CMCore.sjcl

CmCredentialsService = Ember.Service.extend(

  EXPORT_MAGIC: 'cm-exp-0.1'

  credseed: new Melis.credentials()

  credstore: storageFor('credentials-store')

  wordlists: Ember.computed.alias('credseed.wordlists')

  # never actually stored
  currentSeed: null

  deviceId: Ember.computed.alias('credstore.deviceId')
  deviceName: Ember.computed.alias('credstore.deviceName')

  encryptedGenerator: Ember.computed.alias('credstore.encryptedGenerator')
  encryptedSeed: Ember.computed.alias('credstore.encryptedSeed')

  pinAttemptsLeft:  Ember.computed.alias('credstore.pinAttemptsLeft')
  backupConfirmed:  Ember.computed.alias('credstore.backupConfirmed')
  backupChecked:  Ember.computed.alias('credstore.backupChecked')

  #
  # do we have a set of valid credentials
  #
  validCredentials: (->
    !!(@get('encryptedSeed') && @get('deviceId'))
  ).property('encryptedSeed', 'deviceId')


  reset: ->
    @get('credstore').reset()
    @setProperties
      encryptedGenerator: null
      encryptedSeed: null
      currentSeed: null
      deviceId: null
      pinAttemptsLeft: null
      backupConfirmed: false

  signinCredentials: ->
    return


  initializeCredentials: (entropy) ->
    @reset()

    language = language?.substring(0, 2).toLowerCase() || 'en'

    entropy ||= @initializeGenerator()
    seed = @entropyToSeed(entropy)

    return(seed: seed, entropy: entropy)


  storeCredentials: (creds, deviceId, key) ->
    @set('deviceId', deviceId)

    encryptedGenerator = @encryptSecret(key, creds.entropy)
    encryptedSeed = @encryptSecret(key, creds.seed)

    @set('encryptedGenerator', encryptedGenerator)
    @set('encryptedSeed', encryptedSeed)

    @checkStorage()

    ## remove before flight (leave it only in tests, as it's used to check integrity of various operations)
    @set('currentSeed', creds.seed) if (Ember.testing)


  backupGenerator: (devicePass, passphrase, language) ->
    eGen = @get('encryptedGenerator')
    deGen = @decryptSecret(devicePass, eGen)

    if passphrase
      backupGen = @encryptGenerator(deGen, passphrase)
    else
      backupGen = deGen

    mnemonic = @generateMnemonic(backupGen, language)

    return({entropy: backupGen, mnemonic: mnemonic})

  # --
  validateMnemonic: (mnemonic, language) ->
    @credseed.validateMnemonic(mnemonic, language)

  # --
  isMnemonicValid: (mnemonic) ->
    @credseed.isMnemonicValid(mnemonic)

  # --
  isGeneratorValid: (gen) ->
    @credseed.isGeneratorValid(gen)

  # --
  isGeneratorEncrypted: (gen) ->
    @credseed.isGeneratorEncrypted(gen)

  # --
  isMnemonicEncrypted: (mnemonic) ->
    @credseed.isMnemonicEncrypted(mnemonic)

  # --
  importMnemonic: (mnemonic, passphrase) ->
    @credseed.importMnemonic(mnemonic, passphrase)

  # --
  initializeGenerator: (bytes)->
    @credseed.initializeGenerator(bytes)


  exportForPairing: (devicePass, secret, identity) ->
    eGen = @get('encryptedGenerator')
    deGen = @decryptSecret(devicePass, eGen)
    adata = JSON.stringify(magic: @EXPORT_MAGIC, ident: identity)
    @encryptSecret(secret, deGen, adata)


  validatePairingData: (data) ->
    try
      pdata = JSON.parse(data)
      adata = JSON.parse(decodeURIComponent(pdata.adata))
      Ember.assert('Not a valid export', (adata.magic == @EXPORT_MAGIC))
      return true
    catch e
      Ember.assert('Parse error', false)


  importForPairing: (secret, data) ->
    @validatePairingData(data)

    gen = @decryptSecret(secret, data)
    Ember.assert('Decrypt failed', gen)

    @initializeCredentials(gen)

  # --
  generateMnemonic: (entropy, language) ->
    @credseed.generateMnemonic(entropy, language)
    #language ||= 'en'
    #Bip39.entropyToMnemonic(entropy, @wordListFor(language))


  # --
  mnemonicToEntropy: (mnemonic) ->
    @credseed.mnemonicToEntropy(mnemonic)

  # --
  entropyToSeed: (entropy) ->
    @credseed.entropyToSeed(entropy)
    #Bip39.mnemonicToSeedHex(entropy).slice(0, @SEED_SIZE)


  encryptSecret: (key, secret, adata) ->
    Ember.assert("Secret is blank!", !Ember.isBlank(secret))
    adata ||= ''
    sjcl.encrypt(key, secret, {ks: 256, mode: 'gcm', adata: adata})


  decryptSecret: (key, data, adata) ->
    sjcl.decrypt(key, data)

  # --
  encryptGenerator: (generator, key) ->
    @credseed.encryptGenerator(generator, key)


  # --
  decryptGenerator: (data, key) ->
    @credseed.decryptGenerator(data, key)

  # --
  decryptMnemonic: (data, key) ->
    @credseed.decryptMnemonic(data, key)

  # double check the storage has saved out data, and has not failed silently
  checkStorage: ->
    key = @get('credstore._storageKey')
    data = JSON.parse(localStorage.getItem(key))
    Ember.assert("Storage has failed. No data.", data)
    storedGen = Ember.get(data, 'encryptedGenerator')
    Ember.assert("Storage has failed. Data is different.", (storedGen == @get('encryptedGenerator')))

  # --
  wordListFor: (language) ->
    @credseed.wordListFor(language)

  # --
  inferWordList: (mnemonic) ->
    @credseed.inferWordList(mnemonic)
)

`export default CmCredentialsService`
