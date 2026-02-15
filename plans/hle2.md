This isn't actually completed, I'm expecting to see syntax highlighting in the main window, but am only seeing it in the editor:

../completed-plans/highlighteverywhere.md

NOTE: for performance, have some early cutoffs. When not in the editor, don't look at more than 40 lines to figure out which language something is. And make sure to only highlight a bit more than the visible text : if the user has 100 unexpanded things that are each 1000000 lines long, we should really only be highlighting around 700 lines at most. We want the app to feel fast and responsive. Add this to our values and give it as an example

