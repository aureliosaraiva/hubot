Promise = require('promise')
github  = require("octonode").client(process.env.HUBOT_GITHUB_TOKEN or 'unknown')

exports.run = (args, shipbot) ->
  new Promise (resolve, reject) ->
    return resolve() if args["enabled"] == false

    info     = shipbot.deployment_info
    from     = (args["from"] || "master").replace("$branch", info.branch)
    into     = (args["into"] || info.branch).replace("$branch", info.branch)
    message  = "[ci run] Merged #{from} into #{into}"
    path     = "/repos/#{info.application.repository}/merges"
    options  =
      base: into,
      head: from,
      commit_message: message
    shipbot.send_room "Merging #{from} into #{into}"
    github.post path, options, (err, status, body, headers) ->
      str_status = ('' + status)
      if err
        return reject("There's something wrong with #{shipbot.robot.name}: #{err.message}")
      if str_status[0] != '2'
        message = body.message || 'Merge Error'
        return reject("#{message}: Please merge it mannually and type `#{shipbot.robot.name} ship current!` to continue.")

      shipbot.send_room message if str_status == '201'
      shipbot.send_room "#{into} is already up to date with #{from}" if str_status == '204'
      resolve()
