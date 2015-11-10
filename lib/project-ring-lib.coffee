projectReceiverKey = Symbol 'projectReceiverKey'
workspaceReceiverKey = Symbol 'workspaceReceiverKey'
permanentEventKey = Symbol 'permanentEventKey'
onceEventKey = Symbol 'onceEventKey'
statesCacheInitializedEventKey = Symbol 'statesCacheInitializedEventKey'
changedPathsEventKey = Symbol 'changedPathsEventKey'
addedBufferEventKey = Symbol 'addedBufferEventKey'
addedTextEditorEventKey = Symbol 'addedTextEditorEventKey'
destroyedBufferEventKey = Symbol 'destroyedBufferEventKey'
savedBufferEventKey = Symbol 'savedBufferEventKey'
eventCallbacks = new Map()

isPermanentReceiver = (receiver) ->
	return receiver is projectReceiverKey or receiver is workspaceReceiverKey

initializeEventCallbacks = ->
	eventCallbacks.set projectReceiverKey, new Map()
	for eventKey in [ statesCacheInitializedEventKey, changedPathsEventKey, addedBufferEventKey ]
		eventCallbacks.get(projectReceiverKey).set eventKey, new Map()
		eventCallbacks.get(projectReceiverKey).get(eventKey).set permanentEventKey, []
		eventCallbacks.get(projectReceiverKey).get(eventKey).set onceEventKey, []
	eventCallbacks.set workspaceReceiverKey, new Map()
	for eventKey in [ addedTextEditorEventKey ]
		eventCallbacks.get(workspaceReceiverKey).set eventKey, new Map()
		eventCallbacks.get(workspaceReceiverKey).get(eventKey).set permanentEventKey, []
		eventCallbacks.get(workspaceReceiverKey).get(eventKey).set onceEventKey, []

addEventCallbackReceiver = (receiver, eventKey) ->
	return unless receiver
	eventCallbacks.set receiver, new Map() unless eventCallbacks.has receiver
	return if eventCallbacks.get(receiver).has eventKey
	eventCallbacks.get(receiver).set eventKey, new Map()
	eventCallbacks.get(receiver).get(eventKey).set permanentEventKey, []
	eventCallbacks.get(receiver).get(eventKey).set onceEventKey, []

isCallbackReceiver = (receiver) ->
	return false unless eventCallbacks.has(receiver)
	ekIter = eventCallbacks.get(receiver).values()
	ek = ekIter.next()
	while not ek.done
		return true if ek.value.get(permanentEventKey).size or ek.value.get(onceEventKey).size
		ek = ekIter.next()
	false

removeEventCallbackReceiver = (receiver, eventKey) ->
	return unless receiver and eventCallbacks.has receiver
	if typeof eventKey is 'undefined'
		eventCallbacks.delete receiver if not isPermanentReceiver(receiver)
	else
		return if isPermanentReceiver receiver
		eventCallbacks.get(receiver).delete eventKey
		eventCallbacks.delete receiver unless isCallbackReceiver receiver

addEventCallback = (receiver, eventKey, once, callback) ->
	return unless typeof callback is 'function'
	addEventCallbackReceiver receiver, eventKey
	eventCallbacks.get(receiver).get(eventKey).get(if once then onceEventKey else permanentEventKey).push callback

removeEventCallback = (receiver, eventKey, callback) ->
	return unless eventCallbacks.has receiver
	if typeof callback isnt 'function'
		removeEventCallbackReceiver receiver, eventKey
		return
	else
		return unless eventCallbacks.get(receiver).has eventKey
		pi = []; oi = []
		for e, i in eventCallbacks.get(receiver).get(eventKey).get(permanentEventKey)
			pi.push i if e is callback
		for e, i in eventCallbacks.get(receiver).get(eventKey).get(onceEventKey)
			oi.push i if e is callback
		eventCallbacks.get(receiver).get(eventKey).get(permanentEventKey).splice i, 1 for i in pi
		eventCallbacks.get(receiver).get(eventKey).get(onceEventKey).splice i, 1 for i in oi

onPreSetEventHandlerFactory = (receiver, eventKey) ->
	() ->
		return unless eventCallbacks.has(receiver) and eventCallbacks.get(receiver).has eventKey
		for callback in eventCallbacks.get(receiver).get(eventKey).get(permanentEventKey)
			callback.apply null, arguments if typeof callback is 'function'
		for callback in eventCallbacks.get(receiver).get(eventKey).get(onceEventKey)
			callback.apply null, arguments if typeof callback is 'function'
		eventCallbacks.get(receiver).get(eventKey).set onceEventKey, []
		removeEventCallbackReceiver receiver, eventKey

setupPreSetEventHandling = ->
	initializeEventCallbacks()
	atom.project.emitter.on 'project-ring-states-cache-initialized', onPreSetEventHandlerFactory projectReceiverKey, statesCacheInitializedEventKey
	atom.project.onDidChangePaths onPreSetEventHandlerFactory projectReceiverKey, changedPathsEventKey
	atom.project.onDidAddBuffer onPreSetEventHandlerFactory projectReceiverKey, addedBufferEventKey
	atom.workspace.onDidAddTextEditor onPreSetEventHandlerFactory workspaceReceiverKey, addedTextEditorEventKey

regExpEscapesRegExp = /[\$\^\*\(\)\[\]\{\}\|\\\.\?\+]/g
defaultProjectRingId = 'default'
projectRingId = undefined
projectRingConfigurationWatcher = undefined

module.exports = Object.freeze
	#############################
	# Public Variables -- Start #
	#############################

	projectToLoadAtStartUpConfigurationKeyPath: 'project-ring.projectToLoadAtStartUp'
	defaultProjectCacheKey: '<~>'

	###########################
	# Public Variables -- END #
	###########################

	####################################
	# Public Helper Functions -- Start #
	####################################

	setProjectRingId: (id) ->
		projectRingId = id?.trim() or defaultProjectRingId

	getProjectRingId: ->
		projectRingId or defaultProjectRingId

	stripConfigurationKeyPath: (keyPath) ->
		(keyPath or '').replace /^project-ring\./, ''

	getConfigurationPath: ->
		_path = require 'path'
		path = _path.join process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME'], '.atom-project-ring'
		_fs = require 'fs'
		_fs.mkdirSync path unless _fs.existsSync path
		path

	getConfigurationFilePath: (path) ->
		_path = require 'path'
		_path.join @getConfigurationPath(), path

	getCSONFilePath: ->
		return unless projectRingId
		@getConfigurationFilePath projectRingId + '_project_ring.cson'

	getDefaultProjectSpecFilePath: (_projectRingId) ->
		return unless _projectRingId or projectRingId
		@getConfigurationFilePath (_projectRingId or projectRingId) + '_project_ring.default_project_spec'

	getDefaultProjectToLoadAtStartUp: (_projectRingId) ->
		defaultProjectToLoadAtStartUp = undefined
		_fs = require 'fs'
		try
			defaultProjectToLoadAtStartUp = _fs.readFileSync @getDefaultProjectSpecFilePath(_projectRingId), 'utf8'
		catch error
			return undefined
		defaultProjectToLoadAtStartUp?.trim()

	setDefaultProjectToLoadAtStartUp: (key, onlyUpdateSpecFile) ->
		return unless typeof key is 'string'
		unless onlyUpdateSpecFile
			try
				atom.config.set @projectToLoadAtStartUpConfigurationKeyPath, key
			catch error
				return error
		defaultProjectToLoadAtStartUpFilePath = @getDefaultProjectSpecFilePath()
		_fs = require 'fs'
		unless key
			try
				_fs.unlinkSync defaultProjectToLoadAtStartUpFilePath if _fs.existsSync defaultProjectToLoadAtStartUpFilePath
				return
			catch error
				return error
		try
			_fs.writeFileSync defaultProjectToLoadAtStartUpFilePath, key, 'utf8'
		catch error
			return error

	setProjectRingConfigurationWatcher: (watcher) ->
		projectRingConfigurationWatcher = watcher
		undefined

	unsetProjectRingConfigurationWatcher: ->
		projectRingConfigurationWatcher?.close()
		projectRingConfigurationWatcher = undefined

	updateDefaultProjectConfiguration: (selectedProject, allProjects, oldSelectedProjectCondition, oldSelectedProject) ->
		selectedProject = '' unless selectedProject and typeof selectedProject is 'string'
		allProjects = [ '' ] unless allProjects instanceof Array
		allProjects.unshift '' unless '' in allProjects
		allProjects = @filterFromArray allProjects, @defaultProjectCacheKey
		allProjects.sort()
		projectKeyToLoadAtStartUp = @getDefaultProjectToLoadAtStartUp() ? ''
		if oldSelectedProjectCondition is true
			selectedProject = projectKeyToLoadAtStartUp unless oldSelectedProject is projectKeyToLoadAtStartUp
		else if oldSelectedProjectCondition is false
			projectKeyToLoadAtStartUp = @getDefaultProjectToLoadAtStartUp() ? ''
			selectedProject = projectKeyToLoadAtStartUp if oldSelectedProject is projectKeyToLoadAtStartUp
		else
			selectedProject = projectKeyToLoadAtStartUp
		selectedProject = '' unless selectedProject in allProjects
		atom.config.setSchema \
			@projectToLoadAtStartUpConfigurationKeyPath,
			{ type: 'string', default: selectedProject, enum: allProjects, description: 'The project name to load at startup' }
		@setDefaultProjectToLoadAtStartUp selectedProject

	openFiles: (filePathSpec, newWindow) ->
		filePathSpec = if filePathSpec instanceof Array then filePathSpec else [ filePathSpec ]
		newWindow = if typeof newWindow is 'boolean' then newWindow else false
		defer = require('q').defer()
		defer.resolve()
		promise = defer.promise
		if newWindow
			atom.open pathsToOpen: filePathSpec, newWindow: true
		else
			promise = promise.finally ((filePath) -> atom.workspace.open filePath).bind null, filePath for filePath in filePathSpec
		promise

	findInArray: (array, value, valueModFunc, extraModFuncArgs) ->
		return undefined unless array instanceof Array
		isValidFunc = typeof valueModFunc is 'function'
		extraModFuncArgs = if extraModFuncArgs instanceof Array then extraModFuncArgs else []
		for val in array
			return val if (if isValidFunc then valueModFunc.apply val, extraModFuncArgs else val) is value
		undefined

	filterFromArray: (array, value, valueModFunc) ->
		return array unless array instanceof Array
		isValidFunc = typeof valueModFunc is 'function'
		array = array.filter (val) -> (if isValidFunc then valueModFunc.call val else val) isnt value

	makeArrayElementsDistinct: (array, valueModFunc) ->
		return array unless array instanceof Array
		isValidFunc = typeof valueModFunc is 'function'
		distinctElements = new Map()
		array.forEach (val) -> distinctElements.set (if isValidFunc then valueModFunc.call val else val), val
		array = []
		iter = distinctElements.values()
		iterVal = iter.next()
		while not iterVal.done
			array.push iterVal.value
			iterVal = iter.next()
		array

	getProjectRootDirectories: ->
		atom.project.getPaths()

	getProjectKey: (keySpec) ->
		keySpec?.trim()

	turnToPathRegExp: (path) ->
		return '' unless path
		path.replace regExpEscapesRegExp, (match) -> '\\' + match

	filePathIsInProject: (filePath, projectRootDirectories) ->
		projectRootDirectories = if projectRootDirectories instanceof Array then projectRootDirectories else @getProjectRootDirectories()
		for rootDirectory in projectRootDirectories
			return true if new RegExp('^' + @turnToPathRegExp(rootDirectory), 'i').test(filePath)
		false

	getTextEditorFilePaths: ->
		(atom.workspace.getTextEditors().filter (editor) -> editor.buffer.file).map (editor) -> editor.buffer.file.path

	##################
	# Event Handling #
	##################

	#################################
	# ---- Event Handling - Generic #
	#################################

	setupEventHandling: -> setupPreSetEventHandling()

	#################################
	# ---- Event Handling - Project #
	#################################

	onChangedPaths: (callback) ->
		return unless typeof callback is 'function'
		addEventCallback projectReceiverKey, changedPathsEventKey, false, callback

	onceChangedPaths: (callback) ->
		return unless typeof callback is 'function'
		addEventCallback projectReceiverKey, changedPathsEventKey, true, callback

	onAddedBuffer: (callback) ->
		return unless typeof callback is 'function'
		addEventCallback projectReceiverKey, addedBufferEventKey, false, callback

	offAddedBuffer: (callback) ->
		removeEventCallback projectReceiverKey, addedBufferEventKey, callback

	onceAddedBuffer: (callback) ->
		return unless typeof callback is 'function'
		addEventCallback projectReceiverKey, addedBufferEventKey, true, callback

	onceStatesCacheInitialized: (callback) ->
		return unless typeof callback is 'function'
		addEventCallback projectReceiverKey, statesCacheInitializedEventKey, true, callback

	emitStatesCacheInitialized: ->
		atom.project.emitter.emit 'project-ring-states-cache-initialized'

	################################
	# ---- Event Handling - Buffer #
	################################

	offDestroyedBuffer: (buffer, callback) ->
		return unless buffer
		removeEventCallback buffer, destroyedBufferEventKey, callback

	onceDestroyedBuffer: (buffer, callback) ->
		return unless buffer and typeof callback is 'function'
		addEventCallback buffer, destroyedBufferEventKey, true, callback
		if not buffer.onDidDestroyProjectRingEventSet
			buffer.onDidDestroy onPreSetEventHandlerFactory buffer, destroyedBufferEventKey
			buffer.onDidDestroyProjectRingEventSet = true

	onceSavedBuffer: (buffer, callback) ->
		return unless buffer and typeof callback is 'function'
		addEventCallback buffer, savedBufferEventKey, true, callback
		if not buffer.onDidSaveProjectRingEventSet
			buffer.onDidSave onPreSetEventHandlerFactory buffer, savedBufferEventKey
			buffer.onDidSaveProjectRingEventSet = true

	###################################
	# ---- Event Handling - Workspace #
	###################################

	onceAddedTextEditor: (callback) ->
		return unless typeof callback is 'function'
		addEventCallback workspaceReceiverKey, addedTextEditorEventKey, true, callback

	onAddedPane: (callback) ->
		return unless typeof callback is 'function'
		atom.workspace.paneContainer.emitter.on 'did-add-pane', callback
		if typeof atom.workspace.paneContainer.projectRingOnAddedPaneCallback is 'function'
			atom.workspace.paneContainer.emitter.off 'did-add-pane', atom.workspace.paneContainer.projectRingOnAddedPaneCallback
		atom.workspace.paneContainer.projectRingOnAddedPaneCallback = callback

	onDestroyedPane: (callback) ->
		return unless typeof callback is 'function'
		atom.workspace.paneContainer.emitter.on 'did-destroy-pane', callback
		if typeof atom.workspace.paneContainer.projectRingOnDestroyedPaneCallback is 'function'
			atom.workspace.paneContainer.emitter.off 'did-destroy-pane', atom.workspace.paneContainer.projectRingOnDestroyedPaneCallback
		atom.workspace.paneContainer.projectRingOnDestroyedPaneCallback = callback

	onDestroyedPaneItem: (callback) ->
		return unless typeof callback is 'function'
		atom.workspace.paneContainer.emitter.on 'did-destroy-pane-item', callback
		if typeof atom.workspace.paneContainer.projectRingOnDestroyedPaneItemCallback is 'function'
			atom.workspace.paneContainer.emitter.off 'did-destroy-pane-item', atom.workspace.paneContainer.projectRingOnDestroyedPaneItemCallback
		atom.workspace.paneContainer.projectRingOnDestroyedPaneItemCallback = callback

	offAddedPane: () ->
		return unless typeof atom.workspace.paneContainer.projectRingOnAddedPaneCallback is 'function'
		atom.workspace.paneContainer.emitter.off 'did-add-pane', atom.workspace.paneContainer.projectRingOnAddedPaneCallback
		delete atom.workspace.paneContainer.projectRingOnAddedPaneCallback

	offDestroyedPane: () ->
		return unless typeof atom.workspace.paneContainer.projectRingOnDestroyedPaneCallback is 'function'
		atom.workspace.paneContainer.emitter.off 'did-destroy-pane', atom.workspace.paneContainer.projectRingOnDestroyedPaneCallback
		delete atom.workspace.paneContainer.projectRingOnDestroyedPaneCallback

	offDestroyedPaneItem: () ->
		return unless typeof atom.workspace.paneContainer.projectRingOnDestroyedPaneItemCallback is 'function'
		atom.workspace.paneContainer.emitter.off 'did-destroy-pane-item', atom.workspace.paneContainer.projectRingOnDestroyedPaneItemCallback
		delete atom.workspace.paneContainer.projectRingOnDestroyedPaneItemCallback

	#####################
	# Pane Manipulation #
	#####################

	getFirstNonEmptyPane: ->
		atom.workspace.getPanes().filter((pane) -> pane.getItems().length)[0]

	getRestPanes: ->
		firstNonEmptyPane = @getFirstNonEmptyPane()
		atom.workspace.getPanes().filter (pane) -> pane isnt firstNonEmptyPane

	selectFirstNonEmptyPane: ->
		firstNonEmptyPane = @getFirstNonEmptyPane()
		return undefined unless firstNonEmptyPane
		atom.workspace.activateNextPane() while firstNonEmptyPane isnt atom.workspace.getActivePane()
		firstNonEmptyPane

	moveAllEditorsToFirstNonEmptyPane: ->
		firstNonEmptyPane = @getFirstNonEmptyPane()
		@getRestPanes().forEach (pane) =>
			pane.getItems().forEach (item) =>
				return unless item.buffer
				if item.buffer.file
					itemBufferFilePath = item.buffer.file.path.toLowerCase()
					if @findInArray firstNonEmptyPane.getItems(), itemBufferFilePath, (
						-> @.buffer and @.buffer.file and @.buffer.file.path.toLowerCase() is itemBufferFilePath
					)
						pane.removeItem item
						return
				pane.moveItemToPane item, firstNonEmptyPane

	destroyEmptyPanes: ->
		panes = atom.workspace.getPanes()
		return if panes.length is 1
		panes.forEach (pane) ->
			return if atom.workspace.getPanes().length is 1
			pane.destroy() unless pane.items.length

	destroyRestPanes: (allowEditorDestructionEvent) ->
		@getRestPanes().forEach (pane) ->
			pane.getItems().forEach (item) ->
				return unless item.buffer and item.buffer.file
				item.emitter.off 'did-destroy' unless allowEditorDestructionEvent
			pane.destroy()

	buildPanesMap: (mappableFilePaths) ->
		{ $ } = require 'atom-space-pen-views'
		mappableFilePaths = if mappableFilePaths instanceof Array then mappableFilePaths else []
		panesMap = { root: {} }
		currentNode = panesMap.root
		_getPaneMappableFilePaths = ($pane, mappableFilePaths) ->
			pane = atom.workspace.getPanes().filter((pane) -> atom.views.getView(pane) is $pane[0])[0]
			return [] unless pane
			return pane
				.getItems()
				.filter((item) -> item.buffer && item.buffer.file && mappableFilePaths.some((filePath) -> filePath is item.buffer.file.path))
				.map (textEditor) -> textEditor.buffer.file.path
		_fillPanesMap = ($axis, currentNode) ->
			unless $axis.length
				currentNode.type = 'pane'
				currentNode.filePaths = _getPaneMappableFilePaths $('atom-pane-container > atom-pane'), mappableFilePaths
				return
			$axisChildren = $axis.children 'atom-pane-axis, atom-pane'
			isHorizontalAxis = $axis.is '.horizontal'
			currentNode.type = 'axis'
			currentNode.children = []
			currentNode.orientation = if isHorizontalAxis then 'horizontal' else 'vertical'
			$axisChildren.each ->
				$child = $ this
				flexGrow = parseFloat $child.css 'flex-grow'
				flexGrow = undefined if isNaN flexGrow
				if $child.is 'atom-pane-axis'
					currentNode.children.push type: 'axis', children: [], orientation: null, flexGrow: flexGrow
				else if $child.is 'atom-pane'
					currentNode.children.push type: 'pane', filePaths: _getPaneMappableFilePaths($child, mappableFilePaths), flexGrow: flexGrow
			currentNode.children.forEach (child, index) ->
				return unless child.type is 'axis'
				_fillPanesMap $($axisChildren[index]), child
		_fillPanesMap $('atom-pane-container > atom-pane-axis'), currentNode
		panesMap.root

	buildPanesLayout: (panesMap) ->
		_openPaneFiles = (pane) => @openFiles pane.filePaths
		return _openPaneFiles panesMap if panesMap.type is 'pane'
		_q = require 'q'
		{ $ } = require 'atom-space-pen-views'
		_buildAxisLayout = (axis) ->
			defer = _q.defer()
			defer.resolve()
			promise = defer.promise
			axisPaneCache = []
			axis.children.forEach (child, index) ->
				promise = promise.finally ((axis, child, index) ->
					if index > 0
						if axis.orientation is 'horizontal'
							atom.workspace.getActivePane().splitRight()
						else
							atom.workspace.getActivePane().splitDown()
					$child = $ atom.views.getView atom.workspace.getActivePane()
					$parent = 	$child.parent 'atom-pane-axis'
					if typeof axis.flexGrow is 'number' and isNaN parseFloat $parent.attr 'data-project-ring-flex-grow'
						$parent.attr 'data-project-ring-flex-grow', axis.flexGrow
					if typeof child.flexGrow is 'number' and isNaN parseFloat $child.attr 'data-project-ring-flex-grow'
						$child.attr 'data-project-ring-flex-grow', child.flexGrow
					if child.type is 'axis'
						axisPaneCache.push atom.workspace.getActivePane()
						_defer = _q.defer()
						_defer.resolve()
						return _defer.promise
					else
						return _openPaneFiles child
				).bind null, axis, child, index
			axis.children.forEach (child) ->
				promise = promise.finally ((child) ->
					_defer = _q.defer()
					_defer.resolve()
					return _defer.promise unless child.type is 'axis'
					axisPaneCache.shift().activate()
					_buildAxisLayout child
				).bind null, child
			promise
		axisLayoutBuildPromise = _buildAxisLayout panesMap
		axisLayoutBuildPromise = axisLayoutBuildPromise.finally ->
			setTimeout (->
				$('atom-pane-container > atom-pane-axis atom-pane-axis, atom-pane-container > atom-pane-axis atom-pane').each ->
					flexGrowAttr = 'data-project-ring-flex-grow'
					$this = $ @
					flexGrow = parseFloat $this.attr flexGrowAttr
					$this.removeAttr flexGrowAttr
					return if isNaN flexGrow
					$this.css 'flex-grow', flexGrow
			), 0
			__defer = _q.defer()
			__defer.resolve()
			__defer.promise

	fixPanesMapFilePaths: (panesMap) ->
		return unless panesMap and typeof panesMap is 'object' and typeof panesMap.length is 'undefined'
		_fs = require 'fs'
		if panesMap.type is 'pane'
			panesMap.filePaths = panesMap.filePaths.filter (filePath) -> _fs.existsSync filePath
			panesMap.filePaths = @makeArrayElementsDistinct panesMap.filePaths
			return
		_fixPanesAxisFilePaths = (axis) =>
			axis.children.forEach (child) =>
				if child.type is 'pane'
					child.filePaths = child.filePaths.filter (filePath) -> _fs.existsSync filePath
					child.filePaths = @makeArrayElementsDistinct child.filePaths
				else
					_fixPanesAxisFilePaths child
		_fixPanesAxisFilePaths panesMap

	##################################
	# Public Helper Functions -- END #
	##################################
