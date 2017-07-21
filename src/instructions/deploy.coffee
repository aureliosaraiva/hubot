Path    = require("path")
Promise = require('promise')

exports.run = (params, shipbot) ->
  console.log "deploy", params
  deployer = require Path.join(__dirname, 'deployers', params)
  if deployer?
    deployer.run(shipbot)
  else
    new Promise (resolve, reject) ->
      reject("Could not find the deployer for #{params}")
