_       = require('underscore')
Promise = require('promise')
github  = require("octonode").client(process.env.HUBOT_GITHUB_TOKEN or 'unknown')

DELAY = 15000
MAX_CHECK = 4

delay = (ms, cb) -> setTimeout cb, ms

is_error = (state) ->
  state == 'error' || state == 'failed'

check_status = (opts, counter = MAX_CHECK) ->
  { shipbot, repository, ref, regex, resolve, reject } = opts
  path = "repos/#{repository}/commits/#{ref}/statuses"

  github.get path, (err, status, body, headers) ->
    return reject(err['message']) if err
    if body.length == 0 && counter > 0
      return delay DELAY, -> check_status opts, (counter - 1)

    states = {}
    _(body).each (st) ->
      context = st['context']
      state = st['state']
      states[context] = state if context.match(regex) && !states[context]

    for context, state of states
      return reject("Sorry unmet needed preconditions") if is_error(state)
      if state == 'pending'
        return delay DELAY, -> check_status opts

    shipbot.send_room "All Good, please continue"
    resolve()

exports.run = (regex, shipbot) ->
  new Promise (resolve, reject) =>
    return resolve() if regex == ""

    info = shipbot.deployment_info
    opts =
      shipbot: shipbot
      repository: info.application.repository
      ref: info.branch
      regex: regex
      resolve: resolve
      reject: reject

    shipbot.send_room "Checking preconditions..."
    check_status opts
