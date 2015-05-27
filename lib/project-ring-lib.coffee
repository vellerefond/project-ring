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

module.exports = Object.freeze
	##############################
	# Private Variables -- Start #
	##############################

	projectToLoadAtStartUpConfigurationKeyPath: 'project-ring.projectToLoadAtStartUp'
	defaultProjectCacheKey: '<~>'

	############################
	# Private Variables -- END #
	############################

	#####################################
	# Private Helper Functions -- Start #
	#####################################

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

	openFile: (filePathSpec, newWindow) ->
		filePathSpec = if filePathSpec instanceof Array then filePathSpec else [ filePathSpec ]
		newWindow = if typeof newWindow is 'boolean' then newWindow else false
		atom.open pathsToOpen: filePathSpec, newWindow: newWindow

	findInArray: (array, value, valueModFunc) ->
		return undefined unless array instanceof Array
		isValidFunc = typeof valueModFunc is 'function'
		for val in array
			return val if (if isValidFunc then valueModFunc.call val else val) is value
		undefined

	filterFromArray: (array, value, valueModFunc) ->
		return array unless array instanceof Array
		isValidFunc = typeof valueModFunc is 'function'
		array = array.filter (val) -> (if isValidFunc then valueModFunc.call val else val) isnt value

	getProjectRootDirectories: ->
		atom.project.getPaths()

	getProjectKey: (keySpec) ->
		keySpec?.trim()

	turnToPathRegExp: (path) ->
		return '' unless path
		path.replace regExpEscapesRegExp, (match) -> '\\' + match

	filePathIsInProject: (filePath) ->
		for rootDirectory in @getProjectRootDirectories()
			return true if new RegExp('^' + @turnToPathRegExp(rootDirectory), 'i').test(filePath)
		false

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

	###################################
	# Private Helper Functions -- END #
	###################################
