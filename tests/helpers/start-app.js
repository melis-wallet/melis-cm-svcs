import Ember from 'ember';
import Application from '../../app';
import config from '../../config/environment';

import CMCore from 'npm:melis-api-js';

export default function startApp(attrs) {
  let attributes = Ember.merge({}, config.APP);
  attributes = Ember.merge(attributes, attrs); // use defaults, but you can override;
  CMCore.C;

  return Ember.run(() => {
    let application = Application.create(attributes);
    application.setupForTesting();
    application.injectTestHelpers();
    return application;
  });
}
