Path       = require('path')
Promise    = require('promise')
HubotQueue = require(Path.join(__dirname, "..", "hubot_queue")).HubotQueue

exports.run = (enabled, shipbot) ->
  new Promise (resolve, reject) =>
    if enabled
      [_, message] = new HubotQueue(shipbot.robot, shipbot.room).next(false)
      shipbot.send_room message
    resolve()
