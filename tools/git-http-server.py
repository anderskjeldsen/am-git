#!/usr/bin/env python3
"""Tiny smart-HTTP git server for am-git development.

Wraps `git http-backend` (the CGI program that ships with real git) in a
Python HTTP server, so you can push to / fetch from a local bare repo
over plain HTTP without standing up a full Apache + cgit setup.

Usage:
    tools/git-http-server.py [--root DIR] [--port N]

Defaults:
    --root   the current working directory  (must contain a bare repo
             named <whatever>.git that the client will refer to as
             /<whatever>.git/...)
    --port   8181

Set up a bare target repo first:
    git init --bare -b main target.git
    git -C target.git config http.receivepack true
    git -C target.git update-server-info

Then run the server and push / fetch through it:
    tools/git-http-server.py --root . --port 8181 &
    am-git push  http://127.0.0.1:8181/target.git main
    am-git fetch http://127.0.0.1:8181/target.git origin

Ctrl-C (or `kill <pid>`) to stop.

This is for local development only — no auth, no TLS, no concurrency
protection. Don't expose the port.
"""
import argparse
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


def make_handler(root: str):
    backend_dir = subprocess.run(
        ["git", "--exec-path"], capture_output=True, text=True, check=True
    ).stdout.strip()
    backend = os.path.join(backend_dir, "git-http-backend")
    if not os.path.exists(backend):
        sys.exit(f"git-http-backend not found at {backend}")

    class GitHandler(BaseHTTPRequestHandler):
        # Inject all incoming HTTP headers + a few CGI-required env vars,
        # then run git-http-backend as a one-shot CGI program. Its stdout
        # carries CGI-style headers followed by a blank line and the body
        # — we split the two and replay them as a proper HTTP response.
        def _serve(self):
            path = self.path
            query = ""
            if "?" in path:
                path, query = path.split("?", 1)

            env = os.environ.copy()
            env["GIT_PROJECT_ROOT"] = root
            env["GIT_HTTP_EXPORT_ALL"] = "1"
            env["PATH_INFO"] = path
            env["QUERY_STRING"] = query
            env["REQUEST_METHOD"] = self.command
            env["CONTENT_TYPE"] = self.headers.get("Content-Type", "")
            env["CONTENT_LENGTH"] = self.headers.get("Content-Length", "")
            for hk, hv in self.headers.items():
                env["HTTP_" + hk.upper().replace("-", "_")] = hv

            body_in = b""
            if env["CONTENT_LENGTH"]:
                body_in = self.rfile.read(int(env["CONTENT_LENGTH"]))

            proc = subprocess.run([backend], env=env, input=body_in, capture_output=True)
            out = proc.stdout

            # CGI headers / body separator — prefer CRLF CRLF, fall back
            # to bare LF LF.
            sep = b"\r\n\r\n"
            idx = out.find(sep)
            if idx < 0:
                sep = b"\n\n"
                idx = out.find(sep)
            headers_blob = out[:idx].decode("latin-1") if idx >= 0 else ""
            body_out = out[idx + len(sep):] if idx >= 0 else out

            status = 200
            status_msg = "OK"
            parsed_headers = []
            for line in headers_blob.split("\n"):
                line = line.rstrip("\r")
                if not line:
                    continue
                k, _, v = line.partition(":")
                k = k.strip()
                v = v.strip()
                if k.lower() == "status":
                    parts = v.split(" ", 1)
                    status = int(parts[0])
                    status_msg = parts[1] if len(parts) > 1 else ""
                else:
                    parsed_headers.append((k, v))

            self.send_response(status, status_msg)
            for k, v in parsed_headers:
                self.send_header(k, v)
            self.send_header("Content-Length", str(len(body_out)))
            self.end_headers()
            self.wfile.write(body_out)

        do_GET = _serve
        do_POST = _serve
        # The HEAD probes some clients send aren't useful here — short
        # them out so they don't trip 501 noise in the log.
        def do_HEAD(self):
            self.send_response(405)
            self.send_header("Content-Length", "0")
            self.end_headers()

        def log_message(self, fmt, *args):
            sys.stderr.write("[git-http] " + (fmt % args) + "\n")

    return GitHandler


def main(argv):
    parser = argparse.ArgumentParser(description="Local smart-HTTP git server (wraps git-http-backend).")
    parser.add_argument("--root", default=os.getcwd(),
                        help="Directory containing the bare repos to serve (default: cwd)")
    parser.add_argument("--port", type=int, default=8181,
                        help="Port to listen on (default: 8181)")
    parser.add_argument("--host", default="127.0.0.1",
                        help="Host/interface to bind (default: 127.0.0.1)")
    args = parser.parse_args(argv)

    if not os.path.isdir(args.root):
        sys.exit(f"--root path does not exist: {args.root}")

    handler = make_handler(os.path.abspath(args.root))
    server = HTTPServer((args.host, args.port), handler)
    sys.stderr.write(
        f"[git-http] serving {args.root} on http://{args.host}:{args.port}\n"
        f"[git-http] try:  am-git fetch http://{args.host}:{args.port}/<repo>.git origin\n"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        sys.stderr.write("\n[git-http] shutting down\n")
        server.server_close()


if __name__ == "__main__":
    main(sys.argv[1:])
