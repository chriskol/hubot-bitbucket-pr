# Hubot Bitbucket Pull Request

Holler whenever anything happens around a Bitbucket pull request

[![Build Status](https://travis-ci.org/hubot-scripts/hubot-bitbucket-pr.svg)](https://travis-ci.org/hubot-scripts/hubot-bitbucket-pr)

## Features

* Notifies room when a pull request is created, commented, declined, merged, updated, approved or unapproved
* Default room can be set with `HUBOT_BITBUCKET_PULLREQUEST_ROOM`
* Pretty formatting if using the [Slack](https://github.com/tinyspeck/hubot-slack) adapter

## Installation

In your hubot directory, run:

`npm install hubot-bitbucket-pr --save`

Then add *hubot-bitbucket-pr* to your external-scripts.json:

```json
["hubot-bitbucket-pr"]
```

## Configuration

Set up a Bitbucket Pull Request hook by checking all boxes and setting the URL to:
`{your_hubot_base_url}/hubot/bitbucket-pr`

A default room can be set with `HUBOT_BITBUCKET_PULLREQUEST_ROOM`. If this is not set, a room param is required in the URL:
`...bitbucket-pr?room={your_room_id}`

**Example**

```bash
$ heroku config:add HUBOT_BITBUCKET_PULLREQUEST_ROOM=pull-requests
# Or if you're not on Heroku
$ export HUBOT_BITBUCKET_PULLREQUEST_ROOM=pull-requests
```

### Pull Request Configuration

A list of announce events can be set with `HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE`. This comma-separated list sets what events hubot will share in the designated room. Possible options are:

* created
* updated
* declined
* merged
* comment_created
* approve
* unapprove

If left blank, hubot will announce everything.

### Issue Configuration

Issue-specific events can be appended to `HUBOT_BITBUCKET_PULLREQUEST ANNOUNCE`. Possible options are:

* issue_created
* issue_updated
* issue_comment_created

Again, if left blank, hubot will announce everything.

**Example**

```bash
$ heroku config:add HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE=created,merged,issue_created
# Or if you're not on Heroku
$ export HUBOT_BITBUCKET_PULLREQUEST_ANNOUNCE=created,merged,issue_created
```

## Commands

This is only a notifier, nothing more.

## Notes

`v0.3 >=` required the Pull Request URL be set to `...bitbucket-pr?name={your_repo_name}`. Bitbucket's Webhook 2.0 now includes the repo name in the API response; `v0.4 <=` removes this requirement as a non-breaking change.

Issue support is available in `v1.0 <=`.

## Testing

Please add a test to `test/bitbucket-pr_test.coffee` before adding a new feature.

```bash
npm install
npm run test
```
