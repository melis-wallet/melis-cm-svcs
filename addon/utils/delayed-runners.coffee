import { later } from "@ember/runloop"
import RSVP from 'rsvp'

waitTime = (time) ->
  new RSVP.Promise((resolve, reject) ->
    later(this, resolve, time)
  )

waitIdle = ->
  new RSVP.Promise((resolve, reject) ->
     requestIdleCallback( resolve )
  )

waitIdleTime = (time) ->
  new RSVP.Promise((resolve, reject) ->
    later(this, (->
      requestIdleCallback( resolve )
    ), time)
  )


export { waitTime, waitIdle, waitIdleTime }