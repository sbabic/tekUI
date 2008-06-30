
#ifndef _TEK_PROTO_IO_H
#define _TEK_PROTO_IO_H

/*
**	$Id: io.h,v 1.1.1.1 2006/08/20 22:15:26 tmueller Exp $
**	teklib/tek/proto/io.h - I/O module prototypes
**
**	See copyright notice in teklib/COPYRIGHT
*/

#include <tek/mod/io.h>
#include <tek/stdcall/io.h>

extern TMODENTRY TUINT
tek_init_io(TAPTR, struct TModule *, TUINT16, TTAGITEM *);

#endif /* _TEK_PROTO_IO_H */
