import Ember from 'ember'
import { SupportedCoins } from 'melis-cm-svcs/utils/coins'
import Coin from 'melis-cm-svcs/models/coin'

import formatMoney from "accounting/format-money"


CmCoinService = Ember.Service.extend(Ember.Evented,
  cm:  Ember.inject.service('cm-session')

  coinPrefs: Ember.computed.alias('cm.walletMeta.coinPrefs')
  inited: false

  #
  # Available coins
  #
  coins: ( ->
    availcoins = @get('cm.availableCoins')
    SupportedCoins.filter((c) -> availcoins.includes(Ember.get(c, 'unit'))).map((c) -> Coin.create(c))
  ).property('cm.availableCoins')


  blocks: ( ->
    @get('coins').map((c) -> Ember.getProperties(c, 'block') )
  ).property('coins.@each.block')



  #
  #
  #
  initializeCoins: ->
    {coins, coinPrefs} = @getProperties('coins', 'coinPrefs')

    coinPrefs ||= {}

    coins.forEach((c) =>
      unit = Ember.get(c, 'unit')

      # set subunit
      if (sub = (Ember.getWithDefault(coinPrefs, 'subunit', {})[unit])) && (Ember.get(c, 'subunits').findBy('id', sub))
        @setSubunit(unit, sub)
      else
        sub = Ember.get(c, 'dfSubunit')
        @setSubunit(unit, sub)
    )


  #
  #
  #
  setSubunit: (unit, sub) ->
    if (current = @get('coins').findBy('unit', unit)) && (selected = Ember.get(current, 'subunits').findBy('id', sub))
      Ember.set(current, 'subunit', selected)


  #
  #
  #
  initializeBlocks: ->
    coins = @get('coins')
    blocks = @get('cm.config.topBlocks')

    for coin, block of blocks
      if (current = coins.findBy('unit', coin))
        Ember.set(current, 'block', block)
      else
        Ember.Logger.error('[coin] Not found, initializing top block for coin: ', coin, block)


  #
  #
  #
  setCoinPref: (unit, pref, value) ->
    unless (current = @get('coins').findBy('unit', unit))
      Ember.Logger.error("[coin] No unit '#{unit}'")
      return false
    Ember.set(current, pref, value)

  #
  #
  #
  storeCoinPref: (unit, pref, value, set=true) ->

    unless (current = @get('coins').findBy('unit', unit))
      Ember.Logger.error("[coin] No unit '#{unit}'")
      return false

    prefs = @getWithDefault('coinPrefs', {}) || {}
    unitPrefs =
      if (p = Ember.get(prefs, unit))
        p
      else
        Ember.set(prefs, unit, {})

    Ember.set(unitPrefs, pref, value)
    @set('coinPrefs', prefs)

    @setCoinPref(unit, pref, value) if set

    @get('cm.api').walletMetaSet('coinPrefs', prefs).then( ->
      Ember.Logger.debug("[coin] Set '#{pref}' for unit '#{unit}' to '#{value}'")
    ).catch((e) ->
      Ember.Logger.error("[coin] Failed to set '#{pref}' for unit '#{unit}' to '#{value}': ", e)
    )



  #
  #
  storePrefSubunit: (unit, sub) ->

    if (current = @get('coins').findBy('unit', unit)) && (selected = Ember.get(current, 'subunits').findBy('id', sub))
      @setSubunit(unit, sub)
      @storeCoinPref(unit, 'subunit', sub, false)
    else
      Ember.Logger.error("[coin] cannot set subnit for unit '#{unit}' to '#{sub}'")


  #
  #
  #
  formatUnit: (account, amount, options) ->
    return unless account

    options ||= {}
    divider =  account.get('subunit.divider')

    ratio = options.ratio || divider
    scaled = amount/ratio


    if divider > 100000.0
      options.precision = 4
    else if options.compact && (scaled >= 1000)
      options.precision = 0
    else
      options.precision = 2

    if Ember.isBlank(amount) && options.blank
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
    if (coin = Ember.get(data, 'coin'))
      if (current = @get('coins').findBy('unit', coin))
        Ember.set(current, 'block', data)
      else
        Ember.Logger.warn("[coin] New block for unknown coin '#{coin}'")

    else
      Ember.Logger.warn('[coin] New block with no indicated coin')


  #
  #
  blockForCoin: (coin) ->
    if coin && (current = @get('coins').findBy('unit', coin))
      Ember.get(current, 'block')

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
    @get('cm.accounts').forEach((a) -> a.set('unit', coins.findBy('unit', a.get('coin'))) if Ember.isBlank(a.get('unit')))
  ).observes('cm.accounts.[]').on('init')


  #
  #
  #
  changedPrefs: (->
    if !@get('inited')
      Ember.Logger.debug "[coin] Changed prefs.", @get('coinPrefs')

      if !Ember.isBlank(prefs = @get('coinPrefs'))
        for k,v of prefs
          @setSubunit(k, sub) if (sub = Ember.get(v, 'subunit'))
          ['exchange', 'explorer'].forEach((d) => @setCoinPref(k, d, p) if (p = Ember.get(v, d)))

      @set('inited', true)
  ).observes('coinPrefs')


  #
  #
  #
  setup: (->
    Ember.Logger.info "[coin] Started."

    @setupListeners()
    @get('coinPrefs')

    self = @
    @get('cm').waitForReady().then( =>
      @initializeCoins()
      @initializeBlocks()
    ).then( ->
      self.trigger('init-finished')
    ).catch((err) ->
      Ember.Logger.error('[coin] Error during init: '. err)
      throw err
    )

  ).on('init')



  #
  #
  teardownListener: ( -> @get('cm').off('new-block', this, @newBlock)).on('willDestroy')

)

export default CmCoinService