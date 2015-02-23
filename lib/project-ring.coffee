##############################
# Private Variables -- Start            #
##############################

defaultProjectCacheKey = '<~>'

##############################
# Private Variables -- END            #
##############################

##############################
# Private Helper Functions -- Start #
##############################

getProjectRootPath = () ->
    return null unless atom.project.rootDirectories instanceof Array and atom.project.rootDirectories[0]
    atom.project.rootDirectories[0].path or null

findInArray = (array, callback) ->
    return undefined unless array and array.length and typeof callback is 'function'
    for element in array
        return element if callback element
    undefined

##############################
# Private Helper Functions -- END #
##############################

module.exports =
    configDefaults:
        closePreviousProjectFiles: true
        filePatternToHide: ''
        filePatternToExcludeFromHiding: ''
        keepAllOpenFilesRegardlessOfProject: false
        keepOutOfPathOpenFilesInCurrentProject: false
        makeTheCurrentProjectTheDefaultOnStartUp: true
        projectToLoadOnStartUp: ''
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
        atom.config.observe 'project-ring.makeTheCurrentProjectTheDefaultOnStartUp', (makeTheCurrentProjectTheDefaultOnStartUp) =>
            currentProjectState = @getProjectState()
            return unless @inProject and makeTheCurrentProjectTheDefaultOnStartUp and currentProjectState
            atom.config.set 'project-ring.projectToLoadOnStartUp', currentProjectState.alias
        projectToLoadOnStartUp = getProjectRootPath() ? atom.config.get 'project-ring.projectToLoadOnStartUp'
        atom.project.once 'project-ring-states-cache-initialized', =>
            _fs = require 'fs'
            defaultProjectState = @getProjectState defaultProjectCacheKey
            validDefaultBufferPathsToOpen = defaultProjectState.openBufferPaths.filter (openBufferPath) -> _fs.existsSync openBufferPath
            if validDefaultBufferPathsToOpen.length
                currentlyOpenBufferPaths = @getOpenBufferPaths().map (openBufferPath) -> openBufferPath.toLowerCase()
                bufferPathsToOpen = validDefaultBufferPathsToOpen.filter (validDefaultBufferPathToOpen) ->
                    validDefaultBufferPathToOpen not in currentlyOpenBufferPaths
                atom.workspace.openSync bufferPath for bufferPath in bufferPathsToOpen
                unless defaultProjectState.openBufferPaths.length is validDefaultBufferPathsToOpen.length
                    defaultProjectState.openBufferPaths = validDefaultBufferPathsToOpen
                    @saveProjectRing()
        treeView = atom.packages.getLoadedPackage 'tree-view'
        if treeView
            unless treeView?.mainModule.treeView?.updateRoots
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
            atom.config.observe 'project-ring.useFilePatternHiding', (useFilePatternHiding) => @runFilePatternHiding useFilePatternHiding
            atom.config.observe 'project-ring.filePatternToHide', (filePatternToHide) => @runFilePatternHiding()
            atom.config.observe 'project-ring.filePatternToExcludeFromHiding', (filePatternToExcludeFromHiding) => @runFilePatternHiding()
        else
            @setProjectRing 'default', projectToLoadOnStartUp
        atom.commands.add 'atom-workspace', 'tree-view:toggle', => @runFilePatternHiding()
        atom.commands.add 'atom-workspace', "project-ring:add", => @add()
        atom.commands.add 'atom-workspace', "project-ring:add-as", => @addAs()
        atom.commands.add 'atom-workspace', "project-ring:rename", => @addAs true
        atom.commands.add 'atom-workspace', "project-ring:toggle", => @toggle()
        atom.commands.add 'atom-workspace', "project-ring:open-project-files", => @toggle true
        atom.commands.add 'atom-workspace', "project-ring:add-current-file-to-current-project", => @addOpenBufferPathToProject null, true
        atom.commands.add 'atom-workspace', "project-ring:add-files-to-current-project", => @addFilesToProject()
        atom.commands.add 'atom-workspace', "project-ring:ban-current-file-from-current-project", => @banOpenBufferPathFromProject()
        atom.commands.add 'atom-workspace', "project-ring:ban-files-from-current-project", => @banFilesFromProject()
        atom.commands.add 'atom-workspace', "project-ring:always-open-current-file", => @alwaysOpenBufferPath()
        atom.commands.add 'atom-workspace', "project-ring:always-open-files", => @alwaysOpenFiles()
        atom.commands.add 'atom-workspace', "project-ring:delete", => @delete()
        atom.commands.add 'atom-workspace', "project-ring:unlink", => @unlink()
        atom.commands.add 'atom-workspace', "project-ring:set-project-path", => @setProjectPath()
        atom.commands.add 'atom-workspace', "project-ring:delete-project-ring", => @deleteProjectRing()
        atom.commands.add 'atom-workspace', "project-ring:copy-project-alias", => @copy 'alias'
        atom.commands.add 'atom-workspace', "project-ring:copy-project-path", => @copy 'projectPath'
        atom.commands.add 'atom-workspace', "project-ring:move-project-path", => @setProjectPath true
        atom.commands.add 'atom-workspace', "project-ring:edit-key-bindings", => @editKeyBindings()

    setupProjectRingNotification: ->
        @projectRingNotification = new (require './project-ring-notification')
        atom.config.observe 'project-ring.useNotifications', (useNotifications) => @projectRingNotification.isEnabled = useNotifications

    setupAutomaticProjectBuffersSaving: ->
        atom.config.observe 'project-ring.doNotSaveAndRestoreOpenProjectFiles', (doNotSaveAndRestoreOpenProjectFiles) =>
            if doNotSaveAndRestoreOpenProjectFiles
                atom.project.off 'buffer-created.project-ring'
                atom.project.buffers.forEach (buffer) -> buffer.off 'destroyed.project-ring'
                return unless @inProject
                @getProjectState().openBufferPaths = []
                @saveProjectRing()
            else
                onBufferDestroyedProjectRingEventHandlerFactory = (bufferDestroyed) =>
                    =>
                        return unless bufferDestroyed.file
                        setTimeout (
                                =>
                                    bufferDestroyedPathProxy = bufferDestroyed.file.path.toLowerCase()
                                    defaultProjectState = @getProjectState defaultProjectCacheKey
                                    if (defaultProjectState.openBufferPaths.some (openBufferPath) ->
                                        openBufferPath.toLowerCase() is bufferDestroyedPathProxy)
                                            defaultProjectState.openBufferPaths =
                                                defaultProjectState.openBufferPaths.filter (openBufferPath) ->
                                                    openBufferPath.toLowerCase() isnt bufferDestroyedPathProxy
                                            @saveProjectRing()
                                            return
                                    return unless @inProject
                                    currentProjectState = @getProjectState()
                                    if (currentProjectState.openBufferPaths.some (openBufferPath) ->
                                            openBufferPath.toLowerCase() is bufferDestroyedPathProxy)
                                        currentProjectState.openBufferPaths =
                                            currentProjectState.openBufferPaths.filter (openBufferPath) =>
                                                openBufferPath.toLowerCase() isnt bufferDestroyedPathProxy
                                        @saveProjectRing()
                            ),
                            @projectRingInvariantState.deletionDelay
                atom.project.buffers.forEach (buffer) =>
                    buffer.off 'destroyed.project-ring'
                    buffer.on 'destroyed.project-ring', onBufferDestroyedProjectRingEventHandlerFactory buffer
                atom.project.on 'buffer-created.project-ring', (openProjectBuffer) =>
                    return unless openProjectBuffer.file
                    openProjectBuffer.off 'destroyed.project-ring'
                    openProjectBuffer.on 'destroyed.project-ring', onBufferDestroyedProjectRingEventHandlerFactory openProjectBuffer
                    if atom.config.get 'project-ring.keepAllOpenFilesRegardlessOfProject'
                        @alwaysOpenBufferPath openProjectBuffer.file.path
                        return
                    return unless \
                        getProjectRootPath() and
                        (new RegExp(
                            '^' + @turnToPathRegExp(getProjectRootPath()), 'i'
                        ).test(openProjectBuffer.file.path) or
                        atom.config.get 'project-ring.keepOutOfPathOpenFilesInCurrentProject')
                    @addOpenBufferPathToProject openProjectBuffer.file.path
        setTimeout (
                =>
                    { $ } = require 'atom-space-pen-views'
                    $('.tab-bar').on 'drop', => setTimeout (=> @add updateOpenBufferPathPositionsOnly: true), 0
            ),
            0

    setupAutomaticProjectLoadingOnProjectPathChange: ->
        atom.project.on 'path-changed', =>
            return unless @statesCache and getProjectRootPath() and not @currentlySettingProjectPath
            @unlink true, true
            @processProjectRingViewProjectSelection projectState: @getProjectState(), isAsynchronousProjectPathChange: true

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
                    { $ } = require 'atom-space-pen-views'
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
                            if \
                                ((filePattern.test filePath) and
                                not (reverseFilePattern and reverseFilePattern.test filePath)) or
                                ((filePattern.test fileName) and
                                not (reverseFilePattern and reverseFilePattern.test fileName))
                                    $$.removeAttr('data-project-ring-filtered').attr('data-project-ring-filtered', 'true').css 'display', 'none'
                            else
                                $$.removeAttr('data-project-ring-filtered').css 'display', ''
                    else
                        (entries.filter -> $(@).attr('data-project-ring-filtered') is 'true').each ->
                            $(@).removeAttr('data-project-ring-filtered').css 'display', ''
            ),
            0

    getConfigurationPath: ->
        _path = require 'path'
        path = _path.join process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME'], '.atom-project-ring'
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
        (path or getProjectRootPath())?.toLowerCase()

    setProjectState: (cacheKey, projectState) ->
        return unless typeof cacheKey is 'string' and typeof projectState is 'object'
        @statesCache = {} unless typeof @statesCache is 'object'
        @statesCache[@getAtomProjectPathAsKey cacheKey] = projectState

    getProjectState: (cacheKey) ->
        return undefined unless @statesCache
        return @statesCache[@getAtomProjectPathAsKey cacheKey]

    unsetProjectState: (cacheKey) ->
        return unless (typeof cacheKey is 'string' or cacheKey is null) and typeof @statesCache is 'object'
        delete @statesCache[@getAtomProjectPathAsKey cacheKey]

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
                    (currentStat, previousStat) => @setProjectRing @projectRingId # , getProjectRootPath()
            if csonFilePath
                _fs.watchFile \
                    csonFilePath,
                    { persistent: true, interval: @projectRingInvariantState.configurationFileWatchInterval },
                    (currentStat, previousStat) =>
                        if @currentlySavingConfiguration.csonFile
                            @currentlySavingConfiguration.csonFile = false
                            return
                        @setProjectRing @projectRingId # , getProjectRootPath()
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
            @setProjectState defaultProjectCacheKey, { openBufferPaths: [], isIgnored: true }
            return
        _cson = require 'season'
        try
            @statesCache = _cson.readFileSync csonFilePath
            if \
                projectSpecificationToLoad and
                not /^\s*$/.test(projectSpecificationToLoad) and
                @statesCache
                    projectSpecificationToLoad = projectSpecificationToLoad.toLowerCase()
                    for stateKey in Object.keys @statesCache
                        projectState = @getProjectState stateKey
                        unless \
                            not projectState.isIgnored and
                            (projectState.alias.toLowerCase() is projectSpecificationToLoad or
                             projectState.projectPath.toLowerCase() is projectSpecificationToLoad)
                                continue
                        stateKeyToUseForProjectLoading = stateKey
                        setTimeout (
                                =>
                                    @processProjectRingViewProjectSelection projectState: @getProjectState stateKeyToUseForProjectLoading
                                    @runFilePatternHiding()
                            ),
                            0
                        break
        catch error
            @projectRingNotification.alert \
                'Could not load the project ring data for id: "' + @projectRingId + '" (' + error + ')'
            return
        @setProjectState defaultProjectCacheKey, { openBufferPaths: [], isIgnored: true } unless @getProjectState defaultProjectCacheKey
        # ENSURE THAT ALL @statesCache KEYS ARE LOWERCASE
        fixedStatesCacheKeys = false
        for stateKey in Object.keys @statesCache
            stateKeyProxy = @getAtomProjectPathAsKey stateKey
            unless stateKey is stateKeyProxy
                @setProjectState stateKeyProxy, @getProjectState stateKey
                @unsetProjectState stateKey
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
            @projectRingView = new ProjectRingView @

    loadProjectRingInputView: ->
        unless @projectRingInputView
            @projectRingInputView = new (require './project-ring-input-view') @

    loadProjectRingBufferSelectView: ->
        unless @projectRingBufferSelectView
            @projectRingBufferSelectView = new (require './project-ring-buffer-select-view') @

    getOpenBufferPaths: ->
        unless atom.config.get 'project-ring.doNotSaveAndRestoreOpenProjectFiles'
            return (atom.workspace.getEditors().filter (editor) -> editor.buffer.file).map (editor) -> editor.buffer.file.path
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
        defaultProjectState = @getProjectState defaultProjectCacheKey
        currentProjectState = @getProjectState()
        return if \
            not manually and
            (currentProjectState.bannedBufferPaths.some (bannedBufferPath) ->
                bannedBufferPath.toLowerCase() is openBufferPathToAdd)
        if manually
            defaultProjectState.openBufferPaths =
                defaultProjectState.openBufferPaths.filter (openBufferPath) -> openBufferPath.toLowerCase() isnt openBufferPathToAdd
        unless (currentProjectState.openBufferPaths.some (openBufferPath) -> openBufferPath.toLowerCase() is openBufferPathToAdd)
            atom.workspace.once 'editor-created.project-ring editor-created-forced.project-ring', =>
                setTimeout (
                    =>
                        currentProjectState.bannedBufferPaths =
                            currentProjectState.bannedBufferPaths.filter (bannedBufferPath) ->
                                bannedBufferPath.toLowerCase() isnt openBufferPathToAdd
                        newOpenBufferPaths = @getOpenBufferPaths().filter (openBufferPathInAll) =>
                            openBufferPathInAll.toLowerCase() is openBufferPathToAdd or
                            currentProjectState.openBufferPaths.some (openBufferPath) ->
                                openBufferPath.toLowerCase() is openBufferPathInAll.toLowerCase()
                        currentProjectState.openBufferPaths = newOpenBufferPaths
                        @saveProjectRing()
                        if manually
                            @projectRingNotification.notify \
                                'File "' +
                                require('path').basename(openBufferPathToAdd) +
                                '" has been added to project "' +
                                currentProjectState.alias +
                                '"'
                ),
                0
            atom.workspace.emit 'editor-created-forced.project-ring' unless deferedAddition

    banOpenBufferPathFromProject: (openBufferPathToBan) ->
        return unless @checkIfInProject()
        openBufferPathToBan = atom.workspace.getActiveEditor()?.buffer.file?.path unless openBufferPathToBan
        return unless openBufferPathToBan
        openBufferPathToBanProxy = openBufferPathToBan.toLowerCase()
        currentProjectState = @getProjectState()
        unless (currentProjectState.bannedBufferPaths.some (openBufferPath) ->
            openBufferPath.toLowerCase() is openBufferPathToBanProxy)
                currentProjectState.openBufferPaths =
                    currentProjectState.openBufferPaths.filter (openBufferPath) ->
                        openBufferPath.toLowerCase() isnt openBufferPathToBanProxy
                currentProjectState.bannedBufferPaths.push openBufferPathToBan
                @saveProjectRing()
                @projectRingNotification.notify \
                    'File "' +
                    require('path').basename(openBufferPathToBan) +
                    '" has been banned from project "'+
                    currentProjectState.alias +
                    '"'

    alwaysOpenBufferPath: (bufferPathToAlwaysOpen) ->
        bufferPathToAlwaysOpen = atom.workspace.getActiveEditor()?.buffer.file?.path unless bufferPathToAlwaysOpen
        bufferPathToAlwaysOpenProxy = bufferPathToAlwaysOpen?.toLowerCase()
        defaultProjectState = @getProjectState defaultProjectCacheKey
        return unless \
            bufferPathToAlwaysOpen and
            not (defaultProjectState.openBufferPaths.some (openBufferPath) ->
                openBufferPath.toLowerCase() is bufferPathToAlwaysOpenProxy)
        for stateKey in Object.keys @statesCache
            projectState = @getProjectState stateKey
            continue if projectState.isIgnored
            projectState.openBufferPaths = projectState.openBufferPaths.filter (openBufferPath) ->
                openBufferPath.toLowerCase() isnt bufferPathToAlwaysOpenProxy
        defaultProjectState.openBufferPaths.push bufferPathToAlwaysOpen
        @saveProjectRing()
        @projectRingNotification.notify \
            'File "' +
            require('path').basename(bufferPathToAlwaysOpen) +
            '" has been marked to always open'

    add: (options) ->
        options = options or {}
        @projectRingView.destroy() if @projectRingView
        return unless getProjectRootPath() and not /^\s*$/.test getProjectRootPath()
        treeViewState = atom.packages.getLoadedPackage('tree-view')?.serialize()
        currentProjectState = @getProjectState()
        if options.updateTreeViewStateOnly
            return unless @checkIfInProject()
            currentProjectState.treeViewState = treeViewState
            @saveProjectRing()
            return
        if options.updateOpenBufferPathPositionsOnly
            return unless @checkIfInProject()
            currentProjectOpenBufferPaths = currentProjectState.openBufferPaths.map (openBufferPath) -> openBufferPath.toLowerCase()
            currentProjectState.openBufferPaths = @getOpenBufferPaths().filter (openBufferPath) ->
                openBufferPath.toLowerCase() in currentProjectOpenBufferPaths
            @saveProjectRing()
            return
        alias = options.alias or currentProjectState?.alias or require('path').basename getProjectRootPath()
        alias = '...' + alias.substr alias.length - 97 if alias.length > 100
        unless currentProjectState
            aliases = (Object.keys(@statesCache).filter (projectPath) =>
                not @getProjectState(projectPath).isIgnored).map (projectPath) => @getProjectState(projectPath).alias
            if alias in aliases
                salt = 1
                aliasTemp = alias + salt.toString()
                while aliasTemp in aliases
                    aliasTemp = alias + (++salt).toString()
                alias = aliasTemp
        projectToLoadOnStartUp = atom.config.get('project-ring.projectToLoadOnStartUp') or ''
        atomProjectPathAsKey = @getAtomProjectPathAsKey()
        if \
            currentProjectState and
            (currentProjectState.alias is projectToLoadOnStartUp or
             atomProjectPathAsKey is projectToLoadOnStartUp.toLowerCase()) and
            alias isnt currentProjectState.alias
                atom.config.set 'project-ring.projectToLoadOnStartUp', alias
        if options.renameOnly
            return unless @checkIfInProject()
            if currentProjectState
                oldAlias = currentProjectState.alias
                currentProjectState.alias = alias
                @saveProjectRing()
                @projectRingNotification.notify 'Project "' + oldAlias + '" is now known as "' + alias + '"'
            return
        bufferPathsToAlwaysOpen =
            @getProjectState(defaultProjectCacheKey).openBufferPaths.map (openBufferPath) -> openBufferPath.toLowerCase()
        currentProjectState =
            alias: alias
            projectPath: getProjectRootPath()
            treeViewState: treeViewState
            openBufferPaths: @getOpenBufferPaths().filter (openBufferPath) -> openBufferPath.toLowerCase() not in bufferPathsToAlwaysOpen
            bannedBufferPaths: []
        @setProjectState atomProjectPathAsKey, currentProjectState
        @saveProjectRing()
        @projectRingNotification.notify 'Project "' + alias + '" has been created/updated'
        @processProjectRingViewProjectSelection projectState: @getProjectState() unless @checkIfInProject()

    addAs: (renameOnly) ->
        @loadProjectRingInputView()
        unless @projectRingInputView.isVisible()
            alias = getProjectRootPath()
            atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
            currentProjectState = @getProjectState()
            if currentProjectState
            then (
                if currentProjectState.alias is currentProjectState.projectPath
                then alias = (require 'path').basename currentProjectState.projectPath
                else alias = currentProjectState.alias
            )
            else alias = (require 'path').basename (if alias then alias else '')
            @projectRingInputView.attach { viewMode: 'project', renameOnly: renameOnly }, 'Project alias', alias

    toggle: (openProjectBuffersOnly) ->
        deleteKeyBinding = findInArray atom.keymap.getKeyBindings(), (keyBinding) -> keyBinding.command is 'project-ring:add'
        if deleteKeyBinding
        then deleteKeyBinding =
            ' (delete selected: ' + deleteKeyBinding.keystrokes.split(/\s+/)[0].replace(/-[^-]+$/, '-') + 'delete)'
        else deleteKeyBinding = ''
        if @projectRingView and @projectRingView.isVisible()
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
        unless @projectRingBufferSelectView.isVisible()
            bufferPathsToOfferForAddition = []
            buffersOfCurrentProject = @getProjectState().openBufferPaths.map (openBufferPath) -> openBufferPath.toLowerCase()
            (Object.keys(@statesCache).filter (projectPath) =>
                not @getProjectState(projectPath).isIgnored and
                projectPath isnt @getAtomProjectPathAsKey()).forEach (projectPath) =>
                    projectState = @getProjectState projectPath
                    (projectState.openBufferPaths.filter (openBufferPath) ->
                        openBufferPathProxy = openBufferPath.toLowerCase()
                        openBufferPathProxy not in buffersOfCurrentProject and
                        not (bufferPathsToOfferForAddition.some (bufferPathSpec) ->
                            bufferPathSpec.path.toLowerCase() is openBufferPathProxy)).forEach (openBufferPath) =>
                                description = openBufferPath
                                if description.length > 40
                                    description = '...' + description.substr description.length - 37
                                bufferPathsToOfferForAddition.push title: projectState.alias, description: description, path: openBufferPath
            (atom.project.buffers.filter (buffer) ->
                bufferPathProxy = buffer.file?.path.toLowerCase()
                buffer.file and
                bufferPathProxy not in buffersOfCurrentProject and
                not (bufferPathsToOfferForAddition.some (bufferPathSpec) ->
                    bufferPathSpec.path.toLowerCase() is bufferPathProxy)).forEach (buffer) ->
                        description = buffer.file.path
                        description = '...' + description.substr description.length - 37 if description.length > 40
                        bufferPathsToOfferForAddition.push title: 'Not In Project', description: description, path: buffer.file.path
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
        unless @projectRingBufferSelectView.isVisible()
            bufferPathsToOfferForBanning = []
            (atom.project.buffers.filter (buffer) ->
                buffer.file and
                not (bufferPathsToOfferForBanning.some (bufferPathSpec) ->
                    bufferPathSpec.path.toLowerCase() is buffer.file.path.toLowerCase())).forEach (buffer) ->
                        description = buffer.file.path
                        description = '...' + description.substr description.length - 37 if description.length > 40
                        bufferPathsToOfferForBanning.push title: require('path').basename buffer.file.path, description: description, path: buffer.file.path
            bufferPathsToOfferForBanning.sort()
            @projectRingBufferSelectView.attach { viewMode: 'ban', confirmValue: 'Ban' }, bufferPathsToOfferForBanning

    alwaysOpenFiles: ->
        return unless @checkIfInProject()
        @loadProjectRingBufferSelectView()
        unless @projectRingBufferSelectView.isVisible()
            bufferPathsToOfferForAlwaysOpening = []
            (atom.project.buffers.filter (buffer) ->
                buffer.file and
                not (bufferPathsToOfferForAlwaysOpening.some (bufferPathSpec) ->
                    bufferPathSpec.path.toLowerCase() is buffer.file.path.toLowerCase())).forEach (buffer) ->
                        description = buffer.file.path
                        description = '...' + description.substr description.length - 37 if description.length > 40
                        bufferPathsToOfferForAlwaysOpening.push
                            title: require('path').basename buffer.file.path
                            description: description
                            path: buffer.file.path
            bufferPathsToOfferForAlwaysOpening.sort()
            @projectRingBufferSelectView.attach { viewMode: 'always-open', confirmValue: 'Always Open' }, bufferPathsToOfferForAlwaysOpening

    delete: ->
        @projectRingView.destroy() if @projectRingView
        return unless getProjectRootPath() and not /^\s*$/.test getProjectRootPath()
        @inProject = false if @inProject
        atomProjectPathAsKeyProxy = @getAtomProjectPathAsKey()
        alias = @getProjectState()?.alias
        @unsetProjectState()
        @saveProjectRing()
        @projectRingNotification.notify 'Project "' + alias + '" has been deleted' if alias

    unlink: (doNotShowNotification, doNotAffectAtom) ->
        @projectRingView.destroy() if @projectRingView
        return unless getProjectRootPath() and not /^\s*$/.test getProjectRootPath()
        unless doNotAffectAtom
            (atom.packages.getLoadedPackage 'tree-view')?.mainModule.treeView?.detach?()
            atom.project.setPaths []
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
                        return unless getProjectRootPath() and not /^\s*$/.test getProjectRootPath()
                        unless atom.config.get 'project-ring.skipOpeningTreeViewWhenChangingProjectPath'
                            @runFilePatternHiding()
                            (atom.packages.getLoadedPackage 'tree-view')?.mainModule.treeView?.show?()
                        @projectRingNotification.notify 'The project path has been set to "' + getProjectRootPath() + '"'
                    atom.project.setPaths [ pathsToOpen[0] ]
                    @processProjectRingViewProjectSelection
                        projectState: @getProjectState @getAtomProjectPathAsKey pathsToOpen[0]
                        isAsynchronousProjectPathChange: true
                    return
                currentProjectState = @getProjectState()
                if currentProjectState
                    newProjectState = @setProjectState pathsToOpen[0], currentProjectState
                    newProjectState.projectPath = pathsToOpen[0]
                    if newProjectState.treeViewState
                        oldPathRE = new RegExp '^' + (@turnToPathRegExp getProjectRootPath()), 'i'
                        if newProjectState.treeViewState.selectedPath and
                        not /^\s*$/.test newProjectState.treeViewState.selectedPath
                            newProjectState.treeViewState.selectedPath =
                                newProjectState.treeViewState.selectedPath.replace oldPathRE, pathsToOpen[0]
                        if newProjectState.openBufferPaths.length
                            newOpenBufferPaths = newProjectState.openBufferPaths.map (openBufferPath) ->
                                openBufferPath.replace oldPathRE, pathsToOpen[0]
                            newProjectState.openBufferPaths = newOpenBufferPaths
                    @unsetProjectState()
                atom.project.setPaths [ pathsToOpen[0] ]
                if not newProjectState
                    @add()
                else
                    @saveProjectRing()
                @processProjectRingViewProjectSelection projectState: @getProjectState pathsToOpen[0]

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
        return unless projectState and @statesCache
        projectStateProjectPathAsKeyProxy = @getAtomProjectPathAsKey projectState.projectPath
        projectState = @getProjectState projectStateProjectPathAsKeyProxy
        return unless projectState
        @projectRingView.destroy() if @projectRingView
        if \
            getProjectRootPath() and
            projectState and
            projectStateProjectPathAsKeyProxy is @getAtomProjectPathAsKey()
                @inProject = false
        @unsetProjectState projectStateProjectPathAsKeyProxy
        @saveProjectRing()
        @projectRingNotification.notify 'Project "' + projectState.alias + '" has been deleted' if projectState.alias

    handleProjectRingViewSelection: (viewModeParameters, data) ->
        switch viewModeParameters.viewMode
            when 'project'
                @processProjectRingViewProjectSelection projectState: data, openProjectBuffersOnly: viewModeParameters.openProjectBuffersOnly
            else break

    closeProjectBuffersOnBufferCreate: () ->
        bufferPathsToAlwaysOpen =
            @getProjectState(defaultProjectCacheKey).openBufferPaths.map (openBufferPath) -> openBufferPath.toLowerCase()
        projectRelatedBufferPaths = {}
        (Object.keys(@statesCache).filter (projectPath) -> projectPath isnt defaultProjectCacheKey).forEach (projectPath) =>
            @getProjectState(projectPath).openBufferPaths.forEach (openBufferPath) ->
                projectRelatedBufferPaths[openBufferPath.toLowerCase()] = null
        projectRelatedBufferPaths = Object.keys projectRelatedBufferPaths
        projectUnrelatedBufferPaths = []
        (atom.project.buffers.filter (buffer) -> buffer.file).forEach (buffer) =>
                bufferFilePathProxy = buffer.file.path.toLowerCase()
                projectUnrelatedBufferPaths.push bufferFilePathProxy unless bufferFilePathProxy in projectRelatedBufferPaths
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
            @unsetProjectState projectStateProjectPathAsKeyProxy
            @saveProjectRing()
            return
        projectState = @getProjectState projectStateProjectPathAsKeyProxy
        unless projectState.openBufferPaths
            projectState.openBufferPaths = []
            options.projectState.openBufferPaths = []
        unless projectState.bannedBufferPaths
            projectState.bannedBufferPaths = []
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
                        return unless getProjectRootPath() and not /^\s*$/.test getProjectRootPath()
                        unless atom.config.get 'project-ring.skipOpeningTreeViewWhenChangingProjectPath'
                            treeView?.mainModule.treeView?.show?()
                            setTimeout (
                                =>
                                    treeView?.mainModule.treeView?.updateRoots? \
                                        options.projectState.treeViewState.directoryExpansionStates[0] or null
                                    @runFilePatternHiding()
                            ),
                            0
                        @inProject = true
                        @projectRingNotification.notify 'Project "' + options.projectState.alias + '" has been loaded'
                    atom.project.setPaths [ options.projectState.projectPath ]
                    atomProjectPathAsKeyProxy = projectStateProjectPathAsKeyProxy
            else
                @inProject = true
                @projectRingNotification.notify 'Project "' + options.projectState.alias + '" has been loaded'
            if atom.config.get 'project-ring.makeTheCurrentProjectTheDefaultOnStartUp'
                atom.config.set 'project-ring.projectToLoadOnStartUp', options.projectState.alias
        validOpenBufferPaths = options.projectState.openBufferPaths.filter (openBufferPath) -> _fs.existsSync(openBufferPath)
        if \
            not options.openProjectBuffersOnly and
            oldProjectPath and
            (oldProjectPath isnt atomProjectPathAsKeyProxy or options.isAsynchronousProjectPathChange) and
            atom.project.buffers.length and
            atom.config.get 'project-ring.closePreviousProjectFiles'
                @closeProjectBuffersOnBufferCreate()
        removeEmptyBuffers = (bufferCreated) =>
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
                atom.project.on 'buffer-created.project-ring-remove-empty', removeEmptyBuffers
                unless \
                    options.openProjectBuffersOnly or
                    options.projectState.openBufferPaths.length is validOpenBufferPaths.length
                        @getProjectState(options.projectState.projectPath).openBufferPaths = validOpenBufferPaths
                        @saveProjectRing()
                atom.workspace.openSync bufferPath for bufferPath in validOpenBufferPaths
        else if atom.config.get 'project-ring.closePreviousProjectFiles'
            removeEmptyBuffers()

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
        currentyProjectState = @getProjectState()
        return unless \
            @checkIfInProject() and
            not /^\s*$/.test(getProjectRootPath()) and
            currentyProjectState?[copyKey]
        try
            require('clipboard').writeText currentyProjectState[copyKey]
            @projectRingNotification.notify 'The requested project attribute has been copied to the system\'s clipboard'
        catch error
            @projectRingNotification.alert error
            return

    editKeyBindings: ->
        _path = require 'path'
        keyBindingsFilePath = _path.join atom.packages.getLoadedPackage('project-ring').path, 'keymaps', 'project-ring.cson'
        _fs = require 'fs'
        unless _fs.existsSync keyBindingsFilePath
            @projectRingNotification.alert 'Could not find the default Project Ring key bindings file.'
            return
        atom.workspace.openSync keyBindingsFilePath
