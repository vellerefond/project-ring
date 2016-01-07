module.exports =
class ProjectRingNotification
	notify: (message) ->
		return unless @isEnabled and message
		atom.notifications.addSuccess message

	warn: (message) ->
		return unless @isEnabled and message
		atom.notifications.addWarning message, dismissable: true

	alert: (message) ->
		return unless message
		atom.notifications.addError message, dismissable: true
