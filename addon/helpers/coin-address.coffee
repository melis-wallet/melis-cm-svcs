import Helper from '@ember/component/helper'
import { inject as service } from '@ember/service'

CoinAddress = Helper.extend(

  coinsvc: service('cm-coin')

  account: null

  compute: (params, hash) ->
    address = params[0]
    @setProperties
      account: hash.account
      coin: hash.coin

    if (coin = @get('coin'))
      @get('coinsvc').formatAddressCoin(coin, address, format: hash.format)
    else
      @get('coinsvc').formatAddress(@get('account'), address, format: hash.format)

  hasChanged: (-> @recompute()).observes('account.unit', 'coin')
)

export default CoinAddress