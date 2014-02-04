#ifndef _TEKUI_H
#define _TEKUI_H

#include <tek/exec.h>

#define TEKUI_HUGE				1000000

#define TEKUI_FL_LAYOUT			0x0001
#define TEKUI_FL_REDRAW			0x0002
#define TEKUI_FL_REDRAWBORDER	0x0004
#define TEKUI_FL_SETUP			0x0008
#define TEKUI_FL_SHOW			0x0010
#define TEKUI_FL_CHANGED		0x0020
#define TEKUI_FL_POPITEM		0x0040
#define TEKUI_FL_UPDATE			0x0080
#define TEKUI_FL_RECVINPUT		0x0100
#define TEKUI_FL_RECVMOUSEMOVE	0x0200
#define TEKUI_FL_CURSORFOCUS	0x0400
#define TEKUI_FL_AUTOPOSITION	0x0800
#define TEKUI_FL_ERASEBG		0x1000
#define TEKUI_FL_TRACKDAMAGE	0x2000
#define TEKUI_FL_ACTIVATERMB	0x4000
#define TEKUI_FL_INITIALFOCUS	0x8000

#define TEK_UI_OVERLAP(d0, d1, d2, d3, s0, s1, s2, s3) \
((s2) >= (d0) && (s0) <= (d2) && (s3) >= (d1) && (s1) <= (d3))

#define TEK_UI_OVERLAPRECT(d, s) \
TEK_UI_OVERLAP((d)[0], (d)[1], (d)[2], (d)[3], (s)[0], (s)[1], (s)[2], (s)[3])

typedef TINT RECTINT;

struct RectNode
{
	struct TNode rn_Node;
	RECTINT rn_Rect[4];
};

#endif
