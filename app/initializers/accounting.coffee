`import { currency, number } from "accounting/settings"`
`import formatBtcHelper from '../helpers/format-btc'`

AccountingInitializer = {
  name: 'accounting.js'

  initialize: ->
    currency.symbol = "m"
    currency.format = "%v"
    currency.precision = 2
    number.decimal = "."
    currency.thousand = ""

}

`export default AccountingInitializer`