import Service, { inject as service } from '@ember/service'
import Evented from '@ember/object/evented'
import { alias, bool } from '@ember/object/computed'
import { get, set, getProperties, getWithDefault } from "@ember/object"
import { isBlank, isNone, isEmpty } from "@ember/utils"

import { SupportedCoins } from 'melis-cm-svcs/utils/coins'
import Coin from 'melis-cm-svcs/models/coin'
import Logger from 'melis-cm-svcs/utils/logger'

import formatMoney from 'accounting/format-money'

import CMCore from 'npm:melis-api-js'

C = CMCore.C

CmCoinService = Service.extend(Evented,
  cm:  service('cm-session')

  coinPrefs: alias('cm.walletMeta.coinPrefs')
  inited: false

  #
  # Available coins
  #
  coins: ( ->
    availcoins = @get('cm.availableCoins')
    SupportedCoins.filter((c) -> availcoins.includes(get(c, 'unit'))).map((c) -> Coin.create(c))
  ).property('cm.availableCoins')


  #
  # coins (full object) that users can create accounts of
  #
  enabledCoins: ( ->
    @get('coins').filter((c) => @get('cm.enabledCoins').includes(get(c, 'unit')))
  ).property('cm.enabledCoins', 'coins')

  #
  # coins (full object) we have accounts for
  #
  activeCoins: ( ->
    @get('coins').filter((c) =>  @get('activeUnits').includes(get(c, 'unit')))
  ).property('coins', 'activeUnits')

  #
  # coins (just the label, BTC, DOGE etc...) we have accounts for
  #
  activeUnits: ( ->
    @get('cm.accounts')?.uniqBy('coin').map((a) -> get(a, 'coin'))
  ).property('cm.accounts.@each.coin')


  #
  #
  #
  blocks: ( ->
    @get('coins').map((c) -> getProperties(c, 'block') )
  ).property('coins.@each.block')


  validSchemes: ( ->
    @get('coins').map((c) ->  c.get('scheme') ).uniq()
  ).property('coins')


  #
  #
  #
  initializeCoins: ->
    {coins, coinPrefs} = @getProperties('coins', 'coinPrefs')

    coinPrefs ||= {}

    coins.forEach((c) =>
      unit = get(c, 'unit')

      # set subunit
      if (sub = (getWithDefault(coinPrefs, 'subunit', {})[unit])) && (get(c, 'subunits').findBy('id', sub))
        @setSubunit(unit, sub)
      else
        sub = get(c, 'dfSubunit')
        @setSubunit(unit, sub)
    )


  #
  #
  #
  setSubunit: (unit, sub) ->
    if (current = @get('coins').findBy('unit', unit)) && (selected = get(current, 'subunits').findBy('id', sub))
      set(current, 'subunit', selected)


  #
  #
  #
  initializeBlocks: ->
    coins = @get('coins')
    blocks = @get('cm.config.topBlocks')

    for coin, block of blocks
      if (current = coins.findBy('unit', coin))
        set(current, 'block', block)
      else
        Logger.warn('[coin] Not found, initializing top block for coin: ', coin, block)


  #
  #
  #
  setCoinPref: (unit, pref, value) ->
    unless (current = @get('coins').findBy('unit', unit))
      Logger.error("[coin] No unit '#{unit}'")
      return false
    set(current, pref, value)

  #
  #
  #
  storeCoinPref: (unit, pref, value, doset=true) ->

    unless (current = @get('coins').findBy('unit', unit))
      Logger.error("[coin] No unit '#{unit}'")
      return false

    prefs = @getWithDefault('coinPrefs', {}) || {}
    unitPrefs =
      if (p = get(prefs, unit))
        p
      else
        set(prefs, unit, {})

    set(unitPrefs, pref, value)
    @set('coinPrefs', prefs)

    @setCoinPref(unit, pref, value) if doset

    @get('cm.api').walletMetaSet('coinPrefs', prefs).then( ->
      Logger.debug("[coin] Set '#{pref}' for unit '#{unit}' to '#{value}'")
    ).catch((e) ->
      Logger.error("[coin] Failed to set '#{pref}' for unit '#{unit}' to '#{value}': ", e)
    )



  #
  #
  storePrefSubunit: (unit, sub) ->

    if (current = @get('coins').findBy('unit', unit)) && (selected = get(current, 'subunits').findBy('id', sub))
      @setSubunit(unit, sub)
      @storeCoinPref(unit, 'subunit', sub, false)
    else
      Logger.error("[coin] cannot set subnit for unit '#{unit}' to '#{sub}'")


  #
  #
  addressFromUri: (uri, unit) ->
    if (c = @get('coins').findBy('unit', unit))
      if (scheme = c.get('scheme')) && uri.startsWith("#{scheme}:")
        return uri.replace("#{scheme}:", '')
      else
        uri
    else
      uri



  #
  #
  #
  formatAddress: (account, address, options) ->
    return  unless account && (coin = account.get('unit'))
    @formatAddressCoin(coin, address, options)


  #
  #
  #
  formatAddressCoin: (coin, address, options) ->
    return unless coin

    if coin.get('features.altaddrs')
      deflt = 
        if coin.get('features.defaltaddr')
          'standard'
        else
          'legacy'

      options ||= {}
      options.format ||= deflt
      return unless (driver = @get('cm.api').getCoinDriver(coin.get('unit')))

      if C.LEGACY_BITCOIN_REGEX.test(address)
        # address is legacy
        if options.format == 'legacy'
          address
        else
          if (pfx = coin.get('prefix'))
            @concatPfx(coin, driver.toCashAddress(address))
          else
            driver.toCashAddress(address)
      else
        # address is standard
        if options.format == 'standard'
          @concatPfx(coin, address)
        else
          driver.toLegacyAddress(address)
    else
      address


  concatPfx: (coin, address) ->
    if address.includes(':')
      address
    else if (pfx = coin.get('prefix'))
      ''.concat(pfx, ':', address)
    else
      address



  #
  #
  #
  formatUnit: (account, amount, options) ->
    return unless account

    options ||= {}
    divider =  account.get('subunit.divider')

    ratio = options.ratio || divider
    scaled = amount/ratio

    precision = account.get('subunit.precision') || 2

    if (options.compact && (scaled >= 1000) && (precision >= 2))
      precision = precision - 2

    options.precision ||= precision

    if isBlank(amount) && options.blank
      options.blank
    else if options.fullPrecision
      scaled
    else if options.fullPrecisionAligned
      options.precision = Math.log10(divider)
      formatMoney(scaled, options)?.replace(/(0+)$/g, ((match, p1) ->
        if (p1.length >= options.precision - 1)
          '00' +  "\u2007".repeat(p1.length - 2)
        else
          "\u2007".repeat(p1.length)
      ))
    else
      formatMoney(scaled, options)


  #
  #
  #
  parseUnit: (account, value, options) ->
    return unless account

    options ||= {}
    ratio = options.ratio || account.get('subunit.divider')

    parseFloat(value)*ratio


  #
  #
  #
  scaleUnit: (account, amount, options) ->
    return unless account

    options ||= {}

    if amount
      ratio = options.ratio || account.get('subunit.divider')
      scaled = amount/ratio

      scaled


  #
  #
  #
  urlToExplorer: (account, hash) ->
    return unless account
    account.get('unit')?.urlToExplorer(hash)


  #
  #
  #
  newBlock: (data) ->
    if (coin = get(data, 'coin'))
      if (current = @get('coins').findBy('unit', coin))
        set(current, 'block', data)
      else
        Logger.warn("[coin] New block for unknown coin '#{coin}'")

    else
      Logger.warn('[coin] New block with no indicated coin')


  #
  #
  blockForCoin: (coin) ->
    if coin && (current = @get('coins').findBy('unit', coin))
      get(current, 'block')


  #
  #
  #
  validateAddress: (address, coin) ->
    @get('cm.api').isValidAddress(coin, address)


  #
  #
  #
  setupListeners: ->
    @get('cm').on('new-block', this, @newBlock)




  #
  #
  #
  accountsChanged: ( ->
    coins = @get('coins')
    @get('cm.accounts').forEach((a) -> a.set('unit', coins.findBy('unit', a.get('coin'))) if isBlank(a.get('unit')))
  ).observes('cm.accounts.[]').on('init')


  #
  #
  #
  changedPrefs: (->
    if !@get('inited')
      Logger.debug "[coin] Changed prefs.", @get('coinPrefs')

      if !isBlank(prefs = @get('coinPrefs'))
        for k,v of prefs
          @setSubunit(k, sub) if (sub = get(v, 'subunit'))
          ['exchange', 'explorer'].forEach((d) => @setCoinPref(k, d, p) if (p = get(v, d)))

      @set('inited', true)
  ).observes('coinPrefs')


  #
  #
  #
  setup: (->
    Logger.info "[coin] Started."

    @setupListeners()
    @get('coinPrefs')

    self = @
    @get('cm').waitForReady().then( =>
      @initializeCoins()
      @initializeBlocks()
    ).then( ->
      self.trigger('init-finished')
    ).catch((err) ->
      Logger.error('[coin] Error during init: '. err)
      throw err
    )

  ).on('init')



  #
  #
  teardownListener: ( -> @get('cm').off('new-block', this, @newBlock)).on('willDestroy')

)

export default CmCoinService