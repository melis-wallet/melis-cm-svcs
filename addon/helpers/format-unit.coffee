import Helper from '@ember/component/helper'
import { inject as service } from '@ember/service'
import { isBlank } from "@ember/utils"
import { htmlSafe } from "@ember/string"
import { copy } from 'ember-copy'

formatUnit = Helper.extend(
  coinsvc: service('cm-coin')

  account: null

  compute: (params, options) ->

    amount = params[0]
    account = @set('account', options.account)

    subunit = account?.get('subunit.symbol')

    amount = Math.abs(amount) if options.abs
    res =
      try
        @get('coinsvc').formatUnit(account, amount, copy(options))
      catch
        '---'

    if options.withUnit == 'prefixed'
      htmlSafe("<b>#{subunit?.toLowerCase()}<b>#{res}")
    else if options.withUnit
      htmlSafe("<b>#{res}</b> #{subunit}")
    else
      res

  hasChanged: (-> @recompute()).observes('account.subunit')
)

export default formatUnit


