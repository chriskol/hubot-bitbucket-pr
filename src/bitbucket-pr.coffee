# Description:
#   Holler whenever anything happens around a Bitbucket pull request
#
# Configuration:
#   Set up a Bitbucket Pull Request hook with the URL
#   {your_hubot_base_url}/hubot/bitbucket-pr. Check all boxes on prompt.
#   A default room can be set with HUBOT_BITBUCKET_PULLREQUEST_ROOM.
#   If this is not set, a room param is required:
#   ...bitbucket-pr?room={your_room_id}
#
# Author:
#   tshedor

DEFAULT_ROOM = process.env.HUBOT_BITBUCKET_PULLREQUEST_ROOM


module.exports = (robot) ->
  robot.router.post '/hubot/bitbucket-pr', (req, res) ->

    # Set default actions to announce
    announce_options = ['created', 'updated', 'declined', 'merged', 'comment_created', 'approve', 'unapprove']

    # Replace announce options if set in the environment
    if process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE
      announce_options = process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE.replace(/[^a-z\,]+/, '').split(',')


    resp = req.body

    # Really don't understand why this isn't in the response body
    # https://confluence.atlassian.com/bitbucket/event-payloads-740262817.html#EventPayloads-HTTPHeaders
    type = req.headers['x-event-key']

    msg = ''

    cached_vars = {
      actor: resp.actor.display_name
      title: resp.pullrequest.title
      source_branch: resp.pullrequest.source.branch.name
      destination_branch: resp.pullrequest.destination.branch.name
      repo_name: resp.repository.name
      pr_link: resp.pullrequest.links.html.href
    }
    # Fallback to default Pull request room
    room = req.query.room ? DEFAULT_ROOM

    # Slack special formatting
    if robot.adapterName is 'slack'
      green = '#48CE78'
      blue = '#286EA6'
      red = '#E5283E'
      purple = '#AA82E5'
      orange = '#F1A56F'

      msg =
        message:
          reply_to: room
          room: room

      # Created
      if type is 'pullrequest:created' && ('created' in announce_options)
        reviewers = get_reviewers(resp)
        content =
          text: "New Request from #{cached_vars.actor}"
          fallback: "Yo#{reviewers}, #{cached_vars.actor} just *created* the pull request \"#{cached_vars.title}\" for `#{cached_vars.source_branch}` on `#{cached_vars.repo_name}`."
          pretext: ''
          color: blue
          mrkdwn_in: ["text", "title", "fallback", "fields"]
          fields: [
            {
              title: cached_vars.title
              value: "Requesting review from#{reviewers}"
              short: true
            }
            {
              title: cached_vars.repo_name
              value: "Merge to #{cached_vars.destination_branch}\n#{cached_vars.pr_link}"
              short: true
            }
          ]

      # Comment added
      if type is 'pullrequest:comment_created' && ('comment_created' in announce_options)
        content =
          text: ''
          fallback: "#{cached_vars.actor} *added a comment* on `#{cached_vars.repo_name}`: \"#{resp.comment.content.raw}\" \n\n#{resp.comment.links.html.href}"
          pretext: ''
          color: orange
          mrkdwn_in: ["text", "title", "fallback", "fields"]
          fields: [
            {
              title: "#{cached_vars.actor} commented"
              value: resp.comment.content.raw
              short: true
            }
            {
              title: "#{cached_vars.repo_name} (#{cached_vars.source_branch})"
              value: resp.comment.links.html.href
              short: true
            }
          ]

      # Declined
      if type is 'pullrequest:rejected' && ('declined' in announce_options)
        content = branch_action(resp, 'Declined', cached_vars, red)

      # Merged
      if type is 'pullrequest:fulfilled' && ('merged' in announce_options)
        content = branch_action(resp, 'Merged', cached_vars, green)

      # Updated
      if type is 'pullrequest:updated' && ('updated' in announce_options)
        content = branch_action(resp, 'Updated', cached_vars, purple)

      # Approved
      if type is 'pullrequest:approved' && ('approve' in announce_options)
        encourage_array = [':thumbsup:', 'That was a nice thing you did.', 'Boomtown', 'BOOM', 'Finally.', 'And another request bites the dust.']
        encourage_me = encourage_array[Math.floor(Math.random()*encourage_array.length)];
        content =
          text: "Pull Request Approved"
          fallback: "A pull request on `#{cached_vars.repo_name}` has been approved by #{cached_vars.actor}\n#{encourage_me}"
          pretext: encourage_me
          color: green
          mrkdwn_in: ["text", "title", "fallback", "fields"]
          fields: [
            {
              title: cached_vars.title
              value: "Approved by #{cached_vars.actor}"
              short: true
            }
            {
              title: cached_vars.repo_name
              value: cached_vars.pr_link
              short: true
            }
          ]

      # Unapproved
      if type is 'pullrequest:unapproved' && ('unapprove' in announce_options)
        content =
          text: "Pull Request Unapproved"
          fallback: "A pull request on `#{cached_vars.repo_name}` has been unapproved by #{cached_vars.actor}"
          pretext: 'Foiled!'
          color: red
          mrkdwn_in: ["text", "title", "fallback", "fields"]
          fields: [
            {
              title: cached_vars.actor
              value: cached_vars.title
              short: true
            }
            {
              title: cached_vars.repo_name
              value: cached_vars.pr_link
              short: true
            }
          ]

      msg.content = content
      robot.emit 'slack-attachment', msg

    # For hubot adapters that are not Slack
    else

      # PR created
      if type is 'pullrequest:created' && ('created' in announce_options)
        reviewers = get_reviewers(resp)

        msg = "Yo#{reviewers}, #{cached_vars.actor} just *created* the pull request \"#{cached_vars.title}\" for `#{cached_vars.source_branch}` on `#{cached_vars.repo_name}`."
        msg += "\n#{cached_vars.pr_link}"

      # Comment created
      if type is 'pullrequest:comment_created' && ('comment_created' in announce_options)
        msg = "#{cached_vars.actor} *added a comment* on `#{cached_vars.repo_name}`: \"#{resp.comment.content.raw}\" "
        msg += "\n#{resp.comment.links.html.href}"

      # Declined
      if type is 'pullrequest:rejected' && ('declined' in announce_options)
        msg = branch_action(resp, 'declined', 'thwarting the attempted merge of', cached_vars)
        msg += "\n#{cached_vars.pr_link}"

      # Merged
      if type is 'pullrequest:fulfilled' && ('merged' in announce_options)
        msg = branch_action(resp, 'merged', 'joining in sweet harmony', cached_vars)

      # Updated
      if type is 'pullrequest:updated' && ('updated' in announce_options)
        msg = branch_action(resp, 'updated', 'clarifying why it is necessary to merge', cached_vars)
        msg += "\n#{cached_vars.pr_link}"

      # Approved
      if type is 'pullrequest:approved' && ('approve' in announce_options)
        msg = "A pull request on `#{cached_vars.repo_name}` has been approved by #{cached_vars.actor}"
        encourage_array = [':thumbsup:', 'That was a nice thing you did.', 'Boomtown', 'BOOM', 'Finally.', 'And another request bites the dust.']
        encourage_me = encourage_array[Math.floor(Math.random()*encourage_array.length)];
        msg += "\n#{encourage_me}"
        msg += "\n#{cached_vars.pr_link}"

      # Unapproved
      if type is 'pullrequest:unapproved' && ('unapprove' in announce_options)
        msg = "A pull request on `#{cached_vars.repo_name}` has been unapproved by #{cached_vars.actor}"
        msg += "\n#{cached_vars.pr_link}"

      robot.messageRoom room, msg

    # Close response
    res.writeHead 204, { 'Content-Length': 0 }
    res.end()


  get_reviewers = (resp) ->
    if resp.pullrequest.reviewers.length > 0
      reviewers = ''
      for reviewer in resp.pullrequest.reviewers
        reviewers += " #{reviewer.display_name}"
    else
      reviewers = ' no one in particular'

    return reviewers

  # Consolidate redundant formatting with branch_action func

  if robot.adapterName is 'slack'

    branch_action = (resp, action_name, cached_vars, color) ->
      fields = []
      fields.push
        title: cached_vars.title
        value: resp.pullrequest.reason
        short: true
      fields.push
        title: "#{cached_vars.repo_name} (#{cached_vars.source_branch})"
        value: cached_vars.pr_link
        short: true

      payload =
        text: "Pull Request #{action_name} by #{cached_vars.actor}"
        fallback: "#{cached_vars.actor} *#{action_name}* pull request \"#{cached_vars.title}\"."
        pretext: ''
        color: color
        mrkdwn_in: ["text", "title", "fallback", "fields"]
        fields: fields

      return payload

  else

    branch_action = (resp, action_name, action_desc, cached_vars) ->
      msg = "#{cached_vars.actor} *#{action_name}* pull request \"#{cached_vars.title},\" #{action_desc} `#{cached_vars.source_branch}` and `#{cached_vars.destination_branch}` into a `#{cached_vars.repo_name}` super branch"
      msg += if resp.reason isnt '' then ":\n\"#{resp.pullrequest.reason}\"" else "."

      return msg
