
/*
**	display_rfb_mod.c - Raw framebuffer display driver
**	Written by Franciska Schulze <fschulze at schulze-mueller.de>
**	and Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

#include <assert.h>
#include <string.h>
#include <tek/inline/exec.h>
#include <tek/lib/imgload.h>
#include "display_rfb_mod.h"

#if defined(RFB_SUB_DEVICE)
#define STRHELP(x) #x
#define STR(x) STRHELP(x)
#define SUBDEVICE_NAME "display_" STR(RFB_SUB_DEVICE)
#else
#define SUBDEVICE_NAME TNULL
#endif

static void rfb_processevent(RFBDISPLAY *mod);
static RFBWINDOW *rfb_passevent_by_mousexy(RFBDISPLAY *mod, TIMSG *omsg,
	TBOOL focus);
static TBOOL rfb_passevent_to_focus(RFBDISPLAY *mod, TIMSG *omsg);
static TINT rfb_cmdrectaffected(RFBDISPLAY *mod, struct TVRequest *req,
	TINT r[4], TBOOL source_affect);

#define DEF_PTRWIDTH	8
#define DEF_PTRHEIGHT	8
#ifndef DEF_CURSORFILE
#define DEF_CURSORFILE	"tek/ui/cursor/cursor-black.png"
#endif

/*****************************************************************************/

#if defined(ENABLE_LINUXFB)

#include <unistd.h>
#include <linux/fb.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <linux/input.h>
#include <linux/kd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/inotify.h>
#include <tek/lib/utf8.h>

#define EVNOTIFYPATH "/dev/input"
#define EVPATH "/dev/input/by-path/"

static TUINT rfb_processmouseinput(RFBDISPLAY *mod, struct input_event *ev);
static void rfb_processkbdinput(RFBDISPLAY *mod, struct input_event *ev);

#include "keymap.c"

/*****************************************************************************/

static int rfb_findeventinput(const char *path, const char *what,
	char *fullname, size_t len)
{
	int found = 0;
	DIR *dfd = opendir(path);
	if (dfd)
	{
		struct dirent *de;
		while ((de = readdir(dfd)))
		{
			int valid = 0;
			strcpy(fullname, path);
			strcat(fullname, de->d_name);
			if (de->d_type == DT_LNK)
			{
				struct stat s;
				if (stat(fullname, &s) == 0)
					valid = S_ISCHR(s.st_mode);
			}
			else if (de->d_type == DT_CHR)
				valid = 1;
			
			if (!valid)
				continue;
			
			if (!strstr(fullname, what))
				continue;
			
			found = 1;
			break;
		}
		closedir(dfd);
	}
	return found;
}

static void rfb_updateinput(RFBDISPLAY *mod)
{
	char fullname[1024];
	
	if (mod->rfb_fd_input_kbd != -1)
		close(mod->rfb_fd_input_kbd);
	mod->rfb_fd_input_kbd = -1;
	
	if (mod->rfb_fd_input_mouse != -1)
		close(mod->rfb_fd_input_mouse);
	mod->rfb_fd_input_mouse = -1;
	
	if (rfb_findeventinput(EVPATH, "event-kbd", fullname, sizeof fullname))
	{
		mod->rfb_fd_input_kbd = open(fullname, O_RDONLY);
		if (mod->rfb_fd_input_kbd)
		{
			if (fcntl(mod->rfb_fd_input_kbd, F_SETFL, O_NONBLOCK) == -1)
			{
				TDBPRINTF(TDB_ERROR,("Cannot access keyboard\n"));
				close(mod->rfb_fd_input_kbd);
				mod->rfb_fd_input_kbd = -1;
			}
		}
		else
			TDBPRINTF(TDB_WARN,("Cannot open %s\n", fullname));
	}
	else
		TDBPRINTF(TDB_WARN,("No keyboard found\n"));
	
	if (rfb_findeventinput(EVPATH, "event-mouse", fullname, sizeof fullname))
	{
		mod->rfb_fd_input_mouse = open(fullname, O_RDONLY);
		if (mod->rfb_fd_input_mouse)
		{
			if (fcntl(mod->rfb_fd_input_mouse, F_SETFL, O_NONBLOCK) == -1)
			{
				TDBPRINTF(TDB_ERROR,("Cannot access mouse\n"));
				close(mod->rfb_fd_input_mouse);
				mod->rfb_fd_input_mouse = -1;
			}
		}
		else
			TDBPRINTF(TDB_WARN,("Cannot open %s\n", fullname));
	}
	else
		TDBPRINTF(TDB_WARN,("No mouse found\n"));
	
	if (mod->rfb_fd_input_mouse)
	{
		ioctl(mod->rfb_fd_input_mouse, EVIOCGABS(0), &mod->rfb_absinfo[0]);
		TDBPRINTF(TDB_TRACE,("abs xmin=%d xmax=%d reso=%d\n",
			mod->rfb_absinfo[0].minimum,
			mod->rfb_absinfo[0].maximum,
			mod->rfb_absinfo[0].resolution));				  
		ioctl(mod->rfb_fd_input_mouse, EVIOCGABS(1), &mod->rfb_absinfo[1]);
		TDBPRINTF(TDB_TRACE,("abs ymin=%d ymax=%d reso=%d\n",
			mod->rfb_absinfo[1].minimum,
			mod->rfb_absinfo[1].maximum,
			mod->rfb_absinfo[1].resolution));
	}

	/*TDBPRINTF(20,("sigread: %d\n", mod->rfb_fd_sigpipe_read));
	TDBPRINTF(20,("watch  : %d\n", mod->rfb_fd_watch_input));
	TDBPRINTF(20,("mouse  : %d\n", mod->rfb_fd_input_mouse));
	TDBPRINTF(20,("keyboard %d\n", mod->rfb_fd_input_kbd));*/
	mod->rfb_fd_max = TMAX(mod->rfb_fd_sigpipe_read, 
		mod->rfb_fd_inotify_input);
	mod->rfb_fd_max = TMAX(mod->rfb_fd_max, mod->rfb_fd_input_mouse);
	mod->rfb_fd_max = TMAX(mod->rfb_fd_max, mod->rfb_fd_input_kbd);
	/*TDBPRINTF(20,("fd_max : %d\n", mod->rfb_fd_max));*/
	mod->rfb_fd_max++;
}

static void rfb_initkeytable(RFBDISPLAY *mod)
{
	struct RawKey **rkeys = mod->rfb_RawKeys;
	int i;
	memset(mod->rfb_RawKeys, 0, sizeof mod->rfb_RawKeys);
	for (i = 0; 
		i < (int) (sizeof rawkeyinit / sizeof(struct RawKeyInit)); ++i)
	{
		struct RawKeyInit *ri = &rawkeyinit[i];
		rkeys[ri->index] = &ri->rawkey;
	}
}

static void rfb_linux_wait(RFBDISPLAY *mod, TTIME *waitt)
{
	fd_set rset;
	struct timeval tv;
	tv.tv_sec = waitt->tdt_Int64 / 1000000;
	tv.tv_usec = waitt->tdt_Int64 % 1000000;
	
	FD_ZERO(&rset);
	FD_SET(mod->rfb_fd_sigpipe_read, &rset);
	
	if (mod->rfb_fd_input_mouse != -1)
		FD_SET(mod->rfb_fd_input_mouse, &rset);
	if (mod->rfb_fd_input_kbd != -1)
		FD_SET(mod->rfb_fd_input_kbd, &rset);
	if (mod->rfb_fd_inotify_input != -1)
		FD_SET(mod->rfb_fd_inotify_input, &rset);
	
	if (select(mod->rfb_fd_max, &rset, NULL, NULL, &tv) > 0)
	{
		/* consume signal: */
		if (FD_ISSET(mod->rfb_fd_sigpipe_read, &rset))
		{
			char buf[256];
			int nbytes;
			ioctl(mod->rfb_fd_sigpipe_read, FIONREAD, &nbytes);
			if (nbytes > 0)
			{
				nbytes = TMIN((int) sizeof(buf), nbytes);
				if (read(mod->rfb_fd_sigpipe_read, buf, 
					(size_t) nbytes) != nbytes)
					TDBPRINTF(TDB_ERROR,("could not read wakeup signals\n"));
			}
		}
		
		if (mod->rfb_fd_input_mouse != -1 &&
			FD_ISSET(mod->rfb_fd_input_mouse, &rset))
		{
			TUINT input_pending = 0;
		
			struct input_event ie[16];
			for (;;)
			{
				int i;
				ssize_t nread = (int) read(mod->rfb_fd_input_mouse, ie,
					sizeof ie);
				if (nread < (int) sizeof(struct input_event))
					break;
				for (i = 0;
					i < (int) (nread / sizeof(struct input_event)); ++i)
					input_pending |= rfb_processmouseinput(mod, &ie[i]);
			}
			
			if (input_pending & TITYPE_MOUSEMOVE)
			{
				/* get prototype message: */
				TIMSG *msg;
				if (rfb_getimsg(mod, TNULL, &msg, TITYPE_MOUSEMOVE))
				{
					if (rfb_passevent_by_mousexy(mod, msg, TFALSE) != 
						mod->rfb_FocusWindow)
						rfb_passevent_to_focus(mod, msg);
					TAddTail(&mod->rfb_IMsgPool, &msg->timsg_Node);
				}
			}
		}
		
		if (mod->rfb_fd_input_kbd != -1 &&
			FD_ISSET(mod->rfb_fd_input_kbd, &rset))
		{
			struct input_event ie[16];
			for (;;)
			{
				int i;
				ssize_t nread = (int) read(mod->rfb_fd_input_kbd, ie,
					sizeof ie);
				if (nread < (int) sizeof(struct input_event))
					break;
				for (i = 0;
					i < (int) (nread / sizeof(struct input_event)); ++i)
					rfb_processkbdinput(mod, &ie[i]);
			}
		}
		
		if (mod->rfb_fd_inotify_input != -1 &&
			FD_ISSET(mod->rfb_fd_inotify_input, &rset))
		{
			char buf[4096] __attribute__ ((aligned(__alignof__(struct inotify_event))));
			if (read(mod->rfb_fd_inotify_input, buf, sizeof buf) == -1)
				TDBPRINTF(TDB_ERROR,("Error reading from event inotify\n"));
			rfb_updateinput(mod);
		}
	}
}

/*****************************************************************************/

static void rfb_processkbdinput(RFBDISPLAY *mod, struct input_event *ev)
{
	TINT qual = mod->rfb_KeyQual;
	TINT code = 0;
	TINT evtype = ev->value == 0 ? TITYPE_KEYUP : TITYPE_KEYDOWN;
	struct RawKey *rk;
	if (ev->type != EV_KEY)
		return;
	TDBPRINTF(TDB_DEBUG,("code=%d,%d qual=%d\n", ev->code, ev->value, qual));
	rk = mod->rfb_RawKeys[ev->code];
	if (rk)
	{
		if (rk->qualifier)
		{
			if (ev->value == 0)
				qual &= ~rk->qualifier;
			else
				qual |= rk->qualifier;
		}
		else
		{
			int i;
			code = rk->keycode;
			if (qual != 0)
			{
				for (i = 0; i < 4; ++i)
				{
					if ((rk->qualkeys[i].qualifier & qual) == qual && 
						rk->qualkeys[i].keycode)
					{
						code = rk->qualkeys[i].keycode;
						break;
					}
				}
			}
		}
	}
	
	if (code || qual != mod->rfb_KeyQual)
	{
		TIMSG *msg; /* get prototype message */
		if (rfb_getimsg(mod, TNULL, &msg, evtype))
		{
			ptrdiff_t len = 0;
			/* if ((code < 0xe000) || (code >= 0xf900)) */
			{
				len = (ptrdiff_t) utf8encode(msg->timsg_KeyCode, code) -
					(ptrdiff_t) msg->timsg_KeyCode;
			}
			msg->timsg_KeyCode[len] = 0;
			msg->timsg_Code = code;
			msg->timsg_Qualifier = qual & ~TKEYQ_RALT;
			if (!rfb_passevent_to_focus(mod, msg))
				rfb_passevent_by_mousexy(mod, msg, TTRUE);
			
			TDBPRINTF(TDB_DEBUG,("sending code=%d qual=%d\n", 
				msg->timsg_Code, msg->timsg_Qualifier));
				
			/* put back prototype message */
			TAddTail(&mod->rfb_IMsgPool, &msg->timsg_Node);
		}		
	}
	mod->rfb_KeyQual = qual;
}

/*****************************************************************************/

static TUINT rfb_processmouseinput(RFBDISPLAY *mod, struct input_event *ev)
{
	TUINT input_pending = 0;
	switch (ev->type)
	{
		case EV_KEY:
		{
			TUINT bc = 0;
			switch (ev->code)
			{
				case BTN_LEFT:
					bc = ev->value ? TMBCODE_LEFTDOWN : TMBCODE_LEFTUP;
					break;
				case BTN_RIGHT:
					bc = ev->value ? TMBCODE_RIGHTDOWN : TMBCODE_RIGHTUP;
					break;
				case BTN_MIDDLE:
					bc = ev->value ? TMBCODE_MIDDLEDOWN : TMBCODE_MIDDLEUP;
					break;
					
				case BTN_TOOL_FINGER:
				case BTN_TOUCH:
					TDBPRINTF(TDB_DEBUG,("TOUCH %d\n", ev->value));
					mod->rfb_button_touch = ev->value;
					if (ev->value)
					{
						mod->rfb_absstart[0] = mod->rfb_abspos[0];
						mod->rfb_absstart[1] = mod->rfb_abspos[1];
						mod->rfb_startmouse[0] = mod->rfb_MouseX;
						mod->rfb_startmouse[1] = mod->rfb_MouseY;
					}
					break;
			}
			if (bc)
			{
				TIMSG *msg;
				if (rfb_getimsg(mod, TNULL, &msg, TITYPE_MOUSEBUTTON))
				{
					msg->timsg_Code = bc;
					TBOOL down = bc & (TMBCODE_LEFTDOWN | 
						TMBCODE_RIGHTDOWN | TMBCODE_MIDDLEDOWN);
					RFBWINDOW *v = rfb_passevent_by_mousexy(mod, msg, down);
					if (!down && v != mod->rfb_FocusWindow)
						rfb_passevent_to_focus(mod, msg);
					TAddTail(&mod->rfb_IMsgPool, &msg->timsg_Node);
				}
			}
			break;
		}
		case EV_ABS:
		{
			switch (ev->code)
			{
				case ABS_X:
				{
					mod->rfb_abspos[0] = ev->value;
					if (mod->rfb_button_touch)
					{
						int mx = ev->value - mod->rfb_absstart[0];
						mx = mx * mod->rfb_Width /
							(mod->rfb_absinfo[0].maximum - 
							mod->rfb_absinfo[0].minimum);
						mod->rfb_MouseX = TCLAMP(0, 
							mx + mod->rfb_startmouse[0], mod->rfb_Width - 1);
						input_pending |= TITYPE_MOUSEMOVE;
					}
					break;
				}
				case ABS_Y:
				{
					mod->rfb_abspos[1] = ev->value;
					if (mod->rfb_button_touch)
					{
						int my = ev->value - mod->rfb_absstart[1];
						my = my * mod->rfb_Height / 
							(mod->rfb_absinfo[1].maximum - 
							mod->rfb_absinfo[1].minimum);
						mod->rfb_MouseY = TCLAMP(0, 
							my + mod->rfb_startmouse[1], mod->rfb_Height - 1);
						input_pending |= TITYPE_MOUSEMOVE;
					}
					break;
				}
			}
			break;
		}
		case EV_REL:
		{
			switch (ev->code)
			{
				case REL_X:
					mod->rfb_MouseX = TCLAMP(0, 
						mod->rfb_MouseX + ev->value, mod->rfb_Width - 1);
					input_pending |= TITYPE_MOUSEMOVE;
					break;
				case REL_Y:
					mod->rfb_MouseY = TCLAMP(0, 
						mod->rfb_MouseY + ev->value, mod->rfb_Height - 1);
					input_pending |= TITYPE_MOUSEMOVE;
					break;
				case REL_WHEEL:
				{
					TIMSG *msg;
					if (rfb_getimsg(mod, TNULL, &msg, TITYPE_MOUSEBUTTON))
					{
						msg->timsg_Code = ev->value < 0 ? 
							TMBCODE_WHEELDOWN : TMBCODE_WHEELUP;
						rfb_passevent_by_mousexy(mod, msg, TFALSE);
						TAddTail(&mod->rfb_IMsgPool, &msg->timsg_Node);
					}
				}
			}
			break;
		}
	}
	return input_pending;
}

static void rfb_wake(RFBDISPLAY *inst)
{
	char sig = 0;
	if (write(inst->rfb_fd_sigpipe_write, &sig, 1) != 1)
		TDBPRINTF(TDB_ERROR,("could not send wakeup signal\n"));
}

static void rfb_exitlinuxfb(RFBDISPLAY *mod)
{
	if (mod->rfb_fd_input_kbd != -1)
	{
		close(mod->rfb_fd_input_kbd);
		mod->rfb_fd_input_kbd = -1;
	}
	
	if (mod->rfb_fd_input_mouse != -1)
	{
		close(mod->rfb_fd_input_mouse);
		mod->rfb_fd_input_mouse = -1;
	}
	
	if (mod->rfb_fbhnd != -1)
	{
		close(mod->rfb_fbhnd);
		mod->rfb_fbhnd = -1;
	}
	
	if (mod->rfb_ttyfd != -1)
	{
		ioctl(mod->rfb_ttyfd, KDSETMODE, mod->rfb_ttyoldmode);
		close(mod->rfb_ttyfd);
		mod->rfb_ttyfd = -1;
	}
	
	if (mod->rfb_fd_inotify_input != -1)
	{
		close(mod->rfb_fd_inotify_input);
		mod->rfb_fd_inotify_input = -1;
		mod->rfb_fd_watch_input = -1;
	}
}

static const struct supportedfmt 
{ 
	TUINT rmsk, gmsk, bmsk, pixfmt; 
	TUINT8 roffs, rlen, goffs, glen, boffs, blen;
}
supportedfmts[] =
{
	{ 0x00ff0000, 0x0000ff00, 0x000000ff, TVPIXFMT_08R8G8B8, 16,8, 8,8, 0,8 },
	{ 0x000000ff, 0x0000ff00, 0x00ff0000, TVPIXFMT_08B8G8R8, 0,8, 8,8, 16,8 },
	{ 0xff000000, 0x00ff0000, 0x0000ff00, TVPIXFMT_R8G8B808, 24,8, 16,8, 8,8 },
	{ 0x0000ff00, 0x00ff0000, 0xff000000, TVPIXFMT_B8G8R808, 8,8, 16,8, 24,8 },
	{ 0x0000f800, 0x000007e0, 0x0000001f, TVPIXFMT_R5G6B5, 11,5, 5,6, 0,5 },
	{ 0x00007c00, 0x000003e0, 0x0000001f, TVPIXFMT_0R5G5B5, 10,5, 5,5, 0,5 },
	{ 0x0000001f, 0x000003e0, 0x0000f800, TVPIXFMT_0B5G5R5, 0,5, 5,5, 10,5 },
};

#define MASKFROMBF(bf) ((0xffffffff << (bf)->offset) \
	& (0xffffffff >> (32 - (bf)->offset - (bf)->length)))

static void getmasksfromvinfo(struct fb_var_screeninfo *vinfo, TUINT *rmsk, 
	TUINT *gmsk, TUINT *bmsk)
{
	*rmsk = MASKFROMBF(&vinfo->red);
	*gmsk = MASKFROMBF(&vinfo->green);
	*bmsk = MASKFROMBF(&vinfo->blue);
}

static TUINT rfb_getvinfopixfmt(struct fb_var_screeninfo *vinfo)
{
	TUINT i, rmsk, gmsk, bmsk;
	getmasksfromvinfo(vinfo, &rmsk, &gmsk, &bmsk);
	TDBPRINTF(TDB_TRACE,("rmsk=%08x gmsk=%08x bmsk=%08x\n", rmsk, gmsk, bmsk));
	for (i = 0; i < sizeof(supportedfmts) / sizeof(struct supportedfmt); ++i)
	{
		const struct supportedfmt *fmt = &supportedfmts[i];
		if (fmt->rmsk == rmsk && fmt->gmsk == gmsk && fmt->bmsk == bmsk)
			return fmt->pixfmt;
	}
	return TVPIXFMT_UNDEFINED;
}

static TBOOL rfb_setvinfopixfmt(struct fb_var_screeninfo *vinfo, TUINT pixfmt)
{
	TUINT i;
	for (i = 0; i < sizeof(supportedfmts) / sizeof(struct supportedfmt); ++i)
	{
		const struct supportedfmt *fmt = &supportedfmts[i];
		if (pixfmt == fmt->pixfmt)
		{
			vinfo->red.offset = fmt->roffs;
			vinfo->red.length = fmt->rlen;
			vinfo->green.offset = fmt->goffs;
			vinfo->green.length = fmt->glen;
			vinfo->blue.offset = fmt->boffs;
			vinfo->blue.length = fmt->blen;
			return TTRUE;
		}
	}
	return TFALSE;
}

static TBOOL rfb_initlinuxfb(RFBDISPLAY *mod)
{
	for (;;)
	{
		int pipefd[2];
		TUINT pixfmt;
		
		mod->rfb_fd_sigpipe_read = -1;
		mod->rfb_fd_sigpipe_write = -1;
		mod->rfb_ttyfd = -1;
		mod->rfb_ttyoldmode = KD_TEXT;
		mod->rfb_fd_input_kbd = -1;
		mod->rfb_fd_input_mouse = -1;
		mod->rfb_fbhnd = -1;
		mod->rfb_fd_inotify_input = -1;
		mod->rfb_fd_watch_input = -1;
		
		if (pipe(pipefd) != 0)
			break;
		
		mod->rfb_fd_sigpipe_read = pipefd[0];
		mod->rfb_fd_sigpipe_write = pipefd[1];
		
		mod->rfb_fd_inotify_input = inotify_init();
		if (mod->rfb_fd_inotify_input != -1)
			mod->rfb_fd_watch_input = 
				inotify_add_watch(mod->rfb_fd_inotify_input,
				EVNOTIFYPATH, IN_CREATE | IN_DELETE);
		if (mod->rfb_fd_watch_input == -1)
			TDBPRINTF(TDB_WARN,("cannot watch input events\n"));

		mod->rfb_ttyfd = open("/dev/console", O_RDWR);
		if (mod->rfb_ttyfd != -1)
		{
			/*ioctl(mod->rfb_ttyfd, KDGETMODE, &mod->rfb_ttyoldmode);*/
			ioctl(mod->rfb_ttyfd, KDSETMODE, KD_GRAPHICS);
		}
		else
			TDBPRINTF(TDB_WARN,("Cannot access console device\n"));
		
		/* open framebuffer device */
		mod->rfb_fbhnd = open("/dev/fb0", O_RDWR);
		if (mod->rfb_fbhnd == -1)
		{
			TDBPRINTF(TDB_ERROR,("Cannot open framebuffer device\n"));
			break;
		}
		
		if (ioctl(mod->rfb_fbhnd, FBIOGET_FSCREENINFO, &mod->rfb_finfo))
			break;
		
		if (mod->rfb_finfo.type != FB_TYPE_PACKED_PIXELS ||
			mod->rfb_finfo.visual != FB_VISUAL_TRUECOLOR)
		{
			TDBPRINTF(TDB_ERROR,("Unsupported framebuffer type\n"));
			break;
		}
		
		/* get and backup */
		if (ioctl(mod->rfb_fbhnd, FBIOGET_VSCREENINFO, &mod->rfb_vinfo))
			break;
		mod->rfb_orig_vinfo = mod->rfb_vinfo;

		/* setting mode doesn't seem to work? */
#if 0 
#if defined(RFBPIXFMT)
		if (rfb_getvinfopixfmt(&mod->rfb_vinfo) != RFBPIXFMT)
		{
			/* set properties */
			pixfmt = RFBPIXFMT;
			bpp = TVPIXFMT_BYTES_PER_PIXEL(pixfmt);
			mod->rfb_vinfo.bits_per_pixel = bpp * 8;
			rfb_setvinfopixfmt(&mod->rfb_vinfo, pixfmt);
			if (ioctl(mod->rfb_fbhnd, FBIOPUT_VSCREENINFO, &mod->rfb_vinfo))
				break;
			/* reload */
			if (ioctl(mod->rfb_fbhnd, FBIOGET_VSCREENINFO, &mod->rfb_vinfo))
				break;
		}
#endif
#endif

		pixfmt = rfb_getvinfopixfmt(&mod->rfb_vinfo);
		if (pixfmt == TVPIXFMT_UNDEFINED)
		{
			TDBPRINTF(TDB_ERROR,("Unsupported framebuffer pixel format\n"));
			break;
		}
		
		mod->rfb_DevWidth = mod->rfb_vinfo.xres;
		mod->rfb_DevHeight = mod->rfb_vinfo.yres;
		mod->rfb_DevBuf.tpb_BytesPerLine = mod->rfb_finfo.line_length;
		mod->rfb_DevBuf.tpb_Format = pixfmt;
		mod->rfb_DevBuf.tpb_Data = mmap(0, mod->rfb_finfo.smem_len, 
			PROT_READ | PROT_WRITE, MAP_SHARED, mod->rfb_fbhnd, 0);
		if ((TINTPTR) mod->rfb_DevBuf.tpb_Data == -1)
			break;
		memset(mod->rfb_DevBuf.tpb_Data, 0, mod->rfb_finfo.smem_len);
		
		mod->rfb_PixBuf = mod->rfb_DevBuf;

		rfb_updateinput(mod);
		rfb_initkeytable(mod);

		mod->rfb_Flags |= RFBFL_CANSHOWPTR | RFBFL_SHOWPTR;
		mod->rfb_Flags &= ~RFBFL_BUFFER_CAN_RESIZE;
		
		return TTRUE;
	}
	
	rfb_exitlinuxfb(mod);
	return TFALSE;
}

#endif /* defined(ENABLE_LINUXFB) */

/*****************************************************************************/

static TBOOL rfb_initpointer(RFBDISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	if ((mod->rfb_Flags & (RFBFL_CANSHOWPTR | RFBFL_SHOWPTR)) != 
		(RFBFL_CANSHOWPTR | RFBFL_SHOWPTR))
		return TFALSE;
	
#define _mpE 0x00000000
#define _mpW 0xffffffff
#define _mpB 0xff000000
#define _mpG 0xffaaaaaa
	static const TUINT def_ptrimg[] = 
	{
		_mpB,_mpB,_mpB,_mpB,_mpB,_mpB,_mpB,_mpB,
		_mpB,_mpW,_mpW,_mpW,_mpW,_mpW,_mpG,_mpB,
		_mpB,_mpW,_mpW,_mpW,_mpW,_mpG,_mpB,_mpE,
		_mpB,_mpW,_mpW,_mpW,_mpG,_mpB,_mpE,_mpE,
		_mpB,_mpW,_mpW,_mpG,_mpW,_mpG,_mpB,_mpE,
		_mpB,_mpW,_mpG,_mpB,_mpG,_mpW,_mpG,_mpB,
		_mpB,_mpG,_mpB,_mpE,_mpB,_mpG,_mpG,_mpB,
		_mpB,_mpB,_mpE,_mpE,_mpE,_mpB,_mpB,_mpE,
	};
	
	mod->rfb_PtrImage.tpb_Data = (TUINT8 *) def_ptrimg;
	mod->rfb_PtrImage.tpb_Format = TVPIXFMT_A8R8G8B8;
	mod->rfb_PtrImage.tpb_BytesPerLine = DEF_PTRWIDTH * 4;
	mod->rfb_PtrWidth = DEF_PTRWIDTH;
	mod->rfb_PtrHeight = DEF_PTRHEIGHT;
	mod->rfb_MouseHotX = 0;
	mod->rfb_MouseHotY = 0;
	mod->rfb_Flags &= ~(RFBFL_PTR_VISIBLE | RFBFL_PTR_ALLOCATED);

	FILE *f = fopen(DEF_CURSORFILE, "rb");
	if (f)
	{
		TAPTR TExecBase = TGetExecBase(mod);
		struct ImgLoader ld;
		if (imgload_init_file(&ld, TExecBase, f))
		{
			if (imgload_load(&ld))
			{
				mod->rfb_PtrImage = ld.iml_Image;
				mod->rfb_PtrWidth = ld.iml_Width;
				mod->rfb_PtrHeight = ld.iml_Height;
				mod->rfb_Flags |= RFBFL_PTR_ALLOCATED;					
			}
		}
		fclose(f);
	}
	
	mod->rfb_PtrBackBuffer.data = TAlloc(mod->rfb_MemMgr,
		TVPIXFMT_BYTES_PER_PIXEL(mod->rfb_PixBuf.tpb_Format) *
		mod->rfb_PtrWidth * mod->rfb_PtrHeight);
	if (!mod->rfb_PtrBackBuffer.data)
	{
		mod->rfb_Flags &= ~RFBFL_SHOWPTR;
		return TFALSE;
	}
	return TTRUE;
}

static void storebackbuf(RFBDISPLAY *mod, struct BackBuffer *bbuf, TINT x0,
	TINT y0, TINT x1, TINT y1)
{
	TUINT8 *bkdst = bbuf->data;
	TUINT8 *bksrc = TVPB_GETADDRESS(&mod->rfb_DevBuf, x0, y0);
	TUINT bpl = mod->rfb_DevBuf.tpb_BytesPerLine;
	TUINT bpp = TVPIXFMT_BYTES_PER_PIXEL(mod->rfb_DevBuf.tpb_Format);
	TUINT srcbpl = mod->rfb_PtrWidth * bpp;
	TINT y;
	for (y = y0; y <= y1; ++y)
	{
		memcpy(bkdst, bksrc, srcbpl);
		bksrc += bpl;
		bkdst += srcbpl;
	}
	bbuf->rect[0] = x0;
	bbuf->rect[1] = y0;
	bbuf->rect[2] = x1;
	bbuf->rect[3] = y1;
}

static TBOOL drawpointer(RFBDISPLAY *mod, TINT x0, TINT y0)
{
	TINT s0 = 0;
	TINT s1 = 0;
	TINT s2 = mod->rfb_Width - 1;
	TINT s3 = mod->rfb_Height - 1;
	TINT x1 = x0 + mod->rfb_PtrWidth - 1;
	TINT y1 = y0 + mod->rfb_PtrHeight - 1;
	if (RFB_OVERLAP(s0, s1, s2, s3, x0, y0, x1, y1))
	{
		struct TVPixBuf dst = mod->rfb_DevBuf;
		x0 = TMAX(x0, s0);
		y0 = TMAX(y0, s1);
		x1 = TMIN(x1, s2);
		y1 = TMIN(y1, s3);
		storebackbuf(mod, &mod->rfb_PtrBackBuffer, x0, y0, x1, y1);
		pixconv_convert(&mod->rfb_PtrImage, &dst, x0, y0, x1, y1, 0, 0, 
			TTRUE, TFALSE);
		return TTRUE;
	}
	return TFALSE;
}

static void restorebackbuf(RFBDISPLAY *mod, struct BackBuffer *bbuf)
{
	TUINT8 *bksrc = bbuf->data;
	TUINT8 *bkdst = TVPB_GETADDRESS(&mod->rfb_DevBuf, bbuf->rect[0], bbuf->rect[1]);
	TUINT bpl = mod->rfb_DevBuf.tpb_BytesPerLine;
	TUINT bpp = TVPIXFMT_BYTES_PER_PIXEL(mod->rfb_DevBuf.tpb_Format);
	TUINT srcbpl = mod->rfb_PtrWidth * bpp;
	TINT y;
	for (y = bbuf->rect[1]; y <= bbuf->rect[3]; ++y)
	{
		memcpy(bkdst, bksrc, srcbpl);
		bkdst += bpl;
		bksrc += srcbpl;
	}
}

static void rfb_drawptr(RFBDISPLAY *mod)
{
	if (!(mod->rfb_Flags & RFBFL_SHOWPTR))
		return;
	TINT mx = mod->rfb_MouseX - mod->rfb_MouseHotX;
	TINT my = mod->rfb_MouseY - mod->rfb_MouseHotY;
	if (mod->rfb_Flags & RFBFL_PTR_VISIBLE)
	{
		if (mx == mod->rfb_PtrBackBuffer.rect[0] && 
			my == mod->rfb_PtrBackBuffer.rect[1])
			return;
		restorebackbuf(mod, &mod->rfb_PtrBackBuffer);
	}
	drawpointer(mod, mx, my);
	mod->rfb_Flags |= RFBFL_PTR_VISIBLE;
}


static void rfb_restoreptrbg(RFBDISPLAY *mod)
{
	if (!(mod->rfb_Flags & RFBFL_PTR_VISIBLE))
		return;
	restorebackbuf(mod, &mod->rfb_PtrBackBuffer);
	mod->rfb_Flags &= ~RFBFL_PTR_VISIBLE;
}


static TINT rfb_cmdrectaffected(RFBDISPLAY *mod, struct TVRequest *req,
	TINT r[4], TBOOL source_affect)
{
	RFBWINDOW *v = TNULL;
	TINT *rect = TNULL;
	TINT *xywh = TNULL;
	TINT temprect[4];
	switch (req->tvr_Req.io_Command)
	{
		default:
			/* not affected, no rect */
			return 0;
			
		case TVCMD_FLUSH:
		case TVCMD_SETATTRS:
			/* yes, affected, but no rect */
			return -1;

		case TVCMD_DRAWSTRIP:
			v = req->tvr_Op.Strip.Window;
			break;
		case TVCMD_DRAWFAN:
			v = req->tvr_Op.Fan.Window;
			break;
		case TVCMD_TEXT:
			v = req->tvr_Op.Text.Window;
			break;
		case TVCMD_RECT:
			v = req->tvr_Op.Rect.Window;
			xywh = req->tvr_Op.Rect.Rect;
			break;
		case TVCMD_FRECT:
			v = req->tvr_Op.FRect.Window;
			xywh = req->tvr_Op.FRect.Rect;
			break;
		case TVCMD_LINE:
			v = req->tvr_Op.Line.Window;
			xywh = req->tvr_Op.Line.Rect;
			break;
		case TVCMD_DRAWBUFFER:
			v = req->tvr_Op.DrawBuffer.Window;
			xywh = req->tvr_Op.DrawBuffer.RRect;
			break;
		case TVCMD_COPYAREA:
		{
			v = req->tvr_Op.CopyArea.Window;
			TINT *s = req->tvr_Op.CopyArea.Rect;
			TINT dx0 = req->tvr_Op.CopyArea.DestX;
			TINT dy0 = req->tvr_Op.CopyArea.DestY;
			TINT sx0 = s[0];
			TINT sy0 = s[1];
			TINT sx1 = s[0] + s[2] - 1;
			TINT sy1 = s[1] + s[3] - 1;
			TINT dx = dx0 - sx0;
			TINT dy = dy0 - sy0;
			TINT dx1 = sx1 + dx;
			TINT dy1 = sy1 + dy;
			rect = temprect;
			if (source_affect)
			{
				rect[0] = TMIN(sx0, dx0);
				rect[1] = TMIN(sy0, dy0);
				rect[2] = TMAX(sx1, dx1);
				rect[3] = TMAX(sy1, dy1);
				break;
			}
			rect[0] = dx0;
			rect[1] = dy0;
			rect[2] = dx1;
			rect[3] = dy1;
			break;
		}
		case TVCMD_PLOT:
			v = req->tvr_Op.Plot.Window;
			rect = temprect;
			rect[0] = req->tvr_Op.Plot.Rect[0];
			rect[1] = req->tvr_Op.Plot.Rect[1];
			rect[2] = req->tvr_Op.Plot.Rect[0];
			rect[3] = req->tvr_Op.Plot.Rect[1];
			break;
	}
	
	assert(v);
	
	if (v->rfbw_ClipRect[0] == -1)
		return 0;

	if (xywh)
	{
		rect = temprect;
		rect[0] = xywh[0];
		rect[1] = xywh[1];
		rect[2] = xywh[0] + xywh[2] - 1;
		rect[3] = xywh[1] + xywh[3] - 1;
	}
	
	if (rect)
	{
		r[0] = rect[0] + v->rfbw_WinRect[0];
		r[1] = rect[1] + v->rfbw_WinRect[1];
		r[2] = rect[2] + v->rfbw_WinRect[0];
		r[3] = rect[3] + v->rfbw_WinRect[1];
	}
	else
		memcpy(r, v->rfbw_WinRect, sizeof r);

	return region_intersect(r, v->rfbw_ClipRect);
}

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
#if defined(ENABLE_LINUXFB)
	rfb_wake(mod);
#endif
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
		msg->timsg_UserData = v ? v->userdata : TNULL;
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

#if defined(ENABLE_LINUXFB)
	rfb_exitlinuxfb(mod);
#endif

	TFree(mod->rfb_PtrBackBuffer.data);
	if (mod->rfb_Flags & RFBFL_PTR_ALLOCATED)
		TFree(mod->rfb_PtrImage.tpb_Data);
	
	/* free pooled input messages: */
	while ((imsg = TRemHead(&mod->rfb_IMsgPool)))
		TFree(imsg);

	/* close all fonts */
	node = mod->rfb_FontManager.openfonts.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
		rfb_hostclosefont(mod, (TAPTR) node);

	if (mod->rfb_Flags & RFBFL_BUFFER_OWNER)
		TFree(mod->rfb_PixBuf.tpb_Data);
	
	TDestroy(mod->rfb_RndIMsgPort);
	TFree(mod->rfb_RndRequest);
	TCloseModule(mod->rfb_RndDevice);
	TDestroy((struct THandle *) mod->rfb_RndRPort);
	TDestroy((struct THandle *) mod->rfb_InstanceLock);
	
	if (mod->rfb_DirtyRegion)
		region_destroy(&mod->rfb_RectPool, mod->rfb_DirtyRegion);
	
	region_destroypool(&mod->rfb_RectPool);
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
		region_initpool(&mod->rfb_RectPool, TExecBase);
		
		/* list of free input messages: */
		TInitList(&mod->rfb_IMsgPool);

		/* list of all open visuals: */
		TInitList(&mod->rfb_VisualList);

		/* init fontmanager and default font */
		TInitList(&mod->rfb_FontManager.openfonts);

		mod->rfb_PixBuf.tpb_Format = TVPIXFMT_UNDEFINED;
		mod->rfb_DevWidth = RFB_DEF_WIDTH;
		mod->rfb_DevHeight = RFB_DEF_HEIGHT;
		
		mod->rfb_Flags = RFBFL_BUFFER_CAN_RESIZE;
		
#if defined(ENABLE_LINUXFB)
		if (!rfb_initlinuxfb(mod))
			break;
#endif
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
	TUINT sig = 0;

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
		if (sig & cmdportsignal)
		{
			TINT *mouserect = mod->rfb_PtrBackBuffer.rect;
			TBOOL checkrect = mod->rfb_Flags & (RFBFL_PTR_VISIBLE | RFBFL_BACKBUFFER);
			TBOOL ptr_visible = mod->rfb_Flags & RFBFL_PTR_VISIBLE;
			TINT r[4];
			
			while ((req = TGetMsg(cmdport)))
			{
				if (checkrect)
				{
					TINT res = rfb_cmdrectaffected(mod, req, r, ptr_visible);
					if (res != 0)
					{
						if (ptr_visible && (res < 0 || RFB_OVERLAPRECT(mouserect, r)))
						{
							rfb_restoreptrbg(mod);
							checkrect = mod->rfb_Flags & RFBFL_BACKBUFFER;
							ptr_visible = TFALSE;
						}
					}
				}
				rfb_docmd(mod, req);
				TReplyMsg(req);
			}
		}
		rfb_drawptr(mod);
		
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
		
#if defined(ENABLE_LINUXFB)
		rfb_linux_wait(mod, &waitt);
		sig = TSetSignal(0, cmdportsignal | imsgportsignal | TTASK_SIG_ABORT); 
#else
		/* wait for and get signal state: */
		sig = TWaitTime(&waitt,
			cmdportsignal | imsgportsignal | TTASK_SIG_ABORT);
#endif
		
		/* process input messages: */
		if (sig & imsgportsignal)
			rfb_processevent(mod);
		
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
			mod->rfb_MouseX = x;
			mod->rfb_MouseY = y;
			imsg->timsg_Code = omsg->timsg_Code;
			imsg->timsg_Qualifier = omsg->timsg_Qualifier;
			imsg->timsg_MouseX = x - v->rfbw_WinRect[0];
			imsg->timsg_MouseY = y - v->rfbw_WinRect[1];
			imsg->timsg_ScreenMouseX = x;
			imsg->timsg_ScreenMouseY = y;
			memcpy(imsg->timsg_KeyCode, omsg->timsg_KeyCode, 8);
			TPutMsg(v->rfbw_IMsgPort, TNULL, imsg);
			return TTRUE;
		}
	}
	return TFALSE;
}

static RFBWINDOW *rfb_passevent_by_mousexy(RFBDISPLAY *mod, TIMSG *omsg,
	TBOOL focus)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TINT x = omsg->timsg_MouseX = TCLAMP(0, omsg->timsg_MouseX, mod->rfb_Width - 1);
	TINT y = omsg->timsg_MouseY = TCLAMP(0, omsg->timsg_MouseY, mod->rfb_Height - 1);
	TLock(mod->rfb_InstanceLock);
	RFBWINDOW *v = rfb_findcoord(mod, x, y);
	if (v && (omsg->timsg_Type != TITYPE_MOUSEMOVE || 
		(mod->rfb_FocusWindow == v || (v->rfbw_Flags & RFBWFL_IS_POPUP))))
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
				if ((mod->rfb_Flags & RFBFL_BUFFER_OWNER) &&
					(mod->rfb_Flags & RFBFL_BUFFER_CAN_RESIZE))
				{
					if (mod->rfb_DirtyRegion)
					{
						region_destroy(&mod->rfb_RectPool, 
							mod->rfb_DirtyRegion);
						mod->rfb_DirtyRegion = TNULL;
					}
					
					mod->rfb_Width = msg->timsg_Width;
					mod->rfb_Height = msg->timsg_Height;
					TUINT bpp = 
						TVPIXFMT_BYTES_PER_PIXEL(mod->rfb_PixBuf.tpb_Format);
					mod->rfb_PixBuf.tpb_BytesPerLine = mod->rfb_Width * bpp;
					TFree(mod->rfb_PixBuf.tpb_Data);
					mod->rfb_PixBuf.tpb_Data = TAlloc(mod->rfb_MemMgr,
						mod->rfb_PixBuf.tpb_BytesPerLine * mod->rfb_Height);
					
					struct TNode *next, *node = mod->rfb_VisualList.tlh_Head;
					for (; (next = node->tln_Succ); node = next)
					{
						RFBWINDOW *v = (RFBWINDOW *) node;
						
						rfb_setrealcliprect(mod, v);
					
						TINT w0 = v->rfbw_WinRect[2] - v->rfbw_WinRect[0] + 1;
						TINT h0 = v->rfbw_WinRect[3] - v->rfbw_WinRect[1] + 1;
						
						if ((v->rfbw_Flags & RFBWFL_FULLSCREEN))
						{
							v->rfbw_WinRect[2] = mod->rfb_Width - 1;
							v->rfbw_WinRect[3] = mod->rfb_Height - 1;
						}
						
						TINT ww = v->rfbw_WinRect[2] - v->rfbw_WinRect[0] + 1;
						TINT wh = v->rfbw_WinRect[3] - v->rfbw_WinRect[1] + 1;
						
						if (v->rfbw_MinWidth > 0 && ww < v->rfbw_MinWidth)
							v->rfbw_WinRect[0] = 
								v->rfbw_WinRect[2] - v->rfbw_MinWidth;
						if (v->rfbw_MinHeight > 0 && wh < v->rfbw_MinHeight)
							v->rfbw_WinRect[1] = 
								v->rfbw_WinRect[3] - v->rfbw_MinHeight;
						
						v->rfbw_PixBuf.tpb_BytesPerLine = 
							mod->rfb_PixBuf.tpb_BytesPerLine;
						v->rfbw_PixBuf.tpb_Data = mod->rfb_PixBuf.tpb_Data;

						ww = v->rfbw_WinRect[2] - v->rfbw_WinRect[0] + 1;
						wh = v->rfbw_WinRect[3] - v->rfbw_WinRect[1] + 1;
						
						if (ww != w0 || wh != h0)
						{
							if (rfb_getimsg(mod, v, &imsg, TITYPE_NEWSIZE))
							{
								imsg->timsg_Width = ww;
								imsg->timsg_Height = wh;
								TPutMsg(v->rfbw_IMsgPort, TNULL, imsg);
							}
						}
						
						TINT drect[4];
						drect[0] = 0;
						drect[1] = 0;
						drect[2] = ww - 1;
						drect[3] = wh - 1;
						rfb_damage(mod, drect, TNULL);
						
					}
				}
				else
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
				TBOOL down = msg->timsg_Code & (TMBCODE_LEFTDOWN | 
					TMBCODE_RIGHTDOWN | TMBCODE_MIDDLEDOWN);
				RFBWINDOW *v = rfb_passevent_by_mousexy(mod, msg, down);
				if (!down && v != mod->rfb_FocusWindow)
					rfb_passevent_to_focus(mod, msg);
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

LOCAL void rfb_exit(RFBDISPLAY *mod)
{
	TAPTR TExecBase = TGetExecBase(mod);
	if (mod->rfb_Task)
	{
		TSignal(mod->rfb_Task, TTASK_SIG_ABORT);
#if defined(ENABLE_LINUXFB)
		rfb_wake(mod);
#endif
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
	{
		/* Attributes that can be queried during open: */
		TTAG p = TGetTag(tags, TVisual_HaveWindowManager, TNULL);
		if (p) *((TBOOL *) p) = TFALSE;
		return mod;
	}
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
