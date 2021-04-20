
import { test, module } from 'qunit';
import { run } from '@ember/runloop';
import startApp from '../../helpers/start-app';
import { setupTest } from 'ember-qunit';

import setup from '../../helpers/utils/set-up';

let application = null;
let session = null;

let service =  null;

module('Integration: services/cm.account-info', function(hooks) {
  setupTest(hooks);

  hooks.beforeEach(function(assert){
    application = startApp();
    session = this.owner.lookup('service:cm-session');


    const done = assert.async();

    return setup.setupEnroll(session, '1234', 'test').then(() => {
      service = this.owner.lookup('service:cm-account-info');
      return done();
  });
  });

  hooks.afterEach(function() {
    if (session.get('connected')) { session.disconnect(); }
    return run(application, 'destroy');
  });


  test('ready for tests', assert => assert.equal(session.get('ready'), true));


  test('instantiate service', assert => assert.ok(service.get('cm')));


  test('initialize and preload', function(assert) {
    assert.expect(3);

    assert.ok(service.get('cm'));
    const done = assert.async();

    return service.on('init-finished', function() {
      assert.ok(session.get('currentAccount.info'));
      assert.ok(session.get('currentAccount.info.cosigners'));
      return done();
    });
  });

  return test('access some account property', function(assert) {
    assert.expect(2);

    assert.ok(service.get('cm'));
    const done = assert.async();

    return service.on('init-finished', function() {
      assert.equal(session.get('currentAccount.amSummary'), 0);
      return done();
    });
  });
});