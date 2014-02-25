
/*
**	display_rfb_font.c - Raw framebuffer display driver
**	Written by Franciska Schulze <fschulze at schulze-mueller.de>
**	and Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

#include <assert.h>
#include <ctype.h>
#include <dirent.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>

#include <tek/debug.h>
#include <tek/teklib.h>
#include <tek/proto/hal.h>

#include "display_rfb_mod.h"

/*****************************************************************************/

struct fnt_node
{
	struct TNode node;
	TSTRPTR fname;
};

struct fnt_attr
{
	/* list of fontnames */
	struct TList fnlist;
	TSTRPTR fname;
	TINT  fpxsize;
	TBOOL fitalic;
	TBOOL fbold;
	TBOOL fscale;
	TINT  fnum;
};

static TBOOL hostopenfont(RFBDISPLAY *mod, struct FontNode *fn,
	struct fnt_attr *fattr);
static void hostqueryfonts(RFBDISPLAY *mod, struct FontQueryHandle *fqh,
	struct fnt_attr *fattr);
static TINT hostprepfont(RFBDISPLAY *mod, TAPTR font, TUINT32* text, 
	TINT textlen);

/*****************************************************************************/
/*
**	UTF-8 support
*/

struct readstringdata
{
	const unsigned char *src;
	size_t srclen;
};

struct utf8reader
{
	/* character reader callback: */
	int (*readchar)(struct utf8reader *);
	/* reader state: */
	int accu, numa, min, bufc;
	/* userdata to reader */
	void *udata;
	struct readstringdata rsdata;
};

static int readutf8(struct utf8reader *rd)
{
	int c;
	for (;;)
	{
		if (rd->bufc >= 0)
		{
			c = rd->bufc;
			rd->bufc = -1;
		}
		else
			c = rd->readchar(rd);
		if (c < 0)
			return c;

		if (c == 254 || c == 255)
			break;

		if (c < 128)
		{
			if (rd->numa > 0)
			{
				rd->bufc = c;
				break;
			}
			return c;
		}
		else if (c < 192)
		{
			if (rd->numa == 0)
				break;
			rd->accu <<= 6;
			rd->accu += c - 128;
			rd->numa--;
			if (rd->numa == 0)
			{
				if (rd->accu == 0 || rd->accu < rd->min ||
					(rd->accu >= 55296 && rd->accu <= 57343))
					break;
				c = rd->accu;
				rd->accu = 0;
				return c;
			}
		}
		else
		{
			if (rd->numa > 0)
			{
				rd->bufc = c;
				break;
			}

			if (c < 224)
			{
				rd->min = 128;
				rd->accu = c - 192;
				rd->numa = 1;
			}
			else if (c < 240)
			{
				rd->min = 2048;
				rd->accu = c - 224;
				rd->numa = 2;
			}
			else if (c < 248)
			{
				rd->min = 65536;
				rd->accu = c - 240;
				rd->numa = 3;
			}
			else if (c < 252)
			{
				rd->min = 2097152;
				rd->accu = c - 248;
				rd->numa = 4;
			}
			else
			{
				rd->min = 67108864;
				rd->accu = c - 252;
				rd->numa = 5;
			}
		}
	}
	/* bad char */
	rd->accu = 0;
	rd->numa = 0;
	return 65533;
}

static int readstring(struct utf8reader *rd)
{
	struct readstringdata *ud = rd->udata;
	if (ud->srclen == 0)
		return -1;
	ud->srclen--;
	return *ud->src++;
}

static void initutf8reader(struct utf8reader *rd, 
	const unsigned char *utf8text, size_t bytelen)
{
	rd->rsdata.src = utf8text;
	rd->rsdata.srclen = bytelen;
	rd->readchar = readstring;
	rd->accu = 0;
	rd->numa = 0;
	rd->bufc = -1;
	rd->udata = &rd->rsdata;
}

/*****************************************************************************/

LOCAL FT_Error rfb_fontrequester(FTC_FaceID faceID, FT_Library lib, 
	FT_Pointer reqData, FT_Face *face)
{
	struct FontNode *facenode = (struct FontNode *) faceID;
	return FT_New_Face(lib, facenode->name, 0, face);
}

/*****************************************************************************/

static const char *getfontdir()
{
	char *fontdir = getenv("FONTDIR");
	if (!fontdir)
		fontdir = FNT_DEFDIR;
	return (const char *) fontdir;
}

/*****************************************************************************/
/* FontQueryHandle destructor
** free all memory associated with a fontqueryhandle including
** all fontquerynodes, a fontqueryhandle is obtained by calling
** rfb_hostqueryfonts()
*/

THOOKENTRY TTAG fqhdestroy(struct THook *hook, TAPTR obj, TTAG msg)
{
	if (msg == TMSG_DESTROY)
	{
		struct FontQueryHandle *fqh = obj;
		RFBDISPLAY *mod = fqh->handle.thn_Owner;
		TAPTR TExecBase = mod->rfb_ExecBase;
		struct TNode *node, *next;

		node = fqh->reslist.tlh_Head;
		for (; (next = node->tln_Succ); node = next)
		{
			struct FontQueryNode *fqn = (struct FontQueryNode *)node;

			/* remove from resultlist */
			TRemove(&fqn->node);

			/* destroy fontname */
			if (fqn->tags[0].tti_Value)
				TFree((TAPTR) fqn->tags[0].tti_Value);

			/* destroy node */
			TFree(fqn);
		}

		/* destroy queryhandle */
		TFree(fqh);
	}

	return 0;
}

/*****************************************************************************/
/* allocate a fontquerynode and fill in properties
*/

static struct FontQueryNode *fnt_getfqnode(RFBDISPLAY *mod, TSTRPTR filename,
	TINT pxsize)
{
	struct FontQueryNode *fqnode = TNULL;
	TAPTR TExecBase = TGetExecBase(mod);

	/* allocate fquery node */
	fqnode = TAlloc0(mod->rfb_MemMgr, sizeof(struct FontQueryNode));
	if (fqnode)
	{
		/* fquerynode ready - fill in attributes */
		TSTRPTR myfname = TNULL;
		TINT flen = strlen(filename) - 4; /* discard '.ttf' */

		if (flen > 0)
			myfname = TAlloc0(mod->rfb_MemMgr, flen + 1);
		else
			TDBPRINTF(20, ("found invalid font: '%s'\n", filename));

		if (myfname)
		{
			memcpy(myfname, filename, flen);
			fqnode->tags[0].tti_Tag = TVisual_FontName;
			fqnode->tags[0].tti_Value = (TTAG) myfname;
		}
		else
		{
			if (flen > 0)
				TDBPRINTF(20, ("out of memory :(\n"));
		}

		if (fqnode->tags[0].tti_Value)
		{
			TINT i = 1;

			fqnode->tags[i].tti_Tag = TVisual_FontPxSize;
			fqnode->tags[i++].tti_Value = (TTAG) pxsize;

			/* always true */
			fqnode->tags[i].tti_Tag = TVisual_FontScaleable;
			fqnode->tags[i++].tti_Value = (TTAG) TTRUE;

			fqnode->tags[i].tti_Tag = TTAG_DONE;
		}
		else
		{
			TFree(fqnode);
			fqnode = TNULL;
		}

	} /* endif fqnode */
	else
		TDBPRINTF(20, ("out of memory :(\n"));

	return fqnode;
}

/*****************************************************************************/
/* check if a font with similar properties is already contained
** in our resultlist
*/

static TBOOL fnt_checkfqnode(struct TList *rlist, struct FontQueryNode *fqnode)
{
	TUINT8 flags;
	TBOOL match = TFALSE;
	struct TNode *node, *next;
	TSTRPTR newfname = (TSTRPTR)fqnode->tags[0].tti_Value;
	TINT newpxsize = (TINT)fqnode->tags[1].tti_Value;

	/* not yet
	TBOOL newslant = (TBOOL)fqnode->tags[2].tti_Value;
	TBOOL newweight = (TBOOL)fqnode->tags[3].tti_Value;
	*/

	TSIZE flen = strlen(newfname);

	for (node = rlist->tlh_Head; (next = node->tln_Succ); node = next)
	{
		struct FontQueryNode *fqn = (struct FontQueryNode *)node;
		flags = 0;

		if (strlen((TSTRPTR) fqn->tags[0].tti_Value) == flen)
		{
			if (strncmp((TSTRPTR)fqn->tags[0].tti_Value, newfname, flen) == 0)
				flags = FNT_MATCH_NAME;
		}

		if ((TINT)fqn->tags[1].tti_Value == newpxsize)
			flags |= FNT_MATCH_SIZE;

		/* not yet
		if ((TBOOL)fqn->tags[2].tti_Value == newslant)
			flags |= FNT_MATCH_SLANT;

		if ((TBOOL)fqn->tags[3].tti_Value == newweight)
			flags |= FNT_MATCH_WEIGHT;
		*/

		if (flags == FNT_MATCH_ALL)
		{
			/* fqnode is not unique */
			match = TTRUE;
			break;
		}
	}

	return match;
}

#if 0
/*****************************************************************************/
/* dump properties of a fontquerynode
*/

static void fnt_dumpnode(struct FontQueryNode *fqn)
{
	TDBPRINTF(10, ("-----------------------------------------------\n"));
	TDBPRINTF(10, ("dumping fontquerynode @ %p\n", fqn));
	TDBPRINTF(10, (" * FontName: %s\n", (TSTRPTR)fqn->tags[0].tti_Value));
	TDBPRINTF(10, (" * PxSize:   %d\n", (TINT)fqn->tags[1].tti_Value));
	//TDBPRINTF(10, (" * Italic:   %s\n", (TBOOL)fqn->tags[2].tti_Value ? "on" : "off"));
	//TDBPRINTF(10, (" * Bold:     %s\n", (TBOOL)fqn->tags[3].tti_Value ? "on" : "off"));
	TDBPRINTF(10, ("-----------------------------------------------\n"));
}

/*****************************************************************************/
/* dump all fontquerynodes of a (result-)list
*/

static void fnt_dumplist(struct TList *rlist)
{
	struct TNode *node, *next;
	node = rlist->tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		struct FontQueryNode *fqn = (struct FontQueryNode *)node;
		fnt_dumpnode(fqn);
	}
}
#endif

/*****************************************************************************/
/* parses a single fontname or a comma separated list of fontnames
** and returns a list of fontnames, spaces are NOT filtered, so
** "helvetica, fixed" will result in "helvetica" and " fixed"
*/

static void fnt_getfnnodes(RFBDISPLAY *mod, struct TList *fnlist, 
	TSTRPTR fname)
{
	TINT i, p = 0;
	TBOOL lastrun = TFALSE;
	TINT fnlen = strlen(fname);
	TAPTR TExecBase = mod->rfb_ExecBase;

	for (i = 0; i < fnlen; i++)
	{
		if (i == fnlen - 1) lastrun = TTRUE;

		if (fname[i] == ',' || lastrun)
		{
			TINT len = (i > p) ? (lastrun ? (i - p + 1) : (i - p)) : fnlen + 1;
			TSTRPTR ts = TAlloc0(mod->rfb_MemMgr, len + 1);
			if (ts)
			{
				struct fnt_node *fnn;
				memcpy(ts, fname + p, len);
				fnn = TAlloc0(mod->rfb_MemMgr, sizeof(struct fnt_node));
				if (fnn)
				{
					/* add fnnode to fnlist */
					fnn->fname = ts;
					TAddTail(fnlist, &fnn->node);
				}
				else
				{
					TDBPRINTF(20, ("out of memory :(\n"));
					break;
				}
			}
			else
			{
				TDBPRINTF(20, ("out of memory :(\n"));
				break;
			}

			p = i + 1;
		}
	}
}

/*****************************************************************************/
/* examine filename according to the specified flags and set the
** corresponding bits in the flagfield the function returns
** at the moment only FNT_MATCH_NAME is suppported
*/

static TUINT fnt_matchfont(RFBDISPLAY *mod, TSTRPTR filename, TSTRPTR fname,
	struct fnt_attr *fattr, TUINT flag)
{
	TUINT match = 0;

	if (flag & FNT_MATCH_NAME)
	{
		TINT i;
		TINT len = strlen(fname);

		if (strncmp(fname, FNT_WILDCARD, len) == 0)
		{
			/* match all, but filter out invalid filenames like '.' or '..' */
			if (strlen(filename) > 4)
				match = FNT_MATCH_NAME;
		}
		else
		{
			TSTRPTR tempname = TNULL;

			/* convert fontnames to lower case */
			for (i = 0; i < len; i++)
				fname[i] = tolower(fname[i]);

			tempname = TExecAlloc0(mod->rfb_ExecBase, mod->rfb_MemMgr, len+1);
			if (!tempname)
			{
				TDBPRINTF(20, ("out of memory :(\n"));
				return -1;
			}

			for (i = 0; i < len; i++)
				tempname[i] = tolower(filename[i]);

			/* compare converted fontnames */
			if (strncmp(fname, tempname, len) == 0)
				match = FNT_MATCH_NAME;

			TExecFree(mod->rfb_ExecBase, tempname);
		}
	}

	/* not yet
	if (flag & FNT_MATCH_SLANT)		;
	if (flag & FNT_MATCH_WEIGHT)	;
	*/

	return match;
}

/*****************************************************************************/
/* CALL:
**	rfb_hostopenfont(visualbase, tags)
**
** USE:
**  to match and open exactly one font, according to its properties
**
** INPUT:
**	tag name				| description
**	------------------------+---------------------------
**	 TVisual_FontName		| font name
**   TVisual_FontPxSize		| font size in pixel
**
**	tag name				| default¹	| wildcard
**	------------------------+-----------+---------------
**	 TVisual_FontName		| "decker"	| "*"
**   TVisual_FontPxSize		| 14		|  /
**
** ¹ the defaults are used when the tag is missing
**
** RETURN:
** - a pointer to a font ready to be used or TNULL
**
** EXAMPLES:
** - to open the default font of your platform leave all tags empty
** - to open the default font in say 16px, set TVisual_FontPxSize to
**   16 and leave all other tags empty
**
** NOTES:
** - this function won't activate the font, use setfont() to make the
**   font the current active font
** - the function will open the first matching font
*/

static void rfb_freefontnode(RFBDISPLAY *mod, struct FontNode *fn)
{
	if (!fn) return;
	TExecFree(mod->rfb_ExecBase, fn->name);
	TExecFree(mod->rfb_ExecBase, fn);
}

LOCAL TAPTR rfb_hostopenfont(RFBDISPLAY *mod, TTAGITEM *tags)
{
	struct fnt_attr fattr;
	struct FontNode *fn;
	TAPTR font = TNULL;

	/* fetch user specified attributes */
	fattr.fname = (TSTRPTR) TGetTag(tags, TVisual_FontName, 
		(TTAG) FNT_DEFNAME);
	fattr.fpxsize = (TINT) TGetTag(tags, TVisual_FontPxSize,
		(TTAG) FNT_DEFPXSIZE);

	/* not yet
	fattr.fitalic = (TBOOL) TGetTag(tags, TVisual_FontItalic, (TTAG) TFALSE);
	fattr.fbold = (TBOOL) TGetTag(tags, TVisual_FontBold, (TTAG) TFALSE);
	fattr.fscale = (TBOOL) TGetTag(tags, TVisual_FontScaleable, (TTAG) TFALSE);
	*/

	if (fattr.fname)
	{
		fn = TExecAlloc0(mod->rfb_ExecBase, mod->rfb_MemMgr,
			sizeof(struct FontNode));
		if (fn)
		{
			fn->handle.thn_Owner = mod;
			if (hostopenfont(mod, fn, &fattr))
			{
				/* load succeeded, save font attributes */
				fn->pxsize = fattr.fpxsize;
				fn->height = fn->face->size->metrics.height >> 6;
				fn->ascent = fn->face->size->metrics.ascender >> 6;
				fn->descent = fn->face->size->metrics.descender >> 6;

				/* not yet
				if (fattr.fitalic)
					fn->attr = FNT_ITALIC;
				if (fattr.fbold)
					fn->attr |= FNT_BOLD;
				*/

				/* append to the list of open fonts */
				TDBPRINTF(TDB_INFO, ("O '%s' %dpx\n", fattr.fname, 
					fattr.fpxsize));
				TAddTail(&mod->rfb_FontManager.openfonts,
					&fn->handle.thn_Node);
				font = (TAPTR) fn;
			}
			else
			{
				/* load failed, free fontnode */
				TDBPRINTF(TDB_TRACE,("X unable to load '%s'\n", fattr.fname));
				rfb_freefontnode(mod, fn);
			}
		}
		else
			TDBPRINTF(TDB_ERROR,("out of memory\n"));
	}
	else
		TDBPRINTF(TDB_ERROR,("X invalid fontname '%s' specified\n",
			fattr.fname));

	return font;
}

static TBOOL hostopenfont(RFBDISPLAY *mod, struct FontNode *fn,
	struct fnt_attr *fattr)
{
	const char *fontdir = getfontdir();
	fn->name = TExecAlloc0(mod->rfb_ExecBase, mod->rfb_MemMgr,
		strlen(fattr->fname) + strlen(fontdir) + 6);
	if (fn->name)
	{
		sprintf(fn->name, "%s/%s.ttf", fontdir, fattr->fname);
		if (FT_New_Face(mod->rfb_FTLibrary, fn->name, 0, &fn->face) == 0
			&& FT_IS_SCALABLE(fn->face))
		{
			TDBPRINTF(TDB_TRACE,("opened font '%s'\n", fn->name));
			FT_Set_Char_Size(fn->face, 0, fattr->fpxsize << 6, 72, 72);
			return TTRUE;
		}
		TDBPRINTF(TDB_TRACE,("failed to open font '%s'\n", fn->name));
		TExecFree(mod->rfb_ExecBase, fn->name);
		fn->name = TNULL;
	}
	return TFALSE;
}

/*****************************************************************************/
/* CALL:
**  rfb_hostqueryfonts(visualbase, tags)
**
** USE:
**  to match one or more fonts, according to their properties
**
** INPUT:
**	tag name				| description
**	------------------------+---------------------------
**	 TVisual_FontName		| font name
**   TVisual_FontPxSize		| font size in pixel
**	 TVisual_FontNumResults	| how many fonts to return
**
**	tag name				| default¹
**	------------------------+----------------------------
**	 TVisual_FontName		| FNTQUERY_UNDEFINED
**   TVisual_FontPxSize		| FNTQUERY_UNDEFINED
**	 TVisual_FontNumResults	| INT_MAX
**
** ¹ the defaults are used when the tag is missing
**
** RETURN:
** - a pointer to a FontQueryHandle, which is basically a list of
**   taglists, referring to the fonts matched
** - use rfb_hostgetnextfont() to traverse the list
** - use TDestroy to free all memory associated with a FontQueryHandle
**
** EXAMPLES:
** - to match all available fonts, use an empty taglist
** - to match more than one specific font, use a coma separated list
**   for TVisual_FontName, e.g. "helvetica,utopia,fixed", note that
**   spaces are not filtered
**
** NOTES:
** - this function won't open any fonts, to do so use rfb_hostopenfont()
*/

LOCAL TAPTR rfb_hostqueryfonts(RFBDISPLAY *mod, TTAGITEM *tags)
{
	TSTRPTR fname = TNULL;
	struct fnt_attr fattr;
	struct TNode *node, *next;
	struct FontQueryHandle *fqh = TNULL;

	/* init fontname list */
	TInitList(&fattr.fnlist);

	/* fetch and parse fname */
	fname = (TSTRPTR) TGetTag(tags, TVisual_FontName, (TTAG) FNT_WILDCARD);
	if (fname)
		fnt_getfnnodes(mod, &fattr.fnlist, fname);

	/* fetch user specified attributes */
	fattr.fpxsize = (TINT) TGetTag(tags, TVisual_FontPxSize,
		(TTAG) FNT_DEFPXSIZE);
	fattr.fnum = (TINT) TGetTag(tags, TVisual_FontNumResults, (TTAG) INT_MAX);
	/* not yet
	fattr.fitalic = (TBOOL) TGetTag(tags, TVisual_FontItalic, (TTAG) FNTQUERY_UNDEFINED);
	fattr.fbold = (TBOOL) TGetTag(tags, TVisual_FontBold, (TTAG) FNTQUERY_UNDEFINED);
	*/

	/* init result list */
	fqh = TExecAlloc0(mod->rfb_ExecBase, mod->rfb_MemMgr,
		sizeof(struct FontQueryHandle));
	if (fqh)
	{
		fqh->handle.thn_Owner = mod;
		/* connect destructor */
		TInitHook(&fqh->handle.thn_Hook, fqhdestroy, fqh);
		TInitList(&fqh->reslist);
		/* init list iterator */
		fqh->nptr = &fqh->reslist.tlh_Head;

		hostqueryfonts(mod, fqh, &fattr);
		#if 0
		TDB(10,(fnt_dumplist(&fqh->reslist)));
		TDBPRINTF(10, ("***********************************************\n"));
		#endif
	}
	else
		TDBPRINTF(20, ("out of memory :(\n"));

	/* free memory of fnt_nodes */
	for (node = fattr.fnlist.tlh_Head; (next = node->tln_Succ); node = next)
	{
		struct fnt_node *fnn = (struct fnt_node *)node;
		TExecFree(mod->rfb_ExecBase, fnn->fname);
		TRemove(&fnn->node);
		TExecFree(mod->rfb_ExecBase, fnn);
	}

	return fqh;
}

static void hostqueryfonts(RFBDISPLAY *mod, struct FontQueryHandle *fqh,
	struct fnt_attr *fattr)
{
	TINT i, nfont, fcount = 0;
	struct TNode *node, *next;
	struct dirent **dirlist;
	TUINT matchflg = 0;
	const char *fontdir = getfontdir();

	/* scan default font directory */
	nfont = scandir(fontdir, &dirlist, 0, alphasort);
	if (nfont < 0)
	{
		perror("scandir");
		return;
	}

	if (nfont > 0)
	{
		/* found fonts in default font directory */
		for (node = fattr->fnlist.tlh_Head; (next = node->tln_Succ);
			node = next)
		{
			struct fnt_node *fnn = (struct fnt_node *)node;

			/* build matchflag, font pxsize attribute is ignored,
			   because it's not relevant when matching ttf fonts */

			matchflg = FNT_MATCH_NAME;

			/* not yet
			if (fattr->fitalic != FNTQUERY_UNDEFINED)
				matchflg |= FNT_MATCH_SLANT;
			if (fattr->fbold != FNTQUERY_UNDEFINED)
				matchflg |= FNT_MATCH_WEIGHT;
			*/

			for (i = 0; i < nfont; i++)
			{
				if (fnt_matchfont(mod, dirlist[i]->d_name, fnn->fname,
					fattr, matchflg) == matchflg)
				{
					struct FontQueryNode *fqnode;

					/* create fqnode and fill in attributes */
					fqnode = fnt_getfqnode(mod, dirlist[i]->d_name,
						fattr->fpxsize);
					if (!fqnode)
						break;

					/* compare fqnode with nodes in result list */
					if (fnt_checkfqnode(&fqh->reslist, fqnode) == 0)
					{
						if (fcount < fattr->fnum)
						{
							/* fqnode is unique, add to result list */
							TAddTail(&fqh->reslist, &fqnode->node);
							fcount++;
						}
						else
						{
							/* max count of desired results reached */
							TExecFree(mod->rfb_ExecBase,
								(TSTRPTR)fqnode->tags[0].tti_Value);
							TExecFree(mod->rfb_ExecBase, fqnode);
							break;
						}
					}
					else
					{
						/* fqnode is not unique, destroy it */
						TDBPRINTF(10,("X node is not unique\n"));
						TExecFree(mod->rfb_ExecBase,
							(TSTRPTR)fqnode->tags[0].tti_Value);
						TExecFree(mod->rfb_ExecBase, fqnode);
					}
				}
			}

			if (fcount == fattr->fnum)
				break;

		} /* end of fnlist iteration */

	} /* endif fonts found */
	else
		TDBPRINTF(10, ("X no fonts found in '%s'\n", fontdir));

	while (nfont--)
		free(dirlist[nfont]);
	free(dirlist);
}

/*****************************************************************************/
/* CALL:
**  rfb_hostsetfont(visual, fontpointer)
**
** USE:
**  makes the font referred to by fontpointer the current active font
**  for the visual
**
** INPUT:
**  a pointer to a font returned by rfb_hostopenfont()
**
** NOTES:
** - if a font is active it can't be closed
*/

LOCAL void rfb_hostsetfont(RFBDISPLAY *mod, RFBWINDOW *v, TAPTR font)
{
	if (font)
		v->curfont = font;
	else
		TDBPRINTF(20, ("invalid font specified\n"));
}

/*****************************************************************************/
/* CALL:
**  rfb_hostgetnextfont(visualbase, fontqueryhandle)
**
** USE:
**  iterates a list of taglists, returning the next taglist
**  pointer or TNULL
**
** INPUT:
**  a fontqueryhandle obtained by calling rfb_hostqueryfonts()
**
** RETURN:
**  a pointer to a taglist, representing a font or TNULL
**
** NOTES:
**  - the taglist returned by this function can be directly fed to
**	  rfb_hostopenfont()
**  - if the end of the list is reached, TNULL is returned and the
**    iterator is reset to the head of the list
*/

LOCAL TTAGITEM *rfb_hostgetnextfont(RFBDISPLAY *mod, TAPTR fqhandle)
{
	struct FontQueryHandle *fqh = fqhandle;
	struct TNode *next = *fqh->nptr;

	if (next->tln_Succ == TNULL)
	{
		fqh->nptr = &fqh->reslist.tlh_Head;
		return TNULL;
	}

	fqh->nptr = (struct TNode **)next;
	return ((struct FontQueryNode *)next)->tags;
}

/*****************************************************************************/
/* CALL:
**  rfb_hostclosefont(visualbase, fontpointer)
**
** USE:
**  attempts to free all memory associated with the font referred to
**  by fontpointer
**
** INPUT:
**  a pointer to a font returned by rfb_hostopenfont()
**
** NOTES:
**  - the default font is only freed, if there are no more references
**	  to it left
**  - the attempt to free any other font which is currently in use,
**	  will be ignored
*/

LOCAL void rfb_hostclosefont(RFBDISPLAY *mod, TAPTR font)
{
	struct FontNode *fn = (struct FontNode *) font;

	/* free fbfont */
	if (fn->face)
	{
		FT_Done_Face(fn->face);
		fn->face = TNULL;
	}

	/* remove font from openfonts list */
	TRemove(&fn->handle.thn_Node);

	/* free fontnode itself */
	rfb_freefontnode(mod, fn);
}

/*****************************************************************************/
/* CALL:
**  rfb_hosttextsize(visualbase, fontpointer, textstring)
**
** USE:
**  to obtain the width of a given string when the font referred to
**  by fontpointer is used to render the text
**
** INPUT:
**  - a pointer to a font returned by rfb_hostopenfont()
**  - the textstring to measure
**
** RETURN:
**  - the width of the textstring in pixel
*/

LOCAL TINT rfb_hosttextsize(RFBDISPLAY *mod, TAPTR font, TSTRPTR text,
	TINT len)
{
	struct FontNode *myface = font;
	FTC_ImageTypeRec imgtype;
	struct utf8reader rd;
	int c;
	TINT w = 0;
	
	imgtype.face_id = myface;
	imgtype.width = myface->pxsize;
	imgtype.height = myface->pxsize;
	imgtype.flags = FT_LOAD_DEFAULT | FT_LOAD_RENDER;
	
	initutf8reader(&rd, (const unsigned char *) text, -1);
	
	int i = 0;
	while (i++ < len && (c = readutf8(&rd)) > 0)
	{
		FTC_SBit sbit;
		FT_UInt gindex = 
			FTC_CMapCache_Lookup(mod->rfb_FTCCMapCache, myface, -1, c);
		if (FTC_SBitCache_Lookup(mod->rfb_FTCSBitCache, &imgtype, gindex, 
			&sbit, NULL) == 0)
			w += sbit->xadvance;
	}
	return w;
}

/*****************************************************************************/
/* CALL:
**  rfb_hostdrawtext(visualbase, text, textlen, text pos x, text pos y,
**		textpen)
**
** USE:
**  draw text using the current active font
**
** INPUT:
**  - an utf8 string and its length
**  - x and y position of text
**  - a pen to color the text
**
** NOTES:
**  - the text is clipped against v->rfbw_ClipRect[4]
*/

LOCAL TVOID rfb_hostdrawtext(RFBDISPLAY *mod, RFBWINDOW *v, TSTRPTR text,
	TINT len, TINT posx, TINT posy, TVPEN fgpen)
{
	if (!text)
		return;
	struct FontNode *myface = v->curfont;
	if (!myface) return;

	struct Region *R = rfb_getlayermask(mod, v->rfbw_ClipRect, v, 0, 0);
	if (R == TNULL)
		return;
	
	struct RFBPen *textpen = (struct RFBPen *) fgpen;
	FTC_ImageTypeRec imgtype;
	struct utf8reader rd;
	
	TINT asc = myface->ascent;
	TUINT tr = (textpen->rgb >> 16) & 0xff;
	TUINT tg = (textpen->rgb >> 8) & 0xff;
	TUINT tb = textpen->rgb & 0xff;
	int i = 0;
	int c;
	
	imgtype.face_id = myface;
	imgtype.width = myface->pxsize;
	imgtype.height = myface->pxsize;
	imgtype.flags = FT_LOAD_DEFAULT | FT_LOAD_RENDER;
	
	initutf8reader(&rd, (const unsigned char *) text, -1);
	
	while (i++ < len && (c = readutf8(&rd)) > 0)
	{
		FTC_SBit sbit;
		FT_UInt gindex = 
			FTC_CMapCache_Lookup(mod->rfb_FTCCMapCache, myface, -1, c);
		if (FTC_SBitCache_Lookup(mod->rfb_FTCSBitCache, &imgtype, gindex,
			&sbit, NULL))
			continue;
		
		struct { int x, y; } pen;
		
		pen.x = posx + sbit->left;
		pen.y = posy + asc - sbit->top;
		posx += sbit->xadvance;
		
		struct TNode *next, *node = R->rg_Rects.rl_List.tlh_Head;
		for (; (next = node->tln_Succ); node = next)
		{
			struct RectNode *rn = (struct RectNode *) node;
			TINT *r = rn->rn_Rect;
			rfb_markdirty(mod, r);

			int x, y;
			int cx = 0, cy = 0;
			int cw = sbit->width;
			int ch = sbit->height;
			
			/* clipping tests */
			if (r[0] > pen.x)
				cx = r[0] - pen.x;

			if (r[1] > pen.y)
				cy = r[1] - pen.y;

			if (r[2] < pen.x + sbit->width)
				cw -= (pen.x + sbit->width) - r[2] - 1;

			if (r[3] < pen.y + sbit->height)
				ch -= (pen.y + sbit->height) - r[3] - 1;
					
			for (y = cy; y < ch; y++)
			{
				TINT yy = y + pen.y;
				RFBPixel *buf = v->rfbw_BufPtr + yy * v->rfbw_PixelPerLine;
				TUINT8 *sbuf = sbit->buffer + y * sbit->width;
				TINT px = pen.x;
				for (x = cx; x < cw; x++)
				{
					TINT xx = x + px;
					TUINT8 a = sbuf[x];
					TUINT pix = buf[xx];
					TUINT dr = GetRFBPixelRed(pix);
					TUINT dg = GetRFBPixelGreen(pix);
					TUINT db = GetRFBPixelBlue(pix);
					dr += ((tr - dr) * a) >> 8;
					dg += ((tg - dg) * a) >> 8;
					db += ((tb - db) * a) >> 8;
					buf[xx] = RFBPixelFromRGB(dr, dg, db);
				}
			}
		}
	}
	
	rfb_region_destroy(&mod->rfb_RectPool, R);
}

/*****************************************************************************/
/* CALL:
**	rfb_getfattrs(visualbase, fontpointer, taglist);
**
** USE:
**  fills the taglist with the requested properties of the
**  font referred to by fontpointer
**
** INPUT:
**  - a pointer to a font returned by rfb_hostopenfont()
**	- the following tags can be used
**
**  tag name				| description
**	------------------------+---------------------------
**  TVisual_FontPxSize		| font size in pixel
** 	TVisual_FontAscent		| the font ascent in pixel
**	TVisual_FontDescent		| the font descent in pixel
**  TVisual_FontHeight		| height in pixel
**	TVisual_FontUlPosition	| position of an underline
**	TVisual_FontUlThickness	| thickness of the underline
**
** RETURN:
**  - the number of processed properties
**
** NOTES:
**  - TVisual_FontUlPosition defaults to fontdescent / 2
**	  and TVisual_FontUlThickness defaults to 1
*/

LOCAL THOOKENTRY TTAG rfb_hostgetfattrfunc(struct THook *hook, TAPTR obj,
	TTAG msg)
{
	struct rfb_attrdata *data = hook->thk_Data;
	TTAGITEM *item = obj;
	struct FontNode *fn = (struct FontNode *) data->font;

	switch (item->tti_Tag)
	{
		default:
			return TTRUE;

		case TVisual_FontPxSize:
			*((TINT *) item->tti_Value) = fn->pxsize;
			break;

		/* not yet
		case TVisual_FontItalic:
			*((TINT *) item->tti_Value) = (fn->attr & FNT_ITALIC) ?
				TTRUE : TFALSE;
			break;

		case TVisual_FontBold:
			*((TINT *) item->tti_Value) = (fn->attr & FNT_BOLD) ?
				TTRUE : TFALSE;
			break;
		*/
		case TVisual_FontAscent:
			*((TINT *) item->tti_Value) = fn->ascent;
			break;

		case TVisual_FontDescent:
			*((TINT *) item->tti_Value) = fn->descent;
			break;

		case TVisual_FontHeight:
			*((TINT *) item->tti_Value) = fn->height;
			break;

		case TVisual_FontUlPosition:
			*((TINT *) item->tti_Value) = -fn->descent / 2;
			break;
		case TVisual_FontUlThickness:
			*((TINT *) item->tti_Value) = TMAX(1, fn->height / 32);
			break;

		/* ... */
	}
	data->num++;
	return TTRUE;
}
