`import Ember from 'ember'`
`import CMCore from 'npm:melis-api-js'`

C = CMCore.C

CmChatService = Ember.Service.extend(Ember.Evented,
  cm:  Ember.inject.service('cm-session')

  newMessage: (data, account)->

    if data.msg && data.msg.toPtx
      @trigger 'msg-to-ptx', data.msg, account
    else
      # unimplemented

  setup: ( ->
    Ember.Logger.info  "== Starting chat service"
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

`export default CmChatService`