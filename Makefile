# place amlc.jar in this folder or change value.
AMLC:=amlc.jar
CMD=java -jar $(AMLC)
LOGLEVEL:=1

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
	$(CMD) build . -bt $(HOST_BT) -ll5 -maxOneError

build-linux-x64:
	$(CMD) build . -bt linux-x64 -ll5 -maxOneError

build-amigaos:
	$(CMD) build . -bt amigaos_docker -ll5

build-macos:
	$(CMD) build . -bt macos -ll5 -maxOneError

build-macos-arm:
	$(CMD) build . -bt macos-arm -ll5 -maxOneError

build-force-deps:
	$(CMD) build . -fld -bt $(HOST_BT) -ll5

run:
	$(CMD) run . -bt $(HOST_BT) -ll $(LOGLEVEL)

clean:
	rm -rf builds
