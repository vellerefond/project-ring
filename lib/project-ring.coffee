module.exports =
    configDefaults:
        skipSavingProjectBuffers: false
        skipOpeningProjectBuffers: false
        keepOnlyProjectBuffersOnProjectSelection: false,
        projectToLoadOnStartUp: null

    projectRingView: null

    projectRingInputView: null

    projectRingId: null

    statesCache: null

    activate: (state) ->
        @setupSkipSavingProjectBuffersObservation()
        @setProjectRing 'default'
        projectToLoadOnStartUp = atom.config.get('project-ring.projectToLoadOnStartUp')
        if projectToLoadOnStartUp and
        not /^\s*$/.test(projectToLoadOnStartUp) and
        @statesCache
            for stateKey in Object.keys @statesCache
                unless @statesCache[stateKey].alias == projectToLoadOnStartUp or
                @statesCache[stateKey].projectPath == projectToLoadOnStartUp
                    continue
                @processProjectRingViewProjectSelection @statesCache[stateKey]
                break
        atom.workspaceView.command "project-ring:add", => @add()
        atom.workspaceView.command "project-ring:add-as", => @addAs()
        atom.workspaceView.command "project-ring:rename", => @addAs true
        atom.workspaceView.command "project-ring:toggle", => @toggle()
        atom.workspaceView.command "project-ring:open-project-buffers", => @toggle true
        atom.workspaceView.command "project-ring:delete", => @delete()
        atom.workspaceView.command "project-ring:unlink", => @unlink()
        atom.workspaceView.command "project-ring:set-project-path", => @setProjectPath()
        atom.workspaceView.command "project-ring:delete-project-ring", => @deleteProjectRing()
        atom.workspaceView.command "project-ring:copy-project-alias", => @copy 'alias'
        atom.workspaceView.command "project-ring:copy-project-path", => @copy 'projectPath'

    setupSkipSavingProjectBuffersObservation: ->
        atom.config.observe 'project-ring.skipSavingProjectBuffers', null, (skipSavingProjectBuffers) =>
            if skipSavingProjectBuffers
                atom.project.off 'buffer-created.project-ring'
                atom.project.buffers.forEach (buffer) -> buffer.off 'destroyed.project-ring'
                return unless atom.project.path and @statesCache and @statesCache[atom.project.path]
                @statesCache[atom.project.path].openBufferPaths = []
                @saveProjectRing()
            else
                onBufferDestroyedProjectRingEventHandlerFactory = (bufferDestroyed) =>
                    =>
                        return unless bufferDestroyed.file and atom.project.path and @statesCache and @statesCache[atom.project.path]
                        setTimeout (
                                =>
                                    return unless bufferDestroyed.file and atom.project.path and @statesCache and @statesCache[atom.project.path]
                                    if (@statesCache[atom.project.path].openBufferPaths.find (openBufferPath) -> openBufferPath == bufferDestroyed.file.path)
                                        @statesCache[atom.project.path].openBufferPaths = @statesCache[atom.project.path].openBufferPaths.filter (openBufferPath) =>
                                            openBufferPath != bufferDestroyed.file.path
                                        @saveProjectRing()
                            ),
                            250
                atom.project.buffers.forEach (buffer) =>
                    buffer.off 'destroyed.project-ring'
                    buffer.on 'destroyed.project-ring', onBufferDestroyedProjectRingEventHandlerFactory buffer
                atom.project.on 'buffer-created.project-ring', (openProjectBuffer) =>
                    return unless openProjectBuffer.file
                    openProjectBuffer.off 'destroyed.project-ring'
                    openProjectBuffer.on 'destroyed.project-ring', onBufferDestroyedProjectRingEventHandlerFactory openProjectBuffer
                    unless (@statesCache[atom.project.path].openBufferPaths.find (openBufferPath) -> openBufferPath == openProjectBuffer.file.path)
                        @statesCache[atom.project.path].openBufferPaths.push openProjectBuffer.file.path
                        @saveProjectRing()

    getProjectRingPackagePath: ->
        projectRing = atom.packages.getLoadedPackages().find (loadedPackage) -> /^project-ring$/i.test(loadedPackage.name)
        projectRing?.path

    getFilePathRelativeToProject: (path) ->
        _path = require 'path'
        _path.join @getProjectRingPackagePath(), path

    formatProjectRingId: (id) ->
        id?.trim()

    getPathFilePath: (id) ->
        _path = require 'path'
        _path.join 'data', (@formatProjectRingId id) + '_project_ring_path.txt'

    setProjectRing: (id) ->
        id = @formatProjectRingId id
        @projectRingId = id
        pathFilePathForId = @getFilePathRelativeToProject (@getPathFilePath @projectRingId)
        ok = true
        _fs = require 'fs'
        _fs.exists pathFilePathForId, (exists) =>
            return if exists
            _fs.writeFile pathFilePathForId, '/data/' + @projectRingId + '_project_ring.cson', (error) ->
                ok = false if error
                alert 'Could not set project ring files for id: "' + id + '" (' + error + ')' unless ok
        return unless ok
        @loadProjectRing @projectRingId

    getCSONProjectRingPath: ->
        return unless @projectRingId and not /^\s*$/.test(@projectRingId)
        csonFilePath = undefined
        _fs = require 'fs'
        try
            csonFilePath = _fs.readFileSync (@getFilePathRelativeToProject (@getPathFilePath @projectRingId)), 'utf8'
        catch error
            return error
        @getFilePathRelativeToProject csonFilePath if csonFilePath and not /^\s*$/.test(csonFilePath)

    # SHOULD NOT BE USED DIRECTLY BUT ONLY THROUGH setProjectRing INSTEAD
    loadProjectRing: ->
        return unless @projectRingId and not /^\s*$/.test(@projectRingId)
        csonFilePath = @getCSONProjectRingPath()
        return unless csonFilePath and not /^\s*$/.test(csonFilePath)
        _fs = require 'fs'
        unless _fs.existsSync csonFilePath
            @statesCache = {}
            return
        _cson = require 'season'
        try
            @statesCache = _cson.readFileSync csonFilePath
        catch error
            alert 'Could not load the project ring data for id: "' + @projectRingId + '" (' + error + ')'
            return

    saveProjectRing: ->
        return unless @projectRingId and not /^\s*$/.test(@projectRingId)
        csonFilePath = @getCSONProjectRingPath()
        return unless csonFilePath and not /^\s*$/.test(csonFilePath)
        _cson = require 'season'
        try
            _cson.writeFileSync csonFilePath, @statesCache
        catch error
            alert 'Could not save the project ring data for id: "' + @projectRingId + '" (' + error + ')'
            return

    deactivate: ->
        @projectRingView.destroy()

    serialize: ->

    loadProjectRingView: ->
        unless @projectRingView
            ProjectRingView = require './project-ring-view'
            @projectRingView = new ProjectRingView(@) unless @projectRingView

    loadProjectRingInputView: ->
        unless @projectRingInputView
            ProjectRingInputView = require './project-ring-input-view'
            @projectRingInputView = new ProjectRingInputView(@) unless @projectRingInputView

    getOpenBufferPaths: ->
        openBufferPaths = []
        unless atom.config.get('project-ring.skipSavingProjectBuffers')
            for buffer in (atom.project.buffers.filter (buffer) -> buffer.file)
                openBufferPaths.push buffer.file.path
        openBufferPaths

    add: (alias, renameOnly) ->
        @loadProjectRingView()
        @projectRingView.destroy()
        return unless atom.project.path and not /^\s*$/.test(atom.project.path)
        treeView = atom.packages.getLoadedPackages().find (loadedPackage) -> /^tree-view$/i.test(loadedPackage.name)
        return unless treeView;
        treeViewState = treeView.serialize()
        alias = alias or atom.project.path
        alias = '...' + alias.substr alias.length - 97 if alias.length > 100
        if renameOnly
            if @statesCache[atom.project.path]
                @statesCache[atom.project.path].alias = alias
                @saveProjectRing()
            return
        currentProjectState =
            alias: alias
            projectPath: atom.project.path
            treeViewState: treeViewState
            openBufferPaths: @getOpenBufferPaths()
        @statesCache = {} unless @statesCache
        @statesCache[atom.project.path] = currentProjectState
        @saveProjectRing()

    addAs: (renameOnly) ->
        @loadProjectRingInputView()
        unless @projectRingInputView.hasParent()
            alias = atom.project.path
            if @statesCache[atom.project.path]
            then (
                if @statesCache[atom.project.path].alias == @statesCache[atom.project.path].projectPath
                then alias = (require 'path').basename @statesCache[atom.project.path].projectPath
                else alias = @statesCache[atom.project.path].alias
            )
            else alias = (require 'path').basename (if alias then alias else '')
            @projectRingInputView.attach {
                viewMode: 'project',
                renameOnly: renameOnly
            }, 'Project alias', alias

    toggle: (openProjectBuffersOnly) ->
        deleteKeyBinding = atom.keymap.getKeyBindings().find (keyBinding) -> keyBinding.command == 'project-ring:add'
        if deleteKeyBinding
        then deleteKeyBinding = ' (delete selected: ' + deleteKeyBinding.keystrokes.split(/\s+/)[0].replace(/-[^-]+$/, '-') + 'delete)'
        else deleteKeyBinding = ''
        @loadProjectRingView()
        if @projectRingView.hasParent()
            @projectRingView.destroy()
        else
            @projectRingView.attach {
                viewMode: 'project',
                openProjectBuffersOnly: openProjectBuffersOnly
                placeholderText:
                    if not openProjectBuffersOnly
                    then 'Load project...' + deleteKeyBinding
                    else 'Load buffers only...' + deleteKeyBinding
            }, @statesCache, 'alias', 'projectPath'

    delete: ->
        @loadProjectRingView()
        @projectRingView.destroy()
        return unless atom.project.path and not /^\s*$/.test(atom.project.path)
        @statesCache = {} unless @statesCache
        delete @statesCache[atom.project.path]
        @saveProjectRing()

    unlink: ->
        @loadProjectRingView()
        @projectRingView.destroy()
        return unless atom.project.path and not /^\s*$/.test(atom.project.path)
        treeView = atom.packages.getLoadedPackages().find (loadedPackage) -> /^tree-view$/i.test(loadedPackage.name)
        return unless treeView;
        treeView.deactivate()
        atom.project.setPath null

    setProjectPath: ->
        @loadProjectRingView()
        @projectRingView.destroy()
        dialog = (require 'remote').require 'dialog'
        dialog.showOpenDialog title: 'Open', properties: [ 'openDirectory', 'createDirectory' ], (pathsToOpen) =>
            pathsToOpen = pathsToOpen or []
            return unless pathsToOpen.length
            @unlink()
            atom.project.setPath pathsToOpen[0]

    deleteProjectRing: ->
        return unless @projectRingId and not /^\s*$/.test(@projectRingId)
        @projectRingView.destroy()
        csonFilePath = @getCSONProjectRingPath()
        pathFilePathForId = @getFilePathRelativeToProject (@getPathFilePath @projectRingId)
        _fs = require 'fs'
        _fs.unlinkSync csonFilePath if _fs.existsSync csonFilePath
        _fs.unlinkSync pathFilePathForId if _fs.existsSync pathFilePathForId
        @setProjectRing 'default'

    handleProjectRingViewKeydown: (keydownEvent, viewModeParameters, selectedItem) ->
        return unless keydownEvent and selectedItem
        # alt-shift-delete
        if viewModeParameters.viewMode == 'project' and
        keydownEvent.altKey and
        keydownEvent.shiftKey and
        keydownEvent.which == 46
            @processProjectRingViewProjectDeletion selectedItem.data

    processProjectRingViewProjectDeletion: (projectState) ->
        return unless projectState and @statesCache and @statesCache[projectState.projectPath]
        @projectRingView.destroy()
        delete @statesCache[projectState.projectPath]
        @saveProjectRing()

    handleProjectRingViewSelection: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'project' then (@processProjectRingViewProjectSelection data, viewModeParameters.openProjectBuffersOnly); break

    processProjectRingViewProjectSelection: (projectState, openProjectBuffersOnly) ->
        return unless projectState
        _fs = require 'fs'
        unless _fs.existsSync projectState.projectPath
            delete @statesCache[projectState.projectPath]
            @saveProjectRing()
            return
        unless openProjectBuffersOnly
            treeView = atom.packages.getLoadedPackages().find (loadedPackage) -> /^tree-view$/i.test(loadedPackage.name)
            return unless treeView;
            treeView.deactivate()
            atom.project.once 'path-changed', ->
                return unless atom.project.path and not /^\s*$/.test(atom.project.path)
                treeView.activate().done ->
                    treeView.mainModule.activate projectState.treeViewState
                    # ensure that we expand the proper folders
                    treeView.mainModule.treeView.updateRoot(projectState.treeViewState.directoryExpansionStates)
            atom.project.setPath projectState.projectPath
        unless not openProjectBuffersOnly and atom.config.get('project-ring.skipOpeningProjectBuffers')
            if projectState.openBufferPaths and projectState.openBufferPaths.length
                validOpenBufferPaths = projectState.openBufferPaths.filter (openBufferPath) ->
                    _fs.existsSync(openBufferPath)
                unless openProjectBuffersOnly or not atom.config.get('project-ring.keepOnlyProjectBuffersOnProjectSelection')
                    (atom.project.buffers.filter (buffer) ->
                        buffer.file.path not in validOpenBufferPaths).forEach (b) ->
                            b.destroy()
                unless projectState.openBufferPaths.length == validOpenBufferPaths.length or openProjectBuffersOnly
                    @statesCache[projectState.projectPath].openBufferPaths = validOpenBufferPaths
                    @saveProjectRing()
                currentlyOpenBufferPaths = @getOpenBufferPaths()
                bufferPathsToOpen = []
                for openBufferPath in (validOpenBufferPaths.filter (openBufferPath) ->
                    openBufferPath not in currentlyOpenBufferPaths)
                    bufferPathsToOpen.push openBufferPath
                if bufferPathsToOpen.length
                    atom.open
                        pathsToOpen: bufferPathsToOpen
                        newWindow: false

    handleProjectRingInputViewInput: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'project' then (@processProjectRingInputViewProjectAlias data, viewModeParameters.renameOnly); break

    processProjectRingInputViewProjectAlias: (alias, renameOnly) ->
        return unless alias and not /^\s*$/.test(alias)
        @add alias, renameOnly

    copy: (copyKey) ->
        return unless atom.project.path and
            not /^\s*$/.test(atom.project.path) and
            @statesCache[atom.project.path]?[copyKey]
        try
            require('clipboard').writeText @statesCache[atom.project.path][copyKey]
        catch error
            alert error
            return
