import { test, moduleFor } from 'ember-qunit'

import CmSession from 'melis-cm-svcs/services/cm-session'
import CmCredentialsService from 'melis-cm-svcs/services/cm-credentials'

DISCOVERY_URL = 'https://discover-regtest.melis.io/api/v1/endpoint/stomp'

RANDOM_SEED = 'e5f947b327ef2895c1f72df8ed1e02054c404e6484bcf89085c2afb0a9e02bcf'

session = null
creds = null

moduleFor('service:cm-session', 'Unit: cm-session: enroll',
  needs: ['service:cm-credentials', 'storage:wallet-state']

  beforeEach: (assert)->
    creds = CmCredentialsService.create()
    session = this.subject({discoveryUrl: DISCOVERY_URL, autoConnect: false, disableAutoReconnect: true})
    done = assert.async()
    session.connect().then ->
      done()

  afterEach: ->
    session.disconnect() if session.get('connected')
)


test 'ready for tests', (assert) ->
  assert.equal session.get('connected'), true


