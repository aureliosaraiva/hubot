exports.run = (params, shipbot) ->
  shipbot.execute(params.task, params["params"] || {})
