
/*
**	tek.lib.exec - binding of TEKlib modules HAL, Exec, Time to Lua
**	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in COPYRIGHT
*/

#include <string.h>
#include <tek/debug.h>
#include <tek/teklib.h>
#include <tek/lib/tek_lua.h>
#include <tek/proto/hal.h>
#include <tek/proto/exec.h>

#include <tek/inline/exec.h>
#include <tek/mod/visual.h>
#include "lualib.h"


#define TEK_LIB_EXEC_PROGNAME "luatask"
#define TEK_LIB_EXEC_CLASSNAME "tek.lib.exec*"
#define TEK_LIB_TASK_CLASSNAME "tek.lib.exec.task*"
#define TEK_LIB_EXECBASE_NAME "TExecBase*"


struct LuaExecData
{
	struct TExecBase *exec;
	struct TTask *basetask;
};


struct LuaTaskArgs
{
	char *arg;
	size_t len;
};


struct LuaTaskContext
{ 
	struct TExecBase *exec;
	struct TTask *task;
	lua_State *L;
	TBOOL is_ref;
	int dumplen;
	char *fname;
	int status;
	int ref;
	int numargs;
	struct LuaTaskArgs *args;
};


static const struct TInitModule tek_lib_exec_initmodules[] =
{
	{"hal", tek_init_hal, TNULL, 0},
	{"exec", tek_init_exec, TNULL, 0},
	{ TNULL, TNULL, TNULL, 0 }
};


static int tek_lib_exec_base_gc(lua_State *L)
{
	struct LuaExecData *lexec = luaL_checkudata(L, 1, TEK_LIB_EXEC_CLASSNAME);
	if (lexec->exec)
	{
		TDestroy((struct THandle *) lexec->basetask);
		lexec->exec = TNULL;
	}
	return 0;
}


static TUINT tek_lib_exec_string2sig(const char *ss)
{
	TUINT sig = 0;
	int c;
	while ((c = *ss++))
	{
		switch (c)
		{
			case 'A': case 'a':
				sig |= TTASK_SIG_ABORT;
				break;
			case 'M': case 'm':
				sig |= TTASK_SIG_USER;
				break;
			case 'T': case 't':
				sig |= TTASK_SIG_TERM;
				break;
			case 'C': case 'c':
				sig |= TTASK_SIG_CHLD;
				break;
		}
	}
	return sig;
}


static char *tek_lib_exec_sig2string(char *s, TUINT sig)
{
	if (sig & TTASK_SIG_ABORT)
		*s++ = 'a';
	if (sig & TTASK_SIG_USER)
		*s++ = 'm';
	if (sig & TTASK_SIG_TERM)
		*s++ = 't';
	if (sig & TTASK_SIG_CHLD)
		*s++ = 'c';
	*s = '\0';
	return s;
}


static void tek_lib_exec_checkabort(lua_State *L, struct TExecBase *TExecBase,
	TUINT sig)
{
	if (sig & TTASK_SIG_ABORT)
	{
		TAPTR parent = (TAPTR) TGetTaskData(TNULL);
		if (parent)
			TSignal(parent, TTASK_SIG_ABORT);
		luaL_error(L, "received abort signal");
	}
}


static struct LuaExecData *tek_lib_exec_check(lua_State *L)
{
	struct LuaExecData *lexec = lua_touserdata(L, lua_upvalueindex(1));
	if (lexec->exec == TNULL)
		luaL_error(L, "closed handle");
	return lexec;
}


static int tek_lib_exec_getsignals(lua_State *L)
{
	char ss[5];
	struct LuaExecData *lexec = tek_lib_exec_check(L);
	TUINT sig = tek_lib_exec_string2sig(luaL_optstring(L, 1, "atcm"));
	sig = TExecSetSignal(lexec->exec, 0, sig);
	tek_lib_exec_checkabort(L, lexec->exec, sig);
	if (tek_lib_exec_sig2string(ss, sig) == ss)
		return 0;
	lua_pushstring(L, ss);
	return 1;
}


static int tek_lib_exec_sleep(lua_State *L)
{
	struct LuaExecData *lexec = tek_lib_exec_check(L);
	TTIME dt;
	TUINT sig;
	char ss[5];
	dt.tdt_Int64 = luaL_optnumber(L, 1, 0) * 1000;
	if (dt.tdt_Int64)
		sig = TExecWaitTime(lexec->exec, &dt, TTASK_SIG_ABORT);
	else
		sig = TExecWait(lexec->exec, TTASK_SIG_ABORT);
	tek_lib_exec_checkabort(L, lexec->exec, sig);
	tek_lib_exec_sig2string(ss, sig);
	lua_pushstring(L, ss);
	return 1;
}


static int tek_lib_exec_waittime(lua_State *L)
{
	char ss[5];
	struct LuaExecData *lexec = tek_lib_exec_check(L);
	TUINT sig = tek_lib_exec_string2sig(luaL_optstring(L, 1, "tc"));
	TTIME dt, *pdt;
	dt.tdt_Int64 = luaL_optnumber(L, 2, 0) * 1000;
	pdt = dt.tdt_Int64 ? &dt : TNULL;
	sig = TExecWaitTime(lexec->exec, pdt, sig | TTASK_SIG_ABORT);
	tek_lib_exec_checkabort(L, lexec->exec, sig);
	tek_lib_exec_sig2string(ss, sig);
	lua_pushstring(L, ss);
	return 1;
}


static int tek_lib_exec_wait(lua_State *L)
{
	char ss[5];
	struct LuaExecData *lexec = tek_lib_exec_check(L);
	TUINT sig = tek_lib_exec_string2sig(luaL_optstring(L, 1, "tc"));
	sig = TExecWait(lexec->exec, sig | TTASK_SIG_ABORT);
	tek_lib_exec_checkabort(L, lexec->exec, sig);
	tek_lib_exec_sig2string(ss, sig);
	lua_pushstring(L, ss);
	return 1;
}


static int tek_lib_exec_getmsg(lua_State *L)
{
	struct LuaExecData *lexec = tek_lib_exec_check(L);
	struct TExecBase *TExecBase = lexec->exec;
	TAPTR msg = TGetMsg(TGetUserPort(TNULL));
	int nret = 0;
	if (msg)
	{
		TSIZE size = TGetSize(msg);
		if (size)
		{
			lua_pushlstring(L, msg, size);
			nret = 1;
		}
		TAckMsg(msg);
	}
	return nret;
}


static int tek_lib_exec_waitmsg(lua_State *L)
{
	struct LuaExecData *lexec = tek_lib_exec_check(L);
	struct TExecBase *TExecBase = lexec->exec;
	TTIME dt, *ptd;
	TUINT sig;
	dt.tdt_Int64 = luaL_optnumber(L, 1, 0) * 1000;
	ptd = dt.tdt_Int64 ? &dt : TNULL;
	sig = TWaitTime(ptd, TTASK_SIG_USER | TTASK_SIG_ABORT);
	tek_lib_exec_checkabort(L, TExecBase, sig);
	return tek_lib_exec_getmsg(L);
}


static void l_message (const char *pname, const char *msg) {
  if (pname) fprintf(stderr, "%s: ", pname);
  fprintf(stderr, "%s\n", msg);
  fflush(stderr);
}


static int report (lua_State *L, int status) {
  if (status && !lua_isnil(L, -1)) {
    const char *msg = lua_tostring(L, -1);
    if (msg == NULL) msg = "(error object is not a string)";
    l_message(TEK_LIB_EXEC_PROGNAME, msg);
    lua_pop(L, 1);
  }
  return status;
}


#if LUA_VERSION_NUM < 502

static int traceback (lua_State *L) {
  if (!lua_isstring(L, 1))  /* 'message' not a string? */
    return 1;  /* keep it intact */
  lua_getfield(L, LUA_GLOBALSINDEX, "debug");
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 1;
  }
  lua_getfield(L, -1, "traceback");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 2);
    return 1;
  }
  lua_pushvalue(L, 1);  /* pass error message */
  lua_pushinteger(L, 2);  /* skip this function and traceback */
  lua_call(L, 2, 1);  /* call debug.traceback */
  return 1;
}

#else

static int msghandler (lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  if (msg == NULL) {  /* is error object not a string? */
    if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
        lua_type(L, -1) == LUA_TSTRING)  /* that produces a string? */
      return 1;  /* that is the message */
    else
      msg = lua_pushfstring(L, "(error object is a %s value)",
                               luaL_typename(L, 1));
  }
  luaL_traceback(L, L, msg, 1);  /* append a standard traceback */
  return 1;  /* return the traceback */
}

#endif


static void tek_lib_exec_getargs(lua_State *L, struct LuaTaskContext *ctx,
	int first, int narg)
{
	struct TExecBase *TExecBase = ctx->exec;
	if (narg == 0)
		return;
	ctx->args = TAlloc0(TNULL, sizeof(struct LuaTaskArgs) * narg);
	if (ctx->args == TNULL)
		luaL_error(L, "out of memory");
	ctx->numargs = narg;
	int i;
	for (i = 0; i < narg; ++i)
	{
		const char *s = lua_tolstring(L, first + i, &ctx->args[i].len);
		ctx->args[i].arg = TAlloc(TNULL, ctx->args[i].len);
		if (ctx->args[i].arg == TNULL)
			luaL_error(L, "out of memory");
		memcpy(ctx->args[i].arg, s, ctx->args[i].len);
	}
}


static void tek_lib_exec_freeargs(struct LuaTaskContext *ctx)
{
	struct TExecBase *TExecBase = ctx->exec;
	struct LuaTaskArgs *args = ctx->args;
	if (ctx->numargs > 0 && args)
	{
		int i;
		for (i = 0; i < ctx->numargs; ++i)
		{
			TFree(args->arg);
			args++->arg = TNULL;
		}
		TFree(ctx->args);
		ctx->args = TNULL;
	}
	ctx->numargs = 0;
}


static void tek_lib_exec_run_hook(lua_State *L, lua_Debug *d)
{
	lua_getfield(L, LUA_REGISTRYINDEX, TEK_LIB_EXECBASE_NAME);
	if (lua_islightuserdata(L, -1))
	{
		struct TExecBase *TExecBase = lua_touserdata(L, -1);
		tek_lib_exec_checkabort(L, TExecBase, TSetSignal(0, 0));
		lua_pop(L, 1);
	}
}


static void tek_lib_exec_register_task_hook(struct lua_State *L,
	struct TExecBase *exec)
{
	lua_pushlightuserdata(L, exec);
	lua_setfield(L, LUA_REGISTRYINDEX, TEK_LIB_EXECBASE_NAME);
	lua_sethook(L, tek_lib_exec_run_hook, LUA_MASKCOUNT, 128);
}


static int tek_lib_exec_runchild(lua_State *L)
{
	int i;
	struct LuaTaskContext *ctx = lua_touserdata(L, 1);
	struct TExecBase *TExecBase = ctx->exec;
	tek_lib_exec_register_task_hook(ctx->L, TExecBase);
	
	lua_gc(L, LUA_GCSTOP, 0);
	luaL_openlibs(L);
	lua_gc(L, LUA_GCRESTART, 0);
	
	lua_createtable(L, ctx->numargs + 1, 0);
	lua_pushvalue(L, -1);
	lua_setglobal(L, "arg");
	
	for (i = 0; i < ctx->numargs; ++i)
	{
		if (ctx->args[i].arg == TNULL)
			continue;
		lua_pushlstring(L, ctx->args[i].arg, ctx->args[i].len);
		lua_rawseti(L, -2, i + 1);
	}
	tek_lib_exec_freeargs(ctx);
	
	if (ctx->fname)
	{
		lua_pushstring(L, ctx->fname);
		lua_rawseti(L, -2, 0);
		ctx->status = luaL_loadfile(ctx->L, ctx->fname);
	}
	else if (ctx->dumplen)
		ctx->status = luaL_loadbuffer(L, (const char *) (ctx + 1), 
			ctx->dumplen, "...");
	if (ctx->status == 0)
	{
		int narg = 0;
		int base = lua_gettop(L) - narg;
#if LUA_VERSION_NUM < 502
		lua_pushcfunction(L, traceback);
#else
		lua_pushcfunction(L, msghandler);
#endif
		lua_insert(L, base);
		ctx->status = lua_pcall(L, narg, 0, base);
		lua_remove(L, base);
	}
	if (ctx->status)
		TSignal(TGetTaskData(TNULL), TTASK_SIG_ABORT);
	lua_gc(L, LUA_GCCOLLECT, 0);
	return report(L, ctx->status);
}


static THOOKENTRY TTAG
tek_lib_exec_run_dispatch(struct THook *hook, TAPTR task, TTAG msg)
{
	switch (msg)
	{
		case TMSG_INITTASK:
			return TTRUE;

		case TMSG_RUNTASK:
		{
			struct LuaTaskContext *ctx = hook->thk_Data;
			struct TExecBase *TExecBase = ctx->exec;
			TAPTR parent = (TAPTR) TGetTaskData(TNULL);
			TUINT sig = TTASK_SIG_CHLD;
			TUINT sigstate;
			int status;
			ctx->task = TFindTask(TNULL);
			lua_pushcfunction(ctx->L, &tek_lib_exec_runchild);
			lua_pushlightuserdata(ctx->L, ctx);
			status = lua_pcall(ctx->L, 1, 1, 0);
			sigstate = TSetSignal(0, 0);
			report(ctx->L, status);
			lua_close(ctx->L);
			/* error occured? or abort signal received? */
			if (status || ctx->status || (sigstate & TTASK_SIG_ABORT))
				sig |= TTASK_SIG_ABORT;
			TSignal(parent, sig);
			break;
		}
	}
	return 0;
}


static int tek_lib_exec_runtask(lua_State *L, struct LuaTaskContext *ctx)
{
	struct TExecBase *TExecBase = ctx->exec;
	struct THook hook;
	TTAGITEM tags[2];
	ctx->L = luaL_newstate();
	if (ctx->L == TNULL)
		luaL_error(L, "out of memory");
	tags[0].tti_Tag = TTask_UserData;
	tags[0].tti_Value = (TTAG) TFindTask(TNULL);
	tags[1].tti_Tag = TTAG_DONE;
	TInitHook(&hook, tek_lib_exec_run_dispatch, ctx);
	ctx->task = TCreateTask(&hook, tags);
	if (ctx->task == TNULL)
	{
		lua_pop(L, 1);
		lua_pushboolean(L, TFALSE);
		return 1;
	}
	lua_getfield(L, LUA_REGISTRYINDEX, TEK_LIB_TASK_CLASSNAME);
	lua_setmetatable(L, -2);
	lua_pushvalue(L, -1);
	ctx->ref = luaL_ref(L, lua_upvalueindex(2));
	return 1;
}


static int tek_lib_exec_runfile(lua_State *L)
{
	size_t fnamelen;
	const char *fname = luaL_checklstring(L, 1, &fnamelen);
	struct LuaExecData *lexec = tek_lib_exec_check(L);
	struct LuaTaskContext *ctx = lua_newuserdata(L,
		sizeof(struct LuaTaskContext) + fnamelen + 1);
	memset(ctx, 0, sizeof *ctx);
	ctx->fname = (char *) (ctx + 1);
	strcpy(ctx->fname, (char *) fname);
	ctx->exec = lexec->exec;
	tek_lib_exec_getargs(L, ctx, 2, lua_gettop(L) - 2);
	return tek_lib_exec_runtask(L, ctx);
}


static int tek_lib_exec_write(lua_State *L, const void *p, size_t sz, void *ud)
{
	luaL_Buffer *b = ud;
	luaL_addlstring(b, p, sz);
	return 0;
}

static int tek_lib_exec_runfunc(lua_State *L)
{
	if (!lua_isfunction(L, 1) || lua_iscfunction(L, 1))
		luaL_error(L, "not a Lua function");
	lua_pushvalue(L, 1);
	luaL_Buffer b;
	luaL_buffinit(L, &b);

#if LUA_VERSION_NUM < 503
	lua_dump(L, tek_lib_exec_write, &b);
#else
	lua_dump(L, tek_lib_exec_write, &b, 0);
#endif
	luaL_pushresult(&b);
	lua_remove(L, -2);
	
	size_t len;
	const char *s = luaL_checklstring(L, -1, &len);
	struct LuaExecData *lexec = tek_lib_exec_check(L);
	struct LuaTaskContext *ctx = lua_newuserdata(L,
		sizeof(struct LuaTaskContext) + len);
	memset(ctx, 0, sizeof *ctx);
	memcpy(ctx + 1, s, len);
	lua_remove(L, -2); /* remove chunk */
	ctx->dumplen = len;
	ctx->exec = lexec->exec;
	tek_lib_exec_getargs(L, ctx, 2, lua_gettop(L) - 2);
	return tek_lib_exec_runtask(L, ctx);
}


static int tek_lib_exec_runstring(lua_State *L)
{
	size_t len;
	const char *s = luaL_checklstring(L, 1, &len);
	struct LuaExecData *lexec = tek_lib_exec_check(L);
	struct LuaTaskContext *ctx = lua_newuserdata(L,
		sizeof(struct LuaTaskContext) + len + 1);
	memset(ctx, 0, sizeof *ctx);
	memcpy(ctx + 1, s, len);
	ctx->dumplen = len;
	ctx->exec = lexec->exec;
	tek_lib_exec_getargs(L, ctx, 2, lua_gettop(L) - 2);
	return tek_lib_exec_runtask(L, ctx);
}


static int tek_lib_exec_findparent(lua_State *L)
{
	struct LuaExecData *lexec = tek_lib_exec_check(L);
	struct TExecBase *TExecBase = lexec->exec;
	struct LuaTaskContext *ctx = lua_newuserdata(L,
		sizeof(struct LuaTaskContext));
	memset(ctx, 0, sizeof *ctx);
	ctx->exec = TExecBase;
	ctx->task = TGetTaskData(TFindTask(TNULL));
	ctx->is_ref = TTRUE;
	lua_getfield(L, LUA_REGISTRYINDEX, TEK_LIB_TASK_CLASSNAME);
	lua_setmetatable(L, -2);
	return 1;
}


static int tek_lib_exec_child_sigjoin(lua_State *L, TUINT sig)
{
	struct LuaTaskContext *ctx = luaL_checkudata(L, 1, TEK_LIB_TASK_CLASSNAME);
	if (ctx->is_ref)
		luaL_error(L, "attempt to suspend on different task");
	if (ctx->task)
	{
		if (sig)
			TExecSignal(ctx->exec, ctx->task, sig);
		TDestroy((struct THandle *) ctx->task);
		ctx->task = TNULL;
		luaL_unref(L, lua_upvalueindex(1), ctx->ref);
		tek_lib_exec_checkabort(L, ctx->exec, TExecSetSignal(ctx->exec, 0, 0));
	}
	return 0;
}


static int tek_lib_exec_child_join(lua_State *L)
{
	return tek_lib_exec_child_sigjoin(L, 0);
}


static int tek_lib_exec_child_signal(lua_State *L)
{
	struct LuaTaskContext *ctx = luaL_checkudata(L, 1, TEK_LIB_TASK_CLASSNAME);
	TUINT sig = tek_lib_exec_string2sig(luaL_optstring(L, 2, "t"));
	if (ctx->task)
		TExecSignal(ctx->exec, ctx->task, sig);
	return 0;
}


static int tek_lib_exec_child_terminate(lua_State *L)
{
	return tek_lib_exec_child_sigjoin(L, TTASK_SIG_TERM);
}


static int tek_lib_exec_child_gc(lua_State *L)
{
	struct LuaTaskContext *ctx = luaL_checkudata(L, 1, TEK_LIB_TASK_CLASSNAME);
	if (ctx->task && !ctx->is_ref)
	{
		TExecSignal(ctx->exec, ctx->task, TTASK_SIG_ABORT);
		TDestroy((struct THandle *) ctx->task);
		ctx->task = TNULL;
		tek_lib_exec_freeargs(ctx);
		luaL_unref(L, lua_upvalueindex(1), ctx->ref);
	}
	return 0;
}


static int tek_lib_exec_child_sendgui(lua_State *L)
{
	TBOOL success = TFALSE;
	struct LuaTaskContext *ctx = luaL_checkudata(L, 1, TEK_LIB_TASK_CLASSNAME);
	if (ctx->task)
	{
		struct TExecBase *TExecBase = ctx->exec;
		char atomname[256];
		size_t len;
		const char *buf = luaL_checklstring(L, 2, &len);
		sprintf(atomname, "lua.visual.iport.%p", ctx->task);
		TAPTR atom = TLockAtom(atomname, TATOMF_SHARED | TATOMF_NAME);
		if (atom)
		{
			TAPTR imsgport = (TAPTR) TGetAtomData(atom);
			if (imsgport)
			{
				TIMSG *msg = TAllocMsg0(sizeof(TIMSG) + len + 1);
				if (msg)
				{
					msg->timsg_ExtraSize = len;
					msg->timsg_Type = TITYPE_USER;
					msg->timsg_Qualifier = 0;
					msg->timsg_MouseX = -1;
					msg->timsg_MouseY = -1;
					TGetSystemTime(&msg->timsg_TimeStamp);
					memcpy(msg + 1, buf, len);
					TPutMsg(imsgport, TNULL, &msg->timsg_Node);
					success = TTRUE;
				}
			}
			TUnlockAtom(atom, TATOMF_KEEP);
		}
	}
	lua_pushboolean(L, success);
	return 1;
}


static int tek_lib_exec_child_sendmsg(lua_State *L)
{
	TBOOL success = TFALSE;
	struct LuaTaskContext *ctx = luaL_checkudata(L, 1, TEK_LIB_TASK_CLASSNAME);
	if (ctx->task)
	{
		struct TExecBase *TExecBase = ctx->exec;
		size_t len;
		const char *buf = luaL_checklstring(L, 2, &len);
		TAPTR msg = TAllocMsg(len);
		if (msg)
		{
			memcpy(msg, buf, len);
			TPutMsg(TGetUserPort(ctx->task), TNULL, msg);
			success = TTRUE;
		}
	}
	lua_pushboolean(L, success);
	return 1;
}


static const luaL_Reg tek_lib_exec_child_methods[] =
{
	{ "__gc", tek_lib_exec_child_gc },
	{ "abort", tek_lib_exec_child_gc },
	{ "signal", tek_lib_exec_child_signal },
	{ "join", tek_lib_exec_child_join },
	{ "sendgui", tek_lib_exec_child_sendgui },
	{ "sendmsg", tek_lib_exec_child_sendmsg },
	{ "terminate", tek_lib_exec_child_terminate },
	{ TNULL, TNULL }
};


static const luaL_Reg tek_lib_exec_funcs[] =
{
	{ "sleep", tek_lib_exec_sleep },
	{ "runfile", tek_lib_exec_runfile },
	{ "runstring", tek_lib_exec_runstring },
	{ "run", tek_lib_exec_runfunc },
	{ "findparent", tek_lib_exec_findparent },
	{ "wait", tek_lib_exec_wait },
	{ "waittime", tek_lib_exec_waittime },
	{ "getmsg", tek_lib_exec_getmsg },
	{ "waitmsg", tek_lib_exec_waitmsg },
	{ "getsignals", tek_lib_exec_getsignals },
	{ TNULL, TNULL }
};


static const luaL_Reg tek_lib_exec_methods[] =
{
	{ "__gc", tek_lib_exec_base_gc },
	{ TNULL, TNULL }
};


TMODENTRY int luaopen_tek_lib_exec(lua_State *L)
{
	struct LuaExecData *lexec;
	TTAGITEM tags[2];
	
	luaL_newmetatable(L, TEK_LIB_EXEC_CLASSNAME);
	tek_lua_register(L, NULL, tek_lib_exec_methods, 0);
	/* execmeta */

	luaL_newmetatable(L, TEK_LIB_TASK_CLASSNAME);
	/* execmeta, taskmeta */
	lua_pushvalue(L, -2);
	/* execmeta, taskmeta, execmeta */
	tek_lua_register(L, NULL, tek_lib_exec_child_methods, 1);
	lua_pushvalue(L, -1);
	/* execmeta, taskmeta, taskmeta */
	lua_setfield(L, -2, "__index");
	lua_pop(L, 1);
	/* execmeta */
	
	lexec = lua_newuserdata(L, sizeof(struct LuaExecData));
	/* execmeta, luaexec */
	lexec->exec = TNULL;
	lua_pushvalue(L, -1);
	/* execmeta, luaexec, luaexec */
	lua_pushvalue(L, -3);
	/* execmeta, luaexec, luaexec, execmeta */
	tek_lua_register(L, "tek.lib.exec", tek_lib_exec_funcs, 2);
	/* execmeta, luaexec, libtab */

	lua_pushvalue(L, -2);
	/* execmeta, luaexec, libtab, libtab */
	lua_pushvalue(L, -4);
	/* execmeta, luaexec, libtab, libtab, execmeta */
	lua_remove(L, -4);
	lua_remove(L, -4);
	/* libtab, libtab, execmeta */

	lua_setmetatable(L, -2);
	/* libtab, libtab */
	lua_setfield(L, -2, "base");
	/* libtab */

	tags[0].tti_Tag = TExecBase_ModInit;
	tags[0].tti_Value = (TTAG) tek_lib_exec_initmodules;
	tags[1].tti_Tag = TTAG_DONE;

	lexec->basetask = TEKCreate(tags);
	if (lexec->basetask == TNULL)
		luaL_error(L, "Failed to initialize TEKlib");
	lexec->exec = TGetExecBase(lexec->basetask);
	
	/* tek_lib_exec_register_task_hook(L, lexec->exec); */
	
	return 1;
}
