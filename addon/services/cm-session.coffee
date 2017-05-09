`import Ember from 'ember'`
`import CMCore from 'npm:melis-api-js'`
`import Configuration from 'melis-cm-svcs/utils/configuration'`
`import SessionEvents from 'melis-cm-svcs/mixins/session-events'`
`import ModelFactory from 'melis-cm-svcs/mixins/simple-model-factory'`
`import Account from 'melis-cm-svcs/models/account'`
`import { storageFor } from 'ember-local-storage'`

C = CMCore.C

DEFAULT_SESSION_NAME='cm-client'
CLOCK_SKEW = 60000
TIME_PER_BLOCK = 600

# ask
TFA_PIN_FALLBACK=true

IGNORE_EXS = ['TransitionAborted', 'CmInvalidDeviceException']

CmSessionService = Ember.Service.extend(Ember.Evented, SessionEvents, ModelFactory,


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
  # The api endpoint objec
  #
  api: null

  #
  # Credentials service
  #
  credentials: Ember.inject.service('cm-credentials')

  #
  # Localstorage registry for the wallet
  #
  walletstate: storageFor('wallet-state')

  #
  # queue of promises waiting for connect
  #
  waitingConnect: Ember.A()

  #
  # queue of promises waiting for ready
  #
  waitingReady: Ember.A()

  #
  # a message given by the server at connect
  #
  connectMessage: Ember.computed.alias('config.message')

  #
  #
  #
  network:  Ember.computed.alias('config.network')

  #
  #
  #
  testMode: Configuration.testMode

  #
  #
  #
  block: null

  #
  #
  #
  globalCurrency: Ember.computed.alias('walletstate.currency')

  #
  #
  #
  locale: Ember.computed.alias('walletstate.locale')

  #
  #
  #
  btcUnits: ['mBTC', 'BTC', 'bits']

  #
  #
  #
  btcUnit: Ember.computed.alias('walletstate.btcUnit')


  #
  #
  #
  lampField: null


  #
  # report errors and other operational states
  #
  telemetryEnabled: Ember.computed.alias('walletstate.telemetryEnabled')

  #
  #
  #
  tfaPinFallback: TFA_PIN_FALLBACK

  #
  # list of supported currencies
  #
  currencies: ( ->
    Ember.A(@get('config.currencies'))
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
  visibleAccts: Ember.computed.filterBy('accounts', 'invisible', false)

  #
  #
  #
  deviceIdHash: ( ->
    if id = @get('credentials.deviceId')
      @get('api').deviceIdHash(id)
  ).property('credentials.deviceId')


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

    Ember.Logger.info '[CM Session] Initializing. Configuration is: ', config

    api = new CMCore(config)
    @setProperties
      api: api
      lampField: {}

    @trigger('client-init')

    if @get('autoConnect')
      Ember.Logger.info '[CM Session] Automatic connect'
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
        Ember.Logger.info "[CM Session] Connect success."
        @checkClockSkew(Ember.get(config, 'ts'))

        if scheduled = @get('scheduledOpen')
          @set('scheduledOpen', null)
          if scheduled.pin
            scheduled.resolve(@walletReOpen(scheduled.pin))
          else
            scheduled.resolve(@walletOpen(scheduled.seed))

        @set('connectSucceeded', true)
        @trigger('net-first-connect', self)
      else
        Ember.Logger.error "[CM Session] Connect succeded but no config received."
        @setProperties
          connected: false
          connectFailed: true
    ).catch( (err) =>
      @setProperties
        connected: false
        connectFailed: err

      Ember.Logger.error "[CM Session] Connect failed '#{err}'"
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
      Ember.Logger.info "[CM Session] Re-Connect success."
    ).catch((err) =>
      Ember.Logger.error "[CM Session] Re-Connect failed '#{err}'"
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

    Ember.assert('Wallet not open', !@get('currentWallet'))

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
      Ember.assert('Blank deviceId', !Ember.isBlank(deviceId))

      api.deviceGetPassword(deviceId, pin)
    ).then( (res) ->
      creds.storeCredentials(credentials, deviceId, res.password)
    ).catch( (err) =>
      Ember.Logger.error '[CM Session] error enrolling wallet: ', err
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
      Ember.assert('Blank pairDeviceId', !Ember.isBlank(pairDeviceId))
      # the other's device pass
      api.deviceGetPassword(pairDeviceId, pin)
    ).then((res) ->
      pairSecret = res.password
      Ember.assert('Blank pairSecret', !Ember.isBlank(pairSecret))

      # this device pass
      self.deviceGetPassword(pin)
    ).then((res) ->
      secret = creds.exportForPairing(res.password, pairSecret, pairDeviceId)
      return(deviceId: pairDeviceId, secret: secret)
    ).catch((err) ->
      Ember.Logger.error '[CM Session] error export wallet: ', err
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

            givenSeed = creds.entropyToSeed(Ember.get(givenEntropy, 'entropy'))
          catch e
            Ember.Logger.debug('Check Failed: ', e)

          seed = creds.decryptSecret(res.password, eSeed)
          (seed == givenSeed) && givenSeed
        else
          false
      ).catch( (err) =>
        Ember.Logger.error '[CM Session] error verifying credentials: ', err
        throw err
      )
    else
      Ember.RSVP.resolve(false)


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
            Ember.Logger.debug('Check Failed: ', e)

          seed = creds.decryptSecret(res.password, eSeed)
          (seed == givenSeed) && givenSeed
        else
          false
      ).catch( (err) =>
        Ember.Logger.error '[CM Session] error verifying backup: ', err
        throw err
      )
    else
      Ember.RSVP.resolve(false)

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
        Ember.assert('Blank deviceId', !Ember.isBlank(deviceId))

        api.deviceGetPassword(deviceId, pin)
      ).then( (res) ->
        creds.storeCredentials(credentials, deviceId, res.password)
        creds.set('backupConfirmed', true)
      ).catch( (err) =>
        Ember.Logger.error '[CM Session] error importing wallet: ', err
        @walletClose()
        throw err
      )
    else
      Ember.RSVP.reject(msg: 'unable to get valid credentials')


  importForPairing: (data, pin) ->
    creds = @get('credentials')
    api = @get('api')

    imported = null

    try
      pdata = JSON.parse(data)
      adata = JSON.parse(decodeURIComponent(pdata.adata))
      deviceId = adata.ident
    catch e
      Ember.RSVP.reject(e)

    Ember.RSVP.reject(msg: 'unable to get deviceID') unless deviceId

    self = @

    creds.reset()
    creds.set('devicename', 'Paired Device')

    api.deviceGetPassword(deviceId, pin).then((res) ->
      throw {ex: 'WrongPin', msg: 'unable to get device password'} if Ember.isBlank(res.password)
      credentials = creds.importForPairing(res.password, data)
      self.importFromCreds(pin, credentials)
    ).then( (res) ->
      imported = res
      api.devicesDelete(deviceId)
    ).then( (res) ->
      deviceName = Ember.get(res, 'devices.firstObject.name')
      if deviceName
        api.deviceUpdate(creds.get('deviceId'), deviceName)
        creds.set('deviceName', deviceName)
    ).then( ->
      return(imported)
    ).catch( (err) ->
      Ember.Logger.error '[CM Session] error importing for pairing: ', err
      throw err
    )


  importWallet: (pin, mnemonic, passphrase) ->
    creds = @get('credentials')

    try
      entropy =  creds.importMnemonic(mnemonic, passphrase).entropy
    catch e
      return Ember.RSVP.reject(msg: e)

    if entropy
      @importWalletFromGen(pin, entropy)
    else
      Ember.RSVP.reject(msg: 'Import failed')


  importWalletFromGen: (pin, generator, passphrase) ->
    creds = @get('credentials')
    creds.reset()

    if creds.isGeneratorEncrypted(generator)
      if Ember.isBlank(passphrase)
        Ember.RSVP.reject(msg: 'Encrypted generator and no pass')
      else
        try
          generator = creds.decryptGenerator(generator, passphrase)
        catch
          Ember.RSVP.reject(msg: e)

    credentials = creds.initializeCredentials(generator)
    @importFromCreds(pin, credentials)


  deviceChangeName: (name) ->
    api = @get('api')
    creds = @get('credentials')

    api.deviceUpdate(creds.get('deviceId'), name).then((res) =>
      creds.set('deviceName', name)
    ).catch( (err) ->
      Ember.Logger.error '[CM Session] renaming device: ', err
      throw err
    )


  deviceGetPassword: (pin) ->
    creds = @get('credentials')
    api = @get('api')

    deviceId = creds.get('deviceId')
    return Ember.RSVP.reject('No Device Id') if Ember.isBlank(deviceId)

    Ember.Logger.debug '[CM Session] get device password for ', deviceId
    api.deviceGetPassword(deviceId, pin).then((res) ->
      Ember.Logger.debug '[CM Session] got device password: ', res
      if !Ember.isBlank(res) && !Ember.isBlank(res.attemptsLeft)
        creds.set('attemptsLeft', res.attemptsLeft)

      return res
    ).catch((err) =>
      if err.ex == 'CmInvalidDeviceException'
        if err.attemptsLeft
          Ember.Logger.warn 'Pin wrong, attempts left: ', err.attemptsLeft
          creds.set('attemptsLeft', res.attemptsLeft)
        else
          Ember.Logger.warn 'Pin Attempts expired, deleting credentials'
          creds.reset()
      throw err
    )


  changePin: (oldPin, newPin) ->
    creds = @get('credentials')
    api = @get('api')

    deviceId = creds.get('deviceId')
    return Ember.RSVP.reject('No Device Id') if Ember.isBlank(deviceId)

    Ember.Logger.debug '[CM Session] changing pin for ', deviceId
    api.deviceChangePin(deviceId, oldPin, newPin).then((res) ->
      if !Ember.isBlank(res) && !Ember.isBlank(res.attemptsLeft)
        creds.set('attemptsLeft', res.attemptsLeft)
      return res
    ).catch((err) =>
      if err.ex == 'CmInvalidDeviceException'
        if err.attemptsLeft
          Ember.Logger.warn 'Pin wrong, attempts left: ', err.attemptsLeft
          creds.set('attemptsLeft', res.attemptsLeft)
        else
          Ember.Logger.warn 'Pin Attempts expired, deleting credentials'
          creds.reset()
      throw err
    )



  walletReOpen: (pin) ->
    creds = @get('credentials')

    eSeed = creds.get('encryptedSeed')
    return Ember.RSVP.reject('No credentials') if Ember.isBlank(eSeed)

    @deviceGetPassword(pin).then((res) =>
      throw {ex: 'WrongPin', msg: 'Wrong Pin', attemptsLeft: res.attemptsLeft} if Ember.isBlank(res.password)
      seed = creds.decryptSecret(res.password, eSeed)
      throw {ex: 'SeedError', msg: 'No seed or wrong password'} if Ember.isBlank(seed)

      @walletOpen(seed)
    ).catch((err) ->
      Ember.Logger.error '[CM Session] error reopening wallet: ', err
      throw err
    )

  #
  # registers a new wallet
  #
  walletRegister: (seed, name) ->

    try
      deviceId = @get('credentials.deviceId')
    catch
      deviceId = 'test-device'

    sessionName = DEFAULT_SESSION_NAME

    @get('api').walletRegister(seed, sessionName: sessionName, deviceId: deviceId, usePinAsTfa: @get('tfaPinFallback')).then( (wallet) =>
      Ember.Logger.info "registered wallet: '#{seed}'", wallet
      @set('currentWallet', Ember.copy(wallet, true))

      return wallet
    ).catch((err) ->
      Ember.Logger.error '[CM Session] error registering wallet: ', err
      throw err
    )



  #
  # we want to open this wallet now, or as soon the backend is connected
  #
  scheduleWalletOpen: (data) ->
    scheduled = Ember.RSVP.defer()


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

    # close if open
    # clear current account

    @setProperties
      walletOpenFailed: false
      ready: false

    try
      deviceId = @get('credentials.deviceId')
    catch
      deviceId = 'test-device'

    sessionName = DEFAULT_SESSION_NAME

    Ember.Logger.debug "[CM Session] opening wallet: #{seed}"
    @get('api').walletOpen(seed, sessionName: sessionName, deviceId: deviceId, usePinAsTfa: @get('tfaPinFallback')).then((wallet) =>
      @set('currentWallet', Ember.copy(wallet, true))
      Ember.Logger.debug '[CM Session] wallet open', wallet
      return(wallet)
    ).catch( (err) =>
      @set('walletOpenFailed', true)
      Ember.Logger.error  '[CM Session] error opening wallet: ', err
      throw err
    )


  #
  #
  #
  waitForConnect: ->
    deferred = Ember.RSVP.defer()

    if @get('connected')
      deferred.resolve()
    else
      @get('waitingConnect').pushObject(deferred)

    return deferred.promise


  waitForReady: ->
    deferred = Ember.RSVP.defer()

    if @get('ready')
      deferred.resolve()
    else
      @get('waitingReady').pushObject(deferred)

    return deferred.promise


  walletClose: ->
    if (wallet = @get('currentWallet'))
      Ember.Logger.debug '[CM Session] closing wallet'
      @get('api').walletClose().then( (res) =>
        @set('currentAccount', null)
        @set('currentWallet', null)
        @set('ready', false)
        return(res)
      ).catch((err) ->
        Ember.Logger.error  '[CM Session] close account failed', err
        throw err
      )
    else
      Ember.Logger.debug '[CM Session] wallet already close'
      Ember.RSVP.resolve()


  accountDelete: (account) ->
    Ember.Logger.debug "[CM Session] delete account:", account

    @get('api').accountDelete(Ember.get(account, 'cmo')).catch( (err) =>
      Ember.Logger.error  '[CM Session] error deleting account: ', err
      throw err
    )

  accountPush: (data) ->
    acct = @get('accounts').findBy('num', data.account.num)
    balance = Ember.get(data, 'balance')
    if acct
      acct.set('cmo', data.account)
      acct.set('balance', balance) unless Ember.isBlank(balance)
      return acct
    else
      newAcct = @createSimpleModel('account', cmo: data.account, balance: balance)
      @get('accounts').pushObject(newAcct)
      return newAcct


  accountCreate: (data) ->
    Ember.Logger.debug "[CM Session] create account: type: #{data.type} - ", data

    @get('api').accountCreate(data).then((data) =>
      Ember.Logger.debug  '[CM Session] account created', data
      @accountPush(data)
    ).catch( (err) =>
      Ember.Logger.error  '[CM Session] error creating account: ', err
      throw err
    )

  accountJoin: (code, meta) ->
    Ember.Logger.debug "[CM Session] join account with code: '#{code}' - ", meta
    @get('api').accountJoin(code, meta).then((data) =>
      Ember.Logger.debug  '[CM Session] account joined', data
      @accountPush(data)
    ).catch( (err) =>
      Ember.Logger.error  '[CM Session] error joining account: ', err
      throw err
    )

  selectAccount: (index, fallback=false) ->
    acct = @get('accounts').findBy('num', index)
    if acct
      @set 'currentAccount', acct
    else if fallback
      @set 'currentAccount', @get('visibleAccts.firstObject')
    Ember.Logger.info "[CM Session] selected account: #{@get('currentAccount.cmo.meta.name')} "


  payPrepare: (recipients, options = {}) ->
    acct = options.account || @get('currentAccount.cmo')
    if acct
      @get('api').payPrepare(acct, recipients, options).catch((err) ->
        Ember.Logger.error  '[CM Session] error in payment prepare: ', err
        throw err
      )


  payConfirm: (txstate, tfa) ->
    @get('api').payConfirm(txstate, tfa).catch((err) ->
        Ember.Logger.error  '[CM Session] error in payment confirm: ', err
        throw err
      )


  checkClockSkew: (ts) ->
    if ts
      skew = (moment.now() - ts)
      Ember.Logger.debug  '[CM Session] clock skew is (ms): ', skew
      @set('lampField.clockSkew', (Math.abs(skew) > CLOCK_SKEW))
    else
      Ember.Logger.info  '[CM Session] no skew information'


  refreshAccount: (account) ->
    Ember.Logger.debug  '[CM Session] refreshing account: ', account.get('name')
    @get('api').accountRefresh(account.get('cmo')).then((data) =>
      acct = @get('accounts').findBy('num', data.account.num)
      if acct
        acct.set('cmo', data.account)
        acct.set('balance', data.balance)
    ).catch((err) ->
      Ember.Logger.error  '[CM Session] error refreshing account: ', e
    )


  refreshAccounts: ->
    accounts = @get('cm.accounts')
    @get('accounts').forEach( (acc) => @refreshAccount(acc) )


  estimateBlockTime: (block) ->
    current = @get('api').peekTopBlock().height
    diff = (block - current)
    moment().add((diff * TIME_PER_BLOCK), 'seconds').valueOf()

  #
  # sets up the list of accounts when the wallet changes
  #
  _setupAccounts: (->
    if wallet = @get('currentWallet')
      accounts = Ember.A()
      for index, acct of Ember.get(wallet, 'accounts')
        if !Ember.isBlank(acct)
          obj = @createSimpleModel('account', cmo: acct)
          #obj.set('info', @get('api').peekAccountInfo()
          obj.set('balance', wallet.balances[index]) if Ember.isPresent(wallet.balances[index])
          accounts.pushObject(obj)
      @set('accounts', accounts)


    else
      @set('accounts', Ember.A())
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
      @set('waitingConnect', Ember.A())
  ).observes('connected')


  _resolveReady: ( ->
    if @get('ready')
      @get('waitingReady').forEach (deferred) ->
        deferred.resolve(@)
      @set('waitingReady', Ember.A())
  ).observes('ready')


  _updateAppState: ( ->
    @waitForConnect().then( => @get('api').sessionSetParams(locale: @get('locale'), currency: @get('globalCurrency')))
  ).observes('locale', 'globalCurrency')

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


  #
  #_setupVisibleAccount: (->
  #console.error "xxhello"
  #  if @get('currentWallet') && (accounts = @get('visibleAccts'))
  #    console.error "xxhere, wtf?", accounts
  #    unless(accounts.includes(@get('currentAccount')))
  #      @set('currentAccount', accounts.get('firstObject'))
  #  else
  #    @set('currentAccount', null)
  #).observes('visibleAccts.[]')

  _setupTelemetry: ( ->
    #return if @get('testMode')

    report_error = @set('report_error', (e) =>
      return if (Ember.isBlank(e.name) || IGNORE_EXS.includes(e.name))
      Ember.Logger.error "---- ERROR REPORTING ----"
      Ember.Logger.error e
      return unless @get('telemetryEnabled')
      try
        @get('api').logException(
          @get('currentAccount.cmo'),
          { name: e.name, message: e.message, stack: e.stack },
          @get('credentials.deviceId'),
          @get('userAgent')
        ).catch((e) ->
          Ember.Logger.debug "[CM] Telemetry send failed."
        )
      catch error
        Ember.Logger.debug "[CM] Telemetry send failed."
    )

    Ember.onerror = report_error
    Ember.RSVP.configure('onerror', report_error)
    window.onerror = report_error
  ).on('init')

)

`export default CmSessionService`
