#ifndef _TEK_INLINE_EXEC_H
#define _TEK_INLINE_EXEC_H

/*
**	$Id: exec.h $
**	teklib/tek/inline/exec.h - exec inline calls
**
**	Written by Timm S. Mueller <tmueller at neoscientists.org>
**	See copyright notice in teklib/COPYRIGHT
*/

#include <tek/proto/exec.h>

#define TGetHALBase() \
	(*(((TMODCALL struct THALBase *(**)(TAPTR))(TExecBase))[-11]))(TExecBase)

#define TLoadModule(name,version,tags) \
	(*(((TMODCALL struct TModule *(**)(TAPTR,TSTRPTR,TUINT16,TTAGITEM *))(TExecBase))[-12]))(TExecBase,name,version,tags)

#define TOpenModule(name,version,tags) \
	(*(((TMODCALL struct TModule *(**)(TAPTR,TSTRPTR,TUINT16,TTAGITEM *))(TExecBase))[-13]))(TExecBase,name,version,tags)

#define TCloseModule(mod) \
	(*(((TMODCALL void(**)(TAPTR,struct TModule *))(TExecBase))[-14]))(TExecBase,mod)

#define TUnloadModule(mod) \
	(*(((TMODCALL void(**)(TAPTR,struct TModule *))(TExecBase))[-15]))(TExecBase,mod)

#define TCopyMem(src,dst,len) \
	(*(((TMODCALL void(**)(TAPTR,TAPTR,TAPTR,TUINT))(TExecBase))[-16]))(TExecBase,src,dst,len)

#define TFillMem(dst,len,val) \
	(*(((TMODCALL void(**)(TAPTR,TAPTR,TUINT,TUINT8))(TExecBase))[-17]))(TExecBase,dst,len,val)

#define TFillMem32(dst,len,val) \
	(*(((TMODCALL void(**)(TAPTR,TAPTR,TUINT,TUINT))(TExecBase))[-18]))(TExecBase,dst,len,val)

#define TCreateMMU(object,type,tags) \
	(*(((TMODCALL struct TMemManager *(**)(TAPTR,TAPTR,TUINT,TTAGITEM *))(TExecBase))[-19]))(TExecBase,object,type,tags)

#define TAlloc(mm,size) \
	(*(((TMODCALL TAPTR(**)(TAPTR,struct TMemManager *,TUINT))(TExecBase))[-20]))(TExecBase,mm,size)

#define TAlloc0(mm,size) \
	(*(((TMODCALL TAPTR(**)(TAPTR,struct TMemManager *,TUINT))(TExecBase))[-21]))(TExecBase,mm,size)

#define TQueryInterface(mod,name,version,tags) \
	(*(((TMODCALL struct TInterface *(**)(TAPTR,struct TModule *,TSTRPTR,TUINT16,TTAGITEM *))(TExecBase))[-22]))(TExecBase,mod,name,version,tags)

#define TDropInterface(mod,iface) \
	(*(((TMODCALL void(**)(TAPTR,struct TModule *,struct TInterface *))(TExecBase))[-23]))(TExecBase,mod,iface)

#define TFree(mem) \
	(*(((TMODCALL void(**)(TAPTR,TAPTR))(TExecBase))[-24]))(TExecBase,mem)

#define TRealloc(mem,nsize) \
	(*(((TMODCALL TAPTR(**)(TAPTR,TAPTR,TUINT))(TExecBase))[-25]))(TExecBase,mem,nsize)

#define TGetMMU(mem) \
	(*(((TMODCALL struct TMemManager *(**)(TAPTR,TAPTR))(TExecBase))[-26]))(TExecBase,mem)

#define TGetSize(mem) \
	(*(((TMODCALL TUINT(**)(TAPTR,TAPTR))(TExecBase))[-27]))(TExecBase,mem)

#define TCreateLock(tags) \
	(*(((TMODCALL struct TLock *(**)(TAPTR,TTAGITEM *))(TExecBase))[-28]))(TExecBase,tags)

#define TLock(lock) \
	(*(((TMODCALL void(**)(TAPTR,struct TLock *))(TExecBase))[-29]))(TExecBase,lock)

#define TUnlock(lock) \
	(*(((TMODCALL void(**)(TAPTR,struct TLock *))(TExecBase))[-30]))(TExecBase,lock)

#define TAllocSignal(sig) \
	(*(((TMODCALL TUINT(**)(TAPTR,TUINT))(TExecBase))[-31]))(TExecBase,sig)

#define TFreeSignal(sig) \
	(*(((TMODCALL void(**)(TAPTR,TUINT))(TExecBase))[-32]))(TExecBase,sig)

#define TSignal(task,sig) \
	(*(((TMODCALL void(**)(TAPTR,struct TTask *,TUINT))(TExecBase))[-33]))(TExecBase,task,sig)

#define TSetSignal(newsig,sigmask) \
	(*(((TMODCALL TUINT(**)(TAPTR,TUINT,TUINT))(TExecBase))[-34]))(TExecBase,newsig,sigmask)

#define TWait(sig) \
	(*(((TMODCALL TUINT(**)(TAPTR,TUINT))(TExecBase))[-35]))(TExecBase,sig)

#define TStrEqual(s1,s2) \
	(*(((TMODCALL TBOOL(**)(TAPTR,TSTRPTR,TSTRPTR))(TExecBase))[-36]))(TExecBase,s1,s2)

#define TCreatePort(tags) \
	(*(((TMODCALL struct TMsgPort *(**)(TAPTR,TTAGITEM *))(TExecBase))[-37]))(TExecBase,tags)

#define TPutMsg(port,replyport,msg) \
	(*(((TMODCALL void(**)(TAPTR,struct TMsgPort *,struct TMsgPort *,TAPTR))(TExecBase))[-38]))(TExecBase,port,replyport,msg)

#define TGetMsg(port) \
	(*(((TMODCALL TAPTR(**)(TAPTR,struct TMsgPort *))(TExecBase))[-39]))(TExecBase,port)

#define TAckMsg(msg) \
	(*(((TMODCALL void(**)(TAPTR,TAPTR))(TExecBase))[-40]))(TExecBase,msg)

#define TReplyMsg(msg) \
	(*(((TMODCALL void(**)(TAPTR,TAPTR))(TExecBase))[-41]))(TExecBase,msg)

#define TDropMsg(msg) \
	(*(((TMODCALL void(**)(TAPTR,TAPTR))(TExecBase))[-42]))(TExecBase,msg)

#define TSendMsg(port,msg) \
	(*(((TMODCALL TUINT(**)(TAPTR,struct TMsgPort *,TAPTR))(TExecBase))[-43]))(TExecBase,port,msg)

#define TWaitPort(port) \
	(*(((TMODCALL TAPTR(**)(TAPTR,struct TMsgPort *))(TExecBase))[-44]))(TExecBase,port)

#define TGetPortSignal(port) \
	(*(((TMODCALL TUINT(**)(TAPTR,struct TMsgPort *))(TExecBase))[-45]))(TExecBase,port)

#define TGetUserPort(task) \
	(*(((TMODCALL struct TMsgPort *(**)(TAPTR,struct TTask *))(TExecBase))[-46]))(TExecBase,task)

#define TGetSyncPort(task) \
	(*(((TMODCALL struct TMsgPort *(**)(TAPTR,struct TTask *))(TExecBase))[-47]))(TExecBase,task)

#define TCreateTask(func,ifunc,tags) \
	(*(((TMODCALL TAPTR(**)(TAPTR,TTASKFUNC,TINITFUNC,TTAGITEM *))(TExecBase))[-48]))(TExecBase,func,ifunc,tags)

#define TFindTask(name) \
	(*(((TMODCALL TAPTR(**)(TAPTR,TSTRPTR))(TExecBase))[-49]))(TExecBase,name)

#define TGetTaskData(task) \
	(*(((TMODCALL TAPTR(**)(TAPTR,struct TTask *))(TExecBase))[-50]))(TExecBase,task)

#define TSetTaskData(task,data) \
	(*(((TMODCALL TAPTR(**)(TAPTR,struct TTask *,TAPTR))(TExecBase))[-51]))(TExecBase,task,data)

#define TGetTaskMMU(task) \
	(*(((TMODCALL TAPTR(**)(TAPTR,struct TTask *))(TExecBase))[-52]))(TExecBase,task)

#define TAllocMsg(size) \
	(*(((TMODCALL TAPTR(**)(TAPTR,TUINT))(TExecBase))[-53]))(TExecBase,size)

#define TAllocMsg0(size) \
	(*(((TMODCALL TAPTR(**)(TAPTR,TUINT))(TExecBase))[-54]))(TExecBase,size)

#define TLockAtom(atom,mode) \
	(*(((TMODCALL struct TAtom *(**)(TAPTR,TAPTR,TUINT))(TExecBase))[-55]))(TExecBase,atom,mode)

#define TUnlockAtom(atom,mode) \
	(*(((TMODCALL void(**)(TAPTR,TAPTR,TUINT))(TExecBase))[-56]))(TExecBase,atom,mode)

#define TGetAtomData(atom) \
	(*(((TMODCALL TTAG(**)(TAPTR,TAPTR))(TExecBase))[-57]))(TExecBase,atom)

#define TSetAtomData(atom,data) \
	(*(((TMODCALL TTAG(**)(TAPTR,TAPTR,TTAG))(TExecBase))[-58]))(TExecBase,atom,data)

#define TCreatePool(tags) \
	(*(((TMODCALL struct TPool *(**)(TAPTR,TTAGITEM *))(TExecBase))[-59]))(TExecBase,tags)

#define TAllocPool(pool,size) \
	(*(((TMODCALL TAPTR(**)(TAPTR,struct TPool *,TUINT))(TExecBase))[-60]))(TExecBase,pool,size)

#define TFreePool(pool,mem,size) \
	(*(((TMODCALL void(**)(TAPTR,struct TPool *,TAPTR,TUINT))(TExecBase))[-61]))(TExecBase,pool,mem,size)

#define TReallocPool(pool,mem,oldsize,newsize) \
	(*(((TMODCALL TAPTR(**)(TAPTR,struct TPool *,TAPTR,TUINT,TUINT))(TExecBase))[-62]))(TExecBase,pool,mem,oldsize,newsize)

#define TPutIO(ioreq) \
	(*(((TMODCALL void(**)(TAPTR,struct TIORequest *))(TExecBase))[-63]))(TExecBase,ioreq)

#define TWaitIO(ioreq) \
	(*(((TMODCALL TINT(**)(TAPTR,struct TIORequest *))(TExecBase))[-64]))(TExecBase,ioreq)

#define TDoIO(ioreq) \
	(*(((TMODCALL TINT(**)(TAPTR,struct TIORequest *))(TExecBase))[-65]))(TExecBase,ioreq)

#define TCheckIO(ioreq) \
	(*(((TMODCALL TINT(**)(TAPTR,struct TIORequest *))(TExecBase))[-66]))(TExecBase,ioreq)

#define TAbortIO(ioreq) \
	(*(((TMODCALL TINT(**)(TAPTR,struct TIORequest *))(TExecBase))[-67]))(TExecBase,ioreq)

#define TInsertMsg(port,msg,prevmsg,status) \
	(*(((TMODCALL void(**)(TAPTR,struct TMsgPort *,TAPTR,TAPTR,TUINT))(TExecBase))[-68]))(TExecBase,port,msg,prevmsg,status)

#define TRemoveMsg(port,msg) \
	(*(((TMODCALL void(**)(TAPTR,struct TMsgPort *,TAPTR))(TExecBase))[-69]))(TExecBase,port,msg)

#define TGetMsgStatus(msg) \
	(*(((TMODCALL TUINT(**)(TAPTR,TAPTR))(TExecBase))[-70]))(TExecBase,msg)

#define TSetMsgReplyPort(msg,rport) \
	(*(((TMODCALL TUINT(**)(TAPTR,TAPTR,struct TMsgPort *))(TExecBase))[-71]))(TExecBase,msg,rport)

#define TSetPortHook(port,hook) \
	(*(((TMODCALL struct THook *(**)(TAPTR,struct TMsgPort *,struct THook *))(TExecBase))[-72]))(TExecBase,port,hook)

#define TAddModules(im,flags) \
	(*(((TMODCALL TBOOL(**)(TAPTR,struct TModInitNode *,TUINT))(TExecBase))[-73]))(TExecBase,im,flags)

#define TRemModules(im,flags) \
	(*(((TMODCALL TBOOL(**)(TAPTR,struct TModInitNode *,TUINT))(TExecBase))[-74]))(TExecBase,im,flags)

#define TAllocTimeRequest(tags) \
	(*(((TMODCALL TAPTR(**)(TAPTR,TTAGITEM *))(TExecBase))[-75]))(TExecBase,tags)

#define TFreeTimeRequest(req) \
	(*(((TMODCALL void(**)(TAPTR,TAPTR))(TExecBase))[-76]))(TExecBase,req)

#define TGetSystemTime(t) \
	(*(((TMODCALL void(**)(TAPTR,TTIME *))(TExecBase))[-77]))(TExecBase,t)

#define TGetUniversalDate(dt) \
	(*(((TMODCALL TINT(**)(TAPTR,TDATE *))(TExecBase))[-78]))(TExecBase,dt)

#define TGetLocalDate(dt) \
	(*(((TMODCALL TINT(**)(TAPTR,TDATE *))(TExecBase))[-79]))(TExecBase,dt)

#define TWaitTime(t,sig) \
	(*(((TMODCALL TUINT(**)(TAPTR,TTIME *,TUINT))(TExecBase))[-80]))(TExecBase,t,sig)

#define TWaitDate(dt,sig) \
	(*(((TMODCALL TUINT(**)(TAPTR,TDATE *,TUINT))(TExecBase))[-81]))(TExecBase,dt,sig)

#endif /* _TEK_INLINE_EXEC_H */
