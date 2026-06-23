# Install

function install_vim_plug() {
    echo "Installing vim-plug"
    if [ ! -f ~/.vim/autoload/plug.vim ]; then
        curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
        echo "vim-plug installation completed"
    else
        echo "vim-plug alredy installed"
    fi
}

function install_tmux_tpm() {
    echo "Installing tmux-tpm"
    if [ ! -d ~/.tmux/plugins/tpm ]; then
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
        echo "tmux-tpm installation completed"
    else
        echo "tmux-tpm alredy installed"
    fi
}

function install_fzf() {
    echo "Installing fzf ..."
    if [ ! -f ~/.fzf/install ]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all
        echo "fzf installation completed"
    else
        echo "fzf already installed"
    fi
}

function install_nvm() {
    if [ -d ~/.nvm ]; then
        echo "nvm already installed"
        return
    fi
    if [ -n "`which curl 2> /dev/null`" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    else
        wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    fi
}

function install_vscode() {
    local os url file
    os="$(uname -s)"
    case "$os" in
        Linux)
            url="https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
            file="vscode-stable-amd64.deb"
            ;;
        Darwin)
            if [ "$(uname -m)" = "arm64" ]; then
                url="https://code.visualstudio.com/sha/download?build=stable&os=darwin-arm64-dmg"
            else
                url="https://code.visualstudio.com/sha/download?build=stable&os=darwin-dmg"
            fi
            file="vscode-stable.dmg"
            ;;
        *)
            echo "Unsupported OS: $os"
            return 1
            ;;
    esac

    rm -f "./$file"
    wget -O "$file" "$url" || { rm -f "./$file"; return 1; }

    case "$os" in
        Linux)
            sudo apt install -y "./$file"
            rm -f "./$file"
            ;;
        Darwin)
            hdiutil attach "./$file" -quiet
            cp -R "/Volumes/Visual Studio Code/Visual Studio Code.app" /Applications/
            hdiutil detach "/Volumes/Visual Studio Code" -quiet
            rm -f "./$file"
            ;;
    esac
}

function install_chrome_from_deb() {
    local file=google-chrome-stable_current_amd64.deb
    local url=https://dl.google.com/linux/direct/$file
    if [ -f ./$file ]; then
        rm -f ./$file
    fi
    wget $url
    if [ $? -eq 0 ]; then
        sudo apt install -y ./$file
        rm -f ./$file
    fi
}

function install_go() {
    set -x
    local tarball="https://go.dev/dl/go1.20.7.linux-amd64.tar.gz"
    local basename=`pwd`/`basename $tarball`
    if [ ! -f $basename ]; then
        wget $tarball
    fi
    local dest=$HOME/local/opt
    if [ ! -d $dst/go ]; then
        mkdir -p $dest
    else
        rm -rf $dst/go
    fi
    cd $dest
    tar zxf $basename
    rm $basename

    local bin=$HOME/local/bin
    cd $bin
    ln -fs ../opt/go/bin/go
    ln -fs ../opt/go/bin/gofmt
    set +x
}

# macOS Cocoa Text KeyBindings helper
function install_macos_kb_bind() {
  local kb_dir="$HOME/Library/KeyBindings"
  local kb_file="$kb_dir/DefaultKeyBinding.dict"
  local ts="$(date +%Y%m%d-%H%M%S)"
  local mode="${1:-homeend}"   # homeend | full
  local cmd="${2:-install}"    # install | show | uninstall

  # contents
  local content_homeend='{
    /* Home / End → beginning/end of line (adds mapping, does not override ⌘←/→) */
    "\UF729" = moveToBeginningOfLine:; // Home
    "\UF72B" = moveToEndOfLine:;       // End
  }'

  local content_full='{
    /* Home / End → beginning/end of line */
    "\UF729" = moveToBeginningOfLine:; // Home
    "\UF72B" = moveToEndOfLine:;       // End
    /* PageUp / PageDown → move cursor with page up/down */
    "\UF72C" = pageUp:;                // PageUp
    "\UF72D" = pageDown:;              // PageDown
  }'

  case "$cmd" in
    install)
      mkdir -p "$kb_dir" || { echo "❌ Cannot create directory: $kb_dir"; return 1; }
      if [ -f "$kb_file" ]; then
        cp "$kb_file" "$kb_file.bak-$ts" || { echo "❌ Backup failed"; return 1; }
        echo "🗂 Existing file backed up: $kb_file.bak-$ts"
      fi
      if [ "$mode" = "full" ]; then
        printf "%s\n" "$content_full" > "$kb_file"
        echo "✅ Installed (Home/End + PageUp/PageDown): $kb_file"
      else
        printf "%s\n" "$content_homeend" > "$kb_file"
        echo "✅ Installed (Home/End only): $kb_file"
      fi
      echo "ℹ️ Log out or restart apps for changes to take effect (Cocoa text system only)."
      ;;
    show)
      if [ -f "$kb_file" ]; then
        echo "📄 Current content: $kb_file"
        cat "$kb_file"
      else
        echo "ℹ️ Not installed (file does not exist): $kb_file"
      fi
      ;;
    uninstall)
      if [ -f "$kb_file" ]; then
        mv "$kb_file" "$kb_file.removed-$ts" && \
        echo "🧹 Removed, backup saved as: $kb_file.removed-$ts" || \
        { echo "❌ Failed to remove"; return 1; }
        echo "ℹ️ Log out or restart apps to restore default behavior."
      else
        echo "ℹ️ Nothing to remove (file does not exist)."
      fi
      ;;
    *)
      echo "Usage: install_macos_kb_bind [homeend|full] [install|show|uninstall]"
      echo "Examples:"
      echo "   install_macos_kb_bind                   # install Home/End only"
      echo "   install_macos_kb_bind full install       # install with PageUp/PageDown"
      echo "   install_macos_kb_bind show               # show current content"
      echo "   install_macos_kb_bind any uninstall      # remove configuration"
      ;;
  esac
}
