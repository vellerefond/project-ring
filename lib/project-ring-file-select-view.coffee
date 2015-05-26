{ $, View } = require 'atom-space-pen-views'

module.exports =
class ProjectRingBufferSelectView extends View
	@content: ->
		@div class: 'project-ring-file-select overlay from-top', =>
			@div class: 'controls', =>
				@input type: 'button', class: 'right confirm', value: ''
				@input type: 'button', class: 'right cancel', value: 'Cancel'
				@input type: 'button', class: 'left select-all', value: 'Select All'
				@input type: 'button', class: 'left deselect-all', value: 'Deselect All'
			@div class: 'entries'

	initialize: (projectRing) ->
		@projectRing = @projectRing or projectRing

	getEntryView: ({ title, description, path }) ->
		$entry = $('<div></div>', class: 'entry')
		$checkAll = $('<input />', type: 'checkbox', 'data-path': path)

		$entry.append $('<input />', type: 'checkbox', 'data-path': path).on 'click', (event) ->
			event.preventDefault()
			event.returnValue = false
			$this = $ @
			unless $this.is('.checked')
				$this.addClass 'checked'
			else
				$this.removeClass 'checked'
			return event.returnValue
		$entry.append($('<div></div>', class: 'title', text: title))
		$entry.append($('<div></div>', class: 'description', text: description))

	attach: (viewModeParameters, items) ->
		@viewModeParameters = viewModeParameters
		@self = atom.workspace.addModalPanel item: @
		$content = $(atom.views.getView atom.workspace).find '.project-ring-file-select'
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
			$entries.append ($ '<div>There are no files available for opening.</div>').addClass 'empty'
			return
		for { title, description, path } in items
			$entries.append @getEntryView title: title, description: description, path: path

	destroy: ->
		@self.destroy()

	confirmed: ->
		bufferPaths = []
		$(atom.views.getView atom.workspace).find('.project-ring-file-select .entries input:checkbox.checked').each (index, element) ->
				bufferPaths.push $(element).attr 'data-path'
		@destroy()
		@projectRing.handleProjectRingBufferSelectViewSelection @viewModeParameters, bufferPaths

	setAllEntriesSelected: (allSelected) ->
		$checkboxes = $(atom.views.getView atom.workspace).find '.project-ring-file-select .entries input:checkbox'
		if allSelected
			$checkboxes.removeClass('checked').addClass 'checked'
		else
			$checkboxes.removeClass 'checked'
