Promise = require('promise')
github  = require("octonode").client(process.env.HUBOT_GITHUB_TOKEN or 'unknown')

try_message = (obj) ->
  (obj || {})["message"]

search_pull_request_from_branch = (shipbot, branch, repository, resolve, reject) ->
  path = '/search/issues'
  options =
    q: "type:pr+is:open+head:#{branch}+repo:#{repository}"
  github.get path, options, (err, status, body, headers) ->
    if err || ('' + status)[0] != '2' || body.items.length < 1
      error_message = try_message(err) || try_message(body) || ""
      reject("Could not find the Pull Request for branch #{branch}: #{error_message}")
    else
      fetch_pull_request_from_multiple_results repository, branch, body.items, (pull_request) ->
        merge_pull_request shipbot, pull_request, repository, resolve, reject

fetch_pull_request_from_multiple_results = (repository, expected_branch, search_results, cb) ->
  return cb(search_results[0]) if search_results.length == 1

  for pull_request in search_results
    path = "/repos/#{repository}/pulls/#{pull_request.number}"
    github.get path, {}, (err, status, body, headers) ->
      return cb(pull_request) if body.head.ref == expected_branch

merge_pull_request = (shipbot, pull_request, repository, resolve, reject) ->
  path = "/repos/#{repository}/pulls/#{pull_request.number}/merge"
  options =
    commit_message: "Merged #{pull_request.title} into master"
  github.put path, options, (err, status, body, headers) ->
    if body && body.merged
      shipbot.send_room body.message
      resolve()
    else
      error_message = try_message(err) || try_message(body)
      return reject("Could not merge the Pull Request ##{pull_request.number}: #{error_message}")

exports.run = (args, shipbot) ->
  new Promise (resolve, reject) ->
    return resolve() if args["enabled"] == false

    info = shipbot.deployment_info
    search_pull_request_from_branch shipbot, info.branch, info.application.repository, resolve, reject
