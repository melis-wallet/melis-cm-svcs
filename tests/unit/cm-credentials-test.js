
import { test, module } from 'ember-qunit';
import { setupTest } from 'ember-qunit';
import CMCore from 'melis-api-js';
import Logger from 'melis-cm-svcs/utils/logger'

const {
  Buffer
} = CMCore;


let api, creds;

module('Unit: cm-credentials: basics', function(hooks) {
  setupTest(hooks);

  hooks.beforeEach(function(assert) {
    
    creds = this.owner.lookup('service:cm-credentials');

    return api = new CMCore();
  });


  //hooks.afterEach: ->
  //   return

  test('we have a session', (assert)  => {
    assert.ok(creds, 'We have a session');
  });


  test('generating mnemonics from entropy', (assert) => {
    assert.expect(5);


    const entropy = creds.initializeGenerator(32);
    const mnemonic = creds.generateMnemonic(entropy);
    Logger.log('+ mnemonic: ', mnemonic);
    assert.ok(mnemonic);


    const res = creds.validateMnemonic(mnemonic);
    assert.ok(res.valid);
    assert.equal(res.language, 'en');

    const output = creds.mnemonicToEntropy(mnemonic);
    assert.ok(output);
    assert.equal(output.entropy, entropy);
  });


  test('generating mnemonics from entropy, (alternate language)', (assert) => {
    assert.expect(6);

    const language = 'it';

    const entropy = creds.initializeGenerator(32);
    const mnemonic = creds.generateMnemonic(entropy, language);
    Logger.log('+ mnemonic: ', mnemonic);
    assert.ok(mnemonic);

    let res = creds.validateMnemonic(mnemonic, language);
    assert.ok(res.valid);

    res = creds.validateMnemonic(mnemonic);
    assert.ok(res.valid);
    assert.equal(res.language, language);

    const output = creds.mnemonicToEntropy(mnemonic);
    assert.ok(output);
    assert.equal(output.entropy, entropy);
  });



  test('generate a seed from entropy', (assert) => {
    assert.expect(4);

    const entropy = creds.initializeGenerator();
    const mnemonic = creds.generateMnemonic(entropy);
    assert.ok(mnemonic);
    const seed = creds.entropyToSeed(entropy);
    Logger.log('+ seed: ', seed);

    assert.ok(seed);
    assert.equal(creds.credseed.SEED_SIZE, seed.length);

    const buf = new Buffer(seed, 'hex');
    assert.equal(buf.toString('hex'), seed);
  });


  test('generator encryption (for export)', (assert) => {
    assert.expect(3);

    const entropy = creds.initializeGenerator();
    Logger.log('+ entropy generator: ', entropy.length, entropy);
    const mnemonic = creds.generateMnemonic(entropy);
    assert.ok(mnemonic);
    Logger.log('+ mnemonic: ', mnemonic);

    const key =  api.random32HexBytes();
    const encryptedGen = creds.encryptGenerator(entropy, key);

    assert.ok(encryptedGen);
    Logger.log("+ encrypted generator: ", encryptedGen.length, encryptedGen);

    const decryptedGen = creds.decryptGenerator(encryptedGen, key);

    Logger.log("+ decrypted generator: ", decryptedGen);
    assert.equal(decryptedGen, entropy);
  });


  test('mnemonic encryption (for export)', (assert) => {
    assert.expect(6);

    const entropy = creds.initializeGenerator();
    Logger.log('+ entropy generator: ', entropy);
    const mnemonic = creds.generateMnemonic(entropy);
    assert.ok(mnemonic);
    Logger.log('+ mnemonic: ', mnemonic);

    const key =  api.random32HexBytes();

    const encGen = creds.encryptGenerator(entropy, key);
    const encMemonic = creds.generateMnemonic(encGen);
    assert.ok(encMemonic);
    Logger.log("+ encrypted mnemonic", encMemonic);

    let res = creds.validateMnemonic(mnemonic);
    assert.ok(res.valid);
    assert.equal(res.language, 'en');

    res = creds.validateMnemonic(encMemonic);
    assert.ok(res.valid);
    assert.equal(res.language, 'en');
  });


  test('mnemonic decryption', (assert) => {
    assert.expect(5);

    const entropy = creds.initializeGenerator();
    Logger.log('+ entropy generator: ', entropy);
    const mnemonic = creds.generateMnemonic(entropy);
    assert.ok(mnemonic);
    Logger.log('+ mnemonic: ', mnemonic);

    const key =  api.random32HexBytes();

    const encGen = creds.encryptGenerator(entropy, key);
    const encMemonic = creds.generateMnemonic(encGen);
    assert.ok(encMemonic);
    Logger.log("+ encrypted mnemonic", encMemonic);

    const res = creds.validateMnemonic(encMemonic);
    assert.ok(res.valid);
    assert.equal(res.language, 'en');

    const dec = creds.decryptMnemonic(encMemonic, key);

    Logger.log("dec: ", dec);
    assert.equal(dec.entropy, entropy);
  });


  test('mnemonic decryption (alternate language)', (assert) => {
    assert.expect(5);

    const language = 'it';

    const entropy = creds.initializeGenerator();
    Logger.log('+ entropy generator: ', entropy);
    const mnemonic = creds.generateMnemonic(entropy, language);
    assert.ok(mnemonic);
    Logger.log('+ mnemonic: ', mnemonic);

    const key =  api.random32HexBytes();

    const encGen = creds.encryptGenerator(entropy, key);
    const encMemonic = creds.generateMnemonic(encGen, language);
    assert.ok(encMemonic);
    Logger.log("+ encrypted mnemonic", encMemonic);

    const res = creds.validateMnemonic(encMemonic);
    assert.ok(res.valid);
    assert.equal(res.language, language);

    const dec = creds.decryptMnemonic(encMemonic, key);

    Logger.log("dec: ", dec);
    assert.equal(dec.entropy, entropy);
  });


  test('mnemonic decryption failure (alternate language)', (assert) => {
    assert.expect(5);


    const language = 'it';

    const entropy = creds.initializeGenerator();
    Logger.log('+ entropy generator: ', entropy);
    const mnemonic = creds.generateMnemonic(entropy, language);
    assert.ok(mnemonic);
    Logger.log('+ mnemonic: ', mnemonic);

    const key =  api.random32HexBytes();

    const encGen = creds.encryptGenerator(entropy, key);
    let encMemonic = creds.generateMnemonic(encGen, language);
    assert.ok(encMemonic);
    Logger.log("+ encrypted mnemonic", encMemonic);

    const res = creds.validateMnemonic(encMemonic);
    assert.ok(res.valid);
    assert.equal(res.language, language);

    const needle = encMemonic.split(' ')[2];
    const replace = needle === 'rompere' ? 'perno' : 'rompere';
    encMemonic = encMemonic.replace(needle, replace);

    Logger.log("+ patched mnemonic", encMemonic);

    assert.throws((() => creds.decryptMnemonic(encMemonic, key)), new RegExp('Invalid mnemonic checksum', 'i'));
  });


  test('generator encryption (for storage)', (assert) => {
    assert.expect(3);

    const entropy = creds.initializeGenerator();
    Logger.log('+ entropy generator: ', entropy.length, entropy);
    const mnemonic = creds.generateMnemonic(entropy);

    assert.ok(mnemonic, 'We have a mnemonic');
    Logger.log('+ mnemonic: ', mnemonic);

    const key =  api.random32HexBytes();
    const encryptedGen = creds.encryptSecret(key, entropy);

    assert.ok(encryptedGen, 'An encrypted gen is generated');
    Logger.log("+ encrypted generator: ", encryptedGen.length, encryptedGen);

    const decryptedGen = creds.decryptSecret(key, encryptedGen);

    Logger.log("+ decrypted generator: ", decryptedGen);
    assert.equal(decryptedGen, entropy, 'Decrypted gen is gen');
  });
});


