# dotenv

Opinionated dotfiles bootstrapper for bash/zsh/tcsh with Vim/Neovim, tmux, and optional macOS/Windows niceties.

## Highlights
- One command patches your shell rc, tmux, Vim/Neovim configs, and applies git defaults.
- Backups your shell rc before patching and keeps templates in `seeds/` so you can tweak them safely.
- Installs helper tooling for you: `vim-plug`, `tmux-tpm`, and `fzf` (plus helper for `nvm`).
- Curated aliases, prompts, history settings, and utilities live under `inc/` and `bin/`.
- Project virtualenv helpers use `.venv` by default: `venv.create`, `venv.activate`, and
  `venv.migrate` (which safely rebuilds a legacy `venv` directory as `.venv`).
- Cross-platform: Linux/macOS shell scripts and a PowerShell profile patcher for Windows.

## Quick start
1) Clone
```bash
git clone https://github.com/rightson/dotenv.git ~/.env
```
2) Patch, install, and configure (default)
```bash
bash ~/.env/dotenv          # patches rc files + installs tools + configures git/vim
```
   - Only patch rc files (no installs): `bash ~/.env/dotenv patch`
   - Compare what `patch` deployed with the current seeds: `bash ~/.env/dotenv diff` (exits 1 if anything differs)
   - Only install helper tools: `bash ~/.env/dotenv install`
   - Only apply git/vim defaults: `bash ~/.env/dotenv config`
   - Pull the latest version into an existing install: `bash ~/.env/dotenv update` (then open a new shell)
3) Reload your shell rc
`source ~/.bashrc` or `source ~/.zshrc` (tcsh uses `~/.cshrc`).

Windows PowerShell:
```powershell
powershell -File $HOME\.env\dotenv.ps1   # patches your PowerShell profile with aliases/prompt
powershell -File $HOME\.env\dotenv.ps1 update   # pull the latest version, then add new profile lines
powershell -File $HOME\.env\dotenv.ps1 config   # choose the editor for Claude Code's Ctrl+G
```

## What gets installed or patched
- **Shell rc (bash/zsh/tcsh)**: Adds an `.env` block from `seeds/*rc` with aliases, history, prompt, fzf helpers, and exports `ENV_ROOT`. Shell rc files are backed up with a timestamp before patching.
- **Tmux**: Appends `seeds/tmux.conf` once; includes TPM hooks and sensible defaults.
- **Vim / Neovim**: Sources configs from `vim/` plus local override files (`~/.vimrc.plug`, `~/.config/nvim/extra-plug.vim`) and wires in `vim-plug`.
- **Git defaults**: Sets `vimdiff` as the difftool, `vim` as core editor, and a long-lived credential cache.
- **Tools**: Installs `vim-plug`, `tmux-tpm`, and `fzf` automatically. Helpers for `nvm` and macOS text keybindings are available in `inc/install.sh`.
- **macOS extras**: Seeds for Hammerspoon and Karabiner are copied with timestamped backups (`.bak-YYYY-MM-DD-HH-MM-SS`) if files already exist. Scroll Reverser preferences from `seeds/scroll-reverser/defaults` are written with `defaults write`; the existing plist is exported to `~/Library/Preferences/com.pilotmoon.scroll-reverser.plist.bak-*` first.
- **Claude Code external editor**: `claude` is wrapped so only Claude Code's Ctrl+G uses `bin/cc-edit` (global `VISUAL`/`EDITOR` stay vim). Every draft is kept in `~/.claude-prompts/` and pruned after 730 days. See [Claude Code Ctrl+G editor](#claude-code-ctrlg-editor).
- **Windows extras**: PowerShell profile patcher imports git aliases and a prompt from `inc/`.

## Usage
- `bash ~/.env/dotenv patch|diff|update|install|config|config-git|config-vim|config-cc-edit`
  Run targeted steps instead of the full flow.
- `ENV_ROOT` points to the clone; templates live in `seeds/`, and functions live in `inc/`.
- Shell rc patching is idempotent; rerunning will skip already-patched files. For shell rc files, a `*.bak-<timestamp>` backup is created before changes.

## Claude Code Ctrl+G editor
`bin/cc-edit` (Windows: `bin\cc-edit.ps1`) is Claude Code's external editor. It copies the prompt into `~/.claude-prompts/`, opens the copy, waits until you are done, and copies it back. The editor is configurable; the default is `code` everywhere.

| Where | `editor` / `remote_editor` | How to return to Claude Code |
| --- | --- | --- |
| macOS | `code` (default), `textedit`, `macvim`, `vim` | VS Code: save, close the tab. TextEdit: save, quit with Cmd+Q. MacVim: `:wq`. |
| Linux | `code` (default), `gedit`, `vim` | Save, close the tab or window. gedit needs a display. |
| Windows | `code` (default), `notepad` | Save, close it. If Notepad returns early (Windows 11 tabs), press Enter in the terminal. |
| code-server, Remote-SSH, WSL terminal | `remote_editor`: `code` (default, a tab in that editor), `vim` | Close the tab. |

Change it with:
- `bash ~/.env/dotenv config-cc-edit` or `cc-edit --config` (interactive), `cc-edit --config editor=textedit remote_editor=vim`
- `powershell -File $HOME\.env\dotenv.ps1 config` or `cc-edit -Config` (interactive), `cc-edit -Config -Editor notepad`
- `cc-edit --show` / `cc-edit -Show` prints the settings and the editor the current terminal would use.

Settings live in `~/.config/cc-edit/config` (`editor=...`, `remote_editor=...`); `CC_EDIT_EDITOR` and `CC_EDIT_REMOTE_EDITOR` override them. An editor that cannot run (no VS Code CLI, gedit without a display) falls back to `$EDITOR` (or `vi`; on Windows, Notepad). Tests: `bash tests/test_cc_edit.sh`, `pwsh -File tests/test_cc_edit.ps1`.

## macOS Keyboard Shortcuts
The included Karabiner and Hammerspoon configurations provide powerful keyboard shortcuts for window management and productivity.

### Karabiner (System-level Key Remapping)
| Category | Shortcut | Action |
|----------|----------|--------|
| **Remapping** | **Cmd + Shift** | Switch input source (acts as Ctrl + Space when tapped alone) |
| **Remapping** | **fn + Ctrl + 1** | Remapped to Ctrl + Shift + Option + 1 (triggers Hammerspoon left 2/3 width layout) |
| **Remapping** | **fn + Ctrl + 2** | Remapped to Ctrl + Shift + Option + 2 (triggers Hammerspoon middle 2/3 width layout) |
| **Remapping** | **fn + Ctrl + 3** | Remapped to Ctrl + Shift + Option + 3 (triggers Hammerspoon right 2/3 width layout) |
| **Remapping** | **Page Down/Up** | Remapped to fn + Down/Up |
| **Remapping** | **Home/End** | Remapped to Cmd + Left/Right |

### Hammerspoon (Window Management & Utilities)
| Category | Shortcut | Action |
|----------|----------|--------|
| **Window: 1/3** | **Ctrl + Option + 1** | Position window at left 1/3 |
| **Window: 1/3** | **Ctrl + Option + 2** | Position window at middle 1/3 |
| **Window: 1/3** | **Ctrl + Option + 3** | Position window at right 1/3 |
| **Window: 2/3** | **Ctrl + Shift + Option + 1** | Position window at left 2/3 |
| **Window: 2/3** | **Ctrl + Shift + Option + 2** | Position window at middle 2/3 |
| **Window: 2/3** | **Ctrl + Shift + Option + 3** | Position window at right 2/3 |
| **Window: Half** | **Ctrl + Option + Left** | Position window at left half |
| **Window: Half** | **Ctrl + Option + Right** | Position window at right half |
| **Window: Center** | **Ctrl + Option + C** | Center window (70% size) |
| **Multi-Display** | **Ctrl + Option + Cmd + N** | Move window to next display |
| **Multi-Display** | **Ctrl + Option + Cmd + M** | Move window to next display and maximize |
| **Productivity** | **Ctrl + Option + D** | Open macOS Dictionary and lookup clipboard content |
| **Productivity** | **Ctrl + Option + G** | Open Google Translate with clipboard content (EN→ZH-TW) |

### Manual Setup (macOS)
To manually install Karabiner, Hammerspoon, and Scroll Reverser configurations:

```bash
# Source the patch functions first
source ~/.env/inc/patch.sh

# Copy Karabiner config (backs up existing file automatically)
patch_karabiner

# Copy Hammerspoon config (backs up existing file automatically)
patch_hammerspoon

# Apply Scroll Reverser preferences (restart Scroll Reverser afterwards)
patch_scroll_reverser
```

Existing configurations are backed up with timestamps before being replaced (e.g., `init.lua.bak-2025-12-21-10-30-45`).

**Note:** The functions must be sourced because `patch_karabiner` and `patch_hammerspoon` are bash functions defined in [inc/patch.sh](inc/patch.sh), not standalone executables.

## Customize & extend
- `dotenv diff` shows a unified diff (`seed` vs. local) for each deployed item: the dotenv block in shell rc, `.tmux.conf`, `.vimrc`, `.screenrc`, and nvim `init.vim`; the whole Hammerspoon and Karabiner files; and the Scroll Reverser keys on macOS. Copy local changes you want to keep back into `seeds/`.
- Edit the seed files in `seeds/` to change defaults for shells, tmux, Vim/Neovim, Hammerspoon, Karabiner, or Scroll Reverser.
- Add your own Vim/Neovim plugins in `~/.vimrc.plug` or `~/.config/nvim/extra-plug.vim` (these are created for you).
- Drop personal scripts into `bin/` and ensure it is on your `PATH` via the seeded rc files.

Enjoy :)!
