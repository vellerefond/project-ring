{ $ } = require 'atom'

module.exports =
class ProjectRingNotification
	notification: null

	closeTimeout: null

	animationDelay: 250

	createNotification: ->
		return if @notification
		@notification = $('<div></div>').on 'click', => @close()

	getActiveNotification: ->
		atom.workspaceView.find 'project-ring-notification'

	setCSS: (severity) ->
		return unless @notification and severity
		@notification.removeAttr 'class'
		@notification.addClass 'project-ring-notification ' + severity
		@notification.clone true

	scheduleClose: (closeDelay) ->
		clearTimeout @closeTimeout
		@closeTimeout = setTimeout (=> @close()), closeDelay

	notify: (message) ->
		@close()
		atom.workspaceView.append setCSS('notification').text message
		@getActiveNotification().show @animationDelay

	warn: (message) ->
		@close()
		atom.workspaceView.append setCSS('warning').text message

	alert: (message) ->
		@close()
		atom.workspaceView.append setCSS('alert').text message

	close: ->
		@createNotification()
		clearTimeout @closeTimeout
		@getActiveNotification().hide(@animationDelay).queue ->
			$(@).remove().dequeue()
