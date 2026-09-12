#!/usr/bin/env bash
#
# cli-tour — exercise (nearly) every am-git operation against a scratch
# repository, using the real am-git binary built by the parent project.
#
# Copies `app` from the parent am-git build (builds/bin/<host>/app), then
# walks through the whole local command set: init, config, add, status,
# commit, log, diff, show, branch, checkout, merge, merge-base, tag,
# unstage, reset, rm, mv, revert, cherry-pick, rebase, plus the plumbing
# (head, whoami, hash-object, write-tree, cat-file, rev-list-objects).
#
# Network commands (clone / fetch / pull / push) are intentionally left
# out — everything here runs offline on the host (mac or linux).
#
# The script runs with `set -e`, so it doubles as a smoke test: any
# command that errors aborts the tour with a non-zero exit.
#
# Usage:
#   ./run.sh                 # uses ../../builds/bin/<host>/app
#   AMGIT=/path/to/am-git ./run.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- locate the am-git binary built by the parent project ---------------
case "$(uname -s)/$(uname -m)" in
    Darwin/arm64)  HOST_BT=macos-arm ;;
    Darwin/x86_64) HOST_BT=macos ;;
    *)             HOST_BT=linux-x64 ;;
esac
PARENT_BIN="${AMGIT:-$SCRIPT_DIR/../../builds/bin/$HOST_BT/app}"
if [[ ! -f "$PARENT_BIN" ]]; then
    echo "error: $PARENT_BIN not found — build it first:  (cd ../.. && make build)" >&2
    exit 1
fi

# --- fresh scratch workspace -------------------------------------------
WORK="$SCRIPT_DIR/work"
REPO="$WORK/demo-repo"
rm -rf "$WORK"
mkdir -p "$REPO"

# The point of the exercise: copy the app from the parent am-git folder
# and drive that copy.
cp "$PARENT_BIN" "$WORK/am-git"
chmod +x "$WORK/am-git"
AMGIT_BIN="$WORK/am-git"

# Identity comes from `config user.name` / `user.email` set below — the
# 0.12.x .git/config path. (Env vars AM_GIT_USER_NAME / GIT_AUTHOR_NAME
# would override config, same precedence as real git, so we deliberately
# clear them for a deterministic tour.)
unset AM_GIT_USER_NAME AM_GIT_USER_EMAIL GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL \
      GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL 2>/dev/null || true

cd "$REPO"

# g — run one am-git command, echoing it like a shell session.
g() {
    echo
    echo "\$ am-git $*"
    "$AMGIT_BIN" "$@"
}

banner() {
    echo
    echo "===== $* ====="
}

banner "version / init / config"
g version
g init
g config user.name "Tour User"
g config user.email "tour@example.com"
g config --list
g whoami

banner "first files: status -> add -> commit"
printf 'Hello, Amiga!\n' > hello.txt
printf 'notes line one\n' > notes.txt
g status
g add hello.txt notes.txt
g status
g commit -m "Initial commit"
g log
g head

banner "edit -> diff -> stage -> unstage -> commit"
printf 'Hello again.\n' >> hello.txt
g diff
g add hello.txt
g diff --staged
g unstage hello.txt
g status
g add hello.txt
g commit -m "Extend hello.txt"
g show
g show HEAD:hello.txt

banner "branch / checkout / diverge / merge-base / merge"
g branch feature
g branch
g checkout feature
printf 'feature work\n' > feature.txt
g add feature.txt
g commit -m "Add feature.txt"
g checkout main
printf 'notes line two\n' >> notes.txt
g add notes.txt
g commit -m "Extend notes on main"
g merge-base main feature
g merge feature
g log -n 10

banner "tags"
g tag v1.0
g tag scratch-tag
g tag
g tag -d scratch-tag
g tag

banner "mv / rm"
g mv notes.txt docs.txt
g status
g commit -m "Rename notes.txt to docs.txt"
g rm feature.txt
g status
g commit -m "Remove feature.txt"

banner "revert"
g revert HEAD
g log -n 4

banner "cherry-pick"
g branch hotfix
g checkout hotfix
printf 'hotfix change\n' >> hello.txt
g add hello.txt
g commit -m "Hotfix on branch"
HOTFIX_SHA=$("$AMGIT_BIN" log -n 1 | awk '/^commit /{print $2; exit}')
echo "(hotfix commit: $HOTFIX_SHA)"
g checkout main
g cherry-pick "$HOTFIX_SHA"
g log -n 3

banner "rebase"
g branch topic
g checkout topic
printf 'topic work\n' > topic.txt
g add topic.txt
g commit -m "Topic commit"
g checkout main
printf 'main moves on\n' >> docs.txt
g add docs.txt
g commit -m "Main moves on"
g checkout topic
g rebase main
g log -n 4
g checkout main

banner "reset (on a throwaway branch)"
g branch throwaway
g checkout throwaway
FIRST_SHA=$("$AMGIT_BIN" log | awk '/^commit /{sha=$2} END{print sha}')
echo "(resetting hard to root commit: $FIRST_SHA)"
g reset --hard "$FIRST_SHA"
g log
g checkout main

banner "diff between two commits"
PREV_SHA=$("$AMGIT_BIN" log -n 2 | awk '/^commit /{sha=$2} END{print sha}')
HEAD_SHA=$("$AMGIT_BIN" log -n 1 | awk '/^commit /{print $2; exit}')
g diff --name-status "$PREV_SHA" "$HEAD_SHA"

banner "plumbing: hash-object / write-tree / cat-file / rev-list-objects"
g hash-object -w hello.txt
BLOB_SHA=$("$AMGIT_BIN" hash-object hello.txt)
g cat-file -t "$BLOB_SHA"
g cat-file -p "$BLOB_SHA"
g write-tree
g rev-list-objects "$HEAD_SHA"

banner "final state"
g status
g log

echo
echo "cli-tour completed OK — repo left at: $REPO"
