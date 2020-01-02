import Mixin from '@ember/object/mixin'
import { run } from '@ember/runloop'

ScheduledEvent = Mixin.create

  _eventInterval: 60000

  schedulePollEvent: (event, interval) ->
    eventInterval = interval || @get('_eventInterval') || 60000
    run.later(this, (=>
      unless @isDestroyed
        event.apply(this)
        @set '_timer', @schedulePollEvent(event)
    ), eventInterval)

  startScheduling: (interval) ->
    return if @get('_timer')
    @set '_timer', @schedulePollEvent(@get('onScheduledEvent'), interval)

  stopScheduling: ->
    if (timer = @get('_timer'))
      run.cancel(timer)
      @set('_timer', null)

  onScheduledEvent: ->
    @_super()



export default ScheduledEvent