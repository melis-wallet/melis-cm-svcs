
import { test, module } from 'qunit';
import { run } from '@ember/runloop';
import startApp from '../../helpers/start-app';
import { setupTest } from 'ember-qunit';

import setup from '../../helpers/utils/set-up';
import { waitTime } from 'melis-cm-svcs/utils/delayed-runners';


let application = null;
let session = null;

let service =  null;

module('Integration: services/cm-address-provider', function(hooks) {
  setupTest(hooks);

  hooks.beforeEach(function(assert){
    application = startApp();
    session = this.owner.lookup('service:cm-session');


    const done = assert.async();

    return setup.setupEnroll(session, '1234', 'test').then(() => {
      service = this.owner.lookup('service:cm-address-provider');
      return waitTime(5000).then( () => done());
  });
  });

  hooks.afterEach(function() {
    if (session.get('connected')) { session.disconnect(); }
    return run(application, 'destroy');
  });


  test('ready for tests', assert => assert.equal(session.get('ready'), true));


  test('instantiate service', assert => assert.ok(service.get('cm')));

  test('get an unused address', assert => {
    service.getUnusedAddress().then(res => {
      console.log('+++ addrsss', res)
      

    })

  })
});