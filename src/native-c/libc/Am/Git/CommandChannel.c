#include <libc/core.h>
#include <Am/Git/CommandChannel.h>
#include <libc/Am/Git/CommandChannel.h>
#include <Am/Lang/String.h>
#include <Am/Lang/Object.h>
#include <libc/core_inline_functions.h>

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/wait.h>

// The ssh git transport spawns `ssh <host> git-upload-pack '<path>'` and
// streams the pkt-line pack protocol over a socketpair — plain pipes, no
// pty, so the binary packfile passes through byte-for-byte. This mirrors
// how real git drives ssh. See CommandChannel.aml for the AmLang side.

#define AM_GIT_CHAN_MAX_ARGS 128

static command_channel *chan_of(aobject *this) {
	return (command_channel *) this->object_properties.class_object_properties.object_data.value.custom_value;
}

function_result Am_Git_CommandChannel__native_init_0(aobject * const this)
{
	function_result __result = { .has_return_value = false };
	bool __returning = false;
	// object_data starts zeroed, so custom_value == NULL until spawn.
__exit: ;
	return __result;
}

function_result Am_Git_CommandChannel__native_mark_children_0(aobject * const this)
{
	function_result __result = { .has_return_value = false };
	bool __returning = false;
__exit: ;
	return __result;
}

// GC backstop: if a channel is dropped without close(), close the fd and
// reap the child so we don't leak descriptors or leave a zombie.
function_result Am_Git_CommandChannel__native_release_0(aobject * const this)
{
	function_result __result = { .has_return_value = false };
	bool __returning = false;
	command_channel *ch = chan_of(this);
	if (ch != NULL) {
		if (ch->fd >= 0) {
			shutdown(ch->fd, SHUT_RDWR);
			close(ch->fd);
			ch->fd = -1;
		}
		if (ch->pid > 0) {
			int status = 0;
			waitpid(ch->pid, &status, 0);
			ch->pid = -1;
		}
		free(ch);
		this->object_properties.class_object_properties.object_data.value.custom_value = NULL;
	}
__exit: ;
	return __result;
}

// spawnNative(argvLine): argvLine is the argv joined by '\n'. We split it
// in place, socketpair(), fork(), and in the child dup the socket onto fd
// 0 and 1 before execvp. stderr is left inherited so ssh prompts and
// diagnostics reach the user's terminal.
function_result Am_Git_CommandChannel_spawnNative_0(aobject * const this, aobject * argvLine)
{
	function_result __result = { .has_return_value = false };
	bool __returning = false;
	if (this != NULL) {
		__increase_reference_count(this);
	}
	if (argvLine != NULL) {
		__increase_reference_count(argvLine);
	}

	string_holder *line_holder = (string_holder *) (argvLine + 1);
	char *buf = strdup(line_holder->string_value);
	if (buf == NULL) {
		__throw_simple_exception("Out of memory", "in Am_Git_CommandChannel_spawnNative_0", &__result);
		goto __exit;
	}

	// Split the '\n'-joined line into a NULL-terminated argv, in place.
	char *argv[AM_GIT_CHAN_MAX_ARGS];
	int argc = 0;
	char *p = buf;
	char *start = buf;
	while (1) {
		if (*p == '\n' || *p == '\0') {
			int last = (*p == '\0');
			*p = '\0';
			if (argc < AM_GIT_CHAN_MAX_ARGS - 1) {
				argv[argc++] = start;
			}
			start = p + 1;
			if (last) break;
		}
		p++;
	}
	argv[argc] = NULL;

	if (argc == 0) {
		free(buf);
		__throw_simple_exception("CommandChannel: empty argv", "in Am_Git_CommandChannel_spawnNative_0", &__result);
		goto __exit;
	}

	int sv[2];
	if (socketpair(AF_UNIX, SOCK_STREAM, 0, sv) != 0) {
		free(buf);
		__throw_simple_exception("CommandChannel: socketpair failed", "in Am_Git_CommandChannel_spawnNative_0", &__result);
		goto __exit;
	}

	pid_t pid = fork();
	if (pid < 0) {
		close(sv[0]);
		close(sv[1]);
		free(buf);
		__throw_simple_exception("CommandChannel: fork failed", "in Am_Git_CommandChannel_spawnNative_0", &__result);
		goto __exit;
	}

	if (pid == 0) {
		// Child: wire our end of the socketpair to stdin + stdout,
		// leave stderr inherited, then exec. _exit(127) if exec fails
		// (the parent sees the channel EOF + the 127 exit code).
		dup2(sv[1], 0);
		dup2(sv[1], 1);
		if (sv[0] > 2) close(sv[0]);
		if (sv[1] > 2) close(sv[1]);
		execvp(argv[0], argv);
		_exit(127);
	}

	// Parent.
	close(sv[1]);
	free(buf);

	// A dead child mid-write must return EPIPE, not kill us with SIGPIPE.
	signal(SIGPIPE, SIG_IGN);

	command_channel *ch = (command_channel *) malloc(sizeof(command_channel));
	if (ch == NULL) {
		close(sv[0]);
		__throw_simple_exception("Out of memory", "in Am_Git_CommandChannel_spawnNative_0", &__result);
		goto __exit;
	}
	ch->fd = sv[0];
	ch->pid = (int) pid;
	this->object_properties.class_object_properties.object_data.value.custom_value = ch;

__exit: ;
	if (this != NULL) {
		__decrease_reference_count(this);
	}
	if (argvLine != NULL) {
		__decrease_reference_count(argvLine);
	}
	return __result;
}

function_result Am_Git_CommandChannel_read_0(aobject * const this, aobject * data, const long long offset, const unsigned int length)
{
	function_result __result = { .has_return_value = true };
	bool __returning = false;
	if (this != NULL) {
		__increase_reference_count(this);
	}
	if (data != NULL) {
		__increase_reference_count(data);
	}

	command_channel *ch = chan_of(this);
	if (ch == NULL || ch->fd < 0) {
		__throw_simple_exception("CommandChannel: read on closed channel", "in Am_Git_CommandChannel_read_0", &__result);
		goto __exit;
	}

	array_holder *a_holder = (array_holder *) &data[1];
	if ((unsigned long long) offset + length > a_holder->size) {
		__throw_simple_exception("CommandChannel: read length exceeds array", "in Am_Git_CommandChannel_read_0", &__result);
		goto __exit;
	}

	ssize_t n = read(ch->fd, a_holder->array_data + offset, length);
	if (n < 0) {
		__throw_simple_exception("CommandChannel: read error", "in Am_Git_CommandChannel_read_0", &__result);
		goto __exit;
	}

	__result.return_value.value.uint_value = (unsigned int) n;
	__result.return_value.flags = PRIMITIVE_UINT;

__exit: ;
	if (this != NULL) {
		__decrease_reference_count(this);
	}
	if (data != NULL) {
		__decrease_reference_count(data);
	}
	return __result;
}

function_result Am_Git_CommandChannel_write_0(aobject * const this, aobject * data, const long long offset, const unsigned int length)
{
	function_result __result = { .has_return_value = true };
	bool __returning = false;
	if (this != NULL) {
		__increase_reference_count(this);
	}
	if (data != NULL) {
		__increase_reference_count(data);
	}

	command_channel *ch = chan_of(this);
	if (ch == NULL || ch->fd < 0) {
		__throw_simple_exception("CommandChannel: write on closed channel", "in Am_Git_CommandChannel_write_0", &__result);
		goto __exit;
	}

	array_holder *a_holder = (array_holder *) &data[1];
	if ((unsigned long long) offset + length > a_holder->size) {
		__throw_simple_exception("CommandChannel: write length exceeds array", "in Am_Git_CommandChannel_write_0", &__result);
		goto __exit;
	}

	ssize_t n = write(ch->fd, a_holder->array_data + offset, length);
	if (n < 0) {
		__throw_simple_exception("CommandChannel: write error", "in Am_Git_CommandChannel_write_0", &__result);
		goto __exit;
	}

	__result.return_value.value.uint_value = (unsigned int) n;
	__result.return_value.flags = PRIMITIVE_UINT;

__exit: ;
	if (this != NULL) {
		__decrease_reference_count(this);
	}
	if (data != NULL) {
		__decrease_reference_count(data);
	}
	return __result;
}

function_result Am_Git_CommandChannel_closeWrite_0(aobject * const this)
{
	function_result __result = { .has_return_value = false };
	bool __returning = false;
	if (this != NULL) {
		__increase_reference_count(this);
	}

	command_channel *ch = chan_of(this);
	if (ch != NULL && ch->fd >= 0) {
		shutdown(ch->fd, SHUT_WR);
	}

	if (this != NULL) {
		__decrease_reference_count(this);
	}
	return __result;
}

function_result Am_Git_CommandChannel_close_0(aobject * const this)
{
	function_result __result = { .has_return_value = true };
	bool __returning = false;
	if (this != NULL) {
		__increase_reference_count(this);
	}

	int exit_code = 0;
	command_channel *ch = chan_of(this);
	if (ch != NULL) {
		if (ch->fd >= 0) {
			shutdown(ch->fd, SHUT_RDWR);
			close(ch->fd);
			ch->fd = -1;
		}
		if (ch->pid > 0) {
			int status = 0;
			if (waitpid(ch->pid, &status, 0) == ch->pid) {
#ifdef WEXITSTATUS
				if (WIFEXITED(status)) {
					exit_code = WEXITSTATUS(status);
				} else {
					exit_code = -1;
				}
#else
				exit_code = status;
#endif
			}
			ch->pid = -1;
		}
		free(ch);
		this->object_properties.class_object_properties.object_data.value.custom_value = NULL;
	}

	__result.return_value.value.int_value = exit_code;
	__result.return_value.flags = PRIMITIVE_INT;

	if (this != NULL) {
		__decrease_reference_count(this);
	}
	return __result;
}
