Promise = require 'bluebird'
Config  = require '../config'
_       = require 'underscore'

Stream =
  feedIds: (api_promise) ->
    whiteListCategories = Config.getWhiteListCategories()
    blackListCategories = Config.getBlackListCategories()

    api_promise.spread (response, body) ->
      return Promise.reject(response) if response.statusCode isnt 200
      feedIds =
        _.chain(JSON.parse(body).unreadcounts)
          .reject((content) -> content.count is 0 )
          .filter (content) ->
            # whitelist の指定も blacklist の指定もなかったら全部とる
            return true if whiteListCategories isnt undefined or blackListCategories isnt undefined
            content.id.match(/global\.all$/)
          .filter (content) ->
            # whitelist の指定があったらそれを適用
            return true if whiteListCategories is undefined
            return false if content.id.match(/^user\/.+\/category\/(.+)$/) is null
            _.contains(whiteListCategories, content.id.match(/^user\/.+\/category\/(.+)$/)[1])
          .reject (content) ->
            # blacklist の指定があったらそれを適用
            return false if blackListCategories is undefined
            return true if content.id.match(/^user\/.+\/category\/(.+)$/) is null
            _.contains(blackListCategories, content.id.match(/^user\/.+\/category\/(.+)$/)[1])
          .map((content) -> content.id)
          .value()
      return Promise.resolve(feedIds)

  # responseItems: (api_promise, feedIds) ->
  #   _.each(feedIds, (feedId) -> this.streamContents(api_promise, feedId))
  #
  # streamContents: (api_promise, feedId) ->
  #   api_promise.spread (response, body) ->
  #     return Promise.reject(response, body) if response.statusCode isnt 200
  #     # newerThan が期待通りに動かない
  #     #items = _.filter(JSON.parse(response[0].body).items, (item) -> parseInt(item.crawled) > newerThan)
  #     items = _.last(JSON.parse(body).items, 10) # 多すぎるとbotのプロセスが死ぬ？
  #     _.each items, (item) ->
  #       @msg.send item.title
  #       @msg.send item.alternate[0].href
  #       responseItems.push item
  #   .error (response, body) ->
  #     @msg.send 'streamContentsが失敗してしまいました'
  #     @msg.send JSON.stringify(response)
  #     @msg.send JSON.stringify(body)
  #
  # markCounts: () ->
  #   markCategories = Config.getMarkAsReadCategories()
  #   return if markCategories is undefined
  #   markFeeds = _.chain(responseItems)
  #               .map((responseItem) ->
  #                 label = responseItem.categories[0].label
  #                 if _.contains(markCategories, label) then responseItem.id else ''
  #               )
  #               .compact()
  #               .value()
  #   client.markEntriesAsRead(markFeeds)
  #   .then (response) ->
  #     if response[0].statusCode isnt 200
  #       msg.send '既読つけるのに失敗してしまいました'
  #       msg.send JSON.stringify(response[0].body)


module.exports = Stream
