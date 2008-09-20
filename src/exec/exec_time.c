
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
#include <tek/proto/hal.h>
#include <tek/mod/time.h>

/*****************************************************************************/

EXPORT void
exec_SubTime(TEXECBASE *tmod, TTIME *a, TTIME *b)
{
	if (a->ttm_USec < b->ttm_USec)
	{
		a->ttm_Sec = a->ttm_Sec - b->ttm_Sec - 1;
		a->ttm_USec = 1000000 - (b->ttm_USec - a->ttm_USec);
	}
	else
	{
		a->ttm_Sec = a->ttm_Sec - b->ttm_Sec;
		a->ttm_USec = a->ttm_USec - b->ttm_USec;
	}
}

/*****************************************************************************/

EXPORT void
exec_AddTime(TEXECBASE *tmod, TTIME *a, TTIME *b)
{
	a->ttm_Sec += b->ttm_Sec;
	a->ttm_USec += b->ttm_USec;
	if (a->ttm_USec >= 1000000)
	{
		a->ttm_USec -= 1000000;
		a->ttm_Sec++;
	}
}

/*****************************************************************************/

EXPORT TINT
exec_CmpTime(TEXECBASE *tmod, TTIME *a, TTIME *b)
{
	if (a->ttm_Sec < b->ttm_Sec) return -1;
	if (a->ttm_Sec > b->ttm_Sec) return 1;
	if (a->ttm_USec == b->ttm_USec) return 0;
	if (a->ttm_USec > b->ttm_USec) return 1;
	return -1;
}

/*****************************************************************************/

EXPORT struct TTimeRequest *
exec_AllocTimeRequest(TEXECBASE *tmod, TTAGITEM *tags)
{
	TAPTR exec = TGetExecBase(tmod);
	return TExecOpenModule(exec, TMODNAME_TIMER, 0, TNULL);
}

/*****************************************************************************/

EXPORT void
exec_FreeTimeRequest(TEXECBASE *tmod, struct TTimeRequest *req)
{
	if (req)
	{
		TAPTR exec = TGetExecBase(tmod);
		TExecCloseModule(exec, req->ttr_Req.io_Device);
		TExecFree(exec, req);
	}
}

/*****************************************************************************/
/*
**	exec_query(time, treq, time)
**	Insert system time into *time
*/

EXPORT void
exec_QueryTime(TEXECBASE *tmod, struct TTimeRequest *tr, TTIME *timep)
{
#if 1
	THALGetSysTime(tmod->texb_HALBase, timep);
#else
	if (tr)
	{
		TAPTR saverp = tr->ttr_Req.io_ReplyPort;
		tr->ttr_Req.io_ReplyPort = TNULL;
		tr->ttr_Req.io_Command = TTREQ_GETTIME;

		if (TExecDoIO(TExecBase, (struct TIORequest *) tr) == 0)
		{
			if (timep)
				*timep = tr->ttr_Data.ttr_Time;
		}
		tr->ttr_Req.io_ReplyPort = saverp;
	}
#endif
}

/*****************************************************************************/
/*
**	err = exec_getdate(time, treq, date, tzsec)
**
**	Insert datetime into *date. If tzsec is NULL, *date will
**	be set to local time. Otherwise, *date will be set to UT,
**	and *tzsec will be set to seconds west of UT.
**
**	err = -1 - illegal arguments
**	err = 0 - ok
**	err = 1 - no date resource available
**	err = 2 - no timezone info available
*/

EXPORT TINT
exec_GetDate(TEXECBASE *tmod, struct TTimeRequest *tr, TDATE *dtp, TINT *tzp)
{
	TAPTR exec = TGetExecBase(tmod);
	TINT err = -1;
	if (tr)
	{
		TAPTR saverp = tr->ttr_Req.io_ReplyPort;

		tr->ttr_Req.io_ReplyPort = TNULL;
		tr->ttr_Data.ttr_Date.ttr_TimeZone = 1000000;	/* absurd */

		if (tzp)
			tr->ttr_Req.io_Command = TTREQ_GETUNIDATE;
		else
			tr->ttr_Req.io_Command = TTREQ_GETLOCALDATE;

		if (TExecDoIO(exec, (struct TIORequest *) tr) == 0)
		{
			err = 0;

			if (dtp)
				*dtp = tr->ttr_Data.ttr_Date.ttr_Date;

			if (tzp)
			{
				if (tr->ttr_Data.ttr_Date.ttr_TimeZone == 1000000)
					err = 2;
				else
					*tzp = tr->ttr_Data.ttr_Date.ttr_TimeZone;
			}
		}
		else
			err = 1;

		tr->ttr_Req.io_ReplyPort = saverp;
	}

	return err;
}

/*****************************************************************************/
/*
**	exec_adddate(date, d, ndays, time)
**	Add a number of days, and optionally a time, to date d1.
*/

EXPORT void
exec_AddDate(TEXECBASE *tmod, TDATE *d, TINT ndays, TTIME *tm)
{
	TUINT64 jd = d->tdt_Day.tdtt_Int64;
	TUINT64 nd = ndays;

	nd *= 86400000000ULL;
	jd += nd;
	if (tm)
	{
		TUINT64 t;
		t = tm->ttm_Sec;
		t *= 1000000ULL;
		jd += t;
		jd += tm->ttm_USec;
	}
	d->tdt_Day.tdtt_Int64 = jd;
}

/*****************************************************************************/
/*
**	exec_subdate(date, d, ndays, time)
**	Subtract a number of days, and optionally a time, from a date.
*/

EXPORT void
exec_SubDate(TEXECBASE *tmod, TDATE *d, TINT ndays, TTIME *tm)
{
	TDBPRINTF(TDB_ERROR,("*** function not implemented\n"));
}

/*****************************************************************************/
/*
**	ndays = exec_diffdate(date, d1, d2, tm)
**	Get the number of days difference between two dates,
**	and optionally the number of seconds/microseconds
*/

EXPORT TINT
exec_DiffDate(TEXECBASE *tmod, TDATE *d1, TDATE *d2, TTIME *tm)
{
	TDBPRINTF(TDB_ERROR,("*** function not implemented\n"));
	return 0;
}

/*****************************************************************************/
/*
**	sig = exec_wait(time, treq, time, sigmask)
**	wait an amount of time, or for a set of signals
*/

EXPORT TUINT
exec_WaitTime(TEXECBASE *tmod, struct TTimeRequest *tr, TTIME *timeout,
	TUINT sigmask)
{
	TAPTR exec = TGetExecBase(tmod);
	TUINT sig = 0;

	if (timeout && (timeout->ttm_Sec || timeout->ttm_USec))
	{
		TAPTR saverp = tr->ttr_Req.io_ReplyPort;

		tr->ttr_Req.io_ReplyPort = TExecGetSyncPort(exec, TNULL);
		tr->ttr_Req.io_Command = TTREQ_ADDTIME;
		tr->ttr_Data.ttr_Time = *timeout;

		TExecPutIO(exec, (struct TIORequest *) tr);
		sig = TExecWait(exec, TTASK_SIG_SINGLE | sigmask);
		TExecAbortIO(exec, (struct TIORequest *) tr);
		TExecWaitIO(exec, (struct TIORequest *) tr);
		TExecSetSignal(exec, 0, TTASK_SIG_SINGLE);

		tr->ttr_Req.io_ReplyPort = saverp;

		sig &= sigmask;
	}
	else
	{
		if (sigmask)
			sig = TExecWait(exec, sigmask);
	}

	return sig;
}

/*****************************************************************************/
/*
**	sig = exec_waitdate(time, treq, date, sigmask)
**	wait for an universal date, or a set of signals
*/

EXPORT TUINT
exec_WaitDate(TEXECBASE *tmod, struct TTimeRequest *tr, TDATE *date,
	TUINT sigmask)
{
	TAPTR exec = TGetExecBase(tmod);
	TUINT sig = 0;

	if (date)
	{
		TAPTR saverp = tr->ttr_Req.io_ReplyPort;

		tr->ttr_Req.io_ReplyPort = TExecGetSyncPort(exec, TNULL);
		tr->ttr_Req.io_Command = TTREQ_ADDLOCALDATE;
		tr->ttr_Data.ttr_Date.ttr_Date = *date;

		TExecPutIO(exec, (struct TIORequest *) tr);
		sig = TExecWait(exec, TTASK_SIG_SINGLE | sigmask);
		TExecAbortIO(exec, (struct TIORequest *) tr);
		TExecWaitIO(exec, (struct TIORequest *) tr);
		TExecSetSignal(exec, 0, TTASK_SIG_SINGLE);

		tr->ttr_Req.io_ReplyPort = saverp;

		sig &= sigmask;
	}
	else
	{
		if (sigmask)
			sig = TExecWait(exec, sigmask);
	}

	return sig;
}

/*****************************************************************************/
/*
**	exec_delay(time, treq, time)
**	wait an amount of time
*/

EXPORT void
exec_Delay(TEXECBASE *tmod, struct TTimeRequest *tr, TTIME *timeout)
{
	if (timeout && (timeout->ttm_Sec || timeout->ttm_USec))
	{
		tr->ttr_Req.io_ReplyPort = TNULL;
			/*TExecGetSyncPort(TExecBase, TNULL);*/
		tr->ttr_Req.io_Command = TTREQ_ADDTIME;
		tr->ttr_Data.ttr_Time = *timeout;
		TExecDoIO(TGetExecBase(tmod), (struct TIORequest *) tr);
	}
}
