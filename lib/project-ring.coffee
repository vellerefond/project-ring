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
        atom.workspaceView.command "project-ring:move-project-path", => @setProjectPath true

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
                        return unless bufferDestroyed.file and
                            atom.project.path and
                            @statesCache and
                            @statesCache[atom.project.path]
                        setTimeout (
                                =>
                                    return unless bufferDestroyed.file and
                                        atom.project.path and
                                        @statesCache and
                                        @statesCache[atom.project.path]
                                    if (@statesCache[atom.project.path].openBufferPaths.find (openBufferPath) ->
                                            openBufferPath.toLowerCase() == bufferDestroyed.file.path.toLowerCase())
                                        @statesCache[atom.project.path].openBufferPaths =
                                            @statesCache[atom.project.path].openBufferPaths.filter (openBufferPath) =>
                                                openBufferPath.toLowerCase() != bufferDestroyed.file.path.toLowerCase()
                                        @saveProjectRing()
                            ),
                            250
                atom.project.buffers.forEach (buffer) =>
                    buffer.off 'destroyed.project-ring'
                    buffer.on \
                        'destroyed.project-ring', \
                        onBufferDestroyedProjectRingEventHandlerFactory buffer
                atom.project.on 'buffer-created.project-ring', (openProjectBuffer) =>
                    return unless openProjectBuffer.file
                    openProjectBuffer.off 'destroyed.project-ring'
                    openProjectBuffer.on \
                        'destroyed.project-ring', \
                        onBufferDestroyedProjectRingEventHandlerFactory openProjectBuffer
                    return unless atom.project.path and
                        @statesCache and
                        @statesCache[atom.project.path]
                    unless (@statesCache[atom.project.path].openBufferPaths.find (openBufferPath) ->
                                openBufferPath.toLowerCase() == openProjectBuffer.file.path.toLowerCase())
                        @statesCache[atom.project.path].openBufferPaths.push openProjectBuffer.file.path
                        @saveProjectRing()

    getConfigurationPath: ->
        _path = require 'path'
        path = _path.join process.env[if process.platform == 'win32' then 'USERPROFILE' else 'HOME'],
            '.atom-project-ring'
        _fs = require 'fs'
        _fs.mkdirSync path unless _fs.existsSync path
        path

    getConfigurationFilePath: (path) ->
        _path = require 'path'
        _path.join @getConfigurationPath(), path

    formatProjectRingId: (id) ->
        id?.trim()

    getProjectRingPathFilePath: (id) ->
        @getConfigurationFilePath (@formatProjectRingId id) + '_project_ring_path.txt'

    setProjectRing: (id) ->
        id = @formatProjectRingId id
        @projectRingId = id
        pathFilePathForId = @getProjectRingPathFilePath @projectRingId
        ok = true
        _fs = require 'fs'
        _fs.exists pathFilePathForId, (exists) =>
            return if exists
            _fs.writeFile pathFilePathForId, (@getConfigurationFilePath (@projectRingId + '_project_ring.cson')), (error) ->
                ok = false if error
                alert 'Could not set project ring files for id: "' + id + '" (' + error + ')' unless ok
        return unless ok
        @loadProjectRing @projectRingId

    getProjectRingCSONFilePath: ->
        return unless @projectRingId and not /^\s*$/.test(@projectRingId)
        csonFilePath = undefined
        _fs = require 'fs'
        try
            csonFilePath = _fs.readFileSync (@getProjectRingPathFilePath @projectRingId), 'utf8'
        catch error
            return error
        csonFilePath

    # SHOULD NOT BE USED DIRECTLY BUT ONLY THROUGH setProjectRing INSTEAD
    loadProjectRing: ->
        return unless @projectRingId and not /^\s*$/.test(@projectRingId)
        csonFilePath = @getProjectRingCSONFilePath()
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
        csonFilePath = @getProjectRingCSONFilePath()
        return unless csonFilePath and not /^\s*$/.test(csonFilePath)
        _cson = require 'season'
        try
            _cson.writeFileSync csonFilePath, @statesCache
        catch error
            alert 'Could not save the project ring data for id: "' + @projectRingId + '" (' + error + ')'
            return

    deactivate: ->
        @loadProjectRingView()
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

    setProjectPath: (replace) ->
        @loadProjectRingView()
        @projectRingView.destroy()
        dialog = (require 'remote').require 'dialog'
        dialog.showOpenDialog
            title: (if not replace then 'Open' else 'Replace with')
            properties: [ 'openDirectory', 'createDirectory' ],
            (pathsToOpen) =>
                pathsToOpen = pathsToOpen or []
                return unless pathsToOpen.length
                unless replace
                    @unlink()
                    atom.project.setPath pathsToOpen[0]
                    return
                if @statesCache[atom.project.path]
                    @statesCache[pathsToOpen[0]] = @statesCache[atom.project.path]
                    @statesCache[pathsToOpen[0]].projectPath = pathsToOpen[0]
                    if @statesCache[pathsToOpen[0]].treeViewState
                        oldPathRE = new RegExp '^' + (atom.project.path.replace \
                            /[\$\^\*\(\)\[\]\{\}\|\\\.\?\+]/g, (match) -> '\\' + match), 'i'
                        if @statesCache[pathsToOpen[0]].treeViewState.selectedPath and not
                        /^\s*$/.test(@statesCache[pathsToOpen[0]].treeViewState.selectedPath)
                            @statesCache[pathsToOpen[0]].treeViewState.selectedPath =
                                @statesCache[pathsToOpen[0]].treeViewState.selectedPath.replace \
                                    oldPathRE, pathsToOpen[0]
                        if @statesCache[pathsToOpen[0]].openBufferPaths.length
                            newOpenBufferPaths = []
                            @statesCache[pathsToOpen[0]].openBufferPaths.forEach (openBufferPath) ->
                                newOpenBufferPaths.push openBufferPath.replace oldPathRE, pathsToOpen[0]
                            @statesCache[pathsToOpen[0]].openBufferPaths = newOpenBufferPaths
                    delete @statesCache[atom.project.path]
                atom.project.setPath pathsToOpen[0]
                if not @statesCache[pathsToOpen[0]]
                    @add()
                else
                    @saveProjectRing()
                @processProjectRingViewProjectSelection @statesCache[pathsToOpen[0]]

    deleteProjectRing: ->
        return unless @projectRingId and not /^\s*$/.test(@projectRingId)
        @loadProjectRingView()
        @projectRingView.destroy()
        csonFilePath = @getProjectRingCSONFilePath()
        pathFilePathForId = @getProjectRingPathFilePath @projectRingId
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
                currentlyOpenBufferPaths = []
                @getOpenBufferPaths().forEach (openBufferPath) ->
                    currentlyOpenBufferPaths.push openBufferPath.toLowerCase()
                bufferPathsToOpen = []
                for openBufferPath in (validOpenBufferPaths.filter (openBufferPath) ->
                    openBufferPath.toLowerCase() not in currentlyOpenBufferPaths)
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
