alias git.pull='git pull'
alias git.pull.origin.branch='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias git.pull.origin.branch.rebase='git pull origin $(git rev-parse --abbrev-ref HEAD) --rebase'
alias git.push='git push'
alias git.push.origin.branch='git push origin $(git rev-parse --abbrev-ref HEAD)'
alias git.push.origin.branch.tags='git push origin $(git rev-parse --abbrev-ref HEAD) --tags'
alias git.status='git status -v'
alias git.checkout='git checkout'
alias git.commit='git commit'
alias git.commit.message='git commit -m'
alias git.commit.amend='git commit --amend'

alias g='git'

alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gau='git add -u'

alias gaus='git add -u; git status'
alias gauw='git add -u; git diff --word-diff --cached; git status'
alias gauv='git add -u; git vimdiff --word-diff --cached; git status'

alias gbc='git rev-parse --abbrev-ref HEAD'

alias gb='git branch'
alias gba='git branch -a'
alias gbda='git branch --merged | command grep -vE "^(\*|\s*master\s*$)" | command xargs -n 1 git branch -d'
alias gbl='git blame -b -w'
alias gbnm='git branch --no-merged'
alias gbr='git branch --remote'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsr='git bisect reset'
alias gbss='git bisect start'

alias gc='git commit -v'
alias gc!='git commit -v --amend'
alias gca='git commit -v -a'
alias gca!='git commit -v -a --amend'
alias gcan!='git commit -v -a -s --no-edit --amend'
alias gcam='git commit -a -m'
alias gcb='git checkout -b'
alias gcf='git config --list'
alias gcl='git clone --recursive'
alias gclean='git clean -fd'
alias gpristine='git reset --hard && git clean -dfx'
alias gcm='git checkout master'
alias gcmsg='git commit -m'
alias gco='git checkout'
alias gcount='git shortlog -sn'
alias gcp='git cherry-pick'
alias gcs='git commit -S'

alias gd='git diff'
alias gd.vim='git vimdiff'
alias gd.np='git --no-pager diff'
alias gd.wd='git diff --word-diff'
alias gdca='git diff --cached'
alias gdca.vim='git vimdiff --cached'
alias gdca.np='git --no-pager diff --cached'
alias gdca.wd='git diff --word-diff --cached'
alias gdct='git describe --tags `git rev-list --tags --max-count=1`'
alias gdt='git diff-tree --no-commit-id --name-only -r'
gdv() {
    git diff -w "$@" | view -
}
alias gdw='git diff --word-diff'

 alias gf='git fetch'
 alias gfa='git fetch --all --prune'
function gfg() {
    git ls-files | grep $@
}
alias gfo='git fetch origin'

alias gg='git gui citool'
alias gga='git gui citool --amend'
ggf() {
    [[ "$#" != 1 ]] && local b="$(git_current_branch)"
    git push --force origin "${b:=$1}"
}
ggl() {
if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]; then
git pull origin "${*}"
else
[[ "$#" == 0 ]] && local b="$(git_current_branch)"
git pull origin "${b:=$1}"
fi
}
alias ggpull='git pull origin $(git_current_branch)'
ggp() {
    if [[ "$#" != 0 ]] && [[ "$#" != 1 ]]; then
    git push origin "${*}"
else
    [[ "$#" == 0 ]] && local b="$(git_current_branch)"
    git push origin "${b:=$1}"
fi
}
alias ggpush='git push origin $(git_current_branch)'
ggpnp() {
    if [[ "$#" == 0 ]]; then
    ggl && ggp
else
    ggl "${*}" && ggp "${*}"
fi
}
alias ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
ggu() {
    [[ "$#" != 1 ]] && local b="$(git_current_branch)"
    git pull --rebase origin "${b:=$1 }"
}
alias ggpur='ggu'

alias gignore='git update-index --assume-unchanged'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
alias git-svn-dcommit-push='git svn dcommit && git push github master:svntrunk'

alias gk='\gitk --all --branches'
alias gke='\gitk --all $(git log -g --pretty=format:%h)'

alias gl='git pull'
alias glob='git pull origin $(git rev-parse --abbrev-ref HEAD)'
alias globr='git pull origin $(git rev-parse --abbrev-ref HEAD) --rebase'
alias glg='git log --stat --color'
alias glgp='git log --stat --color -p'
alias glgg='git log --graph --color'
alias glgga='git log --graph --decorate --all'
alias glgm='git log --graph --max-count=10'
alias glo='git log --oneline --decorate --color'
alias glol="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias glola="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all"
alias glog='git log --oneline --decorate --color --graph'
alias glp="_git_log_prettily"

alias gm='git merge'
gmb() {
  # Usage: gmb [--rebase] <target_branch>
  local r= t=
  [[ $1 == --rebase ]] && r=--rebase && shift
  t="$1"
  [[ -n $t && $t != -h && $t != --help ]] || { echo "Usage: gmb [--rebase] <target_branch>"; return 2; }

  git rev-parse --git-dir >/dev/null 2>&1 || { echo "Not a git repo."; return 2; }
  git diff --quiet && git diff --cached --quiet || { echo "Working tree not clean."; return 2; }

  local src; src="$(git branch --show-current)"
  [[ -n $src ]] || { echo "Detached HEAD."; return 2; }
  [[ $src != "$t" ]] || { echo "Target equals current."; return 2; }

  git show-ref --verify --quiet "refs/heads/$t" || git fetch origin "$t:$t" || { echo "No branch '$t'."; return 2; }

  git checkout "$t" || return
  [[ -n $r ]] && git pull --rebase || git pull
  git merge --no-ff "$src" || { echo "Resolve conflicts, then: git merge --continue  (or --abort)"; return 1; }
}
alias gmnf='git merge --no-ff'
alias gmom='git merge origin/master'
alias gmt='git mergetool --no-prompt'
alias gmtvim='git mergetool --no-prompt --tool=vimdiff'
alias gmum='git merge upstream/master'

alias gp='git push'
alias gpd='git push --dry-run'
alias gpoat='git push origin --all && git push origin --tags'
alias gpob='git push origin $(git rev-parse --abbrev-ref HEAD)'
alias gpobt='git push origin $(git rev-parse --abbrev-ref HEAD) --tags'
alias gpu='git push upstream'
alias gpv='git push -v'

alias gr='git remote'
alias gra='git remote add'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase -i'
alias grbm='git rebase master'
alias grbs='git rebase --skip'
alias grh='git reset HEAD'
alias grhh='git reset HEAD --hard'
alias grmv='git remote rename'
alias grrm='git remote remove'
alias grset='git remote set-url'
alias grt='cd $(git rev-parse --show-toplevel || echo ".")'
alias gru='git reset --'
alias grup='git remote update'
alias grv='git remote -v'

alias gsb='git status -sb'
alias gsd='git svn dcommit'
alias gsi='git submodule init'
alias gsps='git show --pretty=short --show-signature'
alias gsr='git svn rebase'
alias gss='git status -s'
alias gst='git status'
alias gsta='git stash'
alias gstaa='git stash apply'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash show --text'
alias gsu='git submodule update'

alias gts='git tag -s'
alias gtt='git tag | sort -V | tail'
alias gtv='git tag | sort -V'

alias gunignore='git update-index --no-assume-unchanged'
alias gunwip='git log -n 1 | grep -q -c "\-\-wip\-\-" && git reset HEAD~1'
alias gup='git pull --rebase'
alias gupv='git pull --rebase -v'
alias glum='git pull upstream master'

gwd() {
  # Go back to the worktree that has the repo's default branch checked out.
  local def path
  def="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
  def="${def#origin/}"
  [[ -n $def ]] || def="$(git config --get init.defaultBranch)"
  [[ -n $def ]] || { git show-ref --verify --quiet refs/heads/main && def=main || def=master; }
  path="$(git worktree list --porcelain | awk -v b="refs/heads/$def" '
    /^worktree /{p=substr($0,10)}
    $0=="branch "b{print p; exit}')"
  [[ -n $path ]] || { echo "No worktree on default branch '$def'."; return 1; }
  cd "$path"
}

alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'
alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit -m "--wip--"'

