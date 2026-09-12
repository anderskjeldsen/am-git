# cli-tour — exercise (nearly) every am-git command

A bash script that copies the `app` binary from the parent am-git build
and drives it through the whole **local** command set against a scratch
repository, printing each command and its output like a shell session:

- setup: `version`, `init`, `config` (set + `--list`), `whoami`
- everyday flow: `status`, `add`, `commit`, `log`, `head`, `diff`
  (worktree / `--staged` / two commits / `--name-status`), `show`
  (commit and `HEAD:<path>`), `unstage`
- branching: `branch` (create / list), `checkout`, `merge`,
  `merge-base`, `tag` (create / list / `-d`)
- history surgery: `revert`, `cherry-pick`, `rebase`, `reset --hard`
- file ops: `mv`, `rm`
- plumbing: `hash-object -w`, `cat-file -t/-p`, `write-tree`,
  `rev-list-objects`

Not covered (network): `clone`, `fetch`, `pull`, `push` — everything
here runs offline on the host (macOS or Linux).

## Run

```sh
(cd ../.. && make build)    # build the host am-git binary once
./run.sh                    # copies ../../builds/bin/<host>/app and runs the tour
```

Or point it at any am-git binary:

```sh
AMGIT=/path/to/am-git ./run.sh
```

The script runs under `set -e`, so it doubles as an end-to-end smoke
test: any command that fails aborts the tour with a non-zero exit. The
scratch repo is recreated fresh in `work/demo-repo` on every run and
left in place afterwards for inspection.
