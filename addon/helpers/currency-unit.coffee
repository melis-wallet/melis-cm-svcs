import Helper from '@ember/component/helper'
import { inject as service } from '@ember/service'


currencyUnit = Helper.extend(
  currencySvc: service('cm-currency')

  compute: (params, options) ->
    @get('currencySvc.currency')


  hasChanged: (-> @recompute()).observes('currencySvc.currency')
)

export default currencyUnit


