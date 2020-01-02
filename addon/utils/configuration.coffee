import loadConfig from 'melis-cm-svcs/utils/load-config'
import Logger from 'melis-cm-svcs/utils/logger'

defaults = {
  stompEndpoint: null
  apiDiscoveryUrl: 'https://discover-regtest.melis.io/api/v1/endpoint/stomp'
  appName: 'melis-cm-svcs'
  appVersion: '0.0.0'
  testMode: false
}

Configuration = {
  stompEndpoint: defaults.stompEndpoint
  apiDiscoveryUrl: defaults.apiDiscoveryUrl
  appName: defaults.appName
  appVersion: defaults.appVersion
  testMode: defaults.testMode

  load: loadConfig(defaults, (container, config)->
    Logger.debug "Config:", config
  )
}

export default Configuration