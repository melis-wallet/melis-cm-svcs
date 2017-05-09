`import Ember from 'ember'`


scaleBtc = Ember.Helper.extend(

  currencySvc: Ember.inject.service('cm-currency')

  compute: (params, options) ->

    ratio = @get('currencySvc.btcDivider')
    opts = Ember.copy(options)
    opts.ratio ||= ratio

    amount = params[0]
    amount = Math.abs(amount) if options.abs
    @get('currencySvc').scaleBtc(amount, opts)

  dividerHasChanged: (-> @recompute()).observes('currencySvc.btcDivider')
)

`export default scaleBtc`


