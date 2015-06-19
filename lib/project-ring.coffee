lib = require './project-ring-lib'
window.ll = lib # TODO: remove
module.exports =
	config:
		closePreviousProjectFiles: { type: 'boolean', default: true, description: 'Close the files of other projects when switching to a project' }
		filePatternToHide: { type: 'string', default: '', description: 'The pattern of file names to hide in the Tree View' }
		filePatternToExcludeFromHiding: { type: 'string', default: '', description: 'The pattern of file names to exclude from hiding' }
		keepAllOpenFilesRegardlessOfProject: { type: 'boolean', default: false, description: 'Keep any file that is opened regardless of the current project' }
		keepOutOfPathOpenFilesInCurrentProject: { type: 'boolean', default: false, description: 'Keep any file that is opened in the current project' }
		makeTheCurrentProjectTheDefaultAtStartUp: {
			type: 'boolean', default: false, description: 'Always make the currently chosen project the default at startup'
		}
		###
		projectToLoadAtStartUp: { type: 'string', default: '', enum: [ '' ], description: 'The project name to load at startup' }
		###
		doNotSaveAndRestoreOpenProjectFiles: {
			type: 'boolean', default: false, description: 'Do not automatically handle the save/restoration of open files for projects'
		}
		useFilePatternHiding: { type: 'boolean', default: false, description: 'Use file name pattern hiding' }
		useNotifications: { type: 'boolean', default: true, description: 'Use notifications for important events' }

	activate: (state) ->
		setTimeout (=> @initialize state), 0

	initialize: (state) ->
		if @projectRingInvariantState and @projectRingInvariantState.isInitialized
			return
		@projectRingInvariantState = Object.freeze
			emptyBufferDestroyDelayOnStartup: 750
			deletionDelay: 250
			changedPathsUpdateDelay: 500
			isInitialized: true
		@currentlySavingConfiguration =
			csonFile: false
		lib.setupEventHandling()
		@setupProjectRingNotification()
		@setupAutomaticProjectFileSaving()
		@setupAutomaticRootDirectoryAndTreeViewStateSaving()
		atom.config.observe 'project-ring.makeTheCurrentProjectTheDefaultAtStartUp', (makeTheCurrentProjectTheDefaultAtStartUp) =>
			return unless makeTheCurrentProjectTheDefaultAtStartUp and @currentProjectState
			lib.setDefaultProjectToLoadAtStartUp @currentProjectState.key
		projectKeyToLoadAtStartUp = lib.getDefaultProjectToLoadAtStartUp lib.getProjectRingId()
		lib.onceStatesCacheInitialized =>
			defaultProjectState = @getProjectState lib.defaultProjectCacheKey
			if defaultProjectState.files.open.length
				currentlyOpenFilePaths = @getOpenFilePaths().map (openFilePath) -> openFilePath.toLowerCase()
				filePathsToOpen = defaultProjectState.files.open.filter (filePathToOpen) -> filePathToOpen.toLowerCase() not in currentlyOpenFilePaths
				lib.openFiles filePath for filePath in filePathsToOpen
			setTimeout (=>
				atom.config.observe lib.projectToLoadAtStartUpConfigurationKeyPath, (projectToLoadAtStartUp) =>
					lib.setDefaultProjectToLoadAtStartUp  projectToLoadAtStartUp, true
				return if projectKeyToLoadAtStartUp and @getProjectState projectKeyToLoadAtStartUp
				@projectRingNotification.warn 'No project has been loaded' unless @projectLoadedByPathMatch
			), 0
		treeView = atom.packages.getLoadedPackage 'tree-view'
		if treeView
			unless treeView?.mainModule.treeView?.updateRoots
				treeView.activate().then =>
					setTimeout (=>
						treeView.mainModule.createView()
						treeView.mainModule.treeView.find('.tree-view').on 'click keydown', (event) =>
							setTimeout (=>
								@add updateRootDirectoriesAndTreeViewStateOnly: true
								@runFilePatternHiding()
							), 0
						@setProjectRing 'default', projectKeyToLoadAtStartUp
					), 0
			else
				treeView.mainModule.treeView.find('.tree-view').on 'click keydown', (event) =>
					setTimeout (=>
						@add updateRootDirectoriesAndTreeViewStateOnly: true
						@runFilePatternHiding()
					), 0
				@setProjectRing 'default', projectKeyToLoadAtStartUp
			atom.config.observe 'project-ring.useFilePatternHiding', (useFilePatternHiding) => @runFilePatternHiding useFilePatternHiding
			atom.config.observe 'project-ring.filePatternToHide', (filePatternToHide) => @runFilePatternHiding()
			atom.config.observe 'project-ring.filePatternToExcludeFromHiding', (filePatternToExcludeFromHiding) => @runFilePatternHiding()
		else
			@setProjectRing 'default', projectKeyToLoadAtStartUp
		atom.commands.add 'atom-workspace', 'tree-view:toggle', => @runFilePatternHiding()
		atom.commands.add 'atom-workspace', "project-ring:add-project", => @addAs()
		atom.commands.add 'atom-workspace', "project-ring:rename-current-project", => @addAs true
		atom.commands.add 'atom-workspace', "project-ring:toggle", => @toggle()
		atom.commands.add 'atom-workspace', "project-ring:open-project-files", => @toggle true
		atom.commands.add 'atom-workspace', "project-ring:open-multiple-projects", => @openMultipleProjects()
		atom.commands.add 'atom-workspace', "project-ring:add-current-file-to-current-project", => @addOpenFilePathToProject null, true
		atom.commands.add 'atom-workspace', "project-ring:add-files-to-current-project", => @addFilesToProject()
		atom.commands.add 'atom-workspace', "project-ring:ban-current-file-from-current-project", => @banOpenFilePathFromProject()
		atom.commands.add 'atom-workspace', "project-ring:ban-files-from-current-project", => @banFilesFromProject()
		atom.commands.add 'atom-workspace', "project-ring:always-open-current-file", => @alwaysOpenFilePath()
		atom.commands.add 'atom-workspace', "project-ring:always-open-files", => @alwaysOpenFiles()
		atom.commands.add 'atom-workspace', "project-ring:unload-current-project", => @unloadCurrentProject()
		atom.commands.add 'atom-workspace', "project-ring:delete-current-project", => @deleteCurrentProject()
		atom.commands.add 'atom-workspace', "project-ring:delete-project-ring", => @deleteProjectRing()
		atom.commands.add 'atom-workspace', "project-ring:edit-key-bindings", => @editKeyBindings()

	setupProjectRingNotification: ->
		@projectRingNotification = new (require './project-ring-notification')
		atom.config.observe 'project-ring.useNotifications', (useNotifications) => @projectRingNotification.isEnabled = useNotifications

	setupAutomaticProjectFileSaving: ->
		atom.config.observe 'project-ring.doNotSaveAndRestoreOpenProjectFiles', (doNotSaveAndRestoreOpenProjectFiles) =>
			if doNotSaveAndRestoreOpenProjectFiles
				lib.offAddedBuffer()
				atom.project.buffers.forEach (buffer) -> lib.offDestroyedBuffer buffer
				return unless @currentProjectState
				@currentProjectState.files.open = []
				@saveProjectRing()
			else
				onBufferDestroyedProjectRingEventHandlerFactory = (bufferDestroyed) =>
					=>
						return unless bufferDestroyed.file
						setTimeout (=>
							bufferDestroyed.projectRingFSWatcher.close() if bufferDestroyed.projectRingFSWatcher
							bufferDestroyedPathProxy = bufferDestroyed.file.path.toLowerCase()
							defaultProjectState = @getProjectState lib.defaultProjectCacheKey
							if lib.findInArray defaultProjectState.files.open, bufferDestroyedPathProxy, String.prototype.toLowerCase
								defaultProjectState.files.open =
									lib.filterFromArray defaultProjectState.files.open, bufferDestroyedPathProxy, String.prototype.toLowerCase
								@saveProjectRing()
								return
							return unless @checkIfInProject()
							if lib.findInArray @currentProjectState.files.open, bufferDestroyedPathProxy, String.prototype.toLowerCase
								@currentProjectState.files.open =
									lib.filterFromArray @currentProjectState.files.open, bufferDestroyedPathProxy, String.prototype.toLowerCase
								@saveProjectRing()
						), @projectRingInvariantState.deletionDelay
				atom.project.buffers.forEach (buffer) =>
					lib.offDestroyedBuffer buffer
					lib.onceDestroyedBuffer buffer, onBufferDestroyedProjectRingEventHandlerFactory buffer
				onAddedBufferDoSetup = (openProjectBuffer, deferedManualSetup) =>
					setTimeout (=>
						lib.offDestroyedBuffer openProjectBuffer unless deferedManualSetup
						lib.onceDestroyedBuffer openProjectBuffer, onBufferDestroyedProjectRingEventHandlerFactory openProjectBuffer
						_fs = require('fs')
						openProjectBufferFilePath = openProjectBuffer.file.path
						openProjectBuffer.projectRingFSWatcher = _fs.watch openProjectBuffer.file.path, (event, filename) =>
							setTimeout (=>
								return unless event is 'rename'
								affectedProjectKeys = @filterProjectRingFilePaths()
								if lib.defaultProjectCacheKey in affectedProjectKeys
									openProjectBuffer.projectRingFSWatcher.close() unless @fixOpenFilesToCurrentProjectAssociations()
									@projectRingNotification.warn 'File "' + openProjectBufferFilePath + '" has been removed from the list of files to always open'
								else if not @fixOpenFilesToCurrentProjectAssociations()
									openProjectBuffer.projectRingFSWatcher.close()
									@projectRingNotification.warn 'File "' + openProjectBufferFilePath + '" has been removed from the current project'
								openProjectBufferFilePath = openProjectBuffer.file.path
							), @projectRingInvariantState.changedPathsUpdateDelay
						if atom.config.get 'project-ring.keepAllOpenFilesRegardlessOfProject'
							@alwaysOpenFilePath openProjectBuffer.file.path, true
							return
						return unless \
							atom.config.get('project-ring.keepOutOfPathOpenFilesInCurrentProject') or
							lib.filePathIsInProject openProjectBuffer.file.path
						unless deferedManualSetup
							@addOpenFilePathToProject openProjectBuffer.file.path
						else
							@addOpenFilePathToProject openProjectBuffer.file.path, true, true
					), 0
				lib.onAddedBuffer (openProjectBuffer) =>
					if openProjectBuffer.file
						onAddedBufferDoSetup openProjectBuffer, false
					else
						lib.onceSavedBuffer openProjectBuffer, -> onAddedBufferDoSetup openProjectBuffer, true
		setTimeout (=>
			{ $ } = require 'atom-space-pen-views'
			$('.tab-bar').on 'drop', => setTimeout (=> @add updateOpenFilePathPositionsOnly: true), 0
		), 0

	setupAutomaticRootDirectoryAndTreeViewStateSaving: ->
		lib.onChangedPaths (rootDirectories) =>
			setTimeout (=>
				return unless @checkIfInProject() and not @currentlySettingProjectRootDirectories
				@add updateRootDirectoriesAndTreeViewStateOnly: true
				@runFilePatternHiding()
			), @projectRingInvariantState.changedPathsUpdateDelay

	runFilePatternHiding: (useFilePatternHiding) ->
		setTimeout (=>
			useFilePatternHiding =
				if typeof useFilePatternHiding isnt 'undefined' then useFilePatternHiding else atom.config.get 'project-ring.useFilePatternHiding'
			entries = atom.packages.getLoadedPackage('tree-view')?.mainModule.treeView?.find('.tree-view > .directory > .entries')\
				.find('.directory, .file') ? []
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
						(filePattern.test(filePath) and not (reverseFilePattern and reverseFilePattern.test(filePath))) or
						(filePattern.test(fileName) and not (reverseFilePattern and reverseFilePattern.test(fileName)))
							$$.removeAttr('data-project-ring-filtered').attr('data-project-ring-filtered', 'true').css 'display', 'none'
					else
						$$.removeAttr('data-project-ring-filtered').css 'display', ''
			else
				(entries.filter -> $(@).attr('data-project-ring-filtered') is 'true').each ->
					$(@).removeAttr('data-project-ring-filtered').css 'display', ''
		), 0

	setProjectState: (cacheKey, projectState) ->
		return unless typeof cacheKey is 'string' and typeof projectState is 'object'
		@statesCache = {} unless typeof @statesCache is 'object'
		@statesCache[lib.getProjectKey cacheKey] = projectState

	getProjectState: (cacheKey) ->
		return undefined unless @statesCache
		return @statesCache[lib.getProjectKey cacheKey]

	unsetProjectState: (cacheKey) ->
		return unless (typeof cacheKey is 'string' or cacheKey is null) and typeof @statesCache is 'object'
		delete @statesCache[lib.getProjectKey cacheKey]

	watchProjectRingConfiguration: (watch) ->
		return unless lib.getProjectRingId()
		csonFilePath = lib.getCSONFilePath()
		if watch and csonFilePath
			_fs = require 'fs'
			lib.setProjectRingConfigurationWatcher _fs.watch csonFilePath, (event, filename) =>
				if @currentlySavingConfiguration.csonFile
					@currentlySavingConfiguration.csonFile = false
					return
				@setProjectRing lib.getProjectRingId(), undefined, true
		else
			lib.unsetProjectRingConfigurationWatcher()

	setProjectRing: (id, projectKeyToLoad, fromConfigWatchCallback) ->
		@watchProjectRingConfiguration false
		validConfigurationOptions = Object.keys @config
		validConfigurationOptions.push lib.stripConfigurationKeyPath lib.projectToLoadAtStartUpConfigurationKeyPath
		configurationChanged = false
		projectRingConfigurationSettings = atom.config.settings['project-ring'] or {}
		for configurationOption in Object.keys projectRingConfigurationSettings
			continue if configurationOption in validConfigurationOptions
			delete projectRingConfigurationSettings[configurationOption]
			configurationChanged = true
		atom.config.save() if configurationChanged
		lib.setProjectRingId id
		@loadProjectRing projectKeyToLoad, fromConfigWatchCallback
		@watchProjectRingConfiguration true

	filterProjectRingFilePaths: ->
		return unless @statesCache
		_fs = require 'fs'
		statesCacheKeysFixed = []
		for key in Object.keys @statesCache
			statesCacheHasBeenFixed = false
			projectState = @getProjectState key
			rootDirectories = projectState.rootDirectories.filter (rootDirectory) -> _fs.existsSync rootDirectory
			if  rootDirectories.length isnt projectState.rootDirectories.length
				projectState.rootDirectories = rootDirectories
				statesCacheHasBeenFixed = true
			openFilePaths = projectState.files.open.filter (openFilePath) -> _fs.existsSync openFilePath
			if  openFilePaths.length isnt projectState.files.open.length
				projectState.files.open = openFilePaths
				statesCacheHasBeenFixed = true
			bannedFilePaths = projectState.files.banned.filter (bannedFilePath) -> _fs.existsSync bannedFilePath
			if  bannedFilePaths.length isnt projectState.files.banned.length
				projectState.files.banned = bannedFilePaths
				statesCacheHasBeenFixed = true
			statesCacheKeysFixed.push key if statesCacheHasBeenFixed
		@saveProjectRing() if statesCacheKeysFixed.length
		statesCacheKeysFixed

	loadProjectRing: (projectKeyToLoad, fromConfigWatchCallback) ->
		return unless lib.getProjectRingId()
		csonFilePath = lib.getCSONFilePath()
		return unless csonFilePath
		defaultProjectState = {
			key: lib.defaultProjectCacheKey,
			isDefault: true,
			rootDirectories: [],
			files: { open: [],  banned: [] },
			treeViewState: null
		}
		_fs = require 'fs'
		unless _fs.existsSync csonFilePath
			@setProjectState lib.defaultProjectCacheKey, defaultProjectState
			@saveProjectRing()
		_cson = require 'season'
		try
			@statesCache = _cson.readFileSync csonFilePath
			# START: TRANSITIONAL CODE TO MIGRATE THE PROJECT SPECIFICATION TO THE NEW FORMAT
			if @statesCache and @statesCache[lib.defaultProjectCacheKey] and @statesCache[lib.defaultProjectCacheKey]['openBufferPaths'] instanceof Array
				statesCacheTmp = {}
				for key in Object.keys @statesCache
					projectStateTmp = @statesCache[key]
					keyTmp = projectStateTmp.alias or lib.defaultProjectCacheKey
					statesCacheTmp[keyTmp] = {
						key: keyTmp,
						isDefault: keyTmp is lib.defaultProjectCacheKey,
						rootDirectories: if projectStateTmp.projectPath then [ projectStateTmp.projectPath ] else [],
						files: {
							open: projectStateTmp.openBufferPaths,
							banned: if projectStateTmp.bannedBufferPaths instanceof Array then projectStateTmp.bannedBufferPaths else []
						},
						treeViewState: projectStateTmp.treeViewState or null
					}
				@statesCache = statesCacheTmp
				@saveProjectRing()
				try
					pathFilePath = lib.getConfigurationFilePath 'default_project_ring_path.txt'
					_fs.unlinkSync pathFilePath if _fs.existsSync pathFilePath
				catch
			# END: TRANSITIONAL CODE TO MIGRATE THE PROJECT SPECIFICATION TO THE NEW FORMAT
			projectToLoad = undefined
			unless fromConfigWatchCallback
				@filterProjectRingFilePaths()
				rootDirectoriesSpec = atom.project.getPaths().map((path) -> path.toLowerCase().trim()).sort().join ''
				if rootDirectoriesSpec
					for key in Object.keys @statesCache
						continue if key is lib.defaultProjectCacheKey
						if rootDirectoriesSpec is @getProjectState(key).rootDirectories.map((path) -> path.toLowerCase().trim()).sort().join ''
							projectKeyToLoad = key
							@projectLoadedByPathMatch = true
							break
				projectToLoad = @getProjectState projectKeyToLoad
			if projectToLoad and not projectToLoad.isDefault
				setTimeout (=>
					@processProjectRingViewProjectSelection projectState: @getProjectState projectToLoad.key
					@runFilePatternHiding()
				), 0
		catch error
			@projectRingNotification.alert 'Could not load the project ring data for id: "' + lib.getProjectRingId() + '" (' + error + ')'
			return
		@setProjectState lib.defaultProjectCacheKey, defaultProjectState unless @getProjectState lib.defaultProjectCacheKey
		@currentProjectState = @getProjectState @currentProjectState.key if @currentProjectState
		lib.updateDefaultProjectConfiguration projectKeyToLoad, Object.keys @statesCache
		lib.emitStatesCacheInitialized()

	saveProjectRing: ->
		return unless lib.getProjectRingId()
		csonFilePath = lib.getCSONFilePath()
		return unless csonFilePath
		_cson = require 'season'
		try
			@currentlySavingConfiguration.csonFile = true
			_cson.writeFileSync csonFilePath, @statesCache
		catch error
			@currentlySavingConfiguration.csonFile = false
			@projectRingNotification.alert 'Could not save the project ring data for id: "' + lib.getProjectRingId() + '" (' + error + ')'
			return

	deactivate: ->
		@projectRingView.destroy() if @projectRingView
		@projectRingInputView.destroy() if @projectRingInputView
		@projectRingProjectSelectView.destroy() if @projectRingProjectSelectView
		@projectRingFileSelectView.destroy() if @projectRingFileSelectView

	serialize: ->

	loadProjectRingView: ->
		@projectRingView = new (require './project-ring-view') @ unless @projectRingView

	loadProjectRingInputView: ->
		@projectRingInputView = new (require './project-ring-input-view') @ unless @projectRingInputView

	loadProjectRingProjectSelectView: ->
		@projectRingProjectSelectView = new (require './project-ring-project-select-view') @ unless @projectRingProjectSelectView

	loadProjectRingFileSelectView: ->
		@projectRingFileSelectView = new (require './project-ring-file-select-view') @ unless @projectRingFileSelectView

	getOpenFilePaths: ->
		unless atom.config.get 'project-ring.doNotSaveAndRestoreOpenProjectFiles'
			return (atom.workspace.getTextEditors().filter (editor) -> editor.buffer.file).map (editor) -> editor.buffer.file.path
		return []

	checkIfInProject: (omitNotification) ->
		unless @currentProjectState or (omitNotification ? true)
			@projectRingNotification.alert 'No project has been loaded'
		return @currentProjectState

	addOpenFilePathToProject: (openFilePathToAdd, manually, omitNotification) ->
		return unless @checkIfInProject not manually or omitNotification
		deferedAddition = if openFilePathToAdd and not manually then true else false
		openFilePathToAdd = atom.workspace.getActiveTextEditor()?.buffer.file?.path unless openFilePathToAdd
		return unless openFilePathToAdd
		openFilePathToAdd = openFilePathToAdd.toLowerCase()
		defaultProjectState = @getProjectState lib.defaultProjectCacheKey
		return if \
			lib.findInArray(@currentProjectState.files.open, openFilePathToAdd, String.prototype.toLowerCase) or
			(not manually and
			 lib.findInArray @currentProjectState.files.banned, openFilePathToAdd, String.prototype.toLowerCase)
		if manually
			defaultProjectState.files.open =
				lib.filterFromArray defaultProjectState.files.open, openFilePathToAdd, String.prototype.toLowerCase
		unless  lib.findInArray @currentProjectState.files.open, openFilePathToAdd, String.prototype.toLowerCase
			onceAddedTextEditorHandler = =>
				setTimeout (=>
					@currentProjectState.files.banned =
						lib.filterFromArray @currentProjectState.files.banned, openFilePathToAdd, String.prototype.toLowerCase
					newOpenFilePaths = @getOpenFilePaths().filter (openFilePathInAll) =>
						openFilePathInAll.toLowerCase() is openFilePathToAdd or
						lib.findInArray @currentProjectState.files.open, openFilePathInAll.toLowerCase(), String.prototype.toLowerCase
					@currentProjectState.files.open = newOpenFilePaths
					@saveProjectRing()
					if manually and (typeof omitNotification is 'undefined' or not omitNotification)
						@projectRingNotification.notify \
							'File "' + require('path').basename(openFilePathToAdd) + '" has been added to project "' + @currentProjectState.key + '"'
				), 0
			if deferedAddition
				lib.onceAddedTextEditor onceAddedTextEditorHandler
			else
				onceAddedTextEditorHandler()

	banOpenFilePathFromProject: (openFilePathToBan) ->
		return unless @checkIfInProject false
		openFilePathToBan = atom.workspace.getActiveTextEditor()?.buffer.file?.path unless openFilePathToBan
		return unless openFilePathToBan
		openFilePathToBanProxy = openFilePathToBan.toLowerCase()
		unless lib.findInArray @currentProjectState.files.banned, openFilePathToBanProxy, String.prototype.toLowerCase
			@currentProjectState.files.open =
				lib.filterFromArray @currentProjectState.files.open, openFilePathToBanProxy, String.prototype.toLowerCase
			@currentProjectState.files.banned.push openFilePathToBan
			@saveProjectRing()
			@projectRingNotification.notify \
				'File "' + require('path').basename(openFilePathToBan) + '" has been banned from project "'+ @currentProjectState.key + '"'

	alwaysOpenFilePath: (filePathToAlwaysOpen, omitNotification) ->
		filePathToAlwaysOpen = atom.workspace.getActiveTextEditor()?.buffer.file?.path unless filePathToAlwaysOpen
		filePathToAlwaysOpenProxy = filePathToAlwaysOpen?.toLowerCase()
		defaultProjectState = @getProjectState lib.defaultProjectCacheKey
		return unless \
			filePathToAlwaysOpen and
			not lib.findInArray defaultProjectState.files.open, filePathToAlwaysOpenProxy, String.prototype.toLowerCase
		for stateKey in Object.keys @statesCache
			projectState = @getProjectState stateKey
			continue if projectState.isDefault
			projectState.files.open =
				lib.filterFromArray projectState.files.open, filePathToAlwaysOpenProxy, String.prototype.toLowerCase
		defaultProjectState.files.open.push filePathToAlwaysOpen
		@saveProjectRing()
		if omitNotification ? true
			@projectRingNotification.notify 'File "' + require('path').basename(filePathToAlwaysOpen) + '" has been marked to always open'

	add: (options) ->
		options = options or {}
		@projectRingView.destroy() if @projectRingView
		treeViewState = atom.packages.getLoadedPackage('tree-view')?.serialize() or null
		if options.updateRootDirectoriesAndTreeViewStateOnly
			return unless @checkIfInProject()
			@currentProjectState.rootDirectories = lib.getProjectRootDirectories()
			@currentProjectState.treeViewState = treeViewState
			@saveProjectRing()
			@fixOpenFilesToCurrentProjectAssociations()
			return
		if options.updateOpenFilePathPositionsOnly
			return unless @checkIfInProject()
			currentProjectOpenFilePaths = @currentProjectState.files.open.map (openFilePath) -> openFilePath.toLowerCase()
			@currentProjectState.files.open = @getOpenFilePaths().filter (openFilePath) -> openFilePath.toLowerCase() in currentProjectOpenFilePaths
			@saveProjectRing()
			return
		key = lib.getProjectKey options.key or @currentProjectState?.key or 'Project'
		key = '...' + key.substr key.length - 97 if key.length > 100
		unless @currentProjectState
			salt = 0
			keyTemp = key
			while keyTemp in Object.keys @statesCache
				keyTemp = key + (++salt).toString()
			key = keyTemp
		projectKeyToLoadAtStartUp = lib.getDefaultProjectToLoadAtStartUp() or ''
		if \
			@currentProjectState and
			key isnt @currentProjectState.key and
			key.toLowerCase() is projectKeyToLoadAtStartUp.toLowerCase()
				lib.setDefaultProjectToLoadAtStartUp key
		if options.renameOnly
			return unless @checkIfInProject false
			if @currentProjectState
				oldKey = @currentProjectState.key
				@currentProjectState.key = key
				@unsetProjectState oldKey
				@setProjectState key, @currentProjectState
				@saveProjectRing()
				lib.updateDefaultProjectConfiguration key, Object.keys(@statesCache), true, oldKey
				@projectRingNotification.notify 'Project "' + oldKey + '" is now known as "' + key + '"'
			return
		filePathsToAlwaysOpen = @getProjectState(lib.defaultProjectCacheKey).files.open.map (openFilePath) -> openFilePath.toLowerCase()
		@currentProjectState = {
			key: key,
			isDefault: false,
			rootDirectories: lib.getProjectRootDirectories(),
			files: {
				open: @getOpenFilePaths().filter((openFilePath) -> openFilePath.toLowerCase() not in filePathsToAlwaysOpen),
				banned: []
			},
			treeViewState: treeViewState
		}
		@setProjectState key, @currentProjectState
		@saveProjectRing()
		lib.updateDefaultProjectConfiguration key, Object.keys(@statesCache), true, key
		@projectRingNotification.notify 'Project "' + key + '" has been created/updated'

	addAs: (renameOnly) ->
		return if renameOnly and not @checkIfInProject false
		@loadProjectRingInputView()
		unless @projectRingInputView.isVisible()
			if @currentProjectState then key = @currentProjectState.key else key = undefined
			@projectRingInputView.attach { viewMode: 'project', renameOnly: renameOnly }, 'Project name', key

	toggle: (openProjectFilesOnly) ->
		deleteKeyBinding = lib.findInArray atom.keymaps.getKeyBindings(), 'project-ring:add', -> @.command
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
				currentItem: @checkIfInProject()
				openProjectFilesOnly: openProjectFilesOnly
				placeholderText:
					if not openProjectFilesOnly
					then 'Load project...' + deleteKeyBinding
					else 'Load files only...' + deleteKeyBinding
			}, @statesCache, 'key'

	openMultipleProjects: ->
		return unless @statesCache
		@loadProjectRingProjectSelectView()
		unless @projectRingProjectSelectView.isVisible()
			projectKeysToOfferForOpening = []
			Object.keys(@statesCache).forEach (key) =>
				currentProjectState = @checkIfInProject()
				return if key is lib.defaultProjectCacheKey or (currentProjectState and key is currentProjectState.key)
				projectKeysToOfferForOpening.push key
			@projectRingProjectSelectView.attach { viewMode: 'open', confirmValue: 'Open' }, projectKeysToOfferForOpening.sort()

	addFilesToProject: ->
		return unless @checkIfInProject false
		@loadProjectRingFileSelectView()
		unless @projectRingFileSelectView.isVisible()
			fileSpecsToOfferForAddition = []
			openFilesOfCurrentProject = @currentProjectState.files.open.map (openFilePath) -> openFilePath.toLowerCase()
			Object.keys(@statesCache).filter((key) =>
				not @getProjectState(key).isDefault and
				key isnt @currentProjectState.key
			).forEach (key) =>
				projectState = @getProjectState key
				projectState.files.open.filter((openFilePath) ->
					openFilePathProxy = openFilePath.toLowerCase()
					openFilePathProxy not in openFilesOfCurrentProject and
					not lib.findInArray fileSpecsToOfferForAddition, openFilePathProxy, -> @.path.toLowerCase()
				).forEach (openFilePath) =>
					description = openFilePath
					if description.length > 40
						description = '...' + description.substr description.length - 37
					fileSpecsToOfferForAddition.push title: key, description: description, path: openFilePath
			atom.project.buffers.filter((buffer) ->
				filePathProxy = buffer.file?.path.toLowerCase()
				buffer.file and
				filePathProxy not in openFilesOfCurrentProject and
				not lib.findInArray fileSpecsToOfferForAddition, filePathProxy, -> @.path.toLowerCase()
			).forEach (buffer) ->
				description = buffer.file.path
				description = '...' + description.substr description.length - 37 if description.length > 40
				fileSpecsToOfferForAddition.push title: 'Not In Project', description: description, path: buffer.file.path
			fileSpecsToOfferForAddition.sort (bufferPathSpec1, bufferPathSpec2) ->
				if bufferPathSpec1.title is 'Not In Project' and bufferPathSpec2.title is 'Not In Project'
					return bufferPathSpec1.title.toLowerCase() <= bufferPathSpec2.title.toLowerCase()
				return true if bufferPathSpec1.title is 'Not In Project'
				return false if bufferPathSpec2.title is 'Not in Project'
				bufferPathSpec1.title.toLowerCase() <= bufferPathSpec2.title.toLowerCase()
			@projectRingFileSelectView.attach { viewMode: 'add', confirmValue: 'Add' }, fileSpecsToOfferForAddition

	fixOpenFilesToCurrentProjectAssociations: ->
		return false unless @checkIfInProject() and not atom.config.get 'project-ring.doNotSaveAndRestoreOpenProjectFiles'
		filePathsToAlwaysOpen = @getProjectState(lib.defaultProjectCacheKey).files.open.map (openFilePath) -> openFilePath.toLowerCase()
		projectRelatedFilePaths = {}
		Object.keys(@statesCache).filter((key) -> key isnt lib.defaultProjectCacheKey).forEach (key) =>
			@getProjectState(key).files.open.forEach (openFilePath) -> projectRelatedFilePaths[openFilePath.toLowerCase()] = null
		projectRelatedFilePaths = Object.keys projectRelatedFilePaths
		associationsFixed = false
		atom.project.buffers.filter((buffer) =>
			bufferPath = buffer.file?.path.toLowerCase()
			bufferPath and
			bufferPath not in filePathsToAlwaysOpen and
			bufferPath not in projectRelatedFilePaths and
			not lib.findInArray @currentProjectState.files.banned, bufferPath, String.prototype.toLowerCase
		).forEach (buffer) =>
			bufferFilePathProxy = buffer.file.path.toLowerCase()
			if lib.filePathIsInProject bufferFilePathProxy
				@addOpenFilePathToProject buffer.file.path, true, true
				associationsFixed = true
		###
		currentProjectRelatedFilePaths = @currentProjectState.files.open.map (filePath) -> filePath.toLowerCase()
		currentProjectRelatedFilePaths.forEach (filePath) =>
			unless lib.filePathIsInProject filePath, @currentProjectState.rootDirectories
				@currentProjectState.files.open = lib.filterFromArray @currentProjectState.files.open, filePath.toLowerCase(), String.prototype.toLowerCase
		@saveProjectRing() if @currentProjectState.files.open.length isnt currentProjectRelatedFilePaths.length
		###
		associationsFixed

	banFilesFromProject: ->
		return unless @checkIfInProject false
		@loadProjectRingFileSelectView()
		unless @projectRingFileSelectView.isVisible()
			filePathsToOfferForBanning = []
			atom.project.buffers.filter((buffer) ->
				buffer.file and
				not lib.findInArray filePathsToOfferForBanning, buffer.file.path.toLowerCase(), -> @.path.toLowerCase()
			).forEach (buffer) ->
				description = buffer.file.path
				description = '...' + description.substr description.length - 37 if description.length > 40
				filePathsToOfferForBanning.push title: require('path').basename buffer.file.path, description: description, path: buffer.file.path
			filePathsToOfferForBanning.sort()
			@projectRingFileSelectView.attach { viewMode: 'ban', confirmValue: 'Ban' }, filePathsToOfferForBanning

	alwaysOpenFiles: ->
		return unless @checkIfInProject false
		@loadProjectRingFileSelectView()
		unless @projectRingFileSelectView.isVisible()
			filePathsToOfferForAlwaysOpening = []
			atom.project.buffers.filter((buffer) ->
				buffer.file and
				not lib.findInArray filePathsToOfferForAlwaysOpening, buffer.file.path.toLowerCase(), -> @.path.toLowerCase()
			).forEach (buffer) ->
				description = buffer.file.path
				description = '...' + description.substr description.length - 37 if description.length > 40
				filePathsToOfferForAlwaysOpening.push
					title: require('path').basename buffer.file.path
					description: description
					path: buffer.file.path
			filePathsToOfferForAlwaysOpening.sort()
			@projectRingFileSelectView.attach { viewMode: 'always-open', confirmValue: 'Always Open' }, filePathsToOfferForAlwaysOpening

	unloadCurrentProject: (doNotShowNotification, doNotAffectAtom) ->
		return unless @checkIfInProject false
		@projectRingView.destroy() if @projectRingView
		unless doNotAffectAtom
			try
				atom.packages.getLoadedPackage('tree-view')?.mainModule?.treeView?.detach?()
			catch
			@currentlySettingProjectRootDirectories = true
			atom.project.rootDirectories.filter((rootDirectory) -> rootDirectory.projectRingFSWatcher).forEach (rootDirectory) ->
				rootDirectory.projectRingFSWatcher.close()
			atom.project.setPaths []
			@currentlySettingProjectRootDirectories = false
		@currentProjectState = undefined
		@projectRingNotification.warn 'No project has been loaded' unless doNotShowNotification

	deleteCurrentProject: ->
		@projectRingView.destroy() if @projectRingView
		return unless @currentProjectState
		key = @currentProjectState.key
		@currentProjectState = undefined
		@unsetProjectState key if key
		@saveProjectRing()
		lib.updateDefaultProjectConfiguration '', Object.keys(@statesCache), true, key
		@projectRingNotification.notify 'Project "' + key + '" has been deleted'

	deleteProjectRing: ->
		return unless lib.getProjectRingId() and not /^\s*$/.test lib.getProjectRingId()
		@projectRingView.destroy() if @projectRingView
		csonFilePath = lib.getCSONFilePath()
		_fs = require 'fs'
		_fs.unlinkSync csonFilePath if _fs.existsSync csonFilePath
		@setProjectRing 'default'
		@currentProjectState = undefined
		lib.updateDefaultProjectConfiguration '', [ '' ]
		@projectRingNotification.notify 'All project ring data has been deleted'

	handleProjectRingViewKeydown: (keydownEvent, viewModeParameters, selectedItem) ->
		return unless keydownEvent and selectedItem
		if \
			viewModeParameters.viewMode is 'project' and
			keydownEvent.altKey and
			keydownEvent.shiftKey
				switch keydownEvent.which
					when 8 then @processProjectRingViewProjectDeletion selectedItem.data # alt-shift-backspace
					when 85 then @unloadCurrentProject() # alt-shift-u


	processProjectRingViewProjectDeletion: (projectState) ->
		return unless projectState and @statesCache
		projectState = @getProjectState projectState.key
		return unless projectState
		@projectRingView.destroy() if @projectRingView
		if projectState.key is @currentProjectState?.key
			@currentProjectState = undefined
		@unsetProjectState projectState.key
		@saveProjectRing()
		lib.updateDefaultProjectConfiguration '', Object.keys(@statesCache), true, projectState.key
		@projectRingNotification.notify 'Project "' + projectState.key + '" has been deleted'

	handleProjectRingViewSelection: (viewModeParameters, data) ->
		switch viewModeParameters.viewMode
			when 'project'
				unless data.openInNewWindow
					@processProjectRingViewProjectSelection projectState: data.projectState, openProjectFilesOnly: viewModeParameters.openProjectFilesOnly
				else
					@processProjectRingProjectSelectViewSelection [ data.projectState.key ], 'open'
			else break

	closeProjectBuffersOnBufferCreate: ->
		filePathsToAlwaysOpen = @getProjectState(lib.defaultProjectCacheKey).files.open.map (openFilePath) -> openFilePath.toLowerCase()
		projectRelatedBufferPaths = {}
		Object.keys(@statesCache).filter((key) -> key isnt lib.defaultProjectCacheKey).forEach (key) =>
			@getProjectState(key).files.open.forEach (openFilePath) -> projectRelatedBufferPaths[openFilePath.toLowerCase()] = null
		projectRelatedBufferPaths = Object.keys projectRelatedBufferPaths
		projectUnrelatedBufferPaths = []
		atom.project.buffers.filter((buffer) -> buffer.file).forEach (buffer) =>
			bufferFilePathProxy = buffer.file.path.toLowerCase()
			projectUnrelatedBufferPaths.push bufferFilePathProxy if bufferFilePathProxy not in projectRelatedBufferPaths
		atom.project.buffers.filter((buffer) ->
			bufferPath = buffer.file?.path.toLowerCase()
			bufferPath and
			bufferPath not in filePathsToAlwaysOpen and
			bufferPath not in projectUnrelatedBufferPaths
		).forEach (buffer) ->
			lib.offDestroyedBuffer buffer
			lib.onceSavedBuffer buffer, -> buffer.destroy()
			buffer.save()

	processProjectRingViewProjectSelection: (options) ->
		options = options or {}
		return unless @getProjectState options.projectState?.key
		_fs = require 'fs'
		options.projectState.rootDirectories = options.projectState.rootDirectories.filter (filePath) -> _fs.existsSync filePath
		options.projectState.files.open = options.projectState.files.open.filter (filePath) -> _fs.existsSync filePath
		options.projectState.files.banned = options.projectState.files.banned.filter (filePath) -> _fs.existsSync filePath
		@saveProjectRing()
		oldKey = @currentProjectState?.key
		unless options.openProjectFilesOnly
			unless \
				options.projectState.key is oldKey and
				not options.isAsynchronousProjectPathChange
					@currentlySettingProjectRootDirectories = true
					atom.project.rootDirectories.filter((rootDirectory) -> rootDirectory.projectRingFSWatcher).forEach (rootDirectory) ->
						rootDirectory.projectRingFSWatcher.close()
					treeView = atom.packages.getLoadedPackage 'tree-view'
					lib.onceChangedPaths =>
						@currentlySettingProjectRootDirectories = false
						atom.project.rootDirectories.forEach (rootDirectory) =>
							_fs = require('fs')
							rootDirectory.projectRingFSWatcher = _fs.watch rootDirectory.path, (event, filename) =>
								return unless event is 'rename'
								@add updateRootDirectoriesAndTreeViewStateOnly: true
								@runFilePatternHiding()
						treeView?.mainModule.treeView?.show?()
						setTimeout (=>
							treeView?.mainModule.treeView?.updateRoots? options.projectState.treeViewState.directoryExpansionStates or null
							@runFilePatternHiding()
						), 0
						@currentProjectState = options.projectState
						@fixOpenFilesToCurrentProjectAssociations()
						@projectRingNotification.notify 'Project "' + options.projectState.key + '" has been loaded'
					atom.project.setPaths options.projectState.rootDirectories
			else
				@currentProjectState = options.projectState
				@fixOpenFilesToCurrentProjectAssociations()
				@projectRingNotification.notify 'Project "' + options.projectState.key + '" has been loaded'
			if atom.config.get 'project-ring.makeTheCurrentProjectTheDefaultAtStartUp'
				lib.setDefaultProjectToLoadAtStartUp options.projectState.key
		if \
			not options.openProjectFilesOnly and
			(not oldKey or
			 oldKey isnt options.projectState.key or
			 options.isAsynchronousProjectPathChange) and
			atom.project.buffers.length and
			atom.config.get 'project-ring.closePreviousProjectFiles'
				@closeProjectBuffersOnBufferCreate()
		removeEmptyBuffers = (bufferCreated) =>
			return if bufferCreated and not bufferCreated.file
			setTimeout (->
				(atom.project.buffers.filter (buffer) -> not buffer.file and buffer.cachedText is '').forEach (buffer) ->
					return if \
						bufferCreated is buffer or
						(atom.project.buffers.length is 1 and
						 not atom.project.buffers[0].file and
						 atom.project.buffers[0].cachedText is '' and
						 atom.config.get 'core.destroyEmptyPanes')
					lib.offDestroyedBuffer buffer
					buffer.destroy()
			), @projectRingInvariantState.emptyBufferDestroyDelayOnStartup
		filesCurrentlyOpen = @getOpenFilePaths().map (filePath) -> filePath.toLowerCase()
		filesToOpen = options.projectState.files.open.filter (filePath) -> filePath.toLowerCase() not in filesCurrentlyOpen
		if \
			(options.openProjectFilesOnly or
			 not atom.config.get 'project-ring.doNotSaveAndRestoreOpenProjectFiles') and
			filesToOpen.length
				lib.moveAllEditorsToFirstNonEmptyPane()
				lib.destroyEmptyPanes()
				lib.selectFirstNonEmptyPane()
				lib.onceAddedBuffer removeEmptyBuffers
				lib.openFiles filePath for filePath in filesToOpen
		else if atom.config.get 'project-ring.closePreviousProjectFiles'
			removeEmptyBuffers()

	handleProjectRingInputViewInput: (viewModeParameters, data) ->
		switch viewModeParameters.viewMode
			when 'project' then @processProjectRingInputViewProjectKey data, viewModeParameters.renameOnly
			else break

	processProjectRingInputViewProjectKey: (key, renameOnly) ->
		return unless key and not /^\s*$/.test key
		@add key: key, renameOnly: renameOnly

	handleProjectRingProjectSelectViewSelection: (viewModeParameters, data) ->
		switch viewModeParameters.viewMode
			when 'open' then @processProjectRingProjectSelectViewSelection data, 'open'
			else break

	processProjectRingProjectSelectViewSelection: (keys, action) ->
		return unless keys and keys.length
		switch action
			when 'open' then (
				openInCurrentWindow = not @checkIfInProject()
				didOpenOne = false
				configurationSet = false
				keys.forEach (key) =>
					projectState = @getProjectState key
					return unless projectState and not projectState.isDefault
					if openInCurrentWindow
						@processProjectRingViewProjectSelection projectState: projectState
						openInCurrentWindow = false
						didOpenOne = true
					else if projectState.rootDirectories.length
						lib.openFiles projectState.rootDirectories, true
						didOpenOne = true
					if didOpenOne and not configurationSet
						if atom.config.get 'project-ring.makeTheCurrentProjectTheDefaultAtStartUp'
							atom.config.set 'project-ring.makeTheCurrentProjectTheDefaultAtStartUp', false
						configurationSet = true
			) else break

	handleProjectRingFileSelectViewSelection: (viewModeParameters, data) ->
		switch viewModeParameters.viewMode
			when 'add' then @processProjectRingFileSelectViewSelection data, true
			when 'ban' then @processProjectRingFileSelectViewSelection data, false, true
			when 'always-open' then @processProjectRingFileSelectViewSelection data, false, false, true
			else break

	processProjectRingFileSelectViewSelection: (paths, add, ban, alwaysOpen) ->
		return unless paths and paths.length and (if add or ban then @checkIfInProject false else true)
		if add
			paths.forEach (path) => @addOpenFilePathToProject path, true
		else if ban
			paths.forEach (path) => @banOpenFilePathFromProject path
		else if alwaysOpen
			paths.forEach (path) => @alwaysOpenFilePath path

	editKeyBindings: ->
		_path = require 'path'
		keyBindingsFilePath = _path.join atom.packages.getLoadedPackage('project-ring').path, 'keymaps', 'project-ring.cson'
		_fs = require 'fs'
		unless _fs.existsSync keyBindingsFilePath
			@projectRingNotification.alert 'Could not find the default Project Ring key bindings file'
			return
		lib.openFiles keyBindingsFilePath
