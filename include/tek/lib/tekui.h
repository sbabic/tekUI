#ifndef _TEKUI_H
#define _TEKUI_H

#include <tek/type.h>
typedef TUINT tekui_flags;

#define TEKUI_HUGE				1000000

#define TEKUI_FL_LAYOUT			0x0001
#define TEKUI_FL_REDRAW			0x0002
#define TEKUI_FL_REDRAWBORDER	0x0004
#define TEKUI_FL_SETUP			0x0008
#define TEKUI_FL_SHOW			0x0010
#define TEKUI_FL_CHANGED		0x0020

#define TEK_UI_SUPPORT_NAME		"tek.ui.support*"

#endif
