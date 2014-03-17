
/*
**	display_win_mod.c - Windows display driver
**	Written by Timm S. Mueller <tmueller@schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

#include "display_win_mod.h"

static void fb_runinstance(TAPTR task);
static TBOOL fb_initinstance(TAPTR task);
static void fb_exitinstance(WINDISPLAY *inst);
static TAPTR fb_modopen(WINDISPLAY *mod, TTAGITEM *tags);
static void fb_modclose(WINDISPLAY *mod);
static TMODAPI void fb_beginio(WINDISPLAY *mod, struct TVRequest *req);
static TMODAPI TINT fb_abortio(WINDISPLAY *mod, struct TVRequest *req);
static TMODAPI struct TVRequest *fb_allocreq(WINDISPLAY *mod);
static TMODAPI void fb_freereq(WINDISPLAY *mod, struct TVRequest *req);
static void fb_docmd(WINDISPLAY *mod, struct TVRequest *req);
static LRESULT CALLBACK
win_wndproc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
static void fb_notifywindows(WINDISPLAY *mod);

static const TMFPTR
fb_vectors[FB_DISPLAY_NUMVECTORS] =
{
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,
	(TMFPTR) fb_beginio,
	(TMFPTR) fb_abortio,
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,
	(TMFPTR) TNULL,
	(TMFPTR) fb_allocreq,
	(TMFPTR) fb_freereq,
};

static void
fb_destroy(WINDISPLAY *mod)
{
	TDBPRINTF(TDB_TRACE,("Module destroy...\n"));
	TDestroy((struct THandle *) mod->fbd_Lock);
}

static THOOKENTRY TTAG
fb_dispatch(struct THook *hook, TAPTR obj, TTAG msg)
{
	WINDISPLAY *mod = (WINDISPLAY *) hook->thk_Data;
	switch (msg)
	{
		case TMSG_DESTROY:
			fb_destroy(mod);
			break;
		case TMSG_OPENMODULE:
			return (TTAG) fb_modopen(mod, obj);
		case TMSG_CLOSEMODULE:
			fb_modclose(obj);
			break;
		case TMSG_INITTASK:
			return fb_initinstance(obj);
		case TMSG_RUNTASK:
			fb_runinstance(obj);
			break;
	}
	return 0;
}

TMODENTRY TUINT
tek_init_display_windows(TAPTR task, struct TModule *vis, TUINT16 version,
	TTAGITEM *tags)
{
	WINDISPLAY *mod = (WINDISPLAY *) vis;

	if (mod == TNULL)
	{
		if (version == 0xffff)
			return sizeof(TAPTR) * FB_DISPLAY_NUMVECTORS;

		if (version <= FB_DISPLAY_VERSION)
			return sizeof(WINDISPLAY);

		return 0;
	}

	TDBPRINTF(TDB_TRACE,("Module init...\n"));

	for (;;)
	{
		struct TExecBase *TExecBase = TGetExecBase(mod);
		mod->fbd_ExecBase = TExecBase;
		mod->fbd_Lock = TCreateLock(TNULL);
		if (mod->fbd_Lock == TNULL) break;

		mod->fbd_Module.tmd_Version = FB_DISPLAY_VERSION;
		mod->fbd_Module.tmd_Revision = FB_DISPLAY_REVISION;
		mod->fbd_Module.tmd_Handle.thn_Hook.thk_Entry = fb_dispatch;
		mod->fbd_Module.tmd_Flags = TMODF_VECTORTABLE | TMODF_OPENCLOSE;
		TInitVectors(&mod->fbd_Module, fb_vectors, FB_DISPLAY_NUMVECTORS);
		return TTRUE;
	}
	fb_destroy(mod);

	return TFALSE;
}

/*****************************************************************************/
/*
**	Module open/close
*/

static TAPTR fb_modopen(WINDISPLAY *mod, TTAGITEM *tags)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	TBOOL success = TFALSE;
	TLock(mod->fbd_Lock);
	if (mod->fbd_RefCount == 0)
		success = fb_init(mod, tags);
	if (success)
		mod->fbd_RefCount++;
	TUnlock(mod->fbd_Lock);
	if (success)
		return mod;
	return TNULL;
}

static void
fb_modclose(WINDISPLAY *mod)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	TDBPRINTF(TDB_TRACE,("Device close\n"));
	TLock(mod->fbd_Lock);
	if (--mod->fbd_RefCount == 0)
		fb_exit(mod);
	TUnlock(mod->fbd_Lock);
}

/*****************************************************************************/
/*
**	BeginIO/AbortIO
*/

static TMODAPI void
fb_beginio(WINDISPLAY *mod, struct TVRequest *req)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	TPutMsg(mod->fbd_CmdPort, req->tvr_Req.io_ReplyPort, req);
}

static TMODAPI TINT
fb_abortio(WINDISPLAY *mod, struct TVRequest *req)
{
	return -1;
}

/*****************************************************************************/
/*
**	AllocReq/FreeReq
*/

static TMODAPI struct TVRequest *
fb_allocreq(WINDISPLAY *mod)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	struct TVRequest *req = TAllocMsg(sizeof(struct TVRequest));
	if (req)
		req->tvr_Req.io_Device = (struct TModule *) mod;
	return req;
}

static TMODAPI void
fb_freereq(WINDISPLAY *mod, struct TVRequest *req)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	TFree(req);
}

/*****************************************************************************/
/*
**	Module init/exit
*/

LOCAL TBOOL
fb_init(WINDISPLAY *mod, TTAGITEM *tags)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
// 	mod->fbd_OpenTags = tags;

	for (;;)
	{
		TTAGITEM tags[2];

		tags[0].tti_Tag = TTask_UserData;
		tags[0].tti_Value = (TTAG) mod;
		tags[1].tti_Tag = TTAG_DONE;

		mod->fbd_Task = TCreateTask(&mod->fbd_Module.tmd_Handle.thn_Hook,
			tags);
		if (mod->fbd_Task == TNULL) break;

		mod->fbd_CmdPort = TGetUserPort(mod->fbd_Task);
		mod->fbd_CmdPortSignal = TGetPortSignal(mod->fbd_CmdPort);

		return TTRUE;
	}

	fb_exit(mod);
	return TFALSE;
}

LOCAL void
fb_exit(WINDISPLAY *mod)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	if (mod->fbd_Task)
	{
		TSignal(mod->fbd_Task, TTASK_SIG_ABORT);
		TDestroy((struct THandle *) mod->fbd_Task);
	}
}

/*****************************************************************************/
/*
**	Device instance init/exit
*/

static TBOOL fb_initinstance(TAPTR task)
{
	struct TExecBase *TExecBase = TGetExecBase(task);
	WINDISPLAY *mod = TGetTaskData(task);

	for (;;)
	{
// 		TTAGITEM *opentags = mod->fbd_OpenTags;
		TTAGITEM ftags[3];
		WNDCLASSEX wclass, pclass;

		mod->fbd_HInst = GetModuleHandle(NULL);
		if (mod->fbd_HInst == TNULL)
			break;

		wclass.cbSize = sizeof(wclass);
		wclass.style = 0;
		wclass.lpfnWndProc = win_wndproc;
		wclass.cbClsExtra = 0;
		wclass.cbWndExtra = 0;
		wclass.hInstance = mod->fbd_HInst;
		wclass.hIcon = LoadIcon(NULL, IDI_APPLICATION);
		wclass.hCursor = LoadCursor(NULL, IDC_ARROW);
		wclass.hbrBackground = NULL;
		wclass.lpszMenuName = NULL;
		wclass.lpszClassName = FB_DISPLAY_CLASSNAME;
		wclass.hIconSm = NULL;
		mod->fbd_ClassAtom = RegisterClassEx(&wclass);
		if (mod->fbd_ClassAtom == 0)
			break;

		pclass.cbSize = sizeof(pclass);
		pclass.style = CS_NOCLOSE;
		pclass.lpfnWndProc = win_wndproc;
		pclass.cbClsExtra = 0;
		pclass.cbWndExtra = 0;
		pclass.hInstance = mod->fbd_HInst;
		pclass.hIcon = NULL;
		pclass.hCursor = LoadCursor(NULL, IDC_ARROW);
		pclass.hbrBackground = NULL;
		pclass.lpszMenuName = NULL;
		pclass.lpszClassName = FB_DISPLAY_CLASSNAME_POPUP;
		pclass.hIconSm = NULL;
		mod->fbd_ClassAtomPopup = RegisterClassEx(&pclass);
		if (mod->fbd_ClassAtomPopup == 0)
			break;

		/* Create invisible window for this device: */
		mod->fbd_DeviceHWnd = CreateWindowEx(0, FB_DISPLAY_CLASSNAME, NULL,
			0, 0, 0, 0, 0, (HWND) NULL, (HMENU) NULL, mod->fbd_HInst,
			(LPVOID) NULL);
		if (mod->fbd_DeviceHWnd == NULL)
			break;
		mod->fbd_DeviceHDC = GetDC(mod->fbd_DeviceHWnd);

		/* list of free input messages: */
		TInitList(&mod->fbd_IMsgPool);

		/* list of all open visuals: */
		TInitList(&mod->fbd_VisualList);

		/* init fontmanager and default font */
		TInitList(&mod->fbd_FontManager.openfonts);

		ftags[0].tti_Tag = TVisual_FontName;
		ftags[0].tti_Value = (TTAG) FNT_DEFNAME;
		ftags[1].tti_Tag = TVisual_FontPxSize;
		ftags[1].tti_Value = (TTAG) FNT_DEFPXSIZE;
		ftags[2].tti_Tag = TTAG_DONE;
		mod->fbd_FontManager.deffont = fb_hostopenfont(mod, ftags);
		if (mod->fbd_FontManager.deffont == TNULL) break;

		TDBPRINTF(TDB_TRACE,("Instance init successful\n"));
		return TTRUE;
	}

	fb_exitinstance(mod);
	return TFALSE;
}

static void
fb_exitinstance(WINDISPLAY *mod)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	struct TNode *imsg, *node, *next;

	/* free pooled input messages: */
	while ((imsg = TRemHead(&mod->fbd_IMsgPool)))
		TFree(imsg);

	/* free queued input messages in all open visuals: */
	node = mod->fbd_VisualList.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		WINWINDOW *v = (WINWINDOW *) node;

		/* unset active font in all open visuals */
		v->fbv_CurrentFont = TNULL;

		while ((imsg = TRemHead(&v->fbv_IMsgQueue)))
			TFree(imsg);
	}

	/* force closing of default font */
	mod->fbd_FontManager.defref = 0;

	/* close all fonts */
	node = mod->fbd_FontManager.openfonts.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
		fb_hostclosefont(mod, (TAPTR) node);

	if (mod->fbd_DeviceHWnd)
		DestroyWindow(mod->fbd_DeviceHWnd);

	if (mod->fbd_ClassAtom)
		UnregisterClass(FB_DISPLAY_CLASSNAME, mod->fbd_HInst);

	if (mod->fbd_ClassAtomPopup)
		UnregisterClass(FB_DISPLAY_CLASSNAME_POPUP, mod->fbd_HInst);
}

static void fb_runinstance(TAPTR task)
{
	struct TExecBase *TExecBase = TGetExecBase(task);
	WINDISPLAY *mod = TGetTaskData(task);
	struct TVRequest *req;
	TUINT sig;

	/* interval time: 1/50s: */
	TTIME intt = { 20000 };
	/* next absolute time to send interval message: */
	TTIME nextt;
	TTIME waitt, nowt;

	TGetSystemTime(&nextt);
	TAddTime(&nextt, &intt);

	TDBPRINTF(TDB_INFO,("Device instance running\n"));

	do
	{
		TBOOL do_interval = TFALSE;

		while ((req = TGetMsg(mod->fbd_CmdPort)))
		{
			fb_docmd(mod, req);
			TReplyMsg(req);
		}

		fb_notifywindows(mod);

		/* calculate new delta to wait: */
		TGetSystemTime(&nowt);
		waitt = nextt;
		TSubTime(&waitt, &nowt);

		TWaitTime(&waitt, mod->fbd_CmdPortSignal);

		/* check if time interval has expired: */
		TGetSystemTime(&nowt);
		if (TCmpTime(&nowt, &nextt) > 0)
		{
			/* expired; send interval: */
			do_interval = TTRUE;
			TAddTime(&nextt, &intt);
			if (TCmpTime(&nowt, &nextt) >= 0)
			{
				/* nexttime expired already; create new time from now: */
				nextt = nowt;
				TAddTime(&nextt, &intt);
			}
		}

		/* send out input messages: */
		fb_sendimessages(mod, do_interval);

		/* get signal state: */
		sig = TSetSignal(0, TTASK_SIG_ABORT);

	} while (!(sig & TTASK_SIG_ABORT));

	TDBPRINTF(TDB_INFO,("Device instance closedown\n"));
	fb_exitinstance(mod);
}

/*****************************************************************************/

static void
fb_docmd(WINDISPLAY *mod, struct TVRequest *req)
{
	switch (req->tvr_Req.io_Command)
	{
		case TVCMD_OPENWINDOW:
			fb_openwindow(mod, req);
			break;
		case TVCMD_CLOSEWINDOW:
			fb_closewindow(mod, req);
			break;
		case TVCMD_OPENFONT:
			fb_openfont(mod, req);
			break;
		case TVCMD_CLOSEFONT:
			fb_closefont(mod, req);
			break;
		case TVCMD_GETFONTATTRS:
			fb_getfontattrs(mod, req);
			break;
		case TVCMD_TEXTSIZE:
			fb_textsize(mod, req);
			break;
		case TVCMD_QUERYFONTS:
			fb_queryfonts(mod, req);
			break;
		case TVCMD_GETNEXTFONT:
			fb_getnextfont(mod, req);
			break;
		case TVCMD_SETINPUT:
			fb_setinput(mod, req);
			break;
		case TVCMD_GETATTRS:
			fb_getattrs(mod, req);
			break;
		case TVCMD_SETATTRS:
			fb_setattrs(mod, req);
			break;
		case TVCMD_ALLOCPEN:
			fb_allocpen(mod, req);
			break;
		case TVCMD_FREEPEN:
			fb_freepen(mod, req);
			break;
		case TVCMD_SETFONT:
			fb_setfont(mod, req);
			break;
		case TVCMD_CLEAR:
			fb_clear(mod, req);
			break;
		case TVCMD_RECT:
			fb_rect(mod, req);
			break;
		case TVCMD_FRECT:
			fb_frect(mod, req);
			break;
		case TVCMD_LINE:
			fb_line(mod, req);
			break;
		case TVCMD_PLOT:
			fb_plot(mod, req);
			break;
		case TVCMD_TEXT:
			fb_drawtext(mod, req);
			break;
		case TVCMD_DRAWSTRIP:
			fb_drawstrip(mod, req);
			break;
		case TVCMD_DRAWTAGS:
			fb_drawtags(mod, req);
			break;
		case TVCMD_DRAWFAN:
			fb_drawfan(mod, req);
			break;
		case TVCMD_COPYAREA:
			fb_copyarea(mod, req);
			break;
		case TVCMD_SETCLIPRECT:
			fb_setcliprect(mod, req);
			break;
		case TVCMD_UNSETCLIPRECT:
			fb_unsetcliprect(mod, req);
			break;
		case TVCMD_DRAWBUFFER:
			fb_drawbuffer(mod, req);
			break;
		default:
			TDBPRINTF(TDB_INFO,("Unknown command code: %08x\n",
			req->tvr_Req.io_Command));
	}
}

/*****************************************************************************/

LOCAL TBOOL
fb_getimsg(WINDISPLAY *mod, WINWINDOW *win, TIMSG **msgptr, TUINT type)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	TIMSG *msg;
	TBOOL res = TFALSE;

	TLock(mod->fbd_Lock);
	msg = (TIMSG *) TRemHead(&mod->fbd_IMsgPool);
	if (msg == TNULL)
		msg = TAllocMsg0(sizeof(TIMSG));
	if (msg)
	{
		msg->timsg_Instance = win;
		msg->timsg_UserData = win->fbv_UserData;
		msg->timsg_Type = type;
		msg->timsg_Qualifier = win->fbv_KeyQual;
		msg->timsg_MouseX = win->fbv_MouseX;
		msg->timsg_MouseY = win->fbv_MouseY;
		TGetSystemTime(&msg->timsg_TimeStamp);
		*msgptr = msg;
		res = TTRUE;
	}
	else
		*msgptr = TNULL;
	TUnlock(mod->fbd_Lock);
	return res;
}

static void fb_notifywindows(WINDISPLAY *mod)
{
	struct TNode *next, *node = mod->fbd_VisualList.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		WINWINDOW *v = (WINWINDOW *) node;
		if (v->fbv_Dirty)
		{
			/* force window processing: */
			/*GdiFlush();*/
			v->fbv_Dirty = TFALSE;
			PostMessage(v->fbv_HWnd, WM_USER, 0, 0);
		}
	}
}

LOCAL void fb_sendimessages(WINDISPLAY *mod, TBOOL do_interval)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	struct TNode *next, *node = mod->fbd_VisualList.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		WINWINDOW *v = (WINWINDOW *) node;
		TIMSG *imsg;

		if (do_interval && (v->fbv_InputMask & TITYPE_INTERVAL) &&
			fb_getimsg(mod, v, &imsg, TITYPE_INTERVAL))
			TPutMsg(v->fbv_IMsgPort, TNULL, imsg);

		while ((imsg = (TIMSG *) TRemHead(&v->fbv_IMsgQueue)))
			TPutMsg(v->fbv_IMsgPort, TNULL, imsg);
	}
}

LOCAL void fb_sendimsg(WINDISPLAY *mod, WINWINDOW *win, TIMSG *imsg)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	TPutMsg(win->fbv_IMsgPort, TNULL, imsg);
}

/*****************************************************************************/

static TBOOL getqualifier(WINDISPLAY *mod, WINWINDOW *win)
{
	TUINT quali = TKEYQ_NONE;
	TBOOL newquali;
	BYTE *keystate = win->fbv_KeyState;
	GetKeyboardState(keystate);
	if (keystate[VK_LSHIFT] & 0x80) quali |= TKEYQ_LSHIFT;
	if (keystate[VK_RSHIFT] & 0x80) quali |= TKEYQ_RSHIFT;
	if (keystate[VK_LCONTROL] & 0x80) quali |= TKEYQ_LCTRL;
	if (keystate[VK_RCONTROL] & 0x80) quali |= TKEYQ_RCTRL;
	if (keystate[VK_LMENU] & 0x80) quali |= TKEYQ_LALT;
	if (keystate[VK_RMENU] & 0x80) quali |= TKEYQ_RALT;
	/*if (keystate[VK_NUMLOCK] & 1) quali |= TKEYQ_NUMBLOCK;*/
	newquali = (win->fbv_KeyQual != quali);
	win->fbv_KeyQual = quali;
	return newquali;
}

static void processkey(WINDISPLAY *mod, WINWINDOW *win, TUINT type, TINT code)
{
	TIMSG *imsg;
	TINT numchars = 0;
	WCHAR buff[2];

	getqualifier(mod, win);

	switch (code)
	{
		case VK_LEFT:
			code = TKEYC_CRSRLEFT;
			break;
		case VK_UP:
			code = TKEYC_CRSRUP;
			break;
		case VK_RIGHT:
			code = TKEYC_CRSRRIGHT;
			break;
		case VK_DOWN:
			code = TKEYC_CRSRDOWN;
			break;

		case VK_ESCAPE:
			code = TKEYC_ESC;
			break;
		case VK_DELETE:
			code = TKEYC_DEL;
			break;
		case VK_BACK:
			code = TKEYC_BCKSPC;
			break;
		case VK_TAB:
			code = TKEYC_TAB;
			break;
		case VK_RETURN:
			code = TKEYC_RETURN;
			break;

		case VK_HELP:
			code = TKEYC_HELP;
			break;
		case VK_INSERT:
			code = TKEYC_INSERT;
			break;
		case VK_PRIOR:
			code = TKEYC_PAGEUP;
			break;
		case VK_NEXT:
			code = TKEYC_PAGEDOWN;
			break;
		case VK_HOME:
			code = TKEYC_POSONE;
			break;
		case VK_END:
			code = TKEYC_POSEND;
			break;
		case VK_PRINT:
			code = TKEYC_PRINT;
			break;
		case VK_SCROLL:
			code = TKEYC_SCROLL;
			break;
		case VK_PAUSE:
			code = TKEYC_PAUSE;
			break;
		case VK_DECIMAL:
			code = '.';
			imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
			break;
		case VK_ADD:
			code = '+';
			imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
			break;
		case VK_SUBTRACT:
			code = '-';
			imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
			break;
		case VK_MULTIPLY:
			code = '*';
			imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
			break;
		case VK_DIVIDE:
			code = '/';
			imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
			break;

		case VK_F1: case VK_F2: case VK_F3: case VK_F4:
		case VK_F5: case VK_F6: case VK_F7: case VK_F8:
		case VK_F9: case VK_F10: case VK_F11: case VK_F12:
			code = (TUINT) (code - VK_F1) + TKEYC_F1;
			break;
		default:
			numchars = ToUnicode(code, 0, win->fbv_KeyState,
				buff, 2, 0);
			if (numchars > 0)
				code = buff[0];
	}

	if ((win->fbv_InputMask & type) &&
		fb_getimsg(mod, win, &imsg, type))
	{
		ptrdiff_t len;
		imsg->timsg_Code = code;
		len = (ptrdiff_t)
			utf8encode(imsg->timsg_KeyCode, imsg->timsg_Code) -
			(ptrdiff_t) imsg->timsg_KeyCode;
		imsg->timsg_KeyCode[len] = 0;
		fb_sendimsg(mod, win, imsg);
	}
}

LOCAL void win_getminmax(WINWINDOW *win, TINT *pm1, TINT *pm2, TINT *pm3,
	TINT *pm4, TBOOL windowsize)
{
	TINT m1 = win->fbv_MinWidth;
	TINT m2 = win->fbv_MinHeight;
	TINT m3 = win->fbv_MaxWidth;
	TINT m4 = win->fbv_MaxHeight;
	m1 = TMAX(0, m1);
	m2 = TMAX(0, m2);
	m3 = m3 < 0 ? 1000000 : m3;
	m4 = m4 < 0 ? 1000000 : m4;
	m3 = TMAX(m3, m1);
	m4 = TMAX(m4, m2);
	if (windowsize)
	{
		m1 += win->fbv_BorderWidth;
		m2 += win->fbv_BorderHeight;
		m3 += win->fbv_BorderWidth;
		m4 += win->fbv_BorderHeight;
	}
	*pm1 = m1;
	*pm2 = m2;
	*pm3 = m3;
	*pm4 = m4;
}

static LRESULT CALLBACK
win_wndproc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	WINWINDOW *win = (WINWINDOW *) GetWindowLong(hwnd, GWL_USERDATA);
	WINDISPLAY *mod = win ? win->fbv_Display : TNULL;
	if (mod)
	{
		TIMSG *imsg;
		switch (uMsg)
		{
			default:
				TDBPRINTF(TDB_TRACE,("uMsg: %08x\n", uMsg));
				break;

			case WM_CLOSE:
				if ((win->fbv_InputMask & TITYPE_CLOSE) &&
					(fb_getimsg(mod, win, &imsg, TITYPE_CLOSE)))
					fb_sendimsg(mod, win, imsg);
				return 0;

			case WM_ERASEBKGND:
				return 0;

			case WM_GETMINMAXINFO:
			{
				LPMINMAXINFO mm = (LPMINMAXINFO) lParam;
				TINT m1, m2, m3, m4;
				win_getminmax(win, &m1, &m2, &m3, &m4, TTRUE);
				mm->ptMinTrackSize.x = m1;
				mm->ptMinTrackSize.y = m2;
				mm->ptMaxTrackSize.x = m3;
				mm->ptMaxTrackSize.y = m4;
				return 0;
			}

			case WM_PAINT:
			{
				PAINTSTRUCT ps;
				if (BeginPaint(win->fbv_HWnd, &ps))
				{
					if ((win->fbv_InputMask & TITYPE_REFRESH) &&
						(fb_getimsg(mod, win, &imsg, TITYPE_REFRESH)))
					{
						imsg->timsg_X = ps.rcPaint.left;
						imsg->timsg_Y = ps.rcPaint.top;
						imsg->timsg_Width = ps.rcPaint.right - ps.rcPaint.left;
						imsg->timsg_Height = ps.rcPaint.bottom - ps.rcPaint.top;
						TDBPRINTF(TDB_TRACE,("dirty: %d %d %d %d\n",
							imsg->timsg_X, imsg->timsg_Y, imsg->timsg_Width,
							imsg->timsg_Height));
						fb_sendimsg(mod, win, imsg);
					}
					EndPaint(win->fbv_HWnd, &ps);
				}
				return 0;
			}

			case WM_ACTIVATE:
				#if 0
				TDBPRINTF(TDB_INFO,("Window %p - Focus: %d\n", win, (LOWORD(wParam) != WA_INACTIVE)));
				if (!win->fbv_Borderless && (win->fbv_InputMask & TITYPE_FOCUS) &&
					(fb_getimsg(mod, win, &imsg, TITYPE_FOCUS)))
				{
					imsg->timsg_Code = (LOWORD(wParam) != WA_INACTIVE);
					fb_sendimsg(mod, win, imsg);
				}
				#endif
				return 0;

			case WM_SIZE:
				win->fbv_Width = LOWORD(lParam);
				win->fbv_Height = HIWORD(lParam);
				if ((win->fbv_InputMask & TITYPE_NEWSIZE) &&
					(fb_getimsg(mod, win, &imsg, TITYPE_NEWSIZE)))
				{
					imsg->timsg_Width = win->fbv_Width;
					imsg->timsg_Height = win->fbv_Height;
					fb_sendimsg(mod, win, imsg);
				}
				return 0;

			case WM_CAPTURECHANGED:
				TDBPRINTF(TDB_INFO,("Capture changed\n"));
				break;

			case WM_MOUSEMOVE:
			{
				TINT x = LOWORD(lParam);
				TINT y = HIWORD(lParam);
				win->fbv_MouseX = x;
				win->fbv_MouseY = y;
				if ((win->fbv_InputMask & TITYPE_MOUSEMOVE) &&
					(fb_getimsg(mod, win, &imsg, TITYPE_MOUSEMOVE)))
				{
					imsg->timsg_MouseX = x;
					imsg->timsg_MouseY = y;
					fb_sendimsg(mod, win, imsg);
				}

				if (win->fbv_InputMask & TITYPE_MOUSEOVER)
				{
					POINT scrpos;
					GetCursorPos(&scrpos);
	// 				TDBPRINTF(20,("in window: %d\n",
	// 					(WindowFromPoint(scrpos) == win->fbv_HWnd)));
					#if 0
					POINT scrpos;
					if (GetCapture() != win->fbv_HWnd)
					{
						SetCapture(win->fbv_HWnd);
						if (fb_getimsg(mod, win, &imsg, TITYPE_MOUSEOVER))
						{
							imsg->timsg_Code = 1;
							TDBPRINTF(20,("Mouseover=true\n"));
							fb_sendimsg(mod, win, imsg);
						}
					}
					else
					{
						POINT scrpos;
						GetCursorPos(&scrpos);
						if ((WindowFromPoint(scrpos) != win->fbv_HWnd) ||
							(x < 0) || (y < 0) || (x >= win->fbv_Width) ||
							(y >= win->fbv_Height))
						{
							ReleaseCapture();
							if (fb_getimsg(mod, win, &imsg, TITYPE_MOUSEOVER))
							{
								imsg->timsg_Code = 0;
								TDBPRINTF(20,("Mouseover=false\n"));
								fb_sendimsg(mod, win, imsg);
							}
						}
					}
					#endif
				}
				return 0;
			}

			case WM_LBUTTONDOWN:
				if ((win->fbv_InputMask & TITYPE_MOUSEBUTTON) &&
					fb_getimsg(mod, win, &imsg, TITYPE_MOUSEBUTTON))
				{
					imsg->timsg_Code = TMBCODE_LEFTDOWN;
					fb_sendimsg(mod, win, imsg);
				}
				return 0;
			case WM_LBUTTONUP:
				if ((win->fbv_InputMask & TITYPE_MOUSEBUTTON) &&
					fb_getimsg(mod, win, &imsg, TITYPE_MOUSEBUTTON))
				{
					imsg->timsg_Code = TMBCODE_LEFTUP;
					fb_sendimsg(mod, win, imsg);
				}
				return 0;
			case WM_RBUTTONDOWN:
				if ((win->fbv_InputMask & TITYPE_MOUSEBUTTON) &&
					fb_getimsg(mod, win, &imsg, TITYPE_MOUSEBUTTON))
				{
					imsg->timsg_Code = TMBCODE_RIGHTDOWN;
					fb_sendimsg(mod, win, imsg);
				}
				return 0;
			case WM_RBUTTONUP:
				if ((win->fbv_InputMask & TITYPE_MOUSEBUTTON) &&
					fb_getimsg(mod, win, &imsg, TITYPE_MOUSEBUTTON))
				{
					imsg->timsg_Code = TMBCODE_RIGHTUP;
					fb_sendimsg(mod, win, imsg);
				}
				return 0;
			case WM_MBUTTONDOWN:
				if ((win->fbv_InputMask & TITYPE_MOUSEBUTTON) &&
					fb_getimsg(mod, win, &imsg, TITYPE_MOUSEBUTTON))
				{
					imsg->timsg_Code = TMBCODE_MIDDLEDOWN;
					fb_sendimsg(mod, win, imsg);
				}
				return 0;
			case WM_MBUTTONUP:
				if ((win->fbv_InputMask & TITYPE_MOUSEBUTTON) &&
					fb_getimsg(mod, win, &imsg, TITYPE_MOUSEBUTTON))
				{
					imsg->timsg_Code = TMBCODE_MIDDLEUP;
					fb_sendimsg(mod, win, imsg);
				}
				return 0;

			case WM_SYSKEYDOWN:
				processkey(mod, win, TITYPE_KEYDOWN, 0);
				return 0;

			case WM_SYSKEYUP:
				processkey(mod, win, TITYPE_KEYUP, 0);
				return 0;

			case WM_KEYDOWN:
				processkey(mod, win, TITYPE_KEYDOWN, wParam);
				return 0;

			case WM_KEYUP:
				processkey(mod, win, TITYPE_KEYUP, wParam);
				return 0;

			case 0x020a:
				if (win->fbv_InputMask & TITYPE_MOUSEBUTTON)
				{
					TINT16 zdelta = (TINT16) HIWORD(wParam);
					if (zdelta != 0 &&
						fb_getimsg(mod, win, &imsg, TITYPE_MOUSEBUTTON))
					{
						imsg->timsg_Code = zdelta > 0 ?
							TMBCODE_WHEELUP : TMBCODE_WHEELDOWN;
						fb_sendimsg(mod, win, imsg);
					}
				}
				return 0;
		}
	}
	return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

/*****************************************************************************/
/*
**	convert an utf8 encoded string to latin-1
*/

LOCAL TSTRPTR fb_utf8tolatin(WINDISPLAY *mod, TSTRPTR utf8string, TINT utf8len,
	TINT *bytelen)
{
	TUINT8 *latin = (TUINT8 *) mod->fbd_utf8buffer;
	size_t len = utf8tolatin((const unsigned char *) utf8string, utf8len,
		latin, WIN_UTF8_BUFSIZE, 0xbf);
	if (bytelen)
		*bytelen = len;
	return (TSTRPTR) latin;
}
