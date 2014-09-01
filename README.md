# Project Ring

- ### **Description**:
> ###### Quickly cycle through saved projects in the same window.

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
> ###### Buffers are saved/restored automatically, unless the corresponding configuration options are set to different values.

 - **Project Loading**:
> ###### Load a project, along with its associated buffers and tree view state, or load its buffers without changing Atom's notion of _current project_, thus not affecting the loaded project's tree view. You can also load a new folder as the current project's root path using a key binding (command in command pallete: _Project Ring: Set Project Path_).

 - **Project Cycling**:
> ###### Use the toggle function to bring up a list of saved projects. There you can filter the list, delete a project by selecting it and typing alt-shift-delete. If a project path becomes invalid and you try to load it, it is automatically removed from the ring. If the appropriate configuration property, namely _Keep Only Project Buffers On Project Selection_, is set, then loading a project will close any unrelated buffers.
