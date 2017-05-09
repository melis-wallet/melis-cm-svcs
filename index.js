/* eslint-env node */
'use strict';

module.exports = {
  name: 'melis-cm-svcs',

  included: function( app, parentAddon ) {
    var target = (parentAddon || app);

    target.import('vendor/base32.js');
    target.import('vendor/request-idle-callback.js');
  }
};
