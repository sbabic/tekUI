
/*
**	teklib/src/exec/exec_time.c - Time and date functions
**
**	Written by Frank Pagels <copper at coplabs.org>
**	and Timm S. Mueller <tmueller at neoscientists.org>
**	See copyright notice in teklib/COPYRIGHT
*/

#include <tek/debug.h>
#include <tek/teklib.h>
#include <tek/proto/exec.h>
#include <tek/inline/exec.h>
#include <tek/proto/hal.h>

#include "exec_mod.h"

/*****************************************************************************/

EXPORT struct TTimeRequest *
exec_AllocTimeRequest(struct TExecBase *TExecBase, TTAGITEM *tags)
{
	return (struct TTimeRequest *) TOpenModule(TMODNAME_TIMER, 0, TNULL);
}

/*****************************************************************************/

EXPORT void
exec_FreeTimeRequest(struct TExecBase *TExecBase, struct TTimeRequest *req)
{
	if (req)
	{
		TCloseModule(req->ttr_Req.io_Device);
		TFree(req);
	}
}

/*****************************************************************************/
/*
**	exec_getsystemtime(time, treq, time)
**	Insert system time into *time
*/

EXPORT void
exec_GetSystemTime(struct TExecBase *TExecBase, struct TTimeRequest *tr,
	TTIME *timep)
{
	if (tr && timep)
	{
		TAPTR saverp = tr->ttr_Req.io_ReplyPort;
		tr->ttr_Req.io_ReplyPort = TNULL;
		tr->ttr_Req.io_Command = TTREQ_GETSYSTEMTIME;
		if (TDoIO((struct TIORequest *) tr) == 0)
			*timep = tr->ttr_Data.ttr_Time;
		tr->ttr_Req.io_ReplyPort = saverp;
	}
}

/*****************************************************************************/
/*
**	err = exec_getlocaldate(time, treq, date)
**
**	Insert datetime into *date.
**
**	err = 0 - ok
**	err = -1 - illegal arguments
**	err = -2 - date resource not available
*/

static TINT
execi_getdate(struct TExecBase *TExecBase, struct TTimeRequest *tr, TDATE *dtp,
	TUINT command)
{
	TINT err = -1;
	if (tr)
	{
		struct TMsgPort *saverp = tr->ttr_Req.io_ReplyPort;
		tr->ttr_Req.io_ReplyPort = TNULL;
		tr->ttr_Req.io_Command = command;
		err = -2;
		if (TDoIO((struct TIORequest *) tr) == 0)
		{
			if (dtp)
				*dtp = tr->ttr_Data.ttr_Date;
			err = 0;
		}
		tr->ttr_Req.io_ReplyPort = saverp;
	}
	return err;
}

EXPORT TINT
exec_GetLocalDate(struct TExecBase *TExecBase, struct TTimeRequest *tr, TDATE *dtp)
{
	return execi_getdate(TExecBase, tr, dtp, TTREQ_GETLOCALDATE);
}

EXPORT TINT
exec_GetUniversalDate(struct TExecBase *TExecBase, struct TTimeRequest *tr, TDATE *dtp)
{
	return execi_getdate(TExecBase, tr, dtp, TTREQ_GETUNIVERSALDATE);
}

/*****************************************************************************/
/*
**	sig = exec_wait(time, treq, time, sigmask)
**	wait an amount of time, or for a set of signals
*/

EXPORT TUINT
exec_WaitTime(struct TExecBase *TExecBase, struct TTimeRequest *tr, TTIME *timeout,
	TUINT sigmask)
{
	TUINT sig = 0;

	if (timeout)
	{
		TAPTR saverp = tr->ttr_Req.io_ReplyPort;

		tr->ttr_Req.io_ReplyPort = TGetSyncPort(TNULL);
		tr->ttr_Req.io_Command = TTREQ_WAITTIME;
		tr->ttr_Data.ttr_Time = *timeout;

		TPutIO((struct TIORequest *) tr);
		sig = TWait(TTASK_SIG_SINGLE | sigmask);
		TAbortIO((struct TIORequest *) tr);
		TWaitIO((struct TIORequest *) tr);
		TSetSignal(0, TTASK_SIG_SINGLE);

		tr->ttr_Req.io_ReplyPort = saverp;

		sig &= sigmask;
	}
	else
	{
		if (sigmask)
			sig = TWait(sigmask);
	}

	return sig;
}

/*****************************************************************************/
/*
**	sig = exec_waitdate(time, treq, date, sigmask)
**	wait for an universal date, or a set of signals
*/

EXPORT TUINT
exec_WaitDate(struct TExecBase *TExecBase, struct TTimeRequest *tr, TDATE *date,
	TUINT sigmask)
{
	TUINT sig = 0;

	if (date)
	{
		TAPTR saverp = tr->ttr_Req.io_ReplyPort;

		tr->ttr_Req.io_ReplyPort = TGetSyncPort(TNULL);
		tr->ttr_Req.io_Command = TTREQ_WAITUNIVERSALDATE;
		tr->ttr_Data.ttr_Date = *date;

		TPutIO((struct TIORequest *) tr);
		sig = TWait(TTASK_SIG_SINGLE | sigmask);
		TAbortIO((struct TIORequest *) tr);
		TWaitIO((struct TIORequest *) tr);
		TSetSignal(0, TTASK_SIG_SINGLE);

		tr->ttr_Req.io_ReplyPort = saverp;

		sig &= sigmask;
	}
	else
	{
		if (sigmask)
			sig = TWait(sigmask);
	}

	return sig;
}
