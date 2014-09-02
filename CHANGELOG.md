## 0.1.0 - First Release
* Project Funtions: Add / Add As / Rename / Delete From Ring
* Funtions that change the current project: Unlink Environment From Current Project / Set Current Environment Project / Delete Project Ring
* Buffer saving: Save buffers along with the project and restore them afterwards.
* Buffer restoring: Restore the buffers of the project being loaded.
* Buffer appending: Open the buffers of a saved project withoug affecting the current project.
* Configuration options regarding saving and restoring buffers and whether a loaded project should close all unrelated buffers.
* Basic keybinding for all the main functionality.

## 0.2.0 - Predefined project loading / Automatic save/open for buffers / Configuration of skipSavingProjectBuffers
* Predefined project loading: Set from configuration, a project's alias can be provided for automatic loading on startup.
* Automatic save/open for buffers: Project's buffers are automatically updated as they are opened and closed.
* Configuration of skipSavingProjectBuffers: Automatic save/open of project's buffer is controlled by the observed configuration option "skipSavingProjectBuffers".

## 0.2.1 - See v0.2.0 + Updated README.md

## 0.3.0 - Configuration files now exist in ~/.atom-project-ring
