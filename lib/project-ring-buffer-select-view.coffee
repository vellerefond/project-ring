{$, View} = require 'atom'

module.exports =
class ProjectRingBufferSelectView extends View
	projectRing: null

	isInitialized: false

	@content: ->
		@div class: 'project-ring-buffer-select overlay from-top', =>
			@div class: 'controls', =>
				@input type: 'button', class: 'right add', value: 'Add'
				@input type: 'button', class: 'right cancel', value: 'Cancel'
				@input type: 'button', class: 'left select-all', value: 'Select All'
				@input type: 'button', class: 'left deselect-all', value: 'Deselect All'
			@div class: 'entries'

	initialize: (projectRing) ->
		@projectRing = @projectRing or projectRing

	getEntryView: ({title, description, path}) ->
		$entry = $('<div></div>', class: 'entry')
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

	attach: (items) ->
		atom.workspaceView.append @
		$content = atom.workspaceView.find '.project-ring-buffer-select'
		unless @isInitialized
			$controls = $content.find('.controls')
			$controls.find('input:button.add').on 'click', => @confirmed()
			$controls.find('input:button.cancel').on 'click', => @destroy()
			$controls.find('input:button.select-all').on 'click', => @setAllEntriesSelected true
			$controls.find('input:button.deselect-all').on 'click', => @setAllEntriesSelected false
			@isInitialized = true
		$entries = $content.find('.entries').empty()
		unless items.length
			$entries.append ($ '<div>There are no files available for opening.</div>').addClass 'empty'
			return
		for { title, description, path } in items
			$entries.append @getEntryView title: title, description: description, path: path

	destroy: ->
		@detach()

	confirmed: ->
		bufferPaths = []
		atom.workspaceView.find('.project-ring-buffer-select .entries input:checkbox.checked')\
			.each (index, element) -> \
				bufferPaths.push $(element).attr 'data-path'
		@destroy()
		@projectRing.processProjectRingBufferSelectViewSelection bufferPaths

	setAllEntriesSelected: (allSelected) ->
		$checkboxes = atom.workspaceView.find '.project-ring-buffer-select .entries input:checkbox'
		if allSelected
			$checkboxes.removeClass('checked').addClass 'checked'
		else
			$checkboxes.removeClass 'checked'
