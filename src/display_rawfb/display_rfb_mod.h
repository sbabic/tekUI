#ifndef _TEK_DISPLAY_RFB_MOD_H
#define _TEK_DISPLAY_RFB_MOD_H

/*
**	display_rfb_mod.h - Raw framebuffer display driver
**	Written by Franciska Schulze <fschulze at schulze-mueller.de>
**	and Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

#define NDEBUG
#include <assert.h>

#include <tek/debug.h>
#include <tek/exec.h>
#include <tek/teklib.h>
#include <tek/mod/visual.h>
#include <tek/lib/region.h>
#include <tek/lib/utf8.h>
#include <tek/lib/pixconv.h>

#include <ft2build.h>
#include FT_FREETYPE_H
#include <freetype/ftglyph.h>
#include <freetype/ftcache.h>

#if defined(ENABLE_VNCSERVER)
#include <rfb/rfb.h>
#include <rfb/rfbregion.h>
#endif

/*****************************************************************************/

#define RFB_DISPLAY_VERSION      2
#define RFB_DISPLAY_REVISION     0
#define RFB_DISPLAY_NUMVECTORS   10

#ifndef LOCAL
#define LOCAL
#endif

#ifndef EXPORT
#define EXPORT TMODAPI
#endif

/*****************************************************************************/

#if defined(RFB_DEPTH_24BIT)

typedef TUINT32 RFBPixel;
#define RFB_BITS_PER_GUN 8

/* BGR: */
#define RFBPIXFMT TVPIXFMT_08B8G8R8
#define GetRFBPixelRed(p)		TVPIXFMT_ABGR32_GET_RED8(p)
#define GetRFBPixelGreen(p)		TVPIXFMT_ABGR32_GET_GREEN8(p)
#define GetRFBPixelBlue(p)		TVPIXFMT_ABGR32_GET_BLUE8(p)
#define RGB2RFBPixel(p)			TVPIXFMT_ARGB32_TO_ABGR32(p)
#define RFBPixelFromRGB(r,g,b)	TVPIXFMT_R_G_B_TO_ABGR32(r,g,b)

/* RGB:
#define RFBPIXFMT TVPIXFMT_08R8G8B8
#define GetRFBPixelRed(p)		TVPIXFMT_ARGB32_GET_RED8(p)
#define GetRFBPixelGreen(p)		TVPIXFMT_ARGB32_GET_GREEN8(p)
#define GetRFBPixelBlue(p)		TVPIXFMT_ARGB32_GET_BLUE8(p)
#define RGB2RFBPixel(p)			(p)
#define RFBPixelFromRGB(r,g,b)	TVPIXFMT_R_G_B_TO_ARGB32(r,g,b)
*/

#else

typedef TUINT16 RFBPixel;
#define RFBPIXFMT TVPIXFMT_0B5G5R5
#define RFB_BITS_PER_GUN 5
#define GetRFBPixelRed(p)		TVPIXFMT_BGR15_GET_RED8(p)
#define GetRFBPixelGreen(p)		TVPIXFMT_BGR15_GET_GREEN8(p)
#define GetRFBPixelBlue(p)		TVPIXFMT_BGR15_GET_BLUE8(p)
#define RGB2RFBPixel(p) 		TVPIXFMT_ARGB32_TO_BGR15(p)
#define RFBPixelFromRGB(r,g,b)	TVPIXFMT_R_G_B_TO_BGR15(r,g,b)

#endif

#define WritePixel(v, x, y, p) do { \
	assert((x) >= (v)->rfbw_WinRect[0]); \
	assert((x) <= (v)->rfbw_WinRect[2]); \
	assert((y) >= (v)->rfbw_WinRect[1]); \
	assert((y) <= (v)->rfbw_WinRect[3]); \
	((RFBPixel *)(v)->rfbw_BufPtr)[(y) * (v)->rfbw_PixelPerLine + (x)] = (p); \
} while(0)

/*****************************************************************************/

#define RFB_DEF_WIDTH            600
#define RFB_DEF_HEIGHT           400

#define RFB_UTF8_BUFSIZE 4096

/*****************************************************************************/
/*
**	Fonts
*/

#ifndef FNT_DEFDIR
#define	FNT_DEFDIR          "tek/ui/font"
#endif

#define FNT_DEFNAME         "VeraMono"
#define FNT_DEFPXSIZE       14

#define	FNT_WILDCARD        "*"

#define FNTQUERY_NUMATTR	(5+1)
#define	FNTQUERY_UNDEFINED	-1

#define FNT_ITALIC			0x1
#define	FNT_BOLD			0x2
#define FNT_UNDERLINE		0x4

#define FNT_MATCH_NAME		0x01
#define FNT_MATCH_SIZE		0x02
#define FNT_MATCH_SLANT		0x04
#define	FNT_MATCH_WEIGHT	0x08
#define	FNT_MATCH_SCALE		0x10
/* all mandatory properties: */
#define FNT_MATCH_ALL		0x0f

#define MAX_GLYPHS 256

struct FontManager
{
	/* list of opened fonts */
	struct TList openfonts;
};

struct FontNode
{
	struct THandle handle;
	FT_Face face;
	TUINT pxsize;
	TINT ascent;
	TINT descent;
	TINT height;
	TSTRPTR name;
};

struct FontQueryNode
{
	struct TNode node;
	TTAGITEM tags[FNTQUERY_NUMATTR];
};

struct FontQueryHandle
{
	struct THandle handle;
	struct TList reslist;
	struct TNode **nptr;
};

LOCAL FT_Error rfb_fontrequester(FTC_FaceID faceID, FT_Library lib, 
	FT_Pointer reqData, FT_Face *face);

/*****************************************************************************/

typedef struct
{
	/* Module header: */
	struct TModule rfb_Module;
	/* Exec module base ptr: */
	struct TExecBase *rfb_ExecBase;
	/* Locking for module base: */
	struct TLock *rfb_Lock;
	/* Number of module opens: */
	TUINT rfb_RefCount;
	/* Task: */
	struct TTask *rfb_Task;
	/* Command message port: */
	struct TMsgPort *rfb_CmdPort;
	
	/* Sub rendering device (optional): */
	TAPTR rfb_RndDevice;
	/* Replyport for render requests: */
	struct TMsgPort *rfb_RndRPort;
	/* Render device instance: */
	TAPTR rfb_RndInstance;
	/* Render request: */
	struct TVRequest *rfb_RndRequest;
	/* Own input message port receiving input from sub device: */
	TAPTR rfb_RndIMsgPort;
	
	/* Device open tags: */
	TTAGITEM *rfb_OpenTags;
	
	/* Module global memory manager (thread safe): */
	struct TMemManager *rfb_MemMgr;
	
	/* Locking for instance data: */
	struct TLock *rfb_InstanceLock;
	
	/* pooled input messages: */
	struct TList rfb_IMsgPool;

	/* list of all visuals: */
	struct TList rfb_VisualList;
	
	struct RectPool rfb_RectPool;
	RFBPixel *rfb_BufPtr;
	TBOOL rfb_BufferOwner;
	TUINT rfb_InputMask;

	TINT rfb_Width;
	TINT rfb_Height;
	TINT rfb_Modulo;
	TINT rfb_BytesPerPixel;
	TINT rfb_BytesPerLine;

	FT_Library rfb_FTLibrary;
	FTC_Manager	rfb_FTCManager;
	FTC_CMapCache rfb_FTCCMapCache;
	FTC_SBitCache rfb_FTCSBitCache;

	struct FontManager rfb_FontManager;

	TINT rfb_MouseX;
	TINT rfb_MouseY;
	TINT rfb_KeyQual;

	TUINT32 rfb_unicodebuffer[RFB_UTF8_BUFSIZE];
	
	struct Region *rfb_DirtyRegion;
	
	struct rfb_window *rfb_FocusWindow;
	
#if defined(ENABLE_VNCSERVER)
	rfbScreenInfoPtr rfb_RFBScreen;
	TAPTR rfb_VNCTask;
	int rfb_RFBPipeFD[2];
	TUINT rfb_RFBReadySignal;
	TAPTR rfb_RFBMainTask;
	TBOOL rfb_WaitSignal;
#endif

} RFBDISPLAY;

typedef struct rfb_window
{
	struct TNode rfbw_Node;
	/* Window extents: */
	TINT rfbw_WinRect[4];
	/* Clipping boundaries: */
	TINT rfbw_ClipRect[4];
	/* Buffer pointer to upper left edge of visual: */
	RFBPixel *rfbw_BufPtr;
	/* Current pens: */
	TVPEN bgpen, fgpen;
	/* list of allocated pens: */
	struct TList penlist;
	/* current active font */
	TAPTR curfont;
	/* Destination message port for input messages: */
	TAPTR rfbw_IMsgPort;
	/* mask of active events */
	TUINT rfbw_InputMask;
	/* userdata attached to this window, also propagated in messages: */
	TTAG userdata;
	/* Modulo, pixel per line */
	TINT rfbw_Modulo;
	TINT rfbw_PixelPerLine;
	/* window is "borderless", i.e. a popup window: */
	TBOOL borderless;

} RFBWINDOW;

struct RFBPen
{
	struct TNode node;
	TUINT32 rgb;
};

struct rfb_attrdata
{
	RFBDISPLAY *mod;
	RFBWINDOW *v;
	TAPTR font;
	TINT num;
};

/*****************************************************************************/
/*
**	Framebuffer drawing primitives
*/

LOCAL void fbp_drawpoint(RFBDISPLAY *mod, RFBWINDOW *v, TINT x, TINT y, struct RFBPen *pen);
LOCAL void fbp_drawfrect(RFBDISPLAY *mod, RFBWINDOW *v, TINT rect[4], struct RFBPen *pen);
LOCAL void fbp_drawrect(RFBDISPLAY *mod, RFBWINDOW *v, TINT rect[4], struct RFBPen *pen);
LOCAL void fbp_drawline(RFBDISPLAY *mod, RFBWINDOW *v, TINT rect[4], struct RFBPen *pen);
LOCAL void fbp_drawtriangle(RFBDISPLAY *mod, RFBWINDOW *v, TINT x0, TINT y0, TINT x1, TINT y1,
	TINT x2, TINT y2, struct RFBPen *pen);
LOCAL void fbp_drawbuffer(RFBDISPLAY *mod, RFBWINDOW *v, struct PixArray *src,
	TINT x, TINT y, TINT w, TINT h, TBOOL alpha);
LOCAL void fbp_copyarea(RFBDISPLAY *mod, RFBWINDOW *v, TINT rect[4],
	TINT dx0, TINT dy0, struct THook *exposehook);

/*****************************************************************************/

LOCAL TUINT32 *rfb_utf8tounicode(RFBDISPLAY *mod, TSTRPTR utf8string, TINT len,
	TINT *bytelen);
LOCAL TBOOL rfb_getimsg(RFBDISPLAY *mod, RFBWINDOW *v, TIMSG **msgptr,
	TUINT type);

LOCAL void rfb_exit(RFBDISPLAY *mod);
LOCAL void rfb_openvisual(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_closevisual(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_setinput(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_allocpen(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_freepen(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_frect(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_rect(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_line(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_plot(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_drawstrip(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_clear(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_getattrs(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_setattrs(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_drawtext(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_openfont(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_getfontattrs(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_textsize(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_setfont(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_closefont(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_queryfonts(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_getnextfont(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_drawtags(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_drawfan(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_copyarea(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_setcliprect(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_unsetcliprect(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_drawbuffer(RFBDISPLAY *mod, struct TVRequest *req);
LOCAL void rfb_flush(RFBDISPLAY *mod, struct TVRequest *req);

LOCAL TBOOL rfb_damage(RFBDISPLAY *mod, TINT drect[], RFBWINDOW *v);
LOCAL struct Region *rfb_getlayers(RFBDISPLAY *mod, RFBWINDOW *v, TINT dx, TINT dy);
LOCAL struct Region *rfb_getlayermask(RFBDISPLAY *mod, TINT *crect,
	RFBWINDOW *v, TINT dx, TINT dy);
LOCAL void rfb_markdirty(RFBDISPLAY *mod, TINT *r);
LOCAL void rfb_schedulecopy(RFBDISPLAY *mod, TINT *r, TINT dx, TINT dy);

LOCAL TAPTR rfb_hostopenfont(RFBDISPLAY *mod, TTAGITEM *tags);
LOCAL void rfb_hostclosefont(RFBDISPLAY *mod, TAPTR font);
LOCAL void rfb_hostsetfont(RFBDISPLAY *mod, RFBWINDOW *v, TAPTR font);
LOCAL TTAGITEM *rfb_hostgetnextfont(RFBDISPLAY *mod, TAPTR fqhandle);
LOCAL TINT rfb_hosttextsize(RFBDISPLAY *mod, TAPTR font, TSTRPTR text, TINT len);
LOCAL TVOID rfb_hostdrawtext(RFBDISPLAY *mod, RFBWINDOW *v, TSTRPTR text,
	TINT len, TINT posx, TINT posy, TVPEN fgpen);
LOCAL THOOKENTRY TTAG rfb_hostgetfattrfunc(struct THook *hook, TAPTR obj,
	TTAG msg);
LOCAL TAPTR rfb_hostqueryfonts(RFBDISPLAY *mod, TTAGITEM *tags);

LOCAL void rfb_flush_clients(RFBDISPLAY *mod, TBOOL also_external);

LOCAL RFBWINDOW *rfb_findcoord(RFBDISPLAY *mod, TINT x, TINT y);
LOCAL void rfb_focuswindow(RFBDISPLAY *mod, RFBWINDOW *v);
LOCAL TBOOL rfb_ispointobscured(RFBDISPLAY *mod, TINT x, TINT y, RFBWINDOW *v);
LOCAL void rfb_copyrect_sub(RFBDISPLAY *mod, TINT *rect, TINT dx, TINT dy);

#if defined(ENABLE_VNCSERVER)

int rfb_vnc_init(RFBDISPLAY *mod);
void rfb_vnc_exit(RFBDISPLAY *mod);
void rfb_vnc_flush(RFBDISPLAY *mod, struct Region *D);
void rfb_vnc_copyrect(RFBDISPLAY *mod, RFBWINDOW *v, int dx, int dy,
	int x0, int y0, int x1, int y1, int yinc);

#endif

#endif /* _TEK_DISPLAY_RFB_MOD_H */
