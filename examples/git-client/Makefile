# Cross-build git-client for AmigaOS m68k via the amiga-gcc docker image.
# (AmigaOS-only source: pure dos.library, no host build.)
all: git-client

git-client: git-client.c
	docker run --rm -v "$(CURDIR):/src" -w /src amiga-gcc:latest \
		m68k-amigaos-gcc -noixemul -O2 -o git-client git-client.c

clean:
	rm -f git-client gc_out.tmp
