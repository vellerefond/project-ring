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

		_mappableFilePaths = [ 'C:\\Users\\sdesyllas\\.atom-project-ring\\default_project_ring.cson' ];

		buildPanesMap = function(mappableFilePaths) {
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
	}
};
