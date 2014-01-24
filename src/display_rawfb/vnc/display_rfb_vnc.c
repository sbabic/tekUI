
/*
**	display_rfb_vnc.c - VNC extension to the raw buffer display driver
**	(C) 2013 by Timm S. Mueller <tmueller at schulze-mueller.de>
**
**	This module is written against LibVNCServer, which is a GPLv2 licensed
**	work. Distributing binary versions of your software based on tekUI with
**	VNC support makes your software a combined work with LibVNCServer, which
**	means that your software must comply to the terms of not only tekUI's
**	license, but also to the GPLv2. (Scripts being run on this combined work
**	should not be affected.)
*/

#include <rfb/keysym.h>
#include "display_rfb_mod.h"
#if defined(ENABLE_VNCSERVER_COPYRECT)
#include <sys/ioctl.h>
#endif

#define VNCSERVER_COPYRECT_MINPIXELS	10000

static RFBDISPLAY *g_mod;

/*****************************************************************************/

/*
**	Encode unicode char (31bit) to UTF-8 (up to 6 chars)
**	Reserve AT LEAST 6 bytes free space in the destination buffer
*/

static unsigned char *rfb_encodeutf8(unsigned char *buf, int c)
{
	if (c < 128)
	{
		*buf++ = c;
	}
	else if (c < 2048)
	{
		*buf++ = 0xc0 + (c >> 6);
		*buf++ = 0x80 + (c & 0x3f);
	}
	else if (c < 65536)
	{
		*buf++ = 0xe0 + (c >> 12);
		*buf++ = 0x80 + ((c & 0xfff) >> 6);
		*buf++ = 0x80 + (c & 0x3f);
	}
	else if (c < 2097152)
	{
		*buf++ = 0xf0 + (c >> 18);
		*buf++ = 0x80 + ((c & 0x3ffff) >> 12);
		*buf++ = 0x80 + ((c & 0xfff) >> 6);
		*buf++ = 0x80 + (c & 0x3f);
	}
	else if (c < 67108864)
	{
		*buf++ = 0xf8 + (c >> 24);
		*buf++ = 0x80 + ((c & 0xffffff) >> 18);
		*buf++ = 0x80 + ((c & 0x3ffff) >> 12);
		*buf++ = 0x80 + ((c & 0xfff) >> 6);
		*buf++ = 0x80 + (c & 0x3f);
	}
	else
	{
		*buf++ = 0xfc + (c >> 30);
		*buf++ = 0x80 + ((c & 0x3fffffff) >> 24);
		*buf++ = 0x80 + ((c & 0xffffff) >> 18);
		*buf++ = 0x80 + ((c & 0x3ffff) >> 12);
		*buf++ = 0x80 + ((c & 0xfff) >> 6);
		*buf++ = 0x80 + (c & 0x3f);
	}
	return buf;
}

/*****************************************************************************/

typedef struct 
{
	int oldbutton;
	int oldx, oldy;
} ClientData;

static void rfb_clientgone(rfbClientPtr cl)
{
	free(cl->clientData);
}

static enum rfbNewClientAction rfb_newclient(rfbClientPtr cl)
{
	cl->clientData = (void *) calloc(sizeof(ClientData), 1);
	cl->clientGoneHook = rfb_clientgone;
	return RFB_CLIENT_ACCEPT;
}

static int rfb_sendimsg(RFBDISPLAY *mod, RFBWINDOW *v,
	TINT x, TINT y, TUINT type, TUINT code)
{
	TIMSG *imsg;
	if (rfb_getimsg(mod, v, &imsg, type))
	{
		imsg->timsg_Code = code;
		imsg->timsg_Qualifier = mod->rfb_KeyQual;
		imsg->timsg_MouseX = x - v->rfbw_WinRect[0];
		imsg->timsg_MouseY = y - v->rfbw_WinRect[1];
		TExecPutMsg(mod->rfb_ExecBase, v->rfbw_IMsgPort, TNULL, imsg);
		return 1;
	}
	return 0;
}

static void rfb_doremoteptr(int buttonMask, int x, int y, rfbClientPtr cl)
{
	ClientData *cd = cl->clientData;
	RFBDISPLAY *mod = g_mod;
	TAPTR TExecBase = TGetExecBase(mod);
	RFBWINDOW *v;
	
	TLock(mod->rfb_InstanceLock);
	v = rfb_findcoord(mod, x, y);
	if (v)
	{
		int sent = 0;
		if (!(cd->oldbutton & 0x01) && (buttonMask & 0x01))
			sent += rfb_sendimsg(mod, v, x, y, TITYPE_MOUSEBUTTON, TMBCODE_LEFTDOWN);
		else if ((cd->oldbutton & 0x01) && !(buttonMask & 0x01))
			sent += rfb_sendimsg(mod, v, x, y, TITYPE_MOUSEBUTTON, TMBCODE_LEFTUP);
		if (!(cd->oldbutton & 0x02) && (buttonMask & 0x02))
			sent += rfb_sendimsg(mod, v, x, y, TITYPE_MOUSEBUTTON, TMBCODE_MIDDLEDOWN);
		else if ((cd->oldbutton & 0x02) && !(buttonMask & 0x02))
			sent += rfb_sendimsg(mod, v, x, y, TITYPE_MOUSEBUTTON, TMBCODE_MIDDLEUP);
		if (!(cd->oldbutton & 0x04) && (buttonMask & 0x04))
			sent += rfb_sendimsg(mod, v, x, y, TITYPE_MOUSEBUTTON, TMBCODE_RIGHTDOWN);
		else if ((cd->oldbutton & 0x04) && !(buttonMask & 0x04))
			sent += rfb_sendimsg(mod, v, x, y, TITYPE_MOUSEBUTTON, TMBCODE_RIGHTUP);
		if (buttonMask & 0x10)
			sent += rfb_sendimsg(mod, v, x, y, TITYPE_MOUSEBUTTON, TMBCODE_WHEELDOWN);
		if (buttonMask & 0x08)
			sent += rfb_sendimsg(mod, v, x, y, TITYPE_MOUSEBUTTON, TMBCODE_WHEELUP);
		if (sent == 0)
			rfb_sendimsg(mod, v, x, y, TITYPE_MOUSEMOVE, 0);
	}
	TUnlock(mod->rfb_InstanceLock);
	cd->oldbutton = buttonMask;
	rfbDefaultPtrAddEvent(buttonMask, x, y, cl);
}

static void rfb_doremotekey(rfbBool keydown, rfbKeySym keysym, rfbClientPtr cl)
{
	/*ClientData *cd = cl->clientData;*/
	RFBDISPLAY *mod = g_mod;
	TUINT evtype = 0;
	TUINT newqual;
	TUINT evmask = TITYPE_KEYDOWN | TITYPE_KEYUP;
	TBOOL newkey = TFALSE;
	
	switch (keysym)
	{
		case XK_Shift_L:
			newqual = TKEYQ_LSHIFT;
			break;
		case XK_Shift_R:
			newqual = TKEYQ_RSHIFT;
			break;
		case XK_Control_L:
			newqual = TKEYQ_LCTRL;
			break;
		case XK_Control_R:
			newqual = TKEYQ_RCTRL;
			break;
		case XK_Alt_L:
			newqual = TKEYQ_LALT;
			break;
		case XK_Alt_R:
			newqual = TKEYQ_RALT;
			break;
		default:
			newqual = 0;
	}

	if (newqual != 0)
	{
		if (keydown)
			mod->rfb_KeyQual |= newqual;
		else
			mod->rfb_KeyQual &= ~newqual;
	}

	if (keydown && (evmask & TITYPE_KEYDOWN))
		evtype = TITYPE_KEYDOWN;
	else if (!keydown && (evmask & TITYPE_KEYUP))
		evtype = TITYPE_KEYUP;

	if (evtype)
	{
		TUINT code;
		TUINT qual = mod->rfb_KeyQual;

		if (keysym >= XK_F1 && keysym <= XK_F12)
		{
			code = (TUINT) (keysym - XK_F1) + TKEYC_F1;
			newkey = TTRUE;
		}
		else if (keysym < 256)
		{
			/* cooked ASCII/Latin-1 code */
			code = keysym;
			newkey = TTRUE;
		}
		else if (keysym >= XK_KP_0 && keysym <= XK_KP_9)
		{
			code = (TUINT) (keysym - XK_KP_0) + 48;
			qual |= TKEYQ_NUMBLOCK;
			newkey = TTRUE;
		}
		else
		{
			newkey = TTRUE;
			switch (keysym)
			{
				case XK_Left:
					code = TKEYC_CRSRLEFT;
					break;
				case XK_Right:
					code = TKEYC_CRSRRIGHT;
					break;
				case XK_Up:
					code = TKEYC_CRSRUP;
					break;
				case XK_Down:
					code = TKEYC_CRSRDOWN;
					break;

				case XK_Escape:
					code = TKEYC_ESC;
					break;
				case XK_Delete:
					code = TKEYC_DEL;
					break;
				case XK_BackSpace:
					code = TKEYC_BCKSPC;
					break;
				case XK_ISO_Left_Tab:
				case XK_Tab:
					code = TKEYC_TAB;
					break;
				case XK_Return:
					code = TKEYC_RETURN;
					break;

				case XK_Help:
					code = TKEYC_HELP;
					break;
				case XK_Insert:
					code = TKEYC_INSERT;
					break;
				case XK_Page_Up:
					code = TKEYC_PAGEUP;
					break;
				case XK_Page_Down:
					code = TKEYC_PAGEDOWN;
					break;
				case XK_Home:
					code = TKEYC_POSONE;
					break;
				case XK_End:
					code = TKEYC_POSEND;
					break;
				case XK_Print:
					code = TKEYC_PRINT;
					break;
				case XK_Scroll_Lock:
					code = TKEYC_SCROLL;
					break;
				case XK_Pause:
					code = TKEYC_PAUSE;
					break;
				case XK_KP_Enter:
					code = TKEYC_RETURN;
					qual |= TKEYQ_NUMBLOCK;
					break;
				case XK_KP_Decimal:
					code = '.';
					qual |= TKEYQ_NUMBLOCK;
					break;
				case XK_KP_Add:
					code = '+';
					qual |= TKEYQ_NUMBLOCK;
					break;
				case XK_KP_Subtract:
					code = '-';
					qual |= TKEYQ_NUMBLOCK;
					break;
				case XK_KP_Multiply:
					code = '*';
					qual |= TKEYQ_NUMBLOCK;
					break;
				case XK_KP_Divide:
					code = '/';
					qual |= TKEYQ_NUMBLOCK;
					break;
				default:
					if (keysym > 31 && keysym <= 0x20ff)
						code = keysym;
					else if (keysym >= 0x01000100 && keysym <= 0x0110ffff)
						code = keysym - 0x01000000;
					else
						newkey = TFALSE;
					break;
			}
		}

		if (!newkey && newqual)
		{
			code = TKEYC_NONE;
			newkey = TTRUE;
		}

		if (newkey)
		{
			TAPTR TExecBase = TGetExecBase(mod);
			TIMSG *imsg;
			RFBWINDOW *v;
			TLock(mod->rfb_InstanceLock);
			v = (RFBWINDOW *) TFIRSTNODE(&mod->rfb_VisualList);
			if (rfb_getimsg(mod, v, &imsg, evtype))
			{
				ptrdiff_t len =
					(ptrdiff_t) rfb_encodeutf8(imsg->timsg_KeyCode, code) - 
					(ptrdiff_t) imsg->timsg_KeyCode;
				imsg->timsg_KeyCode[len] = 0;
				imsg->timsg_Code = code;
				imsg->timsg_Qualifier = qual;
				imsg->timsg_MouseX = mod->rfb_MouseX;
				imsg->timsg_MouseY = mod->rfb_MouseY;
				TPutMsg(v->rfbw_IMsgPort, TNULL, imsg);
			}
			TUnlock(mod->rfb_InstanceLock);
		}
	}
}

static void rfb_vnc_task(struct TTask *task)
{
	TAPTR TExecBase = TGetExecBase(task);
	RFBDISPLAY *mod = TGetTaskData(task);
	TBOOL waitsig = TFALSE;
	int extra_fd = mod->rfb_RFBPipeFD[0];
	FD_SET(extra_fd, &mod->rfb_RFBScreen->allFds);
	mod->rfb_RFBScreen->maxFd = TMAX(mod->rfb_RFBScreen->maxFd, extra_fd);

	while (!(TSetSignal(0, 0) & TTASK_SIG_ABORT))
	{
#if defined(ENABLE_VNCSERVER_COPYRECT)
		int res = rfbProcessEvents(mod->rfb_RFBScreen, 10000);
		int nbytes = 0;
		ioctl(extra_fd, FIONREAD, &nbytes);
		if (nbytes > 0)
		{
			char rdbuf;
			if (read(extra_fd, &rdbuf, 1) != 1)
				TDBPRINTF(TDB_ERROR,("error reading from signalfd\n"));
			waitsig = TTRUE;
		}
		if (res == 0 && waitsig)
		{
			TSignal(mod->rfb_RFBMainTask, mod->rfb_RFBReadySignal);
			waitsig = TFALSE;
		}
#else
		rfbProcessEvents(mod->rfb_RFBScreen, 20000);
#endif
	}
}

static THOOKENTRY TTAG rfb_vnc_dispatch(struct THook *hook,
	TAPTR obj, TTAG msg)
{
	switch (msg)
	{
		case TMSG_INITTASK:
			return TTRUE;
		case TMSG_RUNTASK:
			rfb_vnc_task(obj);
			break;
	}
	return 0;
}

/*****************************************************************************/

int rfb_vnc_init(RFBDISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TTAGITEM tags[2];
	struct THook dispatch;
	rfbScreenInfoPtr rfbScreen;
	
	mod->rfb_RFBPipeFD[0] = -1;
	
	for (;;)
	{
		if (pipe(mod->rfb_RFBPipeFD) == -1)
			break;
		mod->rfb_RFBReadySignal = TAllocSignal(0);
		if (mod->rfb_RFBReadySignal == 0)
			break;
		mod->rfb_RFBMainTask = TFindTask(TNULL);
		if (mod->rfb_RFBMainTask == TNULL)
			break;
		rfbScreen = rfbGetScreen(0, NULL, mod->rfb_Width, 
			mod->rfb_Height, RFB_BITS_PER_GUN, 3, sizeof(RFBPixel));
		if (rfbScreen == TNULL)
			break;
		
		g_mod = mod;
		mod->rfb_RFBScreen = rfbScreen;
		rfbScreen->alwaysShared = TRUE;
		rfbScreen->frameBuffer = (char *) mod->rfb_BufPtr;
		rfbScreen->ptrAddEvent = rfb_doremoteptr;
		rfbScreen->kbdAddEvent = rfb_doremotekey;
		rfbScreen->newClientHook = rfb_newclient;
#if defined(VNCSERVER_HTTP_PATH)
		rfbScreen->httpDir = VNCSERVER_HTTP_PATH;
#endif
		rfbInitServer(rfbScreen);
		rfbScreen->cursor = rfbMakeXCursor(1, 1, " ", " ");
		
		tags[0].tti_Tag = TTask_UserData;
		tags[0].tti_Value = (TTAG) mod;
		tags[1].tti_Tag = TTAG_DONE;
		TInitHook(&dispatch, rfb_vnc_dispatch, TNULL);
		mod->rfb_VNCTask = TCreateTask(&dispatch, tags);
		if (mod->rfb_VNCTask == TNULL)
			break;
		return 1;
	}
	
	rfb_vnc_exit(mod);
	return 0;
}

void rfb_vnc_exit(RFBDISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	if (mod->rfb_VNCTask)
	{
		TSignal(mod->rfb_VNCTask, TTASK_SIG_ABORT);
		TDestroy(mod->rfb_VNCTask);
	}
	if (mod->rfb_RFBScreen)
	{
		rfbShutdownServer(mod->rfb_RFBScreen, TRUE);
		rfbScreenCleanup(mod->rfb_RFBScreen);
		mod->rfb_RFBScreen = TNULL;
	}
	if (mod->rfb_RFBReadySignal)
	{
		TFreeSignal(mod->rfb_RFBReadySignal);
		mod->rfb_RFBReadySignal = 0;
	}
	if (mod->rfb_RFBPipeFD[0])
	{
		close(mod->rfb_RFBPipeFD[0]);
		close(mod->rfb_RFBPipeFD[1]);
		mod->rfb_RFBPipeFD[0] = -1;
	}
}

void rfb_vnc_flush(RFBDISPLAY *mod, struct Region *D)
{
	struct TNode *next, *node;
	sraRegionPtr region = sraRgnCreate();
	node = D->rg_Rects.rl_List.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		struct RectNode *rn = (struct RectNode *) node;
		sraRegionPtr rect = sraRgnCreateRect(rn->rn_Rect[0], rn->rn_Rect[1], 
			rn->rn_Rect[2] + 1, rn->rn_Rect[3] + 1);
		sraRgnOr(region, rect);
		sraRgnDestroy(rect);
	}
	rfbMarkRegionAsModified(mod->rfb_RFBScreen, region);
	sraRgnDestroy(region);
}

void rfb_vnc_copyrect(RFBDISPLAY *mod, RFBWINDOW *v, int dx, int dy, 
	int x0, int y0, int x1, int y1, int yinc)
{
	int i, y;
	int w = x1 - x0 + 1;
	int h = y1 - y0 + 1;
	int dy0 = y0;
	int dy1 = y1;
	if (yinc > 0)
	{
		int t = dy0;
		dy0 = dy1;
		dy1 = t;
	}

#if defined(ENABLE_VNCSERVER_COPYRECT)
	if (w * h > VNCSERVER_COPYRECT_MINPIXELS)
	{
		char wrbuf = 0;
		/* flush dirty rects */
		rfb_flush_clients(mod, TTRUE);
		/* break rfbProcessEvents */
		if (write(mod->rfb_RFBPipeFD[1], &wrbuf, 1) != 1)
			TDBPRINTF(TDB_ERROR,("error writing to signalfd\n"));
		/* wait for completion of rfbProcessEvents */
		TExecWait(mod->rfb_ExecBase, mod->rfb_RFBReadySignal);
		/* update own buffer */
		for (i = 0, y = dy0; i < h; ++i, y -= yinc)
			CopyLineOver(v, x0 - dx, y - dy, x0, y, w * sizeof(RFBPixel));
		/* schedule copyrect */
		rfbScheduleCopyRect(mod->rfb_RFBScreen, x0, y0, x1 + 1, y1 + 1,
			dx, dy);
	}
	else
#endif
	{
		/* update own buffer */
		for (i = 0, y = dy0; i < h; ++i, y -= yinc)
			CopyLineOver(v, x0 - dx, y - dy, x0, y, w * sizeof(RFBPixel));
		/* mark dirty */
		rfbMarkRectAsModified(mod->rfb_RFBScreen, x0, y0, x1 + 1, y1 + 1);
	}
}
