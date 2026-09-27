# Path checkout regression

Build `am-git` for macOS ARM, then run `python3 tests/file-checkout/run.py`.
Override `AM_GIT_BIN` to use another host-compatible binary.

The script creates disposable repositories and invokes the real CLI. It covers
HEAD and index checkout, staged/unstaged/deleted files, binary contents, nested
paths with missing parent directories, spaces, multiple files, missing-path
preflight, traversal rejection, and refusing to follow a symlink. It verifies
HEAD, unrelated worktree files and unrelated staged entries after every case.
