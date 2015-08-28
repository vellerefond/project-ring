module.exports =
class ProjectRingNotification
	createNotification: ->
		@isEnabled = atom.config.get 'project-ring.useNotifications'

	notify: (message) ->
		return unless @isEnabled and message
		atom.notifications.addSuccess message

	warn: (message) ->
		return unless @isEnabled and message
		atom.notifications.addWarning message

	alert: (message) ->
		return unless message
		atom.notifications.addError message
