{ $ } = require 'atom'

module.exports =
class ProjectRingNotification
	createNotification: ->
		return if @notification
		@isEnabled = true
		@animationDelay = 250
		@closeDelays =
			notification: 1500
			warning: 2500
			alert: 5000
		@notification = $('<div></div>').on 'click', => @close()

	getActiveNotification: ->
		$(document.body).find '.project-ring-notification'

	setCSS: (severity) ->
		return unless @notification and severity
		@notification.removeAttr 'class'
		@notification.addClass 'project-ring-notification ' + severity
		@notification.clone true

	scheduleClose: (closeDelay) ->
		clearTimeout @closeTimeout
		@closeTimeout = setTimeout (=> @close()), closeDelay

	notify: (message, sticky) ->
		@close()
		return unless @isEnabled and message
		$(document.body).append @setCSS('notify').text message.toString()
		@getActiveNotification().show @animationDelay
		@scheduleClose @closeDelays.notification unless sticky

	warn: (message, sticky) ->
		@close()
		return unless @isEnabled and message
		$(document.body).append @setCSS('warn').text message.toString()
		@getActiveNotification().show @animationDelay
		@scheduleClose @closeDelays.warning unless sticky

	alert: (message, sticky) ->
		@close()
		return unless message
		$(document.body).append @setCSS('alert').text message.toString()
		@getActiveNotification().show @animationDelay
		@scheduleClose @closeDelays.alert unless sticky

	close: ->
		@createNotification()
		clearTimeout @closeTimeout
		@getActiveNotification().stop().hide(@animationDelay).queue ->
			$(@).remove().dequeue()
