import Ember from 'ember'

PerAccountCtx = Ember.Mixin.create(

  #
  #
  #
  ctxContainer: null

  #
  #
  #
  ctxLazyCreation: true


  _ctxs: null

  #
  #
  #
  current: ( ->
    @_getContextForAccount(@get('cm.currentAccount'))
  ).property('cm.currentAccount')

  #
  #
  #
  forAccount: (account) ->
    @_getContextForAccount(account)


  _getContextForAccount: (account) ->
    ctxs = @get('_ctxs')
    if account && Ember.isPresent(pubId = Ember.get(account, 'pubId')) && (ctx = ctxs.findBy('pubId', pubId))
      return ctx
    else
      return ctxs.pushObject(@ctxContainer.create(pubId: pubId, account: account))

  init: ->
    @_super(arguments...)

    @set '_ctxs', Ember.A()

    accts = @get('cm.accounts')
    Ember.assert('per-account-ctx needs access to cm-accounts', Ember.isArray(accts))
    Ember.assert('per-account-ctx requires an account context container', @ctxContainer)

    unless @ctxLazyCreation
      accts.forEach((a) => @_getContextForAccount(a))


)

export default PerAccountCtx
