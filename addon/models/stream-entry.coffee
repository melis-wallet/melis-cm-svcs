import Ember from 'ember'
import { attr, Model } from 'ember-cli-simple-store/model'

StreamEntry = Model.extend(

  subclass: attr()
  content: attr()

  notifiable: false
  notified: false

  created: null
  updated: null

  account: null

  display: Ember.computed.alias('content.display')
  urgent: Ember.computed.alias('content.urgent')
)


export default StreamEntry