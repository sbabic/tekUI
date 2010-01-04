
/*
**	tek.lib.region - Management of rectangular regions
**	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in COPYRIGHT
*/

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <stdio.h>

#include <tek/debug.h>
#include <tek/teklib.h>
#include <tek/proto/exec.h>

/*****************************************************************************/

#define TEK_LIB_REGION_VERSION "Region 9.0"
#define TEK_LIB_REGION_NAME "tek.lib.region*"
#define TEK_LIB_REGION_POOL_NAME "tek.lib.pool*"

#define MERGE_RECTS	8
#define MAXPOOLNODES 2048

typedef TINT RECTINT;

struct RectNode
{
	struct TNode rn_Node;
	RECTINT rn_Rect[4];
};

struct RectList
{
	struct TList rl_List;
	TINT rl_NumNodes;
};

struct Pool
{
	struct RectList p_Rects;
	struct TExecBase *p_ExecBase;
};

struct Region
{
	struct RectList rg_Rects;
	struct Pool *rg_Pool;
};

/*****************************************************************************/

#define OVERLAP(d0, d1, d2, d3, s0, s1, s2, s3) \
((s2) >= (d0) && (s0) <= (d2) && (s3) >= (d1) && (s1) <= (d3))

#define OVERLAPRECT(d, s) \
OVERLAP((d)[0], (d)[1], (d)[2], (d)[3], (s)[0], (s)[1], (s)[2], (s)[3])

static int lib_intersect(lua_State *L)
{
	TINT d0 = luaL_checkinteger(L, 1);
	TINT d1 = luaL_checkinteger(L, 2);
	TINT d2 = luaL_checkinteger(L, 3);
	TINT d3 = luaL_checkinteger(L, 4);
	TINT s0 = luaL_checkinteger(L, 5);
	TINT s1 = luaL_checkinteger(L, 6);
	TINT s2 = luaL_checkinteger(L, 7);
	TINT s3 = luaL_checkinteger(L, 8);

	if (OVERLAP(d0, d1, d2, d3, s0, s1, s2, s3))
	{
		lua_pushinteger(L, TMAX(s0, d0));
		lua_pushinteger(L, TMAX(s1, d1));
		lua_pushinteger(L, TMIN(s2, d2));
		lua_pushinteger(L, TMIN(s3, d3));
		return 4;
	}
	
	return 0;
}

/*****************************************************************************/

static void relinklist(struct TList *dlist, struct TList *slist)
{
	if (!TISLISTEMPTY(slist))
	{
		struct TNode *first = slist->tlh_Head;
		struct TNode *last = slist->tlh_TailPred;
		struct TNode *dlast = dlist->tlh_TailPred;
		first->tln_Pred = dlast;
		last->tln_Succ = (struct TNode *) &dlist->tlh_Tail;
		dlast->tln_Succ = first;
		dlist->tlh_TailPred = last;
 		/*TINITLIST(slist);*/
	}
}

static struct RectNode *allocrectnode(struct Pool *pool,
	TINT x0, TINT y0, TINT x1, TINT y1)
{
	struct TNode *temp;
	struct RectNode *rn = (struct RectNode *) 
		TREMHEAD(&pool->p_Rects.rl_List, temp);
	if (rn)
		pool->p_Rects.rl_NumNodes--;
	else
		rn = TExecAlloc(pool->p_ExecBase, TNULL, sizeof(struct RectNode));
	if (rn)
	{
		rn->rn_Rect[0] = x0;
		rn->rn_Rect[1] = y0;
		rn->rn_Rect[2] = x1;
		rn->rn_Rect[3] = y1;
	}
	return rn;
}

static void initrectlist(struct RectList *rl)
{
	TINITLIST(&rl->rl_List);
	rl->rl_NumNodes = 0;
}

static void relinkrectlist(struct RectList *d, struct RectList *s)
{
	d->rl_NumNodes += s->rl_NumNodes;
	relinklist(&d->rl_List, &s->rl_List);
	initrectlist(s);	
}

static void freepool(struct Pool *p, struct RectList *list)
{
	struct TNode *temp;
	relinkrectlist(&p->p_Rects, list);
	while (p->p_Rects.rl_NumNodes > MAXPOOLNODES)
	{
		TExecFree(p->p_ExecBase, TREMTAIL(&p->p_Rects.rl_List, temp));
		p->p_Rects.rl_NumNodes--;
	}	
}

/*****************************************************************************/

static TBOOL insertrect(struct Pool *pool, struct RectList *list,
	TINT s0, TINT s1, TINT s2, TINT s3)
{
	struct TNode *temp, *next, *node = list->rl_List.tlh_Head;
	struct RectNode *rn;
	int i;

	#if defined(MERGE_RECTS)
	for (i = 0; i < MERGE_RECTS && (next = node->tln_Succ); node = next, ++i)
	{
		rn = (struct RectNode *) node;
		if (rn->rn_Rect[1] == s1 && rn->rn_Rect[3] == s3)
		{
			if (rn->rn_Rect[2] + 1 == s0)
			{
				rn->rn_Rect[2] = s2;
				return TTRUE;
			}
			else if (rn->rn_Rect[0] == s2 + 1)
			{
				rn->rn_Rect[0] = s0;
				return TTRUE;
			}
		}
		else if (rn->rn_Rect[0] == s0 && rn->rn_Rect[2] == s2)
		{
			if (rn->rn_Rect[3] + 1 == s1)
			{
				rn->rn_Rect[3] = s3;
				return TTRUE;
			}
			else if (rn->rn_Rect[1] == s3 + 1)
			{
				rn->rn_Rect[1] = s1;
				return TTRUE;
			}
		}
	}
	#endif

	rn = allocrectnode(pool, s0, s1, s2, s3);
	if (rn)
	{
		TADDHEAD(&list->rl_List, &rn->rn_Node, temp);
		list->rl_NumNodes++;
		return TTRUE;
	}

	return TFALSE;
}

static TBOOL cutrect(struct Pool *pool, struct RectList *list,
	const RECTINT d[4], const RECTINT s[4])
{
	TINT d0 = d[0];
	TINT d1 = d[1];
	TINT d2 = d[2];
	TINT d3 = d[3];

	if (!OVERLAPRECT(d, s))
		return insertrect(pool, list, d[0], d[1], d[2], d[3]);

	for (;;)
	{
		if (d0 < s[0])
		{
			if (!insertrect(pool, list, d0, d1, s[0] - 1, d3))
				break;
			d0 = s[0];
		}

		if (d1 < s[1])
		{
			if (!insertrect(pool, list, d0, d1, d2, s[1] - 1))
				break;
			d1 = s[1];
		}

		if (d2 > s[2])
		{
			if (!insertrect(pool, list, s[2] + 1, d1, d2, d3))
				break;
			d2 = s[2];
		}

		if (d3 > s[3])
		{
			if (!insertrect(pool, list, d0, s[3] + 1, d2, d3))
				break;
		}

		return TTRUE;

	}
	return TFALSE;
}

static TBOOL cutrectlist(struct Pool *pool, struct RectList *inlist,
	struct RectList *outlist, const RECTINT s[4])
{
	TBOOL success = TTRUE;
	struct TNode *next, *node = inlist->rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		struct RectList temp;
		initrectlist(&temp);
		success = cutrect(pool, &temp, rn->rn_Rect, s);
		if (success)
		{
			struct TNode *next2, *node2 = temp.rl_List.tlh_Head;
			for (; success && (next2 = node2->tln_Succ); node2 = next2)
			{
				struct RectNode *rn2 = (struct RectNode *) node2;
				success = insertrect(pool, outlist, rn2->rn_Rect[0],
					rn2->rn_Rect[1], rn2->rn_Rect[2], rn2->rn_Rect[3]);
				/* note that if unsuccessful, outlist is unusable as well */
			}
		}
		freepool(pool, &temp);
	}
	return success;
}

static TBOOL orrect(struct Pool *pool, struct RectList *list, 
	RECTINT s[4])
{
	struct RectList temp;
	initrectlist(&temp);
	if (cutrectlist(pool, list, &temp, s))
	{
		if (insertrect(pool, &temp, s[0], s[1], s[2], s[3]))
		{
			freepool(pool, list);
			relinkrectlist(list, &temp);
			return TTRUE;
		}
	}
	freepool(pool, &temp);
	return TFALSE;
}

/*****************************************************************************/

static int lib_new(lua_State *L)
{
	struct Region *region = lua_newuserdata(L, sizeof(struct Region));
	/* s: udata */
	initrectlist(&region->rg_Rects);
	lua_getfield(L, LUA_REGISTRYINDEX, TEK_LIB_REGION_NAME);
	/* s: udata, metatable */
	lua_rawgeti(L, -1, 2);
	/* s: udata, metatable, pool */
	region->rg_Pool = lua_touserdata(L, -1);
	lua_pop(L, 1);
	/* s: udata, metatable */
	lua_setmetatable(L, -2);
	/* s: udata */
	
	if (lua_gettop(L) == 5)
	{
		TINT x0 = luaL_checkinteger(L, 1);
		TINT y0 = luaL_checkinteger(L, 2);
		TINT x1 = luaL_checkinteger(L, 3);
		TINT y1 = luaL_checkinteger(L, 4);
		if (insertrect(region->rg_Pool,
			&region->rg_Rects, x0, y0, x1, y1) == TFALSE)
			luaL_error(L, "out of memory");
	}
	else if (lua_gettop(L) != 1)
		luaL_error(L, "wrong number of arguments");

	return 1;
}

static int region_set(lua_State *L)
{
	struct Region *region = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	TINT x0 = luaL_checkinteger(L, 2);
	TINT y0 = luaL_checkinteger(L, 3);
	TINT x1 = luaL_checkinteger(L, 4);
	TINT y1 = luaL_checkinteger(L, 5);
	freepool(region->rg_Pool, &region->rg_Rects);
	if (insertrect(region->rg_Pool, &region->rg_Rects,
		x0, y0, x1, y1) == TFALSE)
		luaL_error(L, "out of memory");
	lua_pushvalue(L, 1);
	return 1;
}

static int region_collect(lua_State *L)
{
	struct Region *region = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	freepool(region->rg_Pool, &region->rg_Rects);
	return 0;
}

static int region_orrect(lua_State *L)
{
	struct Region *region = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	RECTINT s[4];

	s[0] = luaL_checkinteger(L, 2);
	s[1] = luaL_checkinteger(L, 3);
	s[2] = luaL_checkinteger(L, 4);
	s[3] = luaL_checkinteger(L, 5);

	if (!orrect(region->rg_Pool, &region->rg_Rects, s))
		luaL_error(L, "out of memory");

	return 0;
}

static TBOOL orregion(struct Region *region, struct RectList *list)
{
	TBOOL success = TTRUE;
	struct TNode *next, *node = list->rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		success = orrect(region->rg_Pool, 
			&region->rg_Rects, rn->rn_Rect);
	}
	return success;
}

static int region_xorrect(lua_State *L)
{
	struct Region *region = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	struct Pool *pool = region->rg_Pool;
	struct TNode *next, *node;
	TBOOL success;
	struct RectList r1, r2;
	RECTINT s[4];

	s[0] = luaL_checkinteger(L, 2);
	s[1] = luaL_checkinteger(L, 3);
	s[2] = luaL_checkinteger(L, 4);
	s[3] = luaL_checkinteger(L, 5);

	initrectlist(&r1);
	initrectlist(&r2);

	success = insertrect(pool, &r2, s[0], s[1], s[2], s[3]);

	node = region->rg_Rects.rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct TNode *next2, *node2;
		struct RectNode *rn = (struct RectNode *) node;
		struct RectList temp;

		initrectlist(&temp);
		success = cutrect(pool, &temp, rn->rn_Rect, s);

		node2 = temp.rl_List.tlh_Head;
		for (; success && (next2 = node2->tln_Succ); node2 = next2)
		{
			struct RectNode *rn2 = (struct RectNode *) node2;
			success = insertrect(pool, &r1, rn2->rn_Rect[0],
				rn2->rn_Rect[1], rn2->rn_Rect[2], rn2->rn_Rect[3]);
		}
		
		freepool(pool, &temp);

		if (success)
		{
			success = cutrectlist(pool, &r2, &temp, rn->rn_Rect);
			freepool(pool, &r2);
			relinkrectlist(&r2, &temp);
		}
	}

	if (success)
	{
		freepool(pool, &region->rg_Rects);
		relinkrectlist(&region->rg_Rects, &r1);
		orregion(region, &r2);
		freepool(pool, &r2);
	}
	else
	{
		freepool(pool, &r1);
		freepool(pool, &r2);
		luaL_error(L, "out of memory");
	}

	return 0;
}

static TBOOL subrect(lua_State *L, struct Region *region, RECTINT s[])
{
	struct RectList r1;
	struct TNode *next, *node;
	struct Pool *pool = region->rg_Pool;
	TBOOL success = TTRUE;

	initrectlist(&r1);
	node = region->rg_Rects.rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct TNode *next2, *node2;
		struct RectNode *rn = (struct RectNode *) node;
		struct RectList temp;

		initrectlist(&temp);
		success = cutrect(region->rg_Pool, &temp, rn->rn_Rect, s);

		node2 = temp.rl_List.tlh_Head;
		for (; success && (next2 = node2->tln_Succ); node2 = next2)
		{
			struct RectNode *rn2 = (struct RectNode *) node2;
			success = insertrect(region->rg_Pool, &r1, rn2->rn_Rect[0],
				rn2->rn_Rect[1], rn2->rn_Rect[2], rn2->rn_Rect[3]);
		}

		freepool(pool, &temp);
	}

	if (success)
	{
		freepool(pool, &region->rg_Rects);
		relinkrectlist(&region->rg_Rects, &r1);
	}
	else
	{
		freepool(pool, &r1);
		luaL_error(L, "out of memory");
	}

	return success;
}

static int region_subrect(lua_State *L)
{
	struct Region *region = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	RECTINT s[4];
	s[0] = luaL_checkinteger(L, 2);
	s[1] = luaL_checkinteger(L, 3);
	s[2] = luaL_checkinteger(L, 4);
	s[3] = luaL_checkinteger(L, 5);
	subrect(L, region, s);
	lua_pushvalue(L, 1);
	return 1;
}

static int region_checkintersect(lua_State *L)
{
	struct Region *region = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	struct TNode *next, *node;
	TINT s[4];

	s[0] = luaL_checkinteger(L, 2);
	s[1] = luaL_checkinteger(L, 3);
	s[2] = luaL_checkinteger(L, 4);
	s[3] = luaL_checkinteger(L, 5);

	node = region->rg_Rects.rl_List.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		if (OVERLAPRECT(rn->rn_Rect, s))
		{
			lua_pushboolean(L, 1);
			return 1;
		}
	}
	lua_pushboolean(L, 0);
	return 1;
}

static void *optudata(lua_State *L, int ud, const char *tname)
{
	void *p = lua_touserdata(L, ud);
	if (p != NULL)
	{
		if (lua_getmetatable(L, ud))
		{
			lua_getfield(L, LUA_REGISTRYINDEX, tname);
			if (lua_rawequal(L, -1, -2))
			{
				lua_pop(L, 2);
				return p;
			}
			luaL_typerror(L, ud, tname);
		}
	}
	return NULL;
}

static int region_subregion(lua_State *L)
{
	struct Region *self = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	struct Region *region = optudata(L, 2, TEK_LIB_REGION_NAME);
	
	if (region)
	{
		struct TNode *rnext, *rnode;

		rnode = region->rg_Rects.rl_List.tlh_Head;
		for (; (rnext = rnode->tln_Succ); rnode = rnext)
		{
			struct RectNode *rn = (struct RectNode *) rnode;
			subrect(L, self, rn->rn_Rect);
		}
	}
	return 0;
}

static TBOOL andrect(struct RectList *temp,
	struct Region *region, TINT s0, TINT s1, TINT s2, TINT s3)
{
	struct TNode *next, *node = region->rg_Rects.rl_List.tlh_Head;
	TBOOL success = TTRUE;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *dr = (struct RectNode *) node;
		TINT x0 = dr->rn_Rect[0];
		TINT y0 = dr->rn_Rect[1];
		TINT x1 = dr->rn_Rect[2];
		TINT y1 = dr->rn_Rect[3];
		if (OVERLAP(x0, y0, x1, y1, s0, s1, s2, s3))
		{
			success = insertrect(region->rg_Pool, temp,
				TMAX(x0, s0), TMAX(y0, s1), TMIN(x1, s2), TMIN(y1, s3));
		}
	}
	if (!success)
		freepool(region->rg_Pool, temp);
	return success;
}

static int region_andrect(lua_State *L)
{
	struct Region *self = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	struct RectList temp;
	
	initrectlist(&temp);
	if (andrect(&temp, self,
		luaL_checkinteger(L, 2), luaL_checkinteger(L, 3),
		luaL_checkinteger(L, 4), luaL_checkinteger(L, 5)))
	{
		freepool(self->rg_Pool, &self->rg_Rects);
		relinkrectlist(&self->rg_Rects, &temp);
		return TTRUE;
	}
	return TFALSE;
}

static int region_andregion(lua_State *L)
{
	struct Region *dregion = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	struct Region *sregion = optudata(L, 2, TEK_LIB_REGION_NAME);
	struct TNode *next, *node = sregion->rg_Rects.rl_List.tlh_Head;
	TBOOL success = TTRUE;
	struct RectList temp;
	initrectlist(&temp);
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *sr = (struct RectNode *) node;
		success = andrect(&temp, dregion, sr->rn_Rect[0],
			sr->rn_Rect[1], sr->rn_Rect[2], sr->rn_Rect[3]);
	}
	if (success)
	{
		freepool(dregion->rg_Pool, &dregion->rg_Rects);
		relinkrectlist(&dregion->rg_Rects, &temp);
	}
	/* note: if unsucessful, dregion is of no use anymore */
	return success;
}

static int region_foreach(lua_State *L)
{
	struct Region *region = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	struct TNode *next, *node = region->rg_Rects.rl_List.tlh_Head;
	int narg = lua_gettop(L) - 3;
	int i;
	for (; (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		lua_pushvalue(L, 2); /* func */
		lua_pushvalue(L, 3); /* object */
		lua_pushinteger(L, rn->rn_Rect[0]);
		lua_pushinteger(L, rn->rn_Rect[1]);
		lua_pushinteger(L, rn->rn_Rect[2]);
		lua_pushinteger(L, rn->rn_Rect[3]);
		for (i = 0; i < narg; ++i)
			lua_pushvalue(L, 4 + i);
		lua_call(L, 5 + narg, 0);
	}
	return 0;
}

/*****************************************************************************/

static int region_shift(lua_State *L)
{
	struct Region *region = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	lua_Number sx = luaL_checknumber(L, 2);
	lua_Number sy = luaL_checknumber(L, 3);	
	struct TNode *next, *node = region->rg_Rects.rl_List.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		rn->rn_Rect[0] += sx;
		rn->rn_Rect[1] += sy;
		rn->rn_Rect[2] += sx;
		rn->rn_Rect[3] += sy;
	}
	return 0;
}

/*****************************************************************************/

static int region_isempty(lua_State *L)
{
	struct Region *region = luaL_checkudata(L, 1, TEK_LIB_REGION_NAME);
	lua_pushboolean(L, TISLISTEMPTY(&region->rg_Rects.rl_List));
	return 1;
}

/*****************************************************************************/

static int pool_collect(lua_State *L)
{
	struct Pool *pool = luaL_checkudata(L, 1, TEK_LIB_REGION_POOL_NAME);
	struct TNode *next, *node = pool->p_Rects.rl_List.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
		TExecFree(pool->p_ExecBase, node);
	return 0;
}

/*****************************************************************************/

static const luaL_Reg tek_lib_region_funcs[] =
{
	{ "new", lib_new },
	{ "intersect", lib_intersect },
	{ NULL, NULL }
};

static const luaL_Reg tek_lib_region_methods[] =
{
	{ "__gc", region_collect },
	{ "setRect", region_set },
	{ "orRect", region_orrect },
	{ "xorRect", region_xorrect },
	{ "subRect", region_subrect },
	{ "checkIntersect", region_checkintersect },
	{ "subRegion", region_subregion },
	{ "andRect", region_andrect },
	{ "andRegion", region_andregion },
	{ "forEach", region_foreach },
	{ "shift", region_shift },
	{ "isEmpty", region_isempty },
	{ NULL, NULL }
};

static const luaL_Reg tek_lib_region_poolmethods[] =
{
	{ "__gc", pool_collect },
	{ NULL, NULL }
};

TMODENTRY int luaopen_tek_lib_region(lua_State *L)
{
	struct Pool *pool;
	
	luaL_register(L, "tek.lib.region", tek_lib_region_funcs);
	/* s: libtab */
	
	lua_pushstring(L, TEK_LIB_REGION_VERSION);
	lua_setfield(L, -2, "_VERSION");
	
	lua_pop(L, 1);
	/* s: */

	/* require "tek.lib.exec": */
	lua_getglobal(L, "require");
	/* s: "require" */
	lua_pushliteral(L, "tek.lib.exec");
	/* s: "require", "tek.lib.exec" */
	lua_call(L, 1, 1);
	/* s: exectab */
	lua_getfield(L, -1, "base");
	/* s: exectab, execbase */
	lua_remove(L, -2);
	/* s: execbase */

	luaL_newmetatable(L, TEK_LIB_REGION_NAME);
	/* s: execbase, metatable */
	luaL_register(L, NULL, tek_lib_region_methods);
	/* s: execbase, metatable */
	lua_pushvalue(L, -1);
	/* s: execbase, metatable, metatable */
	lua_pushvalue(L, -3);
	/* s: execbase, metatable, metatable, execbase */
	lua_rawseti(L, -2, 1);
	/* s: execbase, metatable, metatable */
	
	pool = lua_newuserdata(L, sizeof(struct Pool));
	initrectlist(&pool->p_Rects);
	pool->p_ExecBase = *(TAPTR *) lua_touserdata(L, -4);
	/* s: execbase, metatable, metatable, pool */
	luaL_newmetatable(L, TEK_LIB_REGION_POOL_NAME);
	/* s: execbase, metatable, metatable, pool, poolmt */
	luaL_register(L, NULL, tek_lib_region_poolmethods);
	lua_setmetatable(L, -2);
	/* s: execbase, metatable, metatable, pool */
	lua_rawseti(L, -2, 2);
	/* s: execbase, metatable, metatable */
	
	lua_setfield(L, -2, "__index");
	/* s: execbase, metatable */
	lua_pop(L, 2);
	/* s: */

	return 0;
}
