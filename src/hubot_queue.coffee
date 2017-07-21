_ = require('underscore')

generate_uuid = () ->
  'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace /[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c is 'x' then r else (r & 0x3|0x8)
    v.toString(16)

class HubotQueueElement
  constructor: (name, @metadata = {}) ->
    @metadata['_uuid'] = generate_uuid() unless @metadata['_uuid']
    @name = name.toLowerCase().replace(/\s+/, " ")

  serialize: () ->
    obj = {}
    obj[@name] = @metadata
    JSON.stringify(obj).replace(/\s+/, " ")

  @fromHash: (hash) ->
    name = Object.keys(hash)[0]
    new HubotQueueElement(name, hash[name])

  @fromString: (string) ->
    new HubotQueueElement(string)

  @parse: (obj) ->
    return obj if obj instanceof HubotQueueElement
    HubotQueueElement.fromHash JSON.parse(obj)

  @toString: () ->
    "#{@name}: { #{_(Object.keys(@metadata)).map((k) -> "#{k}: #{@metadata[k]}").join(", ")} }"

class HubotQueue
  @QUEUE = process.env['HUBOT_QUEUE_PREFIX'] or "hubot-queue"
  @callbacks = {}

  constructor: (@robot, @name) ->
    @brain = @robot.brain

  serialize: (obj) ->
    return obj.serialize() if obj instanceof HubotQueueElement

    factory_method = switch typeof obj
      when "string" then "fromString"
      when "object" then "fromHash"
      else throw "Unsupported type"
    element = HubotQueueElement[factory_method].call(this, obj)
    element.serialize()

  deserialize: (element) ->
    HubotQueueElement.parse(element)

  names: (queue) ->
    _(queue).map (element) -> element.name || element

  to_s: (queue) ->
    "[#{ @names(queue).join(', ') }]"

  status: () ->
    @load().toString()

  clear: () ->
    try
      _(@load()).each (element) => @delete_callback(element)
    catch e
      console.log e
    @brain.set("#{ @QUEUE }.#{ @name }", "")
    "[]"

  load: () ->
    serialized_queue = (@brain.get("#{ @QUEUE }.#{ @name }") || '').replace(/^\s+|\s+$/g, "")
    if serialized_queue.length == 0
      queue = []
    else
      queue = _(serialized_queue.split("\t")).map @deserialize

    queue.names = () => @names(queue)
    queue.toString = () => @to_s(queue)
    queue

  store: (queue) ->
    serialized_queue = _(queue).map @serialize
    @brain.set("#{ @QUEUE }.#{ @name }", serialized_queue.join("\t"))
    @load()

  add_callback : (queue, cb) ->
    return queue unless cb

    if queue.length == 1
      cb(queue[0])
    else
      uuid = queue[queue.length-1].metadata["_uuid"]
      HubotQueue.callbacks[uuid] = cb
    queue

  notify_callback : (queue) ->
    return if queue.length == 0

    element = queue[0]
    uuid = element.metadata["_uuid"]
    cb = HubotQueue.callbacks[uuid]
    if cb
      cb(element)
      delete HubotQueue.callbacks[uuid]

  delete_callback : (element) ->
    uuid = element.metadata["_uuid"]
    delete HubotQueue.callbacks[uuid]

  append: (element, cb = null) ->
    queue = @load()
    queue.push element
    @add_callback @store(queue), cb

  insert: (element, index = 0, cb = null) ->
    queue = @load()
    queue.splice(Math.min(index, queue.length), 0, element)
    @add_callback @store(queue), cb

  shift: () ->
    queue = @load()
    element = queue.shift()
    @notify_callback(@store(queue)) if element
    element

  pop: () ->
    queue = @load()
    element = queue.pop()
    if element
      @store(queue)
      @delete_callback(element)
    element

  first: () ->
    queue = @load()
    queue[0] if queue.length > 0

  next: (notify = true) ->
    removed = @shift()
    messages = []
    messages.push "removed #{ removed.name }" if removed

    element = @first()
    if element
      messages.push "#{ element.name } is the next"
      if notify && (user = @brain.userForName(element.name))
        @robot.send { room: user.id }, "You're next! in the ##{ @name } queue"
    else
      messages.push "queue is empty"
    [removed, messages.join(", ")]

exports.HubotQueueElement = HubotQueueElement
exports.HubotQueue = HubotQueue
