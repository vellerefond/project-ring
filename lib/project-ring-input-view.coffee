{View, EditorView} = require 'atom'

module.exports =
class ProjectRingInputView extends View
    projectRing: null

    viewModeParameters: null

    editor: null

    @content: ->
        @div class: 'project-ring-input overlay from-top', =>
            @div class: 'editor-container', outlet: 'editorContainer', =>
                @subview 'editor', (new EditorView mini: true)

    initialize: (projectRing) ->
        @projectRing = @projectRing or projectRing

    attach: (viewModeParameters, placeholderText, text) ->
        @viewModeParameters = viewModeParameters
        @editor.off 'core:confirm'
        @editor.off 'core:cancel'
        @editor.find('input').off 'blur'
        @editor.setPlaceholderText placeholderText
        @editor.setText text or ''
        @editor.editor.selectAll()
        atom.workspaceView.append(@)
        @editor.focus()
        @editor.on 'core:confirm', => @confirmed()
        @editor.on 'core:cancel', => @destroy()
        @editor.find('input').on 'blur', => @destroy()

    destroy: ->
        @editor.find('input').off 'blur'
        @detach()

    confirmed: ->
        @destroy()
        @projectRing.handleProjectRingInputViewInput @viewModeParameters, @editor.getText()
