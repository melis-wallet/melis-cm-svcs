import Helper from '@ember/component/helper'
import { inject as service } from '@ember/service'


formatUnit = Helper.extend(
  account: null
  currencySvc: service('cm-currency')

  compute: (params, options) ->

    account = @set('account', options.account)
    account?.getWithDefault('subunit.symbol', '--') if account

  hasChanged: (-> @recompute()).observes('account.subunit')
)

export default formatUnit


