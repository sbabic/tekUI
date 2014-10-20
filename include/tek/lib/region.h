#ifndef _TEK_LIB_REGION_H
#define _TEK_LIB_REGION_H

#include <tek/exec.h>

/*
**	region.h - Region library
**	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

typedef TINT RECTINT;

struct RectList
{
	struct TList rl_List;
	TINT rl_NumNodes;
};

struct RectPool
{
	struct RectList p_Rects;
	struct TExecBase *p_ExecBase;
};

struct Region
{
	struct RectList rg_Rects;
	struct RectPool *rg_Pool;
};

struct RectNode
{
	struct TNode rn_Node;
	RECTINT rn_Rect[4];
};

TLIBAPI TBOOL region_intersect(TINT *d, TINT *s);
TLIBAPI void region_initrectlist(struct RectList *rl);

TLIBAPI struct Region *region_new(struct RectPool *, TINT *s);
TLIBAPI void region_destroy(struct RectPool *, struct Region *region);
TLIBAPI TBOOL region_overlap(struct RectPool *, struct Region *region, TINT s[]);
TLIBAPI TBOOL region_subrect(struct RectPool *, struct Region *region, TINT s[]);
TLIBAPI TBOOL region_subregion(struct RectPool *, struct Region *dregion, struct Region *sregion);
TLIBAPI TBOOL region_andrect(struct RectPool *, struct Region *region, TINT s[], TINT dx, TINT dy);
TLIBAPI TBOOL region_andregion(struct RectPool *, struct Region *dregion, struct Region *sregion);
TLIBAPI TBOOL region_isempty(struct RectPool *, struct Region *region);
TLIBAPI TBOOL region_orrect(struct RectPool *, struct Region *region, TINT r[], TBOOL opportunistic);
TLIBAPI void region_initpool(struct RectPool *pool, TAPTR TExecBase);
TLIBAPI void region_destroypool(struct RectPool *pool);
TLIBAPI TBOOL region_insertrect(struct RectPool *pool, struct RectList *list, TINT s0, TINT s1, TINT s2, TINT s3);
TLIBAPI void region_freerects(struct RectPool *p, struct RectList *list);
TLIBAPI TBOOL region_orrectlist(struct RectPool *pool, struct RectList *list, TINT s[4], TBOOL opportunistic);
TLIBAPI TBOOL region_xorrect(struct RectPool *pool, struct Region *region, RECTINT s[]);
TLIBAPI TBOOL region_orregion(struct Region *region, struct RectList *list, TBOOL opportunistic);
TLIBAPI TBOOL region_getminmax(struct RectPool *pool, struct Region *region, TINT *minmax);
TLIBAPI void region_shift(struct Region *region, TINT dx, TINT dy);

#endif /* _TEK_LIB_REGION_H */
