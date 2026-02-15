in vim, cmd-f goes to focus mode (full size window).

We do not do transitions, so don't use mac full screen. just take up the full screen like rectangle does (full width and height window). Exiting vim mode goes back to normal window size automatically so the only screen that needs a full width and 

in accord with our values.md:
- keybinding represented in the menu at bottom
- when in full size mode, switches to 'regular size'
- when exiting editor, everything is regular size (the feature is for editing only)

when in focus mode, line numbers are shown. Unless in vim editing style and the user does :set nonu or :set nonumber (or :set nonumb etc.) and :set nu puts numbers back.
numbers can also be shown/hidden in regular size mode with :set nu :set num :set number etc.
This :set mechanism is a hidden feature not described in help. It is vim-style and accords with user's muscle memory if they know it and is unobtrusive otherwise.
