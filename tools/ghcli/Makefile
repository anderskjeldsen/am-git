# ghcli - GitHub CLI POC. Same conventions as am-git's Makefile.
#
# Always the WORKSPACE-ROOT amlc.jar; a per-project copy goes stale and
# then fails to parse newer package.yml files.
AMLC:=../../../amlc.jar
CMD=java -jar $(AMLC)

# -lpp ../../.. points amlc at the sibling checkouts of am-lang-core,
# am-net, am-ssl, am-json and am-web-client in the workspace root,
# instead of pulling the GitHub copies named in package.yml.
LPP := -lpp ../../..

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

# Named explicitly (rather than relying on `build` picking the host) so the
# extensions Makefile can map a platform id onto a target the same way it does
# for am-git.
build-macos:
	$(CMD) build . -bt macos -ll5 -maxOneError $(LPP)

build-macos-arm:
	$(CMD) build . -bt macos-arm -ll5 -maxOneError $(LPP)

# Only the object dir - never wipe builds/ wholesale, the makefiles and
# generated C in there are what incremental builds key off.
clean:
	rm -rf builds/bin/$(HOST_BT)/o

.PHONY: build build-linux-x64 build-amigaos build-morphos build-macos build-macos-arm clean
