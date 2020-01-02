import Helper from '@ember/component/helper'
import { inject as service } from '@ember/service'
import { isBlank } from "@ember/utils"
import { htmlSafe } from "@ember/string"
import { copy } from 'ember-copy'

import formatMoney from 'accounting/format-money'

formatUnit = Helper.extend(
  coinsvc: service('cm-coin')

  coin: null

  compute: (params, options) ->

    amount = params[0]
    coin = @set('coin', options.coin)

    amount = Math.abs(amount) if options.abs

    precision = 4 - (coin?.get('subunit.precision') || 2)

    if (options.compact && (amount >= 1000) && (precision >= 2))
      precision = precision - 2

    opts = copy(options)
    opts.precision ||= precision

    if options.fullPrecision
      amount
    else
      formatMoney(amount, opts)

  hasChanged: (-> @recompute()).observes('coin.subunit')
)

export default formatUnit


