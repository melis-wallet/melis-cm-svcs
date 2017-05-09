`import Ember from 'ember'`
`import CMCore from 'npm:melis-api-js'`
`import { storageFor } from 'ember-local-storage'`


`import formatMoney from "accounting/format-money"`

SATOSHI = 100000000.0
FALLBACK_EX = 'fallback'

C = CMCore.C

CurrencyService = Ember.Service.extend(

  cm: Ember.inject.service('cm-session')
  ajax: Ember.inject.service()

  walletstate: storageFor('wallet-state')

  currency: Ember.computed.alias('cm.globalCurrency')
  value: null

  lastUpdate: null
  currentExchange: Ember.computed.alias('walletstate.exchange')

  knownExchanges: ( ->
    if (lu = @get('lastUpdate'))
      Object.keys(lu)
  ).property('lastUpdate')

  value: ( ->
    if (lu = @get('lastUpdate'))
      ex = Ember.get(lu, @get('currentExchange')) || Ember.get(lu, FALLBACK_EX) || lu[Object.keys(lu)[0]]
      ex.last if ex
  ).property('lastUpdate', 'currentExchange')

  btcUnit: Ember.computed.alias('cm.btcUnit')
  btcUnits: Ember.computed.alias('cm.btcUnits')

  btcDivider: ( ->
    switch @get('btcUnit')
      when 'mBTC'
        100000.0
      when 'bits'
        100.0
      when 'BTC'
        SATOSHI
      else
        Ember.assert('unknown BTC unit')
  ).property('btcUnit')

  serie: ( ->
    switch @get('activeSerie')
      when'mo'
        @get('history_mo.history')
      when '24'
        @get('history_24.history')
  ).property('history_24', 'history_mo', 'activeSerie')

  activeSerie: '24'

  history_24: null
  history_mo: null

  subscription: null



  #
  #
  #
  formatBtc: (amount, options) ->
    options ||= {}
    divider =  @get('btcDivider')

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
  parseBtc: (value, options) ->
    options ||= {}
    ratio = options.ratio || @get('btcDivider')

    parseFloat(value)*ratio


  #
  #
  #
  scaleBtc: (amount, options) ->
    options ||= {}

    if amount
      ratio = options.ratio || @get('btcDivider')
      scaled = amount/ratio

      scaled

  #
  #
  #
  satoshisToBtc: (satoshis) ->
    satoshis / SATOSHI


  #
  #
  #
  parseBtcToBtc: (value, options) ->
    @satoshisToBtc(@parseBtc(value, options))


  #
  #
  #
  convertTo: (satoshis) ->
    if value = @get('value')
      (satoshis/SATOSHI) * value


  #
  #
  #
  convertFrom: (currency) ->
    if value = @get('value')
      Math.ceil((currency/value) * SATOSHI)

  #
  #
  #
  currencySymbol: (->
    @get('currency').toLowerCase()
  ).property('currency')

  #
  #
  #
  subscribedOk: Ember.computed.bool('subscription')


  subscribeQueues: (currency) ->
    api = @get('cm.api')
    @setProperties('lastUpdate', null)
    if currency
      @set 'tickerSub', api.subscribeToTickerData(currency, (data) =>
        if !Ember.isBlank(data)
          Ember.Logger.debug('[ticker] data: ', data)
          @set('lastUpdate', data)
      )
      @set 'historySub', api.subscribeToQuotationHistory(currency, (data) =>
        if data
          switch data.type
            when C.HISTORY_SLIDING_24H
              @set('history_24', data)
            when C.HISTORY_SLIDING_MONTH
              @set('history_mo', data)
      )
    else
      @setProperties
        tickerSub: null
        historySub: null

  unsubscribeQueues: ->
    sub.unsubscribe() if sub = @get('tickerSub')
    sub.unsubscribe() if sub = @get('historySub')


  subscribeNewCurrency: ( ->
    @set('currentExchange', FALLBACK_EX) if Ember.isBlank(@get('currentExchange'))
    return unless @get('cm.ready')

    @unsubscribeQueues()
    @subscribeQueues(@get('currency'))
  ).observes('currency', 'cm.ready').on('init')


  currencyChanged: ( ->
    @set('currentExchange', FALLBACK_EX)
  ).observes('currency')

  teardown: (->
    @unsubscribeQueues()
  ).on('willDestroy')

)

`export default CurrencyService`


