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
    ['created', 'updated', 'declined', 'merged', 'comment_created', 'approve', 'unapprove', 'issue_created', 'issue_comment_created', 'issue_updated']

ANNOUNCE_OPTIONS = getEnvAnnounceOptions()

encourageMe = ->
  encouragements = [
    ':thumbsup:', 'That was a nice thing you did.', 'Boomtown',
    'BOOM', 'Finally.', 'And another request bites the dust.'
  ]

  encouragements[Math.floor(Math.random() * encouragements.length)]

COLORS =
  created: '#286EA6'
  commented: '#F1A56F'
  rejected: '#E5283E'
  merged: '#48CE78'
  updated: '#AA82E5'
  approved: '#48CE78'
  declined: '#E5283E'
  unapproved: '#E5283E'

class PullRequestEvent
  constructor: (@robot, @resp, @type) ->
    @actor = @resp.actor.display_name
    @repo_name = @resp.repository.name

    if /pullrequest/.test(@type)
      @title = @resp.pullrequest.title
      @source_branch = @resp.pullrequest.source.branch.name
      @destination_branch = @resp.pullrequest.destination.branch.name
      @link = @resp.pullrequest.links.html.href
      @reason = "."
      if @resp.reason isnt ''
        if @resp.pullrequest.reason isnt ''
          @reason = ":\n\"#{@resp.pullrequest.reason}\""
    else
      @title = @resp.issue.title
      @link = @resp.issue.links.html.href
      @type = @resp.issue.type
      @priority = @resp.issue.priority
      @state = @resp.issue.state

  getReviewers: ->
    if @resp.pullrequest.reviewers.length > 0
      reviewer_names = for reviewer in @resp.pullrequest.reviewers
        "#{reviewer.display_name}"
      reviewer_names.join(', ')
    else
      'no one in particular'

  pullRequestGenericAction: (action_name, action_desc) ->
    "#{@actor} *#{action_name}* pull request \"#{@title},\" #{action_desc}
    `#{@source_branch}` and `#{@destination_branch}` into a `#{@repo_name}`
    super branch#{@reason}"

  issueGenericAction: (action_name, action_desc) ->
    "#{@actor} #{action_name} issue *#{@title}* for #{@repo_name}#{action_desc}\n#{@link}"

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

      # Issue created
      when @type is 'issue:created' && 'issue_created' in ANNOUNCE_OPTIONS
        @robot.logger.debug "Issue created"
        @issueCreated()

      # Issue comment created
      when @type is 'issue:comment_created' && 'issue_comment_created' in ANNOUNCE_OPTIONS
        @robot.logger.debug "Issue comment created"
        @issueCommentCreated()

      # Issue updated
      when @type is 'issue:updated' && 'issue_updated' in ANNOUNCE_OPTIONS
        @robot.logger.debug "Issue updated"
        @issueUpdated()

  pullRequestCreated: ->
    "Yo #{@getReviewers()}, #{@actor} just *created* the pull request
    \"#{@title}\" for `#{@source_branch}` on `#{@repo_name}`.
    \n#{@link}"

  pullRequestCommentCreated: ->
    "#{@actor} *commented on* `#{@repo_name}`:
    \"#{@resp.comment.content.raw}\"\n#{@resp.comment.links.html.href}"

  pullRequestDeclined: ->
    @pullRequestGenericAction('declined', 'thwarting the attempted merge of') + "\n#{@link}"

  pullRequestMerged: ->
    @pullRequestGenericAction('merged', 'joining in sweet harmony')

  pullRequestUpdated: ->
    @pullRequestGenericAction('updated', 'clarifying why it is necessary to merge') + "\n#{@link}"

  pullRequestApproved: ->
    "A pull request on `#{@repo_name}` has been approved by #{@actor}
    \n#{encourageMe()}\n#{@link}"

  pullRequestUnapproved: ->
    "A pull request on `#{@repo_name}` has been unapproved by #{@actor}\n#{@link}"

  issueCreated: ->
    @issueGenericAction('created', '')

  issueCommentCreated: ->
    @issueGenericAction('commented on', ": #{@resp.comment.content}")

  issueUpdated: ->
    @issueGenericAction('updated', '')

class SlackPullRequestEvent extends PullRequestEvent
  pullRequestGenericAction: (action_name, color) ->
    content =
      text: "Pull Request #{action_name} by #{@actor}"
      fallback: "#{@actor} *#{action_name}* pull request \"#{@title}\"."
      pretext: ''
      color: color
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: @title
          value: @resp.pullrequest.reason
          short: true
        }
        {
          title: "#{@repo_name} (#{@source_branch})"
          value: "<#{@link}|View on Bitbucket>"
          short: true
        }
      ]

  pullRequestCreated: ->
    reviewers = @getReviewers()
    content =
      text: "New Request from #{@actor}"
      fallback: "Yo #{reviewers}, #{@actor} just *created* the pull request
                 \"#{@title}\" for `#{@source_branch}` on `#{@repo_name}`."
      pretext: ''
      color: COLORS.created
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: @title
          value: "Requesting review from #{reviewers}"
          short: true
        }
        {
          title: @repo_name
          value: "Merge #{@source_branch} to #{@destination_branch}\n<#{@link}|View on Bitbucket>"
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
      color: COLORS.commented
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: "#{@actor} commented"
          value: @resp.comment.content.raw
          short: true
        }
        {
          title: "#{@repo_name} (#{@source_branch})"
          value: "<#{@resp.comment.links.html.href}|Read on Bitbucket>"
          short: true
        }
      ]

  pullRequestDeclined: ->
    @pullRequestGenericAction('Declined', COLORS.declined)

  pullRequestMerged: ->
    @pullRequestGenericAction('Merged', COLORS.merged)

  pullRequestUpdated: ->
    @pullRequestGenericAction('Updated', COLORS.updated)

  pullRequestApproved: ->
    content =
      text: "Pull Request Approved"
      fallback: "A pull request on `#{@repo_name}` has been
                 approved by #{@actor}\n#{encourageMe()}"
      pretext: encourageMe()
      color: COLORS.approved
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: @title
          value: "Approved by #{@actor}"
          short: true
        }
        {
          title: @repo_name
          value: "<#{@link}|View on Bitbucket>"
          short: true
        }
      ]

  pullRequestUnapproved: ->
    content =
      text: "Pull Request Unapproved"
      fallback: "A pull request on `#{@repo_name}` has been
                 unapproved by #{@actor}"
      pretext: 'Foiled!'
      color: COLORS.unapproved
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: @actor
          value: @title
          short: true
        }
        {
          title: @repo_name
          value: "<#{@link}|View on Bitbucket>"
          short: true
        }
      ]

  issueCreated: ->
    content =
      text: "New Issue from #{@actor}"
      fallback: "#{@actor} created an issue *#{@title}* for #{@repo_name}\n#{@link}"
      pretext: ''
      color: COLORS.created
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: "#{@title} (#{@type})"
          value: "#{@priority} priority"
          short: true
        }
        {
          title: @repo_name
          value: "<#{@link}|View on Bitbucket>"
          short: true
        }
      ]

  issueCommentCreated: ->
    content =
      text: ''
      fallback: "#{@actor} added a comment to issue *#{@title}* for #{@repo_name}\n#{@link}"
      pretext: ''
      color: COLORS.commented
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: "#{@actor} commented"
          value: @resp.comment.content.raw
          short: true
        }
        {
          title: "#{@title} (#{@repo_name})"
          value: "<#{@resp.comment.links.html.href}|Read on Bitbucket>"
          short: true
        }
      ]

  issueChangedFields: ->
    "*#{field}*: #{change.old} -> #{change.new}" for field, change of @resp.changes

  issueUpdated: ->
    changed_fields = @issueChangedFields()

    content =
      text: "Issue updated by #{@actor}"
      fallback: "#{@actor} updated issue *#{@title}* with the following changes: #{changed_fields.join(', ')} for #{@repo_name}\n#{@link}"
      pretext: ''
      color: COLORS.updated
      mrkdwn_in: ["text", "title", "fallback", "fields"]
      fields: [
        {
          title: "#{@actor} changed"
          value: changed_fields.join("\n")
          short: true
        }
        {
          title: "#{@title} (#{@repo_name})"
          value: "<#{@link}|View on Bitbucket>"
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
