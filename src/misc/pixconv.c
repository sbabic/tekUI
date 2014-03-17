#ifndef _TEK_LIB_PIXCONV_C
#define _TEK_LIB_PIXCONV_C

/*
**	pixconv.c - Pixel array conversion
**	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

#include <string.h>
#include <tek/debug.h>
#include <tek/lib/pixconv.h>

TLIBAPI TINT pixconv_convert(struct PixArray *src, struct PixArray *dst,
	TINT x0, TINT y0, TINT x1, TINT y1, TINT sx, TINT sy, TBOOL alpha, 
	TBOOL swap)
{
	TINT w = x1 - x0 + 1;
	TINT h = y1 - y0 + 1;
	TINT x, y;
	TUINT c = (alpha << 17) | (swap << 16) | ((src->fmt & 0xff) << 8) | (dst->fmt & 0xff);
	TDBPRINTF(TDB_DEBUG,("conversion %08x: alpha=%d swap=%d src=%08x dst=%08x\n", 
		c, alpha, swap, src->fmt, dst->fmt));
	switch(c)
	{
		/* 24/32 bit -> 24/32 bit */
		
		case ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		case ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		case ((TVPIXFMT_08B8G8R8 & 0xff) << 8) | (TVPIXFMT_08B8G8R8 & 0xff):
		case ((TVPIXFMT_08B8G8R8 & 0xff) << 8) | (TVPIXFMT_A8B8G8R8 & 0xff):
		case ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_A8B8G8R8 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				memcpy(dp, sp, w * 4);
			break;
		}
		case ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_08B8G8R8 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
					dp[x] = sp[x] & 0x00ffffff;
			break;
		}
		case 0x10000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		case 0x10000 | ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_A8B8G8R8 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					dp[x] = TVPIXFMT_ARGB32_SWAP(p);
				}
			break;
		}
		case 0x10000 | ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case 0x10000 | ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		case 0x10000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case 0x10000 | ((TVPIXFMT_08B8G8R8 & 0xff) << 8) | (TVPIXFMT_08B8G8R8 & 0xff):
		case 0x10000 | ((TVPIXFMT_08B8G8R8 & 0xff) << 8) | (TVPIXFMT_A8B8G8R8 & 0xff):
		case 0x10000 | ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_08B8G8R8 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					dp[x] = TVPIXFMT_0RGB32_SWAP(p);
				}
			break;
		}
		
		case ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_A8B8G8R8 & 0xff):
		case ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					dp[x] = TVPIXFMT_ARGB32_TO_ABGR32(p);
				}
			break;
		}
		case ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_08B8G8R8 & 0xff):
		case ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_08B8G8R8 & 0xff):
		case ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case ((TVPIXFMT_08B8G8R8 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					dp[x] = TVPIXFMT_0RGB32_TO_0BGR32(p);
				}
			break;
		}

		/* 32 bit -> 16 bit */
		
		case ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		case ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					dp[x] = TVPIXFMT_ARGB32_TO_RGB16(p);
				}
			break;
		}
		case 0x10000 | ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		case 0x10000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					TUINT p2 = TVPIXFMT_ARGB32_TO_RGB16(p);
					dp[x] = TVPIXFMT_RGB16_SWAP(p2);
				}
			break;
		}
		
		case ((TVPIXFMT_08B8G8R8 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		case ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					dp[x] = TVPIXFMT_ABGR32_TO_RGB16(p);
				}
			break;
		}
		case 0x10000 | ((TVPIXFMT_08B8G8R8 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		case 0x10000 | ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					TUINT p2 = TVPIXFMT_ABGR32_TO_RGB16(p);
					dp[x] = TVPIXFMT_RGB16_SWAP(p2);
				}
			break;
		}
		
		/* 32 bit -> 15 bit */
		
		case ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		case ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					dp[x] = TVPIXFMT_ARGB32_TO_RGB15(p);
				}
			break;
		}
		case 0x10000 | ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		case 0x10000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					TUINT16 p2 = TVPIXFMT_ARGB32_TO_RGB15(p);
					dp[x] = TVPIXFMT_RGB16_SWAP(p2);
				}
			break;
		}
		
		case ((TVPIXFMT_08B8G8R8 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		case ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					dp[x] = TVPIXFMT_ABGR32_TO_RGB15(p);
				}
			break;
		}
		case 0x10000 | ((TVPIXFMT_08B8G8R8 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		case 0x10000 | ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					TUINT p2 = TVPIXFMT_ABGR32_TO_RGB15(p);
					dp[x] = TVPIXFMT_RGB16_SWAP(p2);
				}
			break;
		}

		case ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_0B5G5R5 & 0xff):
		case ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_0B5G5R5 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					dp[x] = TVPIXFMT_ARGB32_TO_BGR15(p);
				}
			break;
		}
		case 0x10000 | ((TVPIXFMT_08R8G8B8 & 0xff) << 8) | (TVPIXFMT_0B5G5R5 & 0xff):
		case 0x10000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_0B5G5R5 & 0xff):
		{
			TUINT *sp = ((TUINT *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT p = sp[x];
					TUINT16 p2 = TVPIXFMT_ARGB32_TO_BGR15(p);
					dp[x] = TVPIXFMT_RGB16_SWAP(p2);
				}
			break;
		}
		
		
		/* 15/16 bit -> 15/16 bit */
		
		case ((TVPIXFMT_R5G6B5 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		case ((TVPIXFMT_0R5G5B5 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		case ((TVPIXFMT_0B5G5R5 & 0xff) << 8) | (TVPIXFMT_0B5G5R5 & 0xff):
		{
			TUINT16 *sp = ((TUINT16 *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				memcpy(dp, sp, w * 2);
			break;
		}
		case 0x10000 | ((TVPIXFMT_R5G6B5 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		case 0x10000 | ((TVPIXFMT_0R5G5B5 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		case 0x10000 | ((TVPIXFMT_0B5G5R5 & 0xff) << 8) | (TVPIXFMT_0B5G5R5 & 0xff):
		{
			TUINT16 *sp = ((TUINT16 *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT16 p = sp[x];
					dp[x] = TVPIXFMT_RGB16_SWAP(p);
				}
			break;
		}
		
		/* 15 bit -> 16 bit */
		
		case ((TVPIXFMT_0B5G5R5 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		{
			TUINT16 *sp = ((TUINT16 *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT16 p = sp[x];
					dp[x] = TVPIXFMT_BGR15_TO_RGB16(p);
				}
			break;
		}
		
		
		/* 15 bit -> 32 bit */
		
		case ((TVPIXFMT_0R5G5B5 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case ((TVPIXFMT_0R5G5B5 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		{
			TUINT16 *sp = ((TUINT16 *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT16 p = sp[x];
					dp[x] = TVPIXFMT_RGB15_TO_ARGB32(p);
				}
			break;
		}
		case 0x10000 | ((TVPIXFMT_0R5G5B5 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case 0x10000 | ((TVPIXFMT_0R5G5B5 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		{
			TUINT16 *sp = ((TUINT16 *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT16 p = sp[x];
					TUINT32 p2 = TVPIXFMT_RGB15_TO_ARGB32(p);
					dp[x] = TVPIXFMT_0RGB32_SWAP(p2);
				}
			break;
		}
		
		case ((TVPIXFMT_0B5G5R5 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case ((TVPIXFMT_0B5G5R5 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		{
			TUINT16 *sp = ((TUINT16 *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT16 p = sp[x];
					dp[x] = TVPIXFMT_BGR15_TO_ARGB32(p);
				}
			break;
		}
		case 0x10000 | ((TVPIXFMT_0B5G5R5 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case 0x10000 | ((TVPIXFMT_0B5G5R5 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		{
			TUINT16 *sp = ((TUINT16 *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT16 p = sp[x];
					TUINT32 p2 = TVPIXFMT_BGR15_TO_ARGB32(p);
					dp[x] = TVPIXFMT_0RGB32_SWAP(p2);
				}
			break;
		}
		
		/* 16 bit -> 32 bit */
		
		case ((TVPIXFMT_R5G6B5 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case ((TVPIXFMT_R5G6B5 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		{
			TUINT16 *sp = ((TUINT16 *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT16 p = sp[x];
					dp[x] = TVPIXFMT_RGB16_TO_ARGB32(p);
				}
			break;
		}
		case 0x10000 | ((TVPIXFMT_R5G6B5 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case 0x10000 | ((TVPIXFMT_R5G6B5 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		{
			TUINT16 *sp = ((TUINT16 *) src->buf) + sx + sy * src->width;
			TUINT *dp = ((TUINT *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT16 p = sp[x];
					TUINT32 p2 = TVPIXFMT_RGB16_TO_ARGB32(p);
					dp[x] = TVPIXFMT_0RGB32_SWAP(p2);
				}
			break;
		}
		
		/* 32+alpha -> 32bit */
		
		case 0x20000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		case 0x20000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case 0x20000 | ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_A8B8G8R8 & 0xff):
		case 0x20000 | ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_08B8G8R8 & 0xff):
		{
			TUINT32 *sp = ((TUINT32 *) src->buf) + sx + sy * src->width;
			TUINT32 *dp = ((TUINT32 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT32 spix = sp[x];
					TUINT a = TVPIXFMT_ARGB32_GET_ALPHA8(spix);
					TUINT r = TVPIXFMT_ARGB32_GET_RED8(spix);
					TUINT g = TVPIXFMT_ARGB32_GET_GREEN8(spix);
					TUINT b = TVPIXFMT_ARGB32_GET_BLUE8(spix);
					TUINT dpix = dp[x];
					TUINT dr = TVPIXFMT_ARGB32_GET_RED8(dpix);
					TUINT dg = TVPIXFMT_ARGB32_GET_GREEN8(dpix);
					TUINT db = TVPIXFMT_ARGB32_GET_BLUE8(dpix);
					dr += ((r - dr) * a) >> 8;
					dg += ((g - dg) * a) >> 8;
					db += ((b - db) * a) >> 8;
					dp[x] = TVPIXFMT_R_G_B_TO_ARGB32(dr, dg, db);
				}
			break;
		}
		case 0x30000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		case 0x30000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		case 0x30000 | ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_A8B8G8R8 & 0xff):
		case 0x30000 | ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_08B8G8R8 & 0xff):
		{
			TUINT32 *sp = ((TUINT32 *) src->buf) + sx + sy * src->width;
			TUINT32 *dp = ((TUINT32 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT32 spix = sp[x];
					TUINT a = TVPIXFMT_ARGB32_GET_ALPHA8(spix);
					TUINT r = TVPIXFMT_ARGB32_GET_RED8(spix);
					TUINT g = TVPIXFMT_ARGB32_GET_GREEN8(spix);
					TUINT b = TVPIXFMT_ARGB32_GET_BLUE8(spix);
					TUINT dpix = dp[x];
					TUINT dr = TVPIXFMT_ARGB32_GET_RED8(dpix);
					TUINT dg = TVPIXFMT_ARGB32_GET_GREEN8(dpix);
					TUINT db = TVPIXFMT_ARGB32_GET_BLUE8(dpix);
					dr += ((r - dr) * a) >> 8;
					dg += ((g - dg) * a) >> 8;
					db += ((b - db) * a) >> 8;
					TUINT p = TVPIXFMT_R_G_B_TO_ARGB32(dr, dg, db);
					dp[x] = TVPIXFMT_0RGB32_SWAP(p);
				}
			break;
		}
		
		case 0x20000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_A8B8G8R8 & 0xff):
		case 0x20000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_08B8G8R8 & 0xff):
		case 0x20000 | ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_A8R8G8B8 & 0xff):
		case 0x20000 | ((TVPIXFMT_A8B8G8R8 & 0xff) << 8) | (TVPIXFMT_08R8G8B8 & 0xff):
		{
			TUINT32 *sp = ((TUINT32 *) src->buf) + sx + sy * src->width;
			TUINT32 *dp = ((TUINT32 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT32 spix = sp[x];
					TUINT a = TVPIXFMT_ABGR32_GET_ALPHA8(spix);
					TUINT r = TVPIXFMT_ABGR32_GET_RED8(spix);
					TUINT g = TVPIXFMT_ABGR32_GET_GREEN8(spix);
					TUINT b = TVPIXFMT_ABGR32_GET_BLUE8(spix);
					TUINT dpix = dp[x];
					TUINT dr = TVPIXFMT_ARGB32_GET_RED8(dpix);
					TUINT dg = TVPIXFMT_ARGB32_GET_GREEN8(dpix);
					TUINT db = TVPIXFMT_ARGB32_GET_BLUE8(dpix);
					dr += ((r - dr) * a) >> 8;
					dg += ((g - dg) * a) >> 8;
					db += ((b - db) * a) >> 8;
					dp[x] = TVPIXFMT_R_G_B_TO_ARGB32(dr, dg, db);
				}
			break;
		}
		
		/* 32+alpha -> 15 bit */
		case 0x20000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		{
			TUINT32 *sp = ((TUINT32 *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT32 spix = sp[x];
					TUINT a = TVPIXFMT_ARGB32_GET_ALPHA8(spix);
					TUINT r = TVPIXFMT_ARGB32_GET_RED8(spix);
					TUINT g = TVPIXFMT_ARGB32_GET_GREEN8(spix);
					TUINT b = TVPIXFMT_ARGB32_GET_BLUE8(spix);
					TUINT dpix = dp[x];
					TUINT dr = TVPIXFMT_RGB15_GET_RED8(dpix);
					TUINT dg = TVPIXFMT_RGB15_GET_GREEN8(dpix);
					TUINT db = TVPIXFMT_RGB15_GET_BLUE8(dpix);
					dr += ((r - dr) * a) >> 8;
					dg += ((g - dg) * a) >> 8;
					db += ((b - db) * a) >> 8;
					dp[x] = TVPIXFMT_R_G_B_TO_RGB15(dr, dg, db);
				}
			break;
		}
		case 0x30000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_0R5G5B5 & 0xff):
		{
			TUINT32 *sp = ((TUINT32 *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT32 spix = sp[x];
					TUINT a = TVPIXFMT_ARGB32_GET_ALPHA8(spix);
					TUINT r = TVPIXFMT_ARGB32_GET_RED8(spix);
					TUINT g = TVPIXFMT_ARGB32_GET_GREEN8(spix);
					TUINT b = TVPIXFMT_ARGB32_GET_BLUE8(spix);
					TUINT dpix = dp[x];
					TUINT dr = TVPIXFMT_RGB15_GET_RED8(dpix);
					TUINT dg = TVPIXFMT_RGB15_GET_GREEN8(dpix);
					TUINT db = TVPIXFMT_RGB15_GET_BLUE8(dpix);
					dr += ((r - dr) * a) >> 8;
					dg += ((g - dg) * a) >> 8;
					db += ((b - db) * a) >> 8;
					TUINT16 p = TVPIXFMT_R_G_B_TO_RGB15(dr, dg, db);
					dp[x] = TVPIXFMT_RGB16_SWAP(p);
				}
			break;
		}
		
		case 0x20000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_0B5G5R5 & 0xff):
		{
			TUINT32 *sp = ((TUINT32 *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT32 spix = sp[x];
					TUINT a = TVPIXFMT_ARGB32_GET_ALPHA8(spix);
					TUINT r = TVPIXFMT_ARGB32_GET_RED8(spix);
					TUINT g = TVPIXFMT_ARGB32_GET_GREEN8(spix);
					TUINT b = TVPIXFMT_ARGB32_GET_BLUE8(spix);
					TUINT dpix = dp[x];
					TUINT dr = TVPIXFMT_BGR15_GET_RED8(dpix);
					TUINT dg = TVPIXFMT_BGR15_GET_GREEN8(dpix);
					TUINT db = TVPIXFMT_BGR15_GET_BLUE8(dpix);
					dr += ((r - dr) * a) >> 8;
					dg += ((g - dg) * a) >> 8;
					db += ((b - db) * a) >> 8;
					dp[x] = TVPIXFMT_R_G_B_TO_BGR15(dr, dg, db);
				}
			break;
		}
		case 0x30000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_0B5G5R5 & 0xff):
		{
			TUINT32 *sp = ((TUINT32 *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT32 spix = sp[x];
					TUINT a = TVPIXFMT_ARGB32_GET_ALPHA8(spix);
					TUINT r = TVPIXFMT_ARGB32_GET_RED8(spix);
					TUINT g = TVPIXFMT_ARGB32_GET_GREEN8(spix);
					TUINT b = TVPIXFMT_ARGB32_GET_BLUE8(spix);
					TUINT dpix = dp[x];
					TUINT dr = TVPIXFMT_BGR15_GET_RED8(dpix);
					TUINT dg = TVPIXFMT_BGR15_GET_GREEN8(dpix);
					TUINT db = TVPIXFMT_BGR15_GET_BLUE8(dpix);
					dr += ((r - dr) * a) >> 8;
					dg += ((g - dg) * a) >> 8;
					db += ((b - db) * a) >> 8;
					TUINT16 p = TVPIXFMT_R_G_B_TO_BGR15(dr, dg, db);
					dp[x] = TVPIXFMT_RGB16_SWAP(p);
				}
			break;
		}
		
		/* 32+alpha -> 16 bit */
		
		case 0x20000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		{
			TUINT32 *sp = ((TUINT32 *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT32 spix = sp[x];
					TUINT a = TVPIXFMT_ARGB32_GET_ALPHA8(spix);
					TUINT r = TVPIXFMT_ARGB32_GET_RED8(spix);
					TUINT g = TVPIXFMT_ARGB32_GET_GREEN8(spix);
					TUINT b = TVPIXFMT_ARGB32_GET_BLUE8(spix);
					TUINT dpix = dp[x];
					TUINT dr = TVPIXFMT_RGB16_GET_RED8(dpix);
					TUINT dg = TVPIXFMT_RGB16_GET_GREEN8(dpix);
					TUINT db = TVPIXFMT_RGB16_GET_BLUE8(dpix);
					dr += ((r - dr) * a) >> 8;
					dg += ((g - dg) * a) >> 8;
					db += ((b - db) * a) >> 8;
					dp[x] = TVPIXFMT_R_G_B_TO_RGB16(dr, dg, db);
				}
			break;
		}
		case 0x30000 | ((TVPIXFMT_A8R8G8B8 & 0xff) << 8) | (TVPIXFMT_R5G6B5 & 0xff):
		{
			TUINT32 *sp = ((TUINT32 *) src->buf) + sx + sy * src->width;
			TUINT16 *dp = ((TUINT16 *) dst->buf) + x0 + y0 * dst->width;
			for (y = 0; y < h; ++y, dp += dst->width, sp += src->width)
				for (x = 0; x < w; ++x)
				{
					TUINT32 spix = sp[x];
					TUINT a = TVPIXFMT_ARGB32_GET_ALPHA8(spix);
					TUINT r = TVPIXFMT_ARGB32_GET_RED8(spix);
					TUINT g = TVPIXFMT_ARGB32_GET_GREEN8(spix);
					TUINT b = TVPIXFMT_ARGB32_GET_BLUE8(spix);
					TUINT dpix = dp[x];
					TUINT dr = TVPIXFMT_RGB16_GET_RED8(dpix);
					TUINT dg = TVPIXFMT_RGB16_GET_GREEN8(dpix);
					TUINT db = TVPIXFMT_RGB16_GET_BLUE8(dpix);
					dr += ((r - dr) * a) >> 8;
					dg += ((g - dg) * a) >> 8;
					db += ((b - db) * a) >> 8;
					TUINT16 p = TVPIXFMT_R_G_B_TO_RGB16(dr, dg, db);
					dp[x] = TVPIXFMT_RGB16_SWAP(p);
				}
			break;
		}
		
		default:
			TDBPRINTF(TDB_WARN,("unsupported conversion %08x: alpha=%d swap=%d src=%08x dst=%08x\n", 
				c, alpha, swap, src->fmt, dst->fmt));
			return 1;
	}
	
	return 0;
}

#endif
