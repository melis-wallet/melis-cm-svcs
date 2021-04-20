import Service, { inject as service } from '@ember/service'
import { alias, bool } from "@ember/object/computed"
import { get, set, getProperties } from "@ember/object"
import { isBlank, isNone, isEmpty } from "@ember/utils"

import CMCore from 'melis-api-js'
import { storageFor } from 'ember-local-storage'

import Logger from 'melis-cm-svcs/utils/logger'

import formatMoney from "accounting/format-money"

SATOSHI = 100000000.0
FALLBACK_EX = 'fallback'
DEFAULT_COIN = 'BTC'


C = CMCore.C

CurrencyService = Service.extend(

  cm: service('cm-session')
  coinsvc: service('cm-coin')

  #
  walletstate: storageFor('wallet-state')

  #
  #
  #
  activeCurrency: null

  #
  #
  globalCurrency: alias('cm.globalCurrency')


  #
  #
  usdValues: {}

  #
  #
  #
  currency: ( ->
    @get('activeCurrency') || @get('globalCurrency')
  ).property('activeCurrency', 'globalCurrency')


  #
  #
  #
  exchangesFor: (coin) ->
    if (c = @get('coinsvc.coins').findBy('unit', coin))
      get(c, 'knownExchanges')

  #
  #
  #
  valueFor: (coin) ->
    if (c = @get('coinsvc.coins').findBy('unit', coin))
      get(c, 'value')


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
  # convert to an approximate value in currency from a value in usd, by going
  # through the relative values in a coin (the ticker doesn't provide usd -> currency)
  #
  currUsdRatio: (coin) ->
    if (c = @get('coinsvc.coins')?.findBy('unit', coin)) && (usdRef = @usdValues[c.get('tsym')])
      satoshis = Math.ceil(SATOSHI/usdRef)
      @convertTo(coin, satoshis)


  #
  #
  #
  valueTroughUsd: (coin, satoshis, usdValue) ->
    if (ratio = @currUsdRatio(coin))
      (satoshis/SATOSHI) * usdValue * ratio

  #
  #
  #
  currencySymbol: (->
    @get('currency').toLowerCase()
  ).property('currency')

  #
  #
  #
  subscribedOk: bool('subscription')


  #
  tickerData: (data) ->
    @get('coinsvc.coins')?.forEach((c) ->
      if ticker = get(data, get(c, 'tsym'))
        set(c, 'ticker', ticker)
      else
        # do something clever, like determining a value from usd?
        set(c, 'ticker', null)
    )
    if usdValues = get(data, 'usdValues')
      @set('usdValues', usdValues)

  #
  historyData: (data) ->
    @get('coinsvc.coins')?.forEach((c) ->
      if data.values && (history = get(data.values, get(c, 'tsym')))
        switch data.type
          when C.HISTORY_SLIDING_24H
            set(c, 'history_d', history)
          when C.HISTORY_SLIDING_30D
            set(c, 'history_m', history)
    )


  #
  subscribeQueues: (currency) ->
    api = @get('cm.api')
    @setProperties('lastUpdate', null)
    if currency
      @set 'tickerSub', api.subscribeToTickers(currency, (data) =>
        if !isBlank(data)
          Logger.debug('[ticker] data: ', data)
          @tickerData(data)
      )
      @set 'historyDSub', api.subscribeToTickersHistory(C.HISTORY_SLIDING_DAILY, currency, (data) =>
        if !isBlank(data)
          Logger.debug('[history] data: ', data)
          @historyData(data)

      )
      @set 'historyDSub', api.subscribeToTickersHistory(C.HISTORY_SLIDING_MONTHLY, currency, (data) =>
        if !isBlank(data)
          Logger.debug('[history] data: ', data)
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
    @set('currentExchange', FALLBACK_EX) if isBlank(@get('currentExchange'))
    @set('usdValues', {})
    return unless @get('cm.connected')

    @unsubscribeQueues()
    @subscribeQueues(@get('currency'))
  ).observes('currency', 'cm.connected').on('init')


  currencyChanged: ( ->
    @get('coinsvc.coins')?.forEach((c) -> c.currencyChanged())
  ).observes('currency')

  teardown: (->
    @unsubscribeQueues()
  ).on('willDestroy')

)

export default CurrencyService


