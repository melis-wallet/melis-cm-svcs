import Service, { inject as service } from '@ember/service'
import { get, set, getProperties } from '@ember/object'

import Logger from 'melis-cm-svcs/utils/logger'


CmAddressbook = Service.extend(

  cm: service('cm-session')
  store: service('simple-store')

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
      Logger.error('[CM] Addressbook, failed fetching data.')
      throw err
    )

  #
  # TODO needs pagination
  #
  findAll: ->
    @fetchAll().then( => @get('store').find('ab-entry'))


  find: (id) ->
    @fetchAll().then( =>
      @get('store').find('ab-entry', id)
    )


  push: (entry) ->
    api = @get('cm.api')
    Logger.debug('[abook] push: ', get(entry, 'serialized'))
    api.abAdd(get(entry, 'serialized')).then((res) =>
      @get('store').push('ab-entry', res.entry)
    ).catch((err) ->
      Logger.error "Error saving AB entry: ", err
      throw err
    )


  update: (entry) ->
    api = @get('cm.api')
    Logger.debug('[abook] update: ', get(entry, 'serialized'))
    api.abUpdate(get(entry, 'serialized')).then((res) =>
      @get('store').push('ab-entry', res.entry)
    ).catch((err) ->
      Logger.error "Error updating AB entry: ", err
      throw err
    )


  delete: (entry) ->
    api = @get('cm.api')
    Logger.debug('[abook] delete: ', get(entry, 'serialized'))
    api.abDelete(get(entry, 'serialized')).then((res) =>
      @get('store').remove('ab-entry', entry.id)
    ).catch((err) ->
      Logger.error "Error deleting AB entry: ", err
      throw err
    )

)

export default CmAddressbook
