module.exports =
class ProjectRingNotification
	createNotification: ->
		@isEnabled = atom.config.get 'project-ring.useNotifications'

	notify: (message) ->
		return unless @isEnabled and message
		atom.notifications.addSuccess message, dismissable: true

	warn: (message) ->
		return unless @isEnabled and message
		atom.notifications.addWarning message, dismissable: true

	alert: (message) ->
		return unless message
		atom.notifications.addError message
