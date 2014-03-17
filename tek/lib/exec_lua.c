
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

static const struct TInitModule tek_lib_exec_initmodules[] =
{
	{"hal", tek_init_hal, TNULL, 0},
	{"exec", tek_init_exec, TNULL, 0},
	{ TNULL, TNULL, TNULL, 0 }
};

static const luaL_Reg tek_lib_exec_funcs[] =
{
	{NULL, NULL}
};

static int tek_lib_exec_base_gc(lua_State *L)
{
	TAPTR *pexec = luaL_checkudata(L, 1, "tek.lib.exec.base.meta");
	if (*pexec)
	{
		TAPTR basetask = TExecFindTask(*pexec, TTASKNAME_ENTRY);
		TDestroy(basetask);
		TDBPRINTF(5,("Exec closed\n"));
		*pexec = TNULL;
	}
	return 0;
}

TMODENTRY int luaopen_tek_lib_exec(lua_State *L)
{
	TAPTR *pexec;
	TTAGITEM tags[2];
	TAPTR basetask;

	tek_lua_register(L, "tek.lib.exec", NULL, 0);
	/* s: libtab */
	pexec = lua_newuserdata(L, sizeof(TAPTR));
	/* s: libtab, udata */
	*pexec = TNULL;

	luaL_newmetatable(L, "tek.lib.exec.base.meta");
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

	basetask = TEKCreate(tags);
	if (basetask == TNULL)
		luaL_error(L, "Failed to initialize TEKlib");

	*pexec = TGetExecBase(basetask);
	
	return 1;
}
