{ $, View } = require 'atom-space-pen-views'

module.exports =
class ProjectRingProjectSelectView extends View
	@content: ->
		@div class: 'project-ring-project-select overlay from-top', =>
			@div class: 'controls', =>
				@input type: 'button', class: 'right confirm', value: ''
				@input type: 'button', class: 'right cancel', value: 'Cancel'
				@input type: 'button', class: 'left select-all', value: 'Select All'
				@input type: 'button', class: 'left deselect-all', value: 'Deselect All'
			@div class: 'entries'

	initialize: (projectRing) ->
		@projectRing = @projectRing or projectRing

	getEntryView: (key) ->
		$entry = $('<div></div>', class: 'entry')
		$entry.append $('<input />', type: 'checkbox', 'data-key': key).on 'click', (event) ->
			event.preventDefault()
			event.returnValue = false
			$this = $ @
			unless $this.is('.checked')
				$this.addClass 'checked'
			else
				$this.removeClass 'checked'
			return event.returnValue
		$entry.append($('<div></div>', class: 'title', text: key))

	attach: (viewModeParameters, items) ->
		@viewModeParameters = viewModeParameters
		@self = atom.workspace.addModalPanel item: @
		$content = $(atom.views.getView atom.workspace).find '.project-ring-project-select'
		unless @isInitialized
			$controls = $content.find('.controls')
			$controls.find('input:button.confirm').on 'click', => @confirmed()
			$controls.find('input:button.cancel').on 'click', => @destroy()
			$controls.find('input:button.select-all').on 'click', => @setAllEntriesSelected true
			$controls.find('input:button.deselect-all').on 'click', => @setAllEntriesSelected false
			@isInitialized = true
		$content.find('.controls .confirm').val @viewModeParameters.confirmValue
		$entries = $content.find('.entries').empty()
		unless items.length
			$entries.append ($ '<div>There are no projects available for opening.</div>').addClass 'empty'
			return
		for key in items
			$entries.append @getEntryView key

	destroy: ->
		@self.destroy()

	confirmed: ->
		keys = []
		$(atom.views.getView atom.workspace).find('.project-ring-project-select .entries input:checkbox.checked').each (index, element) ->
			keys.push $(element).attr 'data-key'
		@destroy()
		@projectRing.handleProjectRingProjectSelectViewSelection @viewModeParameters, keys

	setAllEntriesSelected: (allSelected) ->
		$checkboxes = $(atom.views.getView atom.workspace).find '.project-ring-project-select .entries input:checkbox'
		if allSelected
			$checkboxes.removeClass('checked').addClass 'checked'
		else
			$checkboxes.removeClass 'checked'
