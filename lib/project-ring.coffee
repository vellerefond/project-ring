module.exports =
    configDefaults:
        closePreviousProjectFiles: true
        filePatternToHide: null
        filePatternToExcludeFromHiding: null
        keepAllOpenFilesRegardlessOfProject: false
        keepOutOfPathOpenFilesInCurrentProject: false
        makeTheCurrentProjectTheDefaultOnStartUp: true
        projectToLoadOnStartUp: null
        doNotSaveAndRestoreOpenProjectFiles: false
        skipOpeningTreeViewWhenChangingProjectPath: false
        useFilePatternHiding: false
        useNotifications: true

    activate: (state) ->
        setTimeout (=> @initialize state), 0

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
        @setupProjectRingNotification()
        @setupAutomaticProjectBuffersSaving()
        @setupAutomaticProjectLoadingOnProjectPathChange()
        atom.config.observe \
            'project-ring.makeTheCurrentProjectTheDefaultOnStartUp', (makeTheCurrentProjectTheDefaultOnStartUp) =>
                atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
                return unless \
                    @inProject and
                    makeTheCurrentProjectTheDefaultOnStartUp and
                    @statesCache[atomProjectPathAsKeyProxy]
                atom.config.set 'project-ring.projectToLoadOnStartUp', @statesCache[atomProjectPathAsKeyProxy].alias
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
            atom.config.observe 'project-ring.useFilePatternHiding', (useFilePatternHiding) =>
                @runFilePatternHiding useFilePatternHiding
            atom.config.observe 'project-ring.filePatternToHide', (filePatternToHide) =>
                @runFilePatternHiding()
            atom.config.observe 'project-ring.filePatternToExcludeFromHiding', (filePatternToExcludeFromHiding) =>
                @runFilePatternHiding()
        else
            @setProjectRing 'default', projectToLoadOnStartUp
        atom.project.once 'project-ring-states-cache-initialized', =>
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

    setupProjectRingNotification: ->
        @projectRingNotification = new (require './project-ring-notification')
        atom.config.observe 'project-ring.useNotifications', (useNotifications) =>
            @projectRingNotification.isEnabled = useNotifications

    setupAutomaticProjectBuffersSaving: ->
        atom.config.observe 'project-ring.doNotSaveAndRestoreOpenProjectFiles', (doNotSaveAndRestoreOpenProjectFiles) =>
            if doNotSaveAndRestoreOpenProjectFiles
                atom.project.off 'buffer-created.project-ring'
                atom.project.buffers.forEach (buffer) -> buffer.off 'destroyed.project-ring'
                return unless @inProject
                @statesCache[@getAtomProjectPathAsKey()].openBufferPaths = []
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
                                    atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
                                    if (@statesCache[atomProjectPathAsKeyProxy].openBufferPaths.find (openBufferPath) ->
                                            openBufferPath.toLowerCase() is bufferDestroyedPathProxy)
                                        @statesCache[atomProjectPathAsKeyProxy].openBufferPaths =
                                            @statesCache[atomProjectPathAsKeyProxy].openBufferPaths
                                                .filter (openBufferPath) =>
                                                    openBufferPath.toLowerCase() isnt bufferDestroyedPathProxy
                                        @saveProjectRing()
                            ),
                            @projectRingInvariantState.deletionDelay
                atom.project.buffers.forEach (buffer) =>
                    buffer.off 'destroyed.project-ring'
                    buffer.on \
                        'destroyed.project-ring',
                        onBufferDestroyedProjectRingEventHandlerFactory buffer
                atom.project.on 'buffer-created.project-ring', (openProjectBuffer) =>
                    return unless openProjectBuffer.file
                    openProjectBuffer.off 'destroyed.project-ring'
                    openProjectBuffer.on \
                        'destroyed.project-ring',
                        onBufferDestroyedProjectRingEventHandlerFactory openProjectBuffer
                    if atom.config.get 'project-ring.keepAllOpenFilesRegardlessOfProject'
                        @alwaysOpenBufferPath openProjectBuffer.file.path
                        return
                    return unless \
                        atom.project.path and
                        (new RegExp(
                            '^' + @turnToPathRegExp(atom.project.path), 'i'
                        ).test(openProjectBuffer.file.path) or
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
            return unless atom.project.path and not @currentlySettingProjectPath
            @unlink true, true
            @processProjectRingViewProjectSelection
                projectState: @statesCache[@getAtomProjectPathAsKey()]
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

    getAtomProjectPathAsKey: (path) ->
        (path or atom.project.path)?.toLowerCase()

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
                @projectRingNotification.alert 'Could not set project ring files for id: "' + id + '" (' + error + ')'
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
                        setTimeout (
                                =>
                                    @processProjectRingViewProjectSelection projectState: @statesCache[stateKey]
                                    @runFilePatternHiding()
                            ),
                            0
                        break
        catch error
            @projectRingNotification.alert \
                'Could not load the project ring data for id: "' + @projectRingId + '" (' + error + ')'
            return
        @statesCache['<~>'] = openBufferPaths: [], isIgnored: true unless @statesCache['<~>']
        # ENSURE THAT ALL @statesCache KEYS ARE LOWERCASE
        fixedStatesCacheKeys = false
        for stateKey in Object.keys @statesCache
            stateKeyProxy = @getAtomProjectPathAsKey stateKey
            unless stateKey is stateKeyProxy
                @statesCache[stateKeyProxy] = @statesCache[stateKey]
                delete @statesCache[stateKey]
                fixedStatesCacheKeys = true
        @saveProjectRing() if fixedStatesCacheKeys
        atom.project.emit 'project-ring-states-cache-initialized'


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
            @projectRingNotification.alert \
                'Could not save the project ring data for id: "' + @projectRingId + '" (' + error + ')'
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
        unless atom.config.get 'project-ring.doNotSaveAndRestoreOpenProjectFiles'
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
            @projectRingNotification.alert 'You have not loaded a project yet.'
        @inProject

    addOpenBufferPathToProject: (openBufferPathToAdd, manually) ->
        return unless @checkIfInProject not manually
        deferedAddition = if openBufferPathToAdd and not manually then true else false
        openBufferPathToAdd = atom.workspace.getActiveEditor()?.buffer.file?.path unless openBufferPathToAdd
        return unless openBufferPathToAdd
        openBufferPathToAdd = openBufferPathToAdd.toLowerCase()
        atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
        return if \
            not manually and \
            (@statesCache[atomProjectPathAsKeyProxy].bannedBufferPaths.find (bannedBufferPath) -> \
                bannedBufferPath.toLowerCase() is openBufferPathToAdd)
        if manually
            @statesCache['<~>'].openBufferPaths =
                @statesCache['<~>'].openBufferPaths.filter (openBufferPath) ->
                    openBufferPath.toLowerCase() isnt openBufferPathToAdd
        unless (@statesCache[atomProjectPathAsKeyProxy].openBufferPaths.find (openBufferPath) ->
            openBufferPath.toLowerCase() is openBufferPathToAdd)
                atom.workspace.once 'editor-created.project-ring editor-created-forced.project-ring', =>
                    setTimeout (
                        =>
                            @statesCache[atomProjectPathAsKeyProxy].bannedBufferPaths =
                                @statesCache[atomProjectPathAsKeyProxy].bannedBufferPaths.filter (bannedBufferPath) ->
                                    bannedBufferPath.toLowerCase() isnt openBufferPathToAdd
                            newOpenBufferPaths = @getOpenBufferPaths().filter (openBufferPathInAll) =>
                                openBufferPathInAll.toLowerCase() is openBufferPathToAdd or \
                                    @statesCache[atomProjectPathAsKeyProxy].openBufferPaths.find (openBufferPath) ->
                                        openBufferPath.toLowerCase() is openBufferPathInAll.toLowerCase()
                            @statesCache[atomProjectPathAsKeyProxy].openBufferPaths = newOpenBufferPaths
                            @saveProjectRing()
                            if manually
                                @projectRingNotification.notify \
                                    'File "' +
                                    require('path').basename(openBufferPathToAdd) +
                                    '" has been added to project "' +
                                    @statesCache[atomProjectPathAsKeyProxy].alias +
                                    '"'
                    ),
                    0
                unless deferedAddition
                    atom.workspace.emit 'editor-created-forced.project-ring'

    banOpenBufferPathFromProject: (openBufferPathToBan) ->
        return unless @checkIfInProject()
        openBufferPathToBan = atom.workspace.getActiveEditor()?.buffer.file?.path unless openBufferPathToBan
        return unless openBufferPathToBan
        openBufferPathToBanProxy = openBufferPathToBan.toLowerCase()
        atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
        unless (@statesCache[atomProjectPathAsKeyProxy].bannedBufferPaths.find (openBufferPath) ->
            openBufferPath.toLowerCase() is openBufferPathToBanProxy)
                @statesCache[atomProjectPathAsKeyProxy].openBufferPaths =
                    @statesCache[atomProjectPathAsKeyProxy].openBufferPaths.filter (openBufferPath) ->
                        openBufferPath.toLowerCase() isnt openBufferPathToBanProxy
                @statesCache[atomProjectPathAsKeyProxy].bannedBufferPaths.push openBufferPathToBan
                @saveProjectRing()
                @projectRingNotification.notify \
                    'File "' +
                    require('path').basename(openBufferPathToBan) +
                    '" has been banned from project "'+
                    @statesCache[atomProjectPathAsKeyProxy].alias +
                    '"'

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
        @projectRingNotification.notify \
            'File "' +
            require('path').basename(bufferPathToAlwaysOpen) +
            '" has been marked to always open'

    add: (options) ->
        options = options or {}
        @projectRingView.destroy() if @projectRingView
        return unless atom.project.path and not /^\s*$/.test atom.project.path
        treeViewState = atom.packages.getLoadedPackage('tree-view')?.serialize()
        atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
        if options.updateTreeViewStateOnly
            return unless @checkIfInProject()
            @statesCache[atomProjectPathAsKeyProxy].treeViewState = treeViewState
            @saveProjectRing()
            return
        if options.updateOpenBufferPathPositionsOnly
            return unless @checkIfInProject()
            currentProjectOpenBufferPaths = @statesCache[atomProjectPathAsKeyProxy].openBufferPaths\
                .map (openBufferPath) ->
                    openBufferPath.toLowerCase()
            @statesCache[atomProjectPathAsKeyProxy].openBufferPaths = @getOpenBufferPaths().filter (openBufferPath) ->
                openBufferPath.toLowerCase() in currentProjectOpenBufferPaths
            @saveProjectRing()
            return
        alias =
            options.alias or
            @statesCache[atomProjectPathAsKeyProxy]?.alias or
            require('path').basename atom.project.path
        alias = '...' + alias.substr alias.length - 97 if alias.length > 100
        unless @statesCache[atomProjectPathAsKeyProxy]
            aliases = (Object.keys(@statesCache).filter (projectPath) =>
                not @statesCache[projectPath].isIgnored).map (projectPath) => @statesCache[projectPath].alias
            if alias in aliases
                salt = 1
                aliasTemp = alias + salt.toString()
                while aliasTemp in aliases
                    aliasTemp = alias + (++salt).toString()
                alias = aliasTemp
        projectToLoadOnStartUp = atom.config.get('project-ring.projectToLoadOnStartUp') or ''
        if \
            @statesCache[atomProjectPathAsKeyProxy] and
            (@statesCache[atomProjectPathAsKeyProxy].alias is projectToLoadOnStartUp or
             atomProjectPathAsKeyProxy is projectToLoadOnStartUp.toLowerCase()) and
            alias isnt @statesCache[atomProjectPathAsKeyProxy].alias
                atom.config.set 'project-ring.projectToLoadOnStartUp', alias
        if options.renameOnly
            return unless @checkIfInProject()
            if @statesCache[atomProjectPathAsKeyProxy]
                oldAlias = @statesCache[atomProjectPathAsKeyProxy].alias
                @statesCache[atomProjectPathAsKeyProxy].alias = alias
                @saveProjectRing()
                @projectRingNotification.notify 'Project "' + oldAlias + '" is now known as "' + alias + '"'
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
        @statesCache[atomProjectPathAsKeyProxy] = currentProjectState
        @saveProjectRing()
        @projectRingNotification.notify 'Project "' + alias + '" has been created/updated'
        unless @checkIfInProject()
            @processProjectRingViewProjectSelection projectState: @statesCache[atomProjectPathAsKeyProxy]

    addAs: (renameOnly) ->
        @loadProjectRingInputView()
        unless @projectRingInputView.hasParent()
            alias = atom.project.path
            atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
            if @statesCache[atomProjectPathAsKeyProxy]
            then (
                if @statesCache[atomProjectPathAsKeyProxy].alias is @statesCache[atomProjectPathAsKeyProxy].projectPath
                then alias = (require 'path').basename @statesCache[atomProjectPathAsKeyProxy].projectPath
                else alias = @statesCache[atomProjectPathAsKeyProxy].alias
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
            atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
            buffersOfCurrentProject =
                @statesCache[atomProjectPathAsKeyProxy].openBufferPaths\
                    .map (openBufferPath) -> openBufferPath.toLowerCase()
            (Object.keys(@statesCache).filter (projectPath) =>
                not @statesCache[projectPath].isIgnored and
                projectPath isnt atomProjectPathAsKeyProxy).forEach (projectPath) =>
                    (@statesCache[projectPath].openBufferPaths.filter (openBufferPath) ->
                        openBufferPathProxy = openBufferPath.toLowerCase()
                        openBufferPathProxy not in buffersOfCurrentProject and
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
                buffer.file and
                bufferPathProxy not in buffersOfCurrentProject and
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
                buffer.file and
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
                buffer.file and
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
        atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
        alias = @statesCache[atomProjectPathAsKeyProxy]?.alias
        delete @statesCache[atomProjectPathAsKeyProxy]
        @saveProjectRing()
        @projectRingNotification.notify 'Project "' + alias + '" has been deleted' if alias

    unlink: (doNotShowNotification, doNotAffectAtom) ->
        @projectRingView.destroy() if @projectRingView
        return unless atom.project.path and not /^\s*$/.test atom.project.path
        unless doNotAffectAtom
            (atom.packages.getLoadedPackage 'tree-view')?.mainModule.treeView?.detach?()
            atom.project.setPath null
        @inProject = false
        @projectRingNotification.notify 'No project is currently loaded' unless doNotShowNotification

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
                    @unlink true
                    @currentlySettingProjectPath = true
                    atom.project.once 'path-changed', =>
                        @currentlySettingProjectPath = false
                        return unless atom.project.path and not /^\s*$/.test atom.project.path
                        unless atom.config.get 'project-ring.skipOpeningTreeViewWhenChangingProjectPath'
                            @runFilePatternHiding()
                            (atom.packages.getLoadedPackage 'tree-view')?.mainModule.treeView?.show?()
                        @projectRingNotification.notify 'The project path has been set to "' + atom.project.path + '"'
                    atom.project.setPath pathsToOpen[0]
                    @processProjectRingViewProjectSelection
                        projectState: @statesCache[@getAtomProjectPathAsKey pathsToOpen[0]]
                        isAsynchronousProjectPathChange: true
                    return
                atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
                newAtomProjectPathAsKeyProxy = @getAtomProjectPathAsKey pathsToOpen[0]
                if @statesCache[atomProjectPathAsKeyProxy]
                    @statesCache[newAtomProjectPathAsKeyProxy] = @statesCache[atomProjectPathAsKeyProxy]
                    @statesCache[newAtomProjectPathAsKeyProxy].projectPath = pathsToOpen[0]
                    if @statesCache[newAtomProjectPathAsKeyProxy].treeViewState
                        oldPathRE = new RegExp '^' + (@turnToPathRegExp atom.project.path), 'i'
                        if @statesCache[newAtomProjectPathAsKeyProxy].treeViewState.selectedPath and
                        not /^\s*$/.test @statesCache[newAtomProjectPathAsKeyProxy].treeViewState.selectedPath
                            @statesCache[newAtomProjectPathAsKeyProxy].treeViewState.selectedPath =
                                @statesCache[newAtomProjectPathAsKeyProxy].treeViewState.selectedPath.replace \
                                    oldPathRE, pathsToOpen[0]
                        if @statesCache[newAtomProjectPathAsKeyProxy].openBufferPaths.length
                            newOpenBufferPaths = @statesCache[newAtomProjectPathAsKeyProxy].openBufferPaths\
                                .map (openBufferPath) ->
                                    openBufferPath.replace oldPathRE, pathsToOpen[0]
                            @statesCache[newAtomProjectPathAsKeyProxy].openBufferPaths = newOpenBufferPaths
                    delete @statesCache[atomProjectPathAsKeyProxy]
                atom.project.setPath pathsToOpen[0]
                if not @statesCache[newAtomProjectPathAsKeyProxy]
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
        @projectRingNotification.notify 'All project ring data has been deleted'

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
        projectStateProjectPathAsKeyProxy = @getAtomProjectPathAsKey projectState.projectPath
        if \
            atom.project.path and
            @statesCache[projectStateProjectPathAsKeyProxy] and
            projectStateProjectPathAsKeyProxy is @getAtomProjectPathAsKey()
                @inProject = false
        delete @statesCache[projectStateProjectPathAsKeyProxy]
        @saveProjectRing()

    handleProjectRingViewSelection: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'project'
                @processProjectRingViewProjectSelection
                    projectState: data
                    openProjectBuffersOnly: viewModeParameters.openProjectBuffersOnly
            else break

    closeProjectBuffersOnBufferCreate: () ->
        bufferPathsToAlwaysOpen = @statesCache['<~>'].openBufferPaths.map (openBufferPath) ->
            openBufferPath.toLowerCase()
        projectRelatedBufferPaths = {}
        (Object.keys(@statesCache).filter (projectPath) -> projectPath isnt '<~>').forEach (projectPath) =>
            @statesCache[projectPath].openBufferPaths.forEach (openBufferPath) ->
                projectRelatedBufferPaths[openBufferPath.toLowerCase()] = null
        projectRelatedBufferPaths = Object.keys projectRelatedBufferPaths
        projectUnrelatedBufferPaths = []
        (atom.project.buffers.filter (buffer) -> buffer.file).forEach (buffer) =>
                bufferFilePathProxy = buffer.file.path.toLowerCase()
                unless bufferFilePathProxy in projectRelatedBufferPaths
                    projectUnrelatedBufferPaths.push bufferFilePathProxy
        (atom.project.buffers.filter (buffer) ->
            bufferPath = buffer.file?.path.toLowerCase()
            bufferPath and
            bufferPath not in bufferPathsToAlwaysOpen and
            bufferPath not in projectUnrelatedBufferPaths).forEach (buffer) ->
                    buffer.off 'destroyed.project-ring'
                    buffer.once 'saved', -> buffer.destroy()
                    buffer.save()

    processProjectRingViewProjectSelection: (options) ->
        options = options or {}
        return unless options.projectState
        projectStateProjectPathAsKeyProxy = @getAtomProjectPathAsKey options.projectState.projectPath
        _fs = require 'fs'
        unless _fs.existsSync options.projectState.projectPath
            delete @statesCache[projectStateProjectPathAsKeyProxy]
            @saveProjectRing()
            return
        unless @statesCache[projectStateProjectPathAsKeyProxy].openBufferPaths
            @statesCache[projectStateProjectPathAsKeyProxy].openBufferPaths = []
            options.projectState.openBufferPaths = []
        unless @statesCache[projectStateProjectPathAsKeyProxy].bannedBufferPaths
            @statesCache[projectStateProjectPathAsKeyProxy].bannedBufferPaths = []
            options.projectState.bannedBufferPaths = []
        atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
        oldProjectPath = atomProjectPathAsKeyProxy
        unless options.openProjectBuffersOnly
            unless \
                projectStateProjectPathAsKeyProxy is atomProjectPathAsKeyProxy and
                not options.isAsynchronousProjectPathChange
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
                        @projectRingNotification.notify 'Project "' + options.projectState.alias + '" has been loaded'
                    atom.project.setPath options.projectState.projectPath
                    atomProjectPathAsKeyProxy = projectStateProjectPathAsKeyProxy
            else
                @inProject = true
                @projectRingNotification.notify 'Project "' + options.projectState.alias + '" has been loaded'
            if atom.config.get 'project-ring.makeTheCurrentProjectTheDefaultOnStartUp'
                atom.config.set 'project-ring.projectToLoadOnStartUp', options.projectState.alias
        validOpenBufferPaths = options.projectState.openBufferPaths.filter (openBufferPath) ->
            _fs.existsSync(openBufferPath)
        if \
            not options.openProjectBuffersOnly and
            oldProjectPath and
            (oldProjectPath isnt atomProjectPathAsKeyProxy or options.isAsynchronousProjectPathChange) and
            atom.project.buffers.length and
            atom.config.get 'project-ring.closePreviousProjectFiles'
                @closeProjectBuffersOnBufferCreate()
        removeEmtpyBuffers = (bufferCreated) =>
            return unless not bufferCreated or bufferCreated.file
            atom.project.off 'buffer-created.project-ring-remove-empty'
            setTimeout (
                    ->
                        (atom.project.buffers.filter (buffer) ->
                            not buffer.file and buffer.cachedText is '').forEach (buffer) ->
                                return if \
                                    bufferCreated is buffer or
                                    (atom.project.buffers.length is 1 and
                                     not atom.project.buffers[0].file and
                                     atom.project.buffers[0].cachedText is '' and
                                     atom.config.get 'core.destroyEmptyPanes')
                                buffer.off 'destroyed.project-ring'
                                buffer.destroy()
                ),
                @projectRingInvariantState.emptyBufferDestroyDelayOnStartup
        if \
            (options.openProjectBuffersOnly or
             not atom.config.get 'project-ring.doNotSaveAndRestoreOpenProjectFiles') and
            validOpenBufferPaths.length
                atom.project.on 'buffer-created.project-ring-remove-empty', removeEmtpyBuffers
                unless \
                    options.openProjectBuffersOnly or
                    options.projectState.openBufferPaths.length is validOpenBufferPaths.length
                        @statesCache[options.projectState.projectPath].openBufferPaths = validOpenBufferPaths
                        @saveProjectRing()
                atom.open pathsToOpen: validOpenBufferPaths, newWindow: false
        else if atom.config.get 'project-ring.closePreviousProjectFiles'
            removeEmtpyBuffers()

    handleProjectRingInputViewInput: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'project' then @processProjectRingInputViewProjectAlias data, viewModeParameters.renameOnly
            else break

    processProjectRingInputViewProjectAlias: (alias, renameOnly) ->
        return unless alias and not /^\s*$/.test alias
        @add alias: alias, renameOnly: renameOnly

    handleProjectRingBufferSelectViewSelection: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'add' then @processProjectRingBufferSelectViewSelection data, true
            when 'ban' then @processProjectRingBufferSelectViewSelection data, false, true
            when 'always-open' then @processProjectRingBufferSelectViewSelection data, false, false, true
            else break

    processProjectRingBufferSelectViewSelection: (paths, add, ban, alwaysOpen) ->
        return unless paths and paths.length and (if add or ban then @checkIfInProject() else true)
        if add
            paths.forEach (path) => @addOpenBufferPathToProject path, true
        else if ban
            paths.forEach (path) => @banOpenBufferPathFromProject path
        else if alwaysOpen
            paths.forEach (path) => @alwaysOpenBufferPath path

    copy: (copyKey) ->
        atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
        return unless \
            @checkIfInProject() and
            not /^\s*$/.test(atom.project.path) and
            @statesCache[atomProjectPathAsKeyProxy]?[copyKey]
        try
            require('clipboard').writeText @statesCache[atomProjectPathAsKeyProxy][copyKey]
            @projectRingNotification.notify \
                'The requested project attribute has been copied to the system\'s clipboard'
        catch error
            @projectRingNotification.alert error
            return

    editKeyBindings: ->
        _path = require 'path'
        keyBindingsFilePath = _path.join \
            atom.packages.getLoadedPackage('project-ring').path, 'keymaps', 'project-ring.cson'
        _fs = require 'fs'
        unless _fs.existsSync keyBindingsFilePath
            @projectRingNotification.alert 'Could not find the default Project Ring key bindings file.'
            return
        atom.open pathsToOpen: [ keyBindingsFilePath ], newWindow: false
