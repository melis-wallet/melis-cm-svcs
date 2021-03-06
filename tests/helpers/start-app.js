import { run } from '@ember/runloop'
import { assign } from '@ember/polyfills'

import Application from '../../app';
import config from '../../config/environment';

import CMCore from 'melis-api-js';

export default function startApp(attrs) {
  let attributes = assign({}, config.APP);
  attributes = assign(attributes, attrs); // use defaults, but you can override;

  CMCore.C;

  return run(() => {
    let application = Application.create(attributes);
    application.setupForTesting();
    application.injectTestHelpers();
    return application;
  });
}
