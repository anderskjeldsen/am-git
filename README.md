# am-git

A small git client written in [AmLang](https://github.com/anderskjeldsen/am-lang-core).

Built on top of:

- `am-lang-core` — strings, collections, file I/O, sockets-adjacent runtime
- `am-net` — POSIX/AmiSSL-compatible TCP sockets
- `am-ssl` — TLS via OpenSSL on libc / AmiSSL on AmigaOS
- `am-json`, `am-yaml` — pulled in for future config / metadata work

`am-crypto` (SHA-1) will be added when we start producing pack indexes —
right now it isn't pulled in because both it and `am-ssl` ship an `errno.c`
and `amissl_init.c` as `additionalCSources` with identical output names,
which collides on the AmigaOS link.

## Status

This is the *starter* of an Amiga-friendly git client. The current code:

- Parses `http(s)://host[:port]/path` git URLs
- Speaks smart-HTTP `git-upload-pack` v1
- Handles chunked transfer encoding and side-band-64k framing
- Downloads the packfile and writes it to `<dir>/.git/objects/pack/pack-tmp.pack`
- Initialises a `.git` directory: `HEAD`, `config`, `refs/heads/*`,
  `refs/remotes/origin/*`, `refs/tags/*`

What it does **not** do yet:

- Build a `.idx` for the saved pack (run `git index-pack` against the file
  for now)
- Walk the HEAD tree and check out a working copy
- Implement the SSH or git:// transports
- Speak smart-HTTP protocol v2

So a `clone` finishes with a fully populated `.git` directory but no working
tree. Pointing real `git` at the same directory and running
`git index-pack` followed by `git checkout HEAD -- .` will produce the same
result as a normal clone.

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
