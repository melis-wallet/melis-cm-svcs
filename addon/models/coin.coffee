import Ember from 'ember'

SATOSHI = 100000000.0
I18N_PREFIX = 'coins.unit.'
FALLBACK_EX = 'fallback'

Coin = Ember.Object.extend(


  unit: null
  label: null
  symbol: '--'

  subunits: []
  subunit: null

  ticker: null
  history_d: null
  history_m: null

  activeHist: 'd'
  histTypes: ['d', 'm']

  exchange: FALLBACK_EX
  explorers: {}
  explorer: null

  block: null

  i18n: ( ->
    I18N_PREFIX + @get('unit')?.toLowerCase()
  ).property('unit')


  value: ( ->
    if (ticker = @get('ticker'))
      ex = Ember.get(ticker, @get('exchange')) || Ember.get(ticker, FALLBACK_EX) || ticker[Object.keys(ticker)[0]]
      Ember.get(ex, 'l') if ex
  ).property('ticker', 'exchange')


  knownExchanges: ( ->
    if (tick = @get('ticker'))
      Object.keys(tick)
  ).property('ticker')


  getHistory: (type) ->
    @get('history_' + type)


  history: ( ->
    @getHistory(@get('activeHist'))
  ).property('history_d', 'history_m', 'activeHist')


  #
  #
  #
  currentExplorer: ( ->
    { explorers, explorer } = @getProperties('explorers', 'explorer')

    return if (Ember.isEmpty('explorers') || Ember.isBlank(explorer))

    explorers.findBy('id', explorer)
  ).property('explorers', 'explorer')

  #
  #
  #
  convertToCurrency: (satoshis) ->
    if value = @get('value')
      (satoshis/SATOSHI) * value


  #
  #
  #
  convertFromCurrency: (currency) ->
    if value = @get('value')
      Math.ceil((currency/value) * SATOSHI)


  #
  #
  #
  currencyChanged: ->
    @set('exchange', FALLBACK_EX)


  setup: ( ->
    if !@get('subunit') && (selected = @get('subunits')?.findBy('id', @get('dfSubunit')))
      @set('subunit', selected)
    @selectDefaultExplorer()
  ).on('init')


  #
  #
  #
  urlToExplorer: (hash) ->
    if hash && (ex = @get('currentExplorer'))
      if (url =  Ember.get(ex, 'url'))
        url.replace('\%h', hash.toLowerCase()).replace('\%H', hash.toUpperCase())

  #
  #
  #
  selectDefaultExplorer: ->
    unless (@get('explorer') || Ember.isEmpty(exs = @get('explorers')))
      ex = exs[Math.floor(Math.random() * exs.length)]
      @set('explorer', Ember.get(ex, 'id')) if ex



)


export default Coin