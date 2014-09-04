# Project Ring

- ### **Description**:
> ###### Project management for the Atom editor.

- ### **Main features**:

 - **Add**:
> ###### Add a project to the ring using the project root path as the alias (without prompts).

 - **Add As**:
> ###### Add a  project to the ring using the given alias (using a prompt for the alias). Doing an _Add As_ again will rename/update the project in the ring (i.e., the currently open buffers will be saved in the project's metadata).

 - **Rename**:
> ###### Rename the alias of a project without affecting the saved opened buffers or tree view state.

 - **Delete**:
> ###### Delete a project from the ring or the whole ring to start over.

 - **Buffer Save/Restore**:
> ###### Buffers are saved/restored automatically, unless the corresponding configuration options are set to different values. If "Skip Saving Project Buffers" is checked in settings, then the saved buffers for the current project are cleared and no more automatic buffer saving/restoring occurs.

 - **Project Loading**:
> ###### Load a project, along with its associated buffers and tree view state, or load its buffers without changing Atom's notion of _current project_, thus not affecting the loaded project's tree view. You can also load a new folder as the current project's root path using a key binding (command in command pallete: _Project Ring: Set Project Path_).

 - **Automatic Project Loading On Startup**:
> ###### Set a project's alias in the package's settings to have it automatically loaded on Atom's startup.

 - **Project Cycling**:
> ###### Use the toggle function to bring up a list of saved projects. There you can filter the list, delete a project by selecting it and typing alt-shift-delete. If a project path becomes invalid and you try to load it, it is automatically removed from the ring. If the appropriate configuration property, namely _Keep Only Project Buffers On Project Selection_, is set, then loading a project will close any unrelated buffers.

 - **Project Moving**:
> ###### Use the "Project Ring: Move Project Path" to move a project's root path to another location. This location **must** be properly initialized (e.g., all files copied under the new location) so as not to lose state.

 - **Configuration Synchronization**:
> ###### The configuration files are watched so that, e.g., adding, deleting or renaming a project in one window is reflected in all other windows.

 - **File Hiding In Tree View Using Regular Expressions**:
> ###### Use the corresponding configuration settings to setup a file name pattern and enable file hiding in tree view. These configuration settings are observed so as to reflect any changes on the tree view. The exclusion pattern is provided to _undo_ what the hiding pattern does for certain files. For example, to hide all files beginning with a "." (dot), simply enable the use of the hiding pattern and use the pattern "^\\.".
