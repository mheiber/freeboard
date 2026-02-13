
Make a mac clipboard app.
cmd-v pastes
cmd-shift-v or clicking the app in the menu bar opens a menu where ctrl-n ctrl-p, mouse, or fuzzy search select the entry.
Items in the drop-down have 'X' next to them to delete
UI for selecting recents is green and black retro hacker style (like "homebrew" theme of iterm) with subtle VCR glitch effects and not afrai of taking up a lot of space

Restrictions:
- ask me clarifying quesitons up front if it helps you, but don't stop once you've started building
- work as independently as you can! if you need permission from me or need to install something or do an internet search, request it up front
- build with xcodebuild
- Never store anything on disk, always in memory. 
- 0 internet, 0 API calls, totally local
- is well-tested (end-to-end style only) with good test coverage
- commit frequently each time you are in a good state. Include any open questions in the commit message, I can read it later and we can iterate
- Do not stop until done


Bonus features for passwords:
- If something appears to be a password then show it in the menu as `****` and remove it from memory after 1 minute. Use some logic like: no spaces, at least 5 characters, includes at least one lowercase character and at least one special character. Portions of git/hg commit hashes don't count as password-like
- If something is copied from bitwarden then treat it as a password
