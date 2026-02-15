
persist non-passowrds accross app launches using standard Apple ways, that work well with hardened sandbox.
Update our values to include a mention of this feature as a special case: when the user opts in to saying they want something safe persisted we persist it.

NEVER store passwords to disk ever - include this in values as well.
And when something is deleted, remove it even from memory (if we don't do this already)
