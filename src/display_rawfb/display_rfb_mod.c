
/*
**	display_rfb_mod.c - Raw framebuffer display driver
**	Written by Franciska Schulze <fschulze at schulze-mueller.de>
**	and Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

#include "display_rfb_mod.h"

#if defined(RFB_RENDER_DEVICE)
#define STRHELP(x) #x
#define STR(x) STRHELP(x)
#define SUBDEVICE_NAME "display_" STR(RFB_RENDER_DEVICE)
#else
#define SUBDEVICE_NAME TNULL
#endif

static void rfb_processevent(RFBDISPLAY *mod);

/*****************************************************************************/
/*
**	AllocReq/FreeReq
*/

static TMODAPI struct TVRequest *rfb_allocreq(RFBDISPLAY *mod)
{
	struct TVRequest *req = TExecAllocMsg(mod->rfb_ExecBase,
		sizeof(struct TVRequest));
	if (req)
		req->tvr_Req.io_Device = (struct TModule *) mod;
	return req;
}

static TMODAPI void rfb_freereq(RFBDISPLAY *mod, struct TVRequest *req)
{
	TExecFree(mod->rfb_ExecBase, req);
}

/*****************************************************************************/
/*
**	BeginIO/AbortIO
*/

static TMODAPI void rfb_beginio(RFBDISPLAY *mod, struct TVRequest *req)
{
	TExecPutMsg(mod->rfb_ExecBase, mod->rfb_CmdPort,
		req->tvr_Req.io_ReplyPort, req);
}

static TMODAPI TINT rfb_abortio(RFBDISPLAY *mod, struct TVRequest *req)
{
	return -1;
}

/*****************************************************************************/

static void rfb_docmd(RFBDISPLAY *mod, struct TVRequest *req)
{
	switch (req->tvr_Req.io_Command)
	{
		case TVCMD_OPENWINDOW: rfb_openvisual(mod, req); break;
		case TVCMD_CLOSEWINDOW: rfb_closevisual(mod, req); break;
		case TVCMD_OPENFONT: rfb_openfont(mod, req); break;
		case TVCMD_CLOSEFONT: rfb_closefont(mod, req); break;
		case TVCMD_GETFONTATTRS: rfb_getfontattrs(mod, req); break;
		case TVCMD_TEXTSIZE: rfb_textsize(mod, req); break;
		case TVCMD_QUERYFONTS: rfb_queryfonts(mod, req); break;
		case TVCMD_GETNEXTFONT: rfb_getnextfont(mod, req); break;
		case TVCMD_SETINPUT: rfb_setinput(mod, req); break;
		case TVCMD_GETATTRS: rfb_getattrs(mod, req); break;
		case TVCMD_SETATTRS: rfb_setattrs(mod, req); break;
		case TVCMD_ALLOCPEN: rfb_allocpen(mod, req); break;
		case TVCMD_FREEPEN: rfb_freepen(mod, req); break;
		case TVCMD_SETFONT: rfb_setfont(mod, req); break;
		case TVCMD_CLEAR: rfb_clear(mod, req); break;
		case TVCMD_RECT: rfb_rect(mod, req); break;
		case TVCMD_FRECT: rfb_frect(mod, req); break;
		case TVCMD_LINE: rfb_line(mod, req); break;
		case TVCMD_PLOT: rfb_plot(mod, req); break;
		case TVCMD_TEXT: rfb_drawtext(mod, req); break;
		case TVCMD_DRAWSTRIP: rfb_drawstrip(mod, req); break;
		case TVCMD_DRAWTAGS: rfb_drawtags(mod, req); break;
		case TVCMD_DRAWFAN: rfb_drawfan(mod, req); break;
		case TVCMD_COPYAREA: rfb_copyarea(mod, req); break;
		case TVCMD_SETCLIPRECT: rfb_setcliprect(mod, req); break;
		case TVCMD_UNSETCLIPRECT: rfb_unsetcliprect(mod, req); break;
		case TVCMD_DRAWBUFFER: rfb_drawbuffer(mod, req); break;
		case TVCMD_FLUSH: rfb_flush(mod, req); break;
		default:
			TDBPRINTF(TDB_ERROR,("Unknown command code: %d\n",
			req->tvr_Req.io_Command));
	}
}

/*****************************************************************************/

LOCAL TBOOL rfb_getimsg(RFBDISPLAY *mod, RFBWINDOW *v, TIMSG **msgptr, 
	TUINT type)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TIMSG *msg;
	
	TLock(mod->rfb_InstanceLock);
	msg = (TIMSG *) TRemHead(&mod->rfb_IMsgPool);
	TUnlock(mod->rfb_InstanceLock);
	if (msg == TNULL)
		msg = TAllocMsg(sizeof(TIMSG));
	*msgptr = msg;
	if (msg)
	{
		memset(msg, 0, sizeof(TIMSG));
		msg->timsg_Instance = v;
		msg->timsg_UserData = v->userdata;
		msg->timsg_Type = type;
		msg->timsg_Qualifier = mod->rfb_KeyQual;
		msg->timsg_MouseX = mod->rfb_MouseX;
		msg->timsg_MouseY = mod->rfb_MouseY;
		TGetSystemTime(&msg->timsg_TimeStamp);
		return TTRUE;
	}
	return TFALSE;
}

/*****************************************************************************/

static void rfb_exittask(RFBDISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	struct TNode *imsg, *node, *next;

	/* free pooled input messages: */
	while ((imsg = TRemHead(&mod->rfb_IMsgPool)))
		TFree(imsg);

	/* close all fonts */
	node = mod->rfb_FontManager.openfonts.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
		rfb_hostclosefont(mod, (TAPTR) node);

	if (mod->rfb_BufferOwner)
		TFree(mod->rfb_BufPtr);
	
	TDestroy(mod->rfb_RndIMsgPort);
	TFree(mod->rfb_RndRequest);
	TCloseModule(mod->rfb_RndDevice);
	TDestroy((struct THandle *) mod->rfb_RndRPort);
	TDestroy((struct THandle *) mod->rfb_InstanceLock);
	
	if (mod->rfb_DirtyRegion)
		rfb_region_destroy(&mod->rfb_RectPool, mod->rfb_DirtyRegion);
	
	rfb_region_destroypool(&mod->rfb_RectPool);
}

/*****************************************************************************/

static TBOOL rfb_inittask(struct TTask *task)
{
	TAPTR TExecBase = TGetExecBase(task);
	RFBDISPLAY *mod = TGetTaskData(task);

	for (;;)
	{
		TTAGITEM *opentags = mod->rfb_OpenTags;
		TSTRPTR subname;
		
		/* Initialize rectangle pool */
		rfb_region_initpool(&mod->rfb_RectPool, TExecBase);
		
		/* list of free input messages: */
		TInitList(&mod->rfb_IMsgPool);

		/* list of all open visuals: */
		TInitList(&mod->rfb_VisualList);

		/* init fontmanager and default font */
		TInitList(&mod->rfb_FontManager.openfonts);

		/* Instance lock (currently needed for async VNC) */
		mod->rfb_InstanceLock = TCreateLock(TNULL);
		if (mod->rfb_InstanceLock == TNULL)
			break;
		
		/* Open sub device, if one is requested: */
		subname = (TSTRPTR) TGetTag(opentags, TVisual_DriverName,
			(TTAG) SUBDEVICE_NAME);
		if (subname)
		{
			TTAGITEM subtags[2];
			subtags[0].tti_Tag = TVisual_IMsgPort;
			subtags[0].tti_Value = TGetTag(opentags, TVisual_IMsgPort, TNULL);
			subtags[1].tti_Tag = TTAG_DONE;
			
			mod->rfb_RndRPort = TCreatePort(TNULL);
			if (mod->rfb_RndRPort == TNULL)
				break;
			mod->rfb_RndDevice = TOpenModule(subname, 0, subtags);
			if (mod->rfb_RndDevice == TNULL)
				break;
			mod->rfb_RndRequest = TAllocMsg(sizeof(struct TVRequest));
			if (mod->rfb_RndRequest == TNULL)
				break;
			mod->rfb_RndIMsgPort = TCreatePort(TNULL);
			if (mod->rfb_RndIMsgPort == TNULL)
				break;
		}

		TDBPRINTF(TDB_TRACE,("Instance init successful\n"));
		return TTRUE;
	}

	rfb_exittask(mod);
	return TFALSE;
}

/* interval time: 1/50s: */
#define RAWFB_INTERVAL_MICROS	20000

static void rfb_runtask(struct TTask *task)
{
	TAPTR TExecBase = TGetExecBase(task);
	RFBDISPLAY *mod = TGetTaskData(task);
	struct TVRequest *req;
	TUINT sig;

	TTIME intt = { RAWFB_INTERVAL_MICROS };
	/* next absolute time to send interval message: */
	TTIME nextt;
	TTIME waitt, nowt;
	
	TAPTR cmdport = TGetUserPort(task);
	TUINT cmdportsignal = TGetPortSignal(cmdport);
	TUINT imsgportsignal = TGetPortSignal(mod->rfb_RndIMsgPort);
	
	TDBPRINTF(TDB_INFO,("RawFB device context running\n"));
	
	TGetSystemTime(&nowt);
	nextt = nowt;
	TAddTime(&nextt, &intt);
	
	do
	{
		/* process input messages: */
		rfb_processevent(mod);
		
		/* do draw commands: */
		while ((req = TGetMsg(cmdport)))
		{
			rfb_docmd(mod, req);
			TReplyMsg(req);
		}
		
		/* check if time interval has expired: */
		TGetSystemTime(&nowt);
		if (TCmpTime(&nowt, &nextt) > 0)
		{
			/* expired; send intervals: */
			TLock(mod->rfb_InstanceLock);
			
			struct TNode *next, *node = mod->rfb_VisualList.tlh_Head;
			for (; (next = node->tln_Succ); node = next)
			{
				RFBWINDOW *v = (RFBWINDOW *) node;
				TIMSG *imsg;
				if ((v->rfbw_InputMask & TITYPE_INTERVAL) &&
					rfb_getimsg(mod, v, &imsg, TITYPE_INTERVAL))
					TPutMsg(v->rfbw_IMsgPort, TNULL, imsg);
			}
			
			TUnlock(mod->rfb_InstanceLock);
			TAddTime(&nextt, &intt);
		}

		/* calculate new wait time: */
		waitt = nextt;
		TGetSystemTime(&nowt);
		TSubTime(&waitt, &nowt);
		
		if (waitt.tdt_Int64 <= 0 || waitt.tdt_Int64 > RAWFB_INTERVAL_MICROS)
		{
			/* something's wrong with the clock, recalculate */
			TDBPRINTF(TDB_INFO,("clock problem: %lld\n", waitt.tdt_Int64));
			nextt = nowt;
			TAddTime(&nextt, &intt);
			waitt = nextt;
			TSubTime(&waitt, &nowt);
		}
		
		sig = TWaitTime(&waitt, 
			cmdportsignal | imsgportsignal | TTASK_SIG_ABORT);
		
	} while (!(sig & TTASK_SIG_ABORT));
	
	TDBPRINTF(TDB_INFO,("RawFB device context closedown\n"));
	
	rfb_exittask(mod);
}

/*****************************************************************************/

LOCAL RFBWINDOW *rfb_findcoord(RFBDISPLAY *mod, TINT x, TINT y)
{
	struct TNode *next, *node = mod->rfb_VisualList.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		RFBWINDOW *v = (RFBWINDOW *) node;
		TINT *r = v->rfbw_WinRect;
		if (x >= r[0] && x <= r[2] && y >= r[1] && y <= r[3])
			return v;
	}
	return TNULL;
}

static TBOOL rfb_passevent(RFBDISPLAY *mod, RFBWINDOW *v, TIMSG *omsg)
{		
	TAPTR TExecBase = TGetExecBase(mod);
	TUINT type = omsg->timsg_Type;
	if (v && (v->rfbw_InputMask & type))
	{
		TIMSG *imsg;
		if (rfb_getimsg(mod, v, &imsg, omsg->timsg_Type))
		{
			TINT x = omsg->timsg_MouseX;
			TINT y = omsg->timsg_MouseY;
			imsg->timsg_Code = omsg->timsg_Code;
			imsg->timsg_Qualifier = omsg->timsg_Qualifier;
			imsg->timsg_MouseX = x - v->rfbw_WinRect[0];
			imsg->timsg_MouseY = y - v->rfbw_WinRect[1];
			memcpy(imsg->timsg_KeyCode, omsg->timsg_KeyCode, 8);
			TPutMsg(v->rfbw_IMsgPort, TNULL, imsg);
			return TTRUE;
		}
	}
	return TFALSE;
}

static RFBWINDOW *rfb_passevent_by_mousexy(RFBDISPLAY *mod, TIMSG *omsg, TBOOL focus)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TINT x = omsg->timsg_MouseX;
	TINT y = omsg->timsg_MouseY;
	TLock(mod->rfb_InstanceLock);
	RFBWINDOW *v = rfb_findcoord(mod, x, y);
	if (v)
	{
		if (focus)
			rfb_focuswindow(mod, v);
		rfb_passevent(mod, v, omsg);
	}
	TUnlock(mod->rfb_InstanceLock);
	return v;
}

static TBOOL rfb_passevent_to_focus(RFBDISPLAY *mod, TIMSG *omsg)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TBOOL sent = TFALSE;
	TLock(mod->rfb_InstanceLock);
	RFBWINDOW *v = mod->rfb_FocusWindow;
	if (v)
		sent = rfb_passevent(mod, v, omsg);
	TUnlock(mod->rfb_InstanceLock);
	return sent;
}

/*****************************************************************************/

static void rfb_processevent(RFBDISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TIMSG *msg;
	
	if (mod->rfb_RndIMsgPort == TNULL)
		return;

	while ((msg = TGetMsg(mod->rfb_RndIMsgPort)))
	{
		/*RFBWINDOW *v = (RFBWINDOW *) msg->timsg_Instance;*/
		TIMSG *imsg;
		
		switch (msg->timsg_Type)
		{
			case TITYPE_INTERVAL:
				TDBPRINTF(TDB_WARN,("unhandled event: INTERVAL\n"));
				break;
			case TITYPE_REFRESH:
			{
				TINT drect[4];
				drect[0] = msg->timsg_X;
				drect[1] = msg->timsg_Y;
				drect[2] = msg->timsg_X + msg->timsg_Width - 1;
				drect[3] = msg->timsg_Y + msg->timsg_Height - 1;
				rfb_damage(mod, drect, TNULL);
				break;
			}
			case TITYPE_NEWSIZE:
				TDBPRINTF(TDB_WARN,("unhandled event: NEWSIZE\n"));
				break;
				
			case TITYPE_CLOSE:
			{
				/* send to root window */
				TLock(mod->rfb_InstanceLock);
				RFBWINDOW *v = (RFBWINDOW *) TLASTNODE(&mod->rfb_VisualList);
				if (rfb_getimsg(mod, v, &imsg, TITYPE_CLOSE))
					TPutMsg(v->rfbw_IMsgPort, TNULL, imsg);
				TUnlock(mod->rfb_InstanceLock);
				break;
			}
			case TITYPE_FOCUS:
				TDBPRINTF(TDB_INFO,("unhandled event: FOCUS\n"));
				break;
			case TITYPE_MOUSEOVER:
				TDBPRINTF(TDB_INFO,("unhandled event: MOUSEOVER\n"));
				break;
				
			case TITYPE_KEYUP:
			case TITYPE_KEYDOWN:
				/* pass keyboard events to focused window, else to the
				 * hovered window (also setting the focus): */
				if (!rfb_passevent_to_focus(mod, msg))
					rfb_passevent_by_mousexy(mod, msg, TTRUE);
				break;

			case TITYPE_MOUSEMOVE:
				/* pass mouse movements to focused and hovered window: */
				if (rfb_passevent_by_mousexy(mod, msg, TFALSE) != 
					mod->rfb_FocusWindow)
					rfb_passevent_to_focus(mod, msg);
				break;
				
			case TITYPE_MOUSEBUTTON:
			{
				/* set focus on mousebutton down */
				TBOOL focus = msg->timsg_Code & (TMBCODE_LEFTDOWN | 
					TMBCODE_RIGHTDOWN | TMBCODE_MIDDLEDOWN);
				rfb_passevent_by_mousexy(mod, msg, focus);
				break;
			}
		}
		TReplyMsg(msg);
	}
}

/*****************************************************************************/
/*
**	Module init/exit
*/

static void rfb_exit(RFBDISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	if (mod->rfb_Task)
	{
		TSignal(mod->rfb_Task, TTASK_SIG_ABORT);
		TDestroy((struct THandle *) mod->rfb_Task);
	}
}

static TBOOL rfb_init(RFBDISPLAY *mod, TTAGITEM *tags)
{
	TAPTR TExecBase = TGetExecBase(mod);
	mod->rfb_OpenTags = tags;
	for (;;)
	{
		TTAGITEM tags[2];
		tags[0].tti_Tag = TTask_UserData;
		tags[0].tti_Value = (TTAG) mod;
		tags[1].tti_Tag = TTAG_DONE;
		mod->rfb_Task = 
			TCreateTask(&mod->rfb_Module.tmd_Handle.thn_Hook, tags);
		if (mod->rfb_Task == TNULL)
			break;
		mod->rfb_CmdPort = TGetUserPort(mod->rfb_Task);
		return TTRUE;
	}

	rfb_exit(mod);
	return TFALSE;
}

/*****************************************************************************/
/*
**	Module open/close
*/

static TAPTR rfb_modopen(RFBDISPLAY *mod, TTAGITEM *tags)
{
	TBOOL success = TFALSE;
	TExecLock(mod->rfb_ExecBase, mod->rfb_Lock);
	if (mod->rfb_RefCount == 0)
		success = rfb_init(mod, tags);
	if (success)
		mod->rfb_RefCount++;
	TExecUnlock(mod->rfb_ExecBase, mod->rfb_Lock);
	if (success)
		return mod;
	return TNULL;
}

static void rfb_modclose(RFBDISPLAY *mod)
{
	TExecLock(mod->rfb_ExecBase, mod->rfb_Lock);
	if (--mod->rfb_RefCount == 0)
		rfb_exit(mod);
	TExecUnlock(mod->rfb_ExecBase, mod->rfb_Lock);
}

static const TMFPTR rfb_vectors[RFB_DISPLAY_NUMVECTORS] =
{
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,
	(TMFPTR) rfb_beginio,
	(TMFPTR) rfb_abortio,
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,

	(TMFPTR) rfb_allocreq,
	(TMFPTR) rfb_freereq,
};

static void rfb_destroy(RFBDISPLAY *mod)
{
	TDestroy((struct THandle *) mod->rfb_Lock);
	if (mod->rfb_FTLibrary)
	{
		if (mod->rfb_FTCManager)
			FTC_Manager_Done(mod->rfb_FTCManager);
		FT_Done_FreeType(mod->rfb_FTLibrary);
	}
}

static THOOKENTRY TTAG rfb_dispatch(struct THook *hook, TAPTR obj, TTAG msg)
{
	RFBDISPLAY *mod = (RFBDISPLAY *) hook->thk_Data;
	switch (msg)
	{
		case TMSG_DESTROY:
			rfb_destroy(mod);
			break;
		case TMSG_OPENMODULE:
			return (TTAG) rfb_modopen(mod, obj);
		case TMSG_CLOSEMODULE:
			rfb_modclose(obj);
			break;
		case TMSG_INITTASK:
			return rfb_inittask(obj);
		case TMSG_RUNTASK:
			rfb_runtask(obj);
			break;
	}
	return 0;
}

TMODENTRY TUINT tek_init_display_rawfb(struct TTask *task, 
	struct TModule *vis, TUINT16 version, TTAGITEM *tags)
{
	RFBDISPLAY *mod = (RFBDISPLAY *) vis;

	if (mod == TNULL)
	{
		if (version == 0xffff)
			return sizeof(TAPTR) * RFB_DISPLAY_NUMVECTORS;

		if (version <= RFB_DISPLAY_VERSION)
			return sizeof(RFBDISPLAY);

		return 0;
	}

	for (;;)
	{
		TAPTR TExecBase = TGetExecBase(mod);
		
		if (FT_Init_FreeType(&mod->rfb_FTLibrary) != 0)
			break;
		if (FTC_Manager_New(mod->rfb_FTLibrary, 0, 0, 0, rfb_fontrequester, 
				NULL, &mod->rfb_FTCManager) != 0)
			break;
		if (FTC_CMapCache_New(mod->rfb_FTCManager, &mod->rfb_FTCCMapCache) 
			!= 0)
			break;
		if (FTC_SBitCache_New(mod->rfb_FTCManager, &mod->rfb_FTCSBitCache)
			!= 0)
			break;
		
		mod->rfb_ExecBase = TExecBase;
		mod->rfb_Lock = TCreateLock(TNULL);
		if (mod->rfb_Lock == TNULL)
			break;
		
		mod->rfb_Module.tmd_Version = RFB_DISPLAY_VERSION;
		mod->rfb_Module.tmd_Revision = RFB_DISPLAY_REVISION;
		mod->rfb_Module.tmd_Handle.thn_Hook.thk_Entry = rfb_dispatch;
		mod->rfb_Module.tmd_Flags = TMODF_VECTORTABLE | TMODF_OPENCLOSE;
		TInitVectors(&mod->rfb_Module, rfb_vectors, RFB_DISPLAY_NUMVECTORS);
		return TTRUE;
	}
	
	rfb_destroy(mod);
	return TFALSE;
}
