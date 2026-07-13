# Aliases

# common cliases
alias al='alias'
alias aliasrc="vim $ENV_ROOT/inc/aliases.sh"

# add common parameter
alias mv='mv -i'
alias cp='cp -r'
alias scp='scp -r'
alias wget='wget -c'
alias tree='tree -C'
if [[ `uname` = 'Darwin' ]]; then
    alias ls='ls -G'
    alias grep='grep --color'
    alias du1='sudo du -h -d1'
    alias toggle-hidden-file='defaults write com.apple.Finder AppleShowAllFiles'
else
    alias ls='ls --color'
    alias grep='grep --color'
    alias du1='sudo du -h --max-depth 1'
fi

# ls aliases
alias l='ls -lCF'
alias l.='ls -ld .*'
alias la='ls -A'
alias ll='ls -l'
alias lh='ls -lh'

# history aliases
alias hi='history'
alias hig='history | grep'

# chown/chmod
alias steal='sudo chown -R `id -u`:`id -g`'
alias 755='sudo chmod -R 755'

# kill aliases
alias ka9='killall -9'
alias k9='kill -9'

# rm aliases
alias rm-rf='rm -rf'
alias rm-tags='rm -f cscope.* ncscope.* tags'

# rc aliases
alias so=". ${PROFILE_PATH}; sleep 1; uniqueify_PATH; uniqueify_LD_LIBRARY_PATH;"
alias so.tmux="tmux source $HOME/.tmux.conf"
alias path='echo $PATH | sed "s/:/\n/g"'
alias path.lib='echo $LD_LIBRARY_PATH | sed "s/:/\n/g"'
alias shrc="vim ${PROFILE_PATH}"
alias vimrc="vim $HOME/.vimrc"
alias gvimrc="gvim $HOME/.gvimrc"
alias nvimrc="nvim $HOME/.config/nvim/init.lua"
alias tmuxrc="vim $HOME/.tmux.conf"

alias public-ip='curl ipinfo.io/ip'

# python aliases
alias py=python
alias py3=python3

# project virtual environments
function _project_venv_create() {
    local venv_name="${1:-.venv}"
    python3 -m venv "$venv_name" && "$venv_name/bin/pip" install --upgrade pip
}

function _project_venv_activate() {
    local venv_name="${1:-.venv}"

    if [ -f "$venv_name/bin/activate" ]; then
        source "$venv_name/bin/activate"
    elif [ "$venv_name" = ".venv" ] && [ -f "venv/bin/activate" ]; then
        printf '%s\n' \
            '[venv.activate] Warning: legacy ./venv detected; activating it for compatibility.' \
            '[venv.activate] Run venv.migrate, then rerun venv.activate. New environments use ./.venv.' >&2
        source venv/bin/activate
    else
        printf '[venv.activate] Virtual environment %s was not found. Run venv.create first.\n' "$venv_name" >&2
        return 1
    fi
}

function _project_venv_migrate() {
    python3 "$ENV_ROOT/bin/venv-migrate.py"
}

alias venv.create='_project_venv_create'
alias venv.activate='_project_venv_activate'
alias venv.migrate='_project_venv_migrate'

# tmux aliases
alias t='tmux'
alias tl='tmux ls'
#alias tn='tmux new -s'
function tn () {
    local name="${1:-$(basename "$(pwd)")}"
    if [ $# -gt 0 ]; then
        shift
    fi
    tmux new -s "$name" "$@"
}
alias ta='tmux attach'
alias tat='tmux attach -t'
alias tmux-rename-window='tmux_rename_window'
alias trw='tmux_rename_window'

# apt aliases
alias sau='sudo apt update'
alias sai='sudo apt install'
alias sas='sudo apt search'
alias saug='sudo apt update && sudo apt upgrade'
alias sadu='sudo apt update && sudo apt dist-upgrade'
alias sarm='sudo apt autoremove'

# alias ufw
alias sus='sudo ufw status'
alias sen='sudo ufw enable'
alias srm='sudo ufw remove'

alias vbm='VBoxManage'

alias sus='sudo service'

# aliases for brew services:
alias bs='brew services'
alias sbs='sudo brew services'
alias bs.list='brew services list'
alias bs.start='brew services start'
alias bs.status='brew services status'
alias bs.stop='brew services stop'
alias bs.restart='brew services restart'
alias bs.info='brew services info'

grep2() {
    grep $1 | grep -v grep | grep --color $1
}

alias xopen='xdg-open'

function td () {
    local name=`echo $1 | tr -cd '[:alnum:]'`
    shift
    local cmd=$*
    echo tmux new $name -d ${cmd[@]}
    tmux new $name -d ${cmd[@]}
}

# docker aliases
alias docker.ps='docker ps --format "table {{.ID}}\t{{.Names}}"'
# claude aliases
alias claude.agents='claude agents --cwd .'
