import Helper from '@ember/component/helper'

formatTextHelper = Helper.helper((params, options) ->

  string = params[0]
  if(string && options && options.len && (string.length > options.len))
    string.substring(0, options.len - 3) + '...'
  else
    string
)

export default formatTextHelper
