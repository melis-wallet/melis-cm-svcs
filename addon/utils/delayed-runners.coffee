import Ember from 'ember'


waitTime = (time) ->
  new Ember.RSVP.Promise((resolve, reject) ->
    Ember.run.later(this, resolve, time)
  )

waitIdle = ->
  new Ember.RSVP.Promise((resolve, reject) ->
     requestIdleCallback( resolve )
  )

waitIdleTime = (time) ->
  new Ember.RSVP.Promise((resolve, reject) ->
    Ember.run.later(this, (->
      requestIdleCallback( resolve )
    ), time)
  )


export { waitTime, waitIdle, waitIdleTime }