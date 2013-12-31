
/*
**	display_rfb_draw.c - Raw framebuffer primitive drawing
**	Written by Franciska Schulze <fschulze at schulze-mueller.de>
**	and Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

#include <string.h>
#include "display_rfb_mod.h"

#define	MAX_VERT	6
#define	NUM_VERT	3

#define	OC_TOP		0x1
#define	OC_BOTTOM	0x2
#define	OC_RIGHT	0x4
#define	OC_LEFT		0x8

struct Coord
{
	TINT x, y;
};

struct Slope
{
	TINT inta;		/* integer part */
	TINT z;			/* numerator */
	TINT n;			/* denumerator */
	TINT cz;		/* current numerator */
	struct Coord S;	/* start coordinate */
};

/*****************************************************************************/

TINLINE static void CopyLine(RFBWINDOW *v, TUINT8 *buf, TINT totw, TINT xs,
	TINT ys, TINT xd, TINT yd, TINT numb)
{
	memcpy(&((RFBPixel *)v->rfbw_BufPtr)[(yd * v->rfbw_PixelPerLine + xd)],
		   &((RFBPixel *)buf)[ys*totw+xs], numb);
}

/*****************************************************************************/

TINLINE static void CopyLineOver(RFBWINDOW *v, TINT xs, TINT ys, TINT xd,
	TINT yd, TINT numb)
{
	memmove(&((RFBPixel *)v->rfbw_BufPtr)[yd * v->rfbw_PixelPerLine + xd],
		&((RFBPixel *)v->rfbw_BufPtr)[ys * v->rfbw_PixelPerLine + xs], numb);
}

/*****************************************************************************/
/* calculate intersection with clipping edge */

static void intersect(struct Coord *res, struct Coord v1, struct Coord v2,
	struct Coord ce[2], TUINT which)
{
	TINT a, b;
	TINT x0 = v1.x, y0 = v1.y;
	TINT x1 = v2.x, y1 = v2.y;
	TINT xmin = ce[0].x, ymin = ce[0].y;
	TINT xmax = ce[1].x, ymax = ce[1].y;

	if (which & OC_TOP)
	{
		b = y1 - y0;
		a = (x1 - x0) * (ymax - y0);

		if ((a < 0) != (b < 0))
			res->x = x0 + (a - b/2) / b;
		else
			res->x = x0 + (a + b/2) / b;

		res->y = ymax;
	}
	else if (which & OC_BOTTOM)
	{
		b = y1 - y0;
		a = (x1 - x0) * (ymin - y0);

		if ((a < 0) != (b < 0))
			res->x = x0 + (a - b/2) / b;
		else
			res->x = x0 + (a + b/2) / b;

		res->y = ymin;
	}
	else if (which & OC_RIGHT)
	{
		b = x1 - x0;
		a = (y1 - y0) * (xmax - x0);

		if ((a < 0) != (b < 0))
			res->y = y0 + (a - b/2) / b;
		else
			res->y = y0 + (a + b/2) / b;

		res->x = xmax;
	}
	else
	{
		b = x1 - x0;
		a = (y1 - y0) * (xmin - x0);

		if ((a < 0) != (b < 0))
			res->y = y0 + (a - b/2) / b;
		else
			res->y = y0 + (a + b/2) / b;

		res->x = xmin;
	}
}

/*****************************************************************************/

static TBOOL inside(struct Coord v, struct Coord ce[2], TUINT which)
{
	switch (which)
	{
		case OC_BOTTOM:
			if (v.y >= ce[0].y) return TTRUE;
			break;
		case OC_TOP:
			if (v.y <= ce[1].y) return TTRUE;
			break;
		case OC_LEFT:
			if (v.x >= ce[0].x) return TTRUE;
			break;
		case OC_RIGHT:
			if (v.x <= ce[1].x) return TTRUE;
			break;
		default:
			break;
	}
	return TFALSE;
}

static void output(struct Coord outva[MAX_VERT], struct Coord v, TINT *outlen)
{
	if (*outlen < MAX_VERT)
	{
		/* filter out double entries */
		if (*outlen == 0 || (outva[(*outlen)-1].x != v.x
			|| outva[(*outlen)-1].y != v.y))
		{
			outva[*outlen].x = v.x;
			outva[*outlen].y = v.y;
			(*outlen)++;
		}
	}
}

/* sutherland hodgman polygon clipping */
static void shpolyclip(struct Coord outva[MAX_VERT], TINT *outlen, TINT inlen,
	struct Coord inva[NUM_VERT], struct Coord clipedge[2], TUINT which)
{
	struct Coord s, p, i;
	TINT j;

	*outlen = 0;
	s.x = inva[inlen-1].x;
	s.y = inva[inlen-1].y;

	for (j = 0; j < inlen; j++)
	{
		p.x = inva[j].x;
		p.y = inva[j].y;

		if (inside(p, clipedge, which))
		{
			/* cases 1 and 4 */
			if (inside(s, clipedge, which))
			{
				/* case 1 */
				output(outva, p, outlen);
			}
			else
			{
				/* case 4 */
				intersect(&i, s, p, clipedge, which);
				output(outva, i, outlen);
				output(outva, p, outlen);
			}
		}
		else
		{
			/* cases 2 and 3 */
			if (inside(s, clipedge, which))
			{
				/* case 2 */
				intersect(&i, s, p, clipedge, which);
				output(outva, i, outlen);
			} /* else do nothing (case 3) */
		}

		/* advance to next pair of vertices */
		s.x = p.x;
		s.y = p.y;
	}
}

static TBOOL clippoly(struct Coord res[MAX_VERT], TINT *outlen, TINT x0,
	TINT y0, TINT x1, TINT y1, TINT x2, TINT y2, TINT xmin, TINT ymin,
	TINT xmax, TINT ymax)
{
	struct Coord outva[MAX_VERT];
	struct Coord inva[NUM_VERT];
	struct Coord clipedge[2];
	TINT inlen = NUM_VERT;

	inva[0].x = x0; inva[0].y = y0;
	inva[1].x = x1; inva[1].y = y1;
	inva[2].x = x2; inva[2].y = y2;

	clipedge[0].x = xmin; clipedge[0].y = ymin;
	clipedge[1].x = xmax; clipedge[1].y = ymax;

	/* process right clip boundary */
	shpolyclip(outva, outlen, inlen, inva, clipedge, OC_RIGHT);
	if (!*outlen) return TFALSE;

	/* process bottom clip boundary */
	inlen = *outlen;
	shpolyclip(res, outlen, inlen, outva, clipedge, OC_BOTTOM);
	if (!*outlen) return TFALSE;

	/* process left clip boundary */
	inlen = *outlen;
	shpolyclip(outva, outlen, inlen, res, clipedge, OC_LEFT);
	if (!*outlen) return TFALSE;

	/* process top clip boundary */
	inlen = *outlen;
	shpolyclip(res, outlen, inlen, outva, clipedge, OC_TOP);
	if (!*outlen) return TFALSE;

	return TTRUE;
}

/*****************************************************************************/

static TUINT getoutcode(TINT x, TINT y, TINT xmin, TINT ymin, TINT xmax,
	TINT ymax)
{
	TUINT outcode = 0;

	if (y > ymax)
		outcode |= OC_TOP;
	else if (y < ymin)
		outcode |= OC_BOTTOM;
	if (x > xmax)
		outcode |= OC_RIGHT;
	else if (x < xmin)
		outcode |= OC_LEFT;

	return outcode;
}

/*****************************************************************************/

static TBOOL cliprect(struct Coord res[2], TINT x0, TINT y0, TINT x1, TINT y1,
	TINT xmin, TINT ymin, TINT xmax, TINT ymax)
{
	TBOOL accept = TFALSE;
	TBOOL done = TFALSE;
	TUINT outc0, outc1, outc;

	outc0 = getoutcode(x0, y0, xmin, ymin, xmax, ymax);
	outc1 = getoutcode(x1, y1, xmin, ymin, xmax, ymax);

	do
	{
		if (!(outc0 | outc1))
		{
			/* trivial accept and exit */
			accept = TTRUE;
			done = TTRUE;
		}
		else if (outc0 & outc1)
		{
			/* trivial reject and exit */
			done = TTRUE;
		}
		else
		{
			/* move vertices to clipping edge */
			TINT x = 0, y = 0;

			outc = outc0 ? outc0 : outc1;
			if (outc & OC_TOP)
				y = ymax;
			else if (outc & OC_BOTTOM)
				y = ymin;
			else if (outc & OC_RIGHT)
				x = xmax;
			else
				x = xmin;

			/* get ready for next pass */
			if (outc == outc0)
			{
				if (outc & (OC_TOP | OC_BOTTOM))
					y0 = y;
				else
					x0 = x;

				outc0 = getoutcode(x0, y0, xmin, ymin, xmax, ymax);
			}
			else
			{
				if (outc & (OC_TOP | OC_BOTTOM))
					y1 = y;
				else
					x1 = x;

				outc1 = getoutcode(x1, y1, xmin, ymin, xmax, ymax);
			}

		} /* endif subdivide */

	} while (done == TFALSE);

	if (accept)
	{
		res[0].x = x0; res[0].y = y0;
		res[1].x = x1; res[1].y = y1;
	}

	return accept;
}

/*****************************************************************************/

static TBOOL clipline(struct Coord res[2], TINT x0, TINT y0, TINT x1, TINT y1,
	TINT xmin, TINT ymin, TINT xmax, TINT ymax)
{
	TBOOL accept = TFALSE;
	TBOOL done = TFALSE;
	TUINT outc0, outc1, outc;

	outc0 = getoutcode(x0, y0, xmin, ymin, xmax, ymax);
	outc1 = getoutcode(x1, y1, xmin, ymin, xmax, ymax);

	do
	{
		if (!(outc0 | outc1))
		{
			/* trivial accept and exit */
			accept = TTRUE;
			done = TTRUE;
		}
		else if (outc0 & outc1)
		{
			/* trivial reject and exit */
			done = TTRUE;
		}
		else
		{
			/* calculate intersection with clipping edge */
			struct Coord r;
			struct Coord v1 = {x0, y0};
			struct Coord v2 = {x1, y1};
			struct Coord ce[2] = {{xmin, ymin}, {xmax, ymax}};

			outc = outc0 ? outc0 : outc1;
			intersect(&r, v1, v2, ce, outc);

			/* get ready for next pass */
			if (outc == outc0)
			{
				x0 = r.x; y0 = r.y;
				outc0 = getoutcode(x0, y0, xmin, ymin, xmax, ymax);
			}
			else
			{
				x1 = r.x; y1 = r.y;
				outc1 = getoutcode(x1, y1, xmin, ymin, xmax, ymax);
			}

		} /* endif subdivide */

	} while (done == TFALSE);

	if (accept)
	{
		res[0].x = x0; res[0].y = y0;
		res[1].x = x1; res[1].y = y1;
	}

	return accept;
}

/*****************************************************************************/

LOCAL void fbp_drawpoint(RFBDISPLAY *mod, RFBWINDOW *v, TINT x, TINT y, 
	struct RFBPen *pen)
{
	if (rfb_ispointobscured(mod, x, y, v))
		return;
	TINT r[4];
	r[0] = x;
	r[1] = y;
	r[2] = x;
	r[3] = y;
	rfb_markdirty(mod, r);
	WritePixel(v, x, y, RGB2RFBPixel(pen->rgb));
}

/*****************************************************************************/

LOCAL void fbp_drawfrect(RFBDISPLAY *mod, RFBWINDOW *v, TINT rect[4], 
	struct RFBPen *pen)
{
	struct Coord res[2];
	TINT xmin = rect[0];
	TINT ymin = rect[1];
	TINT xmax = rect[0] + rect[2] - 1;
	TINT ymax = rect[1] + rect[3] - 1;
	
	if (!cliprect(res, xmin, ymin, xmax, ymax,
		v->rfbw_ClipRect[0], v->rfbw_ClipRect[1], v->rfbw_ClipRect[2], 
		v->rfbw_ClipRect[3]))
		return;
	
	TINT r[4];
	r[0] = res[0].x;
	r[1] = res[0].y;
	r[2] = res[1].x;
	r[3] = res[1].y;
	struct Region *R = rfb_getlayermask(mod, r, v, 0, 0);
	if (R == TNULL)
		return;

	TINT x, y;
	TUINT ppl = v->rfbw_PixelPerLine;
	
	struct TNode *next, *node = R->rg_Rects.rl_List.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		struct RectNode *r = (struct RectNode *) node;
		
		rfb_markdirty(mod, r->rn_Rect);
		
		xmin = r->rn_Rect[0];
		ymin = r->rn_Rect[1];
		xmax = r->rn_Rect[2];
		ymax = r->rn_Rect[3];
		
		RFBPixel *buf = v->rfbw_BufPtr + ymin * ppl;

		RFBPixel p = RGB2RFBPixel(pen->rgb);
		for (y = ymin; y <= ymax; y++, buf += ppl)
			for (x = xmin; x <= xmax; x++)
				buf[x] = p;
	}
		
	rfb_region_destroy(&mod->rfb_RectPool, R);
}

/*****************************************************************************/

LOCAL void fbp_drawrect(RFBDISPLAY *mod, RFBWINDOW *v, TINT rect[4], 
	struct RFBPen *pen)
{
	TINT x, y;
	
	struct Coord res[2];
	TINT xmin = rect[0];
	TINT ymin = rect[1];
	TINT xmax = rect[0] + rect[2] - 1;
	TINT ymax = rect[1] + rect[3] - 1;

	if (!cliprect(res, xmin, ymin, xmax, ymax,
		v->rfbw_ClipRect[0], v->rfbw_ClipRect[1], v->rfbw_ClipRect[2],
		v->rfbw_ClipRect[3]))
		return;
	
	/* get region of windows obscuring our clip */
	struct RectNode rectnode;
	rectnode.rn_Rect[0] = res[0].x; 
	rectnode.rn_Rect[1] = res[0].y; 
	rectnode.rn_Rect[2] = res[1].x; 
	rectnode.rn_Rect[3] = res[1].y;
	struct Region *R = rfb_getlayermask(mod, rectnode.rn_Rect, v, 0, 0);
	if (R == TNULL)
		return;

	RFBPixel p = RGB2RFBPixel(pen->rgb);
	TUINT ppl = v->rfbw_PixelPerLine;
	
	struct TNode *next, *node = R->rg_Rects.rl_List.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		struct RectNode *r = (struct RectNode *) node;
		TINT x0 = r->rn_Rect[0];
		TINT y0 = r->rn_Rect[1];
		TINT x1 = r->rn_Rect[2];
		TINT y1 = r->rn_Rect[3];
		
		rfb_markdirty(mod, r->rn_Rect);
	
		if (y0 == ymin)
		{
			RFBPixel *buf = v->rfbw_BufPtr + ymin * ppl;
			for (x = x0; x <= x1; x++)
				buf[x] = p;
		}

		if (y1 == ymax)
		{
			RFBPixel *buf = v->rfbw_BufPtr + ymax * ppl;
			for (x = x0; x <= x1; x++)
				buf[x] = p;
		}

		if (x0 == xmin)
		{
			RFBPixel *buf = v->rfbw_BufPtr + y0 * ppl + xmin;
			for (y = y0; y <= y1; y++, buf += ppl)
				*buf = p;
		}

		if (x1 == xmax)
		{
			RFBPixel *buf = v->rfbw_BufPtr + y0 * ppl + xmax;
			for (y = y0; y <= y1; y++, buf += ppl)
				*buf = p;
		}
	}
	
	rfb_region_destroy(&mod->rfb_RectPool, R);
}

/*****************************************************************************/

LOCAL void fbp_drawline(RFBDISPLAY *mod, RFBWINDOW *v, TINT rect[4], 
	struct RFBPen *pen)
{
	struct Coord res[2];
	TINT dx, dy, d, x, y;
	TINT incE, incNE, incSE, incN, incS;
	
	TINT l0, l1, l2, l3;
	
	if (rect[2] < rect[0])
	{
		l0 = rect[2];
		l1 = rect[3];
		l2 = rect[0];
		l3 = rect[1];
	}
	else
	{
		l0 = rect[0];
		l1 = rect[1];
		l2 = rect[2];
		l3 = rect[3];
	}

	struct Region *R = rfb_getlayermask(mod, v->rfbw_ClipRect, v, 0, 0);
	if (R == TNULL)
		return;
	
	RFBPixel p = RGB2RFBPixel(pen->rgb);
	
	struct TNode *next, *node = R->rg_Rects.rl_List.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		TINT *r = rn->rn_Rect;
		if (!clipline(res, 
			l0, l1, l2, l3,
			r[0], r[1], r[2], r[3]))
			continue;
		
		TINT x0 = res[0].x;
		TINT y0 = res[0].y;
		TINT x1 = res[1].x;
		TINT y1 = res[1].y;

		rfb_markdirty(mod, (TINT *) res);
		
		dx = x1 - x0;
		dy = y1 - y0;

		x = x0;
		y = y0;

		WritePixel(v, x, y, p);

		if ((y0 <= y1) && (dy <= dx))
		{
			/* m <= 1 */
			d = 2 * dy - dx;
			incE = 2 * dy;
			incNE = 2 * (dy - dx);

			while (x < x1)
			{
				if (d <= 0)
				{
					d = d + incE;
					x++;
				}
				else
				{
					d = d + incNE;
					x++;
					y++;
				}

				WritePixel(v, x, y, p);
			}
		}

		if ((y0 <= y1) && (dy > dx))
		{
			/* m > 1 */
			d = 2 * dx - dy;
			incN = 2 * dx;
			incNE = 2 * (dx - dy);

			while (y < y1)
			{
				if (d <= 0)
				{
					d = d + incN;
					y++;
				}
				else
				{
					d = d + incNE;
					x++;
					y++;
				}

				WritePixel(v, x, y, p);
			}
		}

		if ((y0 > y1) && (-dy <= dx))
		{
			dy = -dy;
			d = 2 * dy - dx;
			incE = 2 * dy;
			incSE = 2 * (dy - dx);

			while (x < x1)
			{
				if (d <= 0)
				{
					d = d + incE;
					x++;
				}
				else
				{
					d = d + incSE;
					x++;
					y--;
				}

				WritePixel(v, x, y, p);
			}
		}

		if ((y0 > y1) && (-dy > dx))
		{
			dy = -dy;
			d = 2 * dx - dy;
			incS = 2 * dx;
			incSE = 2 * (dx - dy);

			while (y > y1)
			{
				if (d <= 0)
				{
					d = d + incS;
					y--;
				}
				else
				{
					d = d + incSE;
					x++;
					y--;
				}

				WritePixel(v, x, y, p);
			}
		}
		
	}
	
	rfb_region_destroy(&mod->rfb_RectPool, R);
	
}

/*****************************************************************************/

static void initslope(struct Slope *m, struct Coord *c1, struct Coord *c2)
{
	TINT dx = c2->x - c1->x;
	TINT dy = c2->y - c1->y;

	memset(m, 0x0, sizeof(struct Slope));
	m->S.x = c1->x;	m->S.y = c1->y;

	if (dx && dy)
	{
		if (abs(dx) >= dy)
		{
			/* calculate integer part */
			m->inta = dx/dy;
			m->z = dx - (m->inta * dy);
			if (m->z) m->n = dy;
		}
		else
		{
			/* dx < dy */
			m->z = dx;
			m->n = dy;
		}
	}
}

static void hline(RFBWINDOW *v, struct Slope *ms, struct Slope *me, TINT y,
	RFBPixel p)
{
	TINT xs, xe, rs = 0, re = 0;
	TINT x;

	/* check, if we need to round up coordinates */
	if (ms->n && abs(ms->cz)*2 >= ms->n)
		rs = 1;
	if (me->n && abs(me->cz)*2 >= me->n)
		re = 1;

	/* sort that xs < xe */
	if (ms->S.x+rs > me->S.x+re)
	{
		xs = me->S.x + re;
		xe = ms->S.x + rs;
	}
	else
	{
		xs = ms->S.x + rs;
		xe = me->S.x + re;
	}
	
	for (x = xs; x <= xe; x++)
		WritePixel(v, x, y, p);
}

static void rendertriangle(RFBWINDOW *v, struct Coord v1, struct Coord v2,
	struct Coord v3, RFBPixel p)
{
	struct Coord A, B, C;
	struct Slope mAB, mAC, mBC;
	TINT y;

	/* sort that A.y <= B.y <= C.y */
	A.x = v1.x;	A.y = v1.y;
	B.x = v2.x;	B.y = v2.y;
	C.x = v3.x;	C.y = v3.y;

	if (A.y > v2.y)
	{
		B.x = A.x;	B.y = A.y;
		A.x = v2.x;	A.y = v2.y;
	}

	if (A.y > v3.y)
	{
		C.x = B.x;	C.y = B.y;
		B.x = A.x;	B.y = A.y;
		A.x = v3.x;	A.y = v3.y;
	}
	else
	{
		if (B.y > v3.y)
		{
			C.x = B.x;	C.y = B.y;
			B.x = v3.x;	B.y = v3.y;
		}
	}

	initslope(&mAB, &A, &B);
	initslope(&mAC, &A, &C);
	initslope(&mBC, &B, &C);

	for (y = A.y; y < B.y; y++, mAC.S.x += mAC.inta, mAB.S.x += mAB.inta)
	{
		hline(v, &mAC, &mAB, y, p);

		if (mAC.n)
		{
			mAC.cz += mAC.z;
			if (mAC.z < 0)
			{
				if (mAC.cz < 0)
				{
					mAC.S.x -= 1;
					mAC.cz += mAC.n;
				}
			}
			else
			{
				if (mAC.cz >= mAC.n)
				{
					mAC.S.x += 1;
					mAC.cz -= mAC.n;
				}
			}
		}

		if (mAB.n)
		{
			mAB.cz += mAB.z;

			if (mAB.z < 0)
			{
				if (mAB.cz < 0)
				{
					mAB.S.x -= 1;
					mAB.cz += mAB.n;
				}
			}
			else
			{
				if (mAB.cz >= mAB.n)
				{
					mAB.S.x += 1;
					mAB.cz -= mAB.n;
				}
			}
		}
	}

	for (; y <= C.y; y++, mAC.S.x += mAC.inta, mBC.S.x += mBC.inta)
	{
		hline(v, &mAC, &mBC, y, p);

		if (mAC.n)
		{
			mAC.cz += mAC.z;

			if (mAC.z < 0)
			{
				if (mAC.cz < 0)
				{
					mAC.S.x -= 1;
					mAC.cz += mAC.n;
				}
			}
			else
			{
				if (mAC.cz >= mAC.n)
				{
					mAC.S.x += 1;
					mAC.cz -= mAC.n;
				}
			}
		}

		if (mBC.n)
		{
			mBC.cz += mBC.z;

			if (mBC.z < 0)
			{
				if (mBC.cz < 0)
				{
					mBC.S.x -= 1;
					mBC.cz += mBC.n;
				}
			}
			else
			{
				if (mBC.cz >= mBC.n)
				{
					mBC.S.x += 1;
					mBC.cz -= mBC.n;
				}
			}
		}
	}
}

/*****************************************************************************/

LOCAL void fbp_drawtriangle(RFBDISPLAY *mod, RFBWINDOW *v, 
	TINT x0, TINT y0, TINT x1, TINT y1,
	TINT x2, TINT y2, struct RFBPen *pen)
{
	struct Coord res[MAX_VERT];
	TINT outlen;
	
	struct Region *R = rfb_getlayermask(mod, v->rfbw_ClipRect, v, 0, 0);
	if (R == TNULL)
		return;
	
	RFBPixel p = RGB2RFBPixel(pen->rgb);
	struct TNode *next, *node = R->rg_Rects.rl_List.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		TINT *r = rn->rn_Rect;
		if (!clippoly(res, &outlen, x0, y0, x1, y1, x2, y2,
			r[0], r[1], r[2], r[3]))
			continue;

		TINT d[4];
		if (outlen == 1)
		{
			d[0] = res[0].x;
			d[1] = res[0].y;
			d[2] = res[0].x;
			d[3] = res[0].y;
			rfb_markdirty(mod, d);
			WritePixel(v, res[0].x, res[0].y, p);
		}
		else if (outlen == 2)
		{
			TINT rect[4] = {res[0].x, res[0].y, res[1].x, res[1].y};
			rfb_markdirty(mod, rect);
			fbp_drawline(mod, v, rect, pen);
		}
		else
		{
			TINT i;
			
			d[0] = TMIN(TMIN(res[0].x, res[1].x), res[2].x);
			d[1] = TMIN(TMIN(res[0].y, res[1].y), res[2].y);
			d[2] = TMAX(TMAX(res[0].x, res[1].x), res[2].x);
			d[3] = TMAX(TMAX(res[0].y, res[1].y), res[2].y);
			rfb_markdirty(mod, d);
			
			rendertriangle(v, res[0], res[1], res[2], p);
			for (i = 2; i < outlen; i++)
			{
				if ((i + 1) < outlen)
					rendertriangle(v, res[0], res[i], res[i + 1], p);
			}
		}
	}
	rfb_region_destroy(&mod->rfb_RectPool, R);
}

/*****************************************************************************/

LOCAL void fbp_drawbuffer(RFBDISPLAY *mod, RFBWINDOW *v, TUINT8 *buf, 
	TINT rect[4], TINT totw, TUINT pixfmt)
{
	struct Coord res[2];
	TINT xmin = rect[0];
	TINT ymin = rect[1];
	TINT xmax = rect[0] + rect[2] - 1;
	TINT ymax = rect[1] + rect[3] - 1;
	TINT yd, xs, ys, numb;

	if (!cliprect(res, xmin, ymin, xmax, ymax,
		v->rfbw_ClipRect[0], v->rfbw_ClipRect[1], v->rfbw_ClipRect[2], 
		v->rfbw_ClipRect[3]))
		return;

	TINT r[4];
	r[0] = res[0].x;
	r[1] = res[0].y;
	r[2] = res[1].x;
	r[3] = res[1].y;
	struct Region *R = rfb_getlayermask(mod, r, v, 0, 0);
	if (R == TNULL)
		return;

	struct TNode *next, *node = R->rg_Rects.rl_List.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		struct RectNode *r = (struct RectNode *) node;
		
		rfb_markdirty(mod, r->rn_Rect);
		
		xmin = r->rn_Rect[0];
		ymin = r->rn_Rect[1];
		xmax = r->rn_Rect[2];
		ymax = r->rn_Rect[3];
		xs = xmin - rect[0]; 
		ys = ymin - rect[1];
		
		switch ((pixfmt << 8) | RFBPIXFMT)	/* src | dst */
		{
			case (TVPIXFMT_RGB16 << 8) | TVPIXFMT_ARGB32:
				for (yd = ymin; yd <= ymax; yd++, ys++)
				{
					TINT xd;
					RFBPixel *dp = v->rfbw_BufPtr + yd * v->rfbw_PixelPerLine;
					xs = xmin - rect[0]; 
					for (xd = xmin; xd <= xmax; xd++, xs++)
					{
						RFBPixelRGB16 pix = 
							((RFBPixelRGB16 *) buf)[ys * totw + xs];
						dp[xd] = ARGB32FromRGB16(pix);
					}
				}
				break;
			case (TVPIXFMT_ARGB32 << 8) | TVPIXFMT_RGB16:
				for (yd = ymin; yd <= ymax; yd++, ys++)
				{
					TINT xd;
					RFBPixel *dp = v->rfbw_BufPtr + yd * v->rfbw_PixelPerLine;
					xs = xmin - rect[0]; 
					for (xd = xmin; xd <= xmax; xd++, xs++)
					{
						RFBPixelARGB32 pix = 
							((RFBPixelARGB32 *) buf)[ys * totw + xs];
						dp[xd] = RGB16FromARGB32(pix);
					}
				}
				break;
			case (TVPIXFMT_RGB16 << 8) | TVPIXFMT_RGB16:
			case (TVPIXFMT_ARGB32 << 8) | TVPIXFMT_ARGB32:
				numb = (xmax - xmin + 1) * sizeof(RFBPixel);
				for (yd = ymin; yd <= ymax; yd++, ys++)
					CopyLine(v, buf, totw, xs, ys, xmin, yd, numb);
				break;
		}
	}
	rfb_region_destroy(&mod->rfb_RectPool, R);
}

/*****************************************************************************/

LOCAL void fbp_copyarea(RFBDISPLAY *mod, RFBWINDOW *v, TINT rect[4],
	TINT dx0, TINT dy0, struct THook *exposehook)
{
	struct Pool *pool = &mod->rfb_RectPool;
	TINT dx = dx0 - rect[0];
	TINT dy = dy0 - rect[1];
	TINT dr[4];
	TINT dx1 = dx0 + rect[2] - 1;
	TINT dy1 = dy0 + rect[3] - 1;
	dr[0] = dx0;
	dr[1] = dy0;
	dr[2] = dx1;
	dr[3] = dy1;
	
	if (!rfb_region_intersect(&dr[0], &dr[1], &dr[2], &dr[3],
		v->rfbw_ClipRect[0], v->rfbw_ClipRect[1], v->rfbw_ClipRect[2], 
		v->rfbw_ClipRect[3]))
		return;
	
	struct Region *R = rfb_getlayermask(mod, dr, v, 0, 0);
	if (R == TNULL)
		return;
	
// 	rfb_region_andrect(pool, R, v->rfbw_ClipRect, 0, 0);
// 	rfb_region_andrect(pool, R, v->rfbw_ClipRect, dx, dy);
	
	if (R->rg_Rects.rl_NumNodes == 0)
		return;
	
	TINT yinc = dy < 0 ? -1 : 1;
	TINT y, i, h;
	
	dy0 = dr[1];
	dy1 = dr[3];
	h = dy1 - dy0 + 1;
	if (yinc > 0)
	{
		TINT t = dy0;
		dy0 = dy1;
		dy1 = t;
	}
	
	if (R->rg_Rects.rl_NumNodes == 1)
	{
		/* optimization for a single rectangle */
	
		struct RectNode *rn = 
			(struct RectNode *) TFIRSTNODE(&R->rg_Rects.rl_List);
		TINT x0 = rn->rn_Rect[0];
		TINT y0 = rn->rn_Rect[1];
		TINT x1 = rn->rn_Rect[2];
		TINT y1 = rn->rn_Rect[3];
		h = y1 - y0 + 1;
		dy0 = y0;
		dy1 = y1;
		if (yinc > 0)
		{
			TINT t = dy0;
			dy0 = dy1;
			dy1 = t;
		}
		
		/* update sub device */
		rfb_copyrect_sub(mod, rn->rn_Rect, dx, dy);
		
#if defined(ENABLE_VNCSERVER)
		if (mod->rfb_VNCTask)
			rfb_vnc_copyrect(mod, v, dx, dy, x0, y0, x1, y1, yinc);
		else
#endif
		{
			/* update own buffer */
			for (i = 0, y = dy0; i < h; ++i, y -= yinc)
				CopyLineOver(v, x0 - dx, y - dy, x0, y, 
					(x1 - x0 + 1) * sizeof(RFBPixel));
		}
	}
	else
	{
		struct TNode *n;
		struct TList r, t;
		TInitList(&r);
		TInitList(&t);
		
		while ((n = TRemHead(&R->rg_Rects.rl_List)))
			TAddTail(&r, n);
			
		for (i = 0, y = dy0; i < h; ++i, y -= yinc)
		{
			struct TNode *rnext, *rnode = r.tlh_Head;
			for (; (rnext = rnode->tln_Succ); rnode = rnext)
			{
				struct RectNode *rn = (struct RectNode *) rnode;
				if (y >= rn->rn_Rect[1] && y <= rn->rn_Rect[3])
				{
					struct TNode *prednode = TNULL;
					struct TNode *tnext, *tnode = t.tlh_Head;
					for (; (tnext = tnode->tln_Succ); tnode = tnext)
					{
						struct RectNode *tn = (struct RectNode *) tnode;
						if (rn->rn_Rect[2] < tn->rn_Rect[0])
							break;
						prednode = tnode;
					}
					TRemove(rnode);
					TInsert(&t, rnode, prednode); /* insert after prednode */
				}
			}
			
			while (!TISLISTEMPTY(&t))
			{
				TINT x0, x1;
				if (dx < 0)
				{
					struct RectNode *E = (struct RectNode *) TRemHead(&t);
					x0 = E->rn_Rect[0];
					x1 = E->rn_Rect[2];
					TAddTail(&r, &E->rn_Node);
					while (!TISLISTEMPTY(&t))
					{
						struct RectNode *N = 
							(struct RectNode *) TFIRSTNODE(&t);
						if (N->rn_Rect[0] == x1 + 1)
						{
							x1 = N->rn_Rect[2];
							TAddTail(&r, TRemHead(&t));
							continue;
						}
						break;
					}
				}
				else
				{
					struct RectNode *E = (struct RectNode *) TRemTail(&t);
					x0 = E->rn_Rect[0];
					x1 = E->rn_Rect[2];
					TAddTail(&r, &E->rn_Node);
					while (!TISLISTEMPTY(&t))
					{
						struct RectNode *N = (struct RectNode *) TLASTNODE(&t);
						if (N->rn_Rect[2] == x0 - 1)
						{
							x0 = N->rn_Rect[0];
							TAddTail(&r, TRemTail(&t));
							continue;
						}
						break;
					}
				}
				CopyLineOver(v, x0 - dx, y - dy, x0, y, 
					(x1 - x0 + 1) * sizeof(RFBPixel));
			}
		}
		
		while ((n = TRemHead(&r)))
		{
			struct RectNode *rn = (struct RectNode *) n;
			/* this would be incorrect, unfortunately: */
			/* rfb_copyrect_sub(mod, rn->rn_Rect, dx, dy); */
			rfb_markdirty(mod, rn->rn_Rect);
			TAddTail(&R->rg_Rects.rl_List, n);
		}
	}

	rfb_region_destroy(pool, R);
	
	if (exposehook)
	{
		/* calculate damage from exposures of areas previously obscured */
		
		R = rfb_getlayers(mod, v, 0, 0);
		struct Region *L = rfb_getlayers(mod, v, dx, dy);
		if (L)
		{
			if (rfb_region_subregion(pool, L, R) && 
				rfb_region_andrect(pool, L, dr, 0, 0))
			{
				TINT wx = v->rfbw_WinRect[0];
				TINT wy = v->rfbw_WinRect[1];
				struct TNode *next, *node = L->rg_Rects.rl_List.tlh_Head;
				for (; (next = node->tln_Succ); node = next)
				{
					struct RectNode *rn = (struct RectNode *) node;
					TINT *r = rn->rn_Rect;
					r[0] -= wx;
					r[1] -= wy;
					r[2] -= wx;
					r[3] -= wy;
					TCallHookPkt(exposehook, v, (TTAG) r);
				}
			}
			rfb_region_destroy(pool, L);
		}
		rfb_region_destroy(pool, R);
	}
}
