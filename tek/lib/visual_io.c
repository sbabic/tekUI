
/*
**	tek/lib/visual_io.c - tekUI I/O message dispatcher
**	Written by Timm S. Mueller <tmueller at schulze-mueller.de>
**	See copyright notice in COPYRIGHT
**
**	- if ENABLE_FILENO is defined, lines will be read from stdin. Each line
**	will be sent to the gui as an individual message of the type MSG_USER.
**
**	- if ENABLE_DGRAM is defined, a datagram server will be created.
**	The payload of each datagram will be sent to the gui as a message of
**	the type MSG_USER.
**
**	Add other input sources as you see fit.
**
**	To react on these messages, add input handlers to one or more elements:
**
**	Class:show()
**	  Superclass.show(self)
**	  self.Application:addInputHandler(ui.MSG_USER, self, self.msgUser)
**	end
**	Class:hide()
**	  Superclass.hide(self)
**	  self.Application:remInputHandler(ui.MSG_USER, self, self.msgUser)
**	end
**	Class:msgUser(msg)
**	  print(msg)
**	  return msg -- this passes the msg on to the next handler
**	end
*/

#include "visual_lua.h"

#if defined(ENABLE_FILENO) || defined(ENABLE_DGRAM)

#include <string.h>
#include <unistd.h>
#include <sys/select.h>
#include <sys/ioctl.h>

#include <tek/lib/tek_lua.h>
#include <tek/mod/exec.h>
#include <tek/proto/hal.h>

#if defined(ENABLE_DGRAM)
#include <sys/socket.h>
#include <net/if.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#endif

#define IOMAXMSGSIZE 2048

/*****************************************************************************/

#if defined(ENABLE_FILENO)

struct LineReader
{
	int File;
	size_t ReadBytes;
	char ReadBuf[256];
	int BufBytes;
	int BufPos;
 	int (*ReadCharFunc)(struct LineReader *, char c);
 	int (*ReadLineFunc)(struct LineReader *, char **line, size_t *len);
	char *Buffer;
	size_t Pos;
	size_t Size;
	size_t MaxLen;
	int State;
};

static int visual_io_readchar(struct LineReader *r, char c)
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

static int visual_io_readline(struct LineReader *r, char **line, size_t *len)
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
		else if ((*r->ReadCharFunc)(r, c) == 0)
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

static int visual_io_reader_init(struct LineReader *r, int fd, size_t maxlen)
{
	r->File = fd;
	r->ReadBytes = 0;
	r->BufBytes = 0;
	r->BufPos = 0;
	r->MaxLen = maxlen;
	r->ReadCharFunc = visual_io_readchar;
	r->ReadLineFunc = visual_io_readline;
	r->Buffer = NULL;
	r->Pos = 0;
	r->Size = 0;
	r->State = 0;
	return 1;
}

static void visual_io_reader_exit(struct LineReader *r)
{
	free(r->Buffer);
}

static void visual_io_reader_addbytes(struct LineReader *r, int nbytes)
{
	r->ReadBytes += nbytes;
}

#endif

/*****************************************************************************/

static TBOOL 
getusermsg(TEKVisual *vis, TIMSG **msgptr, TUINT type, TSIZE size)
{
	TAPTR TExecBase = vis->vis_ExecBase;
	TIMSG *msg = TAllocMsg0(sizeof(TIMSG) + size);
	if (msg)
	{
		msg->timsg_ExtraSize = size;
		msg->timsg_Type = type;
		msg->timsg_Qualifier = 0;
		msg->timsg_MouseX = -1;
		msg->timsg_MouseY = -1;
		TGetSystemTime(&msg->timsg_TimeStamp);
		*msgptr = msg;
		return TTRUE;
	}
	*msgptr = TNULL;
	return TFALSE;
}

/*****************************************************************************/

struct IOData
{
	TEKVisual *vis;
	int fdmax;
	/* selfpipe for communication: */
	int fd_pipe[2];
#if defined(ENABLE_FILENO)
	int fd_stdin;
	struct LineReader linereader;
#endif
#if defined(ENABLE_DGRAM)
	int fd_dgram;
#endif
};

static void tek_lib_visual_io_exit(struct TTask *task)
{
	struct TExecBase *TExecBase = TGetExecBase(task);
	struct IOData *iodata = TGetTaskData(task);
	int i;
	
	for (i = 0; i < 2; ++i)
		if (iodata->fd_pipe[i] != -1)
			close(iodata->fd_pipe[i]);
#if defined(ENABLE_DGRAM)
	if (iodata->fd_dgram != -1)
		close(iodata->fd_dgram);
#endif
#if defined(ENABLE_FILENO)
	visual_io_reader_exit(&iodata->linereader);
#endif
	
}

static TBOOL tek_lib_visual_io_init(struct TTask *task)
{
	struct TExecBase *TExecBase = TGetExecBase(task);
	struct IOData *iodata = TGetTaskData(task);
	TEKVisual *vis = iodata->vis;
	
	iodata->fd_pipe[0] = -1;
	iodata->fd_pipe[1] = -1;
	iodata->fdmax = 0;

#if defined(ENABLE_FILENO)
	int fd = vis->vis_IOFileNo;
	iodata->fd_stdin = fd == -1 ? STDIN_FILENO : fd;
	visual_io_reader_init(&iodata->linereader, iodata->fd_stdin, IOMAXMSGSIZE);
	iodata->fdmax = TMAX(iodata->fdmax, iodata->fd_stdin);
#endif
	
#if defined(ENABLE_DGRAM)
	iodata->fd_dgram = socket(PF_INET, SOCK_DGRAM, 0);
	if (iodata->fd_dgram != -1)
	{
		int reuse = 1;
		setsockopt(iodata->fd_dgram, SOL_SOCKET, SO_REUSEADDR,
			(char *) &reuse, sizeof(reuse));
		struct sockaddr_in addr;
		memset(&addr, 0, sizeof(struct sockaddr_in));
		addr.sin_family = AF_INET;
		addr.sin_addr.s_addr = inet_addr("127.0.0.1");
		addr.sin_port = htons(ENABLE_DGRAM);
		if (bind(iodata->fd_dgram, 
			(struct sockaddr *) &addr, sizeof addr) == -1)
		{
			close(iodata->fd_dgram);
			iodata->fd_dgram = -1;
		}
	}
	if (iodata->fd_dgram == -1)
	{
		tek_lib_visual_io_exit(task);
		return TFALSE;
	}
	iodata->fdmax = TMAX(iodata->fdmax, iodata->fd_dgram);
#endif
	
	if (pipe(iodata->fd_pipe) != 0)
		return TFALSE;

	iodata->fdmax = TMAX(iodata->fdmax, iodata->fd_pipe[0]) + 1;
	return TTRUE;
}

static void tek_lib_visual_io_task(struct TTask *task)
{
	struct TExecBase *TExecBase = TGetExecBase(task);
	struct IOData *iodata = TGetTaskData(task);
	TEKVisual *vis = iodata->vis;
	TIMSG *imsg;
	char buf[256];
	TUINT sig;
	fd_set rset;
	do
	{
		FD_ZERO(&rset);
		FD_SET(iodata->fd_pipe[0], &rset);
	#if defined(ENABLE_FILENO)
		if (iodata->fd_stdin != -1)
			FD_SET(iodata->fd_stdin, &rset);
	#endif
	#if defined(ENABLE_DGRAM)
		FD_SET(iodata->fd_dgram, &rset);
	#endif
		if (select(iodata->fdmax, &rset, NULL, NULL, NULL) > 0)
		{
			int nbytes = 0;
			
			/* consume signal: */
			if (FD_ISSET(iodata->fd_pipe[0], &rset))
			{
				ioctl(iodata->fd_pipe[0], FIONREAD, &nbytes);
				if (nbytes > 0)
					if (read(iodata->fd_pipe[0], buf,
						TMIN(sizeof(buf), (size_t) nbytes)) != nbytes)
					TDBPRINTF(TDB_ERROR,("Error reading from selfpipe\n"));
			}
			
			#if defined(ENABLE_FILENO)
			/* stdin line reader: */
			if (iodata->fd_stdin >= 0 && FD_ISSET(iodata->fd_stdin, &rset))
			{
				if (ioctl(iodata->fd_stdin, FIONREAD, &nbytes) == 0)
				{
					if (nbytes == 0)
						iodata->fd_stdin = -1; /* stop processing */
					else
					{
						char *line;
						size_t len;
						visual_io_reader_addbytes(&iodata->linereader, nbytes);
						while (visual_io_readline(&iodata->linereader, &line, &len))
						{
							if (getusermsg(vis, &imsg, TITYPE_USER, len))
							{
								memcpy((void *) (imsg + 1), line, len);
								TPutMsg(vis->vis_IMsgPort, TNULL,
									&imsg->timsg_Node);
							}
						}
					}
				}
				else
					iodata->fd_stdin = -1; /* stop processing */
			}
			#endif
			
			#if defined(ENABLE_DGRAM)
			if (iodata->fd_dgram >= 0 && FD_ISSET(iodata->fd_dgram, &rset))
			{
				char umsg[IOMAXMSGSIZE];
				TIMSG *imsg;
				ssize_t len = recv(iodata->fd_dgram, umsg, sizeof umsg, 0);
				if (len >= 0 && getusermsg(vis, &imsg, TITYPE_USER, len))
				{
					memcpy((void *) (imsg + 1), umsg, len);
					TPutMsg(vis->vis_IMsgPort, TNULL, &imsg->timsg_Node);
				}
			}
			#endif
		}
		sig = TSetSignal(0, TTASK_SIG_ABORT);
	} while (!(sig & TTASK_SIG_ABORT));
	
	tek_lib_visual_io_exit(task);
}

/*****************************************************************************/

static THOOKENTRY TTAG 
tek_lib_visual_io_dispatch(struct THook *hook, TAPTR obj, TTAG msg)
{
	switch (msg)
	{
		case TMSG_INITTASK:
			return tek_lib_visual_io_init(obj);
		case TMSG_RUNTASK:
			tek_lib_visual_io_task(obj);
			break;
	}
	return 0;
}

LOCAL TBOOL tek_lib_visual_io_open(TEKVisual *vis)
{	
	struct TExecBase *TExecBase = vis->vis_ExecBase;
	struct IOData *iodata = TAlloc(TNULL, sizeof(struct IOData));
	if (iodata)
	{
		TTAGITEM tags[2];
		iodata->vis = vis;
		vis->vis_IOData = iodata;
		tags[0].tti_Tag = TTask_UserData;
		tags[0].tti_Value = (TTAG) iodata;
		tags[1].tti_Tag = TTAG_DONE;
		struct THook taskhook;
		TInitHook(&taskhook, tek_lib_visual_io_dispatch, TNULL);
		vis->vis_IOTask = TCreateTask(&taskhook, tags);
		if (vis->vis_IOTask)
			return TTRUE;
		TFree(iodata);
		vis->vis_IOData = TNULL;
	}
	return TFALSE;
}

LOCAL void tek_lib_visual_io_close(TEKVisual *vis)
{
	if (vis->vis_IOTask)
	{
		struct TExecBase *TExecBase = vis->vis_ExecBase;
		struct IOData *iodata = vis->vis_IOData;
		char sig = 0;
		TSignal(vis->vis_IOTask, TTASK_SIG_ABORT);
		if (write(iodata->fd_pipe[1], &sig, 1) != 1)
			TDBPRINTF(TDB_ERROR,("Error writing to selfpipe\n"));
		TDestroy((struct THandle *) vis->vis_IOTask);
		vis->vis_IOTask = TNULL;
		TFree(vis->vis_IOData);
		vis->vis_IOData = TNULL;
	}
}

#else

/*****************************************************************************/

LOCAL TBOOL tek_lib_visual_io_open(TEKVisual *vis)
{
	vis->vis_IOTask = (void *) 1;
	return TTRUE;
}

LOCAL void tek_lib_visual_io_close(TEKVisual *vis)
{
}

#endif /* defined(ENABLE_FILENO) || defined(ENABLE_DGRAM) */
