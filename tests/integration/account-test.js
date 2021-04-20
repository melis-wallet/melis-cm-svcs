
import { test, module } from 'qunit';
import { run } from '@ember/runloop';
import startApp from '../helpers/start-app';
import { setupTest } from 'ember-qunit';

import setup from '../helpers/utils/set-up';

let application = null;
let session = null;


module('Integration: accounts', function(hooks) {
  setupTest(hooks);

  hooks.beforeEach(function(assert){

    application = startApp();
    session = this.owner.lookup('service:cm-session');

    const done = assert.async();

    return setup.setupEnroll(session, '1234', 'test').then(() => done());
  });

  hooks.afterEach( function() {
    if (session.get('connected')) { session.disconnect(); }
    return run(application, 'destroy');
  });


  test('ready for tests', assert => assert.equal(session.get('ready'), true));


  test('account created', assert => assert.ok(session.get('currentAccount')));


  test('account state store', assert => assert.equal(session.get('currentAccount.sstate.version'), '1.0'));

});