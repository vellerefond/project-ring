lib = require './project-ring-lib'
{ $, $$, SelectListView } = require 'atom-space-pen-views'

module.exports =
class ProjectRingView extends SelectListView
	initialize: (projectRing) ->
		super
		@projectRing = @projectRing or projectRing
		@addClass 'project-ring-project-select overlay from-top'

	serialize: ->

	attach: (viewModeParameters, items, titleKey) ->
		@viewModeParameters = viewModeParameters
		unless @isInitialized
			openInNewWindowLabel = $ '<label class="new-window-label">Open in a new window? <input type="checkbox" class="new-window" /></label>'
			openInNewWindowLabel.css(
				'display': 'inline-block', 'font-size': '12px', 'letter-spacing': '0px', 'position': 'absolute', 'right': '15px'
			).find('.new-window').css 'vertical-align': 'sub', 'width': '12px', 'height': '12px'
			@filterEditorView[0].shadowRoot.appendChild openInNewWindowLabel[0]
			@filterEditorView[0].shadowRoot.querySelector('.new-window').addEventListener 'click', => @filterEditorView.focus()
			@filterEditorView.after \
				$ '<div class="key-bindings-guide-label">' \
				+  '<div>Delete selected project: <strong>alt-shift-delete</strong></div>' \
				+  '<div>Unload current project: <strong>alt-shift-u</strong></div>' \
				+ '</div>'
			@filterEditorView.on 'keydown', (keydownEvent) => @onKeydown keydownEvent
			@isInitialized = true
		if viewModeParameters.viewMode is 'project'
			@filterEditorView.next('.key-bindings-guide-label').show()
		else
			@filterEditorView.next('.key-bindings-guide-label').hide()
		itemsArray = []
		for key, i in Object.keys(items).filter((key) -> key isnt lib.defaultProjectCacheKey).sort()
			index = (i + 1).toString()
			itemsArray.push
				index: index,
				title: items[key][titleKey],
				query: index + ': ' + items[key][titleKey]
				data: items[key]
				isCurrent: items[key] is @viewModeParameters.currentItem
		@setItems itemsArray
		@self = atom.workspace.addModalPanel item: @
		@filterEditorView.getModel().setPlaceholderText @viewModeParameters.placeholderText
		@filterEditorView.focus()

	getEmptyMessage: (itemCount, filteredItemCount) =>
		'No items in the list or no matching items.'

	viewForItem: ({index, title, isCurrent}) ->
		$$ ->
			@li class: 'project-ring-item' + (if isCurrent then ' project-ring-item-current' else ''), =>
				@div class: 'project-ring-item-title', index + ": " + title

	getFilterKey: ->
		'query'

	confirmed: ({data}) ->
		@destroy()
		@projectRing.handleProjectRingViewSelection @viewModeParameters, {
			projectState: data, openInNewWindow: @filterEditorView[0].shadowRoot.querySelector('.new-window').checked
		}

	onKeydown: (keydownEvent) ->
		@projectRing.handleProjectRingViewKeydown keydownEvent, @viewModeParameters, @getSelectedItem()

	destroy: ->
		@cancel()

	cancelled: ->
		@self.destroy()
