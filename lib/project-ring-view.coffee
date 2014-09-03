{$, $$, View, SelectListView} = require 'atom'

module.exports =
class ProjectRingView extends SelectListView
    projectRing: null

    viewModeParameters: null

    initialize: (projectRing) ->
        super
        @projectRing = @projectRing or projectRing
        @addClass('project-ring overlay from-top')

    serialize: ->

    attach: (viewModeParameters, items, titleKey, descriptionKey) ->
        @viewModeParameters = viewModeParameters
        itemsArray = []
        for key, i in (Object.keys items).sort()
            index = (i + 1).toString()
            itemsArray.push {
                'index': index,
                'title': items[key][titleKey],
                'description': items[key][descriptionKey],
                'query': index + ': ' + items[key][titleKey] + ' ' + items[key][descriptionKey]
                'data': items[key]
            }
        @setItems itemsArray
        atom.workspaceView.append(@)
        @filterEditorView.setPlaceholderText @viewModeParameters.placeholderText
        @filterEditorView.off('keydown').on 'keydown', (keydownEvent) => @onKeydown keydownEvent
        @filterEditorView.focus()

    getEmptyMessage: (itemCount, filteredItemCount) =>
        'No items in the list or no matching items.'

    viewForItem: ({index, title, description}) ->
        $$ ->
            @li class: 'project-ring-item', =>
                @div class: 'project-ring-item-title', index + ": " + title
                unless title == description
                    @div class: 'project-ring-item-description', description


    getFilterKey: ->
        'query'

    confirmed: ({data}) ->
        @destroy()
        @projectRing.handleProjectRingViewSelection @viewModeParameters, data

    onKeydown: (keydownEvent) ->
        @projectRing.handleProjectRingViewKeydown keydownEvent, @viewModeParameters, @getSelectedItem()

    destroy: ->
        @cancel()
        @detach()
