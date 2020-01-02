import CMCore from 'npm:melis-api-js'
import Logger from 'melis-cm-svcs/utils/logger'
C = CMCore.C

setup = {

  setupEnroll: (session, pin, accountName) ->

    session.waitForConnect().then( ->
      Logger.warn "--- Enrolling"
      session.enrollWallet(pin)
    ).then((wallet) ->
      Logger.warn "--- Creating account"
      session.accountCreate(type: C.TYPE_PLAIN_HD, meta:  {name: accountName} )
    ).then( (account)->
      session.selectAccount(Ember.get(account, 'num'))
      session.waitForReady()
    )

}


export default setup
