`import { test, moduleFor } from 'ember-qunit'`
`import { waitTime, waitIdle, waitIdleTime } from 'melis-cm-svcs/utils/delayed-runners'`
`import Ember from 'ember'`

`import CmSession from 'melis-cm-svcs/services/cm-session'`

DISCOVERY_URL = 'https://discover-regtest.melis.io/api/v1/endpoint/stomp'
FAIL_DISCOVERY_URL = 'https://discover-regtest.melis.io/api/v1/endpoint/fail'

RANDOM_SEED = 'e5f947b327ef2895c1f72df8ed1e02054c404e6484bcf89085c2afb0a9e02bcf'

session = null

moduleFor('service:cm-session', 'Unit: cm-session: connection',
  needs: ['service:cm-credentials', 'storage:wallet-state']

  beforeEach: ->
    session = this.subject({discoveryUrl: DISCOVERY_URL, autoConnect: false})

  afterEach: ->
    session.disconnect() if session.get('connected')
)

test 'disable autoconnect', (assert) ->
  assert.ok(this.subject({discoveryUrl: DISCOVERY_URL, autoConnect: false}))


test 'connection to backend', (assert) ->
  assert.expect(8)

  assert.ok(session, 'We have a session')
  assert.ok(session.get('api'), 'It has an API')

  connect = session.connect().then ->
    assert.equal session.get('connecting'), false
    assert.equal session.get('connected'), true
    assert.equal session.get('connectFailed'), null

    assert.equal session.get('walletOpenFailed'), false
    assert.equal session.get('ready'), false

  assert.equal session.get('connecting'), true
  return connect


#test 'failure in connecting to backend', (assert) ->
#  assert.expect(7)
#
#  session = CmSession.create({discoveryUrl: FAIL_DISCOVERY_URL, autoConnect: false, disableAutoReconnect: true})
#  assert.ok(session, 'We have a session')
#  assert.ok(session.get('api'), 'It has an API')

#  connect = session.connect().then(->
#    assert.ok(false, 'Should not connect, but it has')
#  ).catch ->
#    assert.equal session.get('connecting'), false
#    assert.equal session.get('connected'), false
#    assert.notEqual session.get('connectFailed'), null

#    assert.equal session.get('ready'), false

#  assert.equal session.get('connecting'), true
#  return connect


test 'scheduling walletOpen after connection', (assert) ->
  assert.expect(3)

  assert.ok(session)
  schedule = session.scheduleWalletOpen(seed: RANDOM_SEED).catch ->
    assert.equal session.get('connected'), true
    assert.equal session.get('walletOpenFailed'), true

  connect = session.connect()

  return schedule


test 'autoconnect with scheduled walletOpen', (assert) ->
  assert.expect(3)

  session = CmSession.create({discoveryUrl: DISCOVERY_URL})
  assert.ok(session)

  schedule = session.scheduleWalletOpen(seed: RANDOM_SEED).catch ((err) ->
    assert.equal session.get('connected'), true
    assert.equal session.get('walletOpenFailed'), true
  )

  return schedule