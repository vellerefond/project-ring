ProjectRing = require '../lib/project-ring'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "ProjectRing", ->
  activationPromise = null

  beforeEach ->
	activationPromise = atom.packages.activatePackage('project-ring')

  describe "when the project-ring:toggle event is triggered", ->
	it "reports that it need a proper spec", ->
	  waitsForPromise ->
		activationPromise
	  runs ->
		alert 'I need a proper spec!'
