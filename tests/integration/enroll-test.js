
import { test, module } from 'qunit';
import { run } from '@ember/runloop';
import { isBlank, isEmpty } from '@ember/utils';
import startApp from '../helpers/start-app';
import { setupTest } from 'ember-qunit';
import Logger from 'melis-cm-svcs/utils/logger'

let application = null;
let session = null;
let creds = null;

const TESTPIN = 'Pa$$w0rd';
const BACKUP_PASSPHRASE = 's00p3rs3kr1t';
//const EXPORT_SECRET = 'an0therpa$$word';


module('Integration: enroll', function(hooks) {
  setupTest(hooks);

  hooks.beforeEach(function(assert){
    application = startApp();
    creds = this.owner.lookup('service:cm-credentials');
    session = this.owner.lookup('service:cm-session');

    creds.reset();

    const done = assert.async();
    return session.waitForConnect().then(() => done());
  });

  hooks.afterEach( function() {
    if (session.get('connected')) { session.disconnect(); }
    run(application, 'destroy');
  });


  test('ready for tests', assert => assert.equal(session.get('connected'), true));


  test('everything clean', function(assert) {
    assert.expect(4);

    assert.equal(creds.get('encryptedGenerator', 'enc entropy is empty'), null);
    assert.equal(creds.get('encryptedSeed', 'enc seed is empty'), null);
    assert.equal(creds.get('currentSeed', 'currentSeed is empty'), null);
    return assert.equal(creds.get('deviceId', 'deviceId is empty'), null);
  });


  test('[a] Normal enroll process (stateless)', function(assert) {
    assert.expect(18);

    let entropy = null;
    let deviceId = null;
    let encryptedGen = null;
    let encryptedSeed = null;
    let devicePass = null;

    // generate mnemonics
    entropy = creds.initializeGenerator();
    const mnemonic = creds.generateMnemonic(entropy);
    Logger.log("1.a - MNEMONIC: ", mnemonic);
    assert.ok(mnemonic, '[a] We have a mnemonic');

    // generate seed from mnemonics
    const seed = creds.entropyToSeed(entropy);
    Logger.log("1.a - SEED: ", seed);
    assert.ok(seed, '[a]: We have a seed');


    // First, register a wallet
    return session.walletRegister(seed)

    // check we are open, then request deviceId
    .then( function(wallet) {
      Logger.log("1.a - WALLET: ", wallet);
      assert.ok(wallet, '[a]: Got a wallet');

      const sessionWallet = session.get('currentWallet');
      assert.ok(sessionWallet, '[a]: Session has a wallet');
      Logger.log("1.a - SESSION WALLET: ", sessionWallet);

      assert.equal(isEmpty(session.get('accounts')), true, '[a]: Account is empty');

      // set password and request id
      return session.api.deviceSetPassword('testdevice', TESTPIN);
    })

    // request device password
    .then(function(res){
      Logger.log(res);

      ({
        deviceId
      } = res);
      Logger.log("1.a - DEVICEID: ", deviceId);
      assert.ok(deviceId, '[a] Got a device Id');

      return session.api.deviceGetPassword(deviceId, TESTPIN);
    })

    // encrypt the secrets
    .then(function(res) {
      devicePass = res.password;

      Logger.log("1.a - DEVICE PASSWORD: ", devicePass);
      assert.ok(devicePass, '[a] Got a device pass');

      encryptedSeed = creds.encryptSecret(devicePass, seed);

      Logger.log("1.a - ENCRYPTED SEED: ", encryptedSeed);
      assert.ok(encryptedSeed, '[a] Encrypted the seed');

      encryptedGen = creds.encryptSecret(devicePass, entropy);
      Logger.log("1.a - ENCRYPTED GENERATOR: ", encryptedGen);
      assert.ok(encryptedGen, '[a] Encrypted the entropy');

      return(encryptedSeed);
    })

    // check wallet open, close wallet
    .then( function() {
      Logger.log("1.a - WALLET: ", session.get('currentWallet'));
      assert.ok(session.get('currentWallet'), '[a] We have a valid wallet on reopen');
      return session.walletClose();
    })

    // check it closed
    .then( function(res){
      assert.equal(res.res, 'Ok', '[a] Close has succeed');
      Logger.log("1.a - CLOSE: ", res);
      return assert.equal(isBlank(session.get('currentWallet')), true, '[a] No wallet is open');
    })

    // get the device password
    .then( () => session.api.deviceGetPassword(deviceId, TESTPIN))

    // check we got a password, decrypt the seed, reopen the wallet
    .then(function(res) {
      Logger.log("devicePass", devicePass);
      Logger.log("res.password", res.password);

      assert.equal(devicePass, res.password, '[a] We got the same password');
      const decryptedSeed = creds.decryptSecret(devicePass, encryptedSeed);

      assert.equal(seed, decryptedSeed, '[a] Seed decrypts');

      return session.walletOpen(decryptedSeed, {deviceId});
    })

    // check we have opened the wallet
    .then(function(wallet) {
      Logger.log("1.a - WALLET: ", wallet);
      assert.ok(wallet, '[a] Wallet Reopens');
      return assert.ok(session.get('currentWallet'), '[a] We have a session');
    })

    // check we can retrieve the stored generator and export the secret
    .then( () => session.api.deviceGetPassword(deviceId, TESTPIN))
    // check we got a password, decrypt the seed, reopen the wallet
    .then(function(res) {

      assert.equal(devicePass, res.password, '[a] Got the devicePass again');
      const decryptedGen = creds.decryptSecret(devicePass, encryptedGen);
      return assert.equal(decryptedGen, entropy, '[a] Entropy decrypts');

    }).catch(function(err) {
      Logger.log("ERROR: ", err);
      return assert.ok(false, "[a] Should not raise errors");
    });
  });



  test('[b] Normal enroll process (with state)', function(assert) {
    assert.expect(14);

    let seed = null;

    // create wallet
    return session.enrollWallet(TESTPIN).then( (wallet) => {
      Logger.log("1.b - WALLET: ", wallet);

      // yay! we are logged in
      assert.ok(wallet, '[b] We have enrolled successfully');
      assert.ok(session.get('currentWallet'), '[b] We have a session');

      seed = creds.get('currentSeed');
      assert.ok(seed, '[b] We have a valid seed');

      const id = creds.get('deviceId');
      assert.ok(id, '[b] We got a device id');

      // try get the device password
      return session.api.deviceGetPassword(id, TESTPIN);
    })

    // decrypt the encryptedSeed, check if is the currentSeed
    .then(function(res) {

      const {
        password
      } = res;
      assert.ok(password, '[b] We got a password');

      const encryptedSeed = creds.get('encryptedSeed');
      Logger.log("1.b - ENCRYPTED SEED: ", encryptedSeed);
      assert.ok(encryptedSeed, '[b] Enroll has stored encryped seed');

      const decryptedSeed = creds.decryptSecret(res.password, encryptedSeed);
      assert.equal(seed, decryptedSeed, '[b] encryped seed decrypts to seed');
      return Logger.log("1.b - DECRYPTED SEED: ", decryptedSeed);
    })

    // check we can backup the mnemonics
    .then( function() {
      const id = creds.get('deviceId');
      return session.api.deviceGetPassword(id, TESTPIN);
    })

    // do the backup
    .then( function(res){

      const {
        password
      } = res;
      assert.ok(password, '[b] We got a password');

      const encryptedGen = creds.get('encryptedGenerator');
      Logger.log("1.b - ENCRYPTED ENTROPY: ", encryptedGen);
      assert.ok(encryptedGen, '[b] enroll has stored encrypted entropy');

      const backupMnemonics = creds.backupGenerator(res.password, BACKUP_PASSPHRASE);
      Logger.log("1.b - BACKUP MNEMONIC: ", backupMnemonics);
      assert.ok(backupMnemonics, '[b] We have backup mnemonics');

      return session.walletClose();
    })

    // check it closed
    .then( function(res){
      assert.equal(isBlank(session.get('currentWallet')), true, '[b] No current wallet');
      assert.equal(res.res, 'Ok', '[b] Session has closed');
      return Logger.log("1.b - CLOSE: ", res);
    })

    // reopen
    .then( () => session.walletReOpen(TESTPIN))

    // check we have opened the wallet
    .then(function(wallet) {
      Logger.log("1.b - WALLET: ", wallet);
      assert.ok(wallet, '[b] Wallet has reopened');
      return assert.ok(session.get('currentWallet'), '[b] We have a session');
    }).catch(function(err) {
      Logger.log("ERROR: ", err);
      return assert.ok(false, "[b] Should not raise errors");
   });
  });


  test('[c] Credentials reset', function(assert) {
    assert.expect(12);

    let seed = null;

    // create wallet
    return session.enrollWallet(TESTPIN).then( function(wallet){
      Logger.log("1.c - WALLET: ", wallet);

      // yay! we are logged in
      assert.ok(wallet, '[c] We have a wallet');
      assert.ok(session.get('currentWallet'), '[c] We have a session');

      seed = creds.get('currentSeed');
      assert.ok(seed, '[c] We have a current seed');

      const id = creds.get('deviceId');
      assert.ok(id, '[c] We have a device id');

      return session.api.deviceGetPassword(id, TESTPIN);
    })

    // do the backup
    .then( function(res){
      assert.ok(res.password, '[c] We have a device password');
      return session.walletClose();
    })
    // clear credentials, try if it worked
    .then( function(res) {

      assert.equal(isBlank(session.get('currentWallet')), true, '[c] No current wallet');
      assert.equal(res.res, 'Ok', '[c] Session has closed');

      Logger.log("1.c - CLOSE: ", res);
      creds.reset();

      assert.equal(creds.get('encryptedSeed'), null, '[c] Encrypted Seed is empty');
      assert.equal(creds.get('encryptedGenerator'), null, '[c] Encrypted Generator is empty');
      assert.equal(creds.get('currentSeed'), null, '[c] Plaintext seed is empty');
      return assert.equal(creds.get('deviceId'), null, '[c] Device Id is empty');
    })

    // reopen
    .then( () => session.walletReOpen(TESTPIN))

    // check we have opened the wallet
    .then(wallet => 
      assert.ok(false, 'Should not have reopened the wallet')
    ).catch(function(err) {
       Logger.log("1.c - ERROR: ", err);
       return assert.equal(err, 'No credentials', '[c] The proper error has occurred');
    });
  });



  test('[d] Enroll, export, import', function(assert) {
    assert.expect(11);

    let seed = null;

    let backupMnemonics = null;

    // create wallet
    return session.enrollWallet(TESTPIN).then( function(wallet){
      Logger.log("1.d - WALLET: ", wallet);

      // yay! we are logged in
      assert.ok(wallet, '[d] We have a wallet');
      assert.ok(session.get('currentWallet'), '[d] We have a session');

      seed = creds.get('currentSeed');
      assert.ok(seed, '[d] We have a current seed');

      const id = creds.get('deviceId');
      assert.ok(id, '[d] We have a device id');

      return session.api.deviceGetPassword(id, TESTPIN);
    })

    // do the backup
    .then( function(res){
      backupMnemonics = creds.backupGenerator(res.password, BACKUP_PASSPHRASE).mnemonic;
      Logger.log("1.d - BACKUP MNEMONIC: ", backupMnemonics);

      return session.walletClose();
    })
    // clear credentials, try if it worked
    .then( function(res){

      assert.equal(isBlank(session.get('currentWallet')), true, '[d] No current wallet');
      assert.equal(res.res, 'Ok', '[d] Session has closed');
      Logger.log("1.d - CLOSE: ", res);

      creds.reset();

      return session.importWallet(TESTPIN, backupMnemonics, BACKUP_PASSPHRASE);
    })

    // check we have opened the wallet
    .then(function(wallet) {
      Logger.log("1.d - WALLET: ", wallet);
      assert.ok(wallet, '[d] We have a wallet');
      assert.ok(session.get('currentWallet'), '[d] We have a session');

      const encryptedSeed = creds.get('encryptedSeed');
      Logger.log("1.b - ENCRYPTED SEED: ", encryptedSeed);
      assert.ok(encryptedSeed, '[b] Enroll has stored encryped seed');

      const encryptedGen = creds.get('encryptedGenerator');
      Logger.log("1.d - ENCRYPTED ENTROPY: ", encryptedGen);
      assert.ok(encryptedGen, '[d] enroll has stored encrypted entropy');

      const id = creds.get('deviceId');
      return assert.ok(id, '[d] We have a device id');
    }).catch(err => Logger.log("1.c - ERROR: ", err));
  });



  test('[e] Enroll, export, failed import', function(assert) {
    assert.expect(7);

    let seed = null;

    let backupMnemonics = null;

    // create wallet
    return session.enrollWallet(TESTPIN).then( function(wallet){
      Logger.log("1.e - WALLET: ", wallet);

      // yay! we are logged in
      assert.ok(wallet, '[e] We have a wallet');
      assert.ok(session.get('currentWallet'), '[e] We have a session');

      seed = creds.get('currentSeed');
      assert.ok(seed, '[e] We have a current seed');

      const id = creds.get('deviceId');
      assert.ok(id, '[e] We have a device id');

      return session.api.deviceGetPassword(id, TESTPIN);
    })

    // do the backup
    .then( function(res){
      backupMnemonics = creds.backupGenerator(res.password, BACKUP_PASSPHRASE).mnemonic;
      Logger.log("1.e - BACKUP MNEMONIC: ", backupMnemonics);

      return session.walletClose();
    })

    // clear credentials, try if it worked
    .then( function(res){

      assert.equal(isBlank(session.get('currentWallet')), true, '[e] No current wallet');
      assert.equal(res.res, 'Ok', '[e] Session has closed');
      Logger.log("1.e - CLOSE: ", res);

      creds.reset();

      return session.importWallet(TESTPIN, backupMnemonics, 'bad pass');
    })

    // check we have not opened the wallet
    .then(wallet => assert.ok(false, '[e] Should not have reopened the wallet'))

    .catch(function(err) {
       Logger.log("1.e - ERROR: ", err);
       return assert.equal(err.ex, 'CmLoginWrongSignatureException', '[e] check we have the right exception');
    });
  });


  test('[f] Enroll, plaintex export, import', function(assert) {
    assert.expect(8);

    let seed = null;

    let backupMnemonics = null;


    // create wallet
    return session.enrollWallet(TESTPIN).then( function(wallet){
      Logger.log("1.f - WALLET: ", wallet);

      // yay! we are logged in
      assert.ok(wallet, '[f] We have a wallet');
      assert.ok(session.get('currentWallet'), '[f] We have a session');

      seed = creds.get('currentSeed');
      assert.ok(seed, '[f] We have a current seed');

      const id = creds.get('deviceId');
      assert.ok(id, '[f] We have a device id');

      return session.api.deviceGetPassword(id, TESTPIN);
    })

    // do the backup
    .then( function(res){
      backupMnemonics = creds.backupGenerator(res.password).mnemonic;
      Logger.log("1.e - BACKUP MNEMONIC: ", backupMnemonics);

      return session.walletClose();
    })

    // clear credentials, try if it worked
    .then( function(res){

      assert.equal(isBlank(session.get('currentWallet')), true, '[f] No current wallet');
      assert.equal(res.res, 'Ok', '[f] Session has closed');
      Logger.log("1.f - CLOSE: ", res);

      creds.reset();

      return session.importWallet(TESTPIN, backupMnemonics, 'ignore passphrase');
    })

    // check we have opened the wallet
    .then(function(wallet) {
      Logger.log("1.f - WALLET: ", wallet);
      assert.ok(wallet, '[f] We have a wallet');
      return assert.ok(session.get('currentWallet'), '[f] We have a session');
    });
  });

  test('[g] Reopen not enrolled', function(assert) {
    assert.expect(1);


    return session.walletReOpen(TESTPIN).then( () => assert.ok(false, 'Should not succeed')).catch( err => assert.ok(true));
  });


  test('[h] Enroll, pairing import', function(assert) {
    assert.expect(9);

    let seed = null;

    let pairingData = null;


    // create wallet
    return session.enrollWallet(TESTPIN).then( function(wallet){
      Logger.log("1.f - WALLET: ", wallet);

      // yay! we are logged in
      assert.ok(wallet, '[f] We have a wallet');
      assert.ok(session.get('currentWallet'), '[f] We have a session');

      seed = creds.get('currentSeed');
      assert.ok(seed, '[f] We have a current seed');

      const id = creds.get('deviceId');
      assert.ok(id, '[f] We have a device id');

      return session.api.deviceGetPassword(id, TESTPIN);
    })

    // do the pairing export
    .then( res => session.exportForPairing(TESTPIN, 'test device')).then( function(data) {
      pairingData = data.secret;
      Logger.log("1.h - PAIRING DATA: ", pairingData);

      return session.walletClose();
    })

    // clear credentials, try if it worked
    .then( function(res){

      assert.equal(isBlank(session.get('currentWallet')), true, '[f] No current wallet');
      assert.equal(res.res, 'Ok', '[f] Session has closed');
      Logger.log("1.f - CLOSE: ", res);

      creds.reset();
      assert.equal(creds.get('validCredentials'), false);
      return session.importForPairing(pairingData, TESTPIN);
    })

    // check we have opened the wallet
    .then(function(wallet) {
      Logger.log("1.f - WALLET: ", wallet);
      assert.ok(wallet, '[f] We have a wallet');
      return assert.ok(session.get('currentWallet'), '[f] We have a session');
    }).catch( err => Logger.error(err));
  });


  test('[i] Enroll, plaintex export, import (alternate language)', function(assert) {
    assert.expect(10);

    let seed = null;
    const language = 'it';

    let backupMnemonics = null;


    // create wallet
    return session.enrollWallet(TESTPIN).then( function(wallet){
      Logger.log("1.i - WALLET: ", wallet);

      // yay! we are logged in
      assert.ok(wallet, '[i] We have a wallet');
      assert.ok(session.get('currentWallet'), '[f] We have a session');

      seed = creds.get('currentSeed');
      assert.ok(seed, '[i] We have a current seed');

      const id = creds.get('deviceId');
      assert.ok(id, '[i] We have a device id');

      return session.api.deviceGetPassword(id, TESTPIN);
    })

    // do the backup
    .then( function(res){
      backupMnemonics = creds.backupGenerator(res.password, null, language).mnemonic;
      Logger.log("1.i - BACKUP MNEMONIC: ", backupMnemonics);

      res = creds.validateMnemonic(backupMnemonics);
      assert.ok(res.valid);
      assert.equal(res.language, language);

      return session.walletClose();
    })

    // clear credentials, try if it worked
    .then( function(res){

      assert.equal(isBlank(session.get('currentWallet')), true, '[f] No current wallet');
      assert.equal(res.res, 'Ok', '[i] Session has closed');
      Logger.log("1.i - CLOSE: ", res);

      creds.reset();

      return session.importWallet(TESTPIN, backupMnemonics, 'ignore passphrase');
    })

    // check we have opened the wallet
    .then(function(wallet) {
      Logger.log("1.f - WALLET: ", wallet);
      assert.ok(wallet, '[f] We have a wallet');
      return assert.ok(session.get('currentWallet'), '[f] We have a session');
    }).catch( err => Logger.log("1.f - ERROR: ", err));
  });



  return test('[l] Enroll, export, import (alternate language)', function(assert) {
    assert.expect(13);

    let seed = null;
    const language = 'it';

    let backupMnemonics = null;

    // create wallet
    return session.enrollWallet(TESTPIN).then( function(wallet){
      Logger.log("1.l - WALLET: ", wallet);

      // yay! we are logged in
      assert.ok(wallet, '[l] We have a wallet');
      assert.ok(session.get('currentWallet'), '[d] We have a session');

      seed = creds.get('currentSeed');
      assert.ok(seed, '[l] We have a current seed');

      const id = creds.get('deviceId');
      assert.ok(id, '[l] We have a device id');

      return session.api.deviceGetPassword(id, TESTPIN);
    })

    // do the backup
    .then( function(res){
      backupMnemonics = creds.backupGenerator(res.password, BACKUP_PASSPHRASE, language).mnemonic;
      Logger.log("1.l - BACKUP MNEMONIC: ", backupMnemonics);

      res = creds.validateMnemonic(backupMnemonics);
      assert.ok(res.valid);
      assert.equal(res.language, language);

      return session.walletClose();
    })
    // clear credentials, try if it worked
    .then( function(res){

      assert.equal(isBlank(session.get('currentWallet')), true, '[d] No current wallet');
      assert.equal(res.res, 'Ok', '[d] Session has closed');
      Logger.log("1.l - CLOSE: ", res);

      creds.reset();

      return session.importWallet(TESTPIN, backupMnemonics, BACKUP_PASSPHRASE);
    })

    // check we have opened the wallet
    .then(function(wallet) {
      Logger.log("1.l - WALLET: ", wallet);
      assert.ok(wallet, '[d] We have a wallet');
      assert.ok(session.get('currentWallet'), '[d] We have a session');

      const encryptedSeed = creds.get('encryptedSeed');
      Logger.log("1.l - ENCRYPTED SEED: ", encryptedSeed);
      assert.ok(encryptedSeed, '[b] Enroll has stored encryped seed');

      const encryptedGen = creds.get('encryptedGenerator');
      Logger.log("1.l - ENCRYPTED ENTROPY: ", encryptedGen);
      assert.ok(encryptedGen, '[d] enroll has stored encrypted entropy');

      const id = creds.get('deviceId');
      return assert.ok(id, '[l] We have a device id');
    }).catch(err => Logger.log("1.l - ERROR: ", err));
});

});