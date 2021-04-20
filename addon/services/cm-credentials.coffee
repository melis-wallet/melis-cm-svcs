import Service, { inject as service } from '@ember/service'
import { alias, bool } from '@ember/object/computed'
import { get, set, getProperties } from '@ember/object'
import { isBlank, isNone, isEmpty } from '@ember/utils'

import { storageFor } from 'ember-local-storage'
import Melis from 'melis-credentials-seed'
import CMCore from 'melis-api-js'
import wordlist_IT from 'melis-cm-svcs/utils/wordlists/it'

import Logger from 'melis-cm-svcs/utils/logger'

sjcl = CMCore.sjcl

CmCredentialsService = Service.extend(

  EXPORT_MAGIC: 'cm-exp-0.1'

  credseed: new Melis.credentials()

  credstore: storageFor('credentials-store')

  wordlists: alias('credseed.wordlists')

  # never actually stored
  currentSeed: null

  deviceId: alias('credstore.deviceId')
  deviceName: alias('credstore.deviceName')

  encryptedGenerator: alias('credstore.encryptedGenerator')
  encryptedSeed: alias('credstore.encryptedSeed')

  pinAttemptsLeft:  alias('credstore.pinAttemptsLeft')

  backupState:  { backupConfirmed: false, backupChecked: false }

  backupConfirmed: alias('backupState.backupConfirmed')
  backupChecked: alias('backupState.backupChecked')

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
    entropy ||= @initializeGenerator()
    @prepareCredentials(entropy)


  prepareCredentials: (entropy) ->
    language = language?.substring(0, 2).toLowerCase() || 'en'

    throw('No entropy') if isBlank(entropy)
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
      Logger.error('[Credentials] Not a valid export') unless (adata.magic == @EXPORT_MAGIC)
      return true
    catch e
      Logger.error('[Credentials] Parse error', e)


  importForPairing: (secret, data) ->
    @validatePairingData(data)

    gen = @decryptSecret(secret, data)
    throw('[Credentials] Decrypt failed') unless gen

    @initializeCredentials(gen)

  # --
  generateMnemonic: (entropy, language) ->
    @credseed.generateMnemonic(entropy, language)


  # --
  mnemonicToEntropy: (mnemonic) ->
    @credseed.mnemonicToEntropy(mnemonic)

  # --
  entropyToSeed: (entropy) ->
    @credseed.entropyToSeed(entropy)


  encryptSecret: (key, secret, adata) ->
    throw("Secret is blank!") if isBlank(secret)
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
    throw("[CM Credentials] Storage has failed. No data.") unless data
    storedGen = get(data, 'encryptedGenerator')
    throw("[CM Credentials] Storage has failed. Data is different.") unless (storedGen == @get('encryptedGenerator'))

  # --
  wordListFor: (language) ->
    @credseed.wordListFor(language)

  # --
  inferWordList: (mnemonic) ->
    @credseed.inferWordList(mnemonic)
)

export default CmCredentialsService
