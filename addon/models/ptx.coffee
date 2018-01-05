import { attr, Model } from 'ember-cli-simple-store/model'

Ptx = Model.extend(
  cm:  Ember.inject.service('cm-session')

  account: attr()
  cmo: attr()

  discussion: null

  signing: null
  signingProgress: 0

  currentState: null


  setup: ( ->
    @set 'discussion', Ember.A()
  ).on('init')

  state: (->
    if state = @get('currentState')
      state
    else if (account = @get('account.cmo')) && (cmo = @get('cmo'))
      @get('cm.api').rebuildStateFromPtx(account, cmo)
  ).property('account', 'cmo')

  accountHasSigned: ( ->
    if (signatures = @get('cmo.signatures')) && (account = @get('account.cmo.pubId'))
      signatures.findBy('accountPubId', account)
    else false
  ).property('account.cmo', 'cmo.signatures')

  isSignable: Ember.computed.and('isActive', 'hasFieldsSignature')

  isLocal: ( ->
    if hash = @get('cmo.meta.creatorDeviceHash')
      @get('cm.deviceIdHash') == hash
  ).property('cmo.meta.creatorDeviceHash')

  accountCanSign: (->
    !@get('accountHasSigned') && @get('isSignable')
  ).property('isSignable', 'accountHasSigned')

  accountIsOwner: ( ->
    @get('account.cmo.pubId') == @get('cmo.accountPubId')
  ).property('account', 'cmo.accountPubId')

  isActive: Ember.computed.equal('cmo.status', 'ACTIVE')
  isBroadcasted: Ember.computed.equal('cmo.status', 'BROADCASTED')
  isCanceled: Ember.computed.equal('cmo.status', 'CANCELED')
  isRespent: Ember.computed.equal('cmo.status', 'RESPENT')

  # maybe this is wrong because includes non ACTIVE ones
  isWaiting: Ember.computed.or('isSignable', 'accountIsOwner')

  isMultisig: Ember.computed.alias('account.isMultisig')
  cosignRequired: Ember.computed.alias('account.cosignRequired')
  isInvalid: Ember.computed.not('hasFieldsSignature')
  isVerified: Ember.computed.alias('state.summary.validated')

  hasFieldsSignature: ( ->
    !!@get('cm.api').ptxHasFieldsSignature(@get('cmo'))
  ).property('cmo.meta.ownerSig')

  ownerName: ( ->
    if owner = @get('cmo.accountPubId')
      @get('account').cosignerName(owner, {idIsFine: true})
  ).property('account', 'cmo.accountPubId')

  isRotation: ( ->
    return false if (@get('cmo.recipients.length') != 1)
    (r = @get('cmo.recipients.firstObject')) &&
    (pubId = Ember.get(r, 'pubId')) &&
    (pubId == @get('cmo.masterPubId'))
  ).property('cmo.recipients.firstObject', 'cmo.masterPubId')

  # ptx will show on the stream
  display: ( ->
    @get('isSignable') || @get('isRespent')
  ).property('isSignable', 'isRespent')

  #
  urgent: Ember.computed.alias('accountCanSign')
)

export default Ptx