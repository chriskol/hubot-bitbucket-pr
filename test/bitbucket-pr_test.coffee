# https://amussey.github.io/2015/08/11/testing-hubot-scripts.html

Coffee = require('coffee-script')
fs = require('fs')

Helper = require('hubot-test-helper')
expect = require('chai').expect
sinon = require('sinon')

# contents = Coffee.compile( fs.readFileSync('./src/bitbucket-pr.coffee', 'utf8')+'' )
# eval( contents )

# helper loads a specific script if it's a file
helper = new Helper('../src/bitbucket-pr.coffee')

ROBOT = helper.createRoom().robot

CREATED_RESP = require('./support/created.json')
COMMENT_RESP = require('./support/comment.json')
MERGED_RESP = require('./support/merged.json')
UPDATED_RESP = require('./support/updated.json')
APPROVED_RESP = require('./support/approved.json')
UNAPPROVED_RESP = require('./support/unapproved.json')

pre = PullRequestEvent('', APPROVED_RESP, 'pullrequest:created')

describe 'PullRequestEvent', ->
  pre = null

  context 'pull request event is created', ->
    expect( pre.actor ).to.eql 'Emma'
    expect( pre.title ).to.eql 'Title of pull request'
    expect( pre.source_branch ).to.eql 'branch2'
    expect( pre.destination_branch ).to.eql 'master'
    expect( pre.repo_name ).to.eql 'repo_name'
    expect( pre.pr_link ).to.eql 'https://api.bitbucket.org/emmap1'
    expect( pre.reason ).to.eql ':"reason for declining the PR (if applicable)"'

  context '.getReviewers()', ->
    reviewers = pre.getReviewers()
    expect( reviewers ).to.eql 'Emma, Hank'

  context '.branchAction()', ->
    action = pre.branchAction('created', 'thwarting the attempted merge of')

    expect( pre.branchAction ).to.eql 'Emma *created* pull request "Title of pull request," thwarting the attempted merge of `branch2` and `master` into a `repo_name` super branch:"reason for declining the PR (if applicable)"'

describe 'bitbucket-pr', ->
  room = null

  beforeEach ->
    room = helper.createRoom()

  afterEach ->
    room.destroy()
