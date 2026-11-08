# Settings

export PATH=$HOME/local/bin:$HOME/.local/bin:$ENV_ROOT/bin:$PATH
if [ "NO_USER_LOCAL" != 1 ]; then
    export PATH=/usr/local/sbin:/usr/local/bin:$PATH
fi
export VIM_BIN=/usr/bin/vim
export EDITOR=$VIM_BIN
export SVN_EDITOR=$EDITOR
export VISUAL=$VIM_BIN
# Claude Code only: open Ctrl+G prompts via bin/cc-edit; global VISUAL stays vim
claude() { VISUAL="$ENV_ROOT/bin/cc-edit" command claude "$@"; }
export GREP_COLOR="1;33"
export HISTCONTROL=ignoreboth
export TERM=xterm-256color
export LANG=en_US.UTF-8
export LC_ALL=${LANG}
export LC_CTYPE=en_US.UTF-8
