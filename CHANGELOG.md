###### 0.39.0 - feat(app): display current project in status bar

###### 0.38.1 - fix(app): fix typo introduced in v0.38.0

###### 0.38.0 - fix(app): fix configuration file if file exists but is empty

###### 0.37.2 - fix(app): clear previous project state files if not watching open files

###### 0.37.1 - Fixed logic bug for when saving the project state and the cache is not consistent

###### 0.37.0 - Fixed tree view file pattern hiding logic

###### 0.36.2 - Only warning and error notifications are dismissable

###### 0.36.1 - Changed the notification module to create dismissable notifications, except for error notifications

###### 0.36.0 - Implemented a tab and tab-bar context menu item for closing any project/always open unrelated files

###### 0.35.2 - Fixed the logic for when a project's files are removed from the file system but Atom opens their cached versions

###### 0.35.1 - Fixed the logic for always opened files in multiple windows

###### 0.35.0 - Added a clickable status bar tile for easier access to projects (feature started to address issue #38)

###### 0.34.2 - Fixed logic bug in the tree view restoration code

###### 0.34.1 - Fixed the logic for when a file that belongs to a project's open files is renamed

###### 0.34.0 - Switched the notification logic to use Atom's notifications (feature request of issue #39)

###### 0.33.2 - Fixed minor logic bug for when a file that belongs to a project is removed outside of Atom

###### 0.33.1 - Guarded against failed configuration reads when using the multiple simultaneously open projects feature (bug fix for issue #37)

###### 0.33.0 - Fixed the logic for when the configuration file is missing when starting Atom and when watching the file for changes (#36)

###### 0.32.8 - Renamed LICENCE.md to LICENSE

###### 0.32.7 - Removed the spec folder along with the default spec

###### 0.32.6 - Changed the licence from MIT to GPL-2.0

###### 0.32.5 - Implemented additional check to guard against saving the project configuration while in an invalid state

###### 0.32.4 - Implemented additional checks to guard against using the project state cache while in an invalid state

###### 0.32.3 - Removed debugging code

###### 0.32.2 - Implemented sanity checks and fixed the tree view state updating logic

###### 0.32.1 - Fixed a notification service initialization bug, as per issue #31

###### 0.32.0 - Implemented the ability to choose to automatically save and restore the panes layout
* Added a new configuration option (Save And Restore The Panes Layout) with a default value of false
* Implemented basic pane operations such as building a map of the panes layout as well as restoring the panes layout from a panes layout map
* Made use of the Q defered API to chain the steps of the file opening process as well as the pane layout building process
* Implemented the addition of the necessary information in the projects state configuration file so that the pane layout can be restored
* Implemented a basic way to save and restore the sizes of panes
* Filtered code using setTimeout

###### 0.31.0 - Implemented sanity checks and fixed the logic of the project state updates with respect to file changes
* Added sanity check to keep only existing project file paths at startup
* Fixed the logic of the Open Project Files command and substituted fs.[un]watchFile for fs.watch
* When a file is renamed, which includes it being deleted, the open file associations of the projects are updated

###### 0.30.1 - Fixed the file adding logic when creating a new empty file and then saving it while a project has been loaded

###### 0.30.0 - Fixed already opened files addition logic when adding a new project folder

###### 0.20.9 - Small CSS fix regarding the toggle view

###### 0.20.8 - Small logic fix for when opening an already opened file in another pane

###### 0.20.7 - Made logic fixes regarding the addition of files to projects and made it easier to delete a project or unload the current project using the toggle view
* When a project unrelated file is open and a project is loaded where the file belongs to one of the project's root directory subtrees, the file is automatically added to that project
* When a project is loaded only files that are in the open file list of other projects are closed and other files, even belonging to one of the other projects' root directory subtrees, are left open, since they are not yet part of that project
* The toggle view is listening combinations of key strokes to delete the selected project or unload the current project

###### 0.20.6 - Fixed deprecated API code (issue #27 (Project-ring deprecated))

###### 0.20.5 - Removed the context menu specification as there is no need for one

###### 0.20.4 - Removed the command "Show Current Project" in favor of using the list of the toggle action to highlight the current project

###### 0.20.3 - Added a new command (Show Current Project)

###### 0.20.2 - Implemented experimental support for opening projects in new windows
* The toggle action can now open a project in a new window
* A new command has been added to allow multiple projects to open at the same time (Open Multiple Projects)

###### 0.20.1 - Implemented sanity checks to guard against lingering, obsolete settings

###### 0.20.0 - Fixed the codebase to make it compatible with Atom's version 1.0 API
* Rewritten all event handling code
* Removed the ability to automatically load a project by opening it's root path (multiple root paths are now supported)
* Changed a new configuration file format to support multiple root directories
* Removed several minor and non important commands (Copy *, Set/Move Project Path)
* Now all projects require a name when they are added
* Removed the configuration option "Skip Opening Tree View When Changing Project Path"
* Changed the configuration option "Project To Load At StartUp" to a list of available projects to chose from
* Provided transitional code to go from the old project specification format to the new automatically

###### 0.19.6 - Code fixes to account for the new multi-root tree view behavior

###### 0.19.5 - Code fixes to conform with the new Atom API and correct the logic when restoring the Tree View state of a project

###### 0.19.4 - Minor code reformat

###### 0.19.3 - Fixed project cache key usage bug for when keys were not everywhere used correctly
* Fixed project cache key usage bug for when keys were not everywhere used correctly
* Reformatted the code to reduce lines and increase readability

###### 0.19.2 - Added a notification for when using alt-shift-delete to delete a project from the project selection view

###### 0.19.1 - Fix for the project deletion code (using alt-shift-delete)

###### 0.19.0 - Upgraded the package code to make it compatible with version 1.0 of the Atom API

###### 0.18.5 - Minor code logic fix

###### 0.18.4 - Using synchronous open for project files and fixes regarding the project loading logic

###### 0.18.3 - Minor syntactic code fix

###### 0.18.2 - Logic fix for when closing other project buffers upon switching projects

###### 0.18.1 - Minor logic fix for when changing project paths

###### 0.18.0 - Fixed issues #5 (Cannot set property 'treeViewState' of undefined) and #6 (Everytime I switch projects a opened file in the project I am opening gets its content erased)

###### 0.17.0 - Fixed "Close Previous Project Files" bug (due to Atom's API change; issue #4) and set the configuration to default to true
* Fixed "Close Previous Project Files" bug (due to Atom's API change; issue #4) and set the configuration to default to true
* Simplified project selection/switching code for stability
* Replaced "Skip Saving/Loading Project Files" configuration options with unified "Do Not Save And Restore Open Project Files" configuration option
* Removed "Keep Only Project Files On Project Selection" configuration option for simplicity

###### 0.16.6 - Code format fixes (coffeescript switch statement refactorings)

###### 0.16.5 - Reduced exposed package properties to a minimum

###### 0.16.4 - Minor behavior fix for configuration option "project-ring.makeTheCurrentProjectTheDefaultOnStartUp"

###### 0.16.3 - Fixed bug for when loading a project with invalid buffer paths

###### 0.16.2 - Minor fixes for notifications

###### 0.16.1 - Visual fixes for notifications and "Use Notifications" observed configuration option

###### 0.16.0 - Implemented notifications in Atom for project ring's actions/alerts

###### 0.15.2 - Minor behavioral changes regarding startup

###### 0.15.1 - Fixed first time initialization bug (issue #1)

###### 0.15.0 - Impemented the "Make The Current Project The Default On StartUp" configuration option
* Implemented the "project-ring.makeTheCurrentProjectTheDefaultOnStartUp" configuration option
* Bug fix regarding the alert shown when not in project yet opening a file

###### 0.14.1 - "Add Current File To Current Project" beats "Always Open Current File"

###### 0.14.0 - Added configuration option "project-ring.keepAllOpenFilesRegardlessOfProject"

###### 0.13.1 - Minor bug fix

###### 0.13.0 - Implemented support for banning files from projects and always opening certain files
* Banning files of current project by ignoring them when they are opened
* Option to always open certain files by removing them from their respective projects and adding them to the "default" project with alias "<~>"

###### 0.12.0 - Implemented "Add Current File To Project" and "Add Files To Current Project" support
* Add current file to project support
* Add files to current project support: open files and other projects' files
* Various important and minor bug fixes

###### 0.11.3 - Fixed the tree view handling for when it is not activated or hidden

###### 0.11.2 - Fixed spawning logic of new empty file in case of the "project-ring.closePreviousProjectBuffers" configuration option

###### 0.11.1 - Implemented updating the order of open buffers

###### 0.11.0 - File pattern hiding now matches file paths before file names

###### 0.10.1 - Fixed the file pattern hiding implementation to refresh the filtered items when collapsing/expanding a folder

###### 0.10.0 - Implementation for keeping an internal, queryable state as to whether there is a currently loaded project or not

###### 0.9.6 - Minor code enhancement for the file hiding feature

###### 0.9.5 - Fix for the file hiding feature when loading a project at startup

###### 0.9.4 - Fix for the file hiding feature when changing project path

###### 0.9.3 - Code performance and logic fixes
* Better list view initialization
* If a project is updated while it is also the project that is loaded at startup, the "project-ring.projectToLoadOnStartUp" is updated accordingly.

###### 0.9.2 - Fixed Tree View state saving support

###### 0.9.1 - Fixed "project-ring.closePreviousProjectBuffers" timing bug

###### 0.9.0 - Implementation for configuration option "project-ring.closePreviousProjectBuffers"

###### 0.8.1 - Fixed project alias computation code (was running without closure for "this")

###### 0.8.0 - "Add" uses the preexisting alias if already set, implemented support for hiding files based on regular expression patterns and fixed tree view hiding/showing handling

###### 0.7.0 - Fixed Tree View handling

###### 0.6.0 - Simple "Add" uses the base name as alias and configuration files are observed to keep the current project ring synchronized

###### 0.5.0 - Implementation for "Project Ring: Edit Key Bindings" command palette option

###### 0.4.0 - Implementation for moving a project root path to another location (the location must be properly initialized to avoid losing state)

###### 0.3.0 - Configuration files now exist in ~/.atom-project-ring

###### 0.2.1 - See v0.2.0 + Updated README.md

###### 0.2.0 - Predefined project loading / Automatic save/open for buffers / Configuration of skipSavingProjectBuffers
* Predefined project loading: Set from configuration, a project's alias can be provided for automatic loading on startup.
* Automatic save/open for buffers: Project's buffers are automatically updated as they are opened and closed.
* Configuration of skipSavingProjectBuffers: Automatic save/open of project's buffer is controlled by the observed configuration option "skipSavingProjectBuffers".

###### 0.1.0 - First Release
* Project Funtions: Add / Add As / Rename / Delete From Ring
* Funtions that change the current project: Unlink Environment From Current Project / Set Current Environment Project / Delete Project Ring
* Buffer saving: Save buffers along with the project and restore them afterwards.
* Buffer restoring: Restore the buffers of the project being loaded.
* Buffer appending: Open the buffers of a saved project withoug affecting the current project.
* Configuration options regarding saving and restoring buffers and whether a loaded project should close all unrelated buffers.
* Basic keybinding for all the main functionality.
