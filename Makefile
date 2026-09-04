# Always the WORKSPACE-ROOT amlc.jar — a per-project copy goes stale and
# then fails to parse newer package.yml files (the local Aug-5 jar choked
# on am-lang-core's aros-arm64 dockerBuild.platform key).
AMLC:=../amlc.jar
CMD=java -jar $(AMLC)
LOGLEVEL:=1

# -lpp .. tells amlc to prefer sibling checkouts of any dependency
# (am-z, am-ssl, am-web-client, …) over the GitHub git-repo entries
# in package.yml. Lets us iterate on local fixes without pushing
# first. Falls back to GitHub for any sibling that isn't checked out.
LPP := -lpp ..

# Pick the host's native build target so plain `make build` does the
# right thing on both macs and linux dev boxes. macOS is split by arch
# because Homebrew's openssl lives under /opt/homebrew on Apple Silicon
# vs /usr/local on Intel, and that's wired into package.yml's macos /
# macos-arm platforms.
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_S),Darwin)
  ifeq ($(UNAME_M),arm64)
    HOST_BT := macos-arm
  else
    HOST_BT := macos
  endif
else
  HOST_BT := linux-x64
endif

build:
	$(CMD) build . -bt $(HOST_BT) -ll5 -maxOneError $(LPP)

build-linux-x64:
	$(CMD) build . -bt linux-x64 -ll5 -maxOneError $(LPP)

build-amigaos:
	$(CMD) build . -bt amigaos_docker -ll5 $(LPP)

build-morphos:
	$(CMD) build . -bt morphos-ppc_docker -ll5 $(LPP)

build-macos:
	$(CMD) build . -bt macos -ll5 -maxOneError $(LPP)

build-macos-arm:
	$(CMD) build . -bt macos-arm -ll5 -maxOneError $(LPP)

build-force-deps:
	$(CMD) build . -fld -bt $(HOST_BT) -ll5 $(LPP)
deps:
	$(CMD) deps . -bt $(HOST_BT) -fld -ll 5 $(LPP)

run:
	$(CMD) run . -bt $(HOST_BT) -ll $(LOGLEVEL) $(LPP)

test:
	$(CMD) test . -bt $(HOST_BT) -ll $(LOGLEVEL) $(LPP)

# Cross-compile the test binary for m68k (amiga-gcc docker) and run the
# whole suite under headless Amiberry (amlang-amiberry image). amlc's
# dockerTest support stages the binary, watches for the sentinel, and
# reports pass/fail — see the amigaos-amiberry target in package.yml.
test-amigaos:
	$(CMD) test . -bt amigaos-amiberry -ll $(LOGLEVEL) $(LPP)

clean:
	rm -rf builds

# ---------------------------------------------------------------------------
# Aminet distribution
#
# `make aminet` builds the AmigaOS (m68k) binary, renames it from the
# generic `app` to `am-git`, and stages an Aminet-compliant upload:
#
#   builds/aminet/am-git.lha      the archive (contains am-git/ dir)
#   builds/aminet/am-git.readme   the .readme that sits NEXT TO the .lha
#
# Both filenames are lowercase, <=30 chars, and use only [a-z0-9.-], per
# https://wiki.aminet.net/Uploading_instructions . The .readme carries the
# four mandatory fields (Short/Uploader/Type/Architecture) plus the usual
# Author/Version/Requires/Distribution.
#
# The canonical .readme lives at the repo root as am-git.readme (committed,
# version-controlled). Packaging copies it into builds/ and only rewrites
# the Version: line from package.yml — so edit am-git.readme for the text,
# and bump package.yml for the version. Nothing under builds/ is a source
# of truth (it's clobbered by `make clean` and regenerated on demand).
#
# The .lha is built with the *real* Amiga LhA (C:LHA in the CLIDrive SYS
# baked into the amiberry-headless image), so the archive carries genuine
# AmigaDOS protection bits / file comments — not whatever a host `lha`
# port would stamp. We stage the payload into a folder mounted as DH1:,
# drop an `app_starter` script that runs C:LHA, and let the emulator do
# the packing; the resulting am-git.lha lands back in the mounted folder.
#
# The final `make aminet-upload` step only PRINTS the intended FTP session
# for now, so we can eyeball exactly what would be pushed before going live.
# ---------------------------------------------------------------------------

# Version is read straight from package.yml so it never drifts. Strip any
# surrounding quotes / trailing CR so the readme's Version: field is clean.
AMINET_VERSION := $(shell awk '/^version:/{v=$$2; gsub(/["\r]/,"",v); print v; exit}' package.yml)
AMINET_NAME    := am-git

# Canonical, committed sources (NOT under builds/ — they survive `clean`).
AMINET_RDM_SRC := am-git.readme
AMINET_TXT_SRC := am-git.txt

# Where the built m68k binary lands, and where we stage the upload.
AMIGA_BIN   := builds/bin/amigaos/app
AMINET_DIR  := builds/aminet
# DH1_DIR is bind-mounted into the emulator as DH1:. PKG_DIR (= the am-git/
# folder inside it) is what LhA archives, so members keep the am-git/ prefix.
DH1_DIR     := $(AMINET_DIR)/dh1
PKG_DIR     := $(DH1_DIR)/$(AMINET_NAME)
AMINET_LHA  := $(AMINET_DIR)/$(AMINET_NAME).lha
AMINET_RDM  := $(AMINET_DIR)/$(AMINET_NAME).readme

# amiberry-headless runner (sibling checkout). Its run.sh needs the
# amlang-amiberry:latest image already built (see that repo's build.sh).
AMIBERRY_HEADLESS ?= ../amiberry-headless

# Aminet anonymous-FTP endpoint (used only by the publish step). Password
# is your email address, per Aminet's rules.
AMINET_FTP_HOST := main.aminet.net
AMINET_FTP_DIR  := new
AMINET_FTP_USER := anonymous
AMINET_FTP_PASS := kjeldsenanders@gmail.com
# Publishing is a DRY RUN by default so nothing ships by accident. Flip it
# with `make aminet-publish AMINET_DRYRUN=0` when you actually want to send.
AMINET_DRYRUN   ?= 1

# Build fresh, then package.
aminet: build-amigaos aminet-package

# Full pipeline: build + package + publish (publish is dry-run by default).
aminet-release: aminet aminet-publish

# Package an already-built binary (skip the slow docker build).
aminet-package: aminet-readme
	@test -n "$(AMINET_VERSION)" || { echo "error: no version found in package.yml"; exit 1; }
	@echo "packaging $(AMINET_NAME) $(AMINET_VERSION) (version from package.yml)"
	@test -f $(AMIGA_BIN) || { echo "error: $(AMIGA_BIN) not found — run 'make build-amigaos' first"; exit 1; }
	@test -x $(AMIBERRY_HEADLESS)/run.sh || { echo "error: $(AMIBERRY_HEADLESS)/run.sh not found — set AMIBERRY_HEADLESS"; exit 1; }
	@rm -rf $(DH1_DIR) $(AMINET_LHA)
	@mkdir -p $(PKG_DIR)
	@cp $(AMIGA_BIN) $(PKG_DIR)/$(AMINET_NAME)
	@chmod +x $(PKG_DIR)/$(AMINET_NAME)
	@cp $(AMINET_RDM) $(PKG_DIR)/$(AMINET_NAME).readme
	@# Ship a plain-text guide, not README.md — Amiga has no good md reader.
	@cp $(AMINET_TXT_SRC) $(PKG_DIR)/am-git.txt
	@# run.sh insists on an `app` binary in the DH1 folder — give it one.
	@cp $(AMIGA_BIN) $(DH1_DIR)/app
	@# app_starter: the AmigaDOS script the image executes. Build the .lha
	@# with the real C:LHA, into DH1: (= this folder) so the host sees it.
	@{ \
	  printf '%s\n' '; Auto-generated by am-git Makefile — packs the Aminet .lha via C:LHA.'; \
	  printf '%s\n' 'cd DH1:'; \
	  printf '%s\n' 'Delete DH1:$(AMINET_NAME).lha QUIET'; \
	  printf '%s\n' 'C:LHA -r a DH1:$(AMINET_NAME).lha $(AMINET_NAME) >DH1:output.log'; \
	} > $(DH1_DIR)/app_starter
	@echo "packing $(AMINET_NAME).lha with C:LHA inside amiberry-headless ..."
	@# Route the emulator log to a file — LhA's freezing progress meter is
	@# thousands of CR-updates. Print only the meaningful summary lines. The
	@# `test -f` below is the real success gate, so we don't trust exit code.
	@$(AMIBERRY_HEADLESS)/run.sh $(abspath $(DH1_DIR)) > $(AMINET_DIR)/lha-run.log 2>&1 || true
	@LC_ALL=C tr '\r' '\n' < $(AMINET_DIR)/lha-run.log | grep -E 'files added|Operation successful|LhA Eval|[Ee]rror' || true
	@test -f $(DH1_DIR)/$(AMINET_NAME).lha || { echo "error: LhA produced no archive — see $(AMINET_DIR)/lha-run.log"; exit 1; }
	@cp $(DH1_DIR)/$(AMINET_NAME).lha $(AMINET_LHA)
	@echo "packaged:"
	@echo "  $(AMINET_LHA)  ($$(wc -c < $(AMINET_LHA)) bytes)"
	@echo "  $(AMINET_RDM)"
	@echo "staged into the archive (am-git/):"
	@ls -l $(PKG_DIR)

# Produce the upload .readme from the committed am-git.readme source,
# rewriting only the Version: line from package.yml. sed (not sed -i, to
# stay BSD/GNU portable) reads the source and writes the builds/ copy, so
# the source file is never mutated in place.
aminet-readme:
	@test -f $(AMINET_RDM_SRC) || { echo "error: $(AMINET_RDM_SRC) missing (canonical readme source)"; exit 1; }
	@mkdir -p $(AMINET_DIR)
	@sed 's/^Version:.*/Version:      $(AMINET_VERSION)/' $(AMINET_RDM_SRC) > $(AMINET_RDM)
	@echo "wrote $(AMINET_RDM) (from $(AMINET_RDM_SRC), version $(AMINET_VERSION))"

# Publish step — decoupled from packaging. Operates on the artifacts that
# aminet-package already produced (it does NOT rebuild or repackage), so
# you can inspect them first, then publish without re-running the emulator.
# Dry-run by default: prints exactly what it would send. Set AMINET_DRYRUN=0
# to actually upload over anonymous FTP (via curl; /usr/bin/ftp is gone on
# modern macOS).
aminet-publish:
	@test -f $(AMINET_LHA) || { echo "error: $(AMINET_LHA) not found — run 'make aminet-package' first"; exit 1; }
	@test -f $(AMINET_RDM) || { echo "error: $(AMINET_RDM) not found — run 'make aminet-package' first"; exit 1; }
	@echo "publish target: ftp://$(AMINET_FTP_HOST)/$(AMINET_FTP_DIR)  (user: $(AMINET_FTP_USER))"
	@echo "  $(AMINET_LHA)  ->  $(AMINET_NAME).lha"
	@echo "  $(AMINET_RDM)  ->  $(AMINET_NAME).readme"
	@if [ "$(AMINET_DRYRUN)" = "0" ]; then \
	  echo "uploading over anonymous FTP ..."; \
	  curl -sS --ftp-create-dirs -T $(AMINET_LHA) "ftp://$(AMINET_FTP_HOST)/$(AMINET_FTP_DIR)/$(AMINET_NAME).lha" --user "$(AMINET_FTP_USER):$(AMINET_FTP_PASS)" && \
	  curl -sS --ftp-create-dirs -T $(AMINET_RDM) "ftp://$(AMINET_FTP_HOST)/$(AMINET_FTP_DIR)/$(AMINET_NAME).readme" --user "$(AMINET_FTP_USER):$(AMINET_FTP_PASS)" && \
	  echo "upload complete — check the Aminet upload queue."; \
	else \
	  echo ""; \
	  echo "=== DRY RUN — nothing sent ==="; \
	  echo "Re-run to actually publish:  make aminet-publish AMINET_DRYRUN=0"; \
	  echo ""; \
	  echo "Would run:"; \
	  echo "  curl -T $(AMINET_LHA) ftp://$(AMINET_FTP_HOST)/$(AMINET_FTP_DIR)/$(AMINET_NAME).lha --user $(AMINET_FTP_USER):$(AMINET_FTP_PASS)"; \
	  echo "  curl -T $(AMINET_RDM) ftp://$(AMINET_FTP_HOST)/$(AMINET_FTP_DIR)/$(AMINET_NAME).readme --user $(AMINET_FTP_USER):$(AMINET_FTP_PASS)"; \
	fi

.PHONY: aminet aminet-release aminet-package aminet-readme aminet-publish

# ---------------------------------------------------------------------------
# Aminet distribution — MorphOS (ppc-morphos) variant: am-git_mos.lha
#
# Mirrors the m68k pipeline above with its own committed readme
# (am-git_mos.readme, Architecture: ppc-morphos) and its own staging dir.
# The archive still extracts to an am-git/ drawer — same product, per-arch
# download — with the PPC binary inside. Packing reuses the same C:LHA-in-
# amiberry trick: the emulator is m68k, but LhA just archives files; the
# custom app_starter never executes the payload, and the `app` file in the
# DH1 dir only satisfies run.sh's existence check.
# ---------------------------------------------------------------------------

AMINET_MOS_NAME    := am-git_mos
AMINET_MOS_RDM_SRC := am-git_mos.readme
MOS_BIN            := builds/bin/morphos-ppc/app
DH1_MOS_DIR        := $(AMINET_DIR)/dh1-mos
PKG_MOS_DIR        := $(DH1_MOS_DIR)/$(AMINET_NAME)
AMINET_MOS_LHA     := $(AMINET_DIR)/$(AMINET_MOS_NAME).lha
AMINET_MOS_RDM     := $(AMINET_DIR)/$(AMINET_MOS_NAME).readme

# Build fresh, then package.
aminet-mos: build-morphos aminet-mos-package

# Full pipeline: build + package + publish (publish is dry-run by default).
aminet-mos-release: aminet-mos aminet-mos-publish

# Package an already-built binary (skip the slow docker build).
aminet-mos-package: aminet-mos-readme
	@test -n "$(AMINET_VERSION)" || { echo "error: no version found in package.yml"; exit 1; }
	@echo "packaging $(AMINET_MOS_NAME) $(AMINET_VERSION) (version from package.yml)"
	@test -f $(MOS_BIN) || { echo "error: $(MOS_BIN) not found — run 'make build-morphos' first"; exit 1; }
	@test -x $(AMIBERRY_HEADLESS)/run.sh || { echo "error: $(AMIBERRY_HEADLESS)/run.sh not found — set AMIBERRY_HEADLESS"; exit 1; }
	@rm -rf $(DH1_MOS_DIR) $(AMINET_MOS_LHA)
	@mkdir -p $(PKG_MOS_DIR)
	@cp $(MOS_BIN) $(PKG_MOS_DIR)/$(AMINET_NAME)
	@chmod +x $(PKG_MOS_DIR)/$(AMINET_NAME)
	@cp $(AMINET_MOS_RDM) $(PKG_MOS_DIR)/$(AMINET_MOS_NAME).readme
	@# MorphOS-specific guide (no AmiSSL/bebbossh; static TLS; no ssh).
	@cp am-git_mos.txt $(PKG_MOS_DIR)/am-git_mos.txt
	@# run.sh insists on an `app` binary in the DH1 folder (existence check
	@# only — our app_starter below runs C:LHA and never touches it).
	@cp $(MOS_BIN) $(DH1_MOS_DIR)/app
	@{ \
	  printf '%s\n' '; Auto-generated by am-git Makefile — packs the MorphOS Aminet .lha via C:LHA.'; \
	  printf '%s\n' 'cd DH1:'; \
	  printf '%s\n' 'Delete DH1:$(AMINET_MOS_NAME).lha QUIET'; \
	  printf '%s\n' 'C:LHA -r a DH1:$(AMINET_MOS_NAME).lha $(AMINET_NAME) >DH1:output.log'; \
	} > $(DH1_MOS_DIR)/app_starter
	@echo "packing $(AMINET_MOS_NAME).lha with C:LHA inside amiberry-headless ..."
	@$(AMIBERRY_HEADLESS)/run.sh $(abspath $(DH1_MOS_DIR)) > $(AMINET_DIR)/lha-mos-run.log 2>&1 || true
	@LC_ALL=C tr '\r' '\n' < $(AMINET_DIR)/lha-mos-run.log | grep -E 'files added|Operation successful|LhA Eval|[Ee]rror' || true
	@test -f $(DH1_MOS_DIR)/$(AMINET_MOS_NAME).lha || { echo "error: LhA produced no archive — see $(AMINET_DIR)/lha-mos-run.log"; exit 1; }
	@cp $(DH1_MOS_DIR)/$(AMINET_MOS_NAME).lha $(AMINET_MOS_LHA)
	@echo "packaged:"
	@echo "  $(AMINET_MOS_LHA)  ($$(wc -c < $(AMINET_MOS_LHA)) bytes)"
	@echo "  $(AMINET_MOS_RDM)"
	@echo "staged into the archive (am-git/):"
	@ls -l $(PKG_MOS_DIR)

# Produce the upload .readme from the committed am-git_mos.readme source,
# rewriting only the Version: line from package.yml (same policy as m68k).
aminet-mos-readme:
	@test -f $(AMINET_MOS_RDM_SRC) || { echo "error: $(AMINET_MOS_RDM_SRC) missing (canonical readme source)"; exit 1; }
	@mkdir -p $(AMINET_DIR)
	@sed 's/^Version:.*/Version:      $(AMINET_VERSION)/' $(AMINET_MOS_RDM_SRC) > $(AMINET_MOS_RDM)
	@echo "wrote $(AMINET_MOS_RDM) (from $(AMINET_MOS_RDM_SRC), version $(AMINET_VERSION))"

# Publish step — dry-run by default, same as the m68k target.
aminet-mos-publish:
	@test -f $(AMINET_MOS_LHA) || { echo "error: $(AMINET_MOS_LHA) not found — run 'make aminet-mos-package' first"; exit 1; }
	@test -f $(AMINET_MOS_RDM) || { echo "error: $(AMINET_MOS_RDM) not found — run 'make aminet-mos-package' first"; exit 1; }
	@echo "publish target: ftp://$(AMINET_FTP_HOST)/$(AMINET_FTP_DIR)  (user: $(AMINET_FTP_USER))"
	@echo "  $(AMINET_MOS_LHA)  ->  $(AMINET_MOS_NAME).lha"
	@echo "  $(AMINET_MOS_RDM)  ->  $(AMINET_MOS_NAME).readme"
	@if [ "$(AMINET_DRYRUN)" = "0" ]; then \
	  echo "uploading over anonymous FTP ..."; \
	  curl -sS --ftp-create-dirs -T $(AMINET_MOS_LHA) "ftp://$(AMINET_FTP_HOST)/$(AMINET_FTP_DIR)/$(AMINET_MOS_NAME).lha" --user "$(AMINET_FTP_USER):$(AMINET_FTP_PASS)" && \
	  curl -sS --ftp-create-dirs -T $(AMINET_MOS_RDM) "ftp://$(AMINET_FTP_HOST)/$(AMINET_FTP_DIR)/$(AMINET_MOS_NAME).readme" --user "$(AMINET_FTP_USER):$(AMINET_FTP_PASS)" && \
	  echo "upload complete — check the Aminet upload queue."; \
	else \
	  echo ""; \
	  echo "=== DRY RUN — nothing sent ==="; \
	  echo "Re-run to actually publish:  make aminet-mos-publish AMINET_DRYRUN=0"; \
	  echo ""; \
	  echo "Would run:"; \
	  echo "  curl -T $(AMINET_MOS_LHA) ftp://$(AMINET_FTP_HOST)/$(AMINET_FTP_DIR)/$(AMINET_MOS_NAME).lha --user $(AMINET_FTP_USER):$(AMINET_FTP_PASS)"; \
	  echo "  curl -T $(AMINET_MOS_RDM) ftp://$(AMINET_FTP_HOST)/$(AMINET_FTP_DIR)/$(AMINET_MOS_NAME).readme --user $(AMINET_FTP_USER):$(AMINET_FTP_PASS)"; \
	fi

.PHONY: aminet-mos aminet-mos-release aminet-mos-package aminet-mos-readme aminet-mos-publish
