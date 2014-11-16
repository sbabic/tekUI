#ifndef _TEK_DISPLAY_X11_MOD_H
#define _TEK_DISPLAY_X11_MOD_H

/*
**	teklib/src/visual/display_x11_mod.h - X11 Display Driver
**	Written by Timm S. Mueller <tmueller at neoscientists.org>
**	See copyright notice in teklib/COPYRIGHT
*/

#include <tek/debug.h>
#include <tek/teklib.h>
#include <tek/mod/visual.h>
#include <tek/lib/utf8.h>

#include <X11/X.h>
#if defined(ENABLE_XFT)
#include <X11/Xft/Xft.h>
#endif
#include <X11/Xlib.h>
#include <sys/shm.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>
#include <X11/Xatom.h>
#include <X11/XKBlib.h>
#include <X11/extensions/XShm.h>
#if defined(ENABLE_XVID)
#include <X11/extensions/xf86vmode.h>
#endif

/*****************************************************************************/

#define X11DISPLAY_VERSION		1
#define X11DISPLAY_REVISION		1
#define X11DISPLAY_NUMVECTORS	10

#define X11_UTF8_BUFSIZE 4096

#ifndef LOCAL
#define LOCAL
#endif

#ifndef EXPORT
#define EXPORT TMODAPI
#endif

/*****************************************************************************/

#define DEFFONTNAME			"-misc-fixed-medium-r-normal-*-14-*-*-*-*-*-*-*"

#define X11FNT_LENGTH			41
#define X11FNT_DEFNAME			"fixed"
#define X11FNT_WGHT_MEDIUM		"medium"
#define	X11FNT_WGHT_BOLD		"bold"
#define X11FNT_SLANT_R			"r"
#define X11FNT_SLANT_I			"i"
#define X11FNT_DEFPXSIZE		14
#define	X11FNT_DEFREGENC		"iso8859-1"
#define	X11FNT_WILDCARD		"*"

#define X11FNTQUERY_NUMATTR	(5+1)
#define	X11FNTQUERY_UNDEFINED	0xffffffff

#define X11FNT_ITALIC			0x1
#define	X11FNT_BOLD			0x2
#define X11FNT_UNDERLINE		0x4

#define X11FNT_MATCH_NAME		0x01
#define X11FNT_MATCH_SIZE		0x02
#define X11FNT_MATCH_SLANT		0x04
#define	X11FNT_MATCH_WEIGHT	0x08
#define	X11FNT_MATCH_SCALE		0x10
/* all mandatory properties: */
#define X11FNT_MATCH_ALL		0x0f

struct X11FontMan
{
	struct TList openfonts;		/* list of opened fonts */
	TAPTR deffont;				/* pointer to default font */
	TINT defref;				/* count of references to default font */
};

struct X11FontHandle
{
	struct THandle handle;
	XFontStruct *font;
	#if defined(ENABLE_XFT)
	XftFont *xftfont;
	#endif
	TUINT attr;
	TUINT pxsize;
};

struct X11FontQueryNode
{
	struct TNode node;
	TTAGITEM tags[X11FNTQUERY_NUMATTR];
};

struct X11FontQueryHandle
{
	struct THandle handle;
	struct TList reslist;
	struct TNode **nptr;
};

/* internal structures */

struct X11FontNode
{
	struct TNode node;
	TSTRPTR fname;
};

struct X11FontAttr
{
	struct TList fnlist;	/* list of fontnames */
	TSTRPTR fname;
	TUINT  fpxsize;
	TBOOL fitalic;
	TBOOL fbold;
	TBOOL fscale;
	TINT  fnum;
};

#if defined(ENABLE_XFT)
struct XftInterface
{
	XftFont *(*XftFontOpen)(Display *dpy, int screen, ...);
	void (*XftFontClose)(Display *dpy, XftFont *pub);
	void (*XftTextExtentsUtf8)(Display *dpy, XftFont *pub,
		_Xconst FcChar8 *string, int len, XGlyphInfo *extents);
	void (*XftDrawStringUtf8)(XftDraw *draw, _Xconst XftColor *color, 
		XftFont *pub, int x, int y, _Xconst FcChar8  *string, int len);
	void (*XftDrawRect)(XftDraw *draw, _Xconst XftColor *color, int x, int y,
		unsigned int width, unsigned int height);
	FT_Face (*XftLockFace)(XftFont *pub);
	void (*XftUnlockFace)(XftFont *pub);
	Bool (*XftColorAllocValue)(Display *dpy, Visual *visual, Colormap cmap,
		_Xconst XRenderColor *color, XftColor *result);
	void (*XftColorFree)(Display *dpy, Visual *visual, Colormap  cmap,
		XftColor *color);
	XftDraw *(*XftDrawCreate)(Display *dpy, Drawable  drawable, Visual *visual,
		Colormap colormap);
	void (*XftDrawDestroy)(XftDraw *draw);
	Bool (*XftDrawSetClip)(XftDraw *d, Region r);
};

#define LIBXFT_NUMSYMS	(sizeof(struct XftInterface) / sizeof(void (*)(void)))


struct FcInterface
{
	void (*FcDefaultSubstitute)(FcPattern *pattern);
	void (*FcFontSetDestroy)(FcFontSet *s);
	FcFontSet *(*FcFontSort)(FcConfig *config, FcPattern *p, FcBool trim,
		FcCharSet **csp, FcResult *result);
	FcBool (*FcPatternAddBool)(FcPattern *p, const char *object, FcBool b);
	FcBool (*FcPatternAddInteger)(FcPattern *p, const char *object, int i);
	FcPattern *(*FcPatternBuild)(FcPattern *orig, ...);
	void (*FcPatternDestroy)(FcPattern *p);
	void (*FcPatternPrint)(const FcPattern *p);
	FcResult (*FcPatternGetString)(const FcPattern *p, const char *object,
		int n, FcChar8 **s);
	FcResult (*FcPatternGetInteger)(const FcPattern *p, const char *object,
		int n, int *i);
	FcResult (*FcPatternGetBool)(const FcPattern *p, const char *object,
		int n, FcBool *b);
	FcBool (*FcInit)(void);
	void (*FcFini)(void);
};

#define LIBFC_NUMSYMS	(sizeof(struct FcInterface) / sizeof(void (*)(void)))

#endif

/*****************************************************************************/

typedef struct
{
	/* Module header: */
	struct TModule x11_Module;
	/* Module global memory manager (thread safe): */
	TAPTR x11_MemMgr;
	/* Locking for module base structure: */
	TAPTR x11_Lock;
	/* Number of module opens: */
	TUINT x11_RefCount;
	/* Task: */
	TAPTR x11_Task;
	/* Command message port: */
	TAPTR x11_CmdPort;
	/* Command message port signal: */
	TUINT x11_CmdPortSignal;

	/* X11 display: */
	Display *x11_Display;
	/* default X11 screen number: */
	int x11_Screen;
	/* default X11 visual: */
	Visual *x11_Visual;
	
	TAPTR x11_IReplyPort;
	TUINT x11_IReplyPortSignal;	
	struct THook x11_IReplyHook;

	TINT x11_DefaultBPP;
	TINT x11_DefaultDepth;
	TINT x11_ByteOrder;
	TBOOL x11_SwapByteOrder;

	int x11_fd_display;
	int x11_fd_sigpipe_read;
	int x11_fd_sigpipe_write;
	int x11_fd_max;

	#if defined(ENABLE_XFT)
	TBOOL x11_use_xft;
	TAPTR x11_libxfthandle;
	struct XftInterface x11_xftiface;
	TAPTR x11_libfchandle;
	struct FcInterface x11_fciface;
	#endif

	struct X11FontMan x11_fm;

	/* list of all visuals: */
	struct TList x11_vlist;

	struct TList x11_imsgpool;

	struct TVRequest *x11_RequestInProgress;
	struct THook *x11_CopyExposeHook;

	Region x11_HugeRegion;
	TBOOL x11_ShmAvail;
	TINT x11_ShmEvent;

	TINT x11_KeyQual;
	TINT x11_ScreenMouseX, x11_ScreenMouseY;

	TUINT8 x11_utf8buffer[X11_UTF8_BUFSIZE];

	Cursor x11_NullCursor;
	#if defined(ENABLE_DEFAULTCURSOR)
	Cursor x11_DefaultCursor;
	#endif

	TTAGITEM *x11_InitTags;
	struct TMsgPort *x11_IMsgPort;
	
	TINT x11_ScreenWidth;
	TINT x11_ScreenHeight;
	
	/* vidmode screensize: */
	TINT x11_FullScreenWidth;
	TINT x11_FullScreenHeight;
	
	/* fullscreen (logical): */
	TBOOL x11_FullScreen;
	
	Atom x11_XA_TARGETS;
	Atom x11_XA_PRIMARY;
	Atom x11_XA_CLIPBOARD;
	Atom x11_XA_UTF8_STRING;
	Atom x11_XA_STRING;
	Atom x11_XA_COMPOUND_TEXT;
	
	#if defined(ENABLE_XVID)
	XF86VidModeModeInfo x11_OldMode;
	XF86VidModeModeInfo x11_VidMode;
	#endif

	#if defined(ENABLE_X11_DGRAM)
	int x11_UserFD;
	#endif

	TINT x11_NumWindows;

} X11DISPLAY;

struct X11Pen
{
	struct TNode node;
	XColor color;
	#if defined(ENABLE_XFT)
	XftColor xftcolor;
	#endif
};

typedef struct
{
	struct TNode node;

	TINT winwidth, winheight;
	TINT winleft, wintop;
	TSTRPTR title;

	Window window;

	Colormap colormap;
	GC gc;

#if defined(ENABLE_XFT)
	XftDraw *draw;
#endif
	TAPTR curfont; /* current active font */

	Atom atom_wm_delete_win;

	TUINT base_mask;
	TUINT eventmask;

	TVPEN bgpen, fgpen;

	XImage *image;
	TBOOL image_shm;
	char *tempbuf;
	int imw, imh;

	XSizeHints *sizehints;

	struct TList imsgqueue;
	TAPTR imsgport;

	/* list of allocated pens: */
	struct TList penlist;

	/* HACK to consume an Expose event after ConfigureNotify: */
	TBOOL waitforexpose;
	TBOOL waitforresize;

	XShmSegmentInfo shminfo;

	/* userdata attached to this window, also propagated in messages: */
	TTAG userdata;
	
	TBOOL changevidmode;
	
	size_t shmsize;
	
	TUINT pixfmt;
	TUINT bpp;

	TINT mousex, mousey;
	
	TBOOL is_root_window;
	
} X11WINDOW;

struct attrdata
{
	X11DISPLAY *mod;
	X11WINDOW *v;
	TAPTR font;
	TINT num;
	TBOOL sizechanged;
	TINT neww, newh, newx, newy;
};

/*****************************************************************************/

LOCAL TBOOL x11_initlibxft(X11DISPLAY *mod);
LOCAL void x11_exitlibxft(X11DISPLAY *mod);

LOCAL TBOOL x11_init(X11DISPLAY *mod, TTAGITEM *tags);
LOCAL void x11_exit(X11DISPLAY *mod);
LOCAL TTASKENTRY void x11_taskfunc(struct TTask *task);
LOCAL TTASKENTRY TBOOL x11_initinstance(struct TTask *task);

LOCAL void x11_sendimessages(X11DISPLAY *mod, TBOOL do_interval);

LOCAL void x11_openvisual(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_closevisual(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_setinput(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_allocpen(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_freepen(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_frect(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_rect(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_line(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_plot(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_drawstrip(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_clear(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_getattrs(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_setattrs(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_drawtext(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_openfont(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_getfontattrs(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_textsize(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_setfont(X11DISPLAY *mod, struct TVRequest *req);

LOCAL void x11_closefont(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_queryfonts(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_getnextfont(X11DISPLAY *mod, struct TVRequest *req);

LOCAL void x11_drawtags(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_drawfan(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_copyarea(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_setcliprect(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_unsetcliprect(X11DISPLAY *mod, struct TVRequest *req);
LOCAL void x11_drawbuffer(X11DISPLAY *mod, struct TVRequest *req);

LOCAL void x11_wake(X11DISPLAY *inst);

LOCAL void x11_hostsetfont(X11DISPLAY *mod, X11WINDOW *v, TAPTR font);
LOCAL TAPTR x11_hostopenfont(X11DISPLAY *mod, TTAGITEM *tags);
LOCAL TAPTR x11_hostqueryfonts(X11DISPLAY *mod, TTAGITEM *tags);
LOCAL void x11_hostclosefont(X11DISPLAY *mod, TAPTR font);
LOCAL TINT x11_hosttextsize(X11DISPLAY *mod, TAPTR font, TSTRPTR text,
	TINT len);
LOCAL THOOKENTRY TTAG x11_hostgetfattrfunc(struct THook *hook, TAPTR obj,
	TTAG msg);
LOCAL TTAGITEM *x11_hostgetnextfont(X11DISPLAY *mod, TAPTR fqhandle);
LOCAL TSTRPTR x11_utf8tolatin(X11DISPLAY *mod, TSTRPTR utf8string, TINT len,
	TINT *bytelen);

LOCAL void x11_getselection(X11DISPLAY *mod, struct TVRequest *req);

#endif /* _TEK_DISPLAY_X11_MOD_H */
