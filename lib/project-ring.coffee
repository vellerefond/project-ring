module.exports =
    configDefaults:
        closePreviousProjectFiles: false
        filePatternToHide: null
        filePatternToExcludeFromHiding: null
        keepAllOpenFilesRegardlessOfProject: false
        keepOnlyProjectFilesOnProjectSelection: false
        keepOutOfPathOpenFilesInCurrentProject: false
        makeTheCurrentProjectTheDefaultOnStartUp: false
        projectToLoadOnStartUp: null
        skipSavingProjectFiles: false
        skipOpeningProjectFiles: false
        skipOpeningTreeViewWhenChangingProjectPath: false
        useFilePatternHiding: false

    projectRingInvariantState: null

    projectRingNotification: null

    projectRingView: null

    projectRingInputView: null

    projectRingBufferSelectView: null

    projectRingId: null

    inProject: false

    statesCache: null

    currentlySavingConfiguration: null

    currentlySettingProjectPath: false

    initialize: (state) ->
        if @projectRingInvariantState and @projectRingInvariantState.isInitialized
            return
        @projectRingInvariantState =
            emptyBufferDestroyDelayOnStartup: 750
            regExpEscapesRegExp: /[\$\^\*\(\)\[\]\{\}\|\\\.\?\+]/g
            deletionDelay: 250
            configurationFileWatchInterval: 2500
            isInitialized: true
        Object.freeze @projectRingInvariantState
        @currentlySavingConfiguration =
            csonFile: false
        @projectRingNotification = new (require './project-ring-notification')
        window.prn = @projectRingNotification # debug
        @setupAutomaticProjectBuffersSaving()
        @setupAutomaticProjectLoadingOnProjectPathChange()
        projectToLoadOnStartUp = (atom.project.path or null) ? atom.config.get 'project-ring.projectToLoadOnStartUp'
        treeView = atom.packages.getLoadedPackage 'tree-view'
        if treeView
            unless treeView?.mainModule.treeView?.updateRoot
                treeView.activate().then =>
                    setTimeout (
                            =>
                                treeView.mainModule.createView()
                                treeView.mainModule.treeView.find('.tree-view').on 'click keydown', (event) =>
                                    setTimeout (
                                            =>
                                                @add updateTreeViewStateOnly: true
                                                @runFilePatternHiding()
                                        ),
                                        0
                                @setProjectRing 'default', projectToLoadOnStartUp
                        ),
                        0
            else
                treeView.mainModule.treeView.find('.tree-view').on 'click keydown', (event) =>
                    setTimeout (
                            =>
                                @add updateTreeViewStateOnly: true
                                @runFilePatternHiding()
                        ),
                        0
                @setProjectRing 'default', projectToLoadOnStartUp
            atom.config.observe 'project-ring.useFilePatternHiding', null, (useFilePatternHiding) =>
                @runFilePatternHiding useFilePatternHiding
            atom.config.observe 'project-ring.filePatternToHide', null, (filePatternToHide) =>
                @runFilePatternHiding()
            atom.config.observe 'project-ring.filePatternToExcludeFromHiding', null, (filePatternToExcludeFromHiding) =>
                @runFilePatternHiding()
        else
            @setProjectRing 'default', projectToLoadOnStartUp
        _fs = require 'fs'
        validDefaultBufferPathsToOpen = @statesCache['<~>'].openBufferPaths.filter (openBufferPath) ->
            _fs.existsSync openBufferPath
        if validDefaultBufferPathsToOpen.length
            currentlyOpenBufferPaths = @getOpenBufferPaths().map (openBufferPath) -> openBufferPath.toLowerCase()
            bufferPathsToOpen = validDefaultBufferPathsToOpen.filter (validDefaultBufferPathToOpen) ->
                validDefaultBufferPathToOpen not in currentlyOpenBufferPaths
            if bufferPathsToOpen.length
                atom.open pathsToOpen: bufferPathsToOpen, newWindow: false
            unless @statesCache['<~>'].openBufferPaths.length is validDefaultBufferPathsToOpen.length
                @statesCache['<~>'].openBufferPaths = validDefaultBufferPathsToOpen
                @saveProjectRing()
        atom.workspaceView.command 'tree-view:toggle', => @runFilePatternHiding()
        atom.workspaceView.command "project-ring:add", => @add()
        atom.workspaceView.command "project-ring:add-as", => @addAs()
        atom.workspaceView.command "project-ring:rename", => @addAs true
        atom.workspaceView.command "project-ring:toggle", => @toggle()
        atom.workspaceView.command "project-ring:open-project-files", => @toggle true
        atom.workspaceView.command "project-ring:add-current-file-to-current-project", =>
            @addOpenBufferPathToProject null, true
        atom.workspaceView.command "project-ring:add-files-to-current-project", => @addFilesToProject()
        atom.workspaceView.command "project-ring:ban-current-file-from-current-project", =>
            @banOpenBufferPathFromProject()
        atom.workspaceView.command "project-ring:ban-files-from-current-project", => @banFilesFromProject()
        atom.workspaceView.command "project-ring:always-open-current-file", => @alwaysOpenBufferPath()
        atom.workspaceView.command "project-ring:always-open-files", => @alwaysOpenFiles()
        atom.workspaceView.command "project-ring:delete", => @delete()
        atom.workspaceView.command "project-ring:unlink", => @unlink()
        atom.workspaceView.command "project-ring:set-project-path", => @setProjectPath()
        atom.workspaceView.command "project-ring:delete-project-ring", => @deleteProjectRing()
        atom.workspaceView.command "project-ring:copy-project-alias", => @copy 'alias'
        atom.workspaceView.command "project-ring:copy-project-path", => @copy 'projectPath'
        atom.workspaceView.command "project-ring:move-project-path", => @setProjectPath true
        atom.workspaceView.command "project-ring:edit-key-bindings", => @editKeyBindings()

    activate: (state) ->
        setTimeout (=> @initialize state), 0

    setupAutomaticProjectBuffersSaving: ->
        atom.config.observe 'project-ring.skipSavingProjectFiles', null, (skipSavingProjectFiles) =>
            if skipSavingProjectFiles
                atom.project.off 'buffer-created.project-ring'
                atom.project.buffers.forEach (buffer) -> buffer.off 'destroyed.project-ring'
                return unless @inProject
                @statesCache[atom.project.path].openBufferPaths = []
                @saveProjectRing()
            else
                onBufferDestroyedProjectRingEventHandlerFactory = (bufferDestroyed) =>
                    =>
                        return unless bufferDestroyed.file
                        setTimeout (
                                =>
                                    bufferDestroyedPathProxy = bufferDestroyed.file.path.toLowerCase()
                                    if (@statesCache['<~>'].openBufferPaths.find (openBufferPath) ->
                                        openBufferPath.toLowerCase() is bufferDestroyedPathProxy)
                                            @statesCache['<~>'].openBufferPaths =
                                                @statesCache['<~>'].openBufferPaths.filter (openBufferPath) ->
                                                    openBufferPath.toLowerCase() isnt bufferDestroyedPathProxy
                                            @saveProjectRing()
                                            return
                                    return unless @inProject
                                    if (@statesCache[atom.project.path].openBufferPaths.find (openBufferPath) ->
                                            openBufferPath.toLowerCase() is bufferDestroyedPathProxy)
                                        @statesCache[atom.project.path].openBufferPaths =
                                            @statesCache[atom.project.path].openBufferPaths.filter (openBufferPath) =>
                                                openBufferPath.toLowerCase() isnt bufferDestroyedPathProxy
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
                    if atom.config.get 'project-ring.keepAllOpenFilesRegardlessOfProject'
                        @alwaysOpenBufferPath openProjectBuffer.file.path
                        return
                    return unless \
                        atom.project.path and \
                        (new RegExp(
                            '^' + @turnToPathRegExp(atom.project.path), 'i'
                        ).test(openProjectBuffer.file.path) or \
                        atom.config.get 'project-ring.keepOutOfPathOpenFilesInCurrentProject')
                    @addOpenBufferPathToProject openProjectBuffer.file.path
        setTimeout (
                =>
                    atom.workspaceView.find('.tab-bar').on 'drop', =>
                        setTimeout (=> @add updateOpenBufferPathPositionsOnly: true), 0
            ),
            0

    setupAutomaticProjectLoadingOnProjectPathChange: ->
        atom.project.on 'path-changed', =>
            return unless atom.project.path and not @inProject and not @currentlySettingProjectPath
            @processProjectRingViewProjectSelection
                projectState: @statesCache[atom.project.path]
                isAsynchronousProjectPathChange: true

    runFilePatternHiding: (useFilePatternHiding) ->
        setTimeout (
                =>
                    useFilePatternHiding =
                        if typeof useFilePatternHiding isnt 'undefined'
                        then useFilePatternHiding
                        else atom.config.get 'project-ring.useFilePatternHiding'
                    entries = atom.packages.getLoadedPackage('tree-view')?.mainModule.treeView?.\
                        find('.tree-view > .directory > .entries').find('.directory, .file') ? []
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
                            $fileMetadata = $$.find('.name')
                            filePath = $fileMetadata.attr('data-path')
                            fileName = $fileMetadata.text()
                            if ((filePattern.test filePath) and \
                                not (reverseFilePattern and reverseFilePattern.test filePath)) or \
                                ((filePattern.test fileName) and \
                                not (reverseFilePattern and reverseFilePattern.test fileName))
                                    $$.removeAttr('data-project-ring-filtered')\
                                        .attr('data-project-ring-filtered', 'true')\
                                        .css 'display', 'none'
                            else
                                $$.removeAttr('data-project-ring-filtered').css 'display', ''
                    else
                        (entries.filter -> $(@).attr('data-project-ring-filtered') is 'true').each ->
                            $(@).removeAttr('data-project-ring-filtered').css 'display', ''
            ),
            0

    getConfigurationPath: ->
        _path = require 'path'
        path = _path.join process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME'],
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
        return unless @projectRingId
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
                    (currentStat, previousStat) => @setProjectRing @projectRingId # , atom.project.path
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
        unless _fs.existsSync pathFilePath
            try
                _fs.writeFileSync pathFilePath, (@getConfigurationFilePath @projectRingId + '_project_ring.cson')
            catch error
                ok = false
                alert 'Could not set project ring files for id: "' + id + '" (' + error + ')'
        return unless ok
        @loadProjectRing projectSpecificationToLoad
        @watchProjectRingConfiguration true

    loadProjectRing: (projectSpecificationToLoad) ->
        return unless @projectRingId
        csonFilePath = @getCSONFilePath()
        return unless csonFilePath
        _fs = require 'fs'
        unless _fs.existsSync csonFilePath
            @statesCache = '<~>': openBufferPaths: [], isIgnored: true
            return
        _cson = require 'season'
        try
            @statesCache = _cson.readFileSync csonFilePath
            if \
                projectSpecificationToLoad and \
                not /^\s*$/.test(projectSpecificationToLoad) and \
                @statesCache
                    for stateKey in Object.keys @statesCache
                        unless \
                            not @statesCache[stateKey].isIgnored and \
                            (@statesCache[stateKey].alias is projectSpecificationToLoad or \
                             @statesCache[stateKey].projectPath is projectSpecificationToLoad)
                                continue
                        @processProjectRingViewProjectSelection projectState: @statesCache[stateKey], isDefault: true
                        @runFilePatternHiding()
                        break
        catch error
            alert 'Could not load the project ring data for id: "' + @projectRingId + '" (' + error + ')'
            return
        @statesCache['<~>'] = openBufferPaths: [], isIgnored: true unless @statesCache['<~>']

    saveProjectRing: ->
        return unless @projectRingId
        csonFilePath = @getCSONFilePath()
        return unless csonFilePath
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
        @projectRingInputView.destroy() if @projectRingInputView
        @projectRingBufferSelectView.destroy() if @projectRingBufferSelectView

    serialize: ->

    loadProjectRingView: ->
        unless @projectRingView
            ProjectRingView = require './project-ring-view'
            @projectRingView = new ProjectRingView @ unless @projectRingView

    loadProjectRingInputView: ->
        unless @projectRingInputView
            @projectRingInputView = new (require './project-ring-input-view') @

    loadProjectRingBufferSelectView: ->
        unless @projectRingBufferSelectView
            @projectRingBufferSelectView = new (require './project-ring-buffer-select-view') @

    getOpenBufferPaths: ->
        unless atom.config.get 'project-ring.skipSavingProjectFiles'
            return \
                (atom.workspace.getEditors().filter (editor) ->
                    editor.buffer.file).map (editor) ->
                        editor.buffer.file.path
        return []

    turnToPathRegExp: (path) ->
        return '' unless path
        path.replace @projectRingInvariantState.regExpEscapesRegExp, (match) -> '\\' + match

    checkIfInProject: (omitAlert) ->
        unless @inProject or (omitAlert ? true)
            alert 'You have not loaded a project yet.'
        @inProject

    addOpenBufferPathToProject: (openBufferPathToAdd, manually) ->
        return unless @checkIfInProject not manually
        deferedAddition = if openBufferPathToAdd and not manually then true else false
        openBufferPathToAdd = atom.workspace.getActiveEditor()?.buffer.file?.path unless openBufferPathToAdd
        return unless openBufferPathToAdd
        openBufferPathToAdd = openBufferPathToAdd.toLowerCase()
        return if \
            not manually and \
            (@statesCache[atom.project.path].bannedBufferPaths.find (bannedBufferPath) -> \
                bannedBufferPath.toLowerCase() is openBufferPathToAdd)
        if manually
            @statesCache['<~>'].openBufferPaths =
                @statesCache['<~>'].openBufferPaths.filter (openBufferPath) ->
                    openBufferPath.toLowerCase() isnt openBufferPathToAdd
        unless (@statesCache[atom.project.path].openBufferPaths.find (openBufferPath) ->
            openBufferPath.toLowerCase() is openBufferPathToAdd)
                atom.workspace.once 'editor-created.project-ring editor-created-forced.project-ring', =>
                    setTimeout (
                        =>
                            @statesCache[atom.project.path].bannedBufferPaths =
                                @statesCache[atom.project.path].bannedBufferPaths.filter (bannedBufferPath) ->
                                    bannedBufferPath.toLowerCase() isnt openBufferPathToAdd
                            newOpenBufferPaths = @getOpenBufferPaths().filter (openBufferPathInAll) =>
                                openBufferPathInAll.toLowerCase() is openBufferPathToAdd or \
                                    @statesCache[atom.project.path].openBufferPaths.find (openBufferPath) ->
                                        openBufferPath.toLowerCase() is openBufferPathInAll.toLowerCase()
                            @statesCache[atom.project.path].openBufferPaths = newOpenBufferPaths
                            @saveProjectRing()
                    ),
                    0
                unless deferedAddition
                    atom.workspace.emit 'editor-created-forced.project-ring'

    banOpenBufferPathFromProject: (openBufferPathToBan) ->
        return unless @checkIfInProject()
        openBufferPathToBan = atom.workspace.getActiveEditor()?.buffer.file?.path unless openBufferPathToBan
        return unless openBufferPathToBan
        openBufferPathToBanProxy = openBufferPathToBan.toLowerCase()
        unless (@statesCache[atom.project.path].bannedBufferPaths.find (openBufferPath) ->
            openBufferPath.toLowerCase() is openBufferPathToBanProxy)
                @statesCache[atom.project.path].openBufferPaths =
                    @statesCache[atom.project.path].openBufferPaths.filter (openBufferPath) ->
                        openBufferPath.toLowerCase() isnt openBufferPathToBanProxy
                @statesCache[atom.project.path].bannedBufferPaths.push openBufferPathToBan
                @saveProjectRing()

    alwaysOpenBufferPath: (bufferPathToAlwaysOpen) ->
        bufferPathToAlwaysOpen = atom.workspace.getActiveEditor()?.buffer.file?.path unless bufferPathToAlwaysOpen
        bufferPathToAlwaysOpenProxy = bufferPathToAlwaysOpen?.toLowerCase()
        return unless \
            bufferPathToAlwaysOpen and \
            not (@statesCache['<~>'].openBufferPaths.find (openBufferPath) -> \
                openBufferPath.toLowerCase() is bufferPathToAlwaysOpenProxy)
        for stateKey in Object.keys @statesCache
            continue if @statesCache[stateKey].isIgnored
            @statesCache[stateKey].openBufferPaths = @statesCache[stateKey].openBufferPaths.filter (openBufferPath) ->
                openBufferPath.toLowerCase() isnt bufferPathToAlwaysOpenProxy
        @statesCache['<~>'].openBufferPaths.push bufferPathToAlwaysOpen
        @saveProjectRing()

    add: (options) ->
        options = options or {}
        @projectRingView.destroy() if @projectRingView
        return unless atom.project.path and not /^\s*$/.test atom.project.path
        treeViewState = atom.packages.getLoadedPackage('tree-view')?.serialize()
        if options.updateTreeViewStateOnly
            return unless @checkIfInProject()
            @statesCache[atom.project.path].treeViewState = treeViewState
            @saveProjectRing()
            return
        if options.updateOpenBufferPathPositionsOnly
            return unless @checkIfInProject()
            currentProjectOpenBufferPaths = @statesCache[atom.project.path].openBufferPaths.map (openBufferPath) ->
                openBufferPath.toLowerCase()
            @statesCache[atom.project.path].openBufferPaths = @getOpenBufferPaths().filter (openBufferPath) ->
                openBufferPath.toLowerCase() in currentProjectOpenBufferPaths
            @saveProjectRing()
            return
        alias = options.alias or @statesCache[atom.project.path]?.alias or require('path').basename atom.project.path
        alias = '...' + alias.substr alias.length - 97 if alias.length > 100
        unless @statesCache[atom.project.path]
            aliases = (Object.keys(@statesCache).filter (projectPath) =>
                not @statesCache[projectPath].isIgnored).map (projectPath) => @statesCache[projectPath].alias
            if alias in aliases
                salt = 1
                aliasTemp = alias + salt.toString()
                while aliasTemp in aliases
                    aliasTemp = alias + (++salt).toString()
                alias = aliasTemp
        projectToLoadOnStartUp = atom.config.get 'project-ring.projectToLoadOnStartUp' or ''
        if @statesCache[atom.project.path] and \
            (@statesCache[atom.project.path].alias is projectToLoadOnStartUp or \
            atom.project.path.toLowerCase() is projectToLoadOnStartUp.toLowerCase()) and \
            alias isnt @statesCache[atom.project.path].alias
                atom.config.set 'project-ring.projectToLoadOnStartUp', alias
        if options.renameOnly
            return unless @checkIfInProject()
            if @statesCache[atom.project.path]
                @statesCache[atom.project.path].alias = alias
                @saveProjectRing()
            return
        bufferPathsToAlwaysOpen = @statesCache['<~>'].openBufferPaths.map (openBufferPath) ->
            openBufferPath.toLowerCase()
        currentProjectState =
            alias: alias
            projectPath: atom.project.path
            treeViewState: treeViewState
            openBufferPaths: @getOpenBufferPaths().filter (openBufferPath) ->
                openBufferPath.toLowerCase() not in bufferPathsToAlwaysOpen
            bannedBufferPaths: []
        @statesCache[atom.project.path] = currentProjectState
        @saveProjectRing()
        unless @checkIfInProject()
            @processProjectRingViewProjectSelection projectState: @statesCache[atom.project.path]

    addAs: (renameOnly) ->
        @loadProjectRingInputView()
        unless @projectRingInputView.hasParent()
            alias = atom.project.path
            if @statesCache[atom.project.path]
            then (
                if @statesCache[atom.project.path].alias is @statesCache[atom.project.path].projectPath
                then alias = (require 'path').basename @statesCache[atom.project.path].projectPath
                else alias = @statesCache[atom.project.path].alias
            )
            else alias = (require 'path').basename (if alias then alias else '')
            @projectRingInputView.attach {
                viewMode: 'project',
                renameOnly: renameOnly
            }, 'Project alias', alias

    toggle: (openProjectBuffersOnly) ->
        deleteKeyBinding = atom.keymap.getKeyBindings().find (keyBinding) -> keyBinding.command is 'project-ring:add'
        if deleteKeyBinding
        then deleteKeyBinding =
            ' (delete selected: ' + deleteKeyBinding.keystrokes.split(/\s+/)[0].replace(/-[^-]+$/, '-') + 'delete)'
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
                    else 'Load files only...' + deleteKeyBinding
            }, @statesCache, 'alias', 'projectPath'

    addFilesToProject: ->
        return unless @checkIfInProject()
        @loadProjectRingBufferSelectView()
        unless @projectRingBufferSelectView.hasParent()
            bufferPathsToOfferForAddition = []
            buffersOfCurrentProject =
                @statesCache[atom.project.path].openBufferPaths.map (openBufferPath) -> openBufferPath.toLowerCase()
            (Object.keys(@statesCache).filter (projectPath) =>
                not @statesCache[projectPath].isIgnored and \
                projectPath isnt atom.project.path).forEach (projectPath) =>
                    (@statesCache[projectPath].openBufferPaths.filter (openBufferPath) ->
                        openBufferPathProxy = openBufferPath.toLowerCase()
                        openBufferPathProxy not in buffersOfCurrentProject and \
                        not (bufferPathsToOfferForAddition.find (bufferPathSpec) ->
                            bufferPathSpec.path.toLowerCase() is openBufferPathProxy)).forEach (openBufferPath) =>
                                description = openBufferPath
                                if description.length > 40
                                    description = '...' + description.substr description.length - 37
                                bufferPathsToOfferForAddition.push
                                    title: @statesCache[projectPath].alias
                                    description: description
                                    path: openBufferPath
            (atom.project.buffers.filter (buffer) ->
                bufferPathProxy = buffer.file?.path.toLowerCase()
                buffer.file and \
                bufferPathProxy not in buffersOfCurrentProject and \
                not (bufferPathsToOfferForAddition.find (bufferPathSpec) ->
                    bufferPathSpec.path.toLowerCase() is bufferPathProxy)).forEach (buffer) ->
                        description = buffer.file.path
                        description = '...' + description.substr description.length - 37 if description.length > 40
                        bufferPathsToOfferForAddition.push
                            title: 'Not In Project'
                            description: description
                            path: buffer.file.path
            bufferPathsToOfferForAddition.sort (bufferPathSpec1, bufferPathSpec2) ->
                if bufferPathSpec1.title is 'Not In Project' and bufferPathSpec2.title is 'Not In Project'
                    return bufferPathSpec1.title.toLowerCase() <= bufferPathSpec2.title.toLowerCase()
                return true if bufferPathSpec1.title is 'Not In Project'
                return false if bufferPathSpec2.title is 'Not in Project'
                bufferPathSpec1.title.toLowerCase() <= bufferPathSpec2.title.toLowerCase()
            @projectRingBufferSelectView.attach { viewMode: 'add', confirmValue: 'Add' }, bufferPathsToOfferForAddition

    banFilesFromProject: ->
        return unless @checkIfInProject()
        @loadProjectRingBufferSelectView()
        unless @projectRingBufferSelectView.hasParent()
            bufferPathsToOfferForBanning = []
            (atom.project.buffers.filter (buffer) ->
                buffer.file and \
                not (bufferPathsToOfferForBanning.find (bufferPathSpec) ->
                    bufferPathSpec.path.toLowerCase() is buffer.file.path.toLowerCase())).forEach (buffer) ->
                        description = buffer.file.path
                        description = '...' + description.substr description.length - 37 if description.length > 40
                        bufferPathsToOfferForBanning.push
                            title: require('path').basename buffer.file.path
                            description: description
                            path: buffer.file.path
            bufferPathsToOfferForBanning.sort()
            @projectRingBufferSelectView.attach { viewMode: 'ban', confirmValue: 'Ban' }, bufferPathsToOfferForBanning

    alwaysOpenFiles: ->
        return unless @checkIfInProject()
        @loadProjectRingBufferSelectView()
        unless @projectRingBufferSelectView.hasParent()
            bufferPathsToOfferForAlwaysOpening = []
            (atom.project.buffers.filter (buffer) ->
                buffer.file and \
                not (bufferPathsToOfferForAlwaysOpening.find (bufferPathSpec) ->
                    bufferPathSpec.path.toLowerCase() is buffer.file.path.toLowerCase())).forEach (buffer) ->
                        description = buffer.file.path
                        description = '...' + description.substr description.length - 37 if description.length > 40
                        bufferPathsToOfferForAlwaysOpening.push
                            title: require('path').basename buffer.file.path
                            description: description
                            path: buffer.file.path
            bufferPathsToOfferForAlwaysOpening.sort()
            @projectRingBufferSelectView.attach \
                { viewMode: 'always-open', confirmValue: 'Always Open' }, bufferPathsToOfferForAlwaysOpening

    delete: ->
        @projectRingView.destroy() if @projectRingView
        return unless atom.project.path and not /^\s*$/.test atom.project.path
        @statesCache = {} unless @statesCache
        @inProject = false if @inProject
        delete @statesCache[atom.project.path]
        @saveProjectRing()

    unlink: ->
        @projectRingView.destroy() if @projectRingView
        return unless atom.project.path and not /^\s*$/.test atom.project.path
        (atom.packages.getLoadedPackage 'tree-view')?.mainModule.treeView?.detach?()
        atom.project.setPath null
        @inProject = false

    setProjectPath: (replace) ->
        @projectRingView.destroy() if @projectRingView
        return if replace and not @checkIfInProject()
        dialog = (require 'remote').require 'dialog'
        dialog.showOpenDialog
            title: (if not replace then 'Open' else 'Replace with')
            properties: [ 'openDirectory', 'createDirectory' ],
            (pathsToOpen) =>
                pathsToOpen = pathsToOpen or []
                return unless pathsToOpen.length
                unless replace
                    @unlink()
                    @currentlySettingProjectPath = true
                    atom.project.once 'path-changed', =>
                        @currentlySettingProjectPath = false
                        return unless atom.project.path and not /^\s*$/.test atom.project.path
                        unless atom.config.get 'project-ring.skipOpeningTreeViewWhenChangingProjectPath'
                            @runFilePatternHiding()
                            (atom.packages.getLoadedPackage 'tree-view')?.mainModule.treeView?.show?()
                    atom.project.setPath pathsToOpen[0]
                    return
                if @statesCache[atom.project.path]
                    @statesCache[pathsToOpen[0]] = @statesCache[atom.project.path]
                    @statesCache[pathsToOpen[0]].projectPath = pathsToOpen[0]
                    if @statesCache[pathsToOpen[0]].treeViewState
                        oldPathRE = new RegExp '^' + (@turnToPathRegExp atom.project.path), 'i'
                        if @statesCache[pathsToOpen[0]].treeViewState.selectedPath and
                        not /^\s*$/.test @statesCache[pathsToOpen[0]].treeViewState.selectedPath
                            @statesCache[pathsToOpen[0]].treeViewState.selectedPath =
                                @statesCache[pathsToOpen[0]].treeViewState.selectedPath.replace \
                                    oldPathRE, pathsToOpen[0]
                        if @statesCache[pathsToOpen[0]].openBufferPaths.length
                            newOpenBufferPaths = @statesCache[pathsToOpen[0]].openBufferPaths.map (openBufferPath) ->
                                openBufferPath.replace oldPathRE, pathsToOpen[0]
                            @statesCache[pathsToOpen[0]].openBufferPaths = newOpenBufferPaths
                    delete @statesCache[atom.project.path]
                atom.project.setPath pathsToOpen[0]
                if not @statesCache[pathsToOpen[0]]
                    @add()
                else
                    @saveProjectRing()
                @processProjectRingViewProjectSelection projectState: @statesCache[pathsToOpen[0]]

    deleteProjectRing: ->
        return unless @projectRingId and not /^\s*$/.test @projectRingId
        @projectRingView.destroy() if @projectRingView
        pathFilePath = @getPathFilePath()
        csonFilePath = @getCSONFilePath()
        _fs = require 'fs'
        _fs.unlinkSync csonFilePath if _fs.existsSync csonFilePath
        _fs.unlinkSync pathFilePath if _fs.existsSync pathFilePath
        @setProjectRing 'default'
        @inProject = false

    handleProjectRingViewKeydown: (keydownEvent, viewModeParameters, selectedItem) ->
        return unless keydownEvent and selectedItem
        # alt-shift-delete
        if viewModeParameters.viewMode is 'project' and
        keydownEvent.altKey and
        keydownEvent.shiftKey and
        keydownEvent.which is 46
            @processProjectRingViewProjectDeletion selectedItem.data

    processProjectRingViewProjectDeletion: (projectState) ->
        return unless projectState and @statesCache and @statesCache[projectState.projectPath]
        @projectRingView.destroy() if @projectRingView
        if atom.project.path and \
            @statesCache[projectState.projectPath] and \
            projectState.projectPath is atom.project.path
                @inProject = false
        delete @statesCache[projectState.projectPath]
        @saveProjectRing()

    handleProjectRingViewSelection: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'project' then \
                (@processProjectRingViewProjectSelection
                    projectState: data
                    openProjectBuffersOnly: viewModeParameters.openProjectBuffersOnly); \
                break

    processProjectRingViewProjectSelection: (options) ->
        options = options or {}
        return unless options.projectState
        _fs = require 'fs'
        unless _fs.existsSync options.projectState.projectPath
            delete @statesCache[options.projectState.projectPath]
            @saveProjectRing()
            return
        unless @statesCache[options.projectState.projectPath].openBufferPaths
            @statesCache[options.projectState.projectPath].openBufferPaths = []
            options.projectState.openBufferPaths = []
        unless @statesCache[options.projectState.projectPath].bannedBufferPaths
            @statesCache[options.projectState.projectPath].bannedBufferPaths = []
            options.projectState.bannedBufferPaths = []
        previousProjectPath = atom.project.path
        unless options.openProjectBuffersOnly
            unless options.projectState.projectPath is atom.project.path and not options.isAsynchronousProjectPathChange
                @currentlySettingProjectPath = true
                treeView = atom.packages.getLoadedPackage 'tree-view'
                atom.project.once 'path-changed', =>
                    @currentlySettingProjectPath = false
                    return unless atom.project.path and not /^\s*$/.test atom.project.path
                    treeView?.mainModule.treeView?.updateRoot? \
                        options.projectState.treeViewState.directoryExpansionStates
                    @runFilePatternHiding()
                    unless atom.config.get 'project-ring.skipOpeningTreeViewWhenChangingProjectPath'
                        treeView?.mainModule.treeView?.show?()
                    @inProject = true
                atom.project.setPath options.projectState.projectPath
            else
                @inProject = true
            if atom.config.get 'project-ring.makeTheCurrentProjectTheDefaultOnStartUp'
                atom.config.set 'project-ring.projectToLoadOnStartUp', options.projectState.alias
        validOpenBufferPaths = options.projectState.openBufferPaths.filter (openBufferPath) -> _fs.existsSync(openBufferPath)
        if \
            not options.openProjectBuffersOnly and \
            previousProjectPath and \
            previousProjectPath isnt atom.project.path and \
            @statesCache[previousProjectPath] and \
            atom.project.buffers.length and \
            atom.config.get 'project-ring.closePreviousProjectFiles'
                previousProjectStateOpenBufferPaths =
                    @statesCache[previousProjectPath].openBufferPaths.map (openBufferPath) ->
                        openBufferPath.toLowerCase()
                atom.project.once 'buffer-created.project-ring', (bufferCreated) =>
                    setTimeout (
                            =>
                                projectStateOpenBufferPaths =
                                    options.projectState.openBufferPaths.map (openBufferPath) ->
                                        openBufferPath.toLowerCase()
                                (atom.project.buffers.filter (buffer) ->
                                    bufferPath = buffer.file?.path.toLowerCase()
                                    bufferPath and \
                                    bufferPath in previousProjectStateOpenBufferPaths and \
                                    bufferPath not in projectStateOpenBufferPaths).forEach (buffer) ->
                                            buffer.off 'destroyed.project-ring'
                                            buffer.save()
                                            buffer.destroy()
                        ),
                        @projectRingInvariantState.deletionDelay
                unless \
                    (validOpenBufferPaths.length and \
                    not atom.config.get 'project-ring.skipOpeningProjectFiles') or \
                    (atom.project.buffers.find (buffer) ->
                        not buffer.file or \
                        buffer.file.path.toLowerCase() not in previousProjectStateOpenBufferPaths)
                            atom.workspaceView.triggerHandler 'application:new-file'
        if options.openProjectBuffersOnly or not atom.config.get 'project-ring.skipOpeningProjectFiles'
            if options.projectState.openBufferPaths and options.projectState.openBufferPaths.length
                unless \
                    options.openProjectBuffersOnly or \
                    not atom.config.get 'project-ring.keepOnlyProjectFilesOnProjectSelection'
                        atom.project.buffers.forEach (buffer) =>
                            bufferPathProxy = buffer.file.path.toLowerCase()
                            unless \
                                buffer.file and \
                                ((@statesCache['<~>'].openBufferPaths.find (openBufferPath) -> \
                                    openBufferPath.toLowerCase() is bufferPathProxy) or \
                                (validOpenBufferPaths.find (validOpenBufferPath) ->
                                    validOpenBufferPath.toLowerCase() is bufferPathProxy))
                                        buffer.off 'destroyed.project-ring'
                                        buffer.save()
                                        buffer.destroy()
                unless \
                    options.openProjectBuffersOnly or \
                    options.projectState.openBufferPaths.length is validOpenBufferPaths.length
                        @statesCache[projectState.projectPath].openBufferPaths = validOpenBufferPaths
                        @saveProjectRing()
                currentlyOpenBufferPaths = @getOpenBufferPaths().map (openBufferPath) ->
                    openBufferPath.toLowerCase()
                bufferPathsToOpen = validOpenBufferPaths.filter (validOpenBufferPath) ->
                    validOpenBufferPath.toLowerCase() not in currentlyOpenBufferPaths
                if bufferPathsToOpen.length
                    atom.open pathsToOpen: bufferPathsToOpen, newWindow: false
                    if options.isDefault
                        atom.project.on 'buffer-created.project-ring-remove-empty', (bufferCreated) =>
                            return unless bufferCreated.file
                            atom.project.off 'buffer-created.project-ring-remove-empty'
                            setTimeout (
                                    ->
                                        (atom.project.buffers.filter (buffer) ->
                                            not buffer.file and buffer.cachedText is '').forEach (buffer) ->
                                                return if bufferCreated is buffer
                                                buffer.off 'destroyed.project-ring'
                                                buffer.destroy()
                                ),
                                @projectRingInvariantState.emptyBufferDestroyDelayOnStartup

    handleProjectRingInputViewInput: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'project' then (@processProjectRingInputViewProjectAlias data, viewModeParameters.renameOnly); break

    processProjectRingInputViewProjectAlias: (alias, renameOnly) ->
        return unless alias and not /^\s*$/.test alias
        @add alias: alias, renameOnly: renameOnly

    handleProjectRingBufferSelectViewSelection: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'add' then (@processProjectRingBufferSelectViewSelection data, true); break
            when 'ban' then (@processProjectRingBufferSelectViewSelection data, false, true); break
            when 'always-open' then (@processProjectRingBufferSelectViewSelection data, false, false, true); break

    processProjectRingBufferSelectViewSelection: (paths, add, ban, alwaysOpen) ->
        return unless paths and paths.length and (if add or ban then @checkIfInProject() else true)
        if add
            paths.forEach (path) => @addOpenBufferPathToProject path, true
        else if ban
            paths.forEach (path) => @banOpenBufferPathFromProject path
        else if alwaysOpen
            paths.forEach (path) => @alwaysOpenBufferPath path

    copy: (copyKey) ->
        return unless \
            @checkIfInProject() and \
            not /^\s*$/.test(atom.project.path) and \
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
        atom.open pathsToOpen: [ keyBindingsFilePath ], newWindow: false
