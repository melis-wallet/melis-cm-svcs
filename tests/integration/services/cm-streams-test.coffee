`import { test, moduleFor, module } from 'qunit'`
`import Ember from 'ember'`
`import startApp from '../../helpers/start-app'`
`import { lookupService } from '../../helpers/utils/lookup'`

`import setup from '../../helpers/utils/set-up'`

`import CmSession from 'melis-cm-svcs/services/cm-session'`

application = null
session = null

service =  null

module('Integration: services/cm.streams',
  beforeEach: (assert)->
    application = startApp()
    session = lookupService(application, 'cm-session')

    done = assert.async()
    setup.setupEnroll(session, '1234', 'test').then ->
      service = lookupService(application, 'cm-stream')
      done()

  afterEach: ->
    session.disconnect() if session.get('connected')
    Ember.run(application, 'destroy');
)


test 'ready for tests', (assert) ->
  assert.equal session.get('ready'), true


test 'instantiate service', (assert) ->
  assert.ok service.get('cm')


test 'initialize and preload', (assert) ->

  assert.ok service.get('cm')
#  done = assert.async()

#  service.on 'init-finished', ->
#    assert.ok service.get('inited')
#    done()

