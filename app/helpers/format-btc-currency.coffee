`import Ember from 'ember'`
`import formatMoney from "accounting/format-money"`


formatBtcCurrency = Ember.Helper.extend(
  currencySvc: Ember.inject.service('cm-currency')

  compute: (params, options) ->

    ratio = @get('currencySvc.btcDivider')
    options.ratio ||= ratio

    amount = params[0]
    amount = Math.abs(amount) if options.abs
    btcAm = @get('currencySvc').formatBtc(amount, Ember.copy(options))

    if options.withUnit == 'prefixed'
      unit = @get('currencySvc.btcUnit').toLowerCase()
      output = "#{unit}<b>#{btcAm}</b>"
    else
      unit = @get('currencySvc.btcUnit')
      output = "<b>#{btcAm}</b> #{unit}"

    if !Ember.isBlank(amount)
      value = @get('currencySvc').convertTo(amount)

      if options.compact && (value >= 1000)
         options.precision = 0
      currAm = formatMoney(value, options)

    if options.withUnit == 'prefixed'
      currency = @get('currencySvc.currency').toLowerCase()
      output += " (#{currency}#{currAm})"
    else
      currency = @get('currencySvc.currency')
      output += " (#{currAm} #{currency})"

    Ember.String.htmlSafe(output)

  dividerHasChanged: (-> @recompute()).observes('currencySvc.btcDivider')

  currencyHasChanged: (-> @recompute()).observes('currencySvc.value', 'currencySvc.currency')
)

`export default formatBtcCurrency`


