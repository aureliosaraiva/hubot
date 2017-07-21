# Description:
#   Manage deployment queue
#   Validates conditions before deploy
#
# Commands:
#   hubot ship <app_name>/<branch_name> to <environment>

Path       = require("path")
request    = require("superagent")
ShipBot    = require(Path.join(__dirname, "..", "src", "ship_bot")).ShipBot
HubotQueue = require(Path.join(__dirname, "..", "src", "hubot_queue")).HubotQueue

time_diff_str = (date) ->
  diff = (new Date() - date) / 1000
  hours = Math.floor(diff / 3600)
  minutes = Math.floor((diff - hours * 3600) / 60)
  seconds = Math.floor(diff - hours * 3600 - minutes * 60)
  str = ""
  str += "#{hours}h" if hours > 0
  str += " #{minutes}m" if minutes > 0
  str += " #{seconds}s" if seconds > 0
  str += " ago"
  str.trim()

status_message = (info, status) ->
  creation = new Date(info.creation_timestamp)
  "#{status} #{info.app_name}/#{info.branch} to #{info.environment} that was requested #{time_diff_str(creation)}"

module.exports = (robot) ->

  queue_for = (msg) ->
    new HubotQueue(robot, msg.envelope.room)

  shipbot_from = (msg) ->
    queue = queue_for(msg)
    current_in_queue = queue.first()
    unless current_in_queue
      msg.send "There's nothing in progress, please type #{robot.name} ship $app/$branch to $environment to request a deployment"
      return
    user_name = msg.match[2] || 'me'
    user_name = user_name.replace(/^me$/i, msg.envelope.user.name)
    unless current_in_queue.name.toLowerCase() == user_name.toLowerCase()
      msg.send "It's the turn of #{current_in_queue.name}, wait your turn or type #{robot.name} ship it for #{current_in_queue.name} to ship for him/her"
      return null

    shipbot = new ShipBot(robot, msg, current_in_queue.metadata)
    unless shipbot.valid()
      msg.send "Could not retrieve deployment info contact Mats"
      return null
    shipbot

  robot.respond /ship ([^\s/]+)\/([^\s/]+) to (\w+)/i, (msg) ->
    app = msg.match[1]
    branch_name = msg.match[2]
    environment = msg.match[3]
    shipbot = new ShipBot(robot, msg, app, branch_name, environment)

    if shipbot.valid()
      shipbot.execute("enqueue").then null, (errorMessage) ->
        msg.send errorMessage

  robot.respond /ship current(!| for (\S+))/i, (msg) ->
    shipbot = shipbot_from(msg)
    return unless shipbot

    info = shipbot.deployment_info
    shipbot.execute("prepare_deploy").then null, (errorMessage) -> msg.send errorMessage

  robot.respond /ship it(!| for (\S+))/i, (msg) ->
    console.log "ship it #{msg}"
    shipbot = shipbot_from(msg)
    return unless shipbot

    info = shipbot.deployment_info
    msg.send status_message(info, "Starting deployment of")
    shipbot.execute("ship").then () ->
      msg.send status_message(info, "Published")
    , (errorMessage) ->
      msg.send errorMessage

  robot.respond /ship it anyway(!| for (\S+))/i, (msg) ->
    shipbot = shipbot_from(msg)
    return unless shipbot

    info = shipbot.deployment_info
    msg.send status_message(info, "Starting deployment of")
    shipbot.execute("ship", force: true).then () ->
      msg.send status_message(info, "Published")
    , (errorMessage) ->
      msg.send errorMessage

  robot.respond /merge it(!| for (\S+))/i, (msg) ->
    shipbot = shipbot_from(msg)
    return unless shipbot

    shipbot.execute("merge").then () ->
      msg.send status_message(info, "Finished deployment of")
    , (errorMessage) ->
      msg.send errorMessage

  robot.respond /rollback(!| it!?)?/i, (msg) ->
    shipbot = shipbot_from(msg)
    return unless shipbot

    info = shipbot.deployment_info
    msg.send status_message(info, "Rollbacking deployment of")
    shipbot.execute("rollback").then () ->
      msg.send status_message(info, "Rollbacked")
    , (errorMessage) ->
      msg.send errorMessage
