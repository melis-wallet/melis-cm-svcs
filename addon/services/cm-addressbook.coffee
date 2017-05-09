`import Ember from 'ember'`


CmAddressbook = Ember.Service.extend(

  cm: Ember.inject.service('cm-session')
  store: Ember.inject.service('simple-store')

  fetched: false

  fetchAll: (fromDate, force) ->
    cm = @get('cm')
    api = @get('cm.api')
    store = @get('store')

    # TODO
    # we are supposed to have some kind of local storage to use, and maybe refresh
    # in background while we are idle

    cm.waitForReady().then( ->
      api.abGet(fromDate)
    ).then((res) ->
      res.list.forEach((addr) ->
        store.push('ab-entry', addr)
      )
    ).catch((err) ->
      Ember.Logger.error('[CM] Addressbook, failed fetching data.')
      throw err
    )

  #
  # TODO needs pagination
  #
  findAll: ->
    @fetchAll().then( =>
      @get('store').find('ab-entry')
    )


  find: (id) ->
    @fetchAll().then( =>
      @get('store').find('ab-entry', id)
    )


  push: (entry) ->
    api = @get('cm.api')
    api.abAdd(Ember.get(entry, 'serialized')).then((res) =>
      @get('store').push('ab-entry', res.entry)
    ).catch((err) ->
      Ember.Logger.error "Error saving AB entry: ", err
      throw err
    )


  update: (entry) ->
    api = @get('cm.api')
    api.abUpdate(Ember.get(entry, 'serialized')).then((res) =>
      @get('store').push('ab-entry', res.entry)
    ).catch((err) ->
      Ember.Logger.error "Error updating AB entry: ", err
      throw err
    )


  delete: (entry) ->
    api = @get('cm.api')
    api.abDelete(Ember.get(entry, 'serialized')).then((res) =>
      @get('store').remove('ab-entry', entry.id)
    ).catch((err) ->
      Ember.Logger.error "Error deleting AB entry: ", err
      throw err
    )

)

`export default CmAddressbook`
