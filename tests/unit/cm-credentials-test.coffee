`import { test, moduleFor } from 'ember-qunit'`
`import Ember from 'ember'`

`import CMCore from 'npm:melis-api-js'`
`import CMCredentials from 'melis-cm-svcs/services/cm-credentials'`

C = CMCore.C
Buffer = CMCore.Buffer

api = null

moduleFor('service:cm-credentials', 'Unit: cm-credentials: basics',

  beforeEach: ->
    api = new CMCore()

  #afterEach: ->
  #   return
)

test 'we have a session', (assert) ->
  assert.ok(this.subject(), 'We have a session')


test 'generating mnemonics from entropy', (assert) ->
  assert.expect(5)

  creds = @subject()

  entropy = creds.initializeGenerator(32)
  mnemonic = creds.generateMnemonic(entropy)
  console.log '+ mnemonic: ', mnemonic
  assert.ok(mnemonic)


  res = creds.validateMnemonic(mnemonic)
  assert.ok(res.valid)
  assert.equal(res.language, 'en')

  output = creds.mnemonicToEntropy(mnemonic)
  assert.ok(output)
  assert.equal(output.entropy, entropy)


test 'generating mnemonics from entropy, (alternate language)', (assert) ->
  assert.expect(6)

  creds = @subject()

  language = 'it'

  entropy = creds.initializeGenerator(32)
  mnemonic = creds.generateMnemonic(entropy, language)
  console.log '+ mnemonic: ', mnemonic
  assert.ok(mnemonic)

  res = creds.validateMnemonic(mnemonic, language)
  assert.ok(res.valid)

  res = creds.validateMnemonic(mnemonic)
  assert.ok(res.valid)
  assert.equal(res.language, language)

  output = creds.mnemonicToEntropy(mnemonic)
  assert.ok(output)
  assert.equal(output.entropy, entropy)



test 'generate a seed from entropy', (assert) ->
  assert.expect(4)

  creds = @subject()

  entropy = creds.initializeGenerator()
  mnemonic = creds.generateMnemonic(entropy)
  assert.ok(mnemonic)
  seed = creds.entropyToSeed(entropy)
  console.log '+ seed: ', seed

  assert.ok(seed)
  assert.equal(creds.credseed.SEED_SIZE, seed.length)

  buf = new Buffer(seed, 'hex');
  assert.equal(buf.toString('hex'), seed)


test 'generator encryption (for export)', (assert) ->
  assert.expect(3)

  creds = @subject()

  entropy = creds.initializeGenerator()
  console.log '+ entropy generator: ', entropy.length, entropy
  mnemonic = creds.generateMnemonic(entropy)
  assert.ok(mnemonic)
  console.log '+ mnemonic: ', mnemonic

  key =  api.random32HexBytes()
  encryptedGen = creds.encryptGenerator(entropy, key)

  assert.ok(encryptedGen)
  console.log "+ encrypted generator: ", encryptedGen.length, encryptedGen

  decryptedGen = creds.decryptGenerator(encryptedGen, key)

  console.log "+ decrypted generator: ", decryptedGen
  assert.equal(decryptedGen, entropy)


test 'mnemonic encryption (for export)', (assert) ->
  assert.expect(6)

  creds = @subject()

  entropy = creds.initializeGenerator()
  console.log '+ entropy generator: ', entropy
  mnemonic = creds.generateMnemonic(entropy)
  assert.ok(mnemonic)
  console.log '+ mnemonic: ', mnemonic

  key =  api.random32HexBytes()

  encGen = creds.encryptGenerator(entropy, key)
  encMemonic = creds.generateMnemonic(encGen)
  assert.ok(encMemonic)
  console.log "+ encrypted mnemonic", encMemonic

  res = creds.validateMnemonic(mnemonic)
  assert.ok(res.valid)
  assert.equal(res.language, 'en')

  res = creds.validateMnemonic(encMemonic)
  assert.ok(res.valid)
  assert.equal(res.language, 'en')


test 'mnemonic decryption', (assert) ->
  assert.expect(5)

  creds = @subject()

  entropy = creds.initializeGenerator()
  console.log '+ entropy generator: ', entropy
  mnemonic = creds.generateMnemonic(entropy)
  assert.ok(mnemonic)
  console.log '+ mnemonic: ', mnemonic

  key =  api.random32HexBytes()

  encGen = creds.encryptGenerator(entropy, key)
  encMemonic = creds.generateMnemonic(encGen)
  assert.ok(encMemonic)
  console.log "+ encrypted mnemonic", encMemonic

  res = creds.validateMnemonic(encMemonic)
  assert.ok(res.valid)
  assert.equal(res.language, 'en')

  dec = creds.decryptMnemonic(encMemonic, key)

  console.log "dec: ", dec
  assert.equal(dec.entropy, entropy)


test 'mnemonic decryption (alternate language)', (assert) ->
  assert.expect(5)

  creds = @subject()

  language = 'it'

  entropy = creds.initializeGenerator()
  console.log '+ entropy generator: ', entropy
  mnemonic = creds.generateMnemonic(entropy, language)
  assert.ok(mnemonic)
  console.log '+ mnemonic: ', mnemonic

  key =  api.random32HexBytes()

  encGen = creds.encryptGenerator(entropy, key)
  encMemonic = creds.generateMnemonic(encGen, language)
  assert.ok(encMemonic)
  console.log "+ encrypted mnemonic", encMemonic

  res = creds.validateMnemonic(encMemonic)
  assert.ok(res.valid)
  assert.equal(res.language, language)

  dec = creds.decryptMnemonic(encMemonic, key)

  console.log "dec: ", dec
  assert.equal(dec.entropy, entropy)


test 'mnemonic decryption failure (alternate language)', (assert) ->
  assert.expect(5)

  creds = @subject()

  language = 'it'

  entropy = creds.initializeGenerator()
  console.log '+ entropy generator: ', entropy
  mnemonic = creds.generateMnemonic(entropy, language)
  assert.ok(mnemonic)
  console.log '+ mnemonic: ', mnemonic

  key =  api.random32HexBytes()

  encGen = creds.encryptGenerator(entropy, key)
  encMemonic = creds.generateMnemonic(encGen, language)
  assert.ok(encMemonic)
  console.log "+ encrypted mnemonic", encMemonic

  res = creds.validateMnemonic(encMemonic)
  assert.ok(res.valid)
  assert.equal(res.language, language)

  needle = encMemonic.split(' ')[2]
  replace = if needle == 'rompere' then 'perno' else 'rompere'
  encMemonic = encMemonic.replace(needle, replace)

  console.log "+ patched mnemonic", encMemonic

  assert.throws((->
    creds.decryptMnemonic(encMemonic, key)
  ), new RegExp('Invalid mnemonic checksum', 'i'))


test 'generator encryption (for storage)', (assert) ->
  assert.expect(3)

  creds = @subject()

  entropy = creds.initializeGenerator()
  console.log '+ entropy generator: ', entropy.length, entropy
  mnemonic = creds.generateMnemonic(entropy)

  assert.ok(mnemonic, 'We have a mnemonic')
  console.log '+ mnemonic: ', mnemonic

  key =  api.random32HexBytes()
  encryptedGen = creds.encryptSecret(key, entropy)

  assert.ok(encryptedGen, 'An encrypted gen is generated')
  console.log "+ encrypted generator: ", encryptedGen.length, encryptedGen

  decryptedGen = creds.decryptSecret(key, encryptedGen)

  console.log "+ decrypted generator: ", decryptedGen
  assert.equal(decryptedGen, entropy, 'Decrypted gen is gen')



