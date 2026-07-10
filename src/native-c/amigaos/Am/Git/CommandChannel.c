#include <libc/core.h>
#include <Am/Git/CommandChannel.h>
#include <amigaos/Am/Git/CommandChannel.h>
#include <Am/Lang/ClassRef.h>
#include <Am/Lang/Object.h>
#include <Am/Lang/String.h>
#include <Am/Lang/UInt.h>
#include <Am/Lang/UByte.h>
#include <Am/Lang/Array.h>
#include <Am/Lang/Long.h>
#include <Am/Lang/Int.h>
#include <Am/Lang/Exception.h>
#include <Am/Lang/Bool.h>
#include <Am/Collections/List.h>
#include <libc/core_inline_functions.h>

function_result Am_Git_CommandChannel__native_init_0(aobject * const this)
{
	function_result __result = { .has_return_value = false };
	bool __returning = false;
	__increase_reference_count(this);
__exit: ;
	__decrease_reference_count(this);
	return __result;
}

function_result Am_Git_CommandChannel__native_release_0(aobject * const this)
{
	function_result __result = { .has_return_value = false };
	bool __returning = false;
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

function_result Am_Git_CommandChannel_spawnNative_0(aobject * const this, aobject * argvLine)
{
	function_result __result = { .has_return_value = false };
	bool __returning = false;
	__increase_reference_count(this);
	if (argvLine != NULL) {
		__increase_reference_count(argvLine);
	}
__exit: ;
	__decrease_reference_count(this);
	if (argvLine != NULL) {
		__decrease_reference_count(argvLine);
	}
	return __result;
}

function_result Am_Git_CommandChannel_read_0(aobject * const this, aobject * data, long long offset, unsigned int length)
{
	function_result __result = { .has_return_value = true };
	bool __returning = false;
	__increase_reference_count(this);
	if (data != NULL) {
		__increase_reference_count(data);
	}
__exit: ;
	__decrease_reference_count(this);
	if (data != NULL) {
		__decrease_reference_count(data);
	}
	return __result;
}

function_result Am_Git_CommandChannel_write_0(aobject * const this, aobject * data, long long offset, unsigned int length)
{
	function_result __result = { .has_return_value = true };
	bool __returning = false;
	__increase_reference_count(this);
	if (data != NULL) {
		__increase_reference_count(data);
	}
__exit: ;
	__decrease_reference_count(this);
	if (data != NULL) {
		__decrease_reference_count(data);
	}
	return __result;
}

function_result Am_Git_CommandChannel_closeWrite_0(aobject * const this)
{
	function_result __result = { .has_return_value = false };
	bool __returning = false;
	__increase_reference_count(this);
__exit: ;
	__decrease_reference_count(this);
	return __result;
}

function_result Am_Git_CommandChannel_close_0(aobject * const this)
{
	function_result __result = { .has_return_value = true };
	bool __returning = false;
	__increase_reference_count(this);
__exit: ;
	__decrease_reference_count(this);
	return __result;
}

