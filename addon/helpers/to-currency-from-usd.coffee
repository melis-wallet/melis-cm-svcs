import Helper from '@ember/component/helper'
import { inject as service } from '@ember/service'
import { isBlank } from "@ember/utils"
import { htmlSafe } from "@ember/string"
import { copy } from 'ember-copy'

import formatMoney from "accounting/format-money"

toCurrencyUsd = Helper.extend(

  cm:  service('cm-session')
  currencySvc: service('cm-currency')

  account: null

  compute: (params, options) ->
    amount = params[0]
    usdRef = params[1]
    opts = copy(options)
    amount = Math.abs(amount) if opts.abs

    account = @set('account', options.account)

    unless isBlank(amount)
      coin = @get('account.coin')
      value = @get('currencySvc').valueTroughUsd(coin, amount, usdRef)
      if opts.compact && (value >= 1000)
         opts.precision = 0
      res = formatMoney(value, opts)

    if opts.withUnit == 'prefixed'
      unit = @get('currencySvc.currency').toLowerCase()
      htmlSafe("#{unit}#{res}")
    else if opts.withUnit
      unit = @get('currencySvc.currency')
      htmlSafe("#{res} #{unit}")
    else
      res

  hasChanged: (-> @recompute()).observes('currencySvc.usdValues', 'currencySvc.currency' )
)

export default toCurrencyUsd


