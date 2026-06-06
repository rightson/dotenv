
ENV_BLOCK_HEAD='Added by shell-env.sh utility'
ENV_BLOCK_BEGIN='=Begin='
ENV_BLOCK_END='=End='

function get_line_number() {
    if [ "$1" = "" ] || [ "$2" = "" ]; then
        echo "Usage: get_line_number <pattern> <file>"
        return
    fi
    local pattern="$1"
    local file="$2"
    grep -n "$pattern" "$file" | cut -d: -f1
}

function ensure_line_in_file() {
    if [ "$1" = "" ] || [ "$3" = "" ]; then
        echo "Usage: ensure_line_in_file <match-pattern> <line> <file>"
        return
    fi
    local pattern="$1"
    local line="$2"
    local file="$3"
    if ! grep -qF "$pattern" "$file" 2> /dev/null; then
        echo "$line" >> "$file"
        echo "  + $line"
    fi
}

function get_shell_rc_path() {
    local target_root="${TARGET_ROOT:-$HOME}"
    case "$1" in
        *csh)
            echo "$target_root/.cshrc"
            ;;
        *bash)
            echo "$target_root/.bashrc"
            ;;
        *zsh)
            echo "$target_root/.zshrc"
            ;;
        *)
            echo "Unsupported shell (only supports csh, bash and zsh)"
            return
            ;;
    esac
}

function get_patched_rc() {
    if [ "$1" = "" ]; then
        echo "Usage: get_patched_rc <snell-name>"
        return
    fi
    local shell_name=$1
    local rc=`get_shell_rc_path $shell_name`
    local begin=`get_line_number "$ENV_BLOCK_HEAD" $rc`
    local end=`get_line_number "$ENV_BLOCK_END" $rc`
    echo -e "\n# $ENV_BLOCK_HEAD"
    if [ $shell_name = tcsh ]; then
        echo "setenv ENV_ROOT $ENV_ROOT"
    else
        echo "export ENV_ROOT=$ENV_ROOT"
    fi
    cat $ENV_ROOT/seeds/${shell_name}rc
    echo -e "# $ENV_BLOCK_END\n"
}

function patch_shell_rc() {
    if [ "$1" = "" ] || [ "$2" = "" ]; then
        echo "Usage: patch_shell_rc <snell-name> <rc-path>"
        return
    fi
    local shell_name=$1
    local rc=$2
    if [ "`grep \"$ENV_BLOCK_HEAD\" $rc 2> /dev/null`" != "" ]; then
        echo "$2 already patched"
        return
    fi
    local temp=`mktemp`
    # Create rc file if it doesn't exist
    if [ -f "$rc" ]; then
        cat $rc > $temp
        mv $rc ${rc}-`date +%F-%H-%M-%S`.bak
    fi
    get_patched_rc $shell_name >> $temp
    mv $temp $rc
    echo "$rc patched"
}

function patch_tmux_settings() {
    # Idempotently ensure newer tmux settings exist in an already-patched
    # ~/.tmux.conf (added after the original seed block). Safe to re-run.
    local target_root="${TARGET_ROOT:-$HOME}"
    local tmuxrc=$target_root/.tmux.conf
    if [ ! -f "$tmuxrc" ]; then
        echo "$tmuxrc not found; run patch_tmux_rc first"
        return
    fi
    echo "Ensuring tmux settings in $tmuxrc ..."
    ensure_line_in_file 'set -g mouse on' 'set -g mouse on' "$tmuxrc"
    ensure_line_in_file 'MouseDrag1Status' 'bind-key -n MouseDrag1Status swap-window -t=' "$tmuxrc"
    ensure_line_in_file 'pane-border-lines' 'set -g pane-border-lines heavy' "$tmuxrc"
}

function patch_tmux_rc() {
    local target_root="${TARGET_ROOT:-$HOME}"
    local tmuxrc=$target_root/.tmux.conf
    if [ "`grep \"$ENV_BLOCK_HEAD\" $tmuxrc 2> /dev/null`" = "" ]; then
        echo "Patching $tmuxrc ... "
        cat "${ENV_ROOT}/seeds/tmux.conf" >> $tmuxrc
    else
        echo "$tmuxrc already patched"
        patch_tmux_settings
    fi

}

function patch_vim_rc() {
    local target_root="${TARGET_ROOT:-$HOME}"
    local vimrc=$target_root/.vimrc
    local local_vimrc=$target_root/.vimrc.plug
    if [ "`grep \"$ENV_BLOCK_HEAD\" $vimrc 2> /dev/null`" = "" ]; then
        echo "Patching $vimrc ..."
        echo -e "\n\" $ENV_BLOCK_HEAD" >> $vimrc
        echo "\" =Begin=" >> $vimrc
        echo "let g:target_root = '$target_root'" >> $vimrc
        echo "source $ENV_ROOT/vim/plug.vimrc" >> $vimrc
        echo "\" Update local Plug at $local_vimrc" >> $vimrc
        echo "source $ENV_ROOT/vim/helpers.vimrc" >> $vimrc
        echo "source $ENV_ROOT/vim/hotkeys.vimrc" >> $vimrc
        echo "source $ENV_ROOT/vim/setting.vimrc" >> $vimrc
        echo "\" =END=" >> $vimrc
	touch $local_vimrc
    else
        echo "$vimrc already patched"
    fi
}

function patch_nvim_rc() {
    local target_root="${TARGET_ROOT:-$HOME}"
    local nvimrc=$target_root/.config/nvim/init.vim
    local local_nvimrc=$target_root/.config/nvim/extra-plug.vim
    mkdir -p `dirname $nvimrc`;
    mkdir -p `dirname $local_nvimrc`;
	touch $local_nvimrc
    if [ "`grep \"$ENV_BLOCK_HEAD\" $nvimrc 2> /dev/null`" = "" ]; then
        echo "Patching $nvimrc ..."
        cat "${ENV_ROOT}/seeds/nvimrc" >> $nvimrc
        # echo -e "\n\" $ENV_BLOCK_HEAD" >> $nvimrc
        # echo "\" =Begin=" >> $nvimrc
        # echo "source $ENV_ROOT/vim/plug.vimrc" >> $nnvimrc
        # echo "\" Update local Plug at $local_nvimrc" >> $nvimrc
        # echo "source $ENV_ROOT/vim/helpers.vimrc" >> $nvimrc
        # echo "source $ENV_ROOT/vim/hotkeys.vimrc" >> $nvimrc
        # echo "source $ENV_ROOT/vim/setting.vimrc" >> $nvimrc
        # echo "\" =END=" >> $nvimrc
    else
        echo "$nvimrc already patched"
    fi
}

function patch_screen_rc() {
    local target_root="${TARGET_ROOT:-$HOME}"
    local screenrc=$target_root/.screenrc
    if [ "`grep \"$ENV_BLOCK_HEAD\" $screenrc 2> /dev/null`" = "" ]; then
        echo "Patching $screenrc ... "
        cat "${ENV_ROOT}/seeds/screenrc" >> $screenrc
    else
        echo "$screenrc already patched"
    fi
}

function patch_hammerspoon() {
    local target_root="${TARGET_ROOT:-$HOME}"
    local hammerspoon_init=$target_root/.hammerspoon/init.lua
    local seed_file="${ENV_ROOT}/seeds/hammerspoon/init.lua"

    # Create directory if it doesn't exist
    mkdir -p `dirname $hammerspoon_init`

    # Backup existing file only if it would change after patching
    if [ -f "$hammerspoon_init" ]; then
        if ! cmp -s "$hammerspoon_init" "$seed_file"; then
            local ts=`date +%Y-%m-%d-%H-%M-%S`
            echo "Backing up $hammerspoon_init to $hammerspoon_init.bak-$ts"
            cp "$hammerspoon_init" "$hammerspoon_init.bak-$ts"
            # Copy seed file to target
            echo "Copying Hammerspoon config from $seed_file to $hammerspoon_init"
            cp "$seed_file" "$hammerspoon_init"
        else
            echo "$hammerspoon_init is already up to date, skipping"
        fi
    else
        # Copy seed file to target (no backup needed for new file)
        echo "Copying Hammerspoon config from $seed_file to $hammerspoon_init"
        cp "$seed_file" "$hammerspoon_init"
    fi
}

function patch_karabiner() {
    local target_root="${TARGET_ROOT:-$HOME}"
    local karabiner_config=$target_root/.config/karabiner/karabiner.json
    local seed_file="${ENV_ROOT}/seeds/karabiner/karabiner.json"

    # Create directory if it doesn't exist
    mkdir -p `dirname $karabiner_config`

    # Backup existing file only if it would change after patching
    if [ -f "$karabiner_config" ]; then
        if ! cmp -s "$karabiner_config" "$seed_file"; then
            local ts=`date +%Y-%m-%d-%H-%M-%S`
            echo "Backing up $karabiner_config to $karabiner_config.bak-$ts"
            cp "$karabiner_config" "$karabiner_config.bak-$ts"
            # Copy seed file to target
            echo "Copying Karabiner config from $seed_file to $karabiner_config"
            cp "$seed_file" "$karabiner_config"
        else
            echo "$karabiner_config is already up to date, skipping"
        fi
    else
        # Copy seed file to target (no backup needed for new file)
        echo "Copying Karabiner config from $seed_file to $karabiner_config"
        cp "$seed_file" "$karabiner_config"
    fi
}


function patch_rc_files() {
    if [ "$1" = "" ]; then
        echo "Usage: patch_rc_files <snell-name>"
        return
    fi
    local shell_name=$1
    echo "shell_name=$shell_name"
    local rc=`get_shell_rc_path $shell_name`
    echo "rc=$rc"

    patch_shell_rc $shell_name $rc
    patch_tmux_rc
    patch_vim_rc
    patch_screen_rc
    patch_nvim_rc
    patch_hammerspoon
    patch_karabiner

    echo "Please run below command to update your shell setting:"
    echo -e "\n\tsource $rc\n"
}
