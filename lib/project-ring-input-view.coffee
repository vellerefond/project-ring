{ View, TextEditorView } = require 'atom-space-pen-views'

module.exports =
class ProjectRingInputView extends View
	@content: ->
		@div class: 'project-ring-input overlay from-top', =>
			@div class: 'editor-container', outlet: 'editorContainer', =>
				@subview 'editor', new TextEditorView mini: true

	initialize: (projectRing) ->
		@projectRing = @projectRing or projectRing

	attach: (viewModeParameters, placeholderText, text) ->
		@viewModeParameters = viewModeParameters
		unless @isInitialized
			atom.commands.add @editor[0],
				'core:confirm': => @confirmed()
				'core:cancel': => @destroy()
			@isInitialized = true
		@editor.find('input').off 'blur'
		@editor.getModel().setPlaceholderText placeholderText
		@editor.setText text or ''
		@editor.getModel().selectAll()
		@self = atom.workspace.addModalPanel item: @
		@editor.focus()
		@editor.find('input').on 'blur', => @destroy()

	destroy: ->
		@editor.find('input').off 'blur'
		@self.destroy()

	confirmed: ->
		@destroy()
		@projectRing.handleProjectRingInputViewInput @viewModeParameters, @editor.getText()
