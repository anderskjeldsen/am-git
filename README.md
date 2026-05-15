# am-git

A small git client written in [AmLang](https://github.com/anderskjeldsen/am-lang-core).
Speaks git's smart-HTTP transport directly — no shelling out to a real git
binary at runtime.

Built on top of:

- `am-lang-core` — strings, collections, file I/O, env
- `am-net` — TCP sockets
- `am-ssl` — TLS via OpenSSL on libc / AmiSSL on AmigaOS
- `am-z` — zlib bindings for pack inflate + deflate
- `am-crypto` — SHA-1 for git object ids
- `am-web-client` — HTTP/1.1 client (shared with other AmLang projects)
- `am-json`, `am-yaml` — pulled in for future config / metadata work

## Status

End-to-end **clone, commit, push, fetch, and (ff-only) pull** all work
against real HTTPS git remotes (validated against GitHub and a local
`git http-backend` server, byte-for-byte against reference `git`
output). Local-only operations cover the everyday navigation set —
`log`, `status`, `branch`, `checkout`.

### Clone

From an `https://...` URL, am-git negotiates `git-upload-pack` v1 (with
`side-band-64k`, `ofs-delta`), downloads the packfile, parses + delta-
resolves every entry, materialises HEAD's tree into the target dir,
and writes a real `.git` layout — HEAD, config (with the remote URL),
refs under `refs/heads/` + `refs/remotes/origin/` + `refs/tags/`, and
the raw pack at `objects/pack/`.

### Commit

`am-git commit -m "..."` walks the working tree, writes blobs + trees
as loose objects under `.git/objects/xx/...`, builds a commit object
pointing at HEAD's current commit, and advances the current branch's
ref. Output is byte-identical to `git commit` — interoperable with
real `git` against the same repo.

### Fetch

`am-git fetch [<url>|<name>]` does a smart-HTTP `git-upload-pack`
exchange, sending `have` lines for refs we already hold so the server
omits shared history. New objects land as loose files, and
`refs/remotes/<remote>/<branch>` + `refs/tags/*` advance to whatever
the server advertises.

### Push

`am-git push [<url>] [<branch>]` resolves the remote's current SHA via
`info/refs?service=git-receive-pack`, walks objects reachable from the
local commit but not from the remote, writes them into a v2 packfile,
and POSTs the receive-pack body. Handles initial push, incremental
push, and the already-up-to-date short-circuit; parses `unpack ok` and
`ok <ref>` / `ng <ref> <reason>` from the reply.

### Pull (fast-forward only)

`am-git pull [<url>] [<branch>]` runs a fetch, then advances the local
branch ref to the remote tip **only if** the local commit is an
ancestor of the remote commit. Refuses non-fast-forwards loudly — no
merge / rebase machinery yet, but the common "your branch is behind"
case works.

### Local ops

`log`, `status`, `branch`, `checkout` work entirely against the local
`.git` directory — no network, no extra config needed. See the command
reference below.

## Configure

Two sets of env vars matter:

```sh
# Identity (used by `commit` / `commit-tree`)
export AM_GIT_USER_NAME="Your Name"
export AM_GIT_USER_EMAIL="you@example.com"
# (real git's GIT_AUTHOR_NAME / GIT_COMMITTER_NAME etc. also work)

# HTTP Basic auth (used by `push` and by `clone` against private repos)
export AM_GIT_USERNAME="your-github-login"
export AM_GIT_PASSWORD="ghp_yourPersonalAccessToken"
```

GitHub retired plain-password auth — use a personal access token in
`AM_GIT_PASSWORD`. For other forges, anything that works as Basic auth
in real git will work here.

## Workflow

```sh
# 1. Clone (also writes the remote URL into .git/config)
am-git clone https://github.com/youruser/myrepo.git
cd myrepo

# 2. See what's there / pick a branch
am-git log -n 5
am-git branch
am-git status

# 3. Pull any upstream changes (fast-forward only)
am-git pull

# 4. Edit + commit
echo "hello from am-git" > NOTES.md
am-git status                       # shows ?? NOTES.md
am-git commit -m "Add NOTES.md via am-git"

# 5. Push (URL inferred from .git/config; explicit form also works)
am-git push
am-git push https://github.com/youruser/myrepo.git main
```

## Commands

Run `am-git help` for the full list with one-line descriptions. The
main ones:

| Command | What it does |
| ------- | ------------ |
| `clone <url> [dir]` | Clone over smart-HTTP, check out HEAD. |
| `fetch [<url>\|<name>]` | Fetch objects + refs (URL default from `.git/config`). |
| `pull [<url>] [<branch>]` | Fast-forward-only fetch + advance HEAD. |
| `push [<url>] [<branch>]` | Push HEAD or named branch (URL default from config). |
| `status` | Show modified / deleted / untracked paths vs HEAD. |
| `log [-n N]` | Walk commit ancestry from HEAD. |
| `branch [<name>\| -d <name>]` | List / create / delete local branches. |
| `checkout <branch>` | Switch HEAD and the working tree to a branch. |
| `commit -m <msg>` | Commit the working tree on top of HEAD's commit. |
| `head` | Print resolved HEAD (branch / commit / detached). |
| `whoami` | Print the author/committer line a commit would carry. |
| `cat-file -p \| -t <sha>` | Show object content (`-p`) or type (`-t`). |
| `write-tree` | Build trees+blobs from cwd, print the root tree SHA. |
| `commit-tree <tree> [-p <parent>] -m <msg>` | Write a commit object. |
| `hash-object [-w] <file>` | SHA-1 a file as a blob; `-w` also writes it. |

Plumbing useful for debugging the push pipeline:

| Command | What it does |
| ------- | ------------ |
| `rev-list-objects <new> [<have>]` | List SHAs reachable from `<new>` minus `<have>`. |
| `pack-objects <out> <new> [<have>]` | Write a v2 packfile to `<out>`. Pipe through `git index-pack --stdin --strict` to verify. |
| `build-push-body <out> <old> <new> <ref>` | Write a complete receive-pack request body. Pipe through `git receive-pack <bare>` to verify. |
| `auth-header [<user> <pass>]` | Print the Basic auth header value. Defaults to env vars; pass explicit args to test without exporting secrets. |

## Limitations

Things that don't work yet (or don't work the way real git does):

- **Pull is fast-forward only** — diverged branches need real git for
  merge / rebase. The non-FF case bails with a clear error message.
- **No index file** — `commit` and `status` always walk the working
  tree. There's no staging area; `commit` records every change found.
- **Pack delta compression on push** — am-git emits full objects only.
  Real git negotiates and ships delta-encoded entries; receive-pack
  accepts both, so this just means pushes are larger on the wire.
- **`.idx` index files** — `clone` writes the `.pack` it downloaded but
  no companion `.idx`. Run `git index-pack` over the pack if you want
  real git to use it without rebuilding.
- **Executable / symlink modes on checkout** — we record `100755` and
  `120000` modes but write everything as a regular `0644` file (needs
  a native `chmod` / `symlink` binding).
- **Submodules** — `mode 160000` entries are skipped silently.
- **Force pushes** — receive-pack rejects non-fast-forwards by default;
  am-git doesn't try to override that.
- **Tags as standalone refs** — pushed only when reachable from the
  pushed commit; standalone `refs/tags/*` updates aren't wired up.
- **SSH / git:// transports** — HTTPS / HTTP only.
- **Smart-HTTP protocol v2** — we negotiate v1 explicitly.
- **`packed-refs` and `~/.gitconfig`** — we read loose refs only and
  configure identity / auth via env vars.

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
