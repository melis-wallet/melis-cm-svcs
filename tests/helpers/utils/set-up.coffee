`import CMCore from 'npm:melis-api-js'`
C = CMCore.C

setup = {

  setupEnroll: (session, pin, accountName) ->

    session.waitForConnect().then( ->
      session.enrollWallet(pin)
    ).then((wallet) ->
      session.accountCreate(type: C.TYPE_PLAIN_HD, meta:  {name: accountName} )
    ).then( (account)->
      session.selectAccount(Ember.get(account, 'num'))
      session.waitForReady()
    )

}


`export default setup`
