{ $, $$, SelectListView } = require 'atom-space-pen-views'

module.exports =
class ProjectRingView extends SelectListView
    initialize: (projectRing) ->
        super
        @projectRing = @projectRing or projectRing
        @addClass 'project-ring overlay from-top'

    serialize: ->

    attach: (viewModeParameters, items, titleKey, descriptionKey) ->
        @viewModeParameters = viewModeParameters
        unless @isInitialized
            @filterEditorView.on 'keydown', (keydownEvent) => @onKeydown keydownEvent
            @isInitialized = true
        itemsArray = []
        for key, i in (Object.keys items).sort()
            continue if items[key].isIgnored
            index = (i + 1).toString()
            itemsArray.push {
                'index': index,
                'title': items[key][titleKey],
                'description': items[key][descriptionKey],
                'query': index + ': ' + items[key][titleKey] + ' ' + items[key][descriptionKey]
                'data': items[key]
            }
        @setItems itemsArray
        @self = atom.workspace.addModalPanel item: @
        @filterEditorView.getModel().setPlaceholderText @viewModeParameters.placeholderText
        @filterEditorView.focus()

    getEmptyMessage: (itemCount, filteredItemCount) =>
        'No items in the list or no matching items.'

    viewForItem: ({index, title, description}) ->
        $$ ->
            @li class: 'project-ring-item', =>
                @div class: 'project-ring-item-title', index + ": " + title
                unless title is description
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

    cancelled: ->
        @self.destroy()
