'use strict';

const mergeTrees = require('broccoli-merge-trees'),
      stew = require('broccoli-stew'),
      rename = stew.rename,
      map = stew.map;


module.exports = {
  name: 'melis-cm-svcs',

  included: function( app, parentAddon ) {
    var target = (parentAddon || app);

    target.import('vendor/melis-cm-svcs/base32.js');
    target.import('vendor/melis-cm-svcs/request-idle-callback.js');

    // register library version
    target.import('vendor/melis-cm-svcs/register-version.js');
  },


  treeForVendor(vendorTree) {
    let trees = [vendorTree];


    let versionTree = rename(
      map(vendorTree, 'melis-cm-svcs/register-version.template', (c) => c.replace('###VERSION###', require('./package.json').version)),
      'register-version.template',
      'register-version.js'
    );

    trees.push(versionTree);

    return mergeTrees(trees, {overwrite: true});
  }
};
