#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Run inside a disposable container or as the VM's unprivileged user.
set -eu
task_dir=$(mktemp -d)
trap 'rm -rf "$task_dir"' EXIT HUP INT TERM
git init -q --bare "$task_dir/origin"
git init -q "$task_dir/work"
cd "$task_dir/work"
git config user.name 'Image smoke test'
git config user.email 'image-test@example.invalid'
git config commit.gpgsign false
printf 'one\n' > sample.txt
git add sample.txt
git commit -qm 'Initial test commit'
git branch -M main
git remote add origin "$task_dir/origin"
git push -qu origin main
git --git-dir="$task_dir/origin" symbolic-ref HEAD refs/heads/main
git switch -qc feature
printf 'two\n' >> sample.txt
git commit -qam 'Test feature'
git switch -q main
git merge -q --ff-only feature
git push -q origin main
git clone -q "$task_dir/origin" "$task_dir/clone"
test "$(git -C "$task_dir/clone" rev-parse HEAD)" = "$(git rev-parse HEAD)"
git switch -qc independent HEAD~1
printf 'other\n' > other.txt
git add other.txt
git commit -qm 'Test rebase'
git rebase -q main
git grep -P '^one$' -- sample.txt >/dev/null
git worktree add -q --detach "$task_dir/worktree" HEAD
git archive HEAD | tar -tf - | grep -q sample.txt
git -c protocol.file.allow=always submodule add -q "$task_dir/origin" dependency
git submodule status >/dev/null
git gc --prune=now --quiet
git fsck --no-progress >/dev/null
if [ "${1:-}" = --https ]; then
    GIT_TERMINAL_PROMPT=0 git -c credential.helper= ls-remote \
        "${GIT_TEST_HTTPS_URL:-https://github.com/git/git.git}" HEAD
fi
printf 'Git commit, branch, merge, rebase, clone, push, worktree, submodule, archive, PCRE, and GC passed.\n'
