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

getEnvAnnounceOptions = ->
  # Replace announce options if set in the environment
  if process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE
    process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE.replace(/[^a-z\,]+/, '').split(',')
  # Fall back to default actions to announce
  else
    ['created', 'updated', 'declined', 'merged', 'comment_created', 'approve', 'unapprove']

ANNOUNCE_OPTIONS = getEnvAnnounceOptions()

ENCOURAGEMENTS = [
  ':thumbsup:', 'That was a nice thing you did.', 'Boomtown',
  'BOOM', 'Finally.', 'And another request bites the dust.'
]

encourageMe = ->
  ENCOURAGEMENTS[Math.floor(Math.random() * ENCOURAGEMENTS.length)]

class PullRequestEvent
  constructor: (@robot, @resp, @type) ->
    @actor = @resp.actor.display_name
    @title = @resp.pullrequest.title
    @source_branch = @resp.pullrequest.source.branch.name
    @destination_branch = @resp.pullrequest.destination.branch.name
    @repo_name = @resp.repository.name
    @pr_link = @resp.pullrequest.links.html.href
    @reason = "."
    if @resp.reason isnt ''
      if @resp.pullrequest.reason isnt ''
        @reason = ":\n\"#{@resp.pullrequest.reason}\""

  getReviewers: ->
    if @resp.pullrequest.reviewers.length > 0
      reviewer_names = for reviewer in @resp.pullrequest.reviewers
        "#{reviewer.display_name}"
      reviewer_names.join(", ")
    else
      'no one in particular'

  branchAction: (action_name, action_desc) ->
    "#{@actor} *#{action_name}* pull request \"#{@title},\" #{action_desc}
    `#{@source_branch}` and `#{@destination_branch}` into a `#{@repo_name}`
    super branch#{@reason}"

  getMessage: ->
    switch
      # PR created
      when @type is 'pullrequest:created' && 'created' in ANNOUNCE_OPTIONS
        @robot.logger.debug "Pull request created"
        @pullRequestCreated()

      # Comment created
      when @type is 'pullrequest:comment_created' && 'comment_created' in ANNOUNCE_OPTIONS
        @robot.logger.debug "Pull request comment created"
        @pullRequestCommentCreated()

      # Declined
      when @type is 'pullrequest:rejected' && 'declined' in ANNOUNCE_OPTIONS
        @robot.logger.debug "Pull request rejected"
        @pullRequestDeclined()

      # Merged
      when @type is 'pullrequest:fulfilled' && 'merged' in ANNOUNCE_OPTIONS
        @robot.logger.debug "Pull request merged"
        @pullRequestMerged()

      # Updated
      when @type is 'pullrequest:updated' && 'updated' in ANNOUNCE_OPTIONS
        @robot.logger.debug "Pull request updated"
        @pullRequestUpdated()

      # Approved
      when @type is 'pullrequest:approved' && 'approve' in ANNOUNCE_OPTIONS
        @robot.logger.debug "Pull request approved"
        @pullRequestApproved()

      # Unapproved
      when @type is 'pullrequest:unapproved' && 'unapprove' in ANNOUNCE_OPTIONS
        @robot.logger.debug "Pull request unapproved"
        @pullRequestUnapproved()

  pullRequestCreated: ->
    "Yo #{@getReviewers()}, #{@actor} just *created* the pull request
    \"#{@title}\" for `#{@source_branch}` on `#{@repo_name}`.
    \n#{@pr_link}"

  pullRequestCommentCreated: ->
    "#{@actor} *added a comment* on `#{@repo_name}`:
    \"#{@resp.comment.content.raw}\"\n#{@resp.comment.links.html.href}"

  pullRequestDeclined: ->
    @branchAction('declined', 'thwarting the attempted merge of') + "\n#{@pr_link}"

  pullRequestMerged: ->
    @branchAction('merged', 'joining in sweet harmony')

  pullRequestUpdated: ->
    @branchAction('updated', 'clarifying why it is necessary to merge') + "\n#{@pr_link}"

  pullRequestApproved: ->
    "A pull request on `#{@repo_name}` has been approved by #{@actor}
    \n#{encourageMe()}\n#{@pr_link}"

  pullRequestUnapproved: ->
    "A pull request on `#{@repo_name}` has been unapproved by #{@actor}\n#{@pr_link}"

class SlackPullRequestEvent extends PullRequestEvent
  GREEN: '#48CE78'
  BLUE: '#286EA6'
  RED: '#E5283E'
  PURPLE: '#AA82E5'
  ORANGE: '#F1A56F'

  branchAction: (action_name, color) ->
    fields = []
    fields.push
      title: @title
      value: @resp.pullrequest.reason
      short: true
    fields.push
      title: "#{@repo_name} (#{@source_branch})"
      value: @pr_link
      short: true

    payload =
      text: "Pull Request #{action_name} by #{@actor}"
      fallback: "#{@actor} *#{action_name}* pull request \"#{@title}\"."
      pretext: ''
      color: color
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: fields

  pullRequestCreated: ->
    reviewers = @getReviewers()
    content =
      text: "New Request from #{@actor}"
      fallback: "Yo #{reviewers}, #{@actor} just *created* the pull request
                 \"#{@title}\" for `#{@source_branch}` on `#{@repo_name}`."
      pretext: ''
      color: @BLUE
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: @title
          value: "Requesting review from #{reviewers}"
          short: true
        }
        {
          title: @repo_name
          value: "Merge #{@source_branch} to #{@destination_branch}\n<#{@pr_link}|View on Bitbucket>"
          short: true
        }
      ]

  pullRequestCommentCreated: ->
    content =
      text: ''
      fallback: "#{@actor} *added a comment* on `#{@repo_name}`:
                 \"#{@resp.comment.content.raw}\"
                 \n\n#{@resp.comment.links.html.href}"
      pretext: ''
      color: @ORANGE
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: "#{@actor} commented"
          value: @resp.comment.content.raw
          short: true
        }
        {
          title: "#{@repo_name} (<#{@pr_link}|#{@source_branch}>)"
          value: "<#{@resp.comment.links.html.href}|Read on Bitbucket>"
          short: true
        }
      ]

  pullRequestDeclined: ->
    @branchAction('Declined', @RED)

  pullRequestMerged: ->
    @branchAction('Merged', @GREEN)

  pullRequestUpdated: ->
    @branchAction('Updated', @PURPLE)

  pullRequestApproved: ->
    content =
      text: "Pull Request Approved"
      fallback: "A pull request on `#{@repo_name}` has been
                 approved by #{@actor}\n#{encourageMe()}"
      pretext: encourageMe()
      color: @GREEN
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: @title
          value: "Approved by #{@actor}"
          short: true
        }
        {
          title: @repo_name
          value: "<#{@pr_link}|View on Bitbucket>"
          short: true
        }
      ]

  pullRequestUnapproved: ->
    content =
      text: "Pull Request Unapproved"
      fallback: "A pull request on `#{@repo_name}` has been
                 unapproved by #{@actor}"
      pretext: 'Foiled!'
      color: @RED
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: @actor
          value: @title
          short: true
        }
        {
          title: @repo_name
          value: "<#{@pr_link}|View on Bitbucket>"
          short: true
        }
      ]

module.exports = (robot) ->
  robot.router.post '/hubot/bitbucket-pr', (req, res) ->
    resp = req.body

    # Really don't understand why this isn't in the response body
    # https://confluence.atlassian.com/bitbucket/event-payloads-740262817.html#EventPayloads-HTTPHeaders
    type = req.headers['x-event-key']

    # Fallback to default Pull request room
    room = req.query.room ? DEFAULT_ROOM

    # Slack special formatting
    if robot.adapterName is 'slack'
      event = new SlackPullRequestEvent(robot, resp, type)

      msg =
        message:
          reply_to: room
          room: room

      msg.content = event.getMessage()
      robot.emit 'slack-attachment', msg

    # For hubot adapters that are not Slack
    else
      event = new PullRequestEvent(robot, resp, type)
      msg = event.getMessage()
      robot.messageRoom room, msg

    # Close response
    res.writeHead 204, { 'Content-Length': 0 }
    res.end()
