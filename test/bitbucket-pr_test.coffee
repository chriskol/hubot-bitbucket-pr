# https://amussey.github.io/2015/08/11/testing-hubot-scripts.html

Coffee = require('coffee-script')
fs = require('fs')

Helper = require('hubot-test-helper')
expect = require('chai').expect

# Compile without the function wrapper so we can test the PullRequestEvent class
contents = Coffee.compile( fs.readFileSync('./src/bitbucket-pr.coffee', 'utf8')+'', bare: true )
eval( contents )

# helper loads a specific script if it's a file
helper = new Helper('../src/bitbucket-pr.coffee')

ROBOT = helper.createRoom().robot

CREATED_RESP = require('./support/created.json')
COMMENT_RESP = require('./support/comment.json')
MERGED_RESP = require('./support/merged.json')
UPDATED_RESP = require('./support/updated.json')
APPROVED_RESP = require('./support/approved.json')
UNAPPROVED_RESP = require('./support/unapproved.json')

# Mock robot for the logger.debug functions in getMessage
MOCK_ROBOT =
  logger:
    debug: (str) ->
      str

describe 'getEnvAnnounceOptions()', ->
  beforeEach ->
    @original_process_var = process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE

  afterEach ->
    process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE = @original_process_var

  context 'process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE is not set', ->
    it 'should fallback to the default variables', ->
      delete process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE

      generated_announce_options = getEnvAnnounceOptions()
      expect( generated_announce_options ).to.eql ['created', 'updated', 'declined', 'merged', 'comment_created', 'approve', 'unapprove']

  context 'process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE is "created,merged"', ->
    it 'should generate an array from the provided variable', ->
      process.env.HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE = 'created,merged'

      generated_announce_options = getEnvAnnounceOptions()
      expect( generated_announce_options ).to.eql ['created', 'merged']

describe 'encourageMe()', ->
  it 'should contain an encouragement and be a string', ->
    generated_encouragement = encourageMe()

    expect( ENCOURAGEMENTS ).to.include generated_encouragement
    expect( generated_encouragement ).to.be.a 'string'

describe 'PullRequestEvent', ->
  pre = null

  beforeEach ->
    pre = new PullRequestEvent(MOCK_ROBOT, CREATED_RESP, 'pullrequest:created')

  # Clear variable
  afterEach ->
    pre = null

  describe '#constructor', ->

    it 'should have all instance attributes', ->
      expect( pre.actor ).to.eql 'Emma'
      expect( pre.title ).to.eql 'Title of pull request'
      expect( pre.source_branch ).to.eql 'branch2'
      expect( pre.destination_branch ).to.eql 'master'
      expect( pre.repo_name ).to.eql 'repo_name'
      expect( pre.pr_link ).to.eql 'https://api.bitbucket.org/pullrequest_id'
      expect( pre.reason ).to.eql ':\n"reason for declining the PR (if applicable)"'

  describe '#getReviewers()', ->
    it 'should have reviewers', ->
      reviewers = pre.getReviewers()
      expect( reviewers ).to.eql 'Emma, Hank'

  describe '#branchAction()', ->
    it 'should have a custom message', ->
      action = pre.branchAction('created', 'thwarting the attempted merge of')

      expect( action ).to.eql 'Emma *created* pull request "Title of pull request," thwarting the attempted merge of `branch2` and `master` into a `repo_name` super branch:\n"reason for declining the PR (if applicable)"'

  describe '#getMessage()', ->
    it 'should provide the message for pullrequest:created', ->
      message = pre.getMessage()

      expect( message ).to.eql 'Yo Emma, Hank, Emma just *created* the pull request "Title of pull request" for `branch2` on `repo_name`. \nhttps://api.bitbucket.org/pullrequest_id'

describe 'bitbucket-pr', ->
  room = null

  beforeEach ->
    room = helper.createRoom()

  afterEach ->
    room.destroy()
