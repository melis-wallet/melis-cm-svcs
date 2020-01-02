import Mixin from '@ember/object/mixin'
import { get, set, getProperties } from '@ember/object'
import { isBlank, isPresent } from "@ember/utils"
import { A, isArray }  from '@ember/array'
import { assert } from '@ember/debug'


PerAccountCtx = Mixin.create(

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
    if account && isPresent(pubId = get(account, 'pubId')) && (ctx = ctxs.findBy('pubId', pubId))
      return ctx
    else
      return ctxs.pushObject(@ctxContainer.create(pubId: pubId, account: account))

  init: ->
    @_super(arguments...)

    @set '_ctxs', A()

    accts = @get('cm.accounts')
    assert('per-account-ctx needs access to cm-accounts', isArray(accts))
    assert('per-account-ctx requires an account context container', @ctxContainer)

    unless @ctxLazyCreation
      accts.forEach((a) => @_getContextForAccount(a))


)

export default PerAccountCtx
