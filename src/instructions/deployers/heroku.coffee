_          = require('underscore')
Promise    = require('promise')
Deployment = require("hubot-deploy/src/deployment").Deployment
github     = require("octonode").client(process.env.HUBOT_GITHUB_TOKEN or 'unknown')

DELAY = 15000 # 15 secounds

delay = (ms, cb) -> setTimeout cb, ms

get_last_deploy = (shipbot, reject, cb) ->
  info = shipbot.deployment_info

  path    = "/repos/#{info.application.repository}/deployments"
  options =
    environment: info.environment
    task: 'deploy',
    ref: info.branch
  github.get path, options, (err, status, body) ->
    return reject(err.message) if err
    return reject("Could not find the created deploy") if body.length == 0
    cb(body[0])

wait_deployment = (deploy, shipbot, resolve, reject) ->
  info = shipbot.deployment_info
  path = "/repos/#{info.application.repository}/deployments/#{deploy['id']}/statuses"
  github.get path, (err, status, body) ->
    state = 'pending'
    state = body[0]['state'] if body.length > 0

    if state == 'success'
      shipbot.send_room "Deployment succeeded!"
      return resolve()
    if state == 'error' || state == 'failed'
      st = body[body.length-1]
      message = "Deployment failed. See #{st['target_url']}"
      shipbot.send_author message
      return reject(message)
    delay DELAY, -> wait_deployment(deploy, shipbot, resolve, reject)

exports.run = (shipbot) ->
  new Promise (resolve, reject) ->
    info = shipbot.deployment_info
    deployment = new Deployment(info.app_name, info.branch, 'deploy', info.environment, info["force"], '')

    unless deployment.isValidApp()
      return reject "#{info.app_name}? Never heard of it."
    unless deployment.isValidEnv()
      return reject "Please provide a valid destination for the deploy"

    deployment.room = shipbot.room
    deployment.user = shipbot.user.name

    deployment.adapter = shipbot.robot.adapterName

    deployment.post (responseMessage) ->
      return reject("Unknown error trying to deploy") unless responseMessage?
      shipbot.send_room responseMessage if responseMessage?
      if responseMessage == "Deployment of #{info.app_name}/#{info.branch} to #{info.environment} created"
        get_last_deploy shipbot, reject, (deploy) ->
          wait_deployment deploy, shipbot, resolve, reject
      else
        reject(responseMessage)
