# tools/

Development helpers for am-git. Not built into the binary; not shipped
as part of a release. Run them straight from your checkout.

## `ghcli/`

A small `gh` (GitHub CLI) work-alike in AmLang, for the hosts upstream
`gh` never reached. One request in, JSON out:

```sh
cd tools/ghcli && make
./builds/bin/macos-arm/app auth login --with-token ghp_xxx
./builds/bin/macos-arm/app api repos/anderskjeldsen/am-git
```

HTTPS via am-web-client on am-ssl (AmiSSL on the Amiga targets); the
login is saved next to the executable (`PROGDIR:ghcli.json`). Its own
package with its own Makefile — `make build-amigaos` / `make
build-morphos` cross-build it. See `ghcli/README.md`.

## `git-http-server.py`

Tiny smart-HTTP git server. Wraps the real `git http-backend` CGI in
Python so you can push to / fetch from a local bare repo over plain
HTTP, without standing up Apache or anything heavier.

Spin up a target repo + the server:

```sh
# Create a bare target
git init --bare -b main /tmp/target.git
git -C /tmp/target.git config http.receivepack true
git -C /tmp/target.git update-server-info

# Serve everything under /tmp on port 8181
tools/git-http-server.py --root /tmp --port 8181 &
```

Push to it from an am-git working copy:

```sh
am-git push  http://127.0.0.1:8181/target.git main
am-git fetch http://127.0.0.1:8181/target.git origin
```

Defaults: `--root` is the current directory, `--port` is 8181, `--host`
is 127.0.0.1.

Requirements: Python 3 and a real `git` binary on `PATH` (the script
finds `git-http-backend` via `git --exec-path`).

Local development only — no auth, no TLS. Don't expose the port.
