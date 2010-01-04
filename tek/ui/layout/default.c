
/*
**	tek.ui.layout.default - Default layouter
**	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in COPYRIGHT
*/

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <string.h>
#include <tek/lib/tekui.h>

/* Name of superclass: */
#define SUPERCLASS_NAME "tek.ui.class.layout"

/* Name of this class: */
#define CLASS_NAME "tek.ui.layout.default"

/* Version: */
#define TEK_UI_CLASS_LAYOUT_DEFAULT_VERSION "Default Layout 7.0"

/*****************************************************************************/

static const char *ALIGN[2][6] =
{
	{ "HAlign", "VAlign", "right", "bottom", "Width", "Height" },
	{ "VAlign", "HAlign", "bottom", "right", "Height", "Width" }
};

static const int INDICES[2][6] =
{
	{ 1, 2, 3, 4, 5, 6 },
	{ 2, 1, 4, 3, 6, 5 },
};

/*****************************************************************************/

static int layout_getsamesize(lua_State *L, int groupindex, int axis)
{
	lua_getfield(L, groupindex, "SameSize");
	int res;
	if (lua_isboolean(L, -1) && lua_toboolean(L, -1))
		res = 1;
	else
	{
		const char *key = lua_tostring(L, -1);
		res = key && ((axis == 1 && key[0] == 'w') ||
			(axis == 2 && key[0] == 'h'));
	}
	lua_pop(L, 1);
	return res;
}

/*****************************************************************************/

typedef struct { int orientation, width, height; } layout_struct;

static layout_struct layout_getstructure(lua_State *L, int group)
{
	layout_struct res;
	
	size_t nc;
	int gw, gh;
	lua_getfield(L, group, "Columns");
	gw = lua_isnumber(L, -1) ? lua_tointeger(L, -1) : 0;
	lua_getfield(L, group, "Rows");
	gh = lua_isnumber(L, -1) ? lua_tointeger(L, -1) : 0;
	lua_getfield(L, group, "Children");
	nc = lua_objlen(L, -1);
	lua_pop(L, 3);
	
	if (gw)
	{
		res.orientation = 1;
		res.width = gw;
		res.height = (nc + gw - 1) / gw;
	}
	else if (gh)
	{
		res.orientation = 2;
		res.width = (nc + gh - 1) / gh;
		res.height = gh;
	}
	else
	{
		const char *key;
		lua_getfield(L, group, "Orientation");
		key = lua_tostring(L, -1);
		if (key && key[0] == 'h') /* "horizontal" */
		{
			res.orientation = 1;
			res.width = nc;
			res.height = 1;
		}
		else
		{
			res.orientation = 2;
			res.width = 1;
			res.height = nc;
		}
		lua_pop(L, 1);
	}
	
	return res;
}

/*****************************************************************************/

static void layout_calcweights(lua_State *L, layout_struct *lstruct)
{
	int cidx = 1;
	int y, x;
	lua_getfield(L, 1, "Weights");
	lua_newtable(L);
	lua_newtable(L);
	lua_getfield(L, 2, "Children");
	for (y = 1; y <= lstruct->height; ++y)
	{
		for (x = 1; x <= lstruct->width; ++x)
		{
			lua_rawgeti(L, -1, cidx);
			if (lua_isnil(L, -1))
			{
				lua_pop(L, 1);
				break;
			}
			lua_getfield(L, -1, "Weight");
			if (lua_isnumber(L, -1))
			{
				lua_Integer w = lua_tointeger(L, -1);
				lua_rawgeti(L, -5, x);
				lua_rawgeti(L, -5, y);
				lua_pushinteger(L, luaL_optint(L, -2, 0) + w);
				lua_rawseti(L, -8, x);
				lua_pushinteger(L, luaL_optint(L, -1, 0) + w);
				lua_rawseti(L, -7, y);
				lua_pop(L, 4);
			}
			else
				lua_pop(L, 2);
			cidx++;
		}
	}
	lua_pop(L, 1);
	lua_rawseti(L, -3, 2);
	lua_rawseti(L, -2, 1);
	lua_pop(L, 1);
}

/*****************************************************************************/
/*
**	list = layoutAxis(self, group, free, i1, i3, n, isgrid, pad)
*/

static int layout_layoutaxis(lua_State *L)
{
	lua_Number free = lua_tonumber(L, 3);
	lua_Integer i1 = lua_tointeger(L, 4);
	lua_Integer i3 = lua_tointeger(L, 5);
	lua_Integer n = lua_tointeger(L, 6);
	int isgrid = lua_toboolean(L, 7);

	int it = 0;
	size_t len;
	int ssb, ssn = 0;
	int i;

	lua_Integer fw0 = 0;
	lua_Integer tw0 = 0;
	lua_Number fw;
	lua_Number tw;

	lua_createtable(L, n, 0);
	lua_getfield(L, 1, "TempMinMax");
	lua_rawgeti(L, -1, i1);
	lua_rawgeti(L, -2, i3);
	lua_remove(L, -3);
	
	lua_getfield(L, 1, "Weights");
	lua_rawgeti(L, -1, i1);
	lua_remove(L, -2);

	for (i = 1; i <= n; ++i)
	{
		int free;
		lua_rawgeti(L, -3, i);
		lua_rawgeti(L, -3, i);
		lua_rawgeti(L, -3, i);
		free = lua_toboolean(L, -2) ?
			lua_tointeger(L, -2) > lua_tointeger(L, -3) : 0;
		lua_createtable(L, 5, 0);
		lua_pushboolean(L, free);
		lua_rawseti(L, -2, 1);
		lua_pushvalue(L, -4);
		lua_rawseti(L, -2, 2);
		lua_pushvalue(L, -3);
		lua_rawseti(L, -2, 3);
		lua_pushvalue(L, -2);
		lua_rawseti(L, -2, 4);
		lua_pushnil(L);
		lua_rawseti(L, -2, 5);
		lua_rawseti(L, -8, i);
		if (free)
		{
			if (lua_toboolean(L, -1))
				tw0 += lua_tointeger(L, -1);
			else
				fw0 += 0x100;
		}
		lua_pop(L, 3);
	}
	lua_pop(L, 3);

	if (tw0 < 0x10000)
	{
		if (fw0 == 0)
			tw0 = 0x10000;
		else
		{
			fw = 0x10000;
			fw -= tw0;
			fw *= 0x100;
			fw0 = fw / fw0;
			tw0 = 0x10000;
		}
	}
	else
		fw0 = 0;

	tw = tw0 / 0x100;
	fw = fw0 / 0x100;

	ssb = layout_getsamesize(L, 2, i1);
	if (ssb)
	{
		lua_getfield(L, 2, "MinMax");
		lua_rawgeti(L, -1, i1);
		lua_getfield(L, 2, "Margin");
		lua_rawgeti(L, -1, i1);
		lua_rawgeti(L, -2, i3);
		lua_rawgeti(L, 8, i1);
		lua_rawgeti(L, 8, i3);
		ssn = lua_tonumber(L, -6);
		ssn -= lua_tonumber(L, -4);
		ssn -= lua_tonumber(L, -3);
		ssn -= lua_tonumber(L, -2);
		ssn -= lua_tonumber(L, -1);
		lua_pop(L, 7);
		ssn /= n;
	}

	lua_getglobal(L, "table");
	lua_getfield(L, -1, "insert");
	lua_getfield(L, -2, "remove");
	lua_remove(L, -3);

	len = lua_objlen(L, -3);
	lua_createtable(L, len, 0);
	for (i = 1; i <= (int) len; ++i)
	{
		lua_rawgeti(L, -4, i);
		lua_rawseti(L, -2, i);
	}

	while ((len = lua_objlen(L, -1)) > 0)
	{
		lua_Integer rest = free;
		lua_Integer newfree = free;
		it++;

		lua_createtable(L, len, 0);

		do
		{
			lua_Integer olds, news, ti;

			lua_Integer delta = 0;

			lua_pushvalue(L, -3);
			lua_pushvalue(L, -3);
			lua_pushinteger(L, 1);
			lua_call(L, 2, 1);

			lua_rawgeti(L, -1, 1);
			if (lua_toboolean(L, -1))
			{
				lua_Number t;
				lua_rawgeti(L, -2, 4);
				if (lua_toboolean(L, -1))
				{
					t = lua_tonumber(L, -1);
					t /= 0x100;
					t *= tw;
					t *= free;
				}
				else
				{
					t = free;
					t *= 0x100;
					t *= fw;
				}
				t /= 0x10000;
				delta = t;
				lua_pop(L, 1);
			}

			if (delta == 0 && it > 1)
				delta = rest;

			lua_rawgeti(L, -2, 5);
			lua_rawgeti(L, -3, 2);

			if (lua_toboolean(L, -2))
				olds = lua_tointeger(L, -2);
			else if (ssb)
				olds = ssn;
			else
				olds = lua_tointeger(L, -1);

			ti = ssb ? ssn : lua_tointeger(L, -1);
			news = TMAX(olds + delta, ti);

			lua_rawgeti(L, -4, 3);
			if (!(ssb && isgrid) && lua_toboolean(L, -1) &&
				news > lua_tointeger(L, -1))
				news = lua_tointeger(L, -1);

			lua_pushinteger(L, news);
			lua_rawseti(L, -6, 5);

			delta = news - olds;
			newfree -= delta;
			rest -= delta;

			if (!lua_toboolean(L, -1) || lua_tointeger(L, -1) >= TEKUI_HUGE ||
				lua_tointeger(L, -3) < lua_tointeger(L, -1))
			{
				/* redo in next iteration: */
				lua_pushvalue(L, -9);
				lua_pushvalue(L, -7);
				lua_pushvalue(L, -7);
				lua_call(L, 2, 0);
			}

			lua_pop(L, 5);

		} while (lua_objlen(L, -2) > 0);

		free = newfree;
		if (free < 1)
		{
			lua_pop(L, 1);
			break;
		}

		lua_replace(L, -2);
	}

	lua_pop(L, 3);
	return 1;
}

/*****************************************************************************/
/*
**	layout(self, group, r1, r2, r3, r4, markdamage)
*/

static int layout_layout(lua_State *L)
{
	layout_struct lstruct = layout_getstructure(L, 2);
	int ori = lstruct.orientation;
	int gs1 = lstruct.width;
	int gs2 = lstruct.height;
	tekui_flags *f, of;

	if (gs1 > 0 && gs2 > 0)
	{
		int isgrid = (gs1 > 1) && (gs2 > 1);
		const int *I = INDICES[ori - 1];
		int i1 = I[0], i2 = I[1], i3 = I[2], i4 = I[3], i5 = I[4], i6 = I[5];

		lua_Integer isz, osz, oszmax, t, iidx;
		lua_Integer m3, m4, oidx, goffs;
		lua_Integer r1, r2, r3, r4;
		lua_Integer cidx = 1;

		const char **A = ALIGN[ori - 1], *s;

		if (i1 == 2)
		{
			r2 = lua_tointeger(L, 3);
			r1 = lua_tointeger(L, 4);
			r4 = lua_tointeger(L, 5);
			r3 = lua_tointeger(L, 6);
			t = gs1;
			gs1 = gs2;
			gs2 = t;
		}
		else
		{
			r1 = lua_tointeger(L, 3);
			r2 = lua_tointeger(L, 4);
			r3 = lua_tointeger(L, 5);
			r4 = lua_tointeger(L, 6);
		}

		lua_getfield(L, 2, "Margin");
		lua_getfield(L, 2, "Rect");
		
		lua_createtable(L, 4, 0);
		lua_getfield(L, 2, "getPadding");
		lua_pushvalue(L, 2);
		lua_call(L, 1, 4);
		lua_rawseti(L, -5, 4);
		lua_rawseti(L, -4, 3);
		lua_rawseti(L, -3, 2);
		lua_rawseti(L, -2, 1);
		
		lua_rawgeti(L, -1, i1);
		lua_rawgeti(L, -4, i1);
		goffs = lua_tonumber(L, -1) + lua_tonumber(L, -2);
		lua_pop(L, 2);
		lua_createtable(L, 5, 0);

		lua_getfield(L, 2, "Flags");
		f = luaL_checkudata(L, -1, TEK_UI_SUPPORT_NAME);
		of = *f;
		*f &= ~TEKUI_FL_CHANGED;
		if (of & TEKUI_FL_CHANGED)
			layout_calcweights(L, &lstruct);
		lua_pop(L, 1);

		lua_getfield(L, 2, "MinMax");
		lua_getfield(L, 1, "layoutAxis");
		lua_pushvalue(L, 1);
		lua_pushvalue(L, 2);
		lua_rawgeti(L, -4, i2);
		lua_pushinteger(L, r4 - r2 + 1 - lua_tointeger(L, -1));
		lua_remove(L, -2);
		lua_pushinteger(L, i2);
		lua_pushinteger(L, i4);
		lua_pushinteger(L, gs2);
		lua_pushboolean(L, isgrid);
		lua_call(L, 7, 1);

		/* layout on inner axis: */
		lua_getfield(L, 1, "layoutAxis");
		lua_pushvalue(L, 1);
		lua_pushvalue(L, 2);
		lua_rawgeti(L, -5, i1);
		lua_pushinteger(L, r3 - r1 + 1 - lua_tointeger(L, -1));
		lua_remove(L, -2);
		lua_pushinteger(L, i1);
		lua_pushinteger(L, i3);
		lua_pushinteger(L, gs1);
		lua_pushboolean(L, isgrid);
		lua_call(L, 7, 1);
		lua_remove(L, -3);

		lua_getfield(L, 2, "Children");

		/* size on outer axis: */
		lua_rawgeti(L, -6, i4);
		lua_rawgeti(L, -7, i2);
		lua_rawgeti(L, -7, i2);
		lua_rawgeti(L, -8, i4);
		oszmax = lua_tointeger(L, -4) + 1;
		oszmax -= lua_tointeger(L, -3);
		oszmax -= lua_tointeger(L, -2);
		oszmax -= lua_tointeger(L, -1);
		lua_pop(L, 4);

		/* starting position on outer axis: */
		lua_rawgeti(L, -7, i2);
		lua_rawgeti(L, -6, i2);
		lua_pushinteger(L, r2 + lua_tointeger(L, -2) + lua_tointeger(L, -1));
		lua_rawseti(L, -7, i6);
		lua_pop(L, 2);

		/* loop outer axis: */
		for (oidx = 1; oidx <= gs2; ++oidx)
		{
			if (gs2 > 1)
			{
				lua_rawgeti(L, -3, oidx);
				lua_rawgeti(L, -1, 5);
				oszmax = lua_tointeger(L, -1);
				lua_pop(L, 2);
			}

			/* starting position on inner axis: */
			lua_pushinteger(L, r1 + goffs);
			lua_rawseti(L, -5, i5);

			/* loop inner axis: */
			for (iidx = 1; iidx <= gs1; ++iidx)
			{
				lua_rawgeti(L, -1, cidx);
				if (!lua_toboolean(L, -1))
				{
					lua_pop(L, 8);
					return 0;
				}

				/* x0, y0 of child rectangle: */
				lua_rawgeti(L, -5, 5);
				lua_rawseti(L, -6, 1);
				lua_rawgeti(L, -5, 6);
				lua_rawseti(L, -6, 2);

				/* element minmax: */
				lua_getfield(L, -1, "MinMax");

				/* max per inner and outer axis: */
				lua_rawgeti(L, -1, i3);
				lua_rawgeti(L, -2, i4);
				m3 = lua_tointeger(L, -2);
				m4 = lua_tointeger(L, -1);
				lua_pop(L, 2);

				/* inner size: */
				lua_pushvalue(L, -4);
				lua_rawgeti(L, -1, iidx);
				lua_rawgeti(L, -1, 5);
				isz = lua_tointeger(L, -1);
				lua_pop(L, 3);

				lua_getfield(L, -2, A[4]);
				s = lua_tostring(L, -1);
				if (s)
				{
					if (s[0] == 'f') /* "free" or "fill" */
					{
						lua_rawgeti(L, -9, i3);
						lua_rawgeti(L, -10, i1);
						lua_rawgeti(L, -10, i1);
						lua_rawgeti(L, -11, i3);
						m3 = lua_tointeger(L, -4) + 1;
						m3 -= lua_tointeger(L, -3);
						m3 -= lua_tointeger(L, -2);
						m3 -= lua_tointeger(L, -1);
						lua_pop(L, 4);
					}
				}
				lua_pop(L, 1);

				if (m3 < isz)
				{
					lua_getfield(L, -2, A[0]);
					s = lua_tostring(L, -1);
					if (s)
					{
						if (strcmp(s, "center") == 0)
						{
							lua_rawgeti(L, -7, i1);
							t = lua_tointeger(L, -1);
							t += (isz - m3) / 2;
							lua_pushinteger(L, t);
							lua_rawseti(L, -9, i1);
							lua_pop(L, 1);
						}
						else if (strcmp(s, A[2]) == 0)
						{
							lua_rawgeti(L, -7, i1);
							t = lua_tointeger(L, -1);
							t += isz - m3;
							lua_pushinteger(L, t);
							lua_rawseti(L, -9, i1);
							lua_pop(L, 1);
						}
					}
					isz = m3;
					lua_pop(L, 1);
				}

				/* outer size: */
				lua_getfield(L, -2, A[5]);
				s = lua_tostring(L, -1);
				if (s && s[0] == 'f') /* "free" or "fill" */
					osz = oszmax;
				else
				{
					lua_rawgeti(L, -6, oidx);
					lua_rawgeti(L, -1, 5);
					osz = lua_tointeger(L, -1);
					osz = TMIN(osz, m4);
					lua_pop(L, 2);
					/* align if element does not fully occupy outer size: */
					if (osz < oszmax)
					{
						lua_getfield(L, -3, A[1]);
						s = lua_tostring(L, -1);
						if (s)
						{
							if (strcmp(s, "center") == 0)
							{
								lua_rawgeti(L, -8, i2);
								t = lua_tointeger(L, -1);
								t += (oszmax - osz) / 2;
								lua_pushinteger(L, t);
								lua_rawseti(L, -10, i2);
								lua_pop(L, 1);
							}
							else if (strcmp(s, A[3]) == 0)
							{
								/* opposite side: */
								lua_rawgeti(L, -8, i2);
								t = lua_tointeger(L, -1);
								t += oszmax - osz;
								lua_pushinteger(L, t);
								lua_rawseti(L, -10, i2);
								lua_pop(L, 1);
							}
						}
						lua_pop(L, 1);
					}
				}
				lua_pop(L, 1);

				/* x1, y1 of child rectangle: */
				lua_rawgeti(L, -6, i1);
				t = lua_tointeger(L, -1);
				lua_pushinteger(L, t + isz - 1);
				lua_rawseti(L, -8, i3);
				lua_pop(L, 1);

				lua_rawgeti(L, -6, i2);
				t = lua_tointeger(L, -1);
				lua_pushinteger(L, t + osz - 1);
				lua_rawseti(L, -8, i4);
				lua_pop(L, 1);

				/* enter recursion: */
				lua_getfield(L, -2, "layout");
				lua_pushvalue(L, -3);
				lua_rawgeti(L, -8, 1);
				lua_rawgeti(L, -9, 2);
				lua_rawgeti(L, -10, 3);
				lua_rawgeti(L, -11, 4);
				lua_pushvalue(L, 7);
				lua_call(L, 6, 0);

				/* punch a hole for the element into the background: */
				lua_getfield(L, -2, "punch");
				lua_pushvalue(L, -3);
				lua_getfield(L, 2, "FreeRegion");
				lua_call(L, 2, 0);

				/* update x0: */
				lua_rawgeti(L, -6, i5);
				lua_rawgeti(L, -5, iidx);
				lua_rawgeti(L, -1, 5);
				t = lua_tointeger(L, -3);
				t += lua_tointeger(L, -1);
				lua_pushinteger(L, t);
				lua_rawseti(L, -10, i5);
				lua_pop(L, 5);

				/* next child index: */
				cidx++;
			}

			/* update y0: */
			lua_rawgeti(L, -4, i6);
			lua_rawgeti(L, -4, oidx);
			lua_rawgeti(L, -1, 5);
			t = lua_tointeger(L, -3);
			t += lua_tointeger(L, -1);
			lua_pushinteger(L, t);
			lua_rawseti(L, -8, i6);
			lua_pop(L, 3);
		}
		lua_pop(L, 7);
	}
	return 0;
}

/*****************************************************************************/
/*
**	m1, m2, m3, m4 = askMinMax(self, group, m1, m2, m3, m4)
*/

static int layout_askMinMax(lua_State *L)
{
	int m[5] = { 0, 0, 0, 0, 0 };
	layout_struct lstruct = layout_getstructure(L, 2);
	int ori = lstruct.orientation;
	int gw = lstruct.width;
	int gh = lstruct.height;

	if (gw > 0 && gh > 0)
	{
		int i1, gs, y, x;
		int cidx = 1;
		
		lua_createtable(L, 4, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, 1, "TempMinMax");
		lua_createtable(L, gw, 0);
		lua_createtable(L, gh, 0);
		lua_createtable(L, gw, 0);
		lua_createtable(L, gh, 0);
		lua_getfield(L, 2, "Children");

		for (y = 1; y <= gh; ++y)
		{
			for (x = 1; x <= gw; ++x)
			{
				int mm1, mm2, mm3, mm4;
				int minxx, minyy;
				const char *s;

				lua_rawgeti(L, -1, cidx);

				if (!lua_toboolean(L, -1))
				{
					lua_pop(L, 1);
					break;
				}
				cidx++;

				lua_getfield(L, -1, "askMinMax");
				lua_pushvalue(L, -2);
				lua_pushvalue(L, 3);
				lua_pushvalue(L, 4);
				lua_pushvalue(L, 5);
				lua_pushvalue(L, 6);
				lua_call(L, 5, 4);
				mm1 = lua_tointeger(L, -4);
				mm2 = lua_tointeger(L, -3);
				mm3 = lua_tointeger(L, -2);
				mm4 = lua_tointeger(L, -1);
				lua_pop(L, 4);

				lua_getfield(L, -1, "Width");
				s = lua_tostring(L, -1);
				if (s)
				{
					if (strcmp(s, "fill") == 0)
						mm3 = -1; /* nil */
					else if (strcmp(s, "free") == 0)
						mm3 = TEKUI_HUGE;
				}
				lua_pop(L, 1);

				lua_getfield(L, -1, "Height");
				s = lua_tostring(L, -1);
				if (s)
				{
					if (strcmp(s, "fill") == 0)
						mm4 = -1; /* nil */
					else if (strcmp(s, "free") == 0)
						mm4 = TEKUI_HUGE;
				}
				lua_pop(L, 2);

				if (mm3 < 0 && ori == 2)
					mm3 = mm1;
				if (mm4 < 0 && ori == 1)
					mm4 = mm2;

				lua_rawgeti(L, -5, x);
				minxx = lua_isnil(L, -1) ? 0 : lua_tointeger(L, -1);
				minxx = TMAX(minxx, mm1);
				lua_pushinteger(L, minxx);
				lua_rawseti(L, -7, x);
				lua_pop(L, 1);

				lua_rawgeti(L, -4, y);
				minyy = lua_isnil(L, -1) ? 0 : lua_tointeger(L, -1);
				minyy = TMAX(minyy, mm2);
				lua_pushinteger(L, minyy);
				lua_rawseti(L, -6, y);
				lua_pop(L, 1);

				if (mm3 >= 0)
				{
					lua_rawgeti(L, -3, x);
					if (lua_isnil(L, -1) || mm3 > lua_tointeger(L, -1))
					{
						lua_pushinteger(L, TMAX(mm3, minxx));
						lua_rawseti(L, -5, x);
					}
					lua_pop(L, 1);
				}

				if (mm4 >= 0)
				{
					lua_rawgeti(L, -2, y);
					if (lua_isnil(L, -1) || mm4 > lua_tointeger(L, -1))
					{
						lua_pushinteger(L, TMAX(mm4, minyy));
						lua_rawseti(L, -4, y);
					}
					lua_pop(L, 1);
				}

			}
		}

		lua_pop(L, 1);
		lua_rawseti(L, -5, 4);
		lua_rawseti(L, -4, 3);
		lua_rawseti(L, -3, 2);
		lua_rawseti(L, -2, 1);

		gs = gw;
		for (i1 = 1; i1 <= 2; i1++)
		{
			int mins, maxs, ss, n;
			int i3 = i1 + 2;
			int numfree = 0;
			int remainder = 0;
			
			ss = layout_getsamesize(L, 2, i1);

			for (n = 1; n <= gs; ++n)
			{
				lua_rawgeti(L, -1, i1);
				lua_rawgeti(L, -1, n);
				mins = lua_tointeger(L, -1);
				lua_rawgeti(L, -3, i3);
				lua_rawgeti(L, -1, n);
				maxs = lua_isnil(L, -1) ? -1 : lua_tointeger(L, -1);
				
				if (ss)
				{
					if (maxs < 0 || maxs > mins)
						numfree++;
					else
						remainder += mins;
					m[i1] = TMAX(m[i1], mins);
				}
				else
					m[i1] += mins;
				
				if (maxs >= 0)
				{
					maxs = TMAX(maxs, mins);
					lua_pushinteger(L, maxs);
					lua_rawseti(L, -3, n);
					m[i3] = TMAX(m[i3], 0) + maxs;
				}
				else if (ori == i1)
				{
					m[i3] = TMAX(m[i3], 0) + mins;
				}
				
				lua_pop(L, 4);
			}

			if (ss)
			{
				if (numfree == 0)
					m[i1] *= gs;
				else
					m[i1] = m[i1] * numfree + remainder;
				if (m[i3] >= 0 && m[i1] > m[i3])
					m[i3] = m[i1];
			}
			gs = gh;
		}

		lua_pop(L, 1);
	}

	lua_pushinteger(L, m[1]);
	lua_pushinteger(L, m[2]);
	lua_pushinteger(L, m[3]);
	lua_pushinteger(L, m[4]);

	return 4;
}

/*****************************************************************************/

static int layout_new(lua_State *L)
{
	lua_pushvalue(L, lua_upvalueindex(1));
	/* s: Layout */
	lua_getfield(L, -1, "new");
	lua_remove(L, -2);
	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	/* s: Layout.new, class, self */
	lua_newtable(L);
	lua_setfield(L, -2, "TempMinMax");
	lua_newtable(L);
	lua_setfield(L, -2, "Weights");
	lua_call(L, 2, 1);
	return 1;
}

/*****************************************************************************/

static const luaL_Reg tek_ui_layout_default_funcs[] =
{
	{ "new", layout_new },
	{ "askMinMax", layout_askMinMax },
	{ "layoutAxis", layout_layoutaxis },
	{ "layout", layout_layout },
	{ NULL, NULL }
};

TMODENTRY int luaopen_tek_ui_layout_default(lua_State *L)
{
	lua_getglobal(L, "require");
	/* s: <require> */
	lua_pushliteral(L, SUPERCLASS_NAME);
	/* s: <require>, "superclass" */
	lua_call(L, 1, 1);
	/* s: superclass */
	lua_pushvalue(L, -1);
	/* s: superclass, superclass */
	lua_getglobal(L, "require");
	/* s: superclass, superclass, <require> */
	lua_pushliteral(L, SUPERCLASS_NAME);
	/* s: superclass, superclass, <require>, "superclass" */
	lua_call(L, 1, 1);
	/* s: superclass, superclass, Layout: */
	lua_pushstring(L, TEK_UI_CLASS_LAYOUT_DEFAULT_VERSION);
	lua_setfield(L, -2, "_VERSION");
	/* s: superclass, superclass, Layout - Layout is upvalue: */
	luaI_openlib(L, CLASS_NAME, tek_ui_layout_default_funcs, 1);
	/* s: superclass, superclass, class */
	lua_call(L, 1, 1);
	/* s: superclass, class */
	luaL_newmetatable(L, CLASS_NAME "*");
	/* s: superclass, class, meta */
	lua_getfield(L, -3, "newClass");
	/* s: superclass, class, meta, <newClass> */
	lua_setfield(L, -2, "__call");
	/* s: superclass, class, meta */
	lua_pushvalue(L, -3);
	/* s: superclass, class, meta, superclass */
	lua_setfield(L, -2, "__index");
	/* s: superclass, class, meta */
	lua_setmetatable(L, -2);
	/* s: superclass, class */
	lua_pop(L, 2);
	return 0;
}
