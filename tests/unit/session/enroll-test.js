
import { module } from 'ember-qunit';
import { setupTest } from 'ember-qunit';

import CmSession from 'melis-cm-svcs/services/cm-session';

const DISCOVERY_URL = 'https://discover-regtest.melis.io/api/v1/endpoint/stomp';

//const RANDOM_SEED = 'e5f947b327ef2895c1f72df8ed1e02054c404e6484bcf89085c2afb0a9e02bcf';

let session;

module('Unit: cm-session: enroll', function(hooks) {
  setupTest(hooks);


  hooks.beforeEach(function(assert) {
    session = CmSession.create({discoveryUrl: DISCOVERY_URL})
  });

  hooks.afterEach(function(assert) {
    if (session.connected) { session.disconnect(); }
  });

});




