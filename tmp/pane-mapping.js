/*
var path = require('path');

var filesSpec = [
    'project-ring//tmp/pane-mapping.js'
];

console.clear();

filesSpec.forEach(function(spec) {
    var specParts = spec.split(/\/\//);
    try {
        require(path.join(atom.packages.getLoadedPackage(specParts[0]).path, specParts[1]).replace(/[^:]+:/, '').replace(/\\/g, '/')).run();
        console.info('loaded', spec);
    } catch (error) {
        console.error('failed to load', spec, ':', error);
    }
});
*/

module.exports = {
	run: function() {
		TextEditor = require('atom').TextEditor;
		$ = require('atom-space-pen-views').$;

		destroyEmptyPanes = function() {
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

		getFirstNonEmptyPane = function() {
			return atom.workspace.getPanes().filter(function(pane) { return pane.getItems().length; })[0];
		}

		getRestPanes = function() {
			var firstNonEmptyPane = getFirstNonEmptyPane();
			return atom.workspace.getPanes().filter(function (pane) { return pane !== firstNonEmptyPane; });
		}

		selectFirstNonEmptyPane = function() {
			var firstNonEmptyPane = getFirstNonEmptyPane();
			while (firstNonEmptyPane !== atom.workspace.getActivePane()) {
				atom.workspace.activateNextPane();
			}
			return firstNonEmptyPane;
		}

		moveAllEditorsToFirstNonEmptyPane = function() {
			var firstNonEmptyPane = getFirstNonEmptyPane();
			getRestPanes().forEach(function(pane) {
				pane.getItems().forEach(function(item) {
					if (!(item instanceof TextEditor)) {
						return;
					}
					if (item.buffer.file) {
						itemBufferFilePath = item.buffer.file.path.toLowerCase();
						if (firstNonEmptyPane.getItems().some(function(item) {
								return item instanceof TextEditor && item.buffer.file && item.buffer.file.path.toLowerCase() === itemBufferFilePath;
							})) {
							pane.removeItem(item);
							return;
						}
					}
					pane.moveItemToPane(item, firstNonEmptyPane);
				});
			});
		}

		destroyRestPanes = function(allowEditorDestructionEvent) {
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

		_mappableFilePaths = [ 'C:\\Users\\sdesyllas\\.atom\\packages\\project-ring\\tmp\\pane-mapping.js' ];
		_map = JSON.parse(unescape("%7B%22type%22%3A%22axis%22%2C%22children%22%3A%5B%7B%22type%22%3A%22pane%22%2C%22filePaths%22%3A%5B%22C%3A%5C%5CUsers%5C%5Csdesyllas%5C%5C.atom%5C%5Cpackages%5C%5Cproject-ring%5C%5Ctmp%5C%5Cpane-mapping.js%22%5D%7D%2C%7B%22type%22%3A%22axis%22%2C%22children%22%3A%5B%7B%22type%22%3A%22axis%22%2C%22children%22%3A%5B%7B%22type%22%3A%22pane%22%2C%22filePaths%22%3A%5B%22C%3A%5C%5CUsers%5C%5Csdesyllas%5C%5C.atom%5C%5Cpackages%5C%5Cproject-ring%5C%5Ctmp%5C%5Cpane-mapping.js%22%5D%7D%2C%7B%22type%22%3A%22pane%22%2C%22filePaths%22%3A%5B%22C%3A%5C%5CUsers%5C%5Csdesyllas%5C%5C.atom%5C%5Cpackages%5C%5Cproject-ring%5C%5Ctmp%5C%5Cpane-mapping.js%22%5D%7D%5D%2C%22orientation%22%3A%22horizontal%22%7D%2C%7B%22type%22%3A%22pane%22%2C%22filePaths%22%3A%5B%22C%3A%5C%5CUsers%5C%5Csdesyllas%5C%5C.atom%5C%5Cpackages%5C%5Cproject-ring%5C%5Ctmp%5C%5Cpane-mapping.js%22%5D%7D%5D%2C%22orientation%22%3A%22vertical%22%7D%2C%7B%22type%22%3A%22pane%22%2C%22filePaths%22%3A%5B%22C%3A%5C%5CUsers%5C%5Csdesyllas%5C%5C.atom%5C%5Cpackages%5C%5Cproject-ring%5C%5Ctmp%5C%5Cpane-mapping.js%22%5D%7D%5D%2C%22orientation%22%3A%22horizontal%22%7D"));

		buildPanesMap = function(mappableFilePaths) {
			mappableFilePaths = mappableFilePaths instanceof Array ? mappableFilePaths : [];

			var panesMap = { root: {} }, currentNode = panesMap.root;

			function _getPaneMappableFilePaths($pane, mappableFilePaths) {
				var pane = atom.workspace.getPanes().filter(function(pane) {
					return atom.views.getView(pane) === $pane[0];
				})[0];
				if (!pane) {
					return [];
				}
				return pane.getItems().filter(function(item) {
					return item.buffer && item.buffer.file && mappableFilePaths.some(function(filePath) { return filePath === item.buffer.file.path; });
				}).map(function(textEditor) {
					return textEditor.buffer.file.path;
				});
			}

			function _fillPanesMap($axis, currentNode) {
				if (!$axis.length) {
					currentNode.type = 'pane';
					currentNode.filePaths = _getPaneMappableFilePaths($axis, mappableFilePaths);
					return;
				}
				var $axisChildren = $axis.children('atom-pane-axis, atom-pane');
				var isHorizontalAxis = $axis.is('.horizontal');
				currentNode.type = 'axis';
				currentNode.children = [];
				currentNode.orientation = isHorizontalAxis ? 'horizontal' : 'vertical';
				$axisChildren.each(function() {
					var $child = $(this);
					if ($child.is('atom-pane-axis')) {
						currentNode.children.push({ type: 'axis', children: [], orientation: null });
					} else if ($child.is('atom-pane')) {
						currentNode.children.push({ type: 'pane', filePaths: _getPaneMappableFilePaths($child, mappableFilePaths) });
					}
				});
				currentNode.children.forEach(function(child, index) {
					if (child.type === 'pane') {
						return;
					}
					_fillPanesMap($($axisChildren[index]), child);
				});
			}

			_fillPanesMap($('atom-pane-container > atom-pane-axis'), currentNode);

			return panesMap.root;
		}

		buildPanesLayout = function(panesMap) {
			function _openPaneFiles(pane) {
				if (!pane.filePaths.length) {
					return;
				}
				for (var index = 0; index < pane.filePaths.length; index++) {
					atom.workspace.open(pane.filePaths[index]);
				}
			}

			if (panesMap.type === 'pane') {
				_openPaneFiles(panesMap);
				return;
			}

			function _buildAxisLayout(axis) {
				var axisPaneCache = [];
				axis.children.forEach(function(child, index) {
					if (index > 0) {
						if (axis.orientation === 'horizontal') {
							atom.workspace.getActivePane().splitRight();
						} else {
							atom.workspace.getActivePane().splitDown();
						}
					}
					if (child.type === 'axis') {
						axisPaneCache.push(atom.workspace.getActivePane());
					}
					if (child.type === 'pane') {
						_openPaneFiles(child);
					}
				});
				axis.children.forEach(function(child) {
					if (child.type === 'pane') {
						return;
					}
					axisPaneCache.shift().activate();
					_buildAxisLayout(child);
				});
			}

			_buildAxisLayout(panesMap);
		}
	}
};
