# am-git

A small git client written in [AmLang](https://github.com/anderskjeldsen/am-lang-core).

Built on top of:

- `am-lang-core` — strings, collections, file I/O, sockets-adjacent runtime
- `am-net` — POSIX/AmiSSL-compatible TCP sockets
- `am-ssl` — TLS via OpenSSL on libc / AmiSSL on AmigaOS
- `am-z` — zlib bindings for packfile inflate
- `am-crypto` — SHA-1 for git object ids
- `am-json`, `am-yaml` — pulled in for future config / metadata work

## Status

End-to-end `git clone` works. From an `https://...` URL, am-git:

1. Negotiates the smart-HTTP `git-upload-pack` v1 protocol (with
   `side-band-64k`, `ofs-delta`).
2. Downloads the packfile.
3. Walks every entry: full objects are SHA-1'd and indexed; delta
   entries (OFS_DELTA / REF_DELTA) are inflated, applied to their
   bases via the delta resolver, and added to the same index.
4. Materialises the HEAD commit's tree into the target directory —
   one file per blob, recursing into subdirectories.

The resulting working tree is **byte-identical to what real `git clone`
produces** (verified by `diff -r` against a reference clone). The
`.git` directory is also populated with `HEAD`, `config`, and refs
under `refs/heads/`, `refs/remotes/origin/`, `refs/tags/`, plus the
raw `pack-tmp.pack` (no `.idx` yet — `git index-pack` regenerates it
if you want real git to use the pack).

What it does **not** do yet:

- Generate the `.pack`'s companion `.idx` index file. (Pack contents
  are fully decoded in memory and used for the checkout; the on-disk
  pack is a bonus for interop.)
- Set executable mode on `mode 100755` blobs (we record the mode but
  write all files at 0644 — needs a native `chmod` binding).
- Real symbolic links (`mode 120000` blobs are written as regular
  files containing the link target).
- Submodules (`mode 160000` entries are skipped silently).
- The SSH or git:// transports.
- Smart-HTTP protocol v2.

## Usage

```
am-git clone <url> [target-dir]
```

Examples:

```
am-git clone https://github.com/anderskjeldsen/am-lang-core.git
am-git clone https://github.com/anderskjeldsen/am-net.git my-net-clone
```

## Build

```
make build-macos-arm    # macOS Apple Silicon
make build-linux        # Linux x64
make build-amigaos      # AmigaOS m68k via amiga-gcc Docker image
```
