
/*
**	tek.lib.support - C support library
*/

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <stdint.h>

#define TEK_LIB_SUPPORT_NAME    "tek.lib.support*"
#define TEK_LIB_SUPPORT_VERSION "Support Library 4.0"

typedef uint32_t flags_t;

/*****************************************************************************/

static int tek_lib_support_checkanyflags(lua_State *L)
{
	flags_t f = luaL_checkinteger(L, 1);
	flags_t mf = luaL_checkinteger(L, 2);
	lua_pushboolean(L, f & mf);
	return 1;
}

static int tek_lib_support_newflags(lua_State *L)
{
	flags_t inif = luaL_optinteger(L, 1, 0);
	flags_t *f = lua_newuserdata(L, sizeof(flags_t));
	*f = inif;
	lua_getfield(L, LUA_REGISTRYINDEX, TEK_LIB_SUPPORT_NAME);
	lua_setmetatable(L, -2);
	return 1;
}

static int tek_lib_support_flags_check(lua_State *L)
{
	flags_t *f = luaL_checkudata(L, 1, TEK_LIB_SUPPORT_NAME);
	flags_t nf = luaL_checkinteger(L, 2);
	lua_pushboolean(L, (*f & nf) == nf);
	return 1;
}

static int tek_lib_support_flags_clear(lua_State *L)
{
	flags_t *f = luaL_checkudata(L, 1, TEK_LIB_SUPPORT_NAME);
	*f &= ~luaL_checkinteger(L, 2);
	lua_pushinteger(L, *f);
	return 1;
}

static int tek_lib_support_flags_set(lua_State *L)
{
	flags_t *f = luaL_checkudata(L, 1, TEK_LIB_SUPPORT_NAME);
	*f |= luaL_checkinteger(L, 2);
	lua_pushinteger(L, *f);
	return 1;
}

static int tek_lib_support_flags_get(lua_State *L)
{
	flags_t *f = luaL_checkudata(L, 1, TEK_LIB_SUPPORT_NAME);
	flags_t mf = luaL_optinteger(L, 2, 0x7fffffff);
	lua_pushinteger(L, *f & mf);
	return 1;
}

static int tek_lib_support_flags_checkany(lua_State *L)
{
	flags_t *f = luaL_checkudata(L, 1, TEK_LIB_SUPPORT_NAME);
	flags_t mf = luaL_checkinteger(L, 2);
	lua_pushboolean(L, *f & mf);
	return 1;
}

static int tek_lib_support_flags_checkclear(lua_State *L)
{
	flags_t *f = luaL_checkudata(L, 1, TEK_LIB_SUPPORT_NAME);
	flags_t chkf = luaL_checkinteger(L, 2);
	flags_t clrf = luaL_optinteger(L, 3, chkf);
	lua_pushboolean(L, (*f & chkf) == chkf);
	*f &= ~clrf;
	return 1;
}

/*****************************************************************************/

static const int srcidx = -1;
static const int dstidx = -2;

static void tek_lib_support_copytable_r(lua_State *L)
{
	lua_pushnil(L);
	/* s: nil, src, dst */
	while (lua_next(L, srcidx - 1) != 0)
	{
		/* s: val, key, src, dst */
		lua_pushvalue(L, -2);
		/* s: key, val, key, src, dst */
		lua_insert(L, -2);
		/* s: val, key, key, src, dst */
		
		if (lua_type(L, -1) == LUA_TTABLE)
		{
			lua_newtable(L);
			/* s: dst2, val=src2, key, key, src, dst */
			lua_insert(L, -2);
			/* s: val=src2, dst2, key, key, src, dst */
			tek_lib_support_copytable_r(L);
			/* s: src2, dst2, key, key, src, dst */
			lua_pop(L, 1);
			/* s: val=dst2, key, key, src, dst */
		}
		
		/* s: val, key, key, src, dst */
		lua_rawset(L, dstidx - 3);
		/* s: key, src, dst */
	}
	/* s: src, dst */
}

static int tek_lib_support_copytable(lua_State *L)
{
	lua_pushvalue(L, 2);
	lua_pushvalue(L, 1);
	/* s: src, dst */
	tek_lib_support_copytable_r(L);
	lua_pop(L, 1);
	return 1;
}

static int tek_lib_support_get4ints(lua_State *L)
{
	lua_Integer a1, a2, a3, a4;
	a1 = lua_tointeger(L, -4);
	a2 = lua_tointeger(L, -3);
	a3 = lua_tointeger(L, -2);
	a4 = lua_tointeger(L, -1);
	lua_pop(L, 4);
	lua_pushinteger(L, a1);
	lua_pushinteger(L, a2);
	lua_pushinteger(L, a3);
	lua_pushinteger(L, a4);
	return 4;
}

static int tek_lib_support_getmargin(lua_State *L)
{
	lua_getfield(L, 1, "margin-left");
	lua_getfield(L, 1, "margin-top");
	lua_getfield(L, 1, "margin-right");
	lua_getfield(L, 1, "margin-bottom");
	return tek_lib_support_get4ints(L);
}

static int tek_lib_support_getpadding(lua_State *L)
{
	lua_getfield(L, 1, "padding-left");
	lua_getfield(L, 1, "padding-top");
	lua_getfield(L, 1, "padding-right");
	lua_getfield(L, 1, "padding-bottom");
	return tek_lib_support_get4ints(L);
}

static int tek_lib_support_getborder(lua_State *L)
{
	lua_getfield(L, 1, "border-left-width");
	lua_getfield(L, 1, "border-top-width");
	lua_getfield(L, 1, "border-right-width");
	lua_getfield(L, 1, "border-bottom-width");
	return tek_lib_support_get4ints(L);
}

/*****************************************************************************/

static const luaL_Reg tek_lib_support_funcs[] =
{
	{ "checkAnyFlags", tek_lib_support_checkanyflags },
	{ "newFlags", tek_lib_support_newflags },
	{ "copyTable", tek_lib_support_copytable },
	{ "getMargin", tek_lib_support_getmargin },
	{ "getPadding", tek_lib_support_getpadding },
	{ "getBorder", tek_lib_support_getborder },
	{ NULL, NULL }
};

static const luaL_Reg tek_lib_support_flags_methods[] =
{
	{ "check", tek_lib_support_flags_check },
	{ "clear", tek_lib_support_flags_clear },
	{ "set", tek_lib_support_flags_set },
	{ "get", tek_lib_support_flags_get },
	{ "checkAny", tek_lib_support_flags_checkany },
	{ "checkClear", tek_lib_support_flags_checkclear },
	{ NULL, NULL }
};

int luaopen_tek_lib_support(lua_State *L)
{
#if LUA_VERSION_NUM < 502
	luaL_register(L, "tek.lib.support", tek_lib_support_funcs);
#else
	luaL_newlib(L, tek_lib_support_funcs);
#endif
	lua_pushstring(L, TEK_LIB_SUPPORT_VERSION);
	lua_setfield(L, -2, "_VERSION");
	luaL_newmetatable(L, TEK_LIB_SUPPORT_NAME);
#if LUA_VERSION_NUM < 502
	luaL_register(L, NULL, tek_lib_support_flags_methods);
#else
	luaL_setfuncs(L, tek_lib_support_flags_methods, 0);
#endif
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");
	lua_pop(L, 1);
	return 1;
}
