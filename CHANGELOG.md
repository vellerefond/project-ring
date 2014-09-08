###### 0.1.0 - First Release
* Project Funtions: Add / Add As / Rename / Delete From Ring
* Funtions that change the current project: Unlink Environment From Current Project / Set Current Environment Project / Delete Project Ring
* Buffer saving: Save buffers along with the project and restore them afterwards.
* Buffer restoring: Restore the buffers of the project being loaded.
* Buffer appending: Open the buffers of a saved project withoug affecting the current project.
* Configuration options regarding saving and restoring buffers and whether a loaded project should close all unrelated buffers.
* Basic keybinding for all the main functionality.

###### 0.2.0 - Predefined project loading / Automatic save/open for buffers / Configuration of skipSavingProjectBuffers
* Predefined project loading: Set from configuration, a project's alias can be provided for automatic loading on startup.
* Automatic save/open for buffers: Project's buffers are automatically updated as they are opened and closed.
* Configuration of skipSavingProjectBuffers: Automatic save/open of project's buffer is controlled by the observed configuration option "skipSavingProjectBuffers".

###### 0.2.1 - See v0.2.0 + Updated README.md

###### 0.3.0 - Configuration files now exist in ~/.atom-project-ring

###### 0.4.0 - Implementation for moving a project root path to another location (the location must be properly initialized to avoid losing state)

###### 0.5.0 - Implementation for "Project Ring: Edit Key Bindings" command palette option

###### 0.6.0 - Simple "Add" uses the base name as alias and configuration files are observed to keep the current project ring synchronized

###### 0.7.0 - Fixed Tree View handling

###### 0.8.0 - "Add" uses the preexisting alias if already set, implemented support for hiding files based on regular expression patterns and fixed tree view hiding/showing handling

###### 0.8.1 - Fixed project alias computation code (was running without closure for "this")

###### 0.9.0 - Implementation for configuration option "project-ring.closePreviousProjectBuffers"

###### 0.9.1 - Fixed "project-ring.closePreviousProjectBuffers" timing bug

###### 0.9.2 - Fixed Tree View state saving support

###### 0.9.3 - Code performance and logic fixes
* Better list view initialization
* If a project is updated while it is also the project that is loaded at startup, the "project-ring.projectToLoadOnStartUp" is updated accordingly.

###### 0.9.4 - Fix for the file hiding feature when changing project path

###### 0.9.5 - Fix for the file hiding feature when loading a project at startup

###### 0.9.6 - Minor code enhancement for the file hiding feature

###### 0.10.0 - Implementation for keeping an internal, queryable state as to whether there is a currently loaded project or not
