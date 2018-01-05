import Ember from 'ember'
import formatMoney from "accounting/format-money"

toCurrency = Ember.Helper.extend(

  cm:  Ember.inject.service('cm-session')
  account: null

  currencySvc: Ember.inject.service('cm-currency')

  compute: (params, options) ->
    amount = params[0]
    opts = Ember.copy(options)
    amount = Math.abs(amount) if opts.abs

    account = @set('account', options.account)

    unless Ember.isBlank(amount)
      value = @get('account.unit')?.convertToCurrency(amount)
      if opts.compact && (value >= 1000)
         opts.precision = 0
      res = formatMoney(value, opts)

    if opts.withUnit == 'prefixed'
      unit = @get('currencySvc.currency').toLowerCase()
      Ember.String.htmlSafe("#{unit}#{res}")
    else if opts.withUnit
      unit = @get('currencySvc.currency')
      Ember.String.htmlSafe("#{res} #{unit}")
    else
      res


  hasChanged: (-> @recompute()).observes('account.unit.value', 'currencySvc.currency' )

)

export default toCurrency


