import { currency, number } from "accounting/settings"

AccountingInitializer = {
  name: 'accounting.js'

  initialize: ->
    currency.symbol = "m"
    currency.format = "%v"
    currency.precision = 2
    number.decimal = "."
    currency.thousand = ""

}

export default AccountingInitializer