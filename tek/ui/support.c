
/*
**	tek.ui.support - internal C support library
**	This library should be transitory and vanish with Lua 5.2
**	or with an Element or Area class entirely written in C.
*/

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <tek/lib/tekui.h>

#define TEK_UI_SUPPORT_VERSION	"UI Support Library 2.0"

/*****************************************************************************/

static int tek_ui_support_newflags(lua_State *L)
{
	tekui_flags inif = luaL_optinteger(L, 1, 0);
	tekui_flags *f = lua_newuserdata(L, sizeof(tekui_flags));
	*f = inif;
	lua_getfield(L, LUA_REGISTRYINDEX, TEK_UI_SUPPORT_NAME);
	lua_setmetatable(L, -2);
	return 1;
}

static int tek_ui_support_chkflags(lua_State *L)
{
	tekui_flags *f = luaL_checkudata(L, 1, TEK_UI_SUPPORT_NAME);
	tekui_flags nf = luaL_checkinteger(L, 2);
	lua_pushboolean(L, (*f & nf) == nf);
	return 1;
}

static int tek_ui_support_clrflags(lua_State *L)
{
	tekui_flags *f = luaL_checkudata(L, 1, TEK_UI_SUPPORT_NAME);
	*f &= ~luaL_checkinteger(L, 2);
	lua_pushinteger(L, *f);
	return 1;
}

static int tek_ui_support_setflags(lua_State *L)
{
	tekui_flags *f = luaL_checkudata(L, 1, TEK_UI_SUPPORT_NAME);
	*f |= luaL_checkinteger(L, 2);
	lua_pushinteger(L, *f);
	return 1;
}

static int tek_ui_support_chkclrflags(lua_State *L)
{
	tekui_flags *f = luaL_checkudata(L, 1, TEK_UI_SUPPORT_NAME);
	tekui_flags chkf = luaL_checkinteger(L, 2);
	tekui_flags clrf = luaL_optinteger(L, 3, chkf);
	lua_pushboolean(L, (*f & chkf) == chkf);
	*f &= ~clrf;
	return 1;
}

/*****************************************************************************/

static const luaL_Reg tek_ui_support_funcs[] =
{
	{ "newFlags", tek_ui_support_newflags },
	{ NULL, NULL }
};

static const luaL_Reg tek_ui_support_flags_methods[] =
{
	{ "check", tek_ui_support_chkflags },
	{ "clear", tek_ui_support_clrflags },
	{ "set", tek_ui_support_setflags },
	{ "checkClear", tek_ui_support_chkclrflags },
	{ NULL, NULL }
};

TMODENTRY int luaopen_tek_ui_support(lua_State *L)
{
	luaL_register(L, "tek.ui.support", tek_ui_support_funcs);
	lua_pushstring(L, TEK_UI_SUPPORT_VERSION);
	lua_setfield(L, -2, "_VERSION");
	lua_pop(L, 1);
	luaL_newmetatable(L, TEK_UI_SUPPORT_NAME);
	luaL_register(L, NULL, tek_ui_support_flags_methods);
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");
	lua_pop(L, 1);
	return 0;
}
