# Description:
#   Simple queue
#
# Commands:
#   hubot queue me
#   hubot queue << TEXT
#   hubot queue append TEXT
#   hubot queue prepend TEXT
#   hubot queue(?)
#   hubot queue = [NEW_QUEUE]
#   hubot queue pop
#   hubot queue shift
#   hubot queue length
#   hubot queue next?
#   hubot queue next!
#   hubot queue rotate!
#   hubot queue pass!

Path       = require("path")
HubotQueue = require(Path.join(__dirname, "..", "src", "hubot_queue")).HubotQueue

module.exports = (robot) ->

  queue_for = (msg) ->
    new HubotQueue(robot, msg.envelope.room)

  robot.respond /queue\??\s*$/i, (msg) ->
    msg.send queue_for(msg).status()

  robot.respond /queue clear$/i, (msg) ->
    msg.send queue_for(msg).clear()

  robot.respond /queue me\s*$/i, (msg) ->
    msg.send queue_for(msg).append(msg.envelope.user.name)
    msg.send queue_for(msg).status()

  robot.respond /queue << (.+)/i, (msg) ->
    msg.send queue_for(msg).append(msg.match[1])

  robot.respond /queue append (.+)/i, (msg) ->
    msg.send queue_for(msg).append(msg.match[1])

  robot.respond /queue prepend (.+)/i, (msg) ->
    msg.send queue_for(msg).insert(msg.match[1])

  robot.respond /queue = \[([^\]]*)\]\s*$/i, (msg) ->
    msg.send queue_for(msg).store(msg.match[1].split(','))

  robot.respond /queue shift\s*$/i, (msg) ->
    queue = queue_for(msg)
    queue.shift()
    msg.send queue.status()

  robot.respond /queue pop\s*$/i, (msg) ->
    queue = queue_for(msg)
    queue.pop()
    msg.send queue.status()

  robot.respond /queue length\s*$/i, (msg) ->
    queue = queue_for(msg)
    total_ppl = queue_for(msg).status().split(',').length
    msg.send "#{total_ppl} pessoas na fila."

  robot.respond /queue next\?\s*$/i, (msg) ->
    first = queue_for(msg).first()
    if first
      msg.send "#{ first.status() } is the next"
    else
      msg.send "The queue is empty"

  robot.respond /queue next!\s*$/i, (msg) ->
    msg.reply queue_for(msg).next()[1]

  robot.respond /queue rotate!\s*$/i, (msg) ->
    queue = queue_for(msg)
    [removed, message] = queue.next()
    msg.reply message
    msg.send queue.append(removed)

  robot.respond /queue pass!\s*$/i, (msg) ->
    queue = queue_for(msg)
    [removed, message] = queue.next()
    msg.reply message
    msg.send queue.insert(removed, 1)
