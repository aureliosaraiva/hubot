Fs         = require "fs"
Path       = require("path")
_          = require('underscore')
Promise    = require('promise')

delay = (cb) -> setTimeout cb, 500

merge = (xs...) ->
  if xs?.length > 0
    tap {}, (m) -> m[k] = v for k, v of x for x in xs

tap = (o, fn) -> fn(o); o

chain = (shipbot, queue, resolve, reject) ->
  return resolve() if queue.length == 0

  [instruction_name, params] = queue.shift()
  instruction = require(Path.join(__dirname, 'instructions', instruction_name))
  if instruction?
    try
      instruction.run(params, shipbot)
      .then () ->
        delay -> chain(shipbot, queue, resolve, reject)
      , (errorMessage) ->
        reject(errorMessage)
    catch e
      errorMessage = if e? && e.toString then e.toString() else "Unknown error #{e}"
      reject("The instruction #{instruction_name} failed: #{errorMessage}")
  else
    chain(shipbot, queue, resolve, reject)

class ShipBot
  @APPS_FILE = process.env['HUBOT_DEPLOY_APPS_JSON'] or "apps.json"

  constructor: (@robot, @response, @app_name, @branch, @environment) ->
    @room = @response.envelope.room or '#danger-room'
    @room_id = @room["id"] or '123'
    @user = @response.envelope.user or 'aureliosaraiva'

    applications = JSON.parse(Fs.readFileSync(@constructor.APPS_FILE).toString())
    if typeof @app_name == 'object'
      @deployment_info = @app_name
      @app_name = @deployment_info.app_name
      @application = @deployment_info.application
      @environment = @deployment_info.environment
      @branch = @deployment_info.branch
    else
      @application = applications[@app_name]
      if @application
        @deployment_info =
          app_name : @app_name,
          creation_timestamp: new Date(),
          application: @application,
          environment: @environment,
          branch: @branch,
          heroku_app_name: @application["heroku_#{@environment}_name"]
      else
        @response.send "#{@app_name}? Never heard of it"

  valid : () ->
    @deployment_info?

  task: (task_name) ->
    tasks = @application[task_name]
    return {} unless tasks

    task = (tasks[@environment] || tasks["default"])
    inherit_from = task["inherit_from"]
    if inherit_from
      task = merge(tasks[inherit_from], task)
      delete task["inherit_from"]
    task

  instructions : (task_name) ->
    tap [], (instructions) => instructions.push([instruction, params]) for instruction, params of @task(task_name)

  execute: (task_name, params = {}) ->
    @deployment_info = merge(@deployment_info, params)
    console.log @deployment_info
    new Promise (resolve, reject) =>
      chain this, @instructions(task_name), resolve, reject

  send_room : (messages...) ->
    console.log "send_room: #{messages.join("\n")}"
    try
      msgData = {
        channel: @room
        text: @translate(messages)
      }
      @robot.adapter.customMessage msgData
    catch error
      console.log error, @room_id, @room['id'], @room['name'], @room
      @send_messages(@room_id || @room['id'] || @room['name'] || @room, messages)

  send_author : (messages...) ->
    @send_messages(@user.id, messages)

  send : (recipient_id, messages...) ->
    @send_messages(recipient_id, messages)

  send_messages : (recipient_id, messages) ->
    throw "room id or user id is required" unless recipient_id
    throw "at least one message is required" if messages.length == 0
    @robot.send { room: recipient_id }, @translate(messages)

  translate : (messages) ->
    return '' unless messages? && messages.length > 0
    _(messages).map((message) =>
      @replace_vars(message)
    ).join("\n")

  replace_vars : (message) ->
    variables = message.match(/\$\w+/g)
    _(variables).each (v) =>
      message = message.replace(new RegExp("\\#{v}", 'g'), @variable_value(v))
    message

  variable_value : (variable) ->
    {
      "$app"         : @app_name,
      "$room"        : "<##{@room}>",
      "$environment" : @environment,
      "$robot"       : @robot.name,
      "$branch"      : @branch,
      "$user"        : "<@#{@user}>"
    }[variable]

exports.ShipBot = ShipBot
