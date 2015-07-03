# Project Ring

- ### Description

 #### Project management for the Atom editor.


- ### Main features

 - ##### Automatically load a project when Atom starts.

 - ##### Once a project is in the project ring, when loaded, changes to the tree view state, as well as opening and closing files, automatically update its state. Optionally, the panes layout can be saved as well in the project's state by enabling the relevant configuration option.

 - ##### When a project is added in one of Atom's windows it is available in other windows as well.

 - ##### It is possible to use a regular expression to filter the entries of the tree view to hide. The pattern is first matched against the file's path and then against the file's name. You can provide an _anti-pattern_ as well to prevent certain entries from being hidden. This works whether or not a project has been loaded from the project ring so that it can be used regardless of any other usage of the package.

 - ##### Easily change between projects using an _Alt-Tab_ logic.


- ### Usage per package commands
(each commmand can be invoked through the command pallete)

 - #### Adding/renaming/removing a project to/in/from the project ring:

    - **_Add Project_** adds the current project to the project ring. An input field pops up that allows you to enter the desired name. Invoking the same command again simply gives the opportunity to refresh the project's state in the ring if the same name is used.

    - **_Rename Current Project_** simply changes the name of a project but does not update its current status. This exists for cases where you wish to keep the watched project's resources as they are but change only its name.

    - **_Delete Current Project_** deletes the current project from the project ring, if there is a current project. You can use this feature from the **_Toggle_** list using the Atom unrelated shortcut _Alt-Shift-Delete_. **[ Note:** This shortcut is not an Atom key binding but instead a key combination for which the filter input box of the **_Toggle_** list is listening. Additionally, the key combination may differ in various OSes such as OS X where, e.g., the _Delete_ is triggered by _Fn+Delete_. **]**

 - #### Choosing a project to load in Atom:

    - **_Toggle_** displays a list with all the projects currently in the project ring and a mini editor above to filter this list. You can choose a project either by filtering and typing enter or by clicking on it. These actions load its state in Atom. In particular, Atom's project directories will be set to the ones of the chosen project, the tree view state will be updated to reflect the expanded folders as when it was last saved and the project's associated files will be opened. A checkbox in the mini editor allows one to open the selected project in a new window.

    - **_Open Project Files_** opens a project's files (_of course..._ :-) ) but does not actually load the chosen project's state. This means that the current project will remain _current_ and the tree view will remain as is. This feature is useful to _append_ one project's files to another project. This means that the opened files will be saved along with the current project's files (if a project had been previously loaded). To simply _view_ a project's files without actually saving them in a project, use the **_Unload Current Project_** command (see below).

    - **_Open Multiple Projects_** allows one to chose multiple projects for opening. If the current window is not associated with a project, the first project to open will open in it and the rest of the projects will open in new windows.

 - #### Manipulating a project's open files and marking files to always open:

    - **_Add Current File To Current Project_** adds the currently viewed file to the current project, if one has been loaded. If the file had been mark to always open (see below, **_Always Open Current File_**), it is added to the current project and associated only to it, i.e., it will not always open from that point on.

    - **_Open Files To Current Project_** opens a list with the currently open files that do not belong to any project and the files that belong to other projects in the project ring but not in the current one, if one has been loaded.

    - **_Ban Current File From Current Project_** removes the ability to automatically save and open the currently edited file. This can be undone by doing an explicit **_Add Current File To Current Project_**.

    - **_Ban Files From Current Project_** opens a list with any currently open file to select for banning in the current project.

    - **_Always Open Current File_** marks the currently viewed file so that it will always be opened when e.g., opening Atom or changing between projects. The file is first disassociated from any project and then added to the _always open list_. It will be removed from this list when it is closed.

    - **_Always Open Files_** opens a list with any currently open file to select for keeping it always open using the rules of the **_Always Open Current File_** above.

 - #### Other commands

    - **_Unload Current Project_**, well, _unlinks_ Atom from its current notion of project path. It is the opposite from opening a folder when Atom starts. This means that the tree view is emptied and that we can open another folder without Atom opening a new window for it. If a project had been loaded then it can be considered unloaded after this command has run. I.e., opening/closing files and manipulating the tree view after an _Open Folder..._ will not mess anything up.

    - **_Edit Key Bindings_** opens a file, with the package's key bindings file, for you to edit at will. After editing this file you should use the command _Window: Reload_ from the command palette or restart Atom.


- ### Explanation of the configuration options

 - **_Close Previous Project Files:_** If cheched, then loading a project which has files to open, will result in closing all the other projects' open files, but will leave any _Always Open_ files or _out-of-project-path_ files open.

 - **_File Pattern To Hide:_** This is a JavaScript RegExp pattern with which to decide what to hide in the tree view. A typical usage is to hide every folder beginning with a "." (dot). So one could write _"^\\."_ (without the quotes) in this field.

 - **_File Pattern To Exclude From Hiding:_** If a file of folder matches the **_File Pattern To Hide_** and the **_File Pattern To Exclude From Hiding_**, then it is not hidden as a result.

 - **_Use File Pattern Hiding:_** Turns on/off the file pattern hiding feature. To quickly turn off the feature while, at the same, leaving the contents of **_File Pattern To Hide_** intact, uncheck this field.

 - **_Keep All Open Files Regardless Of Project:_** If checked, any opened file will be automatically opened again when Atom restarts again but it will not be associated with any project. This way, a changing projects simply changes Atom's notion of the project root path. If any open file is closed, it is removed from the list and not opened again when Atom restarts.

 - **_Keep Out Of Path Open Files In Current Project:_** Unless checked, files not belonging to the current project's file path are not saved in the project's state when opened.

 - **_Make The Current Project The Default At StartUp:_** If checked, when loading a project that project will be set as the default for when Atom restarts, just as if **_Project To Load At StartUp_** (see below) had been set with that project's alias as the value.

 - **_Project To Load At StartUp:_** Select a project from the dropdown list to have it automatically load when Atom starts.

 - **_Do Not Save And Restore Open Project Files:_** If checked, then a project's files will not be saved in the project's state as they are opened nor will they be restored when the project is loaded.

 - **_Save And Restore The Panes Layout:_** If checked the project description will also contain a map of the text editor panes. With such a map available, when selecting a project to load, the corresponding map with be used to recreate the panes layout.

 - **_Use Notifications:_** Turns on/off the notifications from various actions of Project Ring. Alerts are always produced, when necessary, regardless of this configuration option's value.
