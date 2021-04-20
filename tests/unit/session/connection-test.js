
import { test, module } from 'ember-qunit';
import { setupTest } from 'ember-qunit';

import CmSession from 'melis-cm-svcs/services/cm-session';

const DISCOVERY_URL = 'https://discover-regtest.melis.io/api/v1/endpoint/stomp';
//const FAIL_DISCOVERY_URL = 'https://discover-regtest.melis.io/api/v1/endpoint/fail';

const RANDOM_SEED = 'e5f947b327ef2895c1f72df8ed1e02054c404e6484bcf89085c2afb0a9e02bcf';

let session;

module('Unit: cm-session: connection', function(hooks) {
  setupTest(hooks);
  //needs: ['service:cm-credentials', 'storage:wallet-state'],

  hooks.beforeEach(function(assert) {
    //session = this.owner.lookup('service:cm-session');
    session = CmSession.create({discoveryUrl: DISCOVERY_URL, autoConnect: false})
    //session.setProperties({discoveryUrl: DISCOVERY_URL, autoConnect: false});
  });

  hooks.afterEach(function(assert) {
    if (session.connected) { session.disconnect(); }
  });


  test('disable autoconnect', (assert) => {
    //assert.ok(session({discoveryUrl: DISCOVERY_URL, autoConnect: false}));
    assert.equal(session.autoConnect, false)
    assert.equal(session.connecting, false)
  });


  test('connection to backend', (assert)  => {
    assert.expect(8);

    assert.ok(session, 'We have a session');
    assert.ok(session.api, 'It has an API');

    const connect = session.connect().then(function() {
      assert.equal(session.connecting, false, 'is not connecting');
      assert.equal(session.connected, true, 'is connected');
      assert.equal(session.connectFailed, false, 'is not failed');

      assert.equal(session.walletOpenFailed, false, 'wallet has not opened');
      return assert.equal(session.ready, false, 'not ready');
    });

    assert.equal(session.connecting, true, 'has started connecting');
    return connect;
  });


  //test 'failure in connecting to backend', (assert) ->
  //  assert.expect(7)
  //
  //  session = CmSession.create({discoveryUrl: FAIL_DISCOVERY_URL, autoConnect: false, disableAutoReconnect: true})
  //  assert.ok(session, 'We have a session')
  //  assert.ok(session.get('api'), 'It has an API')

  //  connect = session.connect().then(->
  //    assert.ok(false, 'Should not connect, but it has')
  //  ).catch ->
  //    assert.equal session.get('connecting'), false
  //    assert.equal session.get('connected'), false
  //    assert.notEqual session.get('connectFailed'), null

  //    assert.equal session.get('ready'), false

  //  assert.equal session.get('connecting'), true
  //  return connect


  test('scheduling walletOpen after connection', (assert) => {
    assert.expect(3);

    assert.ok(session, 'session ok');
    const schedule = session.scheduleWalletOpen({seed: RANDOM_SEED}).catch(() => {
      assert.equal(session.connected, true, 'is connected');
      assert.equal(session.walletOpenFailed, true, 'wallet open attempted and failed');
    });

    session.connect();
    return schedule
  });


  test('autoconnect with scheduled walletOpen', (assert) => {
    assert.expect(3);

    session = CmSession.create({discoveryUrl: DISCOVERY_URL});
    assert.ok(session, 'session ok');
    
    const schedule = session.scheduleWalletOpen({seed: RANDOM_SEED}).catch(((err) => {
      assert.equal(session.connected, true, 'is connected');
      assert.equal(session.walletOpenFailed, true, 'wallet open attempted and failed');
    })
    );

    return schedule;
  });

});