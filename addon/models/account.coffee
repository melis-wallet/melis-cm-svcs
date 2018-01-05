import Ember from 'ember'
import PtxsSupport from 'melis-cm-svcs/mixins/ptxs-support'
import StreamSupport from 'melis-cm-svcs/mixins/stream-support'
import CMCore from 'npm:melis-api-js'
import { storageFor } from 'ember-local-storage'


C = CMCore.C

Account = Ember.Object.extend(PtxsSupport, StreamSupport,
  cmo: null
  num: Ember.computed.alias('cmo.num')

  uniqueId: Ember.computed.alias('cmo.pubId')
  pubId: Ember.computed.alias('cmo.pubId')

  name: Ember.computed.alias('cmo.meta.name')
  pos: Ember.computed.alias('cmo.meta.pos')

  #
  #
  #
  labels: null

  #
  #
  #
  balance: null

  #
  #
  #
  info: null

  #
  #
  #
  current: false

  #
  #
  #
  recentTxs: false

  #
  #
  #
  stateModel: (->
    Ember.Object.create(id: @get('uniqueId'), modelName: 'account')
  ).property('uniqueId')

  #
  coin: Ember.computed.alias('cmo.coin')

  #
  unit: null
  subunit: Ember.computed.alias('unit.subunit')

  #
  infoModel: (->
    Ember.Object.create(id: @get('uniqueId'), modelName: 'cm-account')
  ).property('uniqueId')

  #
  sstate: storageFor('account-state', 'stateModel')

  #
  recoveryInfo: storageFor('recovery-info', 'infoModel')

  # hidden locally on the client
  invisible: Ember.computed.alias('sstate.invisible')

  # visible only on the master device
  secure: Ember.computed.alias('cmo.hidden')

  amSummary: ( ->
    @get('balance.amAvailable') + @get('balance.amUnconfirmed')
  ).property('balance.amAvailable', 'balance.amUnconfirmed')

  isMultisig: ( ->
    type = @get('cmo.type')
    type == C.TYPE_MULTISIG_MANDATORY_SERVER || type == C.TYPE_MULTISIG_NO_SERVER || type == C.TYPE_COSIGNER
  ).property('cmo.type')

  isMaster: ( ->
    @get('isMultisig') && (@get('cmo.type') != C.TYPE_COSIGNER)
  ).property('cmo.type')

  masterAccount: ( ->
    return unless @get('isMultisig')
    @get('info.cosigners')?.findBy('isMaster', true)
  ).property('cmo.type', 'info.cosigners.[]')

  totalSignatures: (->
    @get('cmo.numCosigners') + 1
  ).property('cmo')

  cosignRequired: (->
    @get('minSignatures') > 1
  ).property('minSignatures')

  minSignatures: Ember.computed.alias('cmo.minSignatures')

  isComplete: ( ->
    !@get('isMultisig') || @get('cmo.status') == C.STATUS_ALL_COSIGNERS_OK
  ).property('cmo')

  needsRecovery: ( ->
    if @get('hasServer') then !!@get('cmo.lockTimeDays') else true
  ).property('cmo.lockTimeDays', 'hasServer')

  canSignMessage: (->
     (@get('cmo.type') == C.TYPE_PLAIN_HD)
  ).property('cmo.type')

  completeness: ( ->
    return {count: @get('totalSignatures'), complete: 100} if @get('isComplete')

    if cosigners = @get('info.cosigners')
      count = cosigners.filter((e) -> e.activationDate).length
      complete = Math.trunc((count / @get('totalSignatures')) * 100)
    else
      count = 0
      complete = 0

    {count: count, complete: complete}
  ).property('info.cosigners', 'isComplete')


  hasServer: Ember.computed.alias('info.serverSignature')

  identifier: ( ->
    try
      (@get('cmo.meta.name') || "U").charAt(0).toUpperCase()
    catch
      '?'
  ).property('cmo.meta')

  defaultColor: ( ->
    Account.colors[@get('num') % Account.colors.length]
  )

  color: ( ->
    @get('cmo.meta.color') || @defaultColor()
  ).property('cmo.meta')

  isMandatory: ( ->
    if me = @get('info.cosigners')?.findBy('pubId', @get('cmo.pubId'))
      Ember.get(me, 'mandatory')
    else
      false
  ).property('info.cosigners')

  cosignerName: ((pubId, opts) ->
    opts ||= {}

    if opts.you
      if @get('cmo.pubId') == pubId
        return opts.you

    if cosigners = @get('info.cosigners')
      if z = cosigners.findBy('pubId', pubId)
        return z.name || z.alias || z.pubId

    if opts.idIsFine
      return pubId

    if opts.unknown
      return opts.unknown
  )


  # Now, one day could be different
  active: Ember.computed.alias('isComplete')

  #
  #
  #
  destroyState: ->
    if state = @get('sstate')
      state.destroy()
      @set('sstate', null)

  deleteRecoveryInfo: ->
    if info = @get('recoveryInfo')
      info.destroy()
      @set('recoveryInfo', null)

)

Account.reopenClass(

  colors: [
    'red', 'orange', 'yellow', 'olive', 'green', 'teal', 'blue', 'violet', 'purple', 'pink', 'brown', 'grey'
  ]

  icons: [
    'no-icon', 'home', 'automobile', 'bank', 'bed', 'bookmark', 'briefcase', 'coffee', 'diamond', 'exchange', 'female', 'flask', 'gavel', 'gift', 'glass',
    'gamepad', 'heart', 'heartbeat', 'industry', 'institution', 'laptop', 'male', 'motorcycle', 'pie-chart', 'paw', 'plane', 'puzzle-piece', 'shopping-bag',
    'shopping-basket', 'shopping-cart', 'space-shuttle', 'star', 'taxi', 'ticket', 'trophy', 'truck', 'user-circle'
  ]

  accountTypes: [
    { id: C.TYPE_PLAIN_HD, label: 'plain', canCreate: true }
    { id: C.TYPE_2OF2_SERVER, label: 'twooftwo', canCreate: true }
    { id: C.TYPE_MULTISIG_MANDATORY_SERVER, label: 'multisrv', canCreate: true }
    { id: C.TYPE_MULTISIG_NON_MANDATORY_SERVER, label: 'multi',  canCreate: false }
    { id: C.TYPE_MULTISIG_NO_SERVER, label: 'multisimp', canCreate: true }
    { id: C.TYPE_COSIGNER, label: 'cosigner', canCreate: false }
  ]

)

export default Account