
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>
#include <sys/select.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <X11/cursorfont.h>
#if defined(ENABLE_X11_DGRAM)
#include <sys/socket.h>
#include <net/if.h>
#include <netinet/in.h>
#endif

#include "display_x11_mod.h"
#include <tek/inline/exec.h>

static void x11_exitinstance(X11DISPLAY *inst);
static void x11_processevent(X11DISPLAY *mod);
static TBOOL x11_processvisualevent(X11DISPLAY *mod, X11WINDOW *v,
	TAPTR msgstate, XEvent *ev);

#if defined(ENABLE_X11_STDIN)
/*****************************************************************************/
/*
**	File reader
*/

struct FileReader
{
	int File;
	size_t ReadBytes;
	char ReadBuf[256];
	int BufBytes;
	int BufPos;
 	int (*ReadCharFunc)(struct FileReader *, char c);
 	int (*ReadLineFunc)(struct FileReader *, char **line, size_t *len);
	char *Buffer;
	size_t Pos;
	size_t Size;
	size_t MaxLen;
	int State;
};

static int x11_readchar(struct FileReader *r, char c)
{
	if (r->State != 0)
		return 0;
	for (;;)
	{
		if (r->Pos >= r->Size)
		{
			char *nbuf;
			r->Size = r->Size ? r->Size << 1 : 32;
			if (r->Size > r->MaxLen)
			{
				/* length exceeded */
				r->State = 1;
				break;
			}
			nbuf = realloc(r->Buffer, r->Size);
			if (nbuf == NULL)
			{
				/* out of memory */
				r->State = 2;
				break;
			}
			r->Buffer = nbuf;
		}
		r->Buffer[r->Pos++] = c;
		return 1;
	}

	free(r->Buffer);
	r->Buffer = NULL;
	r->Size = 0;
	r->Pos = 0;
	return 0;
}

static int x11_readline(struct FileReader *r, char **line, size_t *len)
{
	int c;
	while (r->ReadBytes > 0 || r->BufBytes > 0)
	{
		if (r->BufBytes == 0)
		{
			int rdlen = TMIN(sizeof(r->ReadBuf), r->ReadBytes);
			rdlen = read(r->File, r->ReadBuf, rdlen);
			r->BufPos = 0;
			r->BufBytes = rdlen;
			r->ReadBytes -= rdlen;
		}
		c = r->ReadBuf[r->BufPos++];
		r->BufBytes--;
		if (c == '\r')
			continue;
		if (c == '\n')
		{
			if (r->State != 0)
			{
				r->State = 0;
				continue;
			}
			c = 0;
		}
		if ((*r->ReadCharFunc)(r, c) == 0)
			continue;

		if (c == 0)
		{
			*line = r->Buffer;
			*len = r->Pos;
			r->Pos = 0;
			return 1;
		}
	}
	return 0;
}

static int x11_reader_init(struct FileReader *r, int fd, size_t maxlen)
{
	r->File = fd;
	r->ReadBytes = 0;
	r->BufBytes = 0;
	r->BufPos = 0;
	r->MaxLen = maxlen;
	r->ReadCharFunc = x11_readchar;
	r->ReadLineFunc = x11_readline;
	r->Buffer = NULL;
	r->Pos = 0;
	r->Size = 0;
	r->State = 0;
	return 1;
}

static void x11_reader_exit(struct FileReader *r)
{
	free(r->Buffer);
}

static void x11_reader_addbytes(struct FileReader *r, int nbytes)
{
	r->ReadBytes += nbytes;
}

#endif

#if defined(ENABLE_X11_STDIN) || defined(ENABLE_X11_DGRAM)
static TBOOL 
getusermsg(X11DISPLAY *mod, TIMSG **msgptr, TUINT type, TSIZE size)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TIMSG *msg = TAllocMsg0(sizeof(TIMSG) + size);
	if (msg)
	{
		msg->timsg_ExtraSize = size;
		msg->timsg_Type = type;
		msg->timsg_Qualifier = mod->x11_KeyQual;
		msg->timsg_ScreenMouseX = mod->x11_MouseX;
		msg->timsg_ScreenMouseY = mod->x11_MouseY;
		TGetSystemTime(&msg->timsg_TimeStamp);
		*msgptr = msg;
		return TTRUE;
	}
	*msgptr = TNULL;
	return TFALSE;
}
#endif


/*****************************************************************************/
/*
**	Module init/exit
*/

static THOOKENTRY TTAG
x11_ireplyhookfunc(struct THook *hook, TAPTR obj, TTAG msg)
{
	X11DISPLAY *mod = hook->thk_Data;
	x11_wake(mod);
	return 0;
}

LOCAL TBOOL x11_init(X11DISPLAY *mod, TTAGITEM *tags)
{
	TAPTR TExecBase = TGetExecBase(mod);
	mod->x11_InitTags = tags;
	for (;;)
	{
		TTAGITEM tags[2];
		#if defined(ENABLE_X11_DGRAM)
		struct sockaddr_in addr;
		int reuse = 1;
		
		mod->x11_UserFD = socket(PF_INET, SOCK_DGRAM, 0);
		if (mod->x11_UserFD < 0)
			break;
		if (setsockopt(mod->x11_UserFD, SOL_SOCKET, SO_REUSEADDR, 
			(char*) &reuse, sizeof(reuse)) < 0)
			break;
		memset(&addr, 0, sizeof(struct sockaddr_in));
		addr.sin_family = AF_INET;
		addr.sin_addr.s_addr = htonl(0x7f000001);
		addr.sin_port = htons(20000);
		if (bind(mod->x11_UserFD, (struct sockaddr *) &addr, sizeof addr) < 0)
			break;
		#endif

		TInitHook(&mod->x11_IReplyHook, x11_ireplyhookfunc, mod);
		tags[0].tti_Tag = TMsgPort_Hook;
		tags[0].tti_Value = (TTAG) &mod->x11_IReplyHook;
		tags[1].tti_Tag = TTAG_DONE;
		mod->x11_IReplyPort = TCreatePort(tags);
		if (mod->x11_IReplyPort == TNULL)
			break;
		mod->x11_IReplyPortSignal = TGetPortSignal(mod->x11_IReplyPort);
		
		tags[0].tti_Tag = TTask_UserData;
		tags[0].tti_Value = (TTAG) mod;
		tags[1].tti_Tag = TTAG_DONE;
		mod->x11_Task =
			TCreateTask(&mod->x11_Module.tmd_Handle.thn_Hook, tags);
		if (mod->x11_Task == TNULL)
			break;

		mod->x11_CmdPort = TGetUserPort(mod->x11_Task);
		mod->x11_CmdPortSignal = TGetPortSignal(mod->x11_CmdPort);
		return TTRUE;
	}
	x11_exit(mod);
	return TFALSE;
}

LOCAL void x11_exit(X11DISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	if (mod->x11_Task)
	{
		TSignal(mod->x11_Task, TTASK_SIG_ABORT);
		x11_wake(mod);
		TDestroy(mod->x11_Task);
	}
	TDestroy(mod->x11_IReplyPort);
	
	#if defined(ENABLE_X11_DGRAM)
	if (mod->x11_UserFD != -1)
		close(mod->x11_UserFD);
	mod->x11_UserFD = -1;
	#endif
}

/*****************************************************************************/

static const TUINT8 endiancheck[4] = { 0x11,0x22,0x33,0x44 };

static TBOOL getprops(X11DISPLAY *inst)
{
	int major, minor, pixmap;
	int order = *(TUINT *) endiancheck == 0x11223344 ? MSBFirst : LSBFirst;
	TBOOL swap = ImageByteOrder(inst->x11_Display) != order;
	XWindowAttributes rootwa;
	
	inst->x11_ByteOrder = order;
	inst->x11_SwapByteOrder = swap;
	TDBPRINTF(20,("(msb=%d lsb=%d) order=%d swap=%d\n",
		MSBFirst, LSBFirst, order, swap));
	inst->x11_ShmAvail = (XShmQueryVersion(inst->x11_Display,
		&major, &minor, &pixmap) == True && major > 0);
	if (inst->x11_ShmAvail)
		inst->x11_ShmEvent = XShmGetEventBase(inst->x11_Display) +
			ShmCompletion;
	inst->x11_DefaultDepth = DefaultDepth(inst->x11_Display, inst->x11_Screen);
	switch (inst->x11_DefaultDepth)
	{
		case 24:
		case 32:
			inst->x11_DefaultBPP = 4;
			break;
		case 15:
		case 16:
		default:
			inst->x11_DefaultBPP = 2;
			break;
	}
	TDBPRINTF(TDB_INFO,("default depth: %d - bpp: %d\n",
		inst->x11_DefaultDepth, inst->x11_DefaultBPP));
	
	XGetWindowAttributes(inst->x11_Display,
		DefaultRootWindow(inst->x11_Display), &rootwa);
	inst->x11_ScreenWidth = WidthOfScreen(rootwa.screen);
	inst->x11_ScreenHeight = HeightOfScreen(rootwa.screen);
	
	return TTRUE;
}

/*****************************************************************************/

static void x11_createnullcursor(X11DISPLAY *mod)
{
	Pixmap cursormask;
	XGCValues xgc;
	GC gc;
	XColor dummycolour;
	Display *display = mod->x11_Display;
	Window root = XRootWindow(mod->x11_Display, mod->x11_Screen);
	cursormask = XCreatePixmap(display, root, 1, 1, 1);
	xgc.function = GXclear;
	gc = XCreateGC(display, cursormask, GCFunction, &xgc);
	XFillRectangle(display, cursormask, gc, 0, 0, 1, 1);
	memset(&dummycolour, 0, sizeof(XColor));
	dummycolour.flags = 7;
	mod->x11_NullCursor = XCreatePixmapCursor(display, cursormask, cursormask,
		&dummycolour, &dummycolour, 0, 0);
	#if defined(ENABLE_DEFAULTCURSOR)
	mod->x11_DefaultCursor = XCreateFontCursor(display, XC_left_ptr);
	#endif
	XFreePixmap(display, cursormask);
	XFreeGC(display, gc);
}

/*****************************************************************************/

LOCAL TBOOL x11_initinstance(struct TTask *task)
{
	X11DISPLAY *inst = TExecGetTaskData(TGetExecBase(task), task);

	for (;;)
	{
		TTAGITEM ftags[3];
		int pipefd[2];
		XRectangle rectangle;

		/* list of free input messages: */
		TInitList(&inst->x11_imsgpool);

		/* list of all open visuals: */
		TInitList(&inst->x11_vlist);

		/* init fontmanager and default font */
		TInitList(&inst->x11_fm.openfonts);

		inst->x11_fd_sigpipe_read = -1;
		inst->x11_fd_sigpipe_write = -1;

		inst->x11_Display = XOpenDisplay(NULL);
		if (inst->x11_Display == TNULL)
			break;
			
		inst->x11_XA_TARGETS = 
			XInternAtom(inst->x11_Display, "TARGETS", False);
		inst->x11_XA_PRIMARY = 
			XInternAtom(inst->x11_Display, "PRIMARY", False);
		inst->x11_XA_CLIPBOARD = 
			XInternAtom(inst->x11_Display, "CLIPBOARD", False);
		inst->x11_XA_UTF8_STRING = 
			XInternAtom(inst->x11_Display, "UTF8_STRING", False);
		inst->x11_XA_STRING = 
			XInternAtom(inst->x11_Display, "STRING", False);
		inst->x11_XA_COMPOUND_TEXT = 
			XInternAtom(inst->x11_Display, "COMPOUND_TEXT", False);

		XkbSetDetectableAutoRepeat(inst->x11_Display, TTRUE, TNULL);

		inst->x11_fd_display = ConnectionNumber(inst->x11_Display);
		inst->x11_Screen = DefaultScreen(inst->x11_Display);
		inst->x11_Visual = DefaultVisual(inst->x11_Display, inst->x11_Screen);

		if (getprops(inst) == TFALSE)
			break;

		if (pipe(pipefd) != 0)
			break;
		inst->x11_fd_sigpipe_read = pipefd[0];
		inst->x11_fd_sigpipe_write = pipefd[1];
		inst->x11_fd_max =
			TMAX(inst->x11_fd_sigpipe_read, inst->x11_fd_display) + 1;

		/* needed for unsetcliprect: */
		inst->x11_HugeRegion = XCreateRegion();
		rectangle.x = 0;
		rectangle.y = 0;
		rectangle.width = (unsigned short) 0xffff;
		rectangle.height = (unsigned short) 0xffff;
		XUnionRectWithRegion(&rectangle, inst->x11_HugeRegion,
			inst->x11_HugeRegion);

		x11_initlibxft(inst);
		
		ftags[0].tti_Tag = TVisual_FontName;
		ftags[0].tti_Value = (TTAG) FNT_DEFNAME;
		ftags[1].tti_Tag = TVisual_FontPxSize;
		ftags[1].tti_Value = (TTAG) FNT_DEFPXSIZE;
		ftags[2].tti_Tag = TTAG_DONE;

		inst->x11_fm.deffont = x11_hostopenfont(inst, ftags);
		/* if (inst->x11_fm.deffont == TNULL) break; */

		x11_createnullcursor(inst);

		inst->x11_IMsgPort = (struct TMsgPort *) TGetTag(inst->x11_InitTags,
			TVisual_IMsgPort, TNULL);

		TDBPRINTF(TDB_TRACE,("instance init successful\n"));
		return TTRUE;
	}

	x11_exitinstance(inst);

	return TFALSE;
}

static void x11_exitinstance(X11DISPLAY *inst)
{
	TAPTR TExecBase = TGetExecBase(inst);
	struct TNode *imsg, *node, *next;

	/* free pooled input messages: */
	while ((imsg = TRemHead(&inst->x11_imsgpool)))
		TFree(imsg);

	/* free queued input messages in all open visuals: */
	node = inst->x11_vlist.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		X11WINDOW *v = (X11WINDOW *) node;

		/* unset active font in all open visuals */
		v->curfont = TNULL;

		while ((imsg = TRemHead(&v->imsgqueue)))
			TFree(imsg);
	}

	/* force closing of default font */
	inst->x11_fm.defref = 0;

	/* close all fonts */
	node = inst->x11_fm.openfonts.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
		x11_hostclosefont(inst, (TAPTR) node);

	if (inst->x11_HugeRegion)
		XDestroyRegion(inst->x11_HugeRegion);

	if (inst->x11_fd_sigpipe_read != -1)
	{
		close(inst->x11_fd_sigpipe_read);
		close(inst->x11_fd_sigpipe_write);
	}

	if (inst->x11_Display)
		XCloseDisplay(inst->x11_Display);

	x11_exitlibxft(inst);
}

/*****************************************************************************/
/*
**	Task
*/

static void x11_docmd(X11DISPLAY *inst, struct TVRequest *req)
{
	switch (req->tvr_Req.io_Command)
	{
		case TVCMD_OPENWINDOW: x11_openvisual(inst, req); break;
		case TVCMD_CLOSEWINDOW: x11_closevisual(inst, req); break;
		case TVCMD_OPENFONT: x11_openfont(inst, req); break;
		case TVCMD_CLOSEFONT: x11_closefont(inst, req); break;
		case TVCMD_GETFONTATTRS: x11_getfontattrs(inst, req); break;
		case TVCMD_TEXTSIZE: x11_textsize(inst, req); break;
		case TVCMD_QUERYFONTS: x11_queryfonts(inst, req); break;
		case TVCMD_GETNEXTFONT: x11_getnextfont(inst, req); break;
		case TVCMD_SETINPUT: x11_setinput(inst, req); break;
		case TVCMD_GETATTRS: x11_getattrs(inst, req); break;
		case TVCMD_SETATTRS: x11_setattrs(inst, req); break;
		case TVCMD_ALLOCPEN: x11_allocpen(inst, req); break;
		case TVCMD_FREEPEN: x11_freepen(inst, req); break;
		case TVCMD_SETFONT: x11_setfont(inst, req); break;
		case TVCMD_CLEAR: x11_clear(inst, req); break;
		case TVCMD_RECT: x11_rect(inst, req); break;
		case TVCMD_FRECT: x11_frect(inst, req); break;
		case TVCMD_LINE: x11_line(inst, req); break;
		case TVCMD_PLOT: x11_plot(inst, req); break;
		case TVCMD_TEXT: x11_drawtext(inst, req); break;
		case TVCMD_DRAWSTRIP: x11_drawstrip(inst, req); break;
		case TVCMD_DRAWTAGS: x11_drawtags(inst, req); break;
		case TVCMD_DRAWFAN: x11_drawfan(inst, req); break;
		case TVCMD_COPYAREA: x11_copyarea(inst, req); break;
		case TVCMD_SETCLIPRECT: x11_setcliprect(inst, req); break;
		case TVCMD_UNSETCLIPRECT: x11_unsetcliprect(inst, req); break;
		case TVCMD_DRAWBUFFER: x11_drawbuffer(inst, req); break;
		case TVCMD_GETSELECTION: x11_getselection(inst, req); break;
		case TVCMD_FLUSH: XFlush(inst->x11_Display); break;
		default:
			TDBPRINTF(TDB_ERROR,("Unknown command code: %d\n",
			req->tvr_Req.io_Command));
	}
}

LOCAL void x11_taskfunc(struct TTask *task)
{
	TAPTR TExecBase = TGetExecBase(task);
	X11DISPLAY *inst = TGetTaskData(task);
	TUINT sig;
	fd_set rset;
	struct TVRequest *req;
	TIMSG *imsg;
	char buf[256];
	struct timeval tv;

	/* interval time: 1/50s: */
	TTIME intt = { 20000 };

	/* next absolute time to send interval message: */
	TTIME nextt;
	TTIME waitt, nowt;

	#if defined(ENABLE_X11_STDIN)
	int fd_in = STDIN_FILENO;
	struct FileReader fr;
	x11_reader_init(&fr, fd_in, 2048);
	#endif
	#if defined(ENABLE_X11_DGRAM)
	int fd_in = inst->x11_UserFD;
	#endif

	TGetSystemTime(&nextt);
	TAddTime(&nextt, &intt);

	TDBPRINTF(TDB_INFO,("Device instance running\n"));

	do
	{
		TBOOL do_interval = TFALSE;
		
		while ((imsg = TGetMsg(inst->x11_IReplyPort)))
		{
			/* returned input message */
			if (imsg->timsg_Type == TITYPE_REQSELECTION)
			{
				XSelectionEvent *reply = 
					(XSelectionEvent *) imsg->timsg_Requestor;
				struct TTagItem *replytags = 
					(struct TTagItem *) imsg->timsg_ReplyData;
				size_t len =
					TGetTag(replytags, TIMsgReply_UTF8SelectionLen, 0);
				TUINT8 *xdata = (TUINT8 *) TGetTag(replytags, 
					TIMsgReply_UTF8Selection, TNULL);
				XChangeProperty(inst->x11_Display, reply->requestor,
	      	        reply->property, XA_ATOM, 8, PropModeReplace, 
        	        (unsigned char *) xdata, len);
				XSendEvent(inst->x11_Display, reply->requestor, 0, 
					NoEventMask, (XEvent *) reply);
				XSync(inst->x11_Display, False);
				TFree((TAPTR) imsg->timsg_Requestor);
				TFree(xdata);
				/* reqselect roundtrip ended */
			}
			TFree(imsg);
		}

		while (inst->x11_RequestInProgress == TNULL &&
			(req = TGetMsg(inst->x11_CmdPort)))
		{
			x11_docmd(inst, req);
			if (inst->x11_RequestInProgress)
				break;
			TReplyMsg(req);
		}

		XFlush(inst->x11_Display);

		FD_ZERO(&rset);
		#if defined(ENABLE_X11_STDIN) || defined(ENABLE_X11_DGRAM)
		if (fd_in >= 0)
			FD_SET(fd_in, &rset);
		#endif
		FD_SET(inst->x11_fd_display, &rset);
		FD_SET(inst->x11_fd_sigpipe_read, &rset);

		/* calculate new delta to wait: */
		TGetSystemTime(&nowt);
		waitt = nextt;
		TSubTime(&waitt, &nowt);

		tv.tv_sec = waitt.tdt_Int64 / 1000000;
		if (tv.tv_sec != 0)
		{
			/* something's wrong with the clock, recalculate waittime */
			nextt = nowt;
			waitt = nextt;
			TSubTime(&waitt, &nowt);
			tv.tv_sec = waitt.tdt_Int64 / 1000000;
		}
		tv.tv_usec = waitt.tdt_Int64 % 1000000;

		/* wait for display, signal fd and timeout: */
		if (select(inst->x11_fd_max, &rset, NULL, NULL, &tv) > 0)
		{
			int nbytes;

			/* consume signal: */
			if (FD_ISSET(inst->x11_fd_sigpipe_read, &rset))
			{
				ioctl(inst->x11_fd_sigpipe_read, FIONREAD, &nbytes);
				if (nbytes > 0)
					if (read(inst->x11_fd_sigpipe_read, buf,
						TMIN(sizeof(buf), (size_t) nbytes)) != nbytes)
					TDBPRINTF(TDB_ERROR,("could not read wakeup signal\n"));
			}

			#if defined(ENABLE_X11_STDIN)
			/* stdin line reader: */
			if (fd_in >= 0 && FD_ISSET(fd_in, &rset))
			{
				if (ioctl(fd_in, FIONREAD, &nbytes) == 0)
				{
					if (nbytes == 0)
						fd_in = -1; /* stop processing */
					else
					{
						char *line;
						size_t len;
						x11_reader_addbytes(&fr, nbytes);
						while (x11_readline(&fr, &line, &len))
						{
							if (inst->x11_IMsgPort &&
								getusermsg(inst, &imsg, TITYPE_USER, len))
							{
								memcpy((void *) (imsg + 1), line, len);
								TPutMsg(inst->x11_IMsgPort, TNULL,
									&imsg->timsg_Node);
							}
						}
					}
				}
				else
					fd_in = -1; /* stop processing */
			}
			#elif defined(ENABLE_X11_DGRAM)
			/* dgram server: */
			if (fd_in >= 0 && FD_ISSET(fd_in, &rset))
			{
				char umsg[1024];
				TIMSG *imsg;
				ssize_t len = recv(fd_in, umsg, sizeof umsg, 0);
				if (len >= 0 && inst->x11_IMsgPort &&
					getusermsg(inst, &imsg, TITYPE_USER, len))
				{
					memcpy((void *) (imsg + 1), umsg, len);
					TPutMsg(inst->x11_IMsgPort, TNULL,
						&imsg->timsg_Node);
				}
			}
			#endif
		}

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

		/* process input messages: */
		x11_processevent(inst);

		/* send out input messages to owners: */
		x11_sendimessages(inst, do_interval);

		/* get signal state: */
		sig = TSetSignal(0, TTASK_SIG_ABORT);

	} while (!(sig & TTASK_SIG_ABORT));

	TDBPRINTF(TDB_INFO,("Device instance closedown\n"));

	#if defined(ENABLE_X11_STDIN)
	x11_reader_exit(&fr);
	#endif

	/* closedown: */
	x11_exitinstance(inst);
}

LOCAL void x11_wake(X11DISPLAY *inst)
{
	char sig = 0;
	if (write(inst->x11_fd_sigpipe_write, &sig, 1) != 1)
		TDBPRINTF(TDB_ERROR,("could not send wakeup signal\n"));
}

/*****************************************************************************/
/*
**	ProcessEvents
*/

static void x11_processevent(X11DISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	struct TNode *next, *node;
	XEvent ev;
	X11WINDOW *v;
	Window w;

	while ((XPending(mod->x11_Display)) > 0)
	{
		XNextEvent(mod->x11_Display, &ev);
		if (ev.type == mod->x11_ShmEvent)
		{
			if (mod->x11_RequestInProgress)
			{
				TReplyMsg(mod->x11_RequestInProgress);
				mod->x11_RequestInProgress = TNULL;
				TDBPRINTF(TDB_TRACE,("Released request (ShmEvent)\n"));
			}
			else
				TDBPRINTF(TDB_ERROR,("shm event while no request pending\n"));
			continue;
		}

		/* lookup window: */
		w = ((XAnyEvent *) &ev)->window;
		v = TNULL;
		node = mod->x11_vlist.tlh_Head;
		for (; (next = node->tln_Succ); node = next)
		{
			v = (X11WINDOW *) node;
			if (v->window == w)
				break;
			v = TNULL;
		}

		if (v == TNULL)
		{
			TDBPRINTF(TDB_INFO,
				("Message Type %04x from unknown window: %p\n", ev.type, w));
			continue;
		}

		/* while true, spool out messages for this particular event: */
		while (x11_processvisualevent(mod, v, TNULL, &ev));
	}
}

static TBOOL getimsg(X11DISPLAY *mod, X11WINDOW *v, TIMSG **msgptr, TUINT type)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TIMSG *msg = (TIMSG *) TRemHead(&mod->x11_imsgpool);
	if (msg == TNULL)
		msg = TAllocMsg0(sizeof(TIMSG));
	if (msg)
	{
		msg->timsg_Instance = v;
		msg->timsg_UserData = v->userdata;
		msg->timsg_Type = type;
		msg->timsg_Qualifier = mod->x11_KeyQual;
		msg->timsg_ScreenMouseX = mod->x11_ScreenMouseX;
		msg->timsg_ScreenMouseY = mod->x11_ScreenMouseY;
		msg->timsg_MouseX = v->mousex;
		msg->timsg_MouseY = v->mousey;
		TGetSystemTime(&msg->timsg_TimeStamp);
		*msgptr = msg;
		return TTRUE;
	}
	*msgptr = TNULL;
	return TFALSE;
}

static void setmousepos(X11DISPLAY *mod, X11WINDOW *v, TINT x, TINT y)
{
	v->mousex = x;
	v->mousey = y;
	mod->x11_ScreenMouseX = x + v->winleft;
	mod->x11_ScreenMouseY = y + v->wintop;
}


static TBOOL processkey(X11DISPLAY *mod, X11WINDOW *v, XKeyEvent *ev,
	TBOOL keydown)
{
	KeySym keysym;
	XComposeStatus compose;
	char buffer[10];

	TIMSG *imsg;
	TUINT evtype = 0;
	TUINT newqual;
	TUINT evmask = v->eventmask;
	TBOOL newkey = TFALSE;
	
	setmousepos(mod, v, ev->x, ev->y);

	XLookupString(ev, buffer, 10, &keysym, &compose);

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
			mod->x11_KeyQual |= newqual;
		else
			mod->x11_KeyQual &= ~newqual;
	}

	if (keydown && (evmask & TITYPE_KEYDOWN))
		evtype = TITYPE_KEYDOWN;
	else if (!keydown && (evmask & TITYPE_KEYUP))
		evtype = TITYPE_KEYUP;

	if (evtype && getimsg(mod, v, &imsg, evtype))
	{
		imsg->timsg_Qualifier = mod->x11_KeyQual;

		if (keysym >= XK_F1 && keysym <= XK_F12)
		{
			imsg->timsg_Code = (TUINT) (keysym - XK_F1) + TKEYC_F1;
			newkey = TTRUE;
		}
		else if (keysym < 256)
		{
			/* cooked ASCII/Latin-1 code */
			imsg->timsg_Code = keysym;
			newkey = TTRUE;
		}
		else if (keysym >= XK_KP_0 && keysym <= XK_KP_9)
		{
			imsg->timsg_Code = (TUINT) (keysym - XK_KP_0) + 48;
			imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
			newkey = TTRUE;
		}
		else
		{
			newkey = TTRUE;
			switch (keysym)
			{
				case XK_Left:
					imsg->timsg_Code = TKEYC_CRSRLEFT;
					break;
				case XK_Right:
					imsg->timsg_Code = TKEYC_CRSRRIGHT;
					break;
				case XK_Up:
					imsg->timsg_Code = TKEYC_CRSRUP;
					break;
				case XK_Down:
					imsg->timsg_Code = TKEYC_CRSRDOWN;
					break;

				case XK_Escape:
					imsg->timsg_Code = TKEYC_ESC;
					break;
				case XK_Delete:
					imsg->timsg_Code = TKEYC_DEL;
					break;
				case XK_BackSpace:
					imsg->timsg_Code = TKEYC_BCKSPC;
					break;
				case XK_ISO_Left_Tab:
				case XK_Tab:
					imsg->timsg_Code = TKEYC_TAB;
					break;
				case XK_Return:
					imsg->timsg_Code = TKEYC_RETURN;
					break;

				case XK_Help:
					imsg->timsg_Code = TKEYC_HELP;
					break;
				case XK_Insert:
					imsg->timsg_Code = TKEYC_INSERT;
					break;
				case XK_Page_Up:
					imsg->timsg_Code = TKEYC_PAGEUP;
					break;
				case XK_Page_Down:
					imsg->timsg_Code = TKEYC_PAGEDOWN;
					break;
				case XK_Home:
					imsg->timsg_Code = TKEYC_POSONE;
					break;
				case XK_End:
					imsg->timsg_Code = TKEYC_POSEND;
					break;
				case XK_Print:
					imsg->timsg_Code = TKEYC_PRINT;
					break;
				case XK_Scroll_Lock:
					imsg->timsg_Code = TKEYC_SCROLL;
					break;
				case XK_Pause:
					imsg->timsg_Code = TKEYC_PAUSE;
					break;
				case XK_KP_Enter:
					imsg->timsg_Code = TKEYC_RETURN;
					imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
					break;
				case XK_KP_Decimal:
					imsg->timsg_Code = '.';
					imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
					break;
				case XK_KP_Add:
					imsg->timsg_Code = '+';
					imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
					break;
				case XK_KP_Subtract:
					imsg->timsg_Code = '-';
					imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
					break;
				case XK_KP_Multiply:
					imsg->timsg_Code = '*';
					imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
					break;
				case XK_KP_Divide:
					imsg->timsg_Code = '/';
					imsg->timsg_Qualifier |= TKEYQ_NUMBLOCK;
					break;
				default:
					if (keysym > 31 && keysym <= 0x20ff)
						imsg->timsg_Code = keysym;
					else if (keysym >= 0x01000100 && keysym <= 0x0110ffff)
						imsg->timsg_Code = keysym - 0x01000000;
					else
						newkey = TFALSE;
					break;
			}
		}

		if (!newkey && newqual)
		{
			imsg->timsg_Code = TKEYC_NONE;
			newkey = TTRUE;
		}

		if (newkey)
		{
			ptrdiff_t len =
				(ptrdiff_t) utf8encode(imsg->timsg_KeyCode, imsg->timsg_Code) -
				(ptrdiff_t) imsg->timsg_KeyCode;
			imsg->timsg_KeyCode[len] = 0;
			TAddTail(&v->imsgqueue, &imsg->timsg_Node);
		}
		else
		{
			/* put back message: */
			TAddTail(&mod->x11_imsgpool, &imsg->timsg_Node);
		}
	}

	return newkey;
}

static TBOOL x11_processvisualevent(X11DISPLAY *mod, X11WINDOW *v,
	TAPTR msgstate, XEvent *ev)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TIMSG *imsg;

	switch (ev->type)
	{
		case ClientMessage:
			if ((v->eventmask & TITYPE_CLOSE) &&
				(Atom) ev->xclient.data.l[0] == v->atom_wm_delete_win)
			{
				if (getimsg(mod, v, &imsg, TITYPE_CLOSE))
					TAddTail(&v->imsgqueue, &imsg->timsg_Node);
			}
			break;

		case ConfigureNotify:
			if (mod->x11_RequestInProgress && v->waitforresize)
			{
				TReplyMsg(mod->x11_RequestInProgress);
				mod->x11_RequestInProgress = TNULL;
				v->waitforresize = TFALSE;
				TDBPRINTF(TDB_INFO,("Released request (ConfigureNotify)\n"));
			}
			
			v->winleft = ev->xconfigure.x;
			v->wintop = ev->xconfigure.y;
			
			if ((v->winwidth != ev->xconfigure.width ||
				v->winheight != ev->xconfigure.height))
			{
				v->waitforexpose = TTRUE;
				v->winwidth = ev->xconfigure.width;
				v->winheight = ev->xconfigure.height;
				if (v->eventmask & TITYPE_NEWSIZE)
				{
					if (getimsg(mod, v, &imsg, TITYPE_NEWSIZE))
					{
						imsg->timsg_Width = v->winwidth;
						imsg->timsg_Height = v->winheight;
						TAddTail(&v->imsgqueue, &imsg->timsg_Node);
					}
					TDBPRINTF(TDB_TRACE,("Configure: NEWSIZE: %d %d\n",
						v->winwidth, v->winheight));
				}
			}
			break;

		case EnterNotify:
		case LeaveNotify:
			if (v->eventmask & TITYPE_MOUSEOVER)
			{
				if (getimsg(mod, v, &imsg, TITYPE_MOUSEOVER))
				{
					imsg->timsg_Code = (ev->type == EnterNotify);
					TAddTail(&v->imsgqueue, &imsg->timsg_Node);
				}
			}
			break;

		case MapNotify:
			if (mod->x11_RequestInProgress)
			{
				TReplyMsg(mod->x11_RequestInProgress);
				mod->x11_RequestInProgress = TNULL;
				v->waitforexpose = TFALSE;
				TDBPRINTF(TDB_TRACE,("Released request (MapNotify)\n"));
			}
			break;

		case Expose:
			if (v->waitforexpose)
				v->waitforexpose = TFALSE;
			else if ((v->eventmask & TITYPE_REFRESH) &&
				getimsg(mod, v, &imsg, TITYPE_REFRESH))
			{
				imsg->timsg_X = ev->xexpose.x;
				imsg->timsg_Y = ev->xexpose.y;
				imsg->timsg_Width = ev->xexpose.width;
				imsg->timsg_Height = ev->xexpose.height;
				TAddTail(&v->imsgqueue, &imsg->timsg_Node);
				TDBPRINTF(TDB_TRACE,("Expose: REFRESH: %d %d %d %d\n",
					imsg->timsg_X, imsg->timsg_Y,
					imsg->timsg_Width, imsg->timsg_Height));
			}
			break;

		case GraphicsExpose:
			if (mod->x11_CopyExposeHook)
			{
				TINT rect[4];
				rect[0] = ev->xgraphicsexpose.x;
				rect[1] = ev->xgraphicsexpose.y;
				rect[2] = rect[0] + ev->xgraphicsexpose.width - 1;
				rect[3] = rect[1] + ev->xgraphicsexpose.height - 1;
				TCallHookPkt(mod->x11_CopyExposeHook,
					mod->x11_RequestInProgress->tvr_Op.CopyArea.Window,
					(TTAG) rect);
			}

			if (ev->xgraphicsexpose.count > 0)
				break;

			/* no more graphics expose events, fallthru: */

		case NoExpose:
			if (mod->x11_RequestInProgress)
			{
				TReplyMsg(mod->x11_RequestInProgress);
				mod->x11_RequestInProgress = TNULL;
				mod->x11_CopyExposeHook = TNULL;
				TDBPRINTF(TDB_TRACE,("Released request (NoExpose)\n"));
			}
			else
				TDBPRINTF(TDB_INFO,("NoExpose: TITYPE_REFRESH not set\n"));
			break;

		case FocusIn:
		case FocusOut:
			mod->x11_KeyQual = 0;
			if (v->eventmask & TITYPE_FOCUS)
			{
				if (getimsg(mod, v, &imsg, TITYPE_FOCUS))
				{
					imsg->timsg_Code = (ev->type == FocusIn);
					TAddTail(&v->imsgqueue, &imsg->timsg_Node);
				}
			}
			break;

		case MotionNotify:
		{
			struct TNode *next, *node = mod->x11_vlist.tlh_Head;
			setmousepos(mod, v, ev->xmotion.x, ev->xmotion.y);
			v->mousex = mod->x11_ScreenMouseX - v->winleft;
			v->mousey = mod->x11_ScreenMouseY - v->wintop;
			for (; (next = node->tln_Succ); node = next)
			{
				X11WINDOW *v = (X11WINDOW *) node;
				if (v->eventmask & TITYPE_MOUSEMOVE &&
					getimsg(mod, v, &imsg, TITYPE_MOUSEMOVE))
					TAddTail(&v->imsgqueue, &imsg->timsg_Node);
			}
			break;
		}

		case ButtonRelease:
		case ButtonPress:
			setmousepos(mod, v, ev->xbutton.x, ev->xbutton.y);
			if (v->eventmask & TITYPE_MOUSEBUTTON)
			{
				if (getimsg(mod, v, &imsg, TITYPE_MOUSEBUTTON))
				{
					unsigned int button = ev->xbutton.button;
					if (ev->type == ButtonPress)
					{
						switch (button)
						{
							case Button1:
								imsg->timsg_Code = TMBCODE_LEFTDOWN;
								break;
							case Button2:
								imsg->timsg_Code = TMBCODE_MIDDLEDOWN;
								break;
							case Button3:
								imsg->timsg_Code = TMBCODE_RIGHTDOWN;
								break;
							case Button4:
								imsg->timsg_Code = TMBCODE_WHEELUP;
								break;
							case Button5:
								imsg->timsg_Code = TMBCODE_WHEELDOWN;
								break;
						}
					}
					else
					{
						switch (button)
						{
							case Button1:
								imsg->timsg_Code = TMBCODE_LEFTUP;
								break;
							case Button2:
								imsg->timsg_Code = TMBCODE_MIDDLEUP;
								break;
							case Button3:
								imsg->timsg_Code = TMBCODE_RIGHTUP;
								break;
						}
					}
					TAddTail(&v->imsgqueue, &imsg->timsg_Node);
				}
			}
			break;

		case KeyRelease:
			processkey(mod, v, (XKeyEvent *) ev, TFALSE);
			break;

		case KeyPress:
			processkey(mod, v, (XKeyEvent *) ev, TTRUE);
			break;

		case SelectionRequest:
		{
			XSelectionRequestEvent *req = (XSelectionRequestEvent *) ev;
			XSelectionEvent reply;
			memset(&reply, 0, sizeof reply);
			reply.type = SelectionNotify;
			reply.serial = ev->xany.send_event;
			reply.send_event = True;
			reply.display = req->display;
			reply.requestor = req->requestor;
			reply.selection = req->selection;
			reply.property = req->property;
			reply.target = None;
			reply.time = req->time;
			
			if (req->target == mod->x11_XA_TARGETS)
			{
				XChangeProperty(mod->x11_Display, req->requestor,
	                req->property, XA_ATOM, 32, PropModeReplace,
					(unsigned char *) &mod->x11_XA_UTF8_STRING, 1);
			}
			else if (req->target == mod->x11_XA_UTF8_STRING)
			{
				XSelectionEvent *rcopy = TAlloc(TNULL, sizeof reply);
				if (rcopy && getimsg(mod, v, &imsg, TITYPE_REQSELECTION))
				{
					*rcopy = reply;
					imsg->timsg_Requestor = (TTAG) rcopy;
					imsg->timsg_Code = 
						req->selection == mod->x11_XA_PRIMARY ? 2 : 1;
					TAddTail(&v->imsgqueue, &imsg->timsg_Node);
					break;
				}
				TFree(rcopy);
			}
			else
				reply.property = None;
			
			XSendEvent(mod->x11_Display, req->requestor, 0, NoEventMask, 
				(XEvent *) &reply);
			XSync(mod->x11_Display, False);
			break;
		}
		
	}
	return TFALSE;
}

/*****************************************************************************/

LOCAL void x11_sendimessages(X11DISPLAY *mod, TBOOL do_interval)
{
	TAPTR TExecBase = TGetExecBase(mod);
	struct TNode *next, *node = mod->x11_vlist.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		X11WINDOW *v = (X11WINDOW *) node;
		TIMSG *imsg;

		if (do_interval && (v->eventmask & TITYPE_INTERVAL) &&
			getimsg(mod, v, &imsg, TITYPE_INTERVAL))
			TPutMsg(v->imsgport, TNULL, imsg);

		while ((imsg = (TIMSG *) TRemHead(&v->imsgqueue)))
		{
			/* only certain input message types are sent two-way */
			struct TMsgPort *rport = imsg->timsg_Type == TITYPE_REQSELECTION ?
				mod->x11_IReplyPort : TNULL;
			TPutMsg(v->imsgport, rport, imsg);
		}
	}
}
