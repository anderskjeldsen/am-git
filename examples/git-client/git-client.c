/*
 * git-client -- minimal AmigaOS C harness that runs `am-git` and forwards
 * its output to this program's own stdout.
 *
 * Usage:   git-client <any am-git arguments>
 * Example: git-client status --porcelain
 *
 * Pure dos.library, no stdio: the command line is handed to SystemTagList()
 * with SYS_UserShell, so the name `am-git` is resolved exactly the way a
 * typed shell line resolves it -- current directory first, then the path
 * list, then C:. The child's stdout goes to a RELATIVE temp file via the
 * shell's own `>` redirect (no T:/RAM: assign needed); the file is then
 * copied to Output() and deleted, and am-git's return code becomes ours.
 *
 * This is the same capture pattern the IDE's git integration needs, reduced
 * to a page of C so recipe changes can be tried here first (amiberry rig)
 * before they go anywhere near the natives.
 */
#include <exec/types.h>
#include <dos/dos.h>
#include <dos/dostags.h>
#include <proto/dos.h>
#include <string.h>

#define TMPNAME "gc_out.tmp"

static void append(char *dst, LONG dstsize, LONG *used, const char *src)
{
	LONG u = *used;
	while (*src != '\0' && u < dstsize - 1) {
		dst[u++] = *src++;
	}
	dst[u] = '\0';
	*used = u;
}

int main(int argc, char **argv)
{
	static char cmd[1024];
	LONG used = 0;
	LONG rc;
	BPTR fh;
	int i;

	append(cmd, sizeof(cmd), &used, "am-git");
	for (i = 1; i < argc; i++) {
		/* Quote anything with a space so multi-word args survive. */
		int spaced = (strchr(argv[i], ' ') != NULL);
		append(cmd, sizeof(cmd), &used, spaced ? " \"" : " ");
		append(cmd, sizeof(cmd), &used, argv[i]);
		if (spaced) {
			append(cmd, sizeof(cmd), &used, "\"");
		}
	}
	append(cmd, sizeof(cmd), &used, " >" TMPNAME);

	{
		struct TagItem tags[] = {
			{ SYS_Asynch,    FALSE },
			{ SYS_UserShell, TRUE  },
			{ TAG_DONE,      0     },
		};
		rc = SystemTagList((STRPTR) cmd, tags);
	}

	fh = Open((CONST_STRPTR) TMPNAME, MODE_OLDFILE);
	if (fh == (BPTR) NULL) {
		/* The shell already printed its own complaint (e.g. "am-git:
		   Unknown command") through our inherited stream; this line just
		   marks that no capture happened. */
		static const char msg[] = "git-client: no output file (command did not run?)\n";
		Write(Output(), (APTR) msg, (LONG) strlen(msg));
		return RETURN_FAIL;
	}
	{
		static UBYTE buf[512];
		LONG n;
		while ((n = Read(fh, buf, sizeof(buf))) > 0) {
			Write(Output(), buf, n);
		}
	}
	Close(fh);
	DeleteFile((CONST_STRPTR) TMPNAME);
	return (int) rc;
}
