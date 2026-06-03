function tmux_load_default_config () {
    tmux set -g default-shell /bin/tcsh
    tmux set -g pane-border-status top
    tmux set -g mouse on
    tmux set -g status-left-length 55
    tmux set -g base-index 0
    tmux set -g pane-base-index 0
    tmux set -g status-bg colour0
    tmux set -g status-fg white
    tmux set-option -g status-left '#[fg=green,bg=black][[#[bg=red,fg=white]#S#[fg=green,bg=black]]]'
    tmux set-option -g status-left-length 25
    tmux set-window-option -g window-status-format ' #[fg=white]#I#[fg=blue]:#[default]#W#[fg=white]#F'
    tmux set-window-option -g window-status-current-format ' #[bg=green,fg=white,bold]#I#[bg=green,fg=white,bold]:#[fg=white]#W#[fg=dim]#F'
    tmux set -g status-right '#[fg=green][[#[fg=yellow]%Y-%m-%d #[fg=white,bg=red]%H:%M:%S#[default]#($HOME/bin/battery)#[fg=cyan]]]'
    tmux set -g status-interval 1
}

function tmux_new_session () {
    local session_name=$1
    local window_name=$1
    tmux -2 new-session -s $session_name -n $window_name -d -c [pwd]
    echo "Session $session_name created with window named \"$window_name\""
    tmux_load_default_conf
}

function tmux_kill_session () {
    local session_name=$1
    tmux kill-session -t $session_name
    echo "Session $session_name killed"
}

function tmux_list_session () {
    local session_name=$1
    if [ -n "$session_name" ]; then
        tmux list-sessions -F "#{session_name}"
    else
        tmux list-sessions
    fi
}

function tmux_set_title () {
    local session_name=$1
    local window_name=$2
    local new_name=$3
    tmux rename-window -t $session_name:$window_name $new_name
}

function tmux_send_keys () {
    local session_name=$1
    local window_name=$2
    local new_name=$3
    local pane_id=$4
    if [ -z "$pane_id" ]; then
        local pane_id=0
    fi
    tmux send-keys -t $session_name:$window_name.$pane_id "$key" C-m
}

function tmux_set_pane_title () {
    local session_name=$1
    local window_name=$2
    local pane_title=$3
    tmux_send_keys $session_name $window_name `printf '\033]2;%s\033\\' \'$pane_title\'` 
}

function tmux_rename_pane() {
    local title=$1
    printf '\033]2;%s\033\\' "$title"
}

function tmux_rename_window() {
    local dir=${1:-$PWD}
    local name=$(basename "$dir" | tr -c 'A-Za-z0-9._-' '-' | sed 's/-*$//')
    tmux rename-window "$name"
}

function tmux_attach () {
    local session_name=$1
    tmux attach -t $session_name
}

function tmux_get_current_session () {
    tmux display-message -p '#S'
}

function tmux_get_current_window () {
    tmux display-message -p '#W'
}

function tmux_get_current_pane() {
    tmux display-message -p '#P'
}

function tmux_get_current() {
    tmux display-message -p '#S:#W.#P'
}

function tmux_send_key () {
    local target=$1
    if [ -z "$target" ]; then
        local target=`tmux_get_current`
    fi
    tmux send-keys -t $target "$key" C-m
}
