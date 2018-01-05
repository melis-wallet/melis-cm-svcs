import Ember from 'ember'

formatUnit = Ember.Helper.extend(
  coinsvc: Ember.inject.service('cm-coin')

  account: null

  compute: (params, options) ->

    amount = params[0]
    account = @set('account', options.account)

    subunit = account?.get('subunit.symbol')

    amount = Math.abs(amount) if options.abs
    res =
      try
        @get('coinsvc').formatUnit(account, amount, Ember.copy(options))
      catch
        '---'

    if options.withUnit == 'prefixed'
      Ember.String.htmlSafe("<b>#{subunit?.toLowerCase()}<b>#{res}")
    else if options.withUnit
      Ember.String.htmlSafe("<b>#{res}</b> #{subunit}")
    else
      res

  hasChanged: (-> @recompute()).observes('account.subunit')
)

export default formatUnit


