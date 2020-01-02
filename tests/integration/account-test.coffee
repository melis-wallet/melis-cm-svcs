import { test, moduleFor, module } from 'qunit'
import { run } from '@ember/runloop'
import startApp from '../helpers/start-app'
import { setupTest } from 'ember-qunit'

import setup from '../helpers/utils/set-up'

import CmSession from 'melis-cm-svcs/services/cm-session'

application = null
session = null


module('Integration: accounts', (hooks) ->
  setupTest(hooks)

  hooks.beforeEach((assert)->

    application = startApp()
    session = @owner.lookup('service:cm-session')

    done = assert.async()

    setup.setupEnroll(session, '1234', 'test').then ->
      done()
  )

  hooks.afterEach( ->
    session.disconnect() if session.get('connected')
    run(application, 'destroy')
  )


  test 'ready for tests', (assert) ->
    assert.equal session.get('ready'), true


  test 'account created', (assert) ->
    assert.ok session.get('currentAccount')


  test 'account state store', (assert) ->
    assert.equal session.get('currentAccount.sstate.version'), '1.0'

)