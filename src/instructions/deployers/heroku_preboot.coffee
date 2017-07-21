Path    = require('path')
Promise = require('promise')
_       = require('underscore')
Heroku  = require('heroku-client')
heroku  = new Heroku({ token: process.env.HEROKU_API_KEY })
heroku_deployer = require(Path.join(__dirname, "heroku"))

NEEDED_DYNOS_FOR_PREBOOT = 2
MINUTES = 60 * 1000

delay = (ms, cb) -> setTimeout cb, ms

wait_dynos_switch = (shipbot, resolve) ->
  shipbot.send_room "Waiting Heroku preboot..."
  # TODO improve this verification when heroku comes up with an API for that
  #      or by checking logs output because heroku says that he sends sigterm
  #      for the old dyno when the new dyno is ready and serving - Mats
  delay 3 * MINUTES, ->
    shipbot.send_room "Your deployment should be available in #{shipbot.environment}", "I'll restore dynos' quantity after 2 minutes from now just for precaution"
    delay 2 * MINUTES , resolve

deploy = (shipbot, resolve, reject) ->
  heroku_deployer.run(shipbot).then () ->
    wait_dynos_switch(shipbot, resolve)
  , reject

scale = (app_name, formation_id, quantity, cb) ->
  heroku.patch "/apps/#{app_name}/formation/#{formation_id}", { quantity: quantity }, cb

exports.run = (shipbot) ->
  new Promise (resolve, reject) ->
    info = shipbot.deployment_info
    app_name = info.heroku_app_name
    heroku.get "/apps/#{app_name}/formation", (err, formations) ->
      return reject "Failed to get the list of dynos" if err

      web_formations = _(formations).filter((formation) -> formation.type == 'web')
      if web_formations.length != 1
        return reject "Sorry, currently we only support single sized web dynos at once, got: #{web_formations.length}"

      formation = web_formations[0]
      previous_quantity = formation.quantity
      return deploy(shipbot, resolve, reject) unless previous_quantity < NEEDED_DYNOS_FOR_PREBOOT

      scale app_name, formation.id, NEEDED_DYNOS_FOR_PREBOOT, (err, f) ->
        return reject "Failed to update the dynos quantity, please do it manually. Error: #{err.message}" if err

        shipbot.send_room "Updated the quantity of web dynos from #{previous_quantity} to #{NEEDED_DYNOS_FOR_PREBOOT}"
        deploy shipbot, () ->
          scale app_name, formation.id, previous_quantity, (err, f) ->
            return reject "Deploy succeeded but, Failed to restore the dynos quantity from #{NEEDED_DYNOS_FOR_PREBOOT} to #{previous_quantity}, please restore it manually. Error: #{err.message}" if err
            shipbot.send_room "Restoring the quantity of web dynos from #{NEEDED_DYNOS_FOR_PREBOOT} to #{previous_quantity}"
            resolve()
        , (error) ->
          scale app_name, formation.id, previous_quantity, (err, f) ->
            return reject "Failed to deploy and to restore the dynos quantity to #{previous_quantity}, please restore it manually. Errors: '#{error}' and '#{err}' respectively" if err
            shipbot.send_room "Restoring the quantity of web dynos from #{NEEDED_DYNOS_FOR_PREBOOT} to #{previous_quantity}"
            reject(error)
