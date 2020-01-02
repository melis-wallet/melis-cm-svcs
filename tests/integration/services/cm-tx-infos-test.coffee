import { test, moduleFor, module } from 'qunit'
import { run } from '@ember/runloop'
import startApp from '../../helpers/start-app'
import { setupTest } from 'ember-qunit'

import setup from '../../helpers/utils/set-up'
import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'


import CmSession from 'melis-cm-svcs/services/cm-session'

application = null
session = null

service =  null

module('Integration: services/cm.tx-infos', (hooks) ->
  setupTest(hooks)

  hooks.beforeEach((assert)->
    application = startApp()
    session = @owner.lookup('service:cm-session')


    done = assert.async()

    setup.setupEnroll(session, '1234', 'test').then =>
      service = @owner.lookup('service:cm-tx-infos')
      waitTime(10000).then( -> done())
  )

  hooks.afterEach(->
    session.disconnect() if session.get('connected')
    run(application, 'destroy')
  )


  test 'ready for tests', (assert) ->
    assert.equal session.get('ready'), true


  test 'instantiate service', (assert) ->
    assert.ok service.get('cm')
)