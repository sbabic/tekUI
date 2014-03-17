/*
** $Id: linit.c,v 1.14.1.1 2007/12/27 13:02:25 roberto Exp $
** Initialization of libraries for lua.c
** See Copyright Notice in lua.h
*/


#define linit_c
#define LUA_LIB

#include "lua.h"

#include "lualib.h"
#include "lauxlib.h"

#if defined(LUA_TEKUI_INCLUDE_CLASS_LIBRARY)
#include "tekui_classlib.c"
#endif

static const luaL_Reg lualibs[] = {
  {"", luaopen_base},
  {LUA_LOADLIBNAME, luaopen_package},
  {LUA_TABLIBNAME, luaopen_table},
  {LUA_IOLIBNAME, luaopen_io},
  {LUA_OSLIBNAME, luaopen_os},
  {LUA_STRLIBNAME, luaopen_string},
  {LUA_MATHLIBNAME, luaopen_math},
  {LUA_DBLIBNAME, luaopen_debug},
  {NULL, NULL}
};

static const luaL_Reg lualibs2[] = {
  { "tek.lib.exec", luaopen_tek_lib_exec },
  { "tek.lib.region", luaopen_tek_lib_region },
  { "tek.lib.string", luaopen_tek_lib_string },
  { "tek.lib.display.x11", luaopen_tek_lib_display_x11 },
  { "tek.lib.visual", luaopen_tek_lib_visual },
  { "tek.lib.support", luaopen_tek_lib_support },
  { "tek.ui.layout.default", luaopen_tek_ui_layout_default },
  { "tek.ui.class.area", luaopen_tek_ui_class_area },
  { "tek.ui.class.frame", luaopen_tek_ui_class_frame },
  {NULL, NULL}
};

LUALIB_API void luaL_openlibs (lua_State *L) {
  const luaL_Reg *lib = lualibs;
  for (; lib->func; lib++) {
    lua_pushcfunction(L, lib->func);
    lua_pushstring(L, lib->name);
    lua_call(L, 1, 0);
  }
  
#if defined(LUA_TEKUI_INCLUDE_CLASS_LIBRARY)
  luaL_loadbuffer(L, (const char *) bytecode, sizeof(bytecode),
  	"tekUI class library");
  lua_call(L, 0, 0);
#endif
  
  lib = lualibs2;
  for (; lib->func; lib++) {
    lua_pushcfunction(L, lib->func);
    lua_pushstring(L, lib->name);
    lua_call(L, 1, 0);
  }
}
