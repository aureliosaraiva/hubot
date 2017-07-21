Promise    = require('promise')
Path       = require("path")
HubotQueue = require(Path.join(__dirname, "..", "hubot_queue")).HubotQueue

exports.run = (enabled, shipbot) ->
  new Promise (resolve, reject) ->
    return resolve() unless enabled
    queue = new HubotQueue(shipbot.robot, shipbot.room)
    length = queue.load().length
    if length > 0
      deployments = if length == 1 then "deployment" else "deployments"
      shipbot.send_room "There's #{length} #{deployments} before you", "Go Review some PRs or help someone", "I'll let you know when your turn comes"
    data = {}
    data[shipbot.user.name] = shipbot.deployment_info
    queue.append data, (element) ->
      resolve()
