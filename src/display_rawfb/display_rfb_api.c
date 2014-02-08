
/*
**	display_rfb_api.c - Raw framebuffer display driver
**	Written by Franciska Schulze <fschulze at schulze-mueller.de>
**	and Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in teklib/COPYRIGHT
*/

#include "display_rfb_mod.h"

/*****************************************************************************/

LOCAL void rfb_focuswindow(RFBDISPLAY *mod, RFBWINDOW *v)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TIMSG *imsg;
	
	if (v == mod->rfb_FocusWindow || (v && v->borderless))
		return;
	
	if (mod->rfb_FocusWindow)
	{
		if (rfb_getimsg(mod, mod->rfb_FocusWindow, &imsg, TITYPE_FOCUS))
		{
			imsg->timsg_Code = 0;
			TPutMsg(mod->rfb_FocusWindow->rfbw_IMsgPort, TNULL, imsg);
		}
	}
	
	if (v)
	{
		if (rfb_getimsg(mod, v, &imsg, TITYPE_FOCUS))
		{
			imsg->timsg_Code = 1;
			TPutMsg(v->rfbw_IMsgPort, TNULL, imsg);
		}
	}
	
	mod->rfb_FocusWindow = v;
}

/*****************************************************************************/

LOCAL void rfb_openvisual(RFBDISPLAY *mod, struct TVRequest *req)
{
	TAPTR TExecBase = TGetExecBase(mod);
	TTAGITEM *tags = req->tvr_Op.OpenWindow.Tags;
	TINT width, height;
	RFBWINDOW *v;
	TIMSG *imsg;
	
	req->tvr_Op.OpenWindow.Window = TNULL;
	
	v = TAlloc0(mod->rfb_MemMgr, sizeof(RFBWINDOW));
	if (v == TNULL)
		return;

	if (TISLISTEMPTY(&mod->rfb_VisualList))
	{
		/* Open root window */
		
		TINT minw = (TINT) TGetTag(tags, TVisual_MinWidth, 0);
		TINT minh = (TINT) TGetTag(tags, TVisual_MinHeight, 0);

		width = (TINT) TGetTag(tags, TVisual_Width, 
			minw ? TMAX(minw, RFB_DEF_WIDTH) : 
				TMAX(mod->rfb_Width, RFB_DEF_WIDTH));
		height = (TINT) TGetTag(tags, TVisual_Height, 
			minh ? TMAX(minh, RFB_DEF_HEIGHT) : 
				TMAX(mod->rfb_Height, RFB_DEF_HEIGHT));
		
		mod->rfb_Width = width;
		mod->rfb_Height = height;
		mod->rfb_Modulo = TGetTag(tags, TVisual_Modulo, 0);
		mod->rfb_BytesPerPixel = sizeof(RFBPixel);
		mod->rfb_BytesPerLine =
			(mod->rfb_Width + mod->rfb_Modulo) * mod->rfb_BytesPerPixel;
		mod->rfb_BufPtr = (RFBPixel *) TGetTag(tags, TVisual_BufPtr, TNULL);
		if (mod->rfb_BufPtr == TNULL)
		{
			mod->rfb_BufPtr = TAlloc0(mod->rfb_MemMgr,
				mod->rfb_BytesPerLine * mod->rfb_Height);
			if (mod->rfb_BufPtr == TNULL)
				return;
			/* we own the buffer: */
			mod->rfb_BufferOwner = TTRUE;
		}

#if defined(ENABLE_VNCSERVER)
		rfb_vnc_init(mod);
#endif
		v->rfbw_WinRect[0] = 0;
		v->rfbw_WinRect[1] = 0;
		v->rfbw_WinRect[2] = width - 1;
		v->rfbw_WinRect[3] = height - 1;

		/* Open rendering instance: */
		if (mod->rfb_RndDevice)
		{
			TTAGITEM subtags[4];
			/* we are proxy, want all input, except intervals: */
			subtags[0].tti_Tag = TVisual_EventMask;
			subtags[0].tti_Value = TITYPE_ALL & ~TITYPE_INTERVAL; 
			subtags[1].tti_Tag = TVisual_Width;
			subtags[1].tti_Value = width;
			subtags[2].tti_Tag = TVisual_Height;
			subtags[2].tti_Value = height; 
			subtags[3].tti_Tag = TTAG_MORE;
			subtags[3].tti_Value = (TTAG) tags;
			mod->rfb_RndRequest->tvr_Req.io_Device = mod->rfb_RndDevice;
			mod->rfb_RndRequest->tvr_Req.io_Command = TVCMD_OPENWINDOW;
			mod->rfb_RndRequest->tvr_Req.io_ReplyPort = mod->rfb_RndRPort;
			mod->rfb_RndRequest->tvr_Op.OpenWindow.Window = TNULL;
			mod->rfb_RndRequest->tvr_Op.OpenWindow.Tags = subtags;
			/* place our own ("proxy") messageport inbetween */
			mod->rfb_RndRequest->tvr_Op.OpenWindow.IMsgPort = 
				mod->rfb_RndIMsgPort;
			TDoIO(&mod->rfb_RndRequest->tvr_Req);
			mod->rfb_RndInstance =
				mod->rfb_RndRequest->tvr_Op.OpenWindow.Window;
		}
	}
	else
	{
		/* Not root window: */
		TINT minw = (TINT) TGetTag(tags, TVisual_MinWidth, -1);
		TINT minh = (TINT) TGetTag(tags, TVisual_MinHeight, -1);
		TINT maxw = (TINT) TGetTag(tags, TVisual_MaxWidth, 1000000);
		TINT maxh = (TINT) TGetTag(tags, TVisual_MaxHeight, 1000000);
		
		width = (TINT) TGetTag(tags, TVisual_Width, RFB_DEF_WIDTH);
		height = (TINT) TGetTag(tags, TVisual_Height, RFB_DEF_HEIGHT);
		width = TCLAMP(minw, width, maxw);
		height = TCLAMP(minh, height, maxh);
		width = TMIN(width, mod->rfb_Width);
		height = TMIN(height, mod->rfb_Height);
		
		if (TGetTag(tags, TVisual_FullScreen, TFALSE))
		{
			v->rfbw_WinRect[0] = 0;
			v->rfbw_WinRect[1] = 0;
			width = mod->rfb_Width;
			height = mod->rfb_Height;
		}
		else
		{
			TINT wx = (TINT) TGetTag(tags, TVisual_WinLeft, 0);
			TINT wy = (TINT) TGetTag(tags, TVisual_WinTop, 0);
			
			if (wx == 0) wx = (mod->rfb_Width - width) / 2;
			if (wy == 0) wy = (mod->rfb_Height - height) / 2;
				
			v->rfbw_WinRect[0] = wx;
			v->rfbw_WinRect[1] = wy;
		}
	}
	
	v->rfbw_WinRect[2] = v->rfbw_WinRect[0] + width - 1;
	v->rfbw_WinRect[3] = v->rfbw_WinRect[1] + height - 1;
	
	rfb_region_intersect(&v->rfbw_WinRect[0], &v->rfbw_WinRect[1], 
		&v->rfbw_WinRect[2], &v->rfbw_WinRect[3], 
		0, 0, mod->rfb_Width - 1, mod->rfb_Height - 1);

	v->rfbw_ClipRect[0] = v->rfbw_WinRect[0];
	v->rfbw_ClipRect[1] = v->rfbw_WinRect[1];
	v->rfbw_ClipRect[2] = v->rfbw_WinRect[2];
	v->rfbw_ClipRect[3] = v->rfbw_WinRect[3];
	
	v->rfbw_Modulo = mod->rfb_Modulo + (mod->rfb_Width - width);
	v->rfbw_PixelPerLine = width + v->rfbw_Modulo;
	
	v->rfbw_InputMask = (TUINT) TGetTag(tags, TVisual_EventMask, 0);
	v->userdata = TGetTag(tags, TVisual_UserData, TNULL);
	
	v->borderless = TGetTag(tags, TVisual_Borderless, TFALSE);
	
	
	v->rfbw_IMsgPort = req->tvr_Op.OpenWindow.IMsgPort;

	TInitList(&v->penlist);
	v->bgpen = TVPEN_UNDEFINED;
	v->fgpen = TVPEN_UNDEFINED;

	v->rfbw_BufPtr = mod->rfb_BufPtr;

	/* add window on top of window stack: */
	TLock(mod->rfb_Lock);
	TAddHead(&mod->rfb_VisualList, &v->rfbw_Node);
	rfb_focuswindow(mod, v);
	TUnlock(mod->rfb_Lock);

	/* Reply instance: */
	req->tvr_Op.OpenWindow.Window = v;		
	
	/* send refresh message: */
	if (rfb_getimsg(mod, v, &imsg, TITYPE_REFRESH))
	{
		imsg->timsg_X = 0;
		imsg->timsg_Y = 0;
		imsg->timsg_Width = width;
		imsg->timsg_Height = height;
		TPutMsg(v->rfbw_IMsgPort, TNULL, imsg);
	}
}

/*****************************************************************************/

LOCAL TBOOL rfb_ispointobscured(RFBDISPLAY *mod, TINT x, TINT y, RFBWINDOW *v)
{
	if (x < 0 || x >= mod->rfb_Width || y < 0 || y >= mod->rfb_Height)
		return TTRUE;
	
	if (x < v->rfbw_ClipRect[0] || x > v->rfbw_ClipRect[2] ||
		y < v->rfbw_ClipRect[1] || y > v->rfbw_ClipRect[3])
		return TTRUE;
	
	struct TNode *next, *node = mod->rfb_VisualList.tlh_Head;
	for (; (next = node->tln_Succ); node = next)
	{
		RFBWINDOW *bv = (RFBWINDOW *) node;
		if (bv == v)
			return TFALSE;
		if (bv->rfbw_WinRect[0] <= x && x <= bv->rfbw_WinRect[2] &&
			bv->rfbw_WinRect[1] <= y && y <= bv->rfbw_WinRect[3])
			return TTRUE;
	}
	assert(TFALSE);
	return TFALSE;
}

/*****************************************************************************/

LOCAL struct Region *rfb_getlayers(RFBDISPLAY *mod, RFBWINDOW *v,
	TINT dx, TINT dy)
{
	struct Pool *pool = &mod->rfb_RectPool;
	struct Region *A = rfb_region_new(pool, TNULL);
	if (A)
	{
		TINT drect[4];
		struct TNode *next, *node = mod->rfb_VisualList.tlh_Head;
		for (; (next = node->tln_Succ); node = next)
		{
			RFBWINDOW *bv = (RFBWINDOW *) node;
			if (bv == v)
				break;
			drect[0] = bv->rfbw_WinRect[0] + dx;
			drect[1] = bv->rfbw_WinRect[1] + dy;
			drect[2] = bv->rfbw_WinRect[2] + dx;
			drect[3] = bv->rfbw_WinRect[3] + dy;
			if (!rfb_region_orrect(pool, A, drect, TFALSE))
			{
				rfb_region_destroy(pool, A);
				return TNULL;
			}
		}
	}
	return A;
}

/*****************************************************************************/

LOCAL struct Region *rfb_getlayermask(RFBDISPLAY *mod, TINT *crect,
	RFBWINDOW *v, TINT dx, TINT dy)
{
	struct Pool *pool = &mod->rfb_RectPool;
	struct Region *A = rfb_region_new(pool, crect);
	if (A)
	{
		TBOOL success = TFALSE;
		struct Region *L = rfb_getlayers(mod, v, dx, dy);
		if (L)
		{
			success = rfb_region_subregion(pool, A, L);
			rfb_region_destroy(pool, L);
		}
		if (!success)
		{
			rfb_region_destroy(pool, A);
			A = TNULL;
		}
	}

	return A;
}

/*****************************************************************************/
/*
**	damage window stack with rectangle; if window is not NULL, the damage
**	starts below that window in the stack
*/

LOCAL TBOOL rfb_damage(RFBDISPLAY *mod, TINT drect[], RFBWINDOW *v)
{
	TAPTR TExecBase = TGetExecBase(mod);
	struct Pool *pool = &mod->rfb_RectPool;
	struct Region *B, *A = rfb_region_new(pool, drect);
	if (A == TNULL) return TFALSE;

	TDBPRINTF(TDB_INFO,("incoming damage: %d %d %d %d\n",
		drect[0], drect[1], drect[2], drect[3]));
	
	/* traverse window stack; refresh B where A and B overlap ; A = A - B */
	
	struct TNode *next, *node = mod->rfb_VisualList.tlh_Head;
	TBOOL success = TTRUE;
	TBOOL below = TFALSE;
	
	TLock(mod->rfb_InstanceLock);
	
	for (; success && !rfb_region_isempty(pool, A) &&
		(next = node->tln_Succ); node = next)
	{
		RFBWINDOW *bv = (RFBWINDOW *) node;
		
		if (v && !below)
		{
			if (bv == v)
				below = TTRUE;
			else
				/* above: subtract current from rect to be damaged: */
				success = rfb_region_subrect(pool, A, bv->rfbw_WinRect);
			continue;
		}
		
		if (bv->rfbw_InputMask & TITYPE_REFRESH)
		{
			success = TFALSE;
			B = rfb_region_new(pool, bv->rfbw_WinRect);
			if (B)
			{
				if (rfb_region_andregion(pool, B, A))
				{
					struct TNode *next, *node = B->rg_Rects.rl_List.tlh_Head;
					for (; (next = node->tln_Succ); node = next)
					{
						TIMSG *imsg;
						struct RectNode *r = (struct RectNode *) node;
						if (rfb_getimsg(mod, bv, &imsg, TITYPE_REFRESH))
						{
							TDBPRINTF(TDB_TRACE,("send refresh %d %d %d %d\n",
								r->rn_Rect[0], r->rn_Rect[1], 
						   		r->rn_Rect[2], r->rn_Rect[3]));
							
							imsg->timsg_X = r->rn_Rect[0];
							imsg->timsg_Y = r->rn_Rect[1];
							imsg->timsg_Width =
								r->rn_Rect[2] - r->rn_Rect[0] + 1;
							imsg->timsg_Height =
								r->rn_Rect[3] - r->rn_Rect[1] + 1;
							imsg->timsg_X -= bv->rfbw_WinRect[0];
							
							imsg->timsg_Y -= bv->rfbw_WinRect[1];
							TPutMsg(bv->rfbw_IMsgPort, TNULL, imsg);
						}
					}
					success = TTRUE;
				}
				rfb_region_destroy(pool, B);
			}
		}
		
		if (success)
			success = rfb_region_subrect(pool, A, bv->rfbw_WinRect);
	}
	
	TUnlock(mod->rfb_InstanceLock);
	
	rfb_region_destroy(pool, A);
	return success;
}

/*****************************************************************************/

LOCAL void rfb_closevisual(RFBDISPLAY *mod, struct TVRequest *req)
{
	TAPTR TExecBase = TGetExecBase(mod);
	struct RFBPen *pen;
	RFBWINDOW *v = req->tvr_Op.CloseWindow.Window;
	if (v == TNULL) return;

	/*rfb_focuswindow(mod, v, TFALSE);*/
	
	rfb_damage(mod, v->rfbw_WinRect, v);

	TLock(mod->rfb_Lock);
	
	if (mod->rfb_FocusWindow == v)
		mod->rfb_FocusWindow = TNULL;
	
	TRemove(&v->rfbw_Node);

	while ((pen = (struct RFBPen *) TRemHead(&v->penlist)))
	{
		/* free pens */
		TRemove(&pen->node);
		TFree(pen);
	}

	if (TISLISTEMPTY(&mod->rfb_VisualList))
	{
		/* last window: */
		if (mod->rfb_RndDevice)
		{
			mod->rfb_RndRequest->tvr_Req.io_Command = TVCMD_CLOSEWINDOW;
			mod->rfb_RndRequest->tvr_Op.CloseWindow.Window =
				mod->rfb_RndInstance;
			TDoIO(&mod->rfb_RndRequest->tvr_Req);
		}
#if defined(ENABLE_VNCSERVER)
		rfb_vnc_exit(mod);
#endif
	}
	TUnlock(mod->rfb_Lock);
	
	TFree(v);
}

/*****************************************************************************/

LOCAL void rfb_setinput(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.SetInput.Window;
	struct TNode *node, *next;
	TUINT newmask = 0;

	req->tvr_Op.SetInput.OldMask = v->rfbw_InputMask;
	v->rfbw_InputMask = req->tvr_Op.SetInput.Mask;
	
	for (node = mod->rfb_VisualList.tlh_Head; 
		 (next = node->tln_Succ); node = next)
	{
		RFBWINDOW *v = (RFBWINDOW *) node;
		newmask |= v->rfbw_InputMask;
	}
	mod->rfb_InputMask = newmask;
}

/*****************************************************************************/

LOCAL void rfb_flush_clients(RFBDISPLAY *mod, TBOOL also_external)
{
	TAPTR TExecBase = mod->rfb_ExecBase;
	struct Region *D = mod->rfb_DirtyRegion;
	if (D)
	{
		if (D->rg_Rects.rl_NumNodes > 0)
		{
			struct TNode *next, *node;
			
#if defined(ENABLE_VNCSERVER)
			if (also_external && mod->rfb_VNCTask)
				rfb_vnc_flush(mod, D);
#endif
			if (mod->rfb_RndDevice)
			{
				TTAGITEM tags[2];
				tags[0].tti_Tag = TVisual_PixelFormat;
				tags[0].tti_Value = RFBPIXFMT;
				tags[1].tti_Tag = TTAG_DONE;
				
				/* TODO: do multiple flushes asynchronously */
				
				struct TVRequest *req = mod->rfb_RndRequest;
				req->tvr_Req.io_Command = TVCMD_DRAWBUFFER;
				req->tvr_Op.DrawBuffer.Window = mod->rfb_RndInstance;
				req->tvr_Op.DrawBuffer.Tags = tags;
				req->tvr_Op.DrawBuffer.TotWidth = mod->rfb_Width;
				
				node = D->rg_Rects.rl_List.tlh_Head;
				for (; (next = node->tln_Succ); node = next)
				{
					struct RectNode *r = (struct RectNode *) node;
					TINT x0 = r->rn_Rect[0];
					TINT y0 = r->rn_Rect[1];
					TINT x1 = r->rn_Rect[2];
					TINT y1 = r->rn_Rect[3];
					req->tvr_Op.DrawBuffer.RRect[0] = x0;
					req->tvr_Op.DrawBuffer.RRect[1] = y0;
					req->tvr_Op.DrawBuffer.RRect[2] = x1 - x0 + 1;
					req->tvr_Op.DrawBuffer.RRect[3] = y1 - y0 + 1;
					req->tvr_Op.DrawBuffer.Buf =
						mod->rfb_BufPtr + (y0 * mod->rfb_Width + x0);
					TDoIO(&req->tvr_Req);
				}
				
				req->tvr_Req.io_Command = TVCMD_FLUSH;
				req->tvr_Op.Flush.Window = mod->rfb_RndInstance;
				req->tvr_Op.Flush.Rect[0] = 0;
				req->tvr_Op.Flush.Rect[1] = 0;
				req->tvr_Op.Flush.Rect[2] = -1;
				req->tvr_Op.Flush.Rect[3] = -1;
				TDoIO(&req->tvr_Req);
			}

			rfb_region_destroy(&mod->rfb_RectPool, D);
			mod->rfb_DirtyRegion = TNULL;
		}
	}
}

LOCAL void rfb_flush(RFBDISPLAY *mod, struct TVRequest *req)
{
	rfb_flush_clients(mod, TTRUE);
}

LOCAL void rfb_copyrect_sub(RFBDISPLAY *mod, TINT *rect, TINT dx, TINT dy)
{
	if (!mod->rfb_RndDevice)
		return;
	TAPTR TExecBase = mod->rfb_ExecBase;
	struct TVRequest *req = mod->rfb_RndRequest;
	req->tvr_Req.io_Command = TVCMD_COPYAREA;
	TINT x0 = rect[0] - dx;
	TINT y0 = rect[1] - dy;
	TINT x1 = rect[2] - dx;
	TINT y1 = rect[3] - dy;
	req->tvr_Op.CopyArea.Window = mod->rfb_RndInstance;
	req->tvr_Op.CopyArea.Rect[0] = x0;
	req->tvr_Op.CopyArea.Rect[1] = y0;
	req->tvr_Op.CopyArea.Rect[2] = x1 - x0 + 1;
	req->tvr_Op.CopyArea.Rect[3] = y1 - y0 + 1;
	req->tvr_Op.CopyArea.DestX = x0 + dx;
	req->tvr_Op.CopyArea.DestY = y0 + dy;
	req->tvr_Op.CopyArea.Tags = TNULL;
	TDoIO(&req->tvr_Req);
}

/*****************************************************************************/

static void setbgpen(RFBDISPLAY *mod, RFBWINDOW *v, TVPEN pen)
{
	if (pen != v->bgpen && pen != TVPEN_UNDEFINED)
		v->bgpen = pen;
}

static TVPEN setfgpen(RFBDISPLAY *mod, RFBWINDOW *v, TVPEN pen)
{
	TVPEN oldpen = v->fgpen;
	if (pen != oldpen && pen != TVPEN_UNDEFINED)
	{
		v->fgpen = pen;
		if (oldpen == TVPEN_UNDEFINED) oldpen = pen;
	}
	return oldpen;
}

/*****************************************************************************/

LOCAL void rfb_allocpen(RFBDISPLAY *mod, struct TVRequest *req)
{
	TAPTR TExecBase = TGetExecBase(mod);
	RFBWINDOW *v = req->tvr_Op.AllocPen.Window;
	TUINT rgb = req->tvr_Op.AllocPen.RGB & 0xffffff;
	struct RFBPen *pen = TAlloc(mod->rfb_MemMgr, sizeof(struct RFBPen));
	if (pen)
	{
		pen->rgb = rgb;
		TAddTail(&v->penlist, &pen->node);
		req->tvr_Op.AllocPen.Pen = (TVPEN) pen;
		return;
	}
	req->tvr_Op.AllocPen.Pen = TVPEN_UNDEFINED;
}

/*****************************************************************************/

LOCAL void rfb_freepen(RFBDISPLAY *mod, struct TVRequest *req)
{
	TAPTR TExecBase = TGetExecBase(mod);
	struct RFBPen *pen = (struct RFBPen *) req->tvr_Op.FreePen.Pen;
	TRemove(&pen->node);
	TFree(pen);
}

/*****************************************************************************/

LOCAL void rfb_frect(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.FRect.Window;
	TINT rect[4];
	struct RFBPen *pen = (struct RFBPen *) req->tvr_Op.FRect.Pen;
	setfgpen(mod, v, req->tvr_Op.FRect.Pen);
	rect[0] = req->tvr_Op.FRect.Rect[0] + v->rfbw_WinRect[0];
	rect[1] = req->tvr_Op.FRect.Rect[1] + v->rfbw_WinRect[1];
	rect[2] = req->tvr_Op.FRect.Rect[2];
	rect[3] = req->tvr_Op.FRect.Rect[3];
	fbp_drawfrect(mod, v, rect, pen);
}

/*****************************************************************************/

LOCAL void rfb_line(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.Line.Window;
	struct RFBPen *pen = (struct RFBPen *) req->tvr_Op.Line.Pen;
	setfgpen(mod, v, req->tvr_Op.Line.Pen);
	TINT rect[4];
	rect[0] = req->tvr_Op.Line.Rect[0] + v->rfbw_WinRect[0];
	rect[1] = req->tvr_Op.Line.Rect[1] + v->rfbw_WinRect[1];
	rect[2] = req->tvr_Op.Line.Rect[2] + v->rfbw_WinRect[0];
	rect[3] = req->tvr_Op.Line.Rect[3] + v->rfbw_WinRect[1];
	fbp_drawline(mod, v, rect, pen);
}

/*****************************************************************************/

LOCAL void rfb_rect(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.Rect.Window;
	struct RFBPen *pen = (struct RFBPen *) req->tvr_Op.Rect.Pen;
	setfgpen(mod, v, req->tvr_Op.Rect.Pen);
	TINT rect[4];
	rect[0] = req->tvr_Op.Rect.Rect[0] + v->rfbw_WinRect[0];
	rect[1] = req->tvr_Op.Rect.Rect[1] + v->rfbw_WinRect[1];
	rect[2] = req->tvr_Op.Rect.Rect[2];
	rect[3] = req->tvr_Op.Rect.Rect[3];
	fbp_drawrect(mod, v, rect, pen);
}

/*****************************************************************************/

LOCAL void rfb_plot(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.Plot.Window;
	TUINT x = req->tvr_Op.Plot.Rect[0] + v->rfbw_WinRect[0];
	TUINT y = req->tvr_Op.Plot.Rect[1] + v->rfbw_WinRect[1];
	struct RFBPen *pen = (struct RFBPen *) req->tvr_Op.Plot.Pen;
	setfgpen(mod, v, req->tvr_Op.Plot.Pen);
	fbp_drawpoint(mod, v, x, y, pen);
}

/*****************************************************************************/

LOCAL void rfb_drawstrip(RFBDISPLAY *mod, struct TVRequest *req)
{
	TINT i, x0, y0, x1, y1, x2, y2;
	RFBWINDOW *v = req->tvr_Op.Strip.Window;
	TINT *array = req->tvr_Op.Strip.Array;
	TINT num = req->tvr_Op.Strip.Num;
	TTAGITEM *tags = req->tvr_Op.Strip.Tags;
	TVPEN pen = (TVPEN) TGetTag(tags, TVisual_Pen, TVPEN_UNDEFINED);
	TVPEN *penarray = (TVPEN *) TGetTag(tags, TVisual_PenArray, TNULL);
	TINT wx = v->rfbw_WinRect[0];
	TINT wy = v->rfbw_WinRect[1];
	
	if (num < 3) return;

	if (penarray)
		setfgpen(mod, v, penarray[2]);
	else
		setfgpen(mod, v, pen);

	x0 = array[0] + wx;
	y0 = array[1] + wy;
	x1 = array[2] + wx;
	y1 = array[3] + wy;
	x2 = array[4] + wx;
	y2 = array[5] + wy;

	fbp_drawtriangle(mod, v, x0, y0, x1, y1, x2, y2,
		(struct RFBPen *) v->fgpen);

	for (i = 3; i < num; i++)
	{
		x0 = x1;
		y0 = y1;
		x1 = x2;
		y1 = y2;
		x2 = array[i*2] + wx;
		y2 = array[i*2+1] + wy;

		if (penarray)
			setfgpen(mod, v, penarray[i]);

		fbp_drawtriangle(mod, v, x0, y0, x1, y1, x2, y2,
			(struct RFBPen *) v->fgpen);
	}
}

/*****************************************************************************/

LOCAL void rfb_drawfan(RFBDISPLAY *mod, struct TVRequest *req)
{
	TINT i, x0, y0, x1, y1, x2, y2;
	RFBWINDOW *v = req->tvr_Op.Fan.Window;
	TINT *array = req->tvr_Op.Fan.Array;
	TINT num = req->tvr_Op.Fan.Num;
	TTAGITEM *tags = req->tvr_Op.Fan.Tags;
	TVPEN pen = (TVPEN) TGetTag(tags, TVisual_Pen, TVPEN_UNDEFINED);
	TVPEN *penarray = (TVPEN *) TGetTag(tags, TVisual_PenArray, TNULL);
	TINT wx = v->rfbw_WinRect[0];
	TINT wy = v->rfbw_WinRect[1];

	if (num < 3) return;

	if (penarray)
		setfgpen(mod, v, penarray[2]);
	else
		setfgpen(mod, v, pen);

	x0 = array[0] + wx;
	y0 = array[1] + wy;
	x1 = array[2] + wx;
	y1 = array[3] + wy;
	x2 = array[4] + wx;
	y2 = array[5] + wy;

	fbp_drawtriangle(mod, v, x0, y0, x1, y1, x2, y2, 
		(struct RFBPen *) v->fgpen);

	for (i = 3; i < num; i++)
	{
		x1 = x2;
		y1 = y2;
		x2 = array[i*2] + wx;
		y2 = array[i*2+1] + wy;

		if (penarray)
			setfgpen(mod, v, penarray[i]);

		fbp_drawtriangle(mod, v, x0, y0, x1, y1, x2, y2,
			(struct RFBPen *) v->fgpen);
	}
}

/*****************************************************************************/

LOCAL void rfb_copyarea(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.CopyArea.Window;
	TINT dx = req->tvr_Op.CopyArea.DestX;
	TINT dy = req->tvr_Op.CopyArea.DestY;
	struct THook *exposehook = (struct THook *)
		TGetTag(req->tvr_Op.CopyArea.Tags, TVisual_ExposeHook, TNULL);
	TINT rect[4];
	rect[0] = req->tvr_Op.CopyArea.Rect[0] + v->rfbw_WinRect[0];
	rect[1] = req->tvr_Op.CopyArea.Rect[1] + v->rfbw_WinRect[1];
	rect[2] = req->tvr_Op.CopyArea.Rect[2];
	rect[3] = req->tvr_Op.CopyArea.Rect[3];
	dx += v->rfbw_WinRect[0];
	dy += v->rfbw_WinRect[1];
	fbp_copyarea(mod, v, rect, dx, dy, exposehook);
}

/*****************************************************************************/

LOCAL void rfb_setcliprect(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.ClipRect.Window;
	v->rfbw_ClipRect[0] = 
		TMAX(0, v->rfbw_WinRect[0] + req->tvr_Op.ClipRect.Rect[0]);
	v->rfbw_ClipRect[1] = 
		TMAX(0, v->rfbw_WinRect[1] + req->tvr_Op.ClipRect.Rect[1]);
	v->rfbw_ClipRect[2] = TMIN(v->rfbw_WinRect[2], 
		v->rfbw_ClipRect[0] + req->tvr_Op.ClipRect.Rect[2] - 1);
	v->rfbw_ClipRect[3] = TMIN(v->rfbw_WinRect[3], 
		v->rfbw_ClipRect[1] + req->tvr_Op.ClipRect.Rect[3] - 1);
}

/*****************************************************************************/

LOCAL void rfb_unsetcliprect(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.ClipRect.Window;
	v->rfbw_ClipRect[0] = v->rfbw_WinRect[0];
	v->rfbw_ClipRect[1] = v->rfbw_WinRect[1];
	v->rfbw_ClipRect[2] = v->rfbw_WinRect[2];
	v->rfbw_ClipRect[3] = v->rfbw_WinRect[3];
}

/*****************************************************************************/

LOCAL void rfb_clear(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.Clear.Window;
	TINT ww = v->rfbw_WinRect[2] - v->rfbw_WinRect[0] + 1;
	TINT wh = v->rfbw_WinRect[3] - v->rfbw_WinRect[1] + 1;
	TINT rect[4] = { 0, 0, ww, wh };
	struct RFBPen *pen = (struct RFBPen *) req->tvr_Op.Clear.Pen;
	setfgpen(mod, v, req->tvr_Op.Clear.Pen);
	fbp_drawfrect(mod, v, rect, pen);
}

/*****************************************************************************/

LOCAL void rfb_drawbuffer(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.DrawBuffer.Window;
	TAPTR buf = req->tvr_Op.DrawBuffer.Buf;
	TINT totw = req->tvr_Op.DrawBuffer.TotWidth;
	TUINT pixfmt = TGetTag(req->tvr_Op.DrawBuffer.Tags, 
		TVisual_PixelFormat, TVPIXFMT_ARGB32);
	TBOOL alpha = TGetTag(req->tvr_Op.DrawBuffer.Tags, 
		TVisual_AlphaChannel, TFALSE);
	TINT rect[4];
	rect[0] = req->tvr_Op.DrawBuffer.RRect[0] + v->rfbw_WinRect[0];
	rect[1] = req->tvr_Op.DrawBuffer.RRect[1] + v->rfbw_WinRect[1];
	rect[2] = req->tvr_Op.DrawBuffer.RRect[2];
	rect[3] = req->tvr_Op.DrawBuffer.RRect[3];
	fbp_drawbuffer(mod, v, (TUINT8 *)buf, rect, totw, pixfmt, alpha);
}

/*****************************************************************************/

static THOOKENTRY TTAG getattrfunc(struct THook *hook, TAPTR obj, TTAG msg)
{
	struct rfb_attrdata *data = hook->thk_Data;
	TTAGITEM *item = obj;
	RFBWINDOW *v = data->v;

	switch (item->tti_Tag)
	{
		default:
			return TTRUE;
		case TVisual_Width:
			*((TINT *) item->tti_Value) =
				v->rfbw_WinRect[2] - v->rfbw_WinRect[0] + 1;
			break;
		case TVisual_Height:
			*((TINT *) item->tti_Value) =
				v->rfbw_WinRect[3] - v->rfbw_WinRect[1] + 1;
			break;
		case TVisual_WinLeft:
			*((TINT *) item->tti_Value) = v->rfbw_WinRect[0];
			break;
		case TVisual_WinTop:
			*((TINT *) item->tti_Value) = v->rfbw_WinRect[1];
			break;
		case TVisual_MinWidth:
			*((TINT *) item->tti_Value) =
				v->rfbw_WinRect[2] - v->rfbw_WinRect[0] + 1;
			break;
		case TVisual_MinHeight:
			*((TINT *) item->tti_Value) =
				v->rfbw_WinRect[3] - v->rfbw_WinRect[1] + 1;
			break;
		case TVisual_MaxWidth:
			*((TINT *) item->tti_Value) =
				v->rfbw_WinRect[2] - v->rfbw_WinRect[0] + 1;
			break;
		case TVisual_MaxHeight:
			*((TINT *) item->tti_Value) =
				v->rfbw_WinRect[3] - v->rfbw_WinRect[1] + 1;
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

LOCAL void rfb_getattrs(RFBDISPLAY *mod, struct TVRequest *req)
{
	struct rfb_attrdata data;
	struct THook hook;

	data.v = req->tvr_Op.GetAttrs.Window;
	data.num = 0;
	data.mod = mod;
	TInitHook(&hook, getattrfunc, &data);

	TForEachTag(req->tvr_Op.GetAttrs.Tags, &hook);
	req->tvr_Op.GetAttrs.Num = data.num;
}

/*****************************************************************************/

static THOOKENTRY TTAG setattrfunc(struct THook *hook, TAPTR obj, TTAG msg)
{
	struct rfb_attrdata *data = hook->thk_Data;
	TTAGITEM *item = obj;
	/*RFBWINDOW *v = data->v;*/
	switch (item->tti_Tag)
	{
		default:
			return TTRUE;
	}
	data->num++;
	return TTRUE;
}

LOCAL void rfb_setattrs(RFBDISPLAY *mod, struct TVRequest *req)
{
	struct rfb_attrdata data;
	struct THook hook;
	RFBWINDOW *v = req->tvr_Op.SetAttrs.Window;

	data.v = v;
	data.num = 0;
	data.mod = mod;
	TInitHook(&hook, setattrfunc, &data);

	TForEachTag(req->tvr_Op.SetAttrs.Tags, &hook);
	req->tvr_Op.SetAttrs.Num = data.num;
}

/*****************************************************************************/

struct drawdata
{
	RFBWINDOW *v;
	RFBDISPLAY *mod;
	TINT x0, x1, y0, y1;
};

static THOOKENTRY TTAG drawtagfunc(struct THook *hook, TAPTR obj, TTAG msg)
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
			setfgpen(data->mod, data->v, item->tti_Value);
			break;
		case TVisualDraw_BgPen:
			setbgpen(data->mod, data->v, item->tti_Value);
			break;
		case TVisualDraw_Command:
			switch (item->tti_Value)
			{
				case TVCMD_FRECT:
				{
					TINT r[] = 
					{ 
						data->x0, data->y0, 
						data->x1-data->x0, data->y1-data->y0 
					};
					struct RFBPen *pen = (struct RFBPen *) data->v->fgpen;
					fbp_drawfrect(data->mod, data->v, r, pen);
					break;
				}
				case TVCMD_RECT:
				{
					TINT r[] = 
					{
						data->x0, data->y0, 
						data->x1-data->x0, data->y1-data->y0 
					};
					struct RFBPen *pen = (struct RFBPen *) data->v->fgpen;
					fbp_drawrect(data->mod, data->v, r, pen);
					break;
				}
				case TVCMD_LINE:
				{
					TINT r[] = { data->x0, data->y0, data->x1, data->y1 };
					struct RFBPen *pen = (struct RFBPen *) data->v->fgpen;
					fbp_drawline(data->mod, data->v, r, pen);
					break;
				}
			}

			break;
	}
	return TTRUE;
}

LOCAL void rfb_drawtags(RFBDISPLAY *mod, struct TVRequest *req)
{
	struct THook hook;
	struct drawdata data;
	data.v = req->tvr_Op.DrawTags.Window;
	data.mod = mod;

	TInitHook(&hook, drawtagfunc, &data);
	TForEachTag(req->tvr_Op.DrawTags.Tags, &hook);
}

/*****************************************************************************/

LOCAL void rfb_drawtext(RFBDISPLAY *mod, struct TVRequest *req)
{
	RFBWINDOW *v = req->tvr_Op.Text.Window;
	rfb_hostdrawtext(mod, v, req->tvr_Op.Text.Text,
		req->tvr_Op.Text.Length, 
		req->tvr_Op.Text.X + v->rfbw_WinRect[0], 
		req->tvr_Op.Text.Y + v->rfbw_WinRect[1],
		req->tvr_Op.Text.FgPen);
}

/*****************************************************************************/

LOCAL void rfb_setfont(RFBDISPLAY *mod, struct TVRequest *req)
{
	rfb_hostsetfont(mod, req->tvr_Op.SetFont.Window,
		req->tvr_Op.SetFont.Font);
}

/*****************************************************************************/

LOCAL void rfb_openfont(RFBDISPLAY *mod, struct TVRequest *req)
{
	req->tvr_Op.OpenFont.Font =
		rfb_hostopenfont(mod, req->tvr_Op.OpenFont.Tags);
}

/*****************************************************************************/

LOCAL void rfb_textsize(RFBDISPLAY *mod, struct TVRequest *req)
{
	req->tvr_Op.TextSize.Width =
		rfb_hosttextsize(mod, req->tvr_Op.TextSize.Font,
			req->tvr_Op.TextSize.Text, req->tvr_Op.TextSize.NumChars);
}

/*****************************************************************************/

LOCAL void rfb_getfontattrs(RFBDISPLAY *mod, struct TVRequest *req)
{
	struct rfb_attrdata data;
	struct THook hook;

	data.mod = mod;
	data.font = req->tvr_Op.GetFontAttrs.Font;
	data.num = 0;
	TInitHook(&hook, rfb_hostgetfattrfunc, &data);

	TForEachTag(req->tvr_Op.GetFontAttrs.Tags, &hook);
	req->tvr_Op.GetFontAttrs.Num = data.num;
}

/*****************************************************************************/

LOCAL void rfb_closefont(RFBDISPLAY *mod, struct TVRequest *req)
{
	rfb_hostclosefont(mod, req->tvr_Op.CloseFont.Font);
}

/*****************************************************************************/

LOCAL void rfb_queryfonts(RFBDISPLAY *mod, struct TVRequest *req)
{
	req->tvr_Op.QueryFonts.Handle =
		rfb_hostqueryfonts(mod, req->tvr_Op.QueryFonts.Tags);
}

/*****************************************************************************/

LOCAL void rfb_getnextfont(RFBDISPLAY *mod, struct TVRequest *req)
{
	req->tvr_Op.GetNextFont.Attrs =
		rfb_hostgetnextfont(mod, req->tvr_Op.GetNextFont.Handle);
}

/*****************************************************************************/

LOCAL void rfb_markdirty(RFBDISPLAY *mod, TINT *r)
{
	struct Pool *pool = &mod->rfb_RectPool;
	if (!mod->rfb_DirtyRegion)
	{
		mod->rfb_DirtyRegion = rfb_region_new(pool, r);
		return;
	}
	rfb_region_orrect(pool, mod->rfb_DirtyRegion, r, TTRUE);
}
