import Helper from '@ember/component/helper'
import { inject as service } from '@ember/service'
import { isBlank } from "@ember/utils"
import { htmlSafe } from "@ember/string"
import { copy } from 'ember-copy'

import formatMoney from "accounting/format-money"


formatUnitCurrency = Helper.extend(
  currencySvc: service('cm-currency')
  coinsvc: service('cm-coin')

  account: null

  compute: (params, options) ->
    account = @set('account', options.account)

    amount = params[0]
    amount = Math.abs(amount) if options.abs
    btcAm =
      try
        @get('coinsvc').formatUnit(account, amount, copy(options))
      catch
        '---'

    if options.withUnit == 'prefixed'
      unit = @get('account.subunit.symbol')?.toLowerCase()
      output = "#{unit}<b>#{btcAm}</b>"
    else
      unit = @get('account.subunit.symbol')
      output = "<b>#{btcAm}</b> #{unit}"

    if !isBlank(amount)
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

    htmlSafe(output)

  subunitHasChanged: (-> @recompute()).observes('account.subunit')
  currencyHasChanged: (-> @recompute()).observes('account.unit.value', 'currencySvc.currency' )
)

export default formatUnitCurrency


