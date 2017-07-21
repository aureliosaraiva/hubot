Promise = require('promise')

exports.run = (params, shipbot) ->
  new Promise (resolve, reject) =>
    unless params["enabled"] == false
      shipbot.send_messages(shipbot.user.id, params.messages)
    resolve()
