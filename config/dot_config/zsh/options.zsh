# shellの挙動設定 (setopt・history・keybind)。最初のpromptより前に効いている必要があるので即時に読み込む。

# Completion
setopt COMPLETE_IN_WORD # Complete from both ends of a word.
setopt ALWAYS_TO_END    # Move cursor to the end of a completed word.
setopt PATH_DIRS        # Perform path search even on command names with slashes.
setopt AUTO_MENU        # Show completion menu on a successive tab press.
setopt AUTO_LIST        # Automatically list choices on ambiguous completion.
setopt AUTO_PARAM_SLASH # If completed parameter is a directory, add a trailing slash.
setopt EXTENDED_GLOB    # Needed for file modification glob modifiers with compinit.
setopt MENU_COMPLETE    # autoselect the first completion entry.
unsetopt FLOW_CONTROL   # Disable start/stop characters in shell editor.

# Directory stack
setopt AUTO_PUSHD        # Push the old directory onto the stack on cd.
setopt PUSHD_IGNORE_DUPS # Do not store duplicates in the stack.
setopt PUSHD_SILENT      # Do not print the directory stack after pushd or popd.
setopt PUSHD_TO_HOME     # Push to home directory when no argument is given.
setopt CDABLE_VARS       # Change directory to a path stored in a variable.
setopt MULTIOS           # Write to multiple descriptors.

# Command correction
setopt CORRECT              # Correct the spelling of a command before executing it.
setopt COMBINING_CHARS      # Combine zero-length punctuation characters (accents) with the base character.
setopt INTERACTIVE_COMMENTS # Enable comments in interactive shell.
setopt RC_QUOTES            # Allow 'Henry''s Garage' instead of 'Henry's Garage'.

# Jobs
setopt LONG_LIST_JOBS # List jobs in the long format by default.
setopt NOTIFY         # Report status of background jobs immediately.
unsetopt BG_NICE      # Don't run all background jobs at a lower priority.
unsetopt HUP          # Don't kill jobs on shell exit.
unsetopt CHECK_JOBS   # Don't report on jobs when shell exit.

# History
# zshは全rcファイルを読み終えた直後、最初のpromptの前にhistory fileを読むため、この設定は遅延できない
setopt BANG_HIST              # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY       # Write the history file in the ':start:elapsed;command' format.
setopt SHARE_HISTORY          # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST # Expire a duplicate event first when trimming history.
setopt HIST_IGNORE_DUPS       # Do not record an event that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS   # Delete an old recorded event if a new event is a duplicate.
setopt HIST_FIND_NO_DUPS      # Do not display a previously found event.
setopt HIST_IGNORE_SPACE      # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS      # Do not write a duplicate event to the history file.
setopt HIST_VERIFY            # Do not execute immediately upon history expansion.
setopt HIST_BEEP              # Beep when accessing non-existent history.

export HISTFILE="${HISTFILE:-${ZDOTDIR:-$HOME}/.zsh_history}"
export HISTSIZE=50000
export SAVEHIST=$HISTSIZE

# Keybindings (plugin固有のkeybind (history-substring-search) は plugins.toml の hooks.post にある)
bindkey -e # Use Emacs key bindings
bindkey "^[[Z" reverse-menu-complete
WORDCHARS='*?_-.[]~&;!#$%^(){}<>'
