# Updating This Fork From Upstream Omarchy

This fork tracks stable Omarchy while preserving the local CachyOS/KDE/GRUB
compatibility policy. Use this document when updating `cachyos/main` from
upstream Omarchy.

## Current Model

This repository is the active Omarchy source for the machine:

```text
$HOME/.local/share/omarchy -> $HOME/dev/github/omarchy-cachyos
```

That means changing this checkout changes the source used by Omarchy commands.
Updating the Git branch is not the same thing as running the installer or
applying system-level changes.

Branch model:

- `cachyos/main`: the maintained downstream branch. Keep this as the default
  branch for the fork.
- `upstream/master`: stable Omarchy from `basecamp/omarchy`.
- `upgrade/upstream-master-YYYY-MM-DD`: temporary integration branch for a
  specific upstream update.
- `dev`: historical branch. Do not use it for new stable updates unless the
  human explicitly asks for it.

Remote model:

```bash
git remote -v
```

Expected:

```text
origin    git@github.com:erikamello/omarchy-cachyos.git (fetch)
origin    git@github.com:erikamello/omarchy-cachyos.git (push)
upstream  git@github.com:basecamp/omarchy.git (fetch)
upstream  DISABLED (push)
```

If `upstream` is missing:

```bash
git remote add upstream git@github.com:basecamp/omarchy.git
git remote set-url --push upstream DISABLED
```

## Downstream Policy

Preserve these decisions unless the human explicitly changes direction:

- Keep CachyOS as the OS base.
- Keep KDE/SDDM compatibility.
- Keep GRUB compatibility.
- Do not install or configure Limine on this system.
- Do not install or configure Plymouth on this system.
- Do not overwrite CachyOS pacman configuration from Omarchy install scripts.
- Prefer CachyOS kernel-bound NVIDIA packages when NVIDIA logic is touched.
- Keep personal paths out of committed files. Use `$HOME`, `~`, or repo-relative
  paths in committed code and documentation.
- Keep `tldr` out of the base package list because `tealdeer` satisfies that
  command on this system.

## Files That Usually Carry The Local Delta

After a clean upstream merge, the downstream diff should stay small. As of the
last successful update, the expected local policy files were:

```text
bin/omarchy-update-restart
config/uwsm/env
install/config/hardware/nvidia.sh
install/config/mimetypes.sh
install/config/omarchy-ai-skill.sh
install/login/all.sh
install/omarchy-base.packages
install/post-install/all.sh
install/preflight/all.sh
migrations/1766942230.sh
migrations/1768906440.sh
```

The list can change over time, but if a future merge creates a much larger
downstream delta, inspect it before committing. Large drift usually means the
merge accidentally preserved old downstream code where upstream should have won,
or it reintroduced machine-local patching.

## Update Procedure

Start from a clean `cachyos/main` checkout:

```bash
cd "$HOME/dev/github/omarchy-cachyos"
git status --short --branch
git switch cachyos/main
git pull --ff-only origin cachyos/main
git fetch upstream --prune
git fetch origin --prune
```

Record the upstream target:

```bash
git log --oneline --decorate -n 5 upstream/master
cat version
```

Create an isolated integration branch. A worktree is preferred because this
checkout is live under `$HOME/.local/share/omarchy`.

```bash
update_date="$(date +%F)"
branch="upgrade/upstream-master-$update_date"
worktree="$HOME/.config/superpowers/worktrees/omarchy-cachyos/upstream-master-$update_date"

git worktree add -b "$branch" "$worktree" cachyos/main
cd "$worktree"
git merge --no-ff --no-commit upstream/master
```

If there are no conflicts, still inspect the staged merge before committing. If
there are conflicts, resolve them by preserving the current downstream policy
and taking upstream improvements everywhere else.

Useful inspection commands:

```bash
git status --short
git diff --name-only --diff-filter=U
git diff --stat
git diff --check
git diff upstream/master...HEAD --name-only
```

## Known Conflict Patterns

### `bin/omarchy-update-restart`

Preserve CachyOS kernel detection while keeping upstream's generic new-kernel
restart check.

The downstream behavior should be:

- If `linux-cachyos` is installed, compare the installed package version with
  `uname -r`.
- If CachyOS kernel package detection is unavailable, fall back to upstream's
  `/usr/lib/modules/*/vmlinuz` mtime check.

This prevents false restart prompts on the CachyOS kernel package layout while
keeping upstream behavior for other kernels.

### `config/uwsm/env`

Keep upstream path handling and keep Fish support.

Expected properties:

- `PATH` includes `$HOME/.local/bin`.
- Bash shims are exported with `mise activate bash --shims`.
- Fish shims are supported with `mise activate fish --shims | source`.
- No hard-coded personal path appears in the file.

### `install/post-install/all.sh`

Do not run Omarchy's pacman post-install config on this machine. The CachyOS
pacman configuration owns repositories, hooks, and package manager defaults.

Expected property:

```bash
! grep -q 'post-install/pacman.sh' install/post-install/all.sh
```

### `install/preflight/all.sh`

Do not run Omarchy's pacman preflight setup on this machine.

Expected property:

```bash
! grep -q 'preflight/pacman.sh' install/preflight/all.sh
```

### `install/login/all.sh`

Do not enable Limine or Plymouth here.

Expected properties:

```bash
! grep -E 'limine|plymouth' install/login/all.sh
```

### `install/omarchy-base.packages`

Do not reintroduce `tldr`.

Expected property:

```bash
! grep -qx 'tldr' install/omarchy-base.packages
```

### Migrations

Do not add migrations that remove CachyOS NVIDIA package variants unless the
human explicitly requests that behavior. This system may use packages such as:

```text
linux-cachyos-nvidia-open
linux-cachyos-lts-nvidia-open
```

## Required Verification

Run these checks in the integration worktree before committing.

Basic Git and formatting checks:

```bash
git status --short --branch
git diff --check
```

Policy checks:

```bash
! rg -n -P "\\x2fhome\\x2f${USER}(?=/|$)|\\x2fUsers\\x2f${USER}(?=/|$)" .
! grep -qx 'tldr' install/omarchy-base.packages
! grep -q 'preflight/pacman.sh' install/preflight/all.sh
! grep -q 'post-install/pacman.sh' install/post-install/all.sh
! grep -E 'limine|plymouth' install/login/all.sh
grep -q 'linux-cachyos' bin/omarchy-update-restart
grep -q 'find /usr/lib/modules' bin/omarchy-update-restart
grep -q '\$HOME/.local/bin' config/uwsm/env
grep -q 'mise activate bash --shims' config/uwsm/env
grep -q 'mise activate fish --shims' config/uwsm/env
```

Shell syntax check for changed shell files:

```bash
git diff --name-only upstream/master...HEAD |
  while IFS= read -r file; do
    [[ -f $file ]] || continue
    if [[ $file == *.sh ]] || head -n 1 "$file" | grep -qE '^#!.*\b(bash|sh)\b'; then
      bash -n "$file" || exit 1
    fi
  done
```

Review downstream delta:

```bash
git diff --name-only upstream/master...HEAD
```

The output should be explainable as CachyOS policy. If unrelated files appear,
inspect them before committing.

## Commit And Push

Commit the merge from the integration worktree:

```bash
git status --short
git commit -m "merge: update Omarchy stable to <version>"
git push -u origin "$branch"
```

Then fast-forward the live checkout:

```bash
cd "$HOME/dev/github/omarchy-cachyos"
git switch cachyos/main
git pull --ff-only origin cachyos/main
git merge --ff-only "$branch"
git push origin cachyos/main
```

If the integration branch was pushed first and another checkout needs to use the
remote ref:

```bash
git merge --ff-only "origin/$branch"
git push origin cachyos/main
```

Do not run the Omarchy installer as part of this repository update. That is a
separate operational step and should be planned explicitly.

## Final Verification In The Live Checkout

After fast-forwarding `cachyos/main`, repeat the important checks in
`$HOME/dev/github/omarchy-cachyos`:

```bash
git status --short --branch
cat version
git log --oneline --decorate -n 8
git diff --check HEAD

! rg -n -P "\\x2fhome\\x2f${USER}(?=/|$)|\\x2fUsers\\x2f${USER}(?=/|$)" .
! grep -qx 'tldr' install/omarchy-base.packages
! grep -q 'preflight/pacman.sh' install/preflight/all.sh
! grep -q 'post-install/pacman.sh' install/post-install/all.sh
! grep -E 'limine|plymouth' install/login/all.sh
grep -q 'linux-cachyos' bin/omarchy-update-restart
grep -q 'find /usr/lib/modules' bin/omarchy-update-restart
grep -q '\$HOME/.local/bin' config/uwsm/env
grep -q 'mise activate bash --shims' config/uwsm/env
grep -q 'mise activate fish --shims' config/uwsm/env
```

If all checks pass, report:

- upstream commit merged,
- upstream Omarchy version,
- merge commit,
- branches pushed,
- whether the live checkout is clean,
- confirmation that no installer/system update was run.

## Cleanup

After the human confirms the update is good, remove the temporary worktree and
optionally delete the temporary branch:

```bash
git worktree remove "$HOME/.config/superpowers/worktrees/omarchy-cachyos/upstream-master-YYYY-MM-DD"
git branch -d "upgrade/upstream-master-YYYY-MM-DD"
git push origin --delete "upgrade/upstream-master-YYYY-MM-DD"
```

Keep the temporary branch if the human wants a durable review branch for the
specific upstream update.

## Last Successful Run

The last known-good update used this method:

```text
Downstream branch: cachyos/main
Upstream branch: upstream/master
Upstream version: 3.6.0
Upstream commit: 4127c749fb633f363151a77f732c27d58f86bd42
Merge commit: 71d848b14cff2bfd7b998b9bc953556d34125407
Integration branch: upgrade/upstream-master-2026-04-25
```

Conflicts resolved during that run:

```text
bin/omarchy-update-restart
config/uwsm/env
```

One non-conflict policy adjustment was also required:

```text
install/post-install/all.sh
```
