`import Ember from 'ember'`
`import CMCore from 'npm:melis-api-js'`
`import { storageFor } from 'ember-local-storage'`

import formatMoney from "accounting/format-money"

SATOSHI = 100000000.0
FALLBACK_EX = 'fallback'
DEFAULT_COIN = 'BTC'


C = CMCore.C

CurrencyService = Ember.Service.extend(

  cm: Ember.inject.service('cm-session')
  coinsvc: Ember.inject.service('cm-coin')

  #
  walletstate: storageFor('wallet-state')

  #
  currency: Ember.computed.alias('cm.globalCurrency')

  #
  #
  #
  exchangesFor: (coin) ->
    if (c = @get('coinsvc.coins').findBy('unit', coin))
      Ember.get(c, 'knownExchanges')

  #
  #
  #
  valueFor: (coin) ->
    if (c = @get('coinsvc.coins').findBy('unit', coin))
      Ember.get(c, 'value')


  #
  #
  #
  satoshisToCoin: (satoshis) ->
    satoshis / SATOSHI


  #
  #
  #
  convertTo: (coin, satoshis) ->
    if (c = @get('coinsvc.coins')?.findBy('unit', coin)) && (value = c.get('value'))
      (satoshis/SATOSHI) * value


  #
  #
  #
  convertFrom: (coin, currency) ->
    if (c = @get('coinsvc.coins')?.findBy('unit', coin)) && (value = c.get('value'))
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


  #
  tickerData: (data) ->
    @get('coinsvc.coins')?.forEach((c) ->
      if ticker = Ember.get(data, Ember.get(c, 'tsym'))
        Ember.set(c, 'ticker', ticker)
    )

  #
  historyData: (data) ->
    @get('coinsvc.coins')?.forEach((c) ->
      if data.values && (history = Ember.get(data.values, Ember.get(c, 'tsym')))
        switch data.type
          when C.HISTORY_SLIDING_24H
            Ember.set(c, 'history_d', history)
          when C.HISTORY_SLIDING_30D
            Ember.set(c, 'history_m', history)
    )


  #
  subscribeQueues: (currency) ->
    api = @get('cm.api')
    @setProperties('lastUpdate', null)
    if currency
      @set 'tickerSub', api.subscribeToTickers(currency, (data) =>
        if !Ember.isBlank(data)
          Ember.Logger.debug('[ticker] data: ', data)
          @tickerData(data)
      )
      @set 'historyDSub', api.subscribeToTickersHistory(C.HISTORY_SLIDING_DAILY, currency, (data) =>
        if !Ember.isBlank(data)
          Ember.Logger.debug('[history] data: ', data)
          @historyData(data)

      )
      @set 'historyDSub', api.subscribeToTickersHistory(C.HISTORY_SLIDING_MONTHLY, currency, (data) =>
        if !Ember.isBlank(data)
          Ember.Logger.debug('[history] data: ', data)
          @historyData(data)

      )
    else
      @setProperties
        tickerSub: null
        historyDSub: null
        historyMSub: null

  #
  unsubscribeQueues: ->
    sub.unsubscribe() if sub = @get('tickerSub')
    sub.unsubscribe() if sub = @get('historyDSub')
    sub.unsubscribe() if sub = @get('historyMSub')


  #
  subscribeNewCurrency: ( ->
    @set('currentExchange', FALLBACK_EX) if Ember.isBlank(@get('currentExchange'))
    return unless @get('cm.ready')

    @unsubscribeQueues()
    @subscribeQueues(@get('currency'))
  ).observes('currency', 'cm.ready').on('init')


  currencyChanged: ( ->
    @get('coinsvc.coins')?.forEach((c) -> c.currencyChanged())
  ).observes('currency')

  teardown: (->
    @unsubscribeQueues()
  ).on('willDestroy')

)

export default CurrencyService


