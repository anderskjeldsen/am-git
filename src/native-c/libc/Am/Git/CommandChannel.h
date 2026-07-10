#pragma once
#include <libc/core.h>
#include <Am/Git/CommandChannel.h>
#include <Am/Lang/Object.h>

// Per-channel native state: the parent-side socketpair fd and the child
// pid we spawned. A pointer to this lives in the aobject's object_data
// custom_value slot (CommandChannel has no AmLang fields, so that slot is
// ours). fd == -1 means closed.
struct _command_channel {
	int fd;
	int pid;
};
typedef struct _command_channel command_channel;

function_result Am_Git_CommandChannel_spawnNative_0(aobject * const this, aobject * argvLine);
function_result Am_Git_CommandChannel_read_0(aobject * const this, aobject * data, const long long offset, const unsigned int length);
function_result Am_Git_CommandChannel_write_0(aobject * const this, aobject * data, const long long offset, const unsigned int length);
function_result Am_Git_CommandChannel_closeWrite_0(aobject * const this);
function_result Am_Git_CommandChannel_close_0(aobject * const this);
