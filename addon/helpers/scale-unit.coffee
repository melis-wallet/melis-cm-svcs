import Helper from '@ember/component/helper'
import { inject as service } from '@ember/service'



scaleUnit = Helper.extend(

  account: null
  coinsvc: service('cm-coin')

  compute: (params, options) ->
    account = @set('account', options.account)

    amount = params[0]
    amount = Math.abs(amount) if options.abs
    @get('coinsvc').scaleUnit(account, amount, options)

  hasChanged: (-> @recompute()).observes('account.subunit')
)

export default scaleUnit


