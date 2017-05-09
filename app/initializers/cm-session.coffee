`import Configuration from 'melis-cm-svcs/utils/configuration'`
`import ENV from '../config/environment'`

MelisSessionInitializer = {
  name:       'melis-session'
  initialize: (application) ->
    config = Ember.copy(ENV['melis-session'] || {})
    config.appVersion = ENV['APP'].version
    Configuration.load(application.container, config);
}

`export default MelisSessionInitializer`