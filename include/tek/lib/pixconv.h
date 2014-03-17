#ifndef _TEK_LIB_PIXCONV_H
#define _TEK_LIB_PIXCONV_H

/*
**	pixconv.h - Pixel array conversion
**	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

#include <tek/mod/visual.h>

struct PixArray
{
	TUINT8 *buf;
	TUINT fmt;
	TINT width;
};

TLIBAPI TINT pixconv_convert(struct PixArray *src, struct PixArray *dst,
	TINT x0, TINT y0, TINT x1, TINT y1, TINT sx, TINT sy, TBOOL alpha, 
	TBOOL swap_byteorder);

#endif /* _TEK_LIB_PIXCONV_H */
