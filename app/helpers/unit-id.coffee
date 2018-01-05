import Ember from 'ember'

formatUnit = Ember.Helper.extend(
  account: null
  currencySvc: Ember.inject.service('cm-currency')

  compute: (params, options) ->

    account = @set('account', options.account)
    account?.getWithDefault('subunit.symbol', '--') if account

  hasChanged: (-> @recompute()).observes('account.subunit')
)

export default formatUnit


