# Project Ring

- ### Description

 #### Project management for the Atom editor.


- ### Main features

 - ##### Automatically load a project when Atom starts.

 - ##### Once a project is in the project ring, changes to the tree view state, as well as opening and closing files, automatically update its state.

 - ##### Adding a project in one of Atom's windows is visible in other windows as well.

 - ##### It is possible to use a regular expression to filter the entries of the tree view to hide. The pattern is first matched against the file's path and then against the file's name. You can provide an _anti-pattern_ as well to prevent certain entries from being hidden. This works whether or not a project has been loaded from the project ring so that it can be used regardless of any other usage of the package.

 - ##### Easily change between projects using an _Alt-Tab_ logic.


- ### Clarifications

 - Atom has the notion of a project path which is the currently open folder (if a folder had been previously opened). When refering to this path I will use the term _Atom's project path_. This is in contrast to a _project_ fron the point of view of this package. The latter is the former plus some state.


- ### Usage per package commands
(each commmand can be invoked through the command pallete)

 - #### Adding/renaming/removing a project to/in/from the project ring:

    - **_Add_** adds the current project to the project ring using as an alias, by default, the basename part or its path. The resources currently saved are the project's path (obviously :-) ), the tree view state (e.g., which folders are expanded) and the open files at the time of the invokation, minus the empty default files that Atom creates (empty, _untitled_ files). Using this command again updates all the resources of the project using the same alias.

    - **_Add As_** functions exactly the same way as **_Add_** but instead of using the default project alias, an input field pops up that allows you to enter the desired alias. Invoking the same command again simply gives the opportunity to refresh the project's state in the ring and to change its alias at the same time.

    - **_Rename_** simply changes the alias of a project but does not update its current status. This exists for cases where you wish to keep the watched project's resources as they are but change only its alias.

    - **_Delete_** deletes the current project from the project ring, if it had previously been added. You can use this feature from the **_Toggle_** list using the Atom unrelated shortcut _Alt-Shift-Delete_. **[ Note:** This shortcut is not an Atom key binding but instead a key combination for which the filter input box of the **_Toggle_** list is listening. Additionally, in the key combination may differ in various OSes such as OS X as the _Delete_ is triggered by _Fn+Delete_. **]**

 - #### Choosing a project to load in Atom:

    - **_Toggle_** displays a list with all the projects currently in the project ring and a mini editor above to filter this list. You can choose a project either by filtering and typing enter or by clicking on it. These actions load its state in Atom. In particular, Atom's project path will be set to that of the chosen project's, the tree view state will be updated to reflect the expanded folders as when it was last saved and the project's associated files will be opened.

    - **_Open Project Files_** opens a project's files (_of course..._ :-) ) but does not actually load the chosen project. This means that the current project will remain _current_ and the tree view will remain as is. This feature is usefull to _append_ one project's files to another project. This means that the opened files will be saved along with the current project's files (if a project had been previously loaded). To simply _view_ a project's files without actually saving them in a project, use the **_Unlink_** command (see below).

 - #### Manipulating a project's open files and marking files to always open:

    - **_Add Current File To Current Project_** adds the currently viewed file to the current project, if one has been loaded. If the file had been mark to always open (see below, **_Always Open Current File_**), it is added to the current project and associated only to it, i.e., it will not always open from that point on.

    - **_Open Files To Current Project_** opens a list with the currently open files that do not belong to any project and the files that belong to other projects in the project ring but not in the current one, if one has been loaded.

    - **_Ban Current File From Current Project_** removes the ability to automatically save and open the currently edited file. This can be undone by doing an explicit **_Add Current File To Current Project_**.

    - **_Ban Files From Current Project_** opens a list with any currently open file to select for banning in the current project.

    - **_Always Open Current File_** marks the currently viewed file so that it will always be opened when e.g., opening Atom or changing between projects. The file is first disassociated from any project and then added to the _always open list_. It will be removed from this list when it is closed.

    - **_Always Open Files_** opens a list with any currently open file to select for keeping it always open using the rules of the **_Always Open Current File_** above.

 - #### Manipulating Atom's project path

    - **_Unlink_**, well, _unlinks_ Atom from its current notion of project path. It is the opposite from opening a folder when Atom starts. This means that the tree view is emptied and that we can open another folder without Atom opening a new window for it. If a project had been loaded then it can be considered unloaded after this command has run. I.e., opening/closing files and manipulating the tree view after an _Open Folder..._ will not mess anything up.

    - **_Set Project Path_** first unlinks Atom from the current project path and then uses the user provider folder path to do an _Open Folder..._. After this one could use **_Add_** or **_Add As_** to create a new project at this path.

    - **_Move Project Path_** _moves_ the current project's root path to another location. It is exactly as if one did a **_Set Project Path_**, set up the tree view to the state it had before and opened the same files using the new project root path as the basepath. This leaves the alias unaffected. **[ Note:** The project's resources must be replicated in order for this to work due to the automatic saving of a project's state. **]**

 - #### Other commands

    - **_Edit Key Bindings_** opens a file, with the package's key bindings file, for you to edit at will. After editing this file you should use the command _Window: Reload_ from the command palette or restart Atom.

    - **_Copy Project Alias_** copies the current project's alias to the OS clipboard.

    - **_Copy Project Path_** copies the current project's path to the OS clipboard.

    - **_Delete Project Ring_** clears the project ring of all projects' states and after this command finishes, there is no currently loaded project.


- ### Explanation of the configuration options

 - **_Close Previous Project Files:_** If cheched, then loading a project which has files to open, will result in closing all the other projects' open files, but will leave any _Always Open_ files or _out-of-project-path_ files open.

 - **_File Pattern To Hide:_** This is a JavaScript RegExp pattern with which to decide what to hide in the tree view. A typical usage is to hide every folder beginning with a "." (dot). So one could write _"^\\."_ (without the quotes) in this field.

 - **_File Pattern To Exclude From Hiding:_** If a file of folder matches the **_File Pattern To Hide_** and the **_File Pattern To Exclude From Hiding_**, then it is not hidden as a result.

 - **_Use File Pattern Hiding:_** Turns on/off the file pattern hiding feature. To quickly turn off the feature while, at the same, leaving the contents of **_File Pattern To Hide_** intact, uncheck this field.

 - **_Keep All Open Files Regardless Of Project:_** If checked, any opened file will be automatically opened again when Atom restarts again but it will not be associated with any project. This way, a changing projects simply changes Atom's notion of the project root path. If any open file is closed, it is removed from the list and not opened again when Atom restarts.

 - **_Keep Out Of Path Open Files In Current Project:_** Unless checked, files not belonging to the current project's file path are not saved in the project's state when opened.

 - **_Make The Current Project The Default On StartUp:_** If checked, when loading a project that project will be set as the default for when Atom restarts, just as if **_Project To Load On StartUp_** (see below) had been set with that project's alias as the value.

 - **_Project To Load On StartUp:_** Give a project's alias of project root path in this field to have it automatically load when Atom starts. When renaming a project and if this project was the one specified in this field, then this field is automatically updated to contains the project's new alias.

 - **_Do Not Save And Restore Open Project Files:_** If checked, then a project's files will not be saved in the project's state as they are opened nor will they be restored when the project is loaded.

 - **_Skip Opening Tree View When Changing Project Path:_** If checked, then the tree view will not automatically opened (if it was previously hidden) when a changing from project to project (e.g., via **_Toggle_**) or setting a new project path (e.g., via **_Set Project Path_**).

 - **_Use Notifications:_** Turns on/off the notifications from various actions of Project Ring. Alerts are always produced, when necessary, regardless of this configuration option's value.
