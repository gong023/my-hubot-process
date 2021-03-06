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

  responseItems: (api_promise) ->
    api_promise.spread (response, body) ->
      if response.statusCode isnt 200
        return Promise.reject(response, body)
      return Promise.resolve(JSON.parse(body).items)

  markCounts: (api_promise, responseItems) ->
    markCategories = Config.getMarkAsReadCategories()
    return if markCategories is undefined
    pickLabel = (responseItem) ->
      label = responseItem.categories[0].label
      if _.contains(markCategories, label) then responseItem.id else ''
    markFeeds = _.chain(responseItems[0]).map(pickLabel).compact().value()
    api_promise.markEntriesAsRead(markFeeds)

module.exports = Stream
