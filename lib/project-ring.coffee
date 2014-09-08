module.exports =
    configDefaults:
        closePreviousProjectBuffers: false
        filePatternToHide: null
        filePatternToExcludeFromHiding: null
        keepOnlyProjectBuffersOnProjectSelection: false
        projectToLoadOnStartUp: null
        skipSavingProjectBuffers: false
        skipOpeningProjectBuffers: false
        skipOpeningTreeViewWhenChangingProjectPath: false
        useFilePatternHiding: false

    projectRingInvariantState: null

    projectRingView: null

    projectRingInputView: null

    projectRingId: null

    hasLoadedProject: false

    statesCache: null

    currentlySavingConfiguration: null

    activate: (state) ->
        @projectRingInvariantState =
            regExpEscapesRegExp: /[\$\^\*\(\)\[\]\{\}\|\\\.\?\+]/g
            deletionDelay: 250
            configurationFileWatchInterval: 2500
        Object.freeze @projectRingInvariantState
        @currentlySavingConfiguration =
            csonFile: false
        @setupAutomaticProjectBuffersSaving()
        treeView = atom.packages.getLoadedPackage 'tree-view'
        unless treeView and treeView.mainModule.treeView
            treeView.activate().then =>
                setTimeout (
                        =>
                            atom.workspaceView.find('.tree-view').on 'click keydown', (event) =>
                                setTimeout (
                                    =>
                                        @add undefined, undefined, true
                                        @runFilePatternHiding()
                                    ),
                                    0
                            @setProjectRing 'default', atom.config.get 'project-ring.projectToLoadOnStartUp'
                    ),
                    0
        else
            atom.workspaceView.find('.tree-view').on 'click keydown', (event) =>
                setTimeout (
                    =>
                        @add undefined, undefined, true
                        @runFilePatternHiding()
                    ),
                    0
            @setProjectRing 'default', atom.config.get 'project-ring.projectToLoadOnStartUp'
        atom.config.observe 'project-ring.useFilePatternHiding', null, (useFilePatternHiding) =>
            @runFilePatternHiding useFilePatternHiding
        atom.config.observe 'project-ring.filePatternToHide', null, (filePatternToHide) =>
            @runFilePatternHiding()
        atom.config.observe 'project-ring.filePatternToExcludeFromHiding', null, (filePatternToExcludeFromHiding) =>
            @runFilePatternHiding()
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
        atom.workspaceView.command "project-ring:edit-key-bindings", => @editKeyBindings()

    setupAutomaticProjectBuffersSaving: ->
        atom.config.observe 'project-ring.skipSavingProjectBuffers', null, (skipSavingProjectBuffers) =>
            if skipSavingProjectBuffers
                atom.project.off 'buffer-created.project-ring'
                atom.project.buffers.forEach (buffer) -> buffer.off 'destroyed.project-ring'
                return unless \
                    @hasLoadedProject and \
                    atom.project.path and \
                    @statesCache and \
                    @statesCache[atom.project.path]
                @statesCache[atom.project.path].openBufferPaths = []
                @saveProjectRing()
            else
                onBufferDestroyedProjectRingEventHandlerFactory = (bufferDestroyed) =>
                    =>
                        return unless \
                            @hasLoadedProject and \
                            bufferDestroyed.file and \
                            atom.project.path and \
                            @statesCache and \
                            @statesCache[atom.project.path]
                        setTimeout (
                                =>
                                    return unless \
                                        @hasLoadedProject and \
                                        bufferDestroyed.file and \
                                        atom.project.path and \
                                        @statesCache and \
                                        @statesCache[atom.project.path]
                                    if (@statesCache[atom.project.path].openBufferPaths.find (openBufferPath) ->
                                            openBufferPath.toLowerCase() == bufferDestroyed.file.path.toLowerCase())
                                        @statesCache[atom.project.path].openBufferPaths =
                                            @statesCache[atom.project.path].openBufferPaths.filter (openBufferPath) =>
                                                openBufferPath.toLowerCase() != bufferDestroyed.file.path.toLowerCase()
                                        @saveProjectRing()
                            ),
                            @projectRingInvariantState.deletionDelay
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
                    return unless \
                        @hasLoadedProject and \
                        atom.project.path and \
                        @statesCache and \
                        @statesCache[atom.project.path]
                    unless (@statesCache[atom.project.path].openBufferPaths.find (openBufferPath) ->
                                openBufferPath.toLowerCase() == openProjectBuffer.file.path.toLowerCase())
                        @statesCache[atom.project.path].openBufferPaths.push openProjectBuffer.file.path
                        @saveProjectRing()

    runFilePatternHiding: (useFilePatternHiding) ->
        setTimeout (
                =>
                    useFilePatternHiding =
                        if typeof useFilePatternHiding != 'undefined'
                        then useFilePatternHiding
                        else atom.config.get 'project-ring.useFilePatternHiding'
                    entries = atom.workspaceView.find('.tree-view > .directory > .entries').find('.directory, .file')
                    return unless entries.length
                    {$} = require 'atom'
                    if useFilePatternHiding
                        filePattern = atom.config.get 'project-ring.filePatternToHide'
                        if filePattern and not /^\s*$/.test filePattern
                            try
                                filePattern = new RegExp filePattern, 'i'
                            catch error
                                filePattern = null
                        else
                            filePattern = null
                        unless filePattern
                            @runFilePatternHiding false
                            return
                        reverseFilePattern = atom.config.get 'project-ring.filePatternToExcludeFromHiding'
                        if reverseFilePattern and not /^\s*$/.test reverseFilePattern
                            try
                                reverseFilePattern = new RegExp reverseFilePattern, 'i'
                            catch error
                                reverseFilePattern = null
                        else
                            reverseFilePattern = null
                        entries.each ->
                            $$ = $ @
                            fileName = $$.find('.name').text()
                            if (filePattern.test fileName) and not (reverseFilePattern and reverseFilePattern.test fileName)
                                $$.removeAttr('data-project-ring-filtered')\
                                    .attr('data-project-ring-filtered', 'true')\
                                    .css 'display', 'none'
                            else
                                $$.removeAttr('data-project-ring-filtered').css 'display', ''
                    else
                        (entries.filter -> $(@).attr('data-project-ring-filtered') == 'true').each ->
                            $(@).removeAttr('data-project-ring-filtered').css 'display', ''
            ),
            0

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

    getPathFilePath: ->
        @getConfigurationFilePath @projectRingId + '_project_ring_path.txt'

    getCSONFilePath: ->
        return unless @projectRingId and not /^\s*$/.test(@projectRingId)
        csonFilePath = undefined
        _fs = require 'fs'
        try
            csonFilePath = _fs.readFileSync @getPathFilePath(), 'utf8'
        catch error
            return error
        csonFilePath

    watchProjectRingConfiguration: (watch) ->
        return unless @projectRingId
        _fs = require 'fs'
        pathFilePath = @getPathFilePath()
        csonFilePath = @getCSONFilePath()
        if watch
            if pathFilePath
                _fs.watchFile \
                    pathFilePath,
                    { persistent: true, interval: @projectRingInvariantState.configurationFileWatchInterval },
                    (currentStat, previousStat) => @setProjectRing @projectRingId # , (atom.project.path)
            if csonFilePath
                _fs.watchFile \
                    csonFilePath,
                    { persistent: true, interval: @projectRingInvariantState.configurationFileWatchInterval },
                    (currentStat, previousStat) =>
                        if @currentlySavingConfiguration.csonFile
                            @currentlySavingConfiguration.csonFile = false
                            return
                        @setProjectRing @projectRingId # , atom.project.path
        else
            _fs.unwatchFile pathFilePath if pathFilePath
            _fs.unwatchFile csonFilePath if csonFilePath

    setProjectRing: (id, projectSpecificationToLoad) ->
        @watchProjectRingConfiguration false
        id = @formatProjectRingId id
        @projectRingId = id
        pathFilePath = @getPathFilePath()
        ok = true
        _fs = require 'fs'
        _fs.exists pathFilePath, (exists) =>
            return if exists
            _fs.writeFile pathFilePath, (@getConfigurationFilePath (@projectRingId + '_project_ring.cson')), (error) ->
                ok = false if error
                alert 'Could not set project ring files for id: "' + id + '" (' + error + ')' unless ok
        return unless ok
        @loadProjectRing projectSpecificationToLoad
        @watchProjectRingConfiguration true

    # SHOULD NOT BE USED DIRECTLY BUT ONLY THROUGH setProjectRing INSTEAD
    loadProjectRing: (projectSpecificationToLoad) ->
        return unless @projectRingId and not /^\s*$/.test(@projectRingId)
        csonFilePath = @getCSONFilePath()
        return unless csonFilePath and not /^\s*$/.test(csonFilePath)
        _fs = require 'fs'
        unless _fs.existsSync csonFilePath
            @statesCache = {}
            return
        _cson = require 'season'
        try
            @statesCache = _cson.readFileSync csonFilePath
            if projectSpecificationToLoad and \
            not /^\s*$/.test(projectSpecificationToLoad) and
            @statesCache
                for stateKey in Object.keys @statesCache
                    unless @statesCache[stateKey].alias == projectSpecificationToLoad or
                    @statesCache[stateKey].projectPath == projectSpecificationToLoad
                        continue
                    @processProjectRingViewProjectSelection @statesCache[stateKey]
                    @runFilePatternHiding()
                    break
        catch error
            alert 'Could not load the project ring data for id: "' + @projectRingId + '" (' + error + ')'
            return

    saveProjectRing: ->
        return unless @projectRingId and not /^\s*$/.test(@projectRingId)
        csonFilePath = @getCSONFilePath()
        return unless csonFilePath and not /^\s*$/.test(csonFilePath)
        _cson = require 'season'
        try
            @currentlySavingConfiguration.csonFile = true
            _cson.writeFileSync csonFilePath, @statesCache
        catch error
            @currentlySavingConfiguration.csonFile = false
            alert 'Could not save the project ring data for id: "' + @projectRingId + '" (' + error + ')'
            return

    deactivate: ->
        @projectRingView.destroy() if @projectRingView

    serialize: ->

    loadProjectRingView: ->
        unless @projectRingView
            ProjectRingView = require './project-ring-view'
            @projectRingView = new ProjectRingView @ unless @projectRingView

    loadProjectRingInputView: ->
        unless @projectRingInputView
            ProjectRingInputView = require './project-ring-input-view'
            @projectRingInputView = new ProjectRingInputView(@) unless @projectRingInputView

    getOpenBufferPaths: ->
        openBufferPaths = []
        unless atom.config.get 'project-ring.skipSavingProjectBuffers'
            (atom.project.buffers.filter (buffer) -> buffer.file).forEach (buffer) ->
                openBufferPaths.push buffer.file.path
        openBufferPaths

    add: (alias, renameOnly, updateTreeViewStateOnly) ->
        @projectRingView.destroy() if @projectRingView
        return unless atom.project.path and not /^\s*$/.test(atom.project.path)
        treeView = atom.packages.getLoadedPackage 'tree-view'
        treeViewState = treeView.serialize()
        if updateTreeViewStateOnly
            return unless @hasLoadedProject and @statesCache[atom.project.path]
            @statesCache[atom.project.path].treeViewState = treeViewState
            @saveProjectRing()
            return
        alias = alias or @statesCache[atom.project.path]?.alias or (require 'path').basename atom.project.path
        alias = '...' + alias.substr alias.length - 97 if alias.length > 100
        unless @statesCache[atom.project.path]
            aliases = (Object.keys @statesCache).map (projectPath) => @statesCache[projectPath].alias
            if alias in aliases
                salt = 1
                aliasTemp = alias + salt.toString()
                while aliasTemp in aliases
                    aliasTemp = alias + (++salt).toString()
                alias = aliasTemp
        projectToLoadOnStartUp = atom.config.get 'project-ring.projectToLoadOnStartUp'
        if @statesCache[atom.project.path] and \
            (@statesCache[atom.project.path].alias == projectToLoadOnStartUp or \
            atom.project.path == projectToLoadOnStartUp) and \
            alias != @statesCache[atom.project.path].alias
                atom.config.set 'project-ring.projectToLoadOnStartUp', alias
        if renameOnly
            return unless @hasLoadedProject
            if @statesCache[atom.project.path]
                @statesCache[atom.project.path].alias = alias
                @saveProjectRing()
            return
        currentProjectState =
            alias: alias
            projectPath: atom.project.path
            treeViewState: treeViewState
            openBufferPaths: @getOpenBufferPaths()
        @statesCache[atom.project.path] = currentProjectState
        @saveProjectRing()
        @processProjectRingViewProjectSelection @statesCache[atom.project.path] unless @hasLoadedProject

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
        if @projectRingView and @projectRingView.hasParent()
            @projectRingView.destroy()
        else
            @loadProjectRingView()
            @projectRingView.attach {
                viewMode: 'project',
                openProjectBuffersOnly: openProjectBuffersOnly
                placeholderText:
                    if not openProjectBuffersOnly
                    then 'Load project...' + deleteKeyBinding
                    else 'Load buffers only...' + deleteKeyBinding
            }, @statesCache, 'alias', 'projectPath'

    delete: ->
        @projectRingView.destroy() if @projectRingView
        return unless atom.project.path and not /^\s*$/.test(atom.project.path)
        @statesCache = {} unless @statesCache
        if @hasLoadedProject and @statesCache[atom.project.path]
            @hasLoadedProject = false
        delete @statesCache[atom.project.path]
        @saveProjectRing()

    unlink: ->
        @projectRingView.destroy() if @projectRingView
        return unless atom.project.path and not /^\s*$/.test(atom.project.path)
        (atom.packages.getLoadedPackage 'tree-view')?.mainModule.treeView?.detach?()
        atom.project.setPath null
        @hasLoadedProject = false

    setProjectPath: (replace) ->
        @projectRingView.destroy() if @projectRingView
        return if replace and not @hasLoadedProject
        dialog = (require 'remote').require 'dialog'
        dialog.showOpenDialog
            title: (if not replace then 'Open' else 'Replace with')
            properties: [ 'openDirectory', 'createDirectory' ],
            (pathsToOpen) =>
                pathsToOpen = pathsToOpen or []
                return unless pathsToOpen.length
                unless replace
                    @unlink()
                    atom.project.once 'path-changed', =>
                        return unless atom.project.path and not /^\s*$/.test(atom.project.path)
                        unless atom.config.get 'project-ring.skipOpeningTreeViewWhenChangingProjectPath'
                            @runFilePatternHiding()
                            (atom.packages.getLoadedPackage 'tree-view')?.mainModule.treeView?.show?()
                    atom.project.setPath pathsToOpen[0]
                    return
                if @statesCache[atom.project.path]
                    @statesCache[pathsToOpen[0]] = @statesCache[atom.project.path]
                    @statesCache[pathsToOpen[0]].projectPath = pathsToOpen[0]
                    if @statesCache[pathsToOpen[0]].treeViewState
                        oldPathRE = new RegExp '^' + (atom.project.path.replace \
                            @projectRingInvariantState.regExpEscapesRegExp, (match) -> '\\' + match), 'i'
                        if @statesCache[pathsToOpen[0]].treeViewState.selectedPath and
                        not /^\s*$/.test(@statesCache[pathsToOpen[0]].treeViewState.selectedPath)
                            @statesCache[pathsToOpen[0]].treeViewState.selectedPath =
                                @statesCache[pathsToOpen[0]].treeViewState.selectedPath.replace \
                                    oldPathRE, pathsToOpen[0]
                        if @statesCache[pathsToOpen[0]].openBufferPaths.length
                            newOpenBufferPaths = @statesCache[pathsToOpen[0]].openBufferPaths.map (openBufferPath) ->
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
        @projectRingView.destroy() if @projectRingView
        pathFilePath = @getPathFilePath()
        csonFilePath = @getCSONFilePath()
        _fs = require 'fs'
        _fs.unlinkSync csonFilePath if _fs.existsSync csonFilePath
        _fs.unlinkSync pathFilePath if _fs.existsSync pathFilePath
        @setProjectRing 'default'
        @hasLoadedProject = false

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
        @projectRingView.destroy() if @projectRingView
        if atom.project.path and \
            @statesCache[projectState.projectPath] and \
            projectState.projectPath == atom.project.path
                @hasLoadedProject = false
        delete @statesCache[projectState.projectPath]
        @saveProjectRing()

    handleProjectRingViewSelection: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'project' \
                then (@processProjectRingViewProjectSelection data, viewModeParameters.openProjectBuffersOnly); \
                        break

    processProjectRingViewProjectSelection: (projectState, openProjectBuffersOnly) ->
        return unless projectState
        _fs = require 'fs'
        unless _fs.existsSync projectState.projectPath
            delete @statesCache[projectState.projectPath]
            @saveProjectRing()
            return
        previousProjectPath = atom.project.path
        unless openProjectBuffersOnly or projectState.projectPath == atom.project.path
            treeView = atom.packages.getLoadedPackage 'tree-view'
            atom.project.once 'path-changed', =>
                return unless atom.project.path and not /^\s*$/.test(atom.project.path)
                treeView.mainModule.treeView.updateRoot(projectState.treeViewState.directoryExpansionStates)
                @runFilePatternHiding()
                unless atom.config.get 'project-ring.skipOpeningTreeViewWhenChangingProjectPath'
                    treeView.mainModule.treeView.show()
            atom.project.setPath projectState.projectPath
        if not openProjectBuffersOnly and \
            previousProjectPath and \
            previousProjectPath != atom.project.path and \
            @statesCache[previousProjectPath] and \
            atom.project.buffers.length and \
            atom.config.get 'project-ring.closePreviousProjectBuffers'
                atom.project.once 'buffer-created.project-ring', =>
                    setTimeout (
                            ->
                                projectStateOpenBufferPaths = projectState.openBufferPaths.map (openBufferPath) ->
                                    openBufferPath.toLowerCase()
                                (atom.project.buffers.filter (buffer) ->
                                    buffer.file and \
                                    buffer.file.path.toLowerCase() \
                                        not in projectStateOpenBufferPaths).forEach (buffer) ->
                                            buffer.off 'destroyed.project-ring'
                                            buffer.save()
                                            buffer.destroy()
                        ),
                        @projectRingInvariantState.deletionDelay
                unless projectState.openBufferPaths.length
                    atom.workspaceView.triggerHandler 'application:new-file'
        if openProjectBuffersOnly or not atom.config.get 'project-ring.skipOpeningProjectBuffers'
            if projectState.openBufferPaths and projectState.openBufferPaths.length
                validOpenBufferPaths = (projectState.openBufferPaths.filter (openBufferPath) ->
                    _fs.existsSync(openBufferPath))
                unless openProjectBuffersOnly or \
                    not atom.config.get 'project-ring.keepOnlyProjectBuffersOnProjectSelection'
                        atom.project.buffers.forEach (buffer) ->
                            unless buffer.file and \
                            (validOpenBufferPaths.find (validOpenBufferPath) ->
                                validOpenBufferPath.toLowerCase() == buffer.file.path.toLowerCase())
                                    buffer.off 'destroyed.project-ring'
                                    buffer.save()
                                    buffer.destroy()
                unless openProjectBuffersOnly or \
                    projectState.openBufferPaths.length == validOpenBufferPaths.length
                        @statesCache[projectState.projectPath].openBufferPaths = validOpenBufferPaths
                        @saveProjectRing()
                currentlyOpenBufferPaths = @getOpenBufferPaths().map (openBufferPath) ->
                    openBufferPath.toLowerCase()
                bufferPathsToOpen = validOpenBufferPaths.filter (validOpenBufferPath) ->
                    validOpenBufferPath.toLowerCase() not in currentlyOpenBufferPaths
                if bufferPathsToOpen.length
                    atom.open
                        pathsToOpen: bufferPathsToOpen
                        newWindow: false
        @hasLoadedProject = true

    handleProjectRingInputViewInput: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'project' then (@processProjectRingInputViewProjectAlias data, viewModeParameters.renameOnly); break

    processProjectRingInputViewProjectAlias: (alias, renameOnly) ->
        return unless alias and not /^\s*$/.test(alias)
        @add alias, renameOnly

    copy: (copyKey) ->
        return unless @hasLoadedProject and
            atom.project.path and
            not /^\s*$/.test(atom.project.path) and
            @statesCache[atom.project.path]?[copyKey]
        try
            require('clipboard').writeText @statesCache[atom.project.path][copyKey]
        catch error
            alert error
            return

    editKeyBindings: ->
        _path = require 'path'
        keyBindingsFilePath = _path.join \
            atom.packages.getLoadedPackage('project-ring').path, 'keymaps', 'project-ring.cson'
        _fs = require 'fs'
        unless _fs.existsSync keyBindingsFilePath
            alert 'Could not find the default Project Ring key bindings file.'
            return
        atom.open
            pathsToOpen: [ keyBindingsFilePath ]
            newWindow: false
