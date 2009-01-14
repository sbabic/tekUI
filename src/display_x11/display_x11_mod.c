
/*
**	teklib/src/visual/x11/display_x11_mod.c - X11 Display driver
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

static const TMFPTR
x11_vectors[X11DISPLAY_NUMVECTORS] =
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

static void
x11_destroy(X11DISPLAY *mod)
{
	TDBPRINTF(TDB_TRACE,("X11 module destroy...\n"));
	TDestroy(mod->x11_Lock);
}

static THOOKENTRY TTAG
x11_dispatch(struct THook *hook, TAPTR obj, TTAG msg)
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
	}
	return 0;
}

TMODENTRY TUINT
tek_init_display_x11(struct TTask *task, struct TModule *vis, TUINT16 version,
	TTAGITEM *tags)
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
		mod->x11_ExecBase = TGetExecBase(mod);
		mod->x11_Lock = TExecCreateLock(mod->x11_ExecBase, TNULL);
		if (mod->x11_Lock == TNULL) break;

		mod->x11_Module.tmd_Version = X11DISPLAY_VERSION;
		mod->x11_Module.tmd_Revision = X11DISPLAY_REVISION;
		mod->x11_Module.tmd_Handle.thn_Hook.thk_Entry = x11_dispatch;
		mod->x11_Module.tmd_Flags = TMODF_VECTORTABLE | TMODF_OPENCLOSE;
		TInitVectors(mod, x11_vectors, X11DISPLAY_NUMVECTORS);
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
	TBOOL success = TTRUE;
	TExecLock(mod->x11_ExecBase, mod->x11_Lock);
	if (mod->x11_RefCount == 0)
		success = x11_init(mod, tags);
	if (success)
		mod->x11_RefCount++;
	TExecUnlock(mod->x11_ExecBase, mod->x11_Lock);
	if (success)
		return mod;
	return TNULL;
}

static void
x11_modclose(X11DISPLAY *mod)
{
	TDBPRINTF(TDB_TRACE,("Device close\n"));
	TExecLock(mod->x11_ExecBase, mod->x11_Lock);
	if (--mod->x11_RefCount == 0)
		x11_exit(mod);
	TExecUnlock(mod->x11_ExecBase, mod->x11_Lock);
}

/*****************************************************************************/
/*
**	BeginIO/AbortIO
*/

static TMODAPI void
x11_beginio(X11DISPLAY *mod, struct TVRequest *req)
{
	TExecPutMsg(mod->x11_ExecBase, mod->x11_CmdPort,
		req->tvr_Req.io_ReplyPort, req);
	x11_wake(mod);
}

static TMODAPI TINT
x11_abortio(X11DISPLAY *mod, struct TVRequest *req)
{
	/* not supported: */
	return -1;
}

/*****************************************************************************/
/*
**	AllocReq/FreeReq
*/

static TMODAPI struct TVRequest *
x11_allocreq(X11DISPLAY *mod)
{
	struct TVRequest *req = TExecAllocMsg(mod->x11_ExecBase,
		sizeof(struct TVRequest));
	if (req)
		req->tvr_Req.io_Device = (struct TModule *) mod;
	return req;
}

static TMODAPI void
x11_freereq(X11DISPLAY *mod, struct TVRequest *req)
{
	TExecFree(mod->x11_ExecBase, req);
}
