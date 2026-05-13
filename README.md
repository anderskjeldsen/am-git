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

End-to-end **clone, commit, and push** all work against real HTTPS git
remotes (validated against GitHub and a local `git http-backend` server,
byte-for-byte against reference `git` output).

### Clone

From an `https://...` URL, am-git:

1. Negotiates the smart-HTTP `git-upload-pack` v1 protocol (with
   `side-band-64k`, `ofs-delta`).
2. Downloads the packfile.
3. Walks every entry: full objects are SHA-1'd and indexed; delta
   entries (OFS_DELTA / REF_DELTA) are inflated, applied to their
   bases via the delta resolver, and added to the same index.
4. Materialises the HEAD commit's tree into the target directory —
   one file per blob, recursing into subdirectories.

### Commit

`am-git commit -m "..."` walks the working tree, writes the blobs and
trees as loose objects under `.git/objects/xx/...`, builds a commit
object pointing at HEAD's current commit, and advances the current
branch's ref to it. Output is byte-identical to what `git commit`
would have produced — you can keep using `git` against the same repo.

### Push

`am-git push <url> [<branch>]` resolves the remote's current SHA via
`info/refs?service=git-receive-pack`, walks the objects reachable from
the local commit but not from the remote's, writes them into a v2
packfile, and POSTs the receive-pack body. It handles:

- **First push of a new ref** — old-sha is 40 zeros; the full reachable
  graph is sent.
- **Incremental push** — only the new objects on top of what the remote
  already has.
- **Up-to-date** — short-circuits without contacting receive-pack.

Server's `unpack ok` and `ok <ref>` / `ng <ref> <reason>` lines are
parsed and printed.

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
# 1. Clone
am-git clone https://github.com/youruser/myrepo.git
cd myrepo

# 2. Edit something
echo "hello from am-git" > NOTES.md

# 3. Commit
am-git commit -m "Add NOTES.md via am-git"

# 4. Push
am-git push https://github.com/youruser/myrepo.git main
```

## Commands

Run `am-git help` for the full list with one-line descriptions. The
main ones:

| Command | What it does |
| ------- | ------------ |
| `clone <url> [dir]` | Clone over smart-HTTP, check out HEAD. |
| `commit -m <msg>` | Commit the working tree on top of HEAD's commit. |
| `push <url> [branch]` | Push branch (default HEAD's) to the remote. |
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
