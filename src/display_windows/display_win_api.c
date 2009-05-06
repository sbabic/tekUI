
/*
**	display_win_api.c - Windows display driver
**	Written by Timm S. Mueller <tmueller@schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

#include "display_win_mod.h"

#define RGB2COLORREF(rgb) \
	((((rgb) << 16) & 0xff0000) | ((rgb) & 0xff00) | (((rgb) >> 16) & 0xff))

static void
fb_closeall(WINDISPLAY *mod, WINWINDOW *win, TBOOL unref_font);

/*****************************************************************************/

static TBOOL fb_initwindow(TAPTR task)
{
	struct TExecBase *TExecBase = TGetExecBase(task);
	struct TVRequest *req = TGetTaskData(task);
	TTAGITEM *tags = req->tvr_Op.OpenWindow.Tags;
	WINDISPLAY *mod = (WINDISPLAY *) req->tvr_Req.io_Device;
	WINWINDOW *win;

	req->tvr_Op.OpenWindow.Window = TNULL;

	for (;;)
	{
		RECT wrect;
		BITMAPINFOHEADER *bmi;
		TUINT style;
		TUINT exstyle;
		TIMSG *imsg;
		const char *classname;
		TSTRPTR title;

		win = TAlloc0(mod->fbd_MemMgr, sizeof(WINWINDOW));
		if (win == TNULL)
			break;

		TInitList(&win->penlist);

		win->fbv_Width = (TUINT) TGetTag(tags, TVisual_Width, FB_DEF_WIDTH);
		win->fbv_Height = (TUINT) TGetTag(tags, TVisual_Height, FB_DEF_HEIGHT);
		win->fbv_Left = (TUINT) TGetTag(tags, TVisual_WinLeft, 0xffffffff);
		win->fbv_Top = (TUINT) TGetTag(tags, TVisual_WinTop, 0xffffffff);
		win->fbv_Title = (TSTRPTR) TGetTag(tags, TVisual_Title,
			(TTAG) "TEKlib Visual");
		win->fbv_Borderless = TGetTag(tags, TVisual_Borderless, TFALSE);
		win->fbv_UserData = TGetTag(tags, TVisual_UserData, TNULL);

		win->fbv_MinWidth = (TINT) TGetTag(tags, TVisual_MinWidth, (TTAG) -1);
		win->fbv_MinHeight = (TINT) TGetTag(tags, TVisual_MinHeight, (TTAG) -1);
		win->fbv_MaxWidth = (TINT) TGetTag(tags, TVisual_MaxWidth, (TTAG) -1);
		win->fbv_MaxHeight = (TINT) TGetTag(tags, TVisual_MaxHeight, (TTAG) -1);

		if (win->fbv_Borderless)
		{
			style = (WS_POPUP | WS_CLIPCHILDREN | WS_CLIPSIBLINGS) & ~WS_BORDER;
			classname = FB_DISPLAY_CLASSNAME_POPUP;
			title = NULL;
			exstyle = WS_EX_TOPMOST | WS_EX_TOOLWINDOW;
		}
		else
		{
			style = WS_OVERLAPPEDWINDOW;
			classname = FB_DISPLAY_CLASSNAME;
			title = win->fbv_Title;
			exstyle = 0;
		}

		wrect.left = wrect.right = wrect.top = wrect.bottom = 0;
		AdjustWindowRectEx(&wrect, style, FALSE, exstyle);
		win->fbv_BorderWidth = wrect.right - wrect.left;
		win->fbv_BorderHeight = wrect.bottom - wrect.top;
		win->fbv_BorderLeft = -wrect.left;
		win->fbv_BorderTop = -wrect.top;

		if (!win->fbv_Borderless)
		{
			TINT m1, m2, m3, m4;
			win_getminmax(win, &m1, &m2, &m3, &m4, TTRUE);
			win->fbv_Width = TCLAMP(m1, (TINT) win->fbv_Width, m3);
			win->fbv_Height = TCLAMP(m2, (TINT) win->fbv_Height, m4);
		}

		if (win->fbv_Left != 0xffffffff && win->fbv_Top != 0xffffffff)
		{
			wrect.left = win->fbv_Left;
			wrect.top = win->fbv_Top;
			wrect.right = win->fbv_Left + win->fbv_Width;
			wrect.bottom = win->fbv_Top + win->fbv_Height;
			if (!AdjustWindowRectEx(&wrect, style, FALSE, exstyle))
				break;

			win->fbv_Left = wrect.left;
			win->fbv_Top = wrect.top;
			win->fbv_HWnd = CreateWindowEx(exstyle, classname,
				title, style, win->fbv_Left, win->fbv_Top,
				wrect.right - wrect.left, wrect.bottom - wrect.top,
				(HWND) NULL, (HMENU) NULL, mod->fbd_HInst, (LPVOID) NULL);
		}
		else
		{
			win->fbv_HWnd = CreateWindowEx(exstyle, classname,
				title, style, CW_USEDEFAULT, CW_USEDEFAULT,
				win->fbv_Width, win->fbv_Height,
				(HWND) NULL, (HMENU) NULL, mod->fbd_HInst, (LPVOID) NULL);
		}

		if (win->fbv_HWnd == TNULL)
			break;

		GetWindowRect(win->fbv_HWnd, &wrect);
		win->fbv_Left = wrect.left + win->fbv_BorderLeft;
		win->fbv_Top = wrect.top + win->fbv_BorderHeight;
		win->fbv_Width = wrect.right - wrect.left - win->fbv_BorderWidth;
		win->fbv_Height = wrect.bottom - wrect.top - win->fbv_BorderHeight;

		SetWindowLong(win->fbv_HWnd, GWL_USERDATA, (LONG) win);

		win->fbv_HDC = GetDC(win->fbv_HWnd);
		win->fbv_Display = mod;
		win->fbv_InputMask = (TUINT) TGetTag(tags, TVisual_EventMask, 0);
		win->fbv_IMsgPort = req->tvr_Op.OpenWindow.IMsgPort;

		bmi = &win->fbv_DrawBitMap;
		bmi->biSize = sizeof(BITMAPINFOHEADER);
		bmi->biPlanes = 1;
		bmi->biBitCount = 32;
		bmi->biCompression = BI_RGB;
		bmi->biSizeImage = 0;
		bmi->biXPelsPerMeter = 1;
		bmi->biYPelsPerMeter = 1;
		bmi->biClrUsed = 0;
		bmi->biClrImportant = 0;

		TInitList(&win->fbv_IMsgQueue);

		req->tvr_Op.OpenWindow.Window = win;
		win->fbv_Task = task;

		TLock(mod->fbd_Lock);

		/* init default font */
		win->fbv_CurrentFont = mod->fbd_FontManager.deffont;
		mod->fbd_FontManager.defref++;

		/* register default font */
		/*TDBPRINTF(TDB_TRACE,("Add window: %p\n", win->window));*/

		/* add window on top of window stack: */
		TAddHead(&mod->fbd_VisualList, &win->fbv_Node);

		TUnlock(mod->fbd_Lock);

		SetBkMode(win->fbv_HDC, TRANSPARENT);
		
		ShowWindow(win->fbv_HWnd, SW_SHOWNORMAL);
		UpdateWindow(win->fbv_HWnd);

		TSetTaskData(task, win);

		if ((win->fbv_InputMask & TITYPE_FOCUS) &&
			(fb_getimsg(mod, win, &imsg, TITYPE_FOCUS)))
		{
			imsg->timsg_Code = 1;
			fb_sendimsg(mod, win, imsg);
		}
		if ((win->fbv_InputMask & TITYPE_REFRESH) &&
			(fb_getimsg(mod, win, &imsg, TITYPE_REFRESH)))
		{
			imsg->timsg_X = 0;
			imsg->timsg_Y = 0;
			imsg->timsg_Width = win->fbv_Width;
			imsg->timsg_Height = win->fbv_Height;
			fb_sendimsg(mod, win, imsg);
		}
		
		return TTRUE;
	}

	TDBPRINTF(TDB_ERROR,("Window open failed\n"));
	fb_closeall(mod, win, TFALSE);
	return TFALSE;
}

static void fb_dowindow(TAPTR task)
{
	struct TExecBase *TExecBase = TGetExecBase(task);
	WINWINDOW *win = TGetTaskData(task);
	WINDISPLAY *mod = win->fbv_Display;
	MSG msg;
	TUINT sig;

	TDBPRINTF(TDB_INFO,("DoWindow...\n"));

	do
	{
		WaitMessage();

		while (PeekMessage(&msg, win->fbv_HWnd, 0,0, PM_REMOVE))
		{
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}

// 		PostMessage(win->fbv_HWnd, WM_USER, 0, 0);
		sig = TSetSignal(0, TTASK_SIG_ABORT);

	} while (!(sig & TTASK_SIG_ABORT));

	TDBPRINTF(TDB_INFO,("Window Done\n"));

	TLock(mod->fbd_Lock);
	TRemove(&win->fbv_Node);
	TUnlock(mod->fbd_Lock);

	fb_closeall(mod, win, TTRUE);
}

/*****************************************************************************/

static THOOKENTRY TTAG
fb_window_dispatch(struct THook *hook, TAPTR task, TTAG msg)
{
	switch (msg)
	{
		case TMSG_INITTASK:
			return fb_initwindow(task);
		case TMSG_RUNTASK:
			fb_dowindow(task);
			break;
	}
	return 0;
}

LOCAL void
fb_openwindow(WINDISPLAY *mod, struct TVRequest *req)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	TTAGITEM tags[2];
	struct THook taskhook;
	tags[0].tti_Tag = TTask_UserData;
	tags[0].tti_Value = (TTAG) req;
	tags[1].tti_Tag = TTAG_DONE;
	TInitHook(&taskhook, fb_window_dispatch, TNULL);
	TCreateTask(&taskhook, tags);
}

/*****************************************************************************/

static void
fb_closeall(WINDISPLAY *mod, WINWINDOW *win, TBOOL unref_font)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	struct FBPen *pen;

	if (win->fbv_HDC)
		ReleaseDC(win->fbv_HWnd, win->fbv_HDC);

	if (win->fbv_HWnd)
		DestroyWindow(win->fbv_HWnd);

	while ((pen = (struct FBPen *) TRemHead(&win->penlist)))
		TFree(pen);

	if (unref_font)
	{
		TLock(mod->fbd_Lock);
		mod->fbd_FontManager.defref--;
		TUnlock(mod->fbd_Lock);
	}

	TFree(win);
}

/*****************************************************************************/

LOCAL void
fb_closewindow(WINDISPLAY *mod, struct TVRequest *req)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	WINWINDOW *win = req->tvr_Op.CloseWindow.Window;
	if (win == TNULL)
		return;
	TSignal(win->fbv_Task, TTASK_SIG_ABORT);
	PostMessage(win->fbv_HWnd, WM_USER, 0, 0);
	TDestroy(win->fbv_Task);
}

/*****************************************************************************/

LOCAL void
fb_setinput(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *v = req->tvr_Op.SetInput.Window;
	req->tvr_Op.SetInput.OldMask = v->fbv_InputMask;
	v->fbv_InputMask = req->tvr_Op.SetInput.Mask;
	TDBPRINTF(TDB_TRACE,("Setinputmask: %08x\n", v->fbv_InputMask));
	/* spool out possible remaining messages: */
	fb_sendimessages(mod, TFALSE);
}

/*****************************************************************************/

LOCAL void
fb_allocpen(WINDISPLAY *mod, struct TVRequest *req)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	WINWINDOW *v = req->tvr_Op.AllocPen.Window;
	TUINT rgb = req->tvr_Op.AllocPen.RGB;
	struct FBPen *pen = TAlloc(mod->fbd_MemMgr, sizeof(struct FBPen));
	if (pen)
	{
		COLORREF col = RGB2COLORREF(rgb);
		pen->rgb = rgb;
		pen->col = col;
		pen->brush = CreateSolidBrush(col);
		pen->pen = CreatePen(PS_SOLID, 0, col);
		TAddTail(&v->penlist, &pen->node);
		req->tvr_Op.AllocPen.Pen = (TVPEN) pen;
		return;
	}
	req->tvr_Op.AllocPen.Pen = TVPEN_UNDEFINED;
}

/*****************************************************************************/

LOCAL void
fb_freepen(WINDISPLAY *mod, struct TVRequest *req)
{
	struct TExecBase *TExecBase = TGetExecBase(mod);
	if (req->tvr_Op.FreePen.Pen != TVPEN_UNDEFINED)
	{
		struct FBPen *pen = (struct FBPen *) req->tvr_Op.FreePen.Pen;
		TRemove(&pen->node);
		DeleteObject(pen->pen);
		DeleteObject(pen->brush);
		TFree(pen);
	}
}

/*****************************************************************************/

LOCAL void
fb_frect(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.FRect.Window;
	TVPEN pen = req->tvr_Op.FRect.Pen;
	if (pen != TVPEN_UNDEFINED)
	{
		RECT r;
		r.left = req->tvr_Op.FRect.Rect[0];
		r.top = req->tvr_Op.FRect.Rect[1];
		r.right = r.left + req->tvr_Op.FRect.Rect[2];
		r.bottom = r.top + req->tvr_Op.FRect.Rect[3];
		FillRect(win->fbv_HDC, &r, ((struct FBPen *) pen)->brush);
		win->fbv_Dirty = TTRUE;
	}
}

/*****************************************************************************/

LOCAL void
fb_line(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.Line.Window;
	TVPEN pen = req->tvr_Op.Line.Pen;
	MoveToEx(win->fbv_HDC, req->tvr_Op.Line.Rect[0],
		req->tvr_Op.Line.Rect[1], NULL);
	SelectObject(win->fbv_HDC, ((struct FBPen *) pen)->pen);
	LineTo(win->fbv_HDC, req->tvr_Op.Line.Rect[2],
		req->tvr_Op.Line.Rect[3]);
	win->fbv_Dirty = TTRUE;
}

/*****************************************************************************/

LOCAL void
fb_rect(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.Rect.Window;
	TVPEN pen = req->tvr_Op.Rect.Pen;
	if (pen != TVPEN_UNDEFINED)
	{
		TINT *r = req->tvr_Op.Rect.Rect;
		SelectObject(win->fbv_HDC, ((struct FBPen *) pen)->pen);
		SelectObject(win->fbv_HDC, GetStockObject(NULL_BRUSH));
		Rectangle(win->fbv_HDC, r[0], r[1], r[0] + r[2], r[1] + r[3]);
		win->fbv_Dirty = TTRUE;
	}
}

/*****************************************************************************/

LOCAL void
fb_plot(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.Plot.Window;
	TUINT x = req->tvr_Op.Plot.Rect[0];
	TUINT y = req->tvr_Op.Plot.Rect[1];
	struct FBPen *fgpen = (struct FBPen *) req->tvr_Op.Plot.Pen;
	SetPixel(win->fbv_HDC, x, y, fgpen->col);
	win->fbv_Dirty = TTRUE;
}

/*****************************************************************************/

LOCAL void
fb_drawstrip(WINDISPLAY *mod, struct TVRequest *req)
{
	TINT i;
	WINWINDOW *win = req->tvr_Op.Strip.Window;
	TINT *array = req->tvr_Op.Strip.Array;
	TINT num = req->tvr_Op.Strip.Num;
	TTAGITEM *tags = req->tvr_Op.Strip.Tags;
	TVPEN *penarray = (TVPEN *) TGetTag(tags, TVisual_PenArray, TNULL);
	POINT points[3];

	if (num < 3) return;

	if (penarray)
	{
		SelectObject(win->fbv_HDC, ((struct FBPen *) penarray[2])->pen);
		SelectObject(win->fbv_HDC, ((struct FBPen *) penarray[2])->brush);
	}
	else
	{
		TVPEN pen = (TVPEN) TGetTag(tags, TVisual_Pen, TVPEN_UNDEFINED);
		SelectObject(win->fbv_HDC, ((struct FBPen *) pen)->pen);
		SelectObject(win->fbv_HDC, ((struct FBPen *) pen)->brush);
	}

	Polygon(win->fbv_HDC, (LPPOINT) array, 3);

	if (num > 3)
	{
		points[0].x = array[0];
		points[0].y = array[1];
		points[1].x = array[2];
		points[1].y = array[3];
		points[2].x = array[4];
		points[2].y = array[5];
		for (i = 3; i < num; ++i)
		{
			if (penarray)
			{
				SelectObject(win->fbv_HDC, ((struct FBPen *) penarray[i])->pen);
				SelectObject(win->fbv_HDC, ((struct FBPen *) penarray[i])->brush);
			}
			points[0].x = points[1].x;
			points[0].y = points[1].y;
			points[1].x = points[2].x;
			points[1].y = points[2].y;
			points[2].x = array[i * 2];
			points[2].y = array[i * 2 + 1];
			Polygon(win->fbv_HDC, points, 3);
		}
	}
	win->fbv_Dirty = TTRUE;
}

/*****************************************************************************/

LOCAL void
fb_drawfan(WINDISPLAY *mod, struct TVRequest *req)
{
	TINT i;
	WINWINDOW *win = req->tvr_Op.Fan.Window;
	TINT *array = req->tvr_Op.Fan.Array;
	TINT num = req->tvr_Op.Fan.Num;
	TTAGITEM *tags = req->tvr_Op.Fan.Tags;
	TVPEN *penarray = (TVPEN *) TGetTag(tags, TVisual_PenArray, TNULL);
	POINT points[3];

	if (num < 3) return;

	if (penarray)
	{
		SelectObject(win->fbv_HDC, ((struct FBPen *) penarray[2])->pen);
		SelectObject(win->fbv_HDC, ((struct FBPen *) penarray[2])->brush);
	}
	else
	{
		TVPEN pen = (TVPEN) TGetTag(tags, TVisual_Pen, TVPEN_UNDEFINED);
		SelectObject(win->fbv_HDC, ((struct FBPen *) pen)->pen);
		SelectObject(win->fbv_HDC, ((struct FBPen *) pen)->brush);
	}

	Polygon(win->fbv_HDC, (LPPOINT) array, 3);

	if (num > 3)
	{
		points[0].x = array[0];
		points[0].y = array[1];
		points[1].x = array[2];
		points[1].y = array[3];
		points[2].x = array[4];
		points[2].y = array[5];
		for (i = 3; i < num; ++i)
		{
			if (penarray)
			{
				SelectObject(win->fbv_HDC, ((struct FBPen *) penarray[i])->pen);
				SelectObject(win->fbv_HDC, ((struct FBPen *) penarray[i])->brush);
			}
			points[1].x = points[2].x;
			points[1].y = points[2].y;
			points[2].x = array[i * 2];
			points[2].y = array[i * 2 + 1];
			Polygon(win->fbv_HDC, points, 3);
		}
	}
	win->fbv_Dirty = TTRUE;
}

/*****************************************************************************/

LOCAL void
fb_copyarea(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.CopyArea.Window;
	struct THook *exposehook = (struct THook *)
		TGetTag(req->tvr_Op.CopyArea.Tags, TVisual_ExposeHook, TNULL);
	TINT *sr = req->tvr_Op.CopyArea.Rect;
	TINT dx = req->tvr_Op.CopyArea.DestX - sr[0];
	TINT dy = req->tvr_Op.CopyArea.DestY - sr[1];
	RECT r;

	r.left = sr[4];
	r.top = sr[5];
	r.right = sr[4] + sr[2];
	r.bottom = sr[5] + sr[3];

	if (exposehook)
	{
		RGNDATAHEADER *rdh = (RGNDATAHEADER *) win->fbv_RegionData;
		RECT *rd = (RECT *) (rdh + 1);
		HRGN updateregion = CreateRectRgn(0, 0, 0, 0);
		ScrollDC(win->fbv_HDC, dx, dy, &r, &r, updateregion, NULL);
		if (GetRegionData(updateregion, 1024, (LPRGNDATA) rdh))
		{
			TUINT i;
			for (i = 0; i < rdh->nCount; ++i)
				TCallHookPkt(exposehook, win, (TTAG) (rd + i));
		}
		else
		{
			TDBPRINTF(TDB_WARN,("Regiondata buffer too small\n"));
			InvalidateRgn(win->fbv_HWnd, updateregion, FALSE);
		}
		DeleteObject(updateregion);
	}
	else
		ScrollDC(win->fbv_HDC, dx, dy, &r, &r, NULL, NULL);

	win->fbv_Dirty = TTRUE;
}

/*****************************************************************************/

LOCAL void
fb_setcliprect(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.ClipRect.Window;
	RECT *cr = &win->fbv_ClipRect;
	HRGN rgn;
	cr->left = req->tvr_Op.ClipRect.Rect[0];
	cr->top = req->tvr_Op.ClipRect.Rect[1];
	cr->right = cr->left + req->tvr_Op.ClipRect.Rect[2];
	cr->bottom = cr->top + req->tvr_Op.ClipRect.Rect[3];
	rgn = CreateRectRgnIndirect(cr);
	SelectClipRgn(win->fbv_HDC, rgn);
	DeleteObject(rgn);
}

/*****************************************************************************/

LOCAL void
fb_unsetcliprect(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.ClipRect.Window;
	RECT *cr = &win->fbv_ClipRect;
	SelectClipRgn(win->fbv_HDC, NULL);
	cr->left = 0;
	cr->top = 0;
	cr->right = win->fbv_Width;
	cr->bottom = win->fbv_Height;
}

/*****************************************************************************/

LOCAL void
fb_clear(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.Clear.Window;
	TVPEN pen = req->tvr_Op.Clear.Pen;
	if (pen != TVPEN_UNDEFINED)
	{
		RECT r;
		r.left = 0;
		r.top = 0;
		r.right = win->fbv_Width;
		r.bottom = win->fbv_Height;
		FillRect(win->fbv_HDC, &r, ((struct FBPen *) pen)->brush);
		win->fbv_Dirty = TTRUE;
	}
}

/*****************************************************************************/

LOCAL void
fb_drawbuffer(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.DrawBuffer.Window;
	TINT *rrect = req->tvr_Op.DrawBuffer.RRect;
	BITMAPINFOHEADER *bmi = &win->fbv_DrawBitMap;
	bmi->biWidth = req->tvr_Op.DrawBuffer.TotWidth;
	bmi->biHeight = -rrect[3];
	SetDIBitsToDevice(win->fbv_HDC,
		rrect[0], rrect[1],
		rrect[2], rrect[3],
		0, 0,
		0, rrect[3],
		req->tvr_Op.DrawBuffer.Buf,
		(const void *) bmi,
		DIB_RGB_COLORS);
	win->fbv_Dirty = TTRUE;
}

/*****************************************************************************/

static THOOKENTRY TTAG
getattrfunc(struct THook *hook, TAPTR obj, TTAG msg)
{
	struct attrdata *data = hook->thk_Data;
	TTAGITEM *item = obj;
	WINWINDOW *v = data->v;

	switch (item->tti_Tag)
	{
		default:
			return TTRUE;
		case TVisual_UserData:
			*((TTAG *) item->tti_Value) = v->fbv_UserData;
			break;
		case TVisual_Width:
			*((TINT *) item->tti_Value) = v->fbv_Width;
			break;
		case TVisual_Height:
			*((TINT *) item->tti_Value) = v->fbv_Height;
			break;
		case TVisual_WinLeft:
			*((TINT *) item->tti_Value) = v->fbv_Left;
			break;
		case TVisual_WinTop:
			*((TINT *) item->tti_Value) = v->fbv_Top;
			break;
		case TVisual_MinWidth:
			*((TINT *) item->tti_Value) = v->fbv_MinWidth;
			break;
		case TVisual_MinHeight:
			*((TINT *) item->tti_Value) = v->fbv_MinHeight;
			break;
		case TVisual_MaxWidth:
			*((TINT *) item->tti_Value) = v->fbv_MaxWidth;
			break;
		case TVisual_MaxHeight:
			*((TINT *) item->tti_Value) = v->fbv_MaxHeight;
			break;
		case TVisual_Device:
			*((TAPTR *) item->tti_Value) = data->mod;
			break;
		case TVisual_Window:
			*((TAPTR *) item->tti_Value) = v;
			break;
	}
	data->num++;
	return TTRUE;
}

LOCAL void
fb_getattrs(WINDISPLAY *mod, struct TVRequest *req)
{
	struct attrdata data;
	struct THook hook;
	RECT wrect;
	WINWINDOW *win = req->tvr_Op.GetAttrs.Window;

	data.v = win;
	data.num = 0;
	data.mod = mod;
	TInitHook(&hook, getattrfunc, &data);

	GetWindowRect(win->fbv_HWnd, &wrect);

	win->fbv_Left = wrect.left + win->fbv_BorderLeft;
	win->fbv_Top = wrect.top + win->fbv_BorderHeight;
	win->fbv_Width = wrect.right - wrect.left - win->fbv_BorderWidth;
	win->fbv_Height = wrect.bottom - wrect.top - win->fbv_BorderHeight;

	TForEachTag(req->tvr_Op.GetAttrs.Tags, &hook);
	req->tvr_Op.GetAttrs.Num = data.num;
}

/*****************************************************************************/

static THOOKENTRY TTAG
setattrfunc(struct THook *hook, TAPTR obj, TTAG msg)
{
	struct attrdata *data = hook->thk_Data;
	TTAGITEM *item = obj;
	WINWINDOW *v = data->v;
	switch (item->tti_Tag)
	{
		default:
			return TTRUE;
		case TVisual_Width:
			data->neww = (TINT) item->tti_Value;
			break;
		case TVisual_Height:
			data->newh = (TINT) item->tti_Value;
			break;
		case TVisual_MinWidth:
			v->fbv_MinWidth = (TINT) item->tti_Value;
			break;
		case TVisual_MinHeight:
			v->fbv_MinHeight = (TINT) item->tti_Value;
			break;
		case TVisual_MaxWidth:
			v->fbv_MaxWidth = (TINT) item->tti_Value;
			break;
		case TVisual_MaxHeight:
			v->fbv_MaxHeight = (TINT) item->tti_Value;
			break;
	}
	data->num++;
	return TTRUE;
}

LOCAL void
fb_setattrs(WINDISPLAY *mod, struct TVRequest *req)
{
	struct attrdata data;
	struct THook hook;
	WINWINDOW *win = req->tvr_Op.SetAttrs.Window;
	TINT neww, newh;
	data.v = win;
	data.num = 0;
	data.mod = mod;
	data.neww = -1;
	data.newh = -1;
	TInitHook(&hook, setattrfunc, &data);
	TForEachTag(req->tvr_Op.SetAttrs.Tags, &hook);
	req->tvr_Op.SetAttrs.Num = data.num;

	win_getminmax(win, &win->fbv_MinWidth, &win->fbv_MinHeight,
		&win->fbv_MaxWidth, &win->fbv_MaxHeight, TFALSE);
	neww = data.neww < 0 ? (TINT) win->fbv_Width : data.neww;
	newh = data.newh < 0 ? (TINT) win->fbv_Height : data.newh;

	if (neww < win->fbv_MinWidth || newh < win->fbv_MinHeight)
	{
		neww = TMAX(neww, win->fbv_MinWidth);
		newh = TMAX(newh, win->fbv_MinHeight);
		neww += win->fbv_BorderWidth;
		newh += win->fbv_BorderHeight;
		SetWindowPos(win->fbv_HWnd, NULL, 0, 0, neww, newh, SWP_NOMOVE);
	}
}

/*****************************************************************************/

struct drawdata
{
	WINWINDOW *v;
	WINDISPLAY *mod;
	TINT x0, x1, y0, y1;
	struct FBPen *bgpen;
	struct FBPen *fgpen;
};

static THOOKENTRY TTAG
drawtagfunc(struct THook *hook, TAPTR obj, TTAG msg)
{
	struct drawdata *data = hook->thk_Data;
	TTAGITEM *item = obj;

	switch (item->tti_Tag)
	{
		case TVisualDraw_X0:
			data->x0 = item->tti_Value;
			break;
		case TVisualDraw_Y0:
			data->y0 = item->tti_Value;
			break;
		case TVisualDraw_X1:
			data->x1 = item->tti_Value;
			break;
		case TVisualDraw_Y1:
			data->y1 = item->tti_Value;
			break;
		case TVisualDraw_NewX:
			data->x0 = data->x1;
			data->x1 = item->tti_Value;
			break;
		case TVisualDraw_NewY:
			data->y0 = data->y1;
			data->y1 = item->tti_Value;
			break;
		case TVisualDraw_FgPen:
			data->fgpen = (struct FBPen *) item->tti_Value;
			SelectObject(data->v->fbv_HDC, data->fgpen->pen);
			break;
		case TVisualDraw_BgPen:
			data->bgpen = (struct FBPen *) item->tti_Value;
			break;
		case TVisualDraw_Command:
			switch (item->tti_Value)
			{
				case TVCMD_FRECT:
					if (data->fgpen)
					{
						RECT r;
						r.left = data->x0;
						r.top = data->y0;
						r.right = data->x0 + data->x1;
						r.bottom = data->y0 + data->y1;
						FillRect(data->v->fbv_HDC, &r, data->fgpen->brush);
					}
					break;

				case TVCMD_RECT:
				{
// 					TINT r[] = { data->x0, data->y0, data->x1-data->x0, data->y1-data->y0 };
// 					struct FBPen *pen = (struct FBPen *) data->v->fgpen;
// 					fbp_drawrect(data->v, r, pen);
					break;
				}
				case TVCMD_LINE:
					if (data->fgpen)
					{
						MoveToEx(data->v->fbv_HDC, data->x0, data->y0, NULL);
						LineTo(data->v->fbv_HDC, data->x1, data->y1);
					}
					break;
			}

			break;
	}
	return TTRUE;
}

LOCAL void
fb_drawtags(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.DrawTags.Window;
	struct THook hook;
	struct drawdata data;
	data.v = win;
	data.mod = mod;
	data.fgpen = TNULL;
	data.bgpen = TNULL;
	TInitHook(&hook, drawtagfunc, &data);
	TForEachTag(req->tvr_Op.DrawTags.Tags, &hook);
	win->fbv_Dirty = TTRUE;
}

/*****************************************************************************/

LOCAL void
fb_drawtext(WINDISPLAY *mod, struct TVRequest *req)
{
	WINWINDOW *win = req->tvr_Op.Text.Window;
	TSTRPTR text = req->tvr_Op.Text.Text;
	TINT len = req->tvr_Op.Text.Length;
	TUINT x = req->tvr_Op.Text.X;
	TUINT y = req->tvr_Op.Text.Y;
	struct FBPen *fgpen = (struct FBPen *) req->tvr_Op.Text.FgPen;
	TSTRPTR latin = fb_utf8tolatin(mod, text, len, &len);
	SetTextColor(win->fbv_HDC, fgpen->col);
	TextOut(win->fbv_HDC, x, y, latin, len);
	win->fbv_Dirty = TTRUE;
}

/*****************************************************************************/

LOCAL void
fb_setfont(WINDISPLAY *mod, struct TVRequest *req)
{
	fb_hostsetfont(mod, req->tvr_Op.SetFont.Window,
		req->tvr_Op.SetFont.Font);
}

/*****************************************************************************/

LOCAL void
fb_openfont(WINDISPLAY *mod, struct TVRequest *req)
{
	req->tvr_Op.OpenFont.Font =
		fb_hostopenfont(mod, req->tvr_Op.OpenFont.Tags);
	TDBPRINTF(TDB_INFO,("font opened: %p\n", req->tvr_Op.OpenFont.Font));
}

/*****************************************************************************/

LOCAL void
fb_textsize(WINDISPLAY *mod, struct TVRequest *req)
{
	TINT len;
	TSTRPTR text = req->tvr_Op.TextSize.Text;
	TSTRPTR latin = fb_utf8tolatin(mod, text, strlen(text), &len);
	req->tvr_Op.TextSize.Width = fb_hosttextsize(mod,
		req->tvr_Op.TextSize.Font, latin, len);
}

/*****************************************************************************/

LOCAL void fb_getfontattrs(WINDISPLAY *mod, struct TVRequest *req)
{
	struct attrdata data;
	data.num = 0;
	struct THook hook;
	SelectObject(mod->fbd_DeviceHDC, req->tvr_Op.GetFontAttrs.Font);
	if (GetTextMetrics(mod->fbd_DeviceHDC, &data.textmetric))
	{
		data.mod = mod;
		TInitHook(&hook, fb_hostgetfattrfunc, &data);
		TForEachTag(req->tvr_Op.GetFontAttrs.Tags, &hook);
	}
	req->tvr_Op.GetFontAttrs.Num = data.num;
}

/*****************************************************************************/

LOCAL void
fb_closefont(WINDISPLAY *mod, struct TVRequest *req)
{
	fb_hostclosefont(mod, req->tvr_Op.CloseFont.Font);
}

/*****************************************************************************/

LOCAL void
fb_queryfonts(WINDISPLAY *mod, struct TVRequest *req)
{
	req->tvr_Op.QueryFonts.Handle =
		fb_hostqueryfonts(mod, req->tvr_Op.QueryFonts.Tags);
}

/*****************************************************************************/

LOCAL void
fb_getnextfont(WINDISPLAY *mod, struct TVRequest *req)
{
	req->tvr_Op.GetNextFont.Attrs =
		fb_hostgetnextfont(mod, req->tvr_Op.GetNextFont.Handle);
}
