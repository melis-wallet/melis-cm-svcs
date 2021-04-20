import Service, { inject as service } from '@ember/service'
import Evented from '@ember/object/evented'
import { get, set, getProperties } from '@ember/object'

import CMCore from 'melis-api-js'

import Logger from 'melis-cm-svcs/utils/logger'

C = CMCore.C

CmChatService = Service.extend(Evented,
  cm: service('cm-session')

  newMessage: (data, account)->

    if data.msg && data.msg.toPtx
      @trigger 'msg-to-ptx', data.msg, account
    else
      # unimplemented

  setup: ( ->
    Logger.info  "== Starting chat service"
    api = @get('cm.api')

    @set '_eventListener', (data) =>

      accounts = @get('cm.accounts')
      accounts.forEach( (acc) =>
        if data.msg && data.msg.toPubId == acc.get('cmo.pubId')
          @newMessage(data, acc)
      )

    api.on(C.EVENT_MESSAGE, @get('_eventListener'))
  ).on('init')

  teardownListener: ( ->
    if handler = @get('_eventListener')
      @get('cm.api').removeListener(C.EVENT_MESSAGE, handler)
  ).on('willDestroy')

)

export default CmChatService