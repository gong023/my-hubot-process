Promise      = require 'bluebird'
_            = require 'underscore'
cronJob      = require('cron').CronJob
Stream       = require '../lib/feedly/stream'
FeedlyClient = require '../lib/feedly/client'
Config       = require '../lib/config'
Item         = require '../lib/feedly/item'

feedTask = (msg) ->
  client = new FeedlyClient(Config.getAccessToken())
  Stream.feedIds(client.markCounts())
  .catch (response) ->
    msg.send 'markCountsが失敗してしまいました'
    msg.send JSON.stringify(response)
  .then (feedIds) ->
    if !feedIds || feedIds.length is 0
      console.log 'フィードがありません'
      return Promise.reject()
    Promise.resolve(feedIds)
  .map (feedId) ->
    Stream.responseItems(client.streamContents(feedId))
  .catch (response, body) ->
    console.log  'streamContentsが失敗してしまいました'
    console.log  JSON.stringify(response)
    console.log  JSON.stringify(body)
  .then (items) ->
    _.each items[0], (i) ->
      message_item = new Item(i)
      message_item.hrefs()
      .then (hrefs) ->
        # title = message_item.title()
        delayLoop(hrefs, 6000, (href) -> msg.send(href))
      .catch (error) ->
        console.trace()
        console.warn(error)
    return Promise.resolve(items)
  .then (items) ->
    Stream.markCounts(client, items)
    .then (response) ->
      if response[0].statusCode isnt 200
        console.warn  '既読つけるのに失敗してしまいました'
        console.warn   JSON.stringify(response[0].body)

delayLoop = (arr, interval, callback) ->
  i = arr.length
  timerId = setInterval(() ->
    return clearInterval(timerId) if !i
    callback(arr[arr.length - i])
    i--
  , interval)

class MessageDecorator
  constructor: (@robot, @env) ->

  send: (message) ->
    @robot.send(@env, message)

module.exports = (robot) ->
  new cronJob('*/20 * * * *', () ->
    msg = new MessageDecorator(robot, {room: Config.getFeedlyRoomName()})
    feedTask(msg)
  ).start()

  robot.respond /feed$/i, (msg) ->
    feedTask(msg)

  robot.respond /help token/i, (msg) ->
    msg.send 'アクセストークンを作るリンクはこれです'
    msg.send 'https://feedly.com/v3/auth/dev'
    msg.send '詳しいことはここを見て下さい'
    msg.send 'https://groups.google.com/forum/#!topic/feedly-cloud/YHLdeRAkn-c'
    msg.send 'アクセストークンがとれたら環境変数FEEDLY_ACCESS_TOKENに入れてください'

  robot.respond /profile$/i, (msg)->
    client = new FeedlyClient(Config.getAccessToken())
    client.profile()
    .spread (response, body) ->
      msg.send response.body