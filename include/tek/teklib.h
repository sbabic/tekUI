#ifndef _TEK_TEKLIB_H
#define _TEK_TEKLIB_H

/*
**	teklib/tek/teklib.h - Link library functions
**
**	Written by Timm S. Mueller <tmueller at neoscientists.org>
**	See copyright notice in teklib/COPYRIGHT
*/

/*****************************************************************************/

#include <tek/exec.h>

#ifdef __cplusplus
extern "C" {
#endif

TLIBAPI TAPTR TEKCreate(TTAGITEM *tags);
TLIBAPI void TDestroy(TAPTR handle);
TLIBAPI void TDestroyList(struct TList *list);
TLIBAPI TAPTR TNewInstance(TAPTR mod, TUINT possize, TUINT negsize);
TLIBAPI void TFreeInstance(TAPTR mod);
TLIBAPI void TInitVectors(TAPTR mod, const TMFPTR *vectors, TUINT numv);
TLIBAPI TTAG TGetTag(TTAGITEM *taglist, TUINT tag, TTAG defvalue);
TLIBAPI void TInitList(struct TList *list);
TLIBAPI void TAddHead(struct TList *list, struct TNode *node);
TLIBAPI void TAddTail(struct TList *list, struct TNode *node);
TLIBAPI struct TNode *TRemHead(struct TList *list);
TLIBAPI struct TNode *TRemTail(struct TList *list);
TLIBAPI void TRemove(struct TNode *node);
TLIBAPI void TNodeUp(struct TNode *node);
TLIBAPI void TInsert(struct TList *list, struct TNode *node,
	struct TNode *prednode);
TLIBAPI TBOOL TForEachTag(struct TTagItem *taglist, struct THook *hook);
TLIBAPI struct THandle *TFindHandle(struct TList *list, TSTRPTR s2);
TLIBAPI void TInitHook(struct THook *hook, THOOKFUNC func, TAPTR data);
TLIBAPI TTAG TCallHookPkt(struct THook *hook, TAPTR obj, TTAG msg);
TLIBAPI void TAddTime(TTIME *a, TTIME *b);
TLIBAPI void TSubTime(TTIME *a, TTIME *b);
TLIBAPI TINT TCmpTime(TTIME *a, TTIME *b);
TLIBAPI void TAddDate(TDATE *d, TINT ndays, TTIME *tm);
TLIBAPI void TSubDate(TDATE *d, TINT ndays, TTIME *tm);
TLIBAPI TINT TDiffDate(TDATE *d1, TDATE *d2, TTIME *tm);
TLIBAPI TBOOL TCreateTime(TTIME *t, TINT d, TINT s, TINT us);
TLIBAPI TBOOL TExtractTime(TTIME *t, TINT *d, TINT *s, TINT *us);

#ifdef __cplusplus
}
#endif

#endif
