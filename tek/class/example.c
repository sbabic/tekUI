
/*
**	example.c
**	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in COPYRIGHT
**
**	Basic setup of a class for the tekUI toolkit written in C
*/

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

/* Name of superclass: */
#define SUPERCLASS_NAME "tek.class"

/* Name of this class: */
#define CLASS_NAME "tek.class.example"

static const luaL_Reg classfuncs[] =
{
	/* insert methods here */
	{ NULL, NULL }
};

int luaopen_tek_class_example(lua_State *L)
{
	lua_getglobal(L, "require");
	/* s: <require> */
	lua_pushliteral(L, SUPERCLASS_NAME);
	/* s: <require>, "superclass" */
	lua_call(L, 1, 1);
	/* s: superclass */
	lua_getfield(L, -1, "newClass");
	/* s: superclass, <newClass> */
	lua_pushvalue(L, -2);
	/* s: superclass, <newClass>, superclass */
#if LUA_VERSION_NUM < 502
	luaL_register(L, CLASS_NAME, classfuncs);
#else
	luaL_newlib(L, classfuncs);
#endif
	/* s: superclass, <newClass>, superclass, class */
	lua_call(L, 2, 1); /* class = superclass.newClass(superclass, class) */
	/* s: superclass, class */
	luaL_newmetatable(L, CLASS_NAME "*");
	/* s: superclass, class, meta */
	lua_pushvalue(L, -3);
	/* s: superclass, class, meta, superclass */
	lua_setfield(L, -2, "__index");
	/* s: superclass, class, meta */
	lua_setmetatable(L, -2);
	/* s: superclass, class */
	lua_remove(L, -2);
	/* s: class */
	return 1;
}
