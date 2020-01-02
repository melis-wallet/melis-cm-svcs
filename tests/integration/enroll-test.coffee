import { test, moduleFor, module } from 'qunit'
import { run } from '@ember/runloop'
import { isBlank, isNone, isEmpty, isEqual } from '@ember/utils'
import startApp from '../helpers/start-app'
import { setupTest } from 'ember-qunit'

import CmSession from 'melis-cm-svcs/services/cm-session'
import CmCredentialsService from 'melis-cm-svcs/services/cm-credentials'


application = null
session = null
creds = null

TESTPIN = 'Pa$$w0rd'
BACKUP_PASSPHRASE = 's00p3rs3kr1t'
EXPORT_SECRET = 'an0therpa$$word'


module('Integration: enroll', (hooks) ->
  setupTest(hooks)

  hooks.beforeEach((assert)->
    application = startApp()
    creds = @owner.lookup('service:cm-credentials')
    session = @owner.lookup('service:cm-session')

    creds.reset()

    done = assert.async()
    session.waitForConnect().then ->
      done()
  )

  hooks.afterEach( ->
    session.disconnect() if session.get('connected')
    run(application, 'destroy')
  )


  test 'ready for tests', (assert) ->
    assert.equal session.get('connected'), true


  test 'everything clean', (assert) ->
    assert.expect(4)

    assert.equal creds.get('encryptedGenerator', 'enc entropy is empty'), null
    assert.equal creds.get('encryptedSeed', 'enc seed is empty'), null
    assert.equal creds.get('currentSeed', 'currentSeed is empty'), null
    assert.equal creds.get('deviceId', 'deviceId is empty'), null


  test '[a] Normal enroll process (stateless)', (assert) ->
    assert.expect(18)

    entropy = null
    deviceId = null
    encryptedGen = null
    encryptedSeed = null
    devicePass = null
    wallet = null

    # generate mnemonics
    entropy = creds.initializeGenerator()
    mnemonic = creds.generateMnemonic(entropy)
    console.log("1.a - MNEMONIC: ", mnemonic)
    assert.ok(mnemonic, '[a] We have a mnemonic')

    # generate seed from mnemonics
    seed = creds.entropyToSeed(entropy)
    console.log("1.a - SEED: ", seed)
    assert.ok(seed, '[a]: We have a seed')


    # First, register a wallet
    session.walletRegister(seed)

    # check we are open, then request deviceId
    .then( (wallet) ->
      console.log "1.a - WALLET: ", wallet
      assert.ok(wallet, '[a]: Got a wallet')

      sessionWallet = session.get('currentWallet')
      assert.ok(sessionWallet, '[a]: Session has a wallet')
      console.log "1.a - SESSION WALLET: ", sessionWallet

      assert.equal(isEmpty(session.get('accounts')), true, '[a]: Account is empty')

      # set password and request id
      session.api.deviceSetPassword('testdevice', TESTPIN)
    )

    # request device password
    .then((res)->
      console.log res

      deviceId = res.deviceId
      console.log "1.a - DEVICEID: ", deviceId
      assert.ok(deviceId, '[a] Got a device Id')

      session.api.deviceGetPassword(deviceId, TESTPIN)
    )

    # encrypt the secrets
    .then((res) ->
      devicePass = res.password

      console.log "1.a - DEVICE PASSWORD: ", devicePass
      assert.ok(devicePass, '[a] Got a device pass')

      encryptedSeed = creds.encryptSecret(devicePass, seed)

      console.log "1.a - ENCRYPTED SEED: ", encryptedSeed
      assert.ok(encryptedSeed, '[a] Encrypted the seed')

      encryptedGen = creds.encryptSecret(devicePass, entropy)
      console.log "1.a - ENCRYPTED GENERATOR: ", encryptedGen
      assert.ok(encryptedGen, '[a] Encrypted the entropy')

      return(encryptedSeed)
    )

    # check wallet open, close wallet
    .then( ->
      console.log "1.a - WALLET: ", session.get('currentWallet')
      assert.ok(session.get('currentWallet'), '[a] We have a valid wallet on reopen')
      session.walletClose()
    )

    # check it closed
    .then( (res)->
      assert.equal(res.res, 'Ok', '[a] Close has succeed')
      console.log "1.a - CLOSE: ", res
      assert.equal(isBlank(session.get('currentWallet')), true, '[a] No wallet is open')
    )

    # get the device password
    .then( ->
      session.api.deviceGetPassword(deviceId, TESTPIN)
    )

    # check we got a password, decrypt the seed, reopen the wallet
    .then((res) ->
      console.log "devicePass", devicePass
      console.log "res.password", res.password

      assert.equal(devicePass, res.password, '[a] We got the same password')
      decryptedSeed = creds.decryptSecret(devicePass, encryptedSeed)

      assert.equal(seed, decryptedSeed, '[a] Seed decrypts')

      session.walletOpen(decryptedSeed, {deviceId: deviceId})
    )

    # check we have opened the wallet
    .then((wallet) ->
      console.log "1.a - WALLET: ", wallet
      assert.ok(wallet, '[a] Wallet Reopens')
      assert.ok(session.get('currentWallet'), '[a] We have a session')
    )

    # check we can retrieve the stored generator and export the secret
    .then( ->
      session.api.deviceGetPassword(deviceId, TESTPIN)
    )
    # check we got a password, decrypt the seed, reopen the wallet
    .then((res) ->

      assert.equal(devicePass, res.password, '[a] Got the devicePass again')
      decryptedGen = creds.decryptSecret(devicePass, encryptedGen)
      assert.equal(decryptedGen, entropy, '[a] Entropy decrypts')

    ).catch((err) ->
      console.log "ERROR: ", err
      assert.ok(false, "[a] Should not raise errors")
    )



  test '[b] Normal enroll process (with state)', (assert) ->
    assert.expect(14)

    seed = null

    # create wallet
    session.enrollWallet(TESTPIN).then( (wallet)->
      console.log "1.b - WALLET: ", wallet

      # yay! we are logged in
      assert.ok(wallet, '[b] We have enrolled successfully')
      assert.ok(session.get('currentWallet'), '[b] We have a session')

      seed = creds.get('currentSeed')
      assert.ok(seed, '[b] We have a valid seed')

      id = creds.get('deviceId')
      assert.ok(id, '[b] We got a device id')

      # try get the device password
      session.api.deviceGetPassword(id, TESTPIN)
    )

    # decrypt the encryptedSeed, check if is the currentSeed
    .then((res) ->

      password = res.password
      assert.ok(password, '[b] We got a password')

      encryptedSeed = creds.get('encryptedSeed')
      console.log "1.b - ENCRYPTED SEED: ", encryptedSeed
      assert.ok(encryptedSeed, '[b] Enroll has stored encryped seed')

      decryptedSeed = creds.decryptSecret(res.password, encryptedSeed)
      assert.equal(seed, decryptedSeed, '[b] encryped seed decrypts to seed')
      console.log "1.b - DECRYPTED SEED: ", decryptedSeed
    )

    # check we can backup the mnemonics
    .then( ->
      id = creds.get('deviceId')
      session.api.deviceGetPassword(id, TESTPIN)
    )

    # do the backup
    .then( (res)->

      password = res.password
      assert.ok(password, '[b] We got a password')

      encryptedGen = creds.get('encryptedGenerator')
      console.log "1.b - ENCRYPTED ENTROPY: ", encryptedGen
      assert.ok(encryptedGen, '[b] enroll has stored encrypted entropy')

      backupMnemonics = creds.backupGenerator(res.password, BACKUP_PASSPHRASE)
      console.log "1.b - BACKUP MNEMONIC: ", backupMnemonics
      assert.ok(backupMnemonics, '[b] We have backup mnemonics')

      session.walletClose()
    )

    # check it closed
    .then( (res)->
      assert.equal(isBlank(session.get('currentWallet')), true, '[b] No current wallet')
      assert.equal(res.res, 'Ok', '[b] Session has closed')
      console.log "1.b - CLOSE: ", res
    )

    # reopen
    .then( ->
      session.walletReOpen(TESTPIN)
    )

    # check we have opened the wallet
    .then((wallet) ->
      console.log "1.b - WALLET: ", wallet
      assert.ok(wallet, '[b] Wallet has reopened')
      assert.ok(session.get('currentWallet'), '[b] We have a session')
    ).catch((err) ->
      console.log "ERROR: ", err
      assert.ok(false, "[b] Should not raise errors")
    )


  test '[c] Credentials reset', (assert) ->
    assert.expect(12)

    seed = null

    # create wallet
    session.enrollWallet(TESTPIN).then( (wallet)->
      console.log "1.c - WALLET: ", wallet

      # yay! we are logged in
      assert.ok(wallet, '[c] We have a wallet')
      assert.ok(session.get('currentWallet'), '[c] We have a session')

      seed = creds.get('currentSeed')
      assert.ok(seed, '[c] We have a current seed')

      id = creds.get('deviceId')
      assert.ok(id, '[c] We have a device id')

      session.api.deviceGetPassword(id, TESTPIN)
    )

    # do the backup
    .then( (res)->
      assert.ok(res.password, '[c] We have a device password')
      session.walletClose()
    )
    # clear credentials, try if it worked
    .then( (res) ->

      assert.equal(isBlank(session.get('currentWallet')), true, '[c] No current wallet')
      assert.equal(res.res, 'Ok', '[c] Session has closed')

      console.log "1.c - CLOSE: ", res
      creds.reset()

      assert.equal(creds.get('encryptedSeed'), null, '[c] Encrypted Seed is empty')
      assert.equal(creds.get('encryptedGenerator'), null, '[c] Encrypted Generator is empty')
      assert.equal(creds.get('currentSeed'), null, '[c] Plaintext seed is empty')
      assert.equal(creds.get('deviceId'), null, '[c] Device Id is empty')
    )

    # reopen
    .then( ->
      session.walletReOpen(TESTPIN)
    )

    # check we have opened the wallet
    .then((wallet) ->
      assert.ok(false, 'Should not have reopened the wallet')
    )
    .catch((err) ->
       console.log "1.c - ERROR: ", err
       assert.equal(err, 'No credentials', '[c] The proper error has occurred')
    )



  test '[d] Enroll, export, import', (assert) ->
    assert.expect(11)

    seed = null

    backupMnemonics = null

    # create wallet
    session.enrollWallet(TESTPIN).then( (wallet)->
      console.log "1.d - WALLET: ", wallet

      # yay! we are logged in
      assert.ok(wallet, '[d] We have a wallet')
      assert.ok(session.get('currentWallet'), '[d] We have a session')

      seed = creds.get('currentSeed')
      assert.ok(seed, '[d] We have a current seed')

      id = creds.get('deviceId')
      assert.ok(id, '[d] We have a device id')

      session.api.deviceGetPassword(id, TESTPIN)
    )

    # do the backup
    .then( (res)->
      backupMnemonics = creds.backupGenerator(res.password, BACKUP_PASSPHRASE).mnemonic
      console.log "1.d - BACKUP MNEMONIC: ", backupMnemonics

      session.walletClose()
    )
    # clear credentials, try if it worked
    .then( (res)->

      assert.equal(isBlank(session.get('currentWallet')), true, '[d] No current wallet')
      assert.equal(res.res, 'Ok', '[d] Session has closed')
      console.log "1.d - CLOSE: ", res

      creds.reset()

      session.importWallet(TESTPIN, backupMnemonics, BACKUP_PASSPHRASE)
    )

    # check we have opened the wallet
    .then((wallet) ->
      console.log "1.d - WALLET: ", wallet
      assert.ok(wallet, '[d] We have a wallet')
      assert.ok(session.get('currentWallet'), '[d] We have a session')

      encryptedSeed = creds.get('encryptedSeed')
      console.log "1.b - ENCRYPTED SEED: ", encryptedSeed
      assert.ok(encryptedSeed, '[b] Enroll has stored encryped seed')

      encryptedGen = creds.get('encryptedGenerator')
      console.log "1.d - ENCRYPTED ENTROPY: ", encryptedGen
      assert.ok(encryptedGen, '[d] enroll has stored encrypted entropy')

      id = creds.get('deviceId')
      assert.ok(id, '[d] We have a device id')
    ).catch((err) ->
      console.log "1.c - ERROR: ", err
    )



  test '[e] Enroll, export, failed import', (assert) ->
    assert.expect(7)

    seed = null

    backupMnemonics = null

    # create wallet
    session.enrollWallet(TESTPIN).then( (wallet)->
      console.log "1.e - WALLET: ", wallet

      # yay! we are logged in
      assert.ok(wallet, '[e] We have a wallet')
      assert.ok(session.get('currentWallet'), '[e] We have a session')

      seed = creds.get('currentSeed')
      assert.ok(seed, '[e] We have a current seed')

      id = creds.get('deviceId')
      assert.ok(id, '[e] We have a device id')

      session.api.deviceGetPassword(id, TESTPIN)
    )

    # do the backup
    .then( (res)->
      backupMnemonics = creds.backupGenerator(res.password, BACKUP_PASSPHRASE).mnemonic
      console.log "1.e - BACKUP MNEMONIC: ", backupMnemonics

      session.walletClose()
    )

    # clear credentials, try if it worked
    .then( (res)->

      assert.equal(isBlank(session.get('currentWallet')), true, '[e] No current wallet')
      assert.equal(res.res, 'Ok', '[e] Session has closed')
      console.log "1.e - CLOSE: ", res

      creds.reset()

      session.importWallet(TESTPIN, backupMnemonics, 'bad pass')
    )

    # check we have not opened the wallet
    .then((wallet) ->
      assert.ok(false, '[e] Should not have reopened the wallet')
    )

    .catch((err) ->
       console.log "1.e - ERROR: ", err
       assert.equal(err.ex, 'CmLoginWrongSignatureException', '[e] check we have the right exception')
    )


  test '[f] Enroll, plaintex export, import', (assert) ->
    assert.expect(8)

    seed = null

    backupMnemonics = null


    # create wallet
    session.enrollWallet(TESTPIN).then( (wallet)->
      console.log "1.f - WALLET: ", wallet

      # yay! we are logged in
      assert.ok(wallet, '[f] We have a wallet')
      assert.ok(session.get('currentWallet'), '[f] We have a session')

      seed = creds.get('currentSeed')
      assert.ok(seed, '[f] We have a current seed')

      id = creds.get('deviceId')
      assert.ok(id, '[f] We have a device id')

      session.api.deviceGetPassword(id, TESTPIN)
    )

    # do the backup
    .then( (res)->
      backupMnemonics = creds.backupGenerator(res.password).mnemonic
      console.log "1.e - BACKUP MNEMONIC: ", backupMnemonics

      session.walletClose()
    )

    # clear credentials, try if it worked
    .then( (res)->

      assert.equal(isBlank(session.get('currentWallet')), true, '[f] No current wallet')
      assert.equal(res.res, 'Ok', '[f] Session has closed')
      console.log "1.f - CLOSE: ", res

      creds.reset()

      session.importWallet(TESTPIN, backupMnemonics, 'ignore passphrase')
    )

    # check we have opened the wallet
    .then((wallet) ->
      console.log "1.f - WALLET: ", wallet
      assert.ok(wallet, '[f] We have a wallet')
      assert.ok(session.get('currentWallet'), '[f] We have a session')
    )

  test '[g] Reopen not enrolled', (assert) ->
    assert.expect(1)


    session.walletReOpen(TESTPIN).then( ->
      assert.ok(false, 'Should not succeed')
    ).catch( (err)->
      assert.ok(true)
    )


  test '[h] Enroll, pairing import', (assert) ->
    assert.expect(9)

    seed = null

    pairingData = null


    # create wallet
    session.enrollWallet(TESTPIN).then( (wallet)->
      console.log "1.f - WALLET: ", wallet

      # yay! we are logged in
      assert.ok(wallet, '[f] We have a wallet')
      assert.ok(session.get('currentWallet'), '[f] We have a session')

      seed = creds.get('currentSeed')
      assert.ok(seed, '[f] We have a current seed')

      id = creds.get('deviceId')
      assert.ok(id, '[f] We have a device id')

      session.api.deviceGetPassword(id, TESTPIN)
    )

    # do the pairing export
    .then( (res)->
      session.exportForPairing(TESTPIN, 'test device')

    ).then( (data) ->
      pairingData = data.secret
      console.log "1.h - PAIRING DATA: ", pairingData

      session.walletClose()
    )

    # clear credentials, try if it worked
    .then( (res)->

      assert.equal(isBlank(session.get('currentWallet')), true, '[f] No current wallet')
      assert.equal(res.res, 'Ok', '[f] Session has closed')
      console.log "1.f - CLOSE: ", res

      creds.reset()
      assert.equal(creds.get('validCredentials'), false)
      session.importForPairing(pairingData, TESTPIN)
    )

    # check we have opened the wallet
    .then((wallet) ->
      console.log "1.f - WALLET: ", wallet
      assert.ok(wallet, '[f] We have a wallet')
      assert.ok(session.get('currentWallet'), '[f] We have a session')
    ).catch( (err)->
      console.error err
    )


  test '[i] Enroll, plaintex export, import (alternate language)', (assert) ->
    assert.expect(10)

    seed = null
    language = 'it'

    backupMnemonics = null


    # create wallet
    session.enrollWallet(TESTPIN).then( (wallet)->
      console.log "1.i - WALLET: ", wallet

      # yay! we are logged in
      assert.ok(wallet, '[i] We have a wallet')
      assert.ok(session.get('currentWallet'), '[f] We have a session')

      seed = creds.get('currentSeed')
      assert.ok(seed, '[i] We have a current seed')

      id = creds.get('deviceId')
      assert.ok(id, '[i] We have a device id')

      session.api.deviceGetPassword(id, TESTPIN)
    )

    # do the backup
    .then( (res)->
      backupMnemonics = creds.backupGenerator(res.password, null, language).mnemonic
      console.log "1.i - BACKUP MNEMONIC: ", backupMnemonics

      res = creds.validateMnemonic(backupMnemonics)
      assert.ok(res.valid)
      assert.equal(res.language, language)

      session.walletClose()
    )

    # clear credentials, try if it worked
    .then( (res)->

      assert.equal(isBlank(session.get('currentWallet')), true, '[f] No current wallet')
      assert.equal(res.res, 'Ok', '[i] Session has closed')
      console.log "1.i - CLOSE: ", res

      creds.reset()

      session.importWallet(TESTPIN, backupMnemonics, 'ignore passphrase')
    )

    # check we have opened the wallet
    .then((wallet) ->
      console.log "1.f - WALLET: ", wallet
      assert.ok(wallet, '[f] We have a wallet')
      assert.ok(session.get('currentWallet'), '[f] We have a session')
    ).catch( (err)->
      console.log "1.f - ERROR: ", err
    )



  test '[l] Enroll, export, import (alternate language)', (assert) ->
    assert.expect(13)

    seed = null
    language = 'it'

    backupMnemonics = null

    # create wallet
    session.enrollWallet(TESTPIN).then( (wallet)->
      console.log "1.l - WALLET: ", wallet

      # yay! we are logged in
      assert.ok(wallet, '[l] We have a wallet')
      assert.ok(session.get('currentWallet'), '[d] We have a session')

      seed = creds.get('currentSeed')
      assert.ok(seed, '[l] We have a current seed')

      id = creds.get('deviceId')
      assert.ok(id, '[l] We have a device id')

      session.api.deviceGetPassword(id, TESTPIN)
    )

    # do the backup
    .then( (res)->
      backupMnemonics = creds.backupGenerator(res.password, BACKUP_PASSPHRASE, language).mnemonic
      console.log "1.l - BACKUP MNEMONIC: ", backupMnemonics

      res = creds.validateMnemonic(backupMnemonics)
      assert.ok(res.valid)
      assert.equal(res.language, language)

      session.walletClose()
    )
    # clear credentials, try if it worked
    .then( (res)->

      assert.equal(isBlank(session.get('currentWallet')), true, '[d] No current wallet')
      assert.equal(res.res, 'Ok', '[d] Session has closed')
      console.log "1.l - CLOSE: ", res

      creds.reset()

      session.importWallet(TESTPIN, backupMnemonics, BACKUP_PASSPHRASE)
    )

    # check we have opened the wallet
    .then((wallet) ->
      console.log "1.l - WALLET: ", wallet
      assert.ok(wallet, '[d] We have a wallet')
      assert.ok(session.get('currentWallet'), '[d] We have a session')

      encryptedSeed = creds.get('encryptedSeed')
      console.log "1.l - ENCRYPTED SEED: ", encryptedSeed
      assert.ok(encryptedSeed, '[b] Enroll has stored encryped seed')

      encryptedGen = creds.get('encryptedGenerator')
      console.log "1.l - ENCRYPTED ENTROPY: ", encryptedGen
      assert.ok(encryptedGen, '[d] enroll has stored encrypted entropy')

      id = creds.get('deviceId')
      assert.ok(id, '[l] We have a device id')
    ).catch((err) ->
      console.log "1.l - ERROR: ", err
    )

)