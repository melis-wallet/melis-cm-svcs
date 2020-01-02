import { test, moduleFor, module } from 'qunit'
import { run } from '@ember/runloop'
import startApp from '../../helpers/start-app'
import { setupTest } from 'ember-qunit'

import setup from '../../helpers/utils/set-up'

import CmSession from 'melis-cm-svcs/services/cm-session'

application = null
session = null

service =  null

module('Integration: services/cm.account-info', (hooks) ->
  setupTest(hooks)

  hooks.beforeEach((assert)->
    application = startApp()
    session = @owner.lookup('service:cm-session')


    done = assert.async()

    setup.setupEnroll(session, '1234', 'test').then =>
      service = @owner.lookup('service:cm-account-info')
      done()
  )

  hooks.afterEach(->
    session.disconnect() if session.get('connected')
    run(application, 'destroy')
  )


  test 'ready for tests', (assert) ->
    assert.equal session.get('ready'), true


  test 'instantiate service', (assert) ->
    assert.ok service.get('cm')


  test 'initialize and preload', (assert) ->
    assert.expect(3)

    assert.ok service.get('cm')
    done = assert.async()

    service.on 'init-finished', ->
      assert.ok session.get('currentAccount.info')
      assert.ok session.get('currentAccount.info.cosigners')
      done()

  test 'access some account property', (assert) ->
    assert.expect(2)

    assert.ok service.get('cm')
    done = assert.async()

    service.on 'init-finished', ->
      assert.equal session.get('currentAccount.amSummary'), 0
      done()
)