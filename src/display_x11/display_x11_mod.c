
/*
**	teklib/src/display_x11/display_x11_all.c - X11 Display driver
**	Written by Timm S. Mueller <tmueller at neoscientists.org>
**	See copyright notice in teklib/COPYRIGHT
*/

#include "display_x11_mod.h"

static TAPTR x11_modopen(X11DISPLAY *mod, TTAGITEM *tags);
static void x11_modclose(X11DISPLAY *mod);
static TMODAPI void x11_beginio(X11DISPLAY *mod, struct TVRequest *req);
static TMODAPI TINT x11_abortio(X11DISPLAY *mod, struct TVRequest *req);
static TMODAPI struct TVRequest *x11_allocreq(X11DISPLAY *mod);
static TMODAPI void x11_freereq(X11DISPLAY *mod, struct TVRequest *req);

static const TMFPTR x11_vectors[X11DISPLAY_NUMVECTORS] =
{
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,
	(TMFPTR) x11_beginio,
	(TMFPTR) x11_abortio,
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,

	(TMFPTR) x11_allocreq,
	(TMFPTR) x11_freereq,
};

static void x11_destroy(X11DISPLAY *mod)
{
	TDBPRINTF(TDB_TRACE,("X11 module destroy...\n"));
	TDestroy(mod->x11_Lock);
}

static THOOKENTRY TTAG x11_dispatch(struct THook *hook, TAPTR obj, TTAG msg)
{
	X11DISPLAY *mod = (X11DISPLAY *) hook->thk_Data;
	switch (msg)
	{
		case TMSG_DESTROY:
			x11_destroy(mod);
			break;
		case TMSG_OPENMODULE:
			return (TTAG) x11_modopen(mod, obj);
		case TMSG_CLOSEMODULE:
			x11_modclose(obj);
			break;
		case TMSG_INITTASK:
			return x11_initinstance(obj);
		case TMSG_RUNTASK:
			x11_taskfunc(obj);
	}
	return 0;
}

TMODENTRY TUINT tek_init_display_x11(struct TTask *task, struct TModule *vis,
	TUINT16 version, TTAGITEM *tags)
{
	X11DISPLAY *mod = (X11DISPLAY *) vis;
	if (mod == TNULL)
	{
		if (version == 0xffff)
			return sizeof(TAPTR) * X11DISPLAY_NUMVECTORS;

		if (version <= X11DISPLAY_VERSION)
			return sizeof(X11DISPLAY);

		return 0;
	}

	for (;;)
	{
		TAPTR TExecBase = TGetExecBase(task);

		mod->x11_Lock = TCreateLock(TNULL);
		if (mod->x11_Lock == TNULL) break;

		mod->x11_Module.tmd_Version = X11DISPLAY_VERSION;
		mod->x11_Module.tmd_Revision = X11DISPLAY_REVISION;
		mod->x11_Module.tmd_Handle.thn_Hook.thk_Entry = x11_dispatch;
		mod->x11_Module.tmd_Flags = TMODF_VECTORTABLE | TMODF_OPENCLOSE;
		TInitVectors(&mod->x11_Module, x11_vectors, X11DISPLAY_NUMVECTORS);
		return TTRUE;
	}

	x11_destroy(mod);
	return TFALSE;
}

/*****************************************************************************/
/*
**	Module open/close
*/

static TAPTR x11_modopen(X11DISPLAY *mod, TTAGITEM *tags)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TBOOL success = TTRUE;
	TLock(mod->x11_Lock);
	if (mod->x11_RefCount == 0)
		success = x11_init(mod, tags);
	if (success)
		mod->x11_RefCount++;
	TUnlock(mod->x11_Lock);
	if (success)
		return mod;
	return TNULL;
}

static void x11_modclose(X11DISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TDBPRINTF(TDB_TRACE,("Device close\n"));
	TLock(mod->x11_Lock);
	if (--mod->x11_RefCount == 0)
		x11_exit(mod);
	TUnlock(mod->x11_Lock);
}

/*****************************************************************************/
/*
**	BeginIO/AbortIO
*/

static TMODAPI void x11_beginio(X11DISPLAY *mod, struct TVRequest *req)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TPutMsg(mod->x11_CmdPort, req->tvr_Req.io_ReplyPort, req);
	x11_wake(mod);
}

static TMODAPI TINT x11_abortio(X11DISPLAY *mod, struct TVRequest *req)
{
	/* not supported: */
	return -1;
}

/*****************************************************************************/
/*
**	AllocReq/FreeReq
*/

static TMODAPI struct TVRequest *x11_allocreq(X11DISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	struct TVRequest *req = TAllocMsg(sizeof(struct TVRequest));
	if (req)
		req->tvr_Req.io_Device = (struct TModule *) mod;
	return req;
}

static TMODAPI void x11_freereq(X11DISPLAY *mod, struct TVRequest *req)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TFree(req);
}

/*****************************************************************************/
/*
**	convert an utf8 encoded string to latin-1
*/

struct readstringdata
{
	const unsigned char *src;
	size_t srclen;
};

static int readstring(struct utf8reader *rd)
{
	struct readstringdata *ud = rd->udata;
	if (ud->srclen == 0)
		return -1;
	ud->srclen--;
	return *ud->src++;
}

LOCAL TSTRPTR x11_utf8tolatin(X11DISPLAY *mod, TSTRPTR utf8string, TINT len,
	TINT *bytelen)
{
	struct utf8reader rd;
	struct readstringdata rs;
	TUINT8 *latin = mod->x11_utf8buffer;
	TINT i = 0;
	TINT c;

	rs.src = (unsigned char *) utf8string;
	rs.srclen = len;

	rd.readchar = readstring;
	rd.accu = 0;
	rd.numa = 0;
	rd.bufc = -1;
	rd.udata = &rs;

	while (i < X11_UTF8_BUFSIZE - 1 && (c = readutf8(&rd)) >= 0)
	{
		if (c < 256)
			latin[i++] = c;
		else
			latin[i++] = 0xbf;
	}

	if (bytelen)
		*bytelen = i;

	return (TSTRPTR) latin;
}
