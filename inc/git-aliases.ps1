function git.pull { git pull $args }
function git.pull.origin.branch { git pull origin (git rev-parse --abbrev-ref HEAD) }
function git.pull.origin.branch.rebase { git pull origin (git rev-parse --abbrev-ref HEAD) --rebase $args }
function git.push { git push $args }
function git.push.origin.branch { git push origin (git rev-parse --abbrev-ref HEAD) }
function git.push.origin.branch.tags { git push origin (git rev-parse --abbrev-ref HEAD) --tags $args }
function git.status { git status -v $args }
function git.checkout { git checkout $args }
function git.commit { git commit $args }
function git.commit.message { param($message) git commit -m $message $args }
function git.commit.amend { git commit --amend $args }
function g { git $args }
function ga { git add $args }
function gaa { git add --all $args }
function gapa { git add --patch $args }
function gau { git add -u $args }
function gaus { git add -u; git status $args }
function gauw { git add -u; git diff --word-diff --cached; git status $args }
function gauv { git add -u; git diff --word-diff --cached; git status $args }
function gbc { git rev-parse --abbrev-ref HEAD $args }
function gb { git branch $args }
function gba { git branch -a $args }
function gbda { git branch --merged | Where-Object { $_ -notmatch '^\*|\s*master\s*$' } | ForEach-Object { git branch -d $_.Trim() } }
function gbl { git blame -b -w $args }
function gbnm { git branch --no-merged $args }
function gbr { git branch --remote $args }
function gbs { git bisect $args }
function gbsb { git bisect bad $args }
function gbsg { git bisect good $args }
function gbsr { git bisect reset $args }
function gbss { git bisect start $args }
function gc { git commit -v $args }
function gca { git commit -v -a $args }
function gca! { git commit -v -a --amend $args }
function gcan! { git commit -v -a -s --no-edit --amend $args }
function gcam { param($message) git commit -a -m $message $args }
function gcb { param($branch) git checkout -b $branch $args }
function gcf { git config --list $args }
function gcl { git clone --recursive $args }
function gclean { git clean -fd $args }
function gpristine { git reset --hard; git clean -dfx $args }
function gcm { git checkout master $args }
function gcmsg { param($message) git commit -m $message $args }
function gco { git checkout $args }
function gcount { git shortlog -sn $args }
function gcp { git cherry-pick $args }
function gcs { git commit -S $args }
function gd { git diff $args }
function gd.vim { git diff $args }
function gd.np { git --no-pager diff $args }
function gd.wd { git diff --word-diff $args }
function gdca { git diff --cached $args }
function gdca.vim { git diff --cached $args }
function gdca.np { git --no-pager diff --cached $args }
function gdca.wd { git diff --word-diff --cached $args }
function gdct { git describe --tags (git rev-list --tags --max-count=1) }
function gdt { git diff-tree --no-commit-id --name-only -r $args }
function gdv { git diff -w $args | vim - }
function gdw { git diff --word-diff $args }
function gf { git fetch $args }
function gfa { git fetch --all --prune $args }
function gfg { param($pattern) git ls-files | Select-String $pattern $args }
function gfo { git fetch origin $args }
function glob { git pull origin $(git rev-parse --abbrev-ref HEAD) }
function gp { git push $args }
function gpd { git push --dry-run $args }
function gpoat { git push origin --all; git push origin --tags $args }
function gpob { git push origin (git rev-parse --abbrev-ref HEAD) }
function gpobt { git push origin (git rev-parse --abbrev-ref HEAD) --tags $args }
function gpu { git push upstream $args }
function gpv { git push -v $args }
function gr { git remote $args }
function gra { git remote add $args }
function grb { git rebase $args }
function grba { git rebase --abort $args }
function grbc { git rebase --continue $args }
function grbi { git rebase -i $args }
function grbm { git rebase master $args }
function grbs { git rebase --skip $args }
function grh { git reset HEAD $args }
function grhh { git reset HEAD --hard $args }
function grmv { git remote rename $args }
function grrm { git remote remove $args }
function grset { git remote set-url $args }
function grt { Set-Location (git rev-parse --show-toplevel) }
function gru { git reset --}
function grup { git remote update $args }
function grv { git remote -v $args }
function gsb { git status -sb $args }
function gsd { git svn dcommit $args }
function gsi { git submodule init $args }
function gsps { git show --pretty=short --show-signature $args }
function gsr { git svn rebase $args }
function gss { git status -s $args }
function gst { git status $args }
function gsta { git stash $args }
function gstaa { git stash apply $args }
function gstd { git stash drop $args }
function gstl { git stash list $args }
function gstp { git stash pop $args }
function gsts { git stash show --text $args }
function gsu { git submodule update $args }
function gts { git tag -s $args }
function gtt { git tag | Select-Object -Last 1 $args }
function gtv { git tag | Sort-Object -Property @{Expression={[Version]$_}} }
function gunignore { git update-index --no-assume-unchanged }
function gunwip {
    $lastCommit = git log -n 1 | Select-String -Pattern "\-\-wip\-\-"
    if ($lastCommit) {
        git reset HEAD~1
    }
}
function gup { git pull --rebase $args }
function gupv { git pull --rebase -v $args }
function glum { git pull upstream master $args }
function gwch { git whatchanged -p --abbrev-commit --pretty=medium $args }
function gwip {
    git add -A
    git ls-files --deleted -z | ForEach-Object { git rm $_ $args }
    git commit -m "--wip--"
}
function Get-GitStatus { git status $args }
function Get-GitLog { git log $args }
function Get-GitBranch { git branch $args }
function Switch-GitBranch { param($branch) git checkout $branch $args }
function New-GitBranch { param($branch) git checkout -b $branch $args }
function Remove-GitBranch { param($branch) git branch -d $branch $args }
function Merge-GitBranch { param($branch) git merge $branch $args }
function Push-GitBranch { param($branch) git push origin $branch $args }
function Pull-GitBranch { param($branch) git pull origin $branch $args }
function git_log_pretty {
    git log --graph --pretty='format:%C(red)%h%C(reset) %C(yellow)%d%C(reset) %C(white)%s%C(reset) %C(green)(%cr)%C(reset) %C(bold blue)[%an]%C(reset)' --abbrev-commit --date=relative
}
function glp { git_log_pretty $args }
function git_current_branch { git rev-parse --abbrev-ref HEAD $args }
function gpc {
    $branch = git_current_branch
    git push origin $branch
}
function gplc {
    $branch = git_current_branch
    git pull origin $branch
}
function gfp { git fetch --all --prune $args }
function gir {
    param($commit = "master")
    git rebase -i $commit
}
function gdp { git diff HEAD^ }
function gsl { git show --name-only $args }
function gcm {
    param($message)
    git commit -m $message
}
function gac {
    param($message)
    git add -A
    git commit -m $message
}
function gacp {
    param($message)
    git add -A
    git commit -m $message
    $branch = git_current_branch
    git push origin $branch
}
function gundo { git reset HEAD~1 --soft $args }
function grh {
    param($branch = (git_current_branch))
    git fetch origin
    git reset --hard origin/$branch
}
function gclean { git clean -fd $args }
function gstm {
    param($message)
    git stash push -m $message
}
function gstal { git stash apply $args }
function gstpl { git stash pop $args }
function gcpa { git cherry-pick --abort $args }
function gcpc { git cherry-pick --continue $args }
function grba { git rebase --abort $args }
function grbc { git rebase --continue $args }
function gma { git merge --abort $args }
function gmc { git merge --continue $args }

# --- worktree helpers / aliases (mirror inc/git-aliases.sh) ---

function _git_default_branch {
    # Best-effort name of the repo's default branch (no "origin/" prefix).
    $def = (git symbolic-ref --short refs/remotes/origin/HEAD 2>$null)
    if ($def) { $def = $def -replace '^origin/', '' }
    if (-not $def) { $def = (git config --get init.defaultBranch) }
    if (-not $def) {
        git show-ref --verify --quiet refs/heads/main
        if ($LASTEXITCODE -eq 0) { $def = 'main' } else { $def = 'master' }
    }
    return $def
}

function _git_default_ref {
    # Resolve the local ref to compare against (default branch), falling back to
    # the remote-tracking ref when there is no local branch for it.
    param($def)
    git show-ref --verify --quiet "refs/heads/$def"
    if ($LASTEXITCODE -eq 0) { return "refs/heads/$def" } else { return "refs/remotes/origin/$def" }
}

function gwl { git worktree list $args }

function gwls {
    # git worktree list, but the path column is shown relative to CWD (shorter).
    $entries = @()
    $path = $null; $sha = ''; $ref = ''
    foreach ($line in (git worktree list --porcelain)) {
        if ($line -like 'worktree *') {
            if ($path) { $entries += [pscustomobject]@{ Path = $path; Sha = $sha; Ref = $ref } }
            $path = $line.Substring(9); $sha = ''; $ref = ''
        }
        elseif ($line -like 'HEAD *') { $sha = $line.Substring(5, 7) }
        elseif ($line -like 'branch *') { $ref = '[' + ($line.Substring(7) -replace '^refs/heads/', '') + ']' }
        elseif ($line -eq 'detached') { $ref = '(detached HEAD)' }
        elseif ($line -eq 'bare') { $ref = '(bare)' }
    }
    if ($path) { $entries += [pscustomobject]@{ Path = $path; Sha = $sha; Ref = $ref } }

    $rel = foreach ($e in $entries) {
        $r = Resolve-Path -LiteralPath $e.Path -Relative -ErrorAction SilentlyContinue
        if (-not $r) { $r = $e.Path }
        [pscustomobject]@{ Path = "$r"; Sha = $e.Sha; Ref = $e.Ref }
    }
    $w = ($rel | ForEach-Object { $_.Path.Length } | Measure-Object -Maximum).Maximum
    foreach ($e in $rel) { '{0}  {1}  {2}' -f $e.Path.PadRight($w), $e.Sha, $e.Ref }
}

function gwd {
    # Go back to the worktree that has the repo's default branch checked out.
    $def = _git_default_branch
    $path = $null; $p = $null
    foreach ($line in (git worktree list --porcelain)) {
        if ($line -like 'worktree *') { $p = $line.Substring(9) }
        elseif ($line -eq "branch refs/heads/$def") { $path = $p; break }
    }
    if (-not $path) { Write-Error "No worktree on $def"; return }
    Set-Location $path
}

function gwlmerged {
    # List worktrees whose branch is already merged into the default branch.
    # `git worktree prune` never removes these (their directories still exist),
    # so they are the manual-cleanup candidates. Run `gfp` first for accuracy.
    $def = _git_default_branch
    $ref = _git_default_ref $def
    $p = $null
    foreach ($line in (git worktree list --porcelain)) {
        if ($line -like 'worktree *') { $p = $line.Substring(9) }
        elseif ($line -like 'branch *') {
            $br = $line.Substring(7) -replace '^refs/heads/', ''
            if ($br -eq $def) { continue }
            git merge-base --is-ancestor "refs/heads/$br" $ref 2>$null
            if ($LASTEXITCODE -eq 0) { '{0}  [{1}]' -f $p.PadRight(50), $br }
        }
    }
}

function gwlgone {
    # List worktrees whose upstream branch was deleted on the remote ([gone]).
    # Run `gfp` (git fetch --all --prune) first so the tracking info is current.
    $p = $null
    foreach ($line in (git worktree list --porcelain)) {
        if ($line -like 'worktree *') { $p = $line.Substring(9) }
        elseif ($line -like 'branch *') {
            $br = $line.Substring(7) -replace '^refs/heads/', ''
            $up = git for-each-ref --format='%(upstream:track)' "refs/heads/$br" 2>$null
            if ($up -eq '[gone]') { '{0}  [{1}]' -f $p.PadRight(50), $br }
        }
    }
}

function gwa {
    # Add a worktree for BRANCH alongside the repo root (../<branch>).
    # Checks out an existing branch, or creates it off the default branch.
    param($br)
    if (-not $br) { Write-Host 'Usage: gwa <branch>'; return }
    $root = git rev-parse --show-toplevel
    if (-not $root) { return }
    $dest = Join-Path (Split-Path $root -Parent) $br
    git show-ref --verify --quiet "refs/heads/$br"
    if ($LASTEXITCODE -eq 0) { git worktree add $dest $br }
    else { git worktree add -b $br $dest (_git_default_branch) }
}

function gwb {
    # Create a worktree on a NEW branch off the default branch.
    param($br)
    if (-not $br) { Write-Host 'Usage: gwb <new-branch>'; return }
    $root = git rev-parse --show-toplevel
    if (-not $root) { return }
    git worktree add -b $br (Join-Path (Split-Path $root -Parent) $br) (_git_default_branch)
}

function gwrm {
    # Remove the current (or named) worktree, then cd back to the default one.
    param($dir = $PWD.Path)
    $target = git -C $dir rev-parse --show-toplevel 2>$null
    if (-not $target) { Write-Error "Not a worktree: $dir"; return }
    $main = $null
    foreach ($line in (git worktree list --porcelain)) {
        if ($line -like 'worktree *') { $main = $line.Substring(9); break }
    }
    if ($target -eq $main) { Write-Error 'Refusing to remove the main worktree.'; return }
    gwd 2>$null
    git worktree remove $target
}

function gwprune { git worktree prune -v $args }
function gwlock { git worktree lock $args }
function gwunlock { git worktree unlock $args }
