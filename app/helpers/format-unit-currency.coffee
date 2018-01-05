import Ember from 'ember'
import formatMoney from "accounting/format-money"


formatUnitCurrency = Ember.Helper.extend(
  currencySvc: Ember.inject.service('cm-currency')
  coinsvc: Ember.inject.service('cm-coin')

  account: null

  compute: (params, options) ->
    account = @set('account', options.account)

    amount = params[0]
    amount = Math.abs(amount) if options.abs
    btcAm =
      try
        @get('coinsvc').formatUnit(account, amount, Ember.copy(options))
      catch
        '---'

    if options.withUnit == 'prefixed'
      unit = @get('account.subunit.symbol')?.toLowerCase()
      output = "#{unit}<b>#{btcAm}</b>"
    else
      unit = @get('account.subunit.symbol')
      output = "<b>#{btcAm}</b> #{unit}"

    if !Ember.isBlank(amount)
      value = @get('account.unit')?.convertToCurrency(amount)

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

  subunitHasChanged: (-> @recompute()).observes('account.subunit')
  currencyHasChanged: (-> @recompute()).observes('account.unit.value', 'currencySvc.currency' )
)

export default formatUnitCurrency


