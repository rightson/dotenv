
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

function get_patched_vimrc() {
    local target_root="${TARGET_ROOT:-$HOME}"
    echo -e "\n\" $ENV_BLOCK_HEAD"
    echo "\" =Begin="
    echo "let g:target_root = '$target_root'"
    echo "source $ENV_ROOT/vim/plug.vimrc"
    echo "\" Update local Plug at $target_root/.vimrc.plug"
    echo "source $ENV_ROOT/vim/helpers.vimrc"
    echo "source $ENV_ROOT/vim/hotkeys.vimrc"
    echo "source $ENV_ROOT/vim/setting.vimrc"
    echo "\" =END="
}

function patch_vim_rc() {
    local target_root="${TARGET_ROOT:-$HOME}"
    local vimrc=$target_root/.vimrc
    local local_vimrc=$target_root/.vimrc.plug
    if [ "`grep \"$ENV_BLOCK_HEAD\" $vimrc 2> /dev/null`" = "" ]; then
        echo "Patching $vimrc ..."
        get_patched_vimrc >> $vimrc
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

# Print seed lines ("<key> <type> <value>") whose current value differs
function get_scroll_reverser_changes() {
    local domain=com.pilotmoon.scroll-reverser
    local key type value current expected
    while read -r key type value; do
        case "$key" in ''|\#*) continue;; esac
        expected=$value
        if [ "$type" = "-bool" ]; then
            [ "$value" = "true" ] && expected=1 || expected=0
        fi
        current=`defaults read $domain $key 2> /dev/null`
        if [ "$current" != "$expected" ]; then
            echo "$key $type $value"
        fi
    done < "${ENV_ROOT}/seeds/scroll-reverser/defaults"
}

function patch_scroll_reverser() {
    local domain=com.pilotmoon.scroll-reverser

    # Preferences live in the macOS defaults database, not a dotfile
    if [ "`uname`" != "Darwin" ]; then
        return
    fi

    local changes=`get_scroll_reverser_changes`
    if [ "$changes" = "" ]; then
        echo "Scroll Reverser preferences are already up to date, skipping"
        return
    fi

    # Backup existing preferences before writing
    local backup=$HOME/Library/Preferences/$domain.plist.bak-`date +%Y-%m-%d-%H-%M-%S`
    if defaults export $domain "$backup" 2> /dev/null; then
        echo "Backing up Scroll Reverser preferences to $backup"
    fi
    local key type value
    echo "$changes" | while read -r key type value; do
        [ "$key" = "" ] && continue
        echo "Setting Scroll Reverser $key = $value"
        defaults write $domain $key $type $value
    done
    echo "Restart Scroll Reverser to apply the new preferences"
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
    patch_scroll_reverser

    echo "Please run below command to update your shell setting:"
    echo -e "\n\tsource $rc\n"
}

# Print the dotenv block (from ENV_BLOCK_HEAD to the end marker) of stdin
function extract_env_block() {
    awk -v head="$ENV_BLOCK_HEAD" 'index($0, head) {p=1} p {print} p && /=(End|END)=/ {exit}'
}

# Compare <deployed-file> with <expected-file>; with "block", only the dotenv block
function diff_deployed() {
    local mode=$1 deployed=$2 expected=$3
    if [ ! -f "$deployed" ]; then
        echo "[missing] $deployed"
        return 1
    fi
    if [ "$mode" = "block" ]; then
        local tmp=`mktemp -d`
        extract_env_block < "$expected" > $tmp/expected
        extract_env_block < "$deployed" > $tmp/deployed
        if [ ! -s $tmp/deployed ]; then
            echo "[not patched] $deployed"
            rm -rf $tmp
            return 1
        fi
        expected=$tmp/expected
        local actual=$tmp/deployed
    else
        local actual=$deployed
    fi
    local rc=0
    if cmp -s "$expected" "$actual"; then
        echo "[same]    $deployed"
    else
        echo "[differs] $deployed"
        diff -u --label "seed" --label "$deployed" "$expected" "$actual"
        rc=1
    fi
    [ "$mode" = "block" ] && rm -rf $tmp
    return $rc
}

function diff_rc_files() {
    if [ "$1" = "" ]; then
        echo "Usage: diff_rc_files <shell-name>"
        return 1
    fi
    local shell_name=$1
    local target_root="${TARGET_ROOT:-$HOME}"
    local tmp=`mktemp -d`
    local rc=0
    get_patched_rc $shell_name > $tmp/shellrc
    get_patched_vimrc > $tmp/vimrc

    diff_deployed block "`get_shell_rc_path $shell_name`" $tmp/shellrc || rc=1
    diff_deployed block $target_root/.tmux.conf "${ENV_ROOT}/seeds/tmux.conf" || rc=1
    diff_deployed block $target_root/.vimrc $tmp/vimrc || rc=1
    diff_deployed block $target_root/.screenrc "${ENV_ROOT}/seeds/screenrc" || rc=1
    diff_deployed block $target_root/.config/nvim/init.vim "${ENV_ROOT}/seeds/nvimrc" || rc=1
    diff_deployed file $target_root/.hammerspoon/init.lua "${ENV_ROOT}/seeds/hammerspoon/init.lua" || rc=1
    diff_deployed file $target_root/.config/karabiner/karabiner.json "${ENV_ROOT}/seeds/karabiner/karabiner.json" || rc=1

    if [ "`uname`" = "Darwin" ]; then
        local changes=`get_scroll_reverser_changes`
        if [ "$changes" = "" ]; then
            echo "[same]    defaults com.pilotmoon.scroll-reverser"
        else
            echo "[differs] defaults com.pilotmoon.scroll-reverser (seed values below)"
            echo "$changes" | sed 's/^/  /'
            rc=1
        fi
    fi
    rm -rf $tmp
    return $rc
}

# Overwrite <seed> with <new> if they differ; <from> is only for the message
function write_seed() {
    local new=$1 seed=$2 from=$3
    if cmp -s "$new" "$seed"; then
        echo "[same]    $seed"
    else
        cat "$new" > "$seed"
        echo "[merged]  $seed <- $from"
    fi
}

# Replace the dotenv block inside <seed> with the one in <deployed>,
# keeping any seed lines before and after the block
function merge_env_block() {
    local deployed=$1 seed=$2
    if [ ! -f "$deployed" ]; then
        echo "[missing] $deployed"
        return
    fi
    local tmp=`mktemp -d`
    extract_env_block < "$deployed" > $tmp/block
    if [ ! -s $tmp/block ]; then
        echo "[not patched] $deployed"
        rm -rf $tmp
        return
    fi
    awk -v head="$ENV_BLOCK_HEAD" -v block=$tmp/block '
        state == 0 && index($0, head) { while ((getline l < block) > 0) print l; state = 1; next }
        state == 1 { if ($0 ~ /=(End|END)=/) state = 2; next }
        { print }
    ' "$seed" > $tmp/new
    write_seed $tmp/new "$seed" "$deployed"
    rm -rf $tmp
}

# Copy everything patch deployed back into seeds/ unconditionally;
# review with `git diff` in $ENV_ROOT and commit manually
function merge_rc_files() {
    if [ "$1" = "" ]; then
        echo "Usage: merge_rc_files <shell-name>"
        return 1
    fi
    local shell_name=$1
    local target_root="${TARGET_ROOT:-$HOME}"
    local tmp=`mktemp -d`

    # Shell rc block = head line + ENV_ROOT line + seed + end line
    local rc=`get_shell_rc_path $shell_name`
    extract_env_block < "$rc" 2> /dev/null > $tmp/shellrc
    if [ -s $tmp/shellrc ]; then
        sed '1,2d;$d' $tmp/shellrc > $tmp/shellseed
        write_seed $tmp/shellseed "${ENV_ROOT}/seeds/${shell_name}rc" "$rc"
    else
        echo "[not patched] $rc"
    fi

    merge_env_block $target_root/.tmux.conf "${ENV_ROOT}/seeds/tmux.conf"
    echo "[skip]    $target_root/.vimrc (generated by get_patched_vimrc in inc/patch.sh)"
    merge_env_block $target_root/.screenrc "${ENV_ROOT}/seeds/screenrc"
    merge_env_block $target_root/.config/nvim/init.vim "${ENV_ROOT}/seeds/nvimrc"

    local f
    for f in .hammerspoon/init.lua:hammerspoon/init.lua .config/karabiner/karabiner.json:karabiner/karabiner.json; do
        if [ -f "$target_root/${f%%:*}" ]; then
            write_seed "$target_root/${f%%:*}" "${ENV_ROOT}/seeds/${f#*:}" "$target_root/${f%%:*}"
        else
            echo "[missing] $target_root/${f%%:*}"
        fi
    done

    if [ "`uname`" = "Darwin" ]; then
        local domain=com.pilotmoon.scroll-reverser
        local seed="${ENV_ROOT}/seeds/scroll-reverser/defaults"
        local line key type value current
        while IFS= read -r line; do
            case "$line" in ''|\#*) echo "$line"; continue;; esac
            read -r key type value <<< "$line"
            current=`defaults read $domain $key 2> /dev/null`
            if [ "$type" = "-bool" ] && [ "$current" != "" ]; then
                [ "$current" = "1" ] && current=true || current=false
            fi
            echo "$key $type ${current:-$value}"
        done < "$seed" > $tmp/scroll
        write_seed $tmp/scroll "$seed" "defaults $domain"
    fi
    rm -rf $tmp

    echo ""
    git -C "$ENV_ROOT" status --short -- seeds
    echo "Review with: git -C $ENV_ROOT diff -- seeds   (then commit and push manually)"
}
