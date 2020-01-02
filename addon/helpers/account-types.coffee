import Helper from '@ember/component/helper'
import Account from 'melis-cm-svcs/models/account'

AccountTypes = Helper.extend(

  accountTypes: Account.accountTypes

  compute: (params, hash) ->
    typeId = params[0]
    what = hash.what || 'name'

    type = (hash.types || @get('accountTypes')).findBy('id', typeId)
    prefix = hash.prefix || 'acct.types'

    if type
      "#{prefix}.#{type.label}.#{what}"
    else
      "#{prefix}.unknown.#{what}"

)

export default AccountTypes