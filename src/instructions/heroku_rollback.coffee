_       = require('underscore')
Promise = require('promise')
Heroku  = require('heroku-client')
heroku  = new Heroku({ token: process.env.HEROKU_API_KEY })

fail = (reject, message) ->
  reject("Failed to rollback, please do it mannually: #{message}")

exports.run = (params, shipbot) ->
  new Promise (resolve, reject) ->
    info = shipbot.deployment_info
    app_name = info.heroku_app_name

    options =
      method: 'GET',
      path: "/apps/#{app_name}/releases",
      headers:
        'Range': 'version ..; order=desc,max=2'

    heroku.request options, (err, releases) ->
      return fail(reject, "Could not retrieve the list of releases") if err
      return fail(reject, "I need at least 2 releases to be able to rollback") if releases.length < 2

      previous = releases[1]
      options =
        release: previous['id']
      heroku.post "/apps/#{app_name}/releases", options, (err, release) ->
        return fail(reject, "Could not complete rollback request") if err

        shipbot.send_room "Rollback succeeded!"
        resolve()
