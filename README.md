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
   - Pull the latest version into an existing install: `bash ~/.env/dotenv update` pulls, then runs `patch` (then open a new shell)
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
- **Coding-agent external editor**: `claude` and `codex` are wrapped so only their Ctrl+G uses `bin/agent-edit` (global `VISUAL`/`EDITOR` stay vim). Every draft is kept in `~/.agent-prompts/` and pruned after 730 days. On macOS, `dotenv patch` installs TextMate, the default editor there. See [Coding-agent Ctrl+G editor](#coding-agent-ctrlg-editor).
- **Windows extras**: PowerShell profile patcher imports git aliases and a prompt from `inc/`.

## Usage
- `bash ~/.env/dotenv patch|diff|update|install|config|config-git|config-vim|config-visual`
  Run targeted steps instead of the full flow.
- `ENV_ROOT` points to the clone; templates live in `seeds/`, and functions live in `inc/`.
- Shell rc patching is idempotent; rerunning will skip already-patched files. For shell rc files, a `*.bak-<timestamp>` backup is created before changes.

## Coding-agent Ctrl+G editor
`bin/agent-edit` (Windows: `bin\agent-edit.ps1`) is the external editor for coding agents (Claude Code, Codex). The `claude` and `codex` wrappers set `VISUAL` to it for that one command. It copies the prompt into `~/.agent-prompts/`, opens the copy, waits until you are done, and copies it back. The first run moves an existing `~/.claude-prompts/` folder to `~/.agent-prompts/` (not when `AGENT_EDIT_DIR` is set).

| Where | `editor` / `remote_editor` | How to return to the agent |
| --- | --- | --- |
| macOS | `textmate` (default), `subl`, `code`, `macvim`, `vim` | TextMate: save, close the window. Sublime Text, VS Code: save, close the tab. MacVim: `:wq`. |
| Linux | `gedit` (default), `subl`, `code`, `gvim`, `vim` | Save, close the window or tab. gVim: `:wq`. GUI editors need a display. |
| Windows | `notepad` (default), `code` | Save, close it. If Notepad returns early (Windows 11 tabs), press Enter in the terminal. |
| code-server, Remote-SSH, WSL terminal | `remote_editor`: `code` (default, a tab in that editor), `vim` | Close the tab. |

On macOS and Linux the editors form a fallback chain: the configured `editor` is tried first, then the others in the order of the table, ending with vim in the terminal (`editor=code` on Linux gives code, gedit, subl, gvim, vim). An editor is passed over, with one line in the terminal that says why, when it is not installed, when it is a GUI editor without a display (Linux) or in an SSH session (macOS), or when it exits with a non-zero status, such as a crash. Every editor opens the same draft, so text saved before a crash is kept. vim ends the chain: a non-zero exit from it (`:cq`) cancels the edit, and `$EDITOR` (or `vi`) is used only when vim is not installed. A VS Code server that is no longer reachable from a stale terminal falls back to vim.

`dotenv patch` on macOS downloads TextMate to `/Applications` (or `~/Applications` when that is not writable) unless it is already installed. Offline, patch continues and agent-edit uses the next editor of the chain until TextMate is installed. A custom `--target-root` installs nothing.

Change the editor with:
- `bash ~/.env/dotenv config-visual` or `agent-edit --config` (interactive), `agent-edit --config editor=code remote_editor=vim`
- `powershell -File $HOME\.env\dotenv.ps1 config-visual` or `agent-edit -Config` (interactive), `agent-edit -Config -Editor code`
- `agent-edit --show` / `agent-edit -Show` prints the settings and the editor the current terminal would use.

Settings live in `~/.config/agent-edit/config` (`editor=...`, `remote_editor=...`); `AGENT_EDIT_EDITOR` and `AGENT_EDIT_REMOTE_EDITOR` override them. Other overrides: `AGENT_EDIT_CONFIG` (config file), `AGENT_EDIT_DIR` (drafts folder), `AGENT_EDIT_PROFILE` (VS Code profile, default `scratch`), `AGENT_EDIT_KEEP` (retention in days, default 730). On Windows, an editor that cannot run falls back to Notepad with a notice. Tests: `bash tests/test_agent_edit.sh`, `bash tests/test_install_textmate.sh`, `pwsh -File tests/test_agent_edit.ps1`.

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
- `hostname-forensics.sh [2d]` (macOS): shows when and by which process the LocalHostName/ComputerName changed, plus the Bonjour name-conflict evidence and sleep proxies behind it.

Enjoy :)!
