/*-----------------------------------------------------------------------------
--
--	tek.lib.region
--	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
--	See copyright notice in COPYRIGHT
--
--	OVERVIEW::
--		This library implements the management of regions, which are
--		collections of non-overlapping rectangles.
--
--	FUNCTIONS::
--		- Region:andRect() - ''And''s a rectangle to a region
--		- Region:andRegion() - ''And''s a region to a region
--		- Region:checkIntersect() - Checks if a rectangle intersects a region
--		- Region:forEach() - Calls a function for each rectangle in a region
--		- Region.intersect() - Returns the intersection of two rectangles
--		- Region:isEmpty() - Checks if a Region is empty
--		- Region.new() - Creates a new Region
--		- Region:orRect() - ''Or''s a rectangle to a region
--		- Region:setRect() - Resets a region to the given rectangle
--		- Region:shift() - Displaces a region
--		- Region:subRect() - Subtracts a rectangle from a region
--		- Region:subRegion() - Subtracts a region from a region
--		- Region:xorRect() - ''Exclusive Or''s a rectangle to a region
--
-------------------------------------------------------------------------------

module "tek.lib.region"
_VERSION = "Region 10.2"
local Region = _M

******************************************************************************/

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <tek/debug.h>
#include <tek/teklib.h>
#include <tek/proto/exec.h>
#include <tek/lib/tekui.h>

#define TEK_LIB_REGION_VERSION "Region 10.2"
#define TEK_LIB_REGION_NAME "tek.lib.region*"
#define TEK_LIB_REGION_POOL_NAME "tek.lib.pool*"

/*****************************************************************************/

#define MERGE_RECTS	5
#define MAXPOOLNODES 1024

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

static void region_relinklist(struct TList *dlist, struct TList *slist)
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
	}
}

static struct RectNode *region_allocrectnode(struct Pool *pool,
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

static void region_initrectlist(struct RectList *rl)
{
	TINITLIST(&rl->rl_List);
	rl->rl_NumNodes = 0;
}

static void region_relinkrects(struct RectList *d, struct RectList *s)
{
	region_relinklist(&d->rl_List, &s->rl_List);
	d->rl_NumNodes += s->rl_NumNodes;
	region_initrectlist(s);	
}

static void region_freerects(struct Pool *p, struct RectList *list)
{
	struct TNode *temp;
	region_relinkrects(&p->p_Rects, list);
	while (p->p_Rects.rl_NumNodes > MAXPOOLNODES)
	{
		TExecFree(p->p_ExecBase, TREMTAIL(&p->p_Rects.rl_List, temp));
		p->p_Rects.rl_NumNodes--;
	}	
}

static TBOOL region_insertrect(struct Pool *pool, struct RectList *list,
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

	rn = region_allocrectnode(pool, s0, s1, s2, s3);
	if (rn)
	{
		TADDHEAD(&list->rl_List, &rn->rn_Node, temp);
		list->rl_NumNodes++;
		return TTRUE;
	}

	return TFALSE;
}

static TBOOL region_cutrect(struct Pool *pool, struct RectList *list,
	const RECTINT d[4], const RECTINT s[4])
{
	TINT d0 = d[0];
	TINT d1 = d[1];
	TINT d2 = d[2];
	TINT d3 = d[3];

	if (!TEK_UI_OVERLAPRECT(d, s))
		return region_insertrect(pool, list, d[0], d[1], d[2], d[3]);

	for (;;)
	{
		if (d0 < s[0])
		{
			if (!region_insertrect(pool, list, d0, d1, s[0] - 1, d3))
				break;
			d0 = s[0];
		}

		if (d1 < s[1])
		{
			if (!region_insertrect(pool, list, d0, d1, d2, s[1] - 1))
				break;
			d1 = s[1];
		}

		if (d2 > s[2])
		{
			if (!region_insertrect(pool, list, s[2] + 1, d1, d2, d3))
				break;
			d2 = s[2];
		}

		if (d3 > s[3])
		{
			if (!region_insertrect(pool, list, d0, s[3] + 1, d2, d3))
				break;
		}

		return TTRUE;

	}
	return TFALSE;
}

static TBOOL region_cutrectlist(struct Pool *pool, struct RectList *inlist,
	struct RectList *outlist, const RECTINT s[4])
{
	TBOOL success = TTRUE;
	struct TNode *next, *node = inlist->rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		struct RectList temp;
		region_initrectlist(&temp);
		success = region_cutrect(pool, &temp, rn->rn_Rect, s);
		if (success)
		{
			struct TNode *next2, *node2 = temp.rl_List.tlh_Head;
			for (; success && (next2 = node2->tln_Succ); node2 = next2)
			{
				struct RectNode *rn2 = (struct RectNode *) node2;
				success = region_insertrect(pool, outlist, rn2->rn_Rect[0],
					rn2->rn_Rect[1], rn2->rn_Rect[2], rn2->rn_Rect[3]);
				/* note that if unsuccessful, outlist is unusable as well */
			}
		}
		region_freerects(pool, &temp);
	}
	return success;
}

static TBOOL region_orrectlist(struct Pool *pool, struct RectList *list, 
	RECTINT s[4])
{
	if (list->rl_NumNodes > 0)
	{
		struct TNode *next, *node = list->rl_List.tlh_Head;
		for (; (next = node->tln_Succ); node = next)
		{
			struct RectNode *rn = (struct RectNode *) node;
			TINT *r = rn->rn_Rect;
			if (s[0] >= r[0] && s[1] >= r[1] &&
				s[2] <= r[2] && s[3] <= r[3])
			{
				return TTRUE;
			}
		}
	}
	
	struct RectList temp;
	region_initrectlist(&temp);
	if (region_cutrectlist(pool, list, &temp, s))
	{
		if (region_insertrect(pool, &temp, s[0], s[1], s[2], s[3]))
		{
			region_freerects(pool, list);
			region_relinkrects(list, &temp);
			return TTRUE;
		}
	}
	region_freerects(pool, &temp);
	return TFALSE;
}

static TBOOL orregion(struct Region *region, struct RectList *list)
{
	TBOOL success = TTRUE;
	struct TNode *next, *node = list->rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		success = region_orrectlist(region->rg_Pool, 
			&region->rg_Rects, rn->rn_Rect);
	}
	return success;
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
		if (TEK_UI_OVERLAP(x0, y0, x1, y1, s0, s1, s2, s3))
		{
			success = region_insertrect(region->rg_Pool, temp,
				TMAX(x0, s0), TMAX(y0, s1), TMIN(x1, s2), TMIN(y1, s3));
		}
	}
	if (!success)
		region_freerects(region->rg_Pool, temp);
	return success;
}

/*****************************************************************************/

static void *region_checkregion(lua_State *L, int n)
{
	return luaL_checkudata(L, n, TEK_LIB_REGION_NAME);
}

static void *region_optregion(lua_State *L, int n)
{
	if (lua_type(L, n) == LUA_TUSERDATA)
		return luaL_checkudata(L, n, TEK_LIB_REGION_NAME);
	return TNULL;
}

/*-----------------------------------------------------------------------------
--	x0, y0, x1, y1 = Region.intersect(d1, d2, d3, d4, s1, s2, s3, s4):
--	Returns the coordinates of a rectangle where a rectangle specified by
--	the coordinates s1, s2, s3, s4 overlaps with the rectangle specified
--	by the coordinates d1, d2, d3, d4. The return value is '''nil''' if
--	the rectangles do not overlap.
-----------------------------------------------------------------------------*/

static int region_intersect(lua_State *L)
{
	TINT d0 = luaL_checkinteger(L, 1);
	TINT d1 = luaL_checkinteger(L, 2);
	TINT d2 = luaL_checkinteger(L, 3);
	TINT d3 = luaL_checkinteger(L, 4);
	TINT s0 = luaL_checkinteger(L, 5);
	TINT s1 = luaL_checkinteger(L, 6);
	TINT s2 = luaL_checkinteger(L, 7);
	TINT s3 = luaL_checkinteger(L, 8);

	if (TEK_UI_OVERLAP(d0, d1, d2, d3, s0, s1, s2, s3))
	{
		lua_pushinteger(L, TMAX(s0, d0));
		lua_pushinteger(L, TMAX(s1, d1));
		lua_pushinteger(L, TMIN(s2, d2));
		lua_pushinteger(L, TMIN(s3, d3));
		return 4;
	}
	
	return 0;
}

/*-----------------------------------------------------------------------------
--	region = Region.new(r1, r2, r3, r4): Creates a new region from the given
--	coordinates.
-----------------------------------------------------------------------------*/

static int region_new(lua_State *L)
{
	struct Region *region = lua_newuserdata(L, sizeof(struct Region));
	/* s: udata */
	region_initrectlist(&region->rg_Rects);
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
		if (region_insertrect(region->rg_Pool,
			&region->rg_Rects, x0, y0, x1, y1) == TFALSE)
			luaL_error(L, "out of memory");
	}
	else if (lua_gettop(L) != 1)
		luaL_error(L, "wrong number of arguments");

	return 1;
}

/*-----------------------------------------------------------------------------
--	self = region:setRect(r1, r2, r3, r4): Resets an existing region
--	to the specified rectangle.
-----------------------------------------------------------------------------*/

static int region_set(lua_State *L)
{
	struct Region *region = region_checkregion(L, 1);
	TINT x0 = luaL_checkinteger(L, 2);
	TINT y0 = luaL_checkinteger(L, 3);
	TINT x1 = luaL_checkinteger(L, 4);
	TINT y1 = luaL_checkinteger(L, 5);
	region_freerects(region->rg_Pool, &region->rg_Rects);
	if (region_insertrect(region->rg_Pool, &region->rg_Rects,
		x0, y0, x1, y1) == TFALSE)
		luaL_error(L, "out of memory");
	lua_pushvalue(L, 1);
	return 1;
}

static int region_collect(lua_State *L)
{
	struct Region *region = region_checkregion(L, 1);
	region_freerects(region->rg_Pool, &region->rg_Rects);
	return 0;
}

/*-----------------------------------------------------------------------------
--	region:orRect(r1, r2, r3, r4): Logical ''or''s a rectangle to a region
-----------------------------------------------------------------------------*/

static int region_orrect(lua_State *L)
{
	struct Region *region = region_checkregion(L, 1);
	RECTINT s[4];

	s[0] = luaL_checkinteger(L, 2);
	s[1] = luaL_checkinteger(L, 3);
	s[2] = luaL_checkinteger(L, 4);
	s[3] = luaL_checkinteger(L, 5);

	if (!region_orrectlist(region->rg_Pool, &region->rg_Rects, s))
		luaL_error(L, "out of memory");

	return 0;
}

/*-----------------------------------------------------------------------------
--	region:xorRect(r1, r2, r3, r4): Logical ''xor''s a rectange to a region
-----------------------------------------------------------------------------*/

static int region_xorrect(lua_State *L)
{
	struct Region *region = region_checkregion(L, 1);
	struct Pool *pool = region->rg_Pool;
	struct TNode *next, *node;
	TBOOL success;
	struct RectList r1, r2;
	RECTINT s[4];

	s[0] = luaL_checkinteger(L, 2);
	s[1] = luaL_checkinteger(L, 3);
	s[2] = luaL_checkinteger(L, 4);
	s[3] = luaL_checkinteger(L, 5);

	region_initrectlist(&r1);
	region_initrectlist(&r2);

	success = region_insertrect(pool, &r2, s[0], s[1], s[2], s[3]);

	node = region->rg_Rects.rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct TNode *next2, *node2;
		struct RectNode *rn = (struct RectNode *) node;
		struct RectList temp;

		region_initrectlist(&temp);
		success = region_cutrect(pool, &temp, rn->rn_Rect, s);

		node2 = temp.rl_List.tlh_Head;
		for (; success && (next2 = node2->tln_Succ); node2 = next2)
		{
			struct RectNode *rn2 = (struct RectNode *) node2;
			success = region_insertrect(pool, &r1, rn2->rn_Rect[0],
				rn2->rn_Rect[1], rn2->rn_Rect[2], rn2->rn_Rect[3]);
		}
		
		region_freerects(pool, &temp);

		if (success)
		{
			success = region_cutrectlist(pool, &r2, &temp, rn->rn_Rect);
			region_freerects(pool, &r2);
			region_relinkrects(&r2, &temp);
		}
	}

	if (success)
	{
		region_freerects(pool, &region->rg_Rects);
		region_relinkrects(&region->rg_Rects, &r1);
		orregion(region, &r2);
		region_freerects(pool, &r2);
	}
	else
	{
		region_freerects(pool, &r1);
		region_freerects(pool, &r2);
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

	region_initrectlist(&r1);
	node = region->rg_Rects.rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct TNode *next2, *node2;
		struct RectNode *rn = (struct RectNode *) node;
		struct RectList temp;

		region_initrectlist(&temp);
		success = region_cutrect(pool, &temp, rn->rn_Rect, s);

		node2 = temp.rl_List.tlh_Head;
		for (; success && (next2 = node2->tln_Succ); node2 = next2)
		{
			struct RectNode *rn2 = (struct RectNode *) node2;
			success = region_insertrect(pool, &r1, rn2->rn_Rect[0],
				rn2->rn_Rect[1], rn2->rn_Rect[2], rn2->rn_Rect[3]);
		}

		region_freerects(pool, &temp);
	}

	if (success)
	{
		region_freerects(pool, &region->rg_Rects);
		region_relinkrects(&region->rg_Rects, &r1);
	}
	else
	{
		region_freerects(pool, &r1);
		luaL_error(L, "out of memory");
	}

	return success;
}

/*-----------------------------------------------------------------------------
--	self = region:subRect(r1, r2, r3, r4): Subtracts a rectangle from a region
-----------------------------------------------------------------------------*/

static int region_subrect(lua_State *L)
{
	struct Region *region = region_checkregion(L, 1);
	RECTINT s[4];
	s[0] = luaL_checkinteger(L, 2);
	s[1] = luaL_checkinteger(L, 3);
	s[2] = luaL_checkinteger(L, 4);
	s[3] = luaL_checkinteger(L, 5);
	subrect(L, region, s);
	lua_pushvalue(L, 1);
	return 1;
}

/*-----------------------------------------------------------------------------
--	success = region:checkIntersect(x0, y0, x1, y1): Returns a boolean
--	indicating whether a rectangle specified by its coordinates overlaps
--	with a region.
-----------------------------------------------------------------------------*/

static int region_checkintersect(lua_State *L)
{
	struct Region *region = region_checkregion(L, 1);
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
		if (TEK_UI_OVERLAPRECT(rn->rn_Rect, s))
		{
			lua_pushboolean(L, 1);
			return 1;
		}
	}
	lua_pushboolean(L, 0);
	return 1;
}

/*-----------------------------------------------------------------------------
--	region:subRegion(region2): Subtracts {{region2}} from {{region}}.
-----------------------------------------------------------------------------*/

static int region_subregion(lua_State *L)
{
	struct Region *self = region_checkregion(L, 1);
	struct Region *region = region_optregion(L, 2);
	
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

/*-----------------------------------------------------------------------------
--	region:andRect(r1, r2, r3, r4): Logical ''and''s a rectange to a region
-----------------------------------------------------------------------------*/

static int region_andrect(lua_State *L)
{
	struct Region *self = region_checkregion(L, 1);
	struct RectList temp;
	
	region_initrectlist(&temp);
	if (andrect(&temp, self,
		luaL_checkinteger(L, 2), luaL_checkinteger(L, 3),
		luaL_checkinteger(L, 4), luaL_checkinteger(L, 5)))
	{
		region_freerects(self->rg_Pool, &self->rg_Rects);
		region_relinkrects(&self->rg_Rects, &temp);
		return TTRUE;
	}
	return TFALSE;
}

/*-----------------------------------------------------------------------------
--	region:andRegion(r): Logically ''and''s a region to a region
-----------------------------------------------------------------------------*/

static int region_andregion(lua_State *L)
{
	struct Region *dregion = region_checkregion(L, 1);
	struct Region *sregion = region_optregion(L, 2);
	struct TNode *next, *node = sregion->rg_Rects.rl_List.tlh_Head;
	TBOOL success = TTRUE;
	struct RectList temp;
	region_initrectlist(&temp);
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *sr = (struct RectNode *) node;
		success = andrect(&temp, dregion, sr->rn_Rect[0],
			sr->rn_Rect[1], sr->rn_Rect[2], sr->rn_Rect[3]);
	}
	if (success)
	{
		region_freerects(dregion->rg_Pool, &dregion->rg_Rects);
		region_relinkrects(&dregion->rg_Rects, &temp);
	}
	/* note: if unsucessful, dregion is of no use anymore */
	return success;
}

/*-----------------------------------------------------------------------------
--	region:forEach(func, obj, ...): For each rectangle in a region, calls the
--	specified function according the following scheme:
--			func(obj, x0, y0, x1, y1, ...)
--	Extra arguments are passed through to the function.
-----------------------------------------------------------------------------*/

static int region_foreach(lua_State *L)
{
	struct Region *region = region_checkregion(L, 1);
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

/*-----------------------------------------------------------------------------
--	region:shift(dx, dy): Shifts a region by delta x and y.
-----------------------------------------------------------------------------*/

static int region_shift(lua_State *L)
{
	struct Region *region = region_checkregion(L, 1);
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

/*-----------------------------------------------------------------------------
--	region:isEmpty(): Returns '''true''' if a region is empty.
-----------------------------------------------------------------------------*/

static int region_isempty(lua_State *L)
{
	struct Region *region = region_checkregion(L, 1);
	lua_pushboolean(L, TISLISTEMPTY(&region->rg_Rects.rl_List));
	return 1;
}

/*-----------------------------------------------------------------------------
--	minx, miny, maxx, maxy = region:get(): Get region's min/max extents
-----------------------------------------------------------------------------*/

static int region_getminmax(lua_State *L)
{
	struct Region *region = region_checkregion(L, 1);
	struct TNode *next, *node = region->rg_Rects.rl_List.tlh_Head;
	if (TISLISTEMPTY(&region->rg_Rects.rl_List))
		return 0;
	else
	{
		TINT minx = TEKUI_HUGE;
		TINT miny = TEKUI_HUGE;
		TINT maxx = 0;
		TINT maxy = 0;
		for (; (next = node->tln_Succ); node = next)
		{
			struct RectNode *rn = (struct RectNode *) node;
			TINT x0 = rn->rn_Rect[0];
			TINT y0 = rn->rn_Rect[1];
			TINT x1 = rn->rn_Rect[2];
			TINT y1 = rn->rn_Rect[3];
			minx = TMIN(minx, x0);
			miny = TMIN(miny, y0);
			maxx = TMAX(maxx, x1);
			maxy = TMAX(maxy, y1);
		}
		lua_pushinteger(L, minx);
		lua_pushinteger(L, miny);
		lua_pushinteger(L, maxx);
		lua_pushinteger(L, maxy);
		return 4;
	}
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

static const luaL_Reg tek_lib_region_funcs[] =
{
	{ "new", region_new },
	{ "intersect", region_intersect },
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
	{ "get", region_getminmax },
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
	
#if LUA_VERSION_NUM < 502
	luaL_register(L, "tek.lib.region", tek_lib_region_funcs);
#else
	luaL_newlib(L, tek_lib_region_funcs);
#endif
	/* s: libtab */
	
	lua_pushstring(L, TEK_LIB_REGION_VERSION);
	lua_setfield(L, -2, "_VERSION");

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
#if LUA_VERSION_NUM < 502
	luaL_register(L, NULL, tek_lib_region_methods);
#else
	luaL_setfuncs(L, tek_lib_region_methods, 0);
#endif
	/* s: execbase, metatable */
	lua_pushvalue(L, -1);
	/* s: execbase, metatable, metatable */
	lua_pushvalue(L, -3);
	/* s: execbase, metatable, metatable, execbase */
	lua_rawseti(L, -2, 1);
	/* s: execbase, metatable, metatable */
	
	pool = lua_newuserdata(L, sizeof(struct Pool));
	region_initrectlist(&pool->p_Rects);
	pool->p_ExecBase = *(TAPTR *) lua_touserdata(L, -4);
	/* s: execbase, metatable, metatable, pool */
	luaL_newmetatable(L, TEK_LIB_REGION_POOL_NAME);
	/* s: execbase, metatable, metatable, pool, poolmt */
#if LUA_VERSION_NUM < 502
	luaL_register(L, NULL, tek_lib_region_poolmethods);
#else
	luaL_setfuncs(L, tek_lib_region_poolmethods, 0);
#endif
	lua_setmetatable(L, -2);
	/* s: execbase, metatable, metatable, pool */
	lua_rawseti(L, -2, 2);
	/* s: execbase, metatable, metatable */
	
	lua_setfield(L, -2, "__index");
	/* s: execbase, metatable */
	lua_pop(L, 2);
	/* s: */

	return 1;
}
