{ $ } = require 'atom-space-pen-views'

module.exports =
class ProjectRingNotification
	createNotification: ->
		return if @notification
		@isEnabled = atom.config.get 'project-ring.useNotifications'
		@animationDelay = 250
		@closeDelays =
			notification: 1500
			warning: 2500
			alert: 5000
		@notification = $('<div></div>').on 'click', => @close()

	getActiveNotification: ->
		fontFamily = atom.config.get 'editor.fontFamily'
		fontSize = atom.config.get 'editor.fontSize'
		activeNotification = $(document.body).find '.project-ring-notification'
		if fontFamily
			activeNotification.css 'font-family', fontFamily
		else
			activeNotification.css 'font-family', null
		if fontSize
			activeNotification.css 'font-size', fontSize
		else
			activeNotification.css 'font-size', null
		activeNotification

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
		console.debug @isEnabled, message, atom.config.get 'project-ring.useNotifications'
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
