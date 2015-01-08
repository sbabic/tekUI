
/*
**	tek.lib.exec - binding of TEKlib modules HAL, Exec, Time to Lua
**	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in COPYRIGHT
*/

#include <tek/debug.h>
#include <tek/teklib.h>
#include <tek/lib/tek_lua.h>
#include <tek/proto/hal.h>
#include <tek/proto/exec.h>


struct LuaExecData
{
	struct TExecBase *exec;
	struct TTask *basetask;
};


static const struct TInitModule tek_lib_exec_initmodules[] =
{
	{"hal", tek_init_hal, TNULL, 0},
	{"exec", tek_init_exec, TNULL, 0},
	{ TNULL, TNULL, TNULL, 0 }
};


static int tek_lib_exec_base_gc(lua_State *L)
{
	struct LuaExecData *lexec = luaL_checkudata(L, 1, "tek.lib.exec*");
	if (lexec->exec)
	{
		TDestroy((struct THandle *) lexec->basetask);
		lexec->exec = TNULL;
	}
	return 0;
}


static int tek_lib_exec_sleep(lua_State *L)
{
	struct LuaExecData *lexec = lua_touserdata(L, lua_upvalueindex(1));
	TTIME dt;
	if (lexec->exec == TNULL)
		luaL_error(L, "closed handle");
	dt.tdt_Int64 = luaL_checknumber(L, 1) * 1000;
	TExecWaitTime(lexec->exec, &dt, 0);
	return 0;
}


static const luaL_Reg tek_lib_exec_funcs[] =
{
	{ "sleep", tek_lib_exec_sleep },
	{ TNULL, TNULL }
};


TMODENTRY int luaopen_tek_lib_exec(lua_State *L)
{
	struct LuaExecData *lexec;
	TTAGITEM tags[2];

	lexec = lua_newuserdata(L, sizeof(struct LuaExecData));
	lexec->exec = TNULL;
	/* s: udata */
	lua_pushvalue(L, -1);
	/* s: udata, udata */
	tek_lua_register(L, "tek.lib.exec", tek_lib_exec_funcs, 1);
	/* s: udata, libtab */

	lua_pushvalue(L, -2);
	/* s: udata, libtab, udata */
	lua_remove(L, -3);
	/* s: libtab, udata */

	luaL_newmetatable(L, "tek.lib.exec*");
	/* s: libtab, udata, metatable */
	lua_pushliteral(L, "__gc");
	/* s: libtab, udata, metatable, "__gc" */
	lua_pushcfunction(L, tek_lib_exec_base_gc);
	/* s: libtab, udata, metatable, "__gc", gcfunc */
	lua_rawset(L, -3);
	/* s: libtab, udata, metatable */
	lua_setmetatable(L, -2);
	/* s: libtab, udata */
	lua_setfield(L, -2, "base");
	/* s: libtab */

	tags[0].tti_Tag = TExecBase_ModInit;
	tags[0].tti_Value = (TTAG) tek_lib_exec_initmodules;
	tags[1].tti_Tag = TTAG_DONE;

	lexec->basetask = TEKCreate(tags);
	if (lexec->basetask == TNULL)
		luaL_error(L, "Failed to initialize TEKlib");
	lexec->exec = TGetExecBase(lexec->basetask);
	
	return 1;
}
