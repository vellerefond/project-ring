var TextEditor = require('atom').TextEditor;
var $ = require('atom-space-pen-views').$;

function destroyEmptyPanes() {
	var panes = atom.workspace.getPanes();
	if (panes.length == 1) {
		return;
	}
	panes.forEach(function(pane) {
		if (atom.workspace.getPanes().length == 1) {
			return;
		}
		if (pane.items.length === 0) {
			pane.destroy();
		}
	});
}

function getFirstPane() {
	return atom.workspace.getPanes()[0];
}

function getRestPanes() {
	return atom.workspace.getPanes().filter(function (pane, index) { return index > 0; });
}

function selectFirstPane() {
	var firstPane = getFirstPane();
	while (firstPane !== atom.workspace.getActivePane()) {
		atom.workspace.activateNextPane();
	}
	return firstPane;
}

function moveAllEditorsToFirstPane() {
	var firstPane = getFirstPane();
	getRestPanes().forEach(function(pane) {
		pane.getItems().forEach(function(item) {
			if (!(item instanceof TextEditor)) {
				return;
			}
			if (item.buffer.file) {
				itemBufferFilePath = item.buffer.file.path.toLowerCase();
				if (firstPane.getItems().some(function(item) {
						return item instanceof TextEditor && item.buffer.file && item.buffer.file.path.toLowerCase() === itemBufferFilePath;
					})) {
					pane.removeItem(item);
					return;
				}
			}
			pane.moveItemToPane(item, firstPane);
		});
	});
}

function destroyRestPanes(allowEditorDestructionEvent) {
	getRestPanes().forEach(function(pane){
		pane.getItems().forEach(function(item) {
			if (!(item instanceof TextEditor)) {
				return;
			}
			if (!allowEditorDestructionEvent) {
				item.emitter.off('did-destroy');
			}
		});
		pane.destroy();
	});
}

var _mappableFilePaths = [ 'C:\Users\sdesyllas\.atom-project-ring\default_project_ring.cson' ];

function buildPanesMap(mappableFilePaths) {
	mappableFilePaths = _mappableFilePaths;
	var panesMap = { type: 'axis', children: [] }, currentNode = panesMap;

	if (panes.length == 1) {
		return { type: 'pane', filePaths: [ mappableFilePaths ] };
	}

	var isHorizontalAxis;

	function _fillPanesMap($axis) {
		var $children = $axis.children();

		$.each($children, function($child) {
			currentNode.panes.push($pane[0]);
		});
	}

	_fillPanesMap($('atom-pane-container > atom-pane-axis'));

	return panesMap;
}
