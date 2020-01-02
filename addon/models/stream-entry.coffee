import { alias } from '@ember/object/computed'

import { attr, Model } from 'ember-cli-simple-store/model'

StreamEntry = Model.extend(

  subclass: attr()
  content: attr()

  notifiable: false
  notified: false

  created: null
  updated: null

  account: null

  display: alias('content.display')
  urgent: alias('content.urgent')
)


export default StreamEntry