
/*
**	display_x11_all.c - Stub to build module from single source
**
**	Written by Timm S. Mueller <tmueller at neoscientists.org>
**	See copyright notice in teklib/COPYRIGHT
*/

#ifndef EXPORT
#define EXPORT static TMODAPI
#endif

#ifndef LOCAL
#define LOCAL static
#endif

#ifndef TLIBAPI
#define TLIBAPI static
#endif

#include "../teklib/teklib.c"
#if defined(TDEBUG) && TDEBUG > 0
#include "../teklib/debug.c"
#endif

#include "../misc/utf8.c"
#include "../misc/pixconv.c"
#include "../misc/imgcache.c"

#include "display_x11_mod.c"
#include "display_x11_api.c"
#include "display_x11_inst.c"
#include "display_x11_font.c"
