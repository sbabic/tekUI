
/*
**	display_rfb_region.c - Region utilities
**	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in COPYRIGHT
*/

#include "display_rfb_mod.h"

/*****************************************************************************/

#define MERGE_RECTS	5
#define MAXPOOLNODES 512
#define OPPORTUNISTIC_MERGE_PERCENT		25
#define OPPORTUNISTIC_MERGE_THRESHOLD	1000

#define OVERLAP(d0, d1, d2, d3, s0, s1, s2, s3) \
((s2) >= (d0) && (s0) <= (d2) && (s3) >= (d1) && (s1) <= (d3))

#define OVERLAPRECT(d, s) \
OVERLAP((d)[0], (d)[1], (d)[2], (d)[3], (s)[0], (s)[1], (s)[2], (s)[3])

/*****************************************************************************/

static void rfb_region_relinklist(struct TList *dlist, struct TList *slist)
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

static struct RectNode *rfb_region_allocrectnode(struct Pool *pool,
	TINT x0, TINT y0, TINT x1, TINT y1)
{
	struct TNode *temp;
	struct RectNode *rn = (struct RectNode *) 
		TREMHEAD(&pool->p_Rects.rl_List, temp);
	if (rn)
	{
		pool->p_Rects.rl_NumNodes--;
		assert(pool->p_Rects.rl_NumNodes >= 0);
	}
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

static void rfb_region_initrectlist(struct RectList *rl)
{
	TINITLIST(&rl->rl_List);
	rl->rl_NumNodes = 0;
}

static void rfb_region_relinkrects(struct RectList *d, struct RectList *s)
{
	rfb_region_relinklist(&d->rl_List, &s->rl_List);
	d->rl_NumNodes += s->rl_NumNodes;
	rfb_region_initrectlist(s);	
}

static void rfb_region_freerects(struct Pool *p, struct RectList *list)
{
	struct TNode *temp;
	rfb_region_relinkrects(&p->p_Rects, list);
	while (p->p_Rects.rl_NumNodes > MAXPOOLNODES)
	{
		TExecFree(p->p_ExecBase, TREMTAIL(&p->p_Rects.rl_List, temp));
		p->p_Rects.rl_NumNodes--;
	}
}

static TBOOL rfb_region_insertrect(struct Pool *pool, struct RectList *list,
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

	rn = rfb_region_allocrectnode(pool, s0, s1, s2, s3);
	if (rn)
	{
		TADDHEAD(&list->rl_List, &rn->rn_Node, temp);
		list->rl_NumNodes++;
		return TTRUE;
	}

	return TFALSE;
}

static TBOOL rfb_region_cutrect(struct Pool *pool, struct RectList *list,
	const RECTINT d[4], const RECTINT s[4])
{
	TINT d0 = d[0];
	TINT d1 = d[1];
	TINT d2 = d[2];
	TINT d3 = d[3];

	if (!OVERLAPRECT(d, s))
		return rfb_region_insertrect(pool, list, d[0], d[1], d[2], d[3]);

	for (;;)
	{
		if (d0 < s[0])
		{
			if (!rfb_region_insertrect(pool, list, d0, d1, s[0] - 1, d3))
				break;
			d0 = s[0];
		}

		if (d1 < s[1])
		{
			if (!rfb_region_insertrect(pool, list, d0, d1, d2, s[1] - 1))
				break;
			d1 = s[1];
		}

		if (d2 > s[2])
		{
			if (!rfb_region_insertrect(pool, list, s[2] + 1, d1, d2, d3))
				break;
			d2 = s[2];
		}

		if (d3 > s[3])
		{
			if (!rfb_region_insertrect(pool, list, d0, s[3] + 1, d2, d3))
				break;
		}

		return TTRUE;

	}
	return TFALSE;
}

static TBOOL rfb_region_cutrectlist(struct Pool *pool, struct RectList *inlist,
	struct RectList *outlist, const RECTINT s[4])
{
	TBOOL success = TTRUE;
	struct TNode *next, *node = inlist->rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		struct RectList temp;
		rfb_region_initrectlist(&temp);
		success = rfb_region_cutrect(pool, &temp, rn->rn_Rect, s);
		if (success)
		{
			struct TNode *next2, *node2 = temp.rl_List.tlh_Head;
			for (; success && (next2 = node2->tln_Succ); node2 = next2)
			{
				struct RectNode *rn2 = (struct RectNode *) node2;
				success = rfb_region_insertrect(pool, outlist, rn2->rn_Rect[0],
					rn2->rn_Rect[1], rn2->rn_Rect[2], rn2->rn_Rect[3]);
				/* note that if unsuccessful, outlist is unusable as well */
			}
		}
		rfb_region_freerects(pool, &temp);
	}
	return success;
}

static TBOOL rfb_region_orrectlist(struct Pool *pool, struct RectList *list, 
	TINT s[4], TBOOL opportunistic)
{
	if (list->rl_NumNodes > 0)
	{
		TINT x0 = s[0];
		TINT y0 = s[1];
		TINT x1 = s[2];
		TINT y1 = s[3];
		TUINT64 area = 0;
		
		struct TNode *next, *node = list->rl_List.tlh_Head;
		for (; (next = node->tln_Succ); node = next)
		{
			struct RectNode *rn = (struct RectNode *) node;
			TINT *r = rn->rn_Rect;
			if (s[0] >= r[0] && s[1] >= r[1] &&
				s[2] <= r[2] && s[3] <= r[3])
				return TTRUE;
			if (!opportunistic)
				continue;
			area += (r[2] - r[0] + 1) * (r[3] - r[1] + 1);
			x0 = TMIN(x0, r[0]);
			y0 = TMIN(y0, r[1]);
			x1 = TMAX(x1, r[2]);
			y1 = TMAX(y1, r[3]);
		}
		if (opportunistic)
		{
			TUINT64 area2 = (x1 - x0 + 1) * (y1 - y0 + 1);
			if (area2 < OPPORTUNISTIC_MERGE_THRESHOLD ||
				(area * 100 / area2) > OPPORTUNISTIC_MERGE_PERCENT)
			{
				/* merge list into a single rectangle */
				TDBPRINTF(TDB_TRACE,("merge %d rects\n",
					list->rl_NumNodes + 1));
				rfb_region_freerects(pool, list);
				assert(list->rl_NumNodes == 0);
				return rfb_region_insertrect(pool, list, x0, y0, x1, y1);
			}
		}
	}

	struct RectList temp;
	rfb_region_initrectlist(&temp);
	if (rfb_region_cutrectlist(pool, list, &temp, s))
	{
		if (rfb_region_insertrect(pool, &temp, s[0], s[1], s[2], s[3]))
		{
			rfb_region_freerects(pool, list);
			rfb_region_relinkrects(list, &temp);
			return TTRUE;
		}
	}
	rfb_region_freerects(pool, &temp);
	return TFALSE;
}

static TBOOL rfb_region_andrect_internal(struct RectList *temp,
	struct Region *region, TINT s[], TINT dx, TINT dy)
{
	struct Pool *pool = region->rg_Pool;
	struct TNode *next, *node = region->rg_Rects.rl_List.tlh_Head;
	TBOOL success = TTRUE;
	TINT s0 = s[0] + dx;
	TINT s1 = s[1] + dy;
	TINT s2 = s[2] + dx;
	TINT s3 = s[3] + dy;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *dr = (struct RectNode *) node;
		TINT x0 = dr->rn_Rect[0];
		TINT y0 = dr->rn_Rect[1];
		TINT x1 = dr->rn_Rect[2];
		TINT y1 = dr->rn_Rect[3];
		if (OVERLAP(x0, y0, x1, y1, s0, s1, s2, s3))
		{
			success = rfb_region_insertrect(pool, temp,
				TMAX(x0, s0), TMAX(y0, s1), TMIN(x1, s2), TMIN(y1, s3));
		}
	}
	if (!success)
		rfb_region_freerects(pool, temp);
	return success;
}




/*****************************************************************************/

LOCAL struct Region *rfb_region_new(struct Pool *pool, TINT *s)
{
	struct TExecBase *TExecBase = pool->p_ExecBase;
	struct Region *region = TAlloc(TNULL, sizeof(struct Region));
	if (region)
	{
		region->rg_Pool = pool;
		rfb_region_initrectlist(&region->rg_Rects);
		if (s && !rfb_region_insertrect(pool, &region->rg_Rects,
			s[0], s[1], s[2], s[3]))
		{
			TFree(region);
			region = TNULL;
		}
	}
	return region;
}

LOCAL void rfb_region_destroy(struct Pool *pool, struct Region *region)
{
	rfb_region_freerects(pool, &region->rg_Rects);
	TExecFree(pool->p_ExecBase, region);
}

LOCAL TBOOL rfb_region_overlap(struct Pool *p, struct Region *region,
	TINT s[])
{
	struct TNode *next, *node;
	node = region->rg_Rects.rl_List.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		if (OVERLAPRECT(rn->rn_Rect, s))
			return TTRUE;
	}
	return TFALSE;
}

LOCAL TBOOL rfb_region_subrect(struct Pool *pool, struct Region *region,
	TINT s[])
{
	struct RectList r1;
	struct TNode *next, *node;
	TBOOL success = TTRUE;

	rfb_region_initrectlist(&r1);
	node = region->rg_Rects.rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct TNode *next2, *node2;
		struct RectNode *rn = (struct RectNode *) node;
		struct RectList temp;
		
		rfb_region_initrectlist(&temp);
		success = rfb_region_cutrect(pool, &temp, rn->rn_Rect, s);

		node2 = temp.rl_List.tlh_Head;
		for (; success && (next2 = node2->tln_Succ); node2 = next2)
		{
			struct RectNode *rn2 = (struct RectNode *) node2;
			success = rfb_region_insertrect(pool, &r1, rn2->rn_Rect[0],
				rn2->rn_Rect[1], rn2->rn_Rect[2], rn2->rn_Rect[3]);
		}

		rfb_region_freerects(pool, &temp);
	}

	if (success)
	{
		rfb_region_freerects(pool, &region->rg_Rects);
		rfb_region_relinkrects(&region->rg_Rects, &r1);
	}
	else
		rfb_region_freerects(pool, &r1);

	return success;
}

LOCAL TBOOL rfb_region_subregion(struct Pool *pool, struct Region *dregion,
	struct Region *sregion)
{
	TBOOL success = TTRUE;
	struct TNode *next, *node;
	node = sregion->rg_Rects.rl_List.tlh_Head;
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		success = rfb_region_subrect(pool, dregion, rn->rn_Rect);
	}
	/* note: if unsucessful, dregion is of no use anymore */
	return success;
}

LOCAL TBOOL rfb_region_andrect(struct Pool *pool, struct Region *region,
	TINT s[], TINT dx, TINT dy)
{
	struct RectList temp;
	rfb_region_initrectlist(&temp);
	if (rfb_region_andrect_internal(&temp, region, s, dx, dy))
	{
		rfb_region_freerects(pool, &region->rg_Rects);
		rfb_region_relinkrects(&region->rg_Rects, &temp);
		return TTRUE;
	}
	return TFALSE;
}

LOCAL TBOOL rfb_region_andregion(struct Pool *pool, struct Region *dregion,
	struct Region *sregion)
{
	struct TNode *next, *node = sregion->rg_Rects.rl_List.tlh_Head;
	TBOOL success = TTRUE;
	struct RectList temp;
	rfb_region_initrectlist(&temp);
	for (; success && (next = node->tln_Succ); node = next)
	{
		struct RectNode *sr = (struct RectNode *) node;
		success = rfb_region_andrect_internal(&temp, dregion,
			sr->rn_Rect, 0, 0);
	}
	if (success)
	{
		rfb_region_freerects(pool, &dregion->rg_Rects);
		rfb_region_relinkrects(&dregion->rg_Rects, &temp);
	}
	/* note: if unsucessful, dregion is of no use anymore */
	return success;
}

LOCAL TBOOL rfb_region_isempty(struct Pool *pool, struct Region *region)
{
	return TISLISTEMPTY(&region->rg_Rects.rl_List);
}


/*****************************************************************************/


LOCAL TBOOL rfb_region_orrect(struct Pool *pool, struct Region *region,
	TINT s[4], TBOOL opportunistic)
{
	return rfb_region_orrectlist(pool, &region->rg_Rects, s, opportunistic);
}

LOCAL void rfb_region_initpool(struct Pool *pool, TAPTR TExecBase)
{
	rfb_region_initrectlist(&pool->p_Rects);
	pool->p_ExecBase = TExecBase;
}

LOCAL void rfb_region_destroypool(struct Pool *pool)
{
	TAPTR TExecBase = pool->p_ExecBase;
	struct TNode *temp;
	struct RectNode *rn;
	while ((rn = (struct RectNode *) TREMHEAD(&pool->p_Rects.rl_List, temp)))
	{
		pool->p_Rects.rl_NumNodes--;
		TFree(rn);
	}
	assert(pool->p_Rects.rl_NumNodes == 0);
}

LOCAL TBOOL rfb_region_intersect(TINT *d0, TINT *d1, TINT *d2, TINT *d3,
	TINT s0, TINT s1, TINT s2, TINT s3)
{
	if (OVERLAP(*d0, *d1, *d2, *d3, s0, s1, s2, s3))
	{
		*d0 = TMAX(*d0, s0);
		*d1 = TMAX(*d1, s1);
		*d2 = TMIN(*d2, s2);
		*d3 = TMIN(*d3, s3);
		return TTRUE;
	}
	return TFALSE;
}
