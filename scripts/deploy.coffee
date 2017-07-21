# Commands:
#   hubot is staging locked? - Gets the lock status on staging

_ = require('underscore')
Heroku = require('heroku-client')
heroku = new Heroku({ token: process.env.HEROKU_API_KEY });
heroku_app_name = "rediscop"
github_app_name = "hubot"

module.exports = (robot) ->
  github = require('githubot')(robot)

  robot.respond /.* staging (un)?lock(ed)?/i, (msg) ->
    msg.send "Checking staging lock status"

    heroku.apps(heroku_app_name).builds().list (err, builds) ->
      if err
        console.log err
        msg.send "Failed to get staging lock status (Error getting list of builds from heroku)"
        return
      sorted = _(builds).sortBy (b) -> [b.created_at]
      slug = sorted[sorted.length - 1].slug
      latest_slug_id = slug.id
      unless latest_slug_id
        console.log err
        msg.send "Failed to get staging lock status (Error getting latest slug id)"
        return
      heroku.apps(heroku_app_name).slugs(latest_slug_id).info (err,info) ->
        if err
          console.log err
          msg.send "Failed to get staging lock status (Error getting slug info from heroku)"
          return
        commit = info.commit
        github.get "https://api.github.com/repos/aureliosaraiva/#{github_app_name}/compare/#{commit}...master", (comparison) ->
          if comparison.status == "identical"
            msg.send "Staging is UNLOCKED"
          else
            msg.send "Staging is LOCKED, master status is '#{comparison.status}' in relation to deployed code"
