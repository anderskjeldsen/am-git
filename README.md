# am-git

A git client written in [AmLang](https://github.com/anderskjeldsen/am-lang-core).
Speaks git's smart protocol directly over smart-HTTP(S) and ssh — no
shelling out to a real git binary at runtime (ssh remotes drive an
external ssh client, exactly like desktop git does).

Built on top of:

- `am-lang-core` — strings, collections, file I/O, env, processes
- `am-net` — TCP sockets
- `am-ssl` — TLS via OpenSSL on libc / AmiSSL on AmigaOS
- `am-z` — zlib bindings for pack inflate + deflate
- `am-crypto` — SHA-1 for git object ids
- `am-web-client` — HTTP/1.1 client (shared with other AmLang projects)
- `am-json`, `am-yaml` — config / metadata support

## Status

End-to-end **clone, fetch, pull, push** work against real remotes over
`https://`, `http://` and ssh (`git@host:path` / `ssh://...`),
validated byte-for-byte against reference `git` output on GitHub and
local servers. The local command set covers everyday work: staging,
commits, branches, tags, diffs, and full **merge / rebase /
cherry-pick / revert** with conflict handling.

Highlights:

- **Clone** negotiates `git-upload-pack` v1 (`side-band-64k`,
  `ofs-delta`), parses + delta-resolves the pack, materialises HEAD's
  tree, writes a real `.git` layout, and seeds a DIRC v2 index.
  `--depth <n>` does a shallow clone (`.git/shallow` maintained).
- **Pull** fast-forwards when it can, otherwise falls back to a real
  3-way merge; conflicts land in the files with `<<<<<<<` markers and
  as index stages 1/2/3.
- **Push** walks reachable objects, writes a v2 packfile, and speaks
  receive-pack — initial, incremental, and `--force`. Parses
  `ok` / `ng` per-ref replies.
- **Merge machinery** — `merge`, `rebase`, `cherry-pick`, `revert`,
  with `--continue` / `--abort` where a conflict interrupts the run,
  and `merge-base` for the ancestry math. Real git accepts the
  resulting repos without complaint.
- **Index** — reads + writes a real DIRC v2 `.git/index`, including
  conflict stages; `git ls-files` / `git status` / `git commit` work
  against the same index.
- **Refs** — loose refs and `packed-refs` are both read; branches and
  lightweight tags can be listed / created / deleted.
- The whole test suite (118 tests) runs on the desktop **and on real
  m68k AmigaOS** under headless Amiberry (`make test` /
  `make test-amigaos`).

## Configure

Identity (used by `commit` / `commit-tree`):

```sh
export AM_GIT_USER_NAME="Your Name"
export AM_GIT_USER_EMAIL="you@example.com"
# (real git's GIT_AUTHOR_NAME / GIT_COMMITTER_NAME etc. also work)
```

HTTP(S) credentials — used by `push` and by `clone`/`fetch` against
private repos. Resolved per remote host, first match wins:

1. **In the URL** — `https://user:token@host/owner/repo.git`
2. **A `.netrc` store** — different logins per host. `~/.netrc` on
   macOS/Linux, or put the whole file content into the `AM_GIT_NETRC`
   env var (on AmigaOS: `ENV:AM_GIT_NETRC`):

   ```
   machine github.com login alice password ghp_alicetoken
   machine gitlab.com login bob   password glpat_bobtoken
   default login guest password anon
   ```
3. **One global login** (simple / CI fallback):

   ```sh
   export AM_GIT_USERNAME="your-github-login"
   export AM_GIT_PASSWORD="ghp_yourPersonalAccessToken"
   ```

GitHub retired plain-password auth — use a personal access token as
the password. For other forges, anything that works as Basic auth in
real git works here.

## SSH remotes (bebbossh on AmigaOS)

am-git supports `git@host:path` and `ssh://user@host[:port]/path`
remotes by running an external ssh client and speaking the git
protocol through it. On macOS/Linux the system `ssh` is used
automatically — your normal keys and agent apply.

On AmigaOS, use [BebboSSH](https://aminet.net/package/comm/net/bebbossh)
(needs `bebbossh` in `C:` and `libcryptossh.library` in `LIBS:`):

```sh
# 1. point am-git at bebbossh
setenv AM_GIT_SSH bebbossh
copy ENV:AM_GIT_SSH ENVARC:

# 2. create a key pair (key auth only — GitHub takes no passwords,
#    and bebbossh doesn't send them). The key file is unencrypted.
bebbosshkeygen -f ENVARC:.ssh/id_ed25519

# 3. register the public key with the server
type ENVARC:.ssh/id_ed25519.pub
#    -> paste at github.com -> Settings -> SSH and GPG keys

# 4. clone
am-git clone git@github.com:youruser/myrepo.git
```

On the first connection to a new host, am-git forwards bebbossh's
"do you trust host ...?" prompt to your shell — answer `yes` once and
the host key is stored in `ENVARC:.ssh/known-hosts`. bebbossh reads
`ENVARC:.ssh/id_ed25519` by default; `AM_GIT_SSH` accepts any client
with an `ssh <host> <command>`-style CLI. Error 23 ("password login
not supported") means the server rejected the key (or none was found)
— re-check steps 2 and 3.

## Workflow

```sh
# 1. Clone (also writes the remote URL into .git/config)
am-git clone https://github.com/youruser/myrepo.git
cd myrepo

# 2. Look around
am-git log -n 5
am-git branch
am-git status

# 3. Pull upstream changes (ff or 3-way merge)
am-git pull

# 4. Edit + stage + commit
echo "hello from am-git" > NOTES.md
am-git add NOTES.md
am-git commit -m "Add NOTES.md via am-git"

# 5. Branch + merge
am-git branch feature-x
am-git checkout feature-x
# ...edit, add, commit...
am-git checkout main
am-git merge feature-x            # ff, merge commit, or conflict stop

# 6. Push (URL inferred from .git/config)
am-git push
```

When a merge / rebase / cherry-pick / revert stops on conflicts:
resolve the `<<<<<<<` markers in the listed files, `am-git add` them,
then `am-git commit` (merge) or `am-git rebase --continue` /
`cherry-pick --continue` / `revert --continue`. `--abort` rolls back.

## Commands

Run `am-git help` for the full list with one-line descriptions.

| Command | What it does |
| ------- | ------------ |
| `init [<dir>]` | Scaffold an empty `.git/`. |
| `config [--list \| --unset <key> \| <key> [<value>]]` | Read / write `.git/config`. |
| `clone <url> [dir] [--depth <n>]` | Clone over smart-HTTP or ssh; `--depth` for shallow. |
| `fetch [<url>\|<name>]` | Fetch objects + refs (URL default from `.git/config`). |
| `pull [<url>] [<branch>]` | Fast-forward, else 3-way merge. |
| `push [--force] [<url>] [<branch>]` | Push HEAD or named branch. |
| `add <path>...` | Stage paths (`.` adds everything). |
| `rm [--cached] <path>...` | Unstage; without `--cached` also deletes the file. |
| `mv <src> <dst>` | Rename a tracked file. |
| `status` | Staged / unstaged / untracked, three buckets. |
| `log [-n N]` | Walk commit ancestry from HEAD. |
| `branch [<name> \| -d <name>]` | List / create / delete local branches. |
| `tag [<name> [<commit>]] \| -d <name>` | List / create (lightweight) / delete tags. |
| `checkout <branch>` | Switch HEAD + working tree. |
| `checkout HEAD -- <file>...` | Discard selected regular files' staged and local changes, restoring HEAD without switching branches. |
| `checkout -- <file>...` | Restore selected regular files from the index, preserving staged changes. |
| `merge <branch>` | Merge into the current branch (ff / merge commit / conflicts). |
| `merge-base <a> <b>` | Print the lowest common ancestor. |
| `reset [--soft\|--mixed\|--hard] [<commit>]` | Move HEAD (and index / worktree). |
| `rebase <upstream>` | Replay current-branch commits; `--continue` / `--abort`. |
| `cherry-pick <commit>` | Apply a commit onto HEAD; `--continue` / `--abort`. |
| `revert <commit>` | Commit the inverse of a commit; `--continue` / `--abort`. |
| `diff [--staged] [--name-only \| --name-status] [<a> [<b>]]` | Unified diff. |
| `show [<commit>]` | Commit metadata + path-level changes. |
| `commit -m <msg>` | Commit the staged index on top of HEAD. |
| `head` / `whoami` | Resolved HEAD / commit identity. |
| `cat-file (-p\|-t) <sha>` | Object content / type. |
| `version [--all]` | Version; `--all` lists every package built in. |

Plumbing useful for debugging the push pipeline:

| Command | What it does |
| ------- | ------------ |
| `write-tree` / `commit-tree` / `hash-object [-w]` | Low-level object creation. |
| `rev-list-objects <new> [<have>]` | SHAs reachable from `<new>` minus `<have>`. |
| `pack-objects <out> <new> [<have>]` | Write a v2 packfile (verify with `git index-pack --stdin --strict`). |
| `build-push-body <out> <old> <new> <ref>` | Full receive-pack request body. |
| `auth-header [<user> <pass>]` | Print the Basic auth header value. |

## Limitations

- **No exec / symlink modes on disk** — `100755` and `120000` modes
  are recorded faithfully in trees and the index, but files are
  written as regular `0644` (symlinks as a file containing the target)
  until native `chmod` / `symlink` bindings exist.
- **Pack delta compression on push** — full objects only; receive-pack
  accepts them, pushes are just larger on the wire.
- **`.idx` index files** — `clone` saves the downloaded `.pack`
  without a companion `.idx`; run `git index-pack` over it if real git
  should reuse the pack directly.
- **Submodules** — `mode 160000` entries are skipped silently.
- **Standalone tag pushes** — tags travel only when reachable from the
  pushed commit; direct `refs/tags/*` updates aren't wired up.
- **`git://` transport** — https / http / ssh only.
- **Smart-HTTP protocol v2** — v1 is negotiated explicitly.
- **`~/.gitconfig`** — identity / auth come from env vars, not the
  global config file.

## Build

```
make build              # native host (auto-detects macOS / Linux arch)
make build-macos-arm    # macOS Apple Silicon
make build-macos        # macOS Intel
make build-linux-x64    # Linux x64
make build-amigaos      # AmigaOS m68k via amiga-gcc Docker image
```

The host binary lands at `builds/bin/<platform>/app`; symlink or alias
it as `am-git` if you want it on `$PATH`.

## Test

```
make test               # full suite on the host
make test-amigaos       # same suite cross-compiled to m68k and run
                        # under headless Amiberry (amlang-amiberry
                        # Docker image; see amiberry-headless/)
```

## Aminet

`make aminet-package` builds the release archive (binary + docs,
packed with real LhA inside the emulator); `make aminet-publish`
uploads it (dry-run by default — `AMINET_DRYRUN=0` to send). The
canonical docs are `am-git.readme` / `am-git.txt` in the repo root.
