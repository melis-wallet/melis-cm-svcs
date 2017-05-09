`import Ember from 'ember'`

CmTestComponent = Ember.Component.extend(
  cm: Ember.inject.service('cm-session')

  setupStuff: (->
    console.log "hello"
    console.log @get('cm')

  ).on('init')
)

`export default CmTestComponent`
