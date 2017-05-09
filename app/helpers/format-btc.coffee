`import Ember from 'ember'`

formatBtc = Ember.Helper.extend(
  currencySvc:  Ember.inject.service('cm-currency')

  compute: (params, options) ->

    amount = params[0]
    amount = Math.abs(amount) if options.abs
    res = @get('currencySvc').formatBtc(amount, Ember.copy(options))

    if options.withUnit == 'prefixed'
      unit = @get('currencySvc.btcUnit').toLowerCase()
      Ember.String.htmlSafe("<b>#{unit}<b>#{res}")
    else if options.withUnit
      unit = @get('currencySvc.btcUnit')
      Ember.String.htmlSafe("<b>#{res}</b> #{unit}")
    else
      res

  dividerHasChanged: (-> @recompute()).observes('currencySvc.btcDivider')
)

`export default formatBtc`


