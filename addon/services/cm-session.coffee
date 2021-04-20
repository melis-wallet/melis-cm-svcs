import Service, { inject as service } from '@ember/service'
import Evented from "@ember/object/evented"
import { get, set, getProperties } from "@ember/object"
import { A }  from '@ember/array'
import { alias, filterBy } from "@ember/object/computed"
import { isBlank, isPresent } from "@ember/utils"
import { assert } from "@ember/debug"
import RSVP from 'rsvp'
import CMCore from 'melis-api-js'
import Configuration from 'melis-cm-svcs/utils/configuration'
import SessionEvents from 'melis-cm-svcs/mixins/session-events'
import ModelFactory from 'melis-cm-svcs/mixins/simple-model-factory'
import Account from 'melis-cm-svcs/models/account'
import { storageFor } from 'ember-local-storage'
import Logger from 'melis-cm-svcs/utils/logger'
import { copy } from 'ember-copy'

C = CMCore.C

DEFAULT_SESSION_NAME='cm-client'
CLOCK_SKEW = 60000
TIME_PER_BLOCK = 600

# ask
TFA_PIN_FALLBACK=true

IGNORE_EXS = ['TransitionAborted', 'CmInvalidDeviceException']


CmSessionService = Service.extend(Evented, SessionEvents, ModelFactory,


  #
  # connect when initialized
  #
  autoConnect: true

  #
  # The endpoint of the backend, overrides the configuration, used in tests
  #
  discoveryUrl: null

  #
  # connected to the network
  #
  connected: false

  #
  # connect suceeded at least once, we might not be connected now, but we have been
  #
  connectSucceeded: false

  #
  # connection to the network failed at the first attempt
  #
  connectFailed: null

  #
  # connected and a wallet is open
  #
  ready: false

  #
  # configuration, from network
  #
  config: null

  #
  # selected wallet
  #
  currentWallet: null

  #
  # selected account
  #
  currentAccount: null

  #
  # all the accessible accounts
  #
  accounts: []

  #
  # Login has failed
  #
  walletOpenFailed: false

  #
  # The api endpoint object
  #
  api: null

  #
  # Credentials service
  #
  credentials: service('cm-credentials')

  #
  # Localstorage registry for the wallet
  #
  walletstate: storageFor('wallet-state')

  #
  # queue of promises waiting for connect
  #
  waitingConnect: A()

  #
  # queue of promises waiting for ready
  #
  waitingReady: A()

  #
  # a message given by the server at connect
  #
  connectMessage: alias('config.message')

  #
  #
  #
  network:  alias('config.network')

  #
  #
  #
  testMode: Configuration.testMode


  #
  #
  #
  globalCurrency: alias('walletstate.currency')

  #
  #
  #
  locale: alias('walletstate.locale')


  #
  #
  #
  lampField: null


  #
  #
  #
  walletMeta: {}

  #
  # report errors and other operational states
  #
  telemetryEnabled: alias('walletstate.telemetryEnabled')

  #
  #
  #
  tfaPinFallback: TFA_PIN_FALLBACK

  #
  # list of supported currencies
  #
  currencies: ( ->
    A(@get('config.currencies'))
  ).property('config')


  #
  # Simple mode is when the user has just started
  #
  simpleMode: ( ->
    @get('accounts.length') <= 1
  ).property('accounts.[]')

  #
  # List of accts that are not hidden
  #
  visibleAccts: filterBy('accounts', 'invisible', false)

  #
  #
  #
  deviceIdHash: ( ->
    if id = @get('credentials.deviceId')
      @get('api').deviceIdHash(id)
  ).property('credentials.deviceId')

  #
  # Available coins on this backend
  #
  availableCoins: ( -> @getWithDefault('config.backends', [])).property('config.backends')


  #
  # Users can create accounts for these coins
  #
  enabledCoins: alias('config.coins')

  #
  # Ran at initialization
  #
  setup: (->
    @ensureState()
    @apiDiscoveryUrl = @get('discoveryUrl') || Configuration.apiDiscoveryUrl
    @get('visibleAccts')

    config =
      if (stompEndpoint = Configuration.stompEndpoint)
        {stompEndpoint: stompEndpoint}
      else
        {apiDiscoveryUrl: @apiDiscoveryUrl}

    Logger.info '[CM Session] Initializing. Configuration is: ', config

    api = new CMCore(config)
    @setProperties
      api: api
      lampField: {}

    @trigger('client-init')

    if @get('autoConnect')
      Logger.info '[CM Session] Automatic connect'
      @connect()

    if @get('disableAutoReconnect')
      api.autoReconnectFunc = false

  ).on('init')


  #
  #
  #
  userAgent: ( ->
    {
      application: Configuration.appName
      version: Configuration.appVersion
    }
  ).property()

  #
  #
  #
  latestVersion: alias('config.currentClientVersion')


  #
  #
  #
  versionCode: ( ->
    try
      if(v = Configuration.appVersion)
        [major, minor, patch] = v.split('+')[0].replace('-', '').split('.')
        (major * 1000000) + (minor * 10000) + (patch * 100);
    catch
  ).property()

  #
  #
  #
  outdatedClient: ( ->
    @get('versionCode') < @get('latestVersion')
  ).property('versionCode', 'latestVersion')


  #
  #
  #
  ensureState: ( ->
    @set('btcUnit', 'mBTC') if !@get('btcUnit')
    @set('globalCurrency', 'USD') if !@get('globalCurrency')
  )

  #
  # esplicitly connects, if not autoConnect
  #
  connect: (->
    api = @get('api')

    @setProperties
      connectFailed: null
      connecting: true

    options = {
      locale: @get('walletstate.locale')
      userAgent: @get('userAgent')
    }

    api.connect(options).then( (config) =>

      if config
        Logger.info "[CM Session] Connect success."
        @checkClockSkew(get(config, 'ts'))

        if scheduled = @get('scheduledOpen')
          @set('scheduledOpen', null)
          if scheduled.pin
            scheduled.resolve(@walletReOpen(scheduled.pin))
          else
            scheduled.resolve(@walletOpen(scheduled.seed))

        @set('connectSucceeded', true)
        @trigger('net-first-connect', self)
      else
        Logger.error "[CM Session] Connect succeded but no config received."
        @setProperties
          connected: false
          connectFailed: true
    ).catch( (err) =>
      @setProperties
        connected: false
        connectFailed: err

      Logger.error "[CM Session] Connect failed '#{err}'"
      throw err
    ).finally( =>
      @set 'connecting', false
    )
  )


  #
  # re-connect
  #
  reconnect: ( ->
    api = @get('api')
    api.connect().then((config) =>
      Logger.info "[CM Session] Re-Connect success."
    ).catch((err) =>
      Logger.error "[CM Session] Re-Connect failed '#{err}'"
      throw err
    )
  )

  #
  # disconnect
  #
  disconnect: (->
    api = @get('api')
    if api && @get('connected')
      api.disconnect()
  )

  #
  #
  #
  enrollWallet: (pin) ->

    assert('Wallet not open', !@get('currentWallet'))

    api = @get('api')
    creds = @get('credentials')
    deviceName = @get('credentials.deviceName')

    deviceId = null
    @_resetStates()
    credentials = creds.initializeCredentials()

    sessionName = DEFAULT_SESSION_NAME

    @walletRegister(credentials.seed).then((res) ->
      api.deviceSetPassword(deviceName, pin)
    ).then( (res) ->
      deviceId = res.deviceId
      assert('Blank deviceId', !isBlank(deviceId))

      api.deviceGetPassword(deviceId, pin)
    ).then( (res) ->
      creds.storeCredentials(credentials, deviceId, res.password)
    ).catch( (err) =>
      Logger.error '[CM Session] error enrolling wallet: ', err
      @walletClose()
      throw err
    )

  #
  # pairing is done by enrolling a new device on this side,
  # then transmitting the deviceID and the entropy encrypted with
  # the devicePassword to the other side
  #
  exportForPairing: (pin, deviceName) ->
    creds = @get('credentials')
    api = @get('api')

    self = @
    pairDeviceId = null
    pairSecret = null

    api.deviceSetPassword(deviceName, pin).then((res) ->
      pairDeviceId = res.deviceId
      assert('Blank pairDeviceId', !isBlank(pairDeviceId))
      # the other's device pass
      api.deviceGetPassword(pairDeviceId, pin)
    ).then((res) ->
      pairSecret = res.password
      assert('Blank pairSecret', !isBlank(pairSecret))

      # this device pass
      self.deviceGetPassword(pin)
    ).then((res) ->
      secret = creds.exportForPairing(res.password, pairSecret, pairDeviceId)
      return(deviceId: pairDeviceId, secret: secret)
    ).catch((err) ->
      Logger.error '[CM Session] error export wallet: ', err
      throw err
    )


  validateMnemonic: (pin, mnemonic, passphrase) ->
    api = @get('api')
    creds = @get('credentials')
    eSeed = creds.get('encryptedSeed')
    givenSeed = null

    if mnemonic
      @deviceGetPassword(pin).then((res) ->
        if res.password
          try
            givenEntropy =
              if creds.isMnemonicEncrypted(mnemonic)
                creds.decryptMnemonic(mnemonic, passphrase)
              else
                creds.mnemonicToEntropy(mnemonic)

            givenSeed = creds.entropyToSeed(get(givenEntropy, 'entropy'))
          catch e
            Logger.debug('Check Failed: ', e)

          seed = creds.decryptSecret(res.password, eSeed)
          (seed == givenSeed) && givenSeed
        else
          false
      ).catch( (err) =>
        Logger.error '[CM Session] error verifying credentials: ', err
        throw err
      )
    else
      RSVP.resolve(false)


  validateBackup: (pin, generator, passphrase) ->
    api = @get('api')
    creds = @get('credentials')
    eSeed = creds.get('encryptedSeed')
    givenSeed = null

    if generator
      @deviceGetPassword(pin).then((res) ->
        if res.password
          try
            if creds.isGeneratorEncrypted(generator)
              generator = creds.decryptGenerator(generator, passphrase)
            givenSeed = creds.entropyToSeed(generator)
          catch e
            Logger.debug('Check Failed: ', e)

          seed = creds.decryptSecret(res.password, eSeed)
          (seed == givenSeed) && givenSeed
        else
          false
      ).catch( (err) =>
        Logger.error '[CM Session] error verifying backup: ', err
        throw err
      )
    else
      RSVP.resolve(false)

  importFromCreds: (pin, credentials) ->
    api = @get('api')
    deviceName = @get('credentials.deviceName')
    creds = @get('credentials')
    deviceId = null

    @_resetStates()

    if credentials
      @walletOpen(credentials.seed).then((res) ->
        api.deviceSetPassword(deviceName, pin)
      ).then( (res)->
        deviceId = res.deviceId
        assert('Blank deviceId', !isBlank(deviceId))

        api.deviceGetPassword(deviceId, pin)
      ).then( (res) ->
        creds.storeCredentials(credentials, deviceId, res.password)
        creds.set('backupConfirmed', true)
      ).catch( (err) =>
        Logger.error '[CM Session] error importing wallet: ', err
        @walletClose()
        throw err
      )
    else
      RSVP.reject(msg: 'unable to get valid credentials')


  importForPairing: (data, pin) ->
    creds = @get('credentials')
    api = @get('api')

    imported = null

    try
      pdata = JSON.parse(data)
      adata = JSON.parse(decodeURIComponent(pdata.adata))
      deviceId = adata.ident
    catch e
      RSVP.reject(e)

    RSVP.reject(msg: 'unable to get deviceID') unless deviceId

    self = @

    creds.reset()
    creds.set('devicename', 'Paired Device')

    api.deviceGetPassword(deviceId, pin).then((res) ->
      throw {ex: 'WrongPin', msg: 'unable to get device password'} if isBlank(res.password)
      credentials = creds.importForPairing(res.password, data)
      self.importFromCreds(pin, credentials)
    ).then( (res) ->
      imported = res
      api.devicesDelete(deviceId)
    ).then( (res) ->
      deviceName = get(res, 'devices.firstObject.name')
      if deviceName
        api.deviceUpdate(creds.get('deviceId'), deviceName)
        creds.set('deviceName', deviceName)
    ).then( ->
      return(imported)
    ).catch( (err) ->
      Logger.error '[CM Session] error importing for pairing: ', err
      throw err
    )



  validateGenerator: (entropy, passphrase) ->
    creds = @get('credentials')

    return RSVP.reject(msg: 'Wallet already open') if @get('currentWallet')

    if creds.isGeneratorEncrypted(entropy)
      if isBlank(passphrase)
        RSVP.reject(msg: 'Encrypted generator and no pass')
      else
        try
          entropy = creds.decryptGenerator(entropy, passphrase)
        catch e
          RSVP.reject(msg: e)

    credentials = creds.prepareCredentials(entropy)

    @get('api').walletOpen(credentials.seed).then((wallet) =>
      @get('api').walletClose()
    ).then( ->
      Logger.debug '[CM Session] valid credentials'
      true
    ).catch( (err) =>
      Logger.error  '[CM Session] TryOpen failed: ', err
      throw err
    )


  validateCredentials: (mnemonic, passphrase) ->
    creds = @get('credentials')

    try
      entropy =  creds.importMnemonic(mnemonic, passphrase).entropy
    catch e
      return RSVP.reject(msg: e)

    return RSVP.reject(msg: 'Import failed') unless entropy
    @validateGenerator(entropy, passphrase)



  importWallet: (pin, mnemonic, passphrase) ->
    creds = @get('credentials')

    try
      entropy =  creds.importMnemonic(mnemonic, passphrase).entropy
    catch e
      return RSVP.reject(msg: e)

    if entropy
      @importWalletFromGen(pin, entropy)
    else
      RSVP.reject(msg: 'Import failed')


  importWalletFromGen: (pin, generator, passphrase) ->
    creds = @get('credentials')
    creds.reset()

    if creds.isGeneratorEncrypted(generator)
      if isBlank(passphrase)
        RSVP.reject(msg: 'Encrypted generator and no pass')
      else
        try
          generator = creds.decryptGenerator(generator, passphrase)
        catch e
          RSVP.reject(msg: e)

    credentials = creds.initializeCredentials(generator)
    @importFromCreds(pin, credentials)


  deviceChangeName: (name) ->
    api = @get('api')
    creds = @get('credentials')

    api.deviceUpdate(creds.get('deviceId'), name).then((res) =>
      creds.set('deviceName', name)
    ).catch( (err) ->
      Logger.error '[CM Session] renaming device: ', err
      throw err
    )


  deviceGetPassword: (pin) ->
    creds = @get('credentials')
    api = @get('api')

    deviceId = creds.get('deviceId')
    return RSVP.reject('No Device Id') if isBlank(deviceId)

    Logger.debug '[CM Session] get device password for ', deviceId
    api.deviceGetPassword(deviceId, pin).then((res) ->
      Logger.debug '[CM Session] got device password: ', res
      if !isBlank(res) && !isBlank(res.attemptsLeft)
        creds.set('attemptsLeft', res.attemptsLeft)

      return res
    ).catch((err) =>
      if err.ex == 'CmInvalidDeviceException'
        if err.attemptsLeft
          Logger.warn 'Pin wrong, attempts left: ', err.attemptsLeft
          creds.set('attemptsLeft', res.attemptsLeft)
        else
          Logger.warn 'Pin Attempts expired, deleting credentials'
          creds.reset()
      throw err
    )


  changePin: (oldPin, newPin) ->
    creds = @get('credentials')
    api = @get('api')

    deviceId = creds.get('deviceId')
    return RSVP.reject('No Device Id') if isBlank(deviceId)

    Logger.debug '[CM Session] changing pin for ', deviceId
    api.deviceChangePin(deviceId, oldPin, newPin).then((res) ->
      if !isBlank(res) && !isBlank(res.attemptsLeft)
        creds.set('attemptsLeft', res.attemptsLeft)
      return res
    ).catch((err) =>
      if err.ex == 'CmInvalidDeviceException'
        if err.attemptsLeft
          Logger.warn 'Pin wrong, attempts left: ', err.attemptsLeft
          creds.set('attemptsLeft', res.attemptsLeft)
        else
          Logger.warn 'Pin Attempts expired, deleting credentials'
          creds.reset()
      throw err
    )



  walletReOpen: (pin) ->
    creds = @get('credentials')

    eSeed = creds.get('encryptedSeed')
    return RSVP.reject('No credentials') if isBlank(eSeed)

    @deviceGetPassword(pin).then((res) =>
      throw {ex: 'WrongPin', msg: 'Wrong Pin', attemptsLeft: res.attemptsLeft} if isBlank(res.password)
      seed = creds.decryptSecret(res.password, eSeed)
      throw {ex: 'SeedError', msg: 'No seed or wrong password'} if isBlank(seed)

      @walletOpen(seed)
    ).catch((err) ->
      Logger.error '[CM Session] error reopening wallet: ', err
      throw err
    )

  #
  # registers a new wallet
  #
  walletRegister: (seed, name) ->

    try
      deviceId = @get('credentials.deviceId')
    catch

    if Ember.testing
      deviceId ||= 'test-device'
    sessionName = DEFAULT_SESSION_NAME

    @get('api').walletRegister(seed, sessionName: sessionName, deviceId: deviceId, usePinAsTfa: @get('tfaPinFallback')).then( (wallet) =>
      Logger.info "registered wallet: '#{seed}'", wallet
      @set('currentWallet', copy(wallet, true))

      return wallet
    ).catch((err) ->
      Logger.error '[CM Session] error registering wallet: ', err
      throw err
    )



  #
  # we want to open this wallet now, or as soon the backend is connected
  #
  scheduleWalletOpen: (data) ->
    scheduled = RSVP.defer()


    if @get('connected')
      if data.pin
        scheduled.resolve(@walletReOpen(data.pin))
      else if data.seed
        scheduled.resolve(@walletOpen(data))
    else
      scheduled.pin = data.pin
      scheduled.seed = data.seed
      @set('scheduledOpen', scheduled)

    return scheduled.promise


  #
  # Opens a wallet and makes it the currentWallet
  #
  walletOpen: (seed) ->

    @setProperties
      walletOpenFailed: false
      ready: false
    try
      deviceId = @get('credentials.deviceId')
    catch
      if Ember.testing
        deviceId = 'test-device'

    sessionName = DEFAULT_SESSION_NAME

    Logger.debug "[CM Session] opening wallet: #{seed}"
    @get('api').walletOpen(seed, sessionName: sessionName, deviceId: deviceId, usePinAsTfa: @get('tfaPinFallback')).then((wallet) =>
      @set('currentWallet', copy(wallet, true))
      Logger.debug '[CM Session] wallet open', wallet
      @_getWalletMetadata()
      return wallet
    ).catch( (err) =>
      @set('walletOpenFailed', true)
      Logger.error  '[CM Session] error opening wallet: ', err
      throw err
    )


  #
  #
  #
  waitForConnect: ->
    deferred = RSVP.defer()

    if @get('connected')
      deferred.resolve()
    else
      @get('waitingConnect').pushObject(deferred)

    return deferred.promise


  waitForReady: ->
    deferred = RSVP.defer()

    if @get('ready')
      deferred.resolve()
    else
      @get('waitingReady').pushObject(deferred)

    return deferred.promise


  walletClose: ->
    if (wallet = @get('currentWallet'))
      Logger.debug '[CM Session] closing wallet'
      @get('api').walletClose().then( (res) =>
        @set('currentAccount', null)
        @set('currentWallet', null)
        @set('ready', false)
        return(res)
      ).catch((err) ->
        Logger.error  '[CM Session] close account failed', err
        throw err
      )
    else
      Logger.debug '[CM Session] wallet already close'
      RSVP.resolve()


  accountDelete: (account) ->
    Logger.debug "[CM Session] delete account:", account

    @get('api').accountDelete(get(account, 'cmo')).catch( (err) =>
      Logger.error  '[CM Session] error deleting account: ', err
      throw err
    )


  accountRemove: (id) ->
    Logger.debug "[CM Session] removing account with id:", id

    acct = @get('accounts').findBy('pubId', id)
    if acct
      @get('accounts').removeObject(acct)


  accountSecure: (id, state) ->
    Logger.debug "[CM Session] secure state account:", state, id

    acct = @get('accounts').findBy('pubId', id)
    if acct
      set(acct, 'secure', state)


  accountPush: (data) ->
    acct = @get('accounts').findBy('pubId', get(data, 'account.pubId'))
    balance = get(data, 'balance')
    if acct
      acct.set('cmo', get(data, 'account'))
      acct.set('balance', balance) unless isBlank(balance)
      return acct
    else
      newAcct = @createSimpleModel('account', cmo: data.account, balance: balance)
      @get('accounts').pushObject(newAcct)
      return newAcct


  accountCreate: (data) ->
    Logger.debug "[CM Session] create account: type: #{data.type} - ", data

    @get('api').accountCreate(data).then((data) =>
      Logger.debug  '[CM Session] account created', data
      @accountPush(data)
    ).catch( (err) =>
      Logger.error  '[CM Session] error creating account: ', err
      throw err
    )

  accountJoin: (code, meta) ->
    Logger.debug "[CM Session] join account with code: '#{code}' - ", meta
    @get('api').accountJoin(code, meta).then((data) =>
      Logger.debug  '[CM Session] account joined', data
      @accountPush(data)
    ).catch( (err) =>
      Logger.error  '[CM Session] error joining account: ', err
      throw err
    )

  selectAccount: (id, fallback=false) ->
    acct = @get('accounts').findBy('pubId', id)
    if acct
      @set 'currentAccount', acct
      Logger.info "[CM Session] selected account: #{@get('currentAccount.cmo.meta.name')} "
      @get('currentAccount')
    else if fallback
      @set 'currentAccount', @get('visibleAccts.firstObject')
      Logger.info "[CM Session] selected fallback account: #{@get('currentAccount.cmo.meta.name')} "
      @get('currentAccount')

  payPrepare: (recipients, options = {}) ->
    acct = options.account || @get('currentAccount.cmo')
    if acct
      @get('api').payPrepare(acct, recipients, options).catch((err) ->
        Logger.error  '[CM Session] error in payment prepare: ', err
        throw err
      )


  payConfirm: (txstate, tfa) ->
    @get('api').payConfirm(txstate, tfa).catch((err) ->
        Logger.error  '[CM Session] error in payment confirm: ', err
        throw err
      )


  checkClockSkew: (ts) ->
    if ts
      skew = (moment.now() - ts)
      Logger.debug  '[CM Session] clock skew is (ms): ', skew
      @set('lampField.clockSkew', (Math.abs(skew) > CLOCK_SKEW))
    else
      Logger.info  '[CM Session] no skew information'


  refreshAccount: (account) ->
    Logger.debug  '[CM Session] refreshing account: ', account.get('name')
    @get('api').accountRefresh(account.get('cmo')).then((data) =>
      acct = @get('accounts').findBy('pubId', data.account.pubId)
      if acct
        acct.setProperties
          cmo: data.account
          balance: data.balance
          info: @get('api').peekAccountInfo(acct)
    ).catch((err) ->
      Logger.error  '[CM Session] error refreshing account: ', e
    )


  refreshAccounts: ->
    accounts = @get('cm.accounts')
    @get('accounts').forEach( (acc) => @refreshAccount(acc))


  restoreAccounts: (accountsData) ->
    Logger.debug  '[CM Session] restoring accounts from recovery event.'
    {accounts, balances} = getProperties(accountsData, 'accounts', 'balances')

    if (!isBlank(accounts) && !isBlank(balances) && (wallet = @get('currentWallet')))
      for index, acct of accounts
        if !isBlank(acct) && (id = get(acct, 'pubId'))
          try
            obj = @accountPush(account: acct, balance: balances[id])
            obj.set('info', @get('api').peekAccountInfo(acct))
          catch e
            Logger.error('[] Restire error:' , e)

  findMasterFor: (pubId) ->
    @get('accounts')?.find((a) ->
      (a.get('cmo.type') == C.TYPE_COSIGNER) && (a.get('masterAccount.pubId') == pubId)
    )

  estimateBlockTime: (block, coin) ->
    if(current = @get('api').peekTopBlock(coin)?.height)
      diff = (block - current)
      moment().add((diff * TIME_PER_BLOCK), 'seconds').valueOf()


  updateBackupState: (data) ->
    if data
      @set('credentials.backupConfirmed', data.backupConfirmed) if data.backupConfirmed
      @set('credentials.backupChecked', data.backupChecked) if data.backupChecked

      @get('api').walletMetaSet('backupState', @get('credentials.backupState')).then( (res) =>
        Logger.debug("Backup state: ", res)
      )

  #
  # sets up the list of accounts when the wallet changes
  #
  _setupAccounts: (->
    if wallet = @get('currentWallet')
      accounts = A()
      for index, acct of get(wallet, 'accounts')
        if !isBlank(acct)
          obj = @createSimpleModel('account', cmo: acct)
          obj.set('info', @get('api').peekAccountInfo(acct))
          obj.set('balance', wallet.balances[index]) if isPresent(wallet.balances[index])
          accounts.pushObject(obj)
      @set('accounts', accounts)

    else
      @set('accounts', A())
  ).observes('currentWallet')


  _resetStates: ->
    @get('walletstate').setProperties(
      nnenable: false
      ianenable: false
      pushenabled: false
    )

  _readyState: (->
    @set('ready', true) if @get('currentAccount')
  ).observes('currentAccount')

  _resolveConnected: ( ->
    if @get('connected')
      @get('waitingConnect').forEach (deferred) ->
        deferred.resolve(@)
      @set('waitingConnect', A())
  ).observes('connected')


  _resolveReady: ( ->
    if @get('ready')
      @get('waitingReady').forEach (deferred) ->
        deferred.resolve(@)
      @set('waitingReady', A())
  ).observes('ready')


  _updateAppState: ( ->
    @waitForConnect().then( => @get('api').sessionSetParams(locale: @get('locale'), currency: @get('globalCurrency')))
  ).observes('locale', 'globalCurrency')


  _getWalletMetadata: ( ->
    @get('api').walletMetaGet(['backupState', 'coinPrefs']).then( (res) =>
      if res
        @set('walletMeta', res)
        @set('credentials.backupState', state) if state = get(res, 'backupState')
    ).catch((err) ->
      Logger.error  '[CM Session] getting initial state metadata: ', err
    )
  )


  #
  # make the current account the first in list, if the current is deleted
  #
  _setupAccount: (->
    if @get('currentWallet') && (accounts = @get('visibleAccts'))
      unless(accounts.includes(@get('currentAccount')))
        @set('currentAccount', accounts.get('firstObject'))
    else
      @set('currentAccount', null)
  ).observes('visibleAccts.[]')


  _setupTelemetry: ( ->
    return if @get('testMode') || Ember.testing

    report_error = @set('report_error', (e) =>

      return if (isBlank(e.name) || IGNORE_EXS.includes(e.name))
      Logger.error "---- ERROR REPORTING ----"
      Logger.error e
      return unless @get('telemetryEnabled')
      try
        @get('api').logException(
          @get('currentAccount.cmo'),
          { name: e.name, message: e.message, stack: e.stack },
          @get('credentials.deviceId'),
          @get('userAgent')
        ).catch((e) ->
          Logger.debug "[CM] Telemetry send failed."
        )
      catch error
        Logger.debug "[CM] Telemetry send failed."
    )

    Ember.onerror = report_error
    RSVP.configure('onerror', report_error)
    window.onerror = report_error
  ).on('init')

)

export default CmSessionService
