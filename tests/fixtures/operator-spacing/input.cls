Import sqluser

Class web.DHCST.DHCINIsTrf Extends (%RegisteredObject, %XML.Adaptor, StkTypeG) [ Not ProcedureBlock ]
{

Parameter AppName [ Final ] = "DHCSTTRANSFER";

/// Descript:   保存/更新出库单信息
/// Creater:    ZhangDongmei
/// CreateDate: 2012-07-20
/// Table:DHC_InIsTrf,DHC_InIsTrfItm
/// Input:出库主表id;
/// 供应科室RowId^请求科室RowId^库存转移请求单RowId^出库类型RowId^完成标志^单据状态^制单人RowId^类组RowId^库存类型^备注^入库单id,
/// 明细id^批次id^数量^单位^请求明细id^备注，明细id^批次id^数量^单位^请求明细id^备注
/// Output:     
/// Return：成功：出库主表id；
/// 失败：ErrCode:ErrInfo
/// 
ClassMethod Save(InitId As %String, MainInfo As %String, ListData As %String) As %Library.String
{
    n (InitId,MainInfo,ListData)
    tstart
    s $ZT="Error^DHCSTERROR"                        ;增加错误处理
    s MainId=""
    s Ret=..Update(InitId,MainInfo)
    i +Ret>0  d
    .s MainId=Ret
    e  i Ret=-99  d
    .s ErrInfo=..Trans("加锁失败")
    e  i Ret=-2   d
    .s ErrInfo=..Trans("生成单号失败")
    e  i Ret=-101   d
    .s ErrInfo=..Trans("转移单已完成或者已出库,不能再次保存!")
    e  d
    .s ErrInfo=..Trans("保存转移单主表失败")
    ;b ;1
    i Ret<0 trollback
    q:MainId="" Ret_":"_ErrInfo
    ;
    s Ret=##class(web.DHCST.DHCINIsTrfItm).Save(MainId,ListData)
    
    i +Ret'=0 trollback   ;存在明细保存失败
    q:+Ret'=0 Ret   ;存在保存失败的明细
    ;i (+Ret=-6)!(+Ret=-5) trollback
    ;q:(+Ret=-6)!(+Ret=-5) -5 
    
    b ;tc
    tcommit    ;全部保存成功，则提交事务
    ;
    q MainId
}

/// 插入或更新转移主表记录
/// Author:zhwh
/// Date:2012-07-13
/// Argu:
///    init - 主表rowid
///    data - 数据串
///    
/// Return:
///   > 0  - 库存转移主表rowid
///   <0 - 插入或更新错误
ClassMethod Update(init As %String, data As %String) As %String
{
 n (init,data)
 s frLoc=$p(data,"^",1) //供应科室RowId
 s toLoc=$p(data,"^",2) //请求科室RowId
 s req=$p(data,"^",3)   //库存转移请求单RowId
 s opType=$p(data,"^",4) //出库类型RowId
 i opType="" s opType=..DefaultOpType()
 s comp=$p(data,"^",5) //“完成”标志
 s status=$p(data,"^",6) //单据状态
 s user=$p(data,"^",7) //制单人RowId
 s scg=$p(data,"^",8) //类组RowId
 s stkType=$p(data,"^",9) //库存类型
 s remark=$p(data,"^",10) //备注
 s remark=$lfs(remark,$c(3))
 s ingrid=$p(data,"^",11) //入库单id,zdm,2012-10-22	;依入库单转移时用到
 
 i (scg="") && (ingrid'="") d
 .s scg=$p(^DHCINGR(ingrid),"^",28)		;依入库单转移时用到
 
 i (scg="") && (req'="") d
 .&sql(select INRQ_RowId into :inrq from DHC_INRequest where INRQ_INRQ_DR=:req)
 .q:inrq=""
 .s scg=$p(^DHCINRQ(inrq),"^",10)
 .i scg="" s scg=3
 s d=+$h
 s t=$p($h,",",2)
 s AppName=..%GetParameter("AppName")
 ;
 s result=0
 i init="" d
 . 
 .;生成单号需加锁
 .s ret=##class(web.DHCST.Common.AppCommon).Lock("TRANSFERNO")  
 .s:ret'=0 result=-99  ;加锁失败
 .q:ret'=0
 .;
 .s TrNo=##class(web.DHCST.Common.AppCommon).GetAppNo(AppName,scg,frLoc)
 .;b ;222
 .s:TrNo="" result=-2   ;生成单号失败
 .i TrNo="" d ##class(web.DHCST.Common.AppCommon).UnLock("TRANSFERNO")
 .q:TrNo=""
 .&sql(insert into dhc_inistrf (INIT_No, init_frloc_dr,
  init_toloc_dr,init_inrq_dr,init_date,init_time,init_ssusr_dr,
  init_state,init_usercompleted,init_scg_dr,init_stktype,
  INIT_OperateType,INIT_INGR_Dr,INIT_Remarks)
  values (:TrNo,:frLoc,:toLoc,:req,:d,:t,:user,:status,:comp,:scg,:stkType,:opType,:ingrid,:remark) )
 .;b ;1
 .i SQLCODE'=0  d
 ..s ret=$$ErrorRecord^DHCSTERROR(..%GetParameter("AppName"),TrNo,SQLCODE_":"_%msg)
 ..s result=-1
 .e  d
 ..s result=%ROWID
 .d ##class(web.DHCST.Common.AppCommon).UnLock("TRANSFERNO")
 e  d
 .s ret=..AllowDel(init)
 .s:ret<0 result=-101
 .q:result<0
 .s obj=##class(User.DHCInIsTrf).%OpenId(init)
 .d obj.%Reload()
 .
 .s obj.INITFrLocDR=##class(User.CTLoc).%OpenId(frLoc,0)
 .s result=obj.%Id()
 .
 .s obj.INITToLocDR=##class(User.CTLoc).%OpenId(toLoc,0)
 .s obj.INITINRQDR=##class(User.INRequest).%OpenId(req,0)
 .//s obj.INITDate=d
 .//s obj.INITTime=t
 .s obj.INITOperateType=##class(User.DHCOperateType).%OpenId(opType,0)
 .s obj.INITState= status
 .s obj.INITSCGDR =##class(User.DHCStkCatGroup).%OpenId(scg,0)
 .s obj.INITStkType=stkType
 .s obj.INITSSUSRDR=##class(User.SSUser).%OpenId(user,0)
 .s obj.INITUserCompleted=comp
 .d obj.INITRemarks.Clear()
 .d obj.INITRemarks.InsertList(remark)
 .;b ;123
 .s sc=obj.%Save()
 .i $$$ISERR(sc) s result=-1
 .;b ;124
 q +result
}

/// 取库存转移主表记录数据串
/// Author:zhwh
/// Date:2012-07-13
/// Argu:
///   init - 库存转移主表 RowId
/// Return:
ClassMethod Select(init As %String) As %String
{
 k PLIST
 s result=""
 
 &sql(select * into :PLIST() from DHC_INIsTrf where %ID=:init )
 q:SQLCODE'=0 result
 s memoDelim=##class(web.DHCST.Common.UtilCommon).MemoDelim()
 s PLIST(10)=$lts(PLIST(10),memoDelim)  //备注处理
 s cnt=$o(PLIST(""),-1)
 s cnt=26 //2015-02-15 赵志端 库存转移打印主信息错误和简单界面查询信息错误
 f i=1:1:cnt d
 .i result=""  s result=$g(PLIST(i))
 .e  s result=result_"^"_$g(PLIST(i))
 .
 s INITDate=PLIST(6)
 s INITTime=PLIST(12)
 s FrLocId=PLIST(7)
 s ToLocId=PLIST(13)
 s INITUser=PLIST(11)
 s:INITDate'="" INITDate=##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(INITDate,"ST")
 s:INITTime'="" INITTime=##class(web.DHCSTInterfaceFromElse).TimeLogicalToHtml(INITTime,"ST")
 s:FrLocId'="" FrLocDesc=$p(^CTLOC(FrLocId),"^",2)
 s:ToLocId'="" ToLocDesc=$p(^CTLOC(ToLocId),"^",2)
 s:INITUser'="" INITUserName=$p(^SSU("SSUSR",INITUser),"^",2)
 s ReqId=PLIST(8)
 s:+ReqId'=0 ReqNo=$p(^INRQ(ReqId),"^",1)
 s OperateType=PLIST(22)
 s OperateTypeDesc=""
 s:OperateType'="" OperateTypeDesc=$p(^DHCOPTYPE(OperateType),"^",2)
 s result=result_"^"_$g(FrLocDesc)_"^"_$g(ToLocDesc)_"^"_$g(ReqNo)_"^"_INITDate_"^"_$g(ReqId)_"^"_$g(INITUserName)_"^"_$g(OperateTypeDesc)_"^"_$g(INITTime)
 q result
}

/// 删除库存转移主表记录
/// Author:zhwh
/// Date:2012-07-13
/// Argu:
///   init - 库存转移主表 RowId
/// Return:
///  0 -success
///  <0 - failure
/// w ##Class(web.DHCST.DHCINIsTrf).Delete(100)
ClassMethod Delete(init As %String) As %String
{
 q:init="" -1
 q:..lock(init)<0 -99
 ;
 i ..AllowDel(init)<0 d ..uLock(init) q -2
 ;zdm,2012-10-22,增加占用数量处理、事务
 ts
 s $ZT="Error^DHCSTERROR"
 s ret=..HandleTransDirtyQty(init,0)   ;减去占用数量处理
 i ret'=0  tro  d ..uLock(init)  q -3  ;处理占用数量失败
 ;
 &sql(delete from dhc_inistrf where %ID=:init)
 i SQLCODE'=0  tro  d ..uLock(init)  q SQLCODE
 
 //恢复拒绝接收单据状态
 s RefuseInit=$O(^DHCINIT(0,"AgainINIT",init,""))
 i RefuseInit'="" d
 .s status=$P(^DHCINIT(RefuseInit),"^",14)
 .s RefuseNo=$P(^DHCINIT(RefuseInit),"^",1)
 .i status'=40 s ret=-5_..Trans("^对应的拒绝接收单据")_RefuseNo_..Trans("状态不为作废状态!")
 .s RefuseStatus=30
 .&sql(UPDATE DHC_InIsTrf SET INIT_State=:RefuseStatus WHERE INIT_RowId =:RefuseInit)
 .i SQLCODE'=0 s ret=SQLCODE
 
 i ret'=0  tro  d ..uLock(init)  q ret  ;处理占用数量失败
 ;
 tc
 d ..uLock(init)
 q 0
}

/// 是否允许删除
/// Author:zhwh
/// Date:2012-07-13
/// Argu:
///   init - 库存转移主表 RowId
/// Return:
///    0 - 可以
///    <0 - 不可以
/// 
ClassMethod AllowDel(init As %String) As %String
{
  s obj=##class(User.DHCInIsTrf).%OpenId(init,0) 
  Do obj.%Reload()
  ;
  s comp=obj.INITUserCompleted
  s status=obj.INITState
  
  i +status=11 q -2
  i +status=21 q -3
  i +status=31 q -4
  i comp="Y" q -1
  q 0
}

/// 设置库存转移单“完成”状态
/// Author:zhwh
/// Date:2012-07-16
/// Argu:
///   init - 库存转移主表 RowId
/// Return:
///   0 - SUccess
///   <0 -failure
///   
ClassMethod SetCompleted(init As %String, comp As %String, status As %String, type As %String) As %String
{
 n (init,comp,status,type)
 q:..lock(init)<0 -99   //锁定
 
 &sql(select init_state into :tmpstatus from dhc_inistrf where %ID=:init)
 i (+$G(tmpstatus)>20) && (+$G(tmpstatus)'=30)  d ..uLock(init)  q -1   //已经审核，不允许再设置状态 //回退的单子,置为"未完成"状态
 ;
 s ErrId=0
 ;zdm,2012-10-19,增加数据验证
 i comp="Y"  d
 .s ErrId=..CheckDataValid(init)
 i ErrId'=0  d
 .s ErrInfo=##class(web.DHCST.ErrorRecord).GetErrorInfo(ErrId)
 .
 i ErrId'=0 d ..uLock(init)  q -5_":"_$g(ErrInfo)  //出库单数据验证不通过
 ;
 ;zdm,2012-10-17,根据参数配置确定库存转移完成时是否自动出库审核
 s LocId=$p(^DHCINIT(init),"^",5)    ;出库科室
 s UserId=$p(^DHCINIT(init),"^",8)
 s AutoAckOut=""
 i comp="Y"  d       
 .s GroupId=$p(^SSU("SSUSR",UserId),"^",5)
 .s HospId=$p(^CTLOC(LocId),"^",22)
 .s Params=GroupId_"^"_LocId_"^"_UserId_"^"_HospId
 .s AutoAckOut=##class(web.DHCST.Common.AppCommon).GetAppPropValue(..%GetParameter("AppName"),"AutoAckOutAfterCompleted",Params)
 .
 ts
 s $ZT="Error^DHCSTERROR"
 &sql(UPDATE dhc_inistrf set init_usercompleted=:comp,init_state=:status,INIT_OperateType=:type where %ID=:init)
 i SQLCODE'=0  d ..uLock(init) tro  q -2
 &sql(UPDATE DHC_InIsTrfItm SET DHCITI_State=:status WHERE INITI_INIT_ParRef =:init)
 i SQLCODE'=0  d ..uLock(init) tro  q -2
 d ..uLock(init)
 s Ret=0
 i (comp="Y")&(AutoAckOut="Y")  d
 .s Ret=..TransOutAuditYes(init,UserId)
 i Ret'=0 tro 
 q:Ret'=0 -3
 tc
 q 0
}

/// Descript:根据请求单生成出库单
/// Creater:ZhangDongmei
/// CreateDate: 2012-10-15
/// Table:DHC_InIsTrf,DHC_InIsTrfItm
/// Input:供应科室RowId^请求科室RowId^制单人RowId,请求单id
/// Output:     
/// Return：成功：出库主表id；
/// -12  ;请求单id不能为空
/// -10   ;供应科室不能为空
/// -11   ;请求科室不能为空
/// -13   ;没有要出库的明细
/// -99  ;加锁失败
/// -2   ;生成出库单号失败
/// -1    ;保存出库单失败
/// -5:保存出库单明细失败
/// -6其它：处理占用数量失败
/// 
ClassMethod CreateTransferByReq(MainInfo As %String, ReqId As %String) As %String
{
    n (MainInfo,ReqId)
    q:ReqId="" -12  ;请求单id不能为空
    s FrLocId=$p(MainInfo,"^",1)
    s ToLocId=$p(MainInfo,"^",2)
    s UserId=$p(MainInfo,"^",3)
    q:FrLocId="" -10   ;供应科室不能为空
    q:ToLocId="" -11   ;请求科室不能为空
    s OpTypeId=..DefaultOpType()
    s HospId=$p($g(^CTLOC(FrLocId)),"^",22)    
    s Complete="N"
    s Status="10"
    s StkGrpId=""
    &sql(select INRQ_RowId into :Inrqrowid from DHC_INRequest where INRQ_INRQ_DR=:ReqId)
    s:Inrqrowid'="" StkGrpId=$p(^DHCINRQ(Inrqrowid),"^",10)
    s StkType=..sssCode()
    s Remark=""
    tstart
    s $ZT="Error^DHCSTERROR"
    s MainData=FrLocId_"^"_ToLocId_"^"_ReqId_"^"_OpTypeId_"^"_Complete_"^"_Status_"^"_UserId_"^"_StkGrpId_"^"_StkType_"^"_Remark
    s MainId=""
    s Ret=..Update("",MainData)
    ;b ;1
    i +Ret>0  d
    .s MainId=Ret
    ;b ;1
    i MainId<0 trollback
    q:MainId="" Ret
    s ListDetail=""
    s Err=0
    s allTransed=0
    s Count=0
    s Chl=0
    f  s Chl=$o(^INRQ(ReqId,"RQI",Chl)) q:(Chl="")!(Err'=0)  d
    .s Inrqi=ReqId_"||"_Chl
    .s ReqStr=^INRQ(ReqId,"RQI",Chl)
    .s Rem=$g(^INRQ(ReqId,"RQI",Chl,"REM",0))
    .s InciDr=$p(ReqStr,"^",4) 
    .q:InciDr=""  
    .s ReqQty=+$p(ReqStr,"^",3)
    .s UomDr=+$p(ReqStr,"^",5)
    .s refuseflag=$p(ReqStr,"^",6)
    .q:refuseflag="Y" //过滤作废的明细
    .s TransQty=##class(web.DHCST.DHCINIsTrf).TransQty(Inrqi)   ;已转移数量
    .s BUomDr=$p(^INCI(InciDr,1),"^",10)
    .s PurUomDr=$p(^INCI(InciDr,3),"^",6)
    .s ConFac=##class(web.DHCST.Common.UtilCommon).UOMFac(+PurUomDr,+BUomDr)
    .s Fac=##class(web.DHCST.Common.UtilCommon).UOMFac(UomDr,BUomDr)
    .s NotTrQty=ReqQty*Fac-TransQty    ;未转移数量(基本单位)
    .q:NotTrQty'>0     ;全部转移的明细过滤掉
    .s allTransed=1
    .s ExistFlag=0   ;标识是否存在可转移的批次
    .s pid=##class(web.DHCST.DHCINIsTrfItm).GetInclbForTransfer(FrLocId,InciDr,NotTrQty)
    .i pid'=""  d
    ..s Inclb=""
    ..f  s Inclb=$o(^TMPGETINCLB(pid,Inclb)) q:(Inclb="")!(Err'=0)  d
    ...s IncInfo=^TMPGETINCLB(pid,Inclb)    ;批次信息
    ...s Qty=$p(IncInfo,"^",7)     ;批次转移数量
    ...s InclbId=$p(IncInfo,"^",4)
    ...//此处判断是使用基本单位还是入库单位，为了避免无限小数的出现 2020-02-15 yangsj
    ...i Qty#Fac'=0  d
    ....s UomDr=BUomDr
    ...e  d
    ....s Qty=Qty/Fac
    ...
    ...s ExistFlag=1
    ...//s Rp=##class(web.DHCST.Common.PriceCommon).GetClbRp(Inclb,UomDr,HospId)
    ...s Rp=##class(web.DHCST.Common.PriceCommon).GetClbRp(InclbId,UomDr,HospId,"G",+$h,"")
    ...s Sp=##class(web.DHCST.Common.PriceCommon).GetPriceElse(InclbId,+$h,UomDr,HospId,"G","")  
    ...s NewSp=##class(web.DHCST.Common.PriceCommon).BatSpUom(InclbId,UomDr,HospId)
    ...s SpAmt=Sp*Qty
    ...s RpAmt=Rp*Qty
    ...s NewSpAmt=NewSp*Qty
    ...s SpAmt=##class(web.DHCST.Common.AppCommon).FormatSpAmt(SpAmt,HospId)
    ...s NewSpAmt=##class(web.DHCST.Common.AppCommon).FormatSpAmt(NewSpAmt,HospId)
    ...s RpAmt=##class(web.DHCST.Common.AppCommon).FormatRpAmt(RpAmt,HospId)
    ...s Remark=""
    ...s Data1=InclbId_"^"_Qty_"^"_UomDr_"^"_Inrqi_"^"_Rp_"^"_RpAmt_"^"_Sp_"^"_SpAmt
    ...s Data2=Rp_"^"_RpAmt_"^"_NewSp_"^"_NewSpAmt_"^"_Remark
    ...s Detail=Data1_"^"_Data2
    ...s Count=Count+1
    ...;保存明细
    ...s Ret=##class(web.DHCST.DHCINIsTrfItm).Update("",MainId,Detail)
    ...i +Ret<=0  s Err=-5    ;保存明细失败
    ...q:+Ret<=0
    ...;增加新占用库存
    ...s Rowid=Ret
    ...s Ret=##class(web.DHCST.DHCINIsTrf).HandleTransItmDirtyQty(Rowid,1)  ;增加新占用库存
    ...i Ret'=0  s Err=-6    ;增加占用库存失败
    ...q:Ret'=0
    ...
    ..k ^TMPGETINCLB(pid)
    ..q:Err'=0
    ..
    .q:Err'=0
    .i ExistFlag=0  d    ;没找到可出库的批次
    ..;s Qty=NotTrQty/Fac
    ..;s Detail="^"_Qty_"^"_UomDr_"^"_Inrqi_"^^^"_Sp_"^"_SpAmt_"^^^^^"
    i allTransed=0 s Err=-8 //yunhaibao20160308,判断是否有可转移批次,优先级第一
    i Err'=0 trollback
    q:Err'=0 Err
    i Count<1  trollback
    q:Count<1 -7
    tcommit
    q MainId
}

/// 设置库存转移单“出库审核通过”状态
/// Author:zhwh
/// Date:2012-07-13
/// Argu:
///   init - 库存转移主表 RowId
/// Return:
/// w ##class(web.DHCST.DHCINIsTrf).TransOutAuditYes(6391,590)
ClassMethod TransOutAuditYes(init As %String, user As %String) As %String
{
  //加锁
  q:..lock(init)<0 -99  

  //验证数据
  //s ret=..CheckDataValid(init)
  //i ret'="" d ..uLock(init)  q ret
  ;
  s status=""
  &sql(select init_state into :status from dhc_inistrf where %ID=:init)
  i status'="11" d ..uLock(init) q -100
  ;
  ;zdm,2012-10-19,增加数据验证
  s ErrId=..CheckDataValid(init)
  i ErrId'=0  d
  .s ErrInfo=##class(web.DHCST.ErrorRecord).GetErrorInfo(ErrId)
  .
  i ErrId'=0 d ..uLock(init)  q -101_":"_$g(ErrInfo)  //出库单数据验证不通过
  
  s ret = ##class(PHA.IN.MonSettle.Save).CheckCanAudit(init)
  i (ret '= "Y") d ..uLock(init) q -102_":"_"科室月结配置：开启自动接收配置时在自动接收任务执行时间禁止审核转移单"
  ;
  //设置状态值
  s newStatus="21"
  s d=+$h,t=$p($h,",",2)
  ts
  s $ZT="Error^DHCSTERROR"
 &sql(UPDATE dhc_inistrf set init_state=:newStatus,init_ackdate=:d,init_acktime=:t,init_ackuser_dr=:user 
   where %ID=:init)
 i SQLCODE'=0 tro  d ..uLock(init) q -1
 //处理库存(转出), 台账, 占用数
 s err=0,ret=0
 s initNo=$p(^DHCINIT(init),"^",1)
 s initFromLoc=$p(^DHCINIT(init),"^",5)
 s HospID=""
 i initFromLoc'="" s HospID=$p($g(^CTLOC(initFromLoc)),"^",22)
 s type="T"
 s ch=0
 f  s ch=$o(^DHCINIT(init,"ITI",ch)) q:(ch="")!(err'=0)  d
 .s initi=init_"||"_ch
 .s initiStatus=$p(^DHCINIT(init,"ITI",ch),"^",23)
 .q:initiStatus="21"
 .s inclb=$p(^DHCINIT(init,"ITI",ch),"^",3)
 .s qty=$p(^DHCINIT(init,"ITI",ch),"^",1)
 .s trQty=qty
 .s uom=$p(^DHCINIT(init,"ITI",ch),"^",7)
 .s inci=+inclb
 .s buom=$P(^INCI(inci,1),"^",10)
 .s fac=##class(web.DHCST.Common.UtilCommon).UOMFac(uom,buom)
 .s qty=qty*fac
 .s rp=##class(web.DHCST.Common.PriceCommon).GetClbRp(inclb,uom,HospID,..sssCode(),+$h,"")
 .s sp=##class(web.DHCST.Common.PriceCommon).GetPriceElse(inclb,+$h,uom,HospID,..sssCode(),"")
 .s rpAmt=trQty*rp
 .s spAmt=trQty*sp
 .s spAmt=##class(web.DHCST.Common.AppCommon).FormatSpAmt(spAmt,HospID)
 .s rpAmt=##class(web.DHCST.Common.AppCommon).FormatRpAmt(rpAmt,HospID)
 .s $p(^DHCINIT(init,"ITI",ch),"^",15)=rp
 .s $p(^DHCINIT(init,"ITI",ch),"^",16)=rpAmt
 .s $p(^DHCINIT(init,"ITI",ch),"^",17)=sp
 .s $p(^DHCINIT(init,"ITI",ch),"^",18)=spAmt
 .s ret=##class(web.DHCST.Common.StockHandle).UpdateStock(inclb,-qty)
 .i ret<0 tro  s err=-3  q 
 .s trData=type
 .s trData=trData_"^"_initNo
 .s trData=trData_"^"_inclb
 .s trData=trData_"^"_-trQty
 .s trData=trData_"^"_uom
 .s trData=trData_"^"_sp
 .s trData=trData_"^"_user
 .s trData=trData_"^"_initi
 .s trData=trData_"^"_rp
 .s trData=trData_"^"_-rpAmt
 .s trData=trData_"^"_-spAmt
 .
 .//插入台账
 .s ret=##class(web.DHCST.Common.StockHandle).IntoTrans(trData)
 .;b ;4
 .i ret<0 tro   s err=-4  q 
 .
 .//更新子表记录状态
 .&sql(update dhc_inistrfitm set dhciti_state=:newStatus where %ID=:initi)
 .;b ;5
 .i SQLCODE'=0 tro  s err=-5 q
 .
 .//处理批次dirtyQty
 .s ret=..HandleTransItmDirtyQty(initi,0)
 .;b ;6
 .i ret<0 tro   s err=-6  q 
 .
 ;b ;7
 i err=0  tc      ;出库审核提交
 d ..uLock(init)
 ;b ;8
 ;zdm,2012-10-17,根据参数配置确定出库审核时是否自动接收
 s LocId=$p(^DHCINIT(init),"^",6)    ;接收科室
 s AutoAckIn=""
 s UserId=""
 s GroupId=""
 s HospId=$p(^CTLOC(LocId),"^",22)
 s Params=GroupId_"^"_LocId_"^"_UserId_"^"_HospId
 s AutoAckIn=##class(web.DHCST.Common.AppCommon).GetAppPropValue(..%GetParameter("AppName"),"AutoAckInAfterAckOut",Params)
 i AutoAckIn="Y"  d
 .s ret=..TransInAuditYes(init,UserId)
 .i ret'=0 s err=-7
 .
 q err
}

/// 设置库存转移单“出库审核拒绝”状态
/// Author:zhwh
/// Date:2012-07-13
/// Argu:
///   init - 库存转移主表 RowId
/// Return:
ClassMethod TransOutAuditNo(init As %String, user As %String) As %String
{
  //加锁
  q:..lock(init)<0 -99  

  //检查状态
  s status=""
  &sql(select init_state into :status from dhc_inistrf where %ID=:init)
  i (status'="11")  d ..uLock(init) q -100   //&& (status'="30")
  ;zdm,2012-07-24,增加事务处理和错误处理
  ts
  s $ZT="Error^DHCSTERROR"  
  //设置状态值
  s newStatus="20"
  s d=+$h,t=$p($h,",",2)
 &sql(UPDATE dhc_inistrf set init_state=:newStatus, init_ackdate=:d,init_acktime=:t,init_ackuser_dr=:user 
   where %ID=:init)
 i SQLCODE'=0 tro  d ..uLock(init) q -1
 &sql(update dhc_inistrfitm set dhciti_state=:newStatus where initi_init_parref=:init)
 i SQLCODE'=0 tro  d ..uLock(init) q -2
 
 s comp="N"
 &sql(UPDATE dhc_inistrf set init_usercompleted=:comp  where %ID=:init)
 i SQLCODE'=0 tro  d ..uLock(init) q -3
 tc
 d ..uLock(init)
 q 0
}

/// 设置库存转移单“入库审核通过”状态
/// Author:zhwh
/// Date:2012-07-13
/// Argu:
///   init - 库存转移主表 RowId
/// Return:
/// w ##class(web.DHCST.DHCINIsTrf).TransInAuditYes(25,13609)
ClassMethod TransInAuditYes(init As %String, user As %String) As %String
{
 n (init,user)
 //加锁
 q:..lock(init)<0 -99  
 //检查状态
 s status=""
 &sql(select init_state into :status from dhc_inistrf where %ID=:init)
 i status'="21" d ..uLock(init) q -100
 ts
 s newStatus="31"
 s d=+$h,t=$p($h,",",2)
 &sql(UPDATE dhc_inistrf set init_state=:newStatus,init_inackdate=:d,init_inacktime=:t,init_inackuser_dr=:user 
   where %ID=:init)
 i SQLCODE'=0 tro  d ..uLock(init) q -1
   &sql(update dhc_inistrfitm set dhciti_state=:newStatus where initi_init_parref=:init)
 i SQLCODE'=0 tro  d ..uLock(init) q -2
 
 //处理库存，台账记录
 //-------出库科室出库审核后，医院调价立即生效，接收科室入库审核不产生损益 zzd添加
 s toloc=$p(^DHCINIT(init),"^",6)
 s CustStr=##Class(web.DHCSTCOMMO).GetLocCust(toloc)
 s HospID=$p(CustStr,"^",5)
 s CustID=$p(CustStr,"^",1)
 //-------出库科室出库审核后，医院调价立即生效，接收科室入库审核不产生损益 zzd添加
 s err=0,ret=0
 s initNo=$p(^DHCINIT(init),"^",1)
 s type="K"
 s ch=0
 f  s ch=$o(^DHCINIT(init,"ITI",ch)) q:(ch="")!(err'=0)  d
 .s initi=init_"||"_ch
 .s inclb=$p(^DHCINIT(init,"ITI",ch),"^",3)
 .
 .s toInclb=..GetToLocINCLB(initi)  //取入方科室的库存批次rowid
 .
 .s qty=$p(^DHCINIT(init,"ITI",ch),"^",1)
 .s trQty=qty
 .s uom=$p(^DHCINIT(init,"ITI",ch),"^",7)
 .s inci=+inclb
 .s buom=$P(^INCI(inci,1),"^",10)
 .s fac=##class(web.DHCST.Common.UtilCommon).UOMFac(uom,buom)
 .s qty=qty*fac
 .s rp=$p(^DHCINIT(init,"ITI",ch),"^",15)
 .s rpAmt=$p(^DHCINIT(init,"ITI",ch),"^",16)
 .s sp=$p(^DHCINIT(init,"ITI",ch),"^",17)
 .s spAmt=$p(^DHCINIT(init,"ITI",ch),"^",18)
 .// 跨院区价格补充
 .s UpdatePriceFlag = ..UpdatePriceForInitByHosp(initi,toInclb)
 .i (UpdatePriceFlag '= 0) s err = UpdatePriceFlag tro  q
 .s ret=##class(web.DHCST.Common.StockHandle).UpdateStock(toInclb,qty)
 .i ret<0 tro  s err=-3  q 
 .
 .s trData=type
 .s trData=trData_"^"_initNo
 .s trData=trData_"^"_toInclb
 .s trData=trData_"^"_+trQty
 .s trData=trData_"^"_uom
 .s trData=trData_"^"_+sp
 .s trData=trData_"^"_user
 .s trData=trData_"^"_initi
 .s trData=trData_"^"_+rp
 .s trData=trData_"^"_+rpAmt
 .s trData=trData_"^"_+spAmt
 .
 .s ret=##class(web.DHCST.Common.StockHandle).IntoTrans(trData)
 .i ret<0 tro   s err=-4  q 
 .//-------出库科室出库审核后，医院调价立即生效，接收科室入库审核不产生损益 zzd添加 
 .s LocID=toloc
 .s sPrice=sp
 .s sTrRowID=initi //存业务表id
 .s DataStr=toInclb_"^"_inci_"^"_LocID_"^"_+sp_"^"_+trQty_"^"_+spAmt_"^"_user_"^"_sTrRowID_"^"_type_"^"_+rp_"^"_+rpAmt_"^"_HospID_"^"_uom_"^"_CustID
 .s ret=..InsertRetAsp(DataStr)
 .i ret<0 tro   s err=-5 q 
 .//-------出库科室出库审核后，医院调价立即生效，接收科室入库审核不产生损益 zzd添加
 i err=0  tc
 d ..uLock(init)
 q err
}

/// 设置库存转移单“入库审核拒绝”状态
/// Author:zhwh
/// Date:2012-07-13
/// Argu:
///   init - 库存转移主表 RowId
/// Return:
ClassMethod TransInAuditNo(init As %String, user As %String) As %String
{
 n (init,user)
 //加锁
 q:..lock(init)<0 -99  
 //检查状态
 s status=""
 &sql(select init_state into :status from dhc_inistrf where %ID=:init)
 i status'="21" d ..uLock(init) q -100
 s Todate=0
 s frloc=$p(^DHCINIT(init),"^",5)
 s arcdate=$p(^DHCINIT(init),"^",9)
 s sm=$o(^DHCSM(0,"CTLOC",frloc,""),-1)
 i sm'="" s Todate=$p(^DHCSM(sm),"^",4)
 i (Todate-arcdate)'<0 d ..uLock(init) q -201 		//出库科室已月结，不允许执行 “拒绝入库” 操作 add zzd
 i ..IfAuditPart(init)=1 d ..uLock(init) q -202     //hulihua 2016-01-07 做了部分接收的不能"拒绝入库"！
 ts
 s newStatus="30"
 s d=+$h,t=$p($h,",",2),Completed="N"
 &sql(UPDATE dhc_inistrf set init_state=:newStatus, init_inackdate=:d,init_inacktime=:t,init_inackuser_dr=:user,INIT_UserCompleted=:Completed 
 where %ID=:init)
 i SQLCODE'=0 tro  d ..uLock(init) q -1
  //回退出方的库存和台账
 s err=0,ret=0
 s type="T"
 s ch=0
 f  s ch=$o(^DHCINIT(init,"ITI",ch)) q:(ch="")!(ret'=0)  d
 .s initi=init_"||"_ch
 .
 .s status=$p(^DHCINIT(init,"ITI",ch),"^",23)
 .q:status'="21"
 .
 .//恢复库存，清除台账
 .s ret=##class(web.DHCST.Common.StockHandle).DelIntrs(type,initi)
 .i ret<0 tro  s err=-3  q 
 .
 .//恢复占用数量
 .s ret=..HandleTransItmDirtyQty(initi,1)
 .i ret<0 tro  s err=-4  q 
 .//拒绝接收,损益添加到对应的调价损益
 .s ret=..InsertAsp(initi)
 .i ret<0 tro  s err=-6 q
 .&sql(update dhc_inistrfitm set dhciti_state=:newStatus where %ID=:initi)
 .i SQLCODE<0 tro  s err=-5  q 
 .
 i err=0  tc
 d ..uLock(init)
 q err
}

/// 库存转移单解锁
/// Date:2012-07-13
/// Argu:
///   init - 库存转移主表 RowId
/// Return:
///   0 - success
///   <0 - failure
ClassMethod lock(init As %String) As %String
{
 q:init="" 0
 q ##class(web.DHCST.Common.AppCommon).Lock(..%GetParameter("AppName")_init)
}

/// 库存转移单解锁
/// Date:2012-07-13
/// Argu:
///   init - 库存转移主表 RowId
ClassMethod uLock(init As %String)
{
 d ##class(web.DHCST.Common.AppCommon).UnLock(..%GetParameter("AppName")_init)
 q
}

/// 处理占用数量(整单)
/// Date:2012-07-13
/// Argu:
///   init - 库存转移主表 RowId
///   sign - 处理符号
/// Return:
///  0 - success
///  <0 -failure
ClassMethod HandleTransDirtyQty(init As %String, sign As %String) As %String
{
 s err=0
 //tstart
 s ch=0
 ;
 f  s ch=$o(^DHCINIT(init,"ITI",ch))  q:(ch="")!(err<0)  d
 .s initi=init_"||"_ch
 .
 .s err=..HandleTransItmDirtyQty(initi,sign)
 .
 //i err<0 trollback
 //tcommit
 q err
}

/// 处理库存转移明细记录的占用数量
/// Date:2012-07-13
/// Argu:
///   initi - 库存转移子表 RowId
///   sign- 处理符号(1 - 加  0 - 减)
/// Return:
///  0 - success
///  <0 -failure
ClassMethod HandleTransItmDirtyQty(initi As %String, sign As %String) As %String
{
  n (initi,sign)
  s obj=##class(User.DHCInIsTrfItm).%OpenId(initi,0)
  d obj.%Reload()
  ;b ;11
  s inclb=obj.INITIINCLBDR.%Id()
  s qty=obj.INITIQty
  s uom=obj.INITICTUOMDR.%Id()
  ;
  ;zdm,2012-10-22,占用库存处理改为调用公共方法
  s buom=$p(^INCI(+inclb,1),"^",10)
  s fac=##class(web.DHCST.Common.UtilCommon).UOMFac(uom,buom)
  s qty=qty*fac    ;基本单位对应的数量
  i sign="0" s qty=-qty  //回退
  s err=##class(web.DHCST.Common.StockHandle).UpdateDirtyQty(inclb,qty)
  ;s err=..HandleInclbDirtyQty(inclb,qty,uom)
  q err
}

/// 根据库存转移单明细得出入方的批次
/// Author:zhwh
/// Date:2012-07-16
/// Argu:
///  initi  - 库存转移单明细rowid
/// Return:
///  入方的批次rowid
///  
ClassMethod GetToLocINCLB(initi As %String) As %String
{
 n (initi)
 s init=+initi
 s ch=$P(initi,"||",2)
 s toLocDR= $p(^DHCINIT(init),"^",6)
 s ProvLocInclb=$P(^DHCINIT(init,"ITI",ch),"^",3)
 q:ProvLocInclb="" -1
 s inci="",incilsub="",inclbsub="",incib=""
 s ibsub="",batno="",expdate="",inclb=""
 s inci=$p(ProvLocInclb,"||",1)  q:inci="" -1
 s incilsub=$p(ProvLocInclb,"||",2) q:incilsub="" -1
 s inclbsub=$p(ProvLocInclb,"||",3) q:inclbsub="" -1
 q:'$d(^INCI(inci,"IL",incilsub,"LB",inclbsub)) -1
 s incib=$p(^INCI(inci,"IL",incilsub,"LB",inclbsub),"^",1) q:incib="" -1
 s ibsub=$p(incib,"||",2) q:ibsub="" -1
 q:($d(^INCI(inci,"IB",ibsub))=0)!($d(^INCI(inci,"IB",ibsub))=10) -1
 ;
 l +^DBLock($zn,inci_"^"_toLocDR):10 e  q ""
 s incil="",inclb=""
 s ilch=$O(^INCI("IL_LOC",toLocDR,inci,""))
 i ilch="" d
 .&sql(insert into inc_itmloc(incil_Inci_parref,incil_ctloc_dr)
   values (:inci,:toLocDR) )
 .i SQLCODE=0 s incil=%ROWID  
 .s ilch=$P(incil,"||",2)
 e  d
 .s incil=inci_"||"_ilch
 s lb=$O(^INCI("LB_IB",incib,inci,ilch,"")  )
 i lb="" d
 .&sql(insert into INC_ItmLcBt (inclb_incil_parref,inclb_incib_dr)
   values(:incil,:incib) )
 .i SQLCODE=0 s inclb=%ROWID
 e  d
 .s inclb=inci_"||"_ilch_"||"_lb 
 
 l -^DBLock($zn,inci_"^"_toLocDR)
 Q inclb
}

/// 取库存转移单据主表数据串(json)
/// Author:zhwh
/// Date:2012-07-16
/// Argu:
///   Start
///   Limit
///   Sort
///   Dir
///   sPar - 参数串
/// Return:
///  Json数据串
///  w ##class(web.DHCST.DHCINIsTrf).jsDHCINIsTrfM("0","30","","","2021-06-19^2021-07-19^165^^Y^21^^")
ClassMethod jsDHCINIsTrfM(Start As %String, Limit As %String, Sort As %String, Dir As %String, sPar As %String) As %String
{
 s ^YSJTMP("jsDHCINIsTrfM")=$LB(Start , Limit , Sort , Dir , sPar)
 s StartDate=$p(sPar,"^",1)
 s EndDate=$p(sPar,"^",2)
 s FrLoc=$p(sPar,"^",3)
 s ToLoc=$p(sPar,"^",4)
 s Comp=$p(sPar,"^",5)
 s Status=$p(sPar,"^",6)
 s TrNo=$p(sPar,"^",7)
 s ReqNo=$p(sPar,"^",8)
 s StkGrpId=$p(sPar,"^",9)
 s Inci=$p(sPar,"^",10)     //zdm,2012-10-18,库存项id,为查询占用数量
 s OperateOutType=$p(sPar,"^",11)  //出库方式  
 s MZJYFlag = $p(sPar,"^",12)
 s qPar=Sort_"^"_Dir
 s result=##class(%Library.ResultSet).%New("web.DHCST.DHCINIsTrf:DHCINIsTrfM")
 s sc=result.Execute(qPar,StartDate,EndDate,FrLoc,ToLoc,Comp,Status,TrNo,ReqNo,StkGrpId,Inci,OperateOutType,MZJYFlag)    
 i $$$ISERR(sc) q ""

 s colNum=result.GetColumnCount()
 s colNameStr=""
 f i=1:1:colNum d
 .i colNameStr="" s colNameStr=result.GetColumnName(i)
 .e  s colNameStr=colNameStr_"^"_result.GetColumnName(i)

 s count = 0
 s resultString = ""
 s end = Start+Limit
 s json = ##class(Code.JsonObj).%New()
 While(result.Next())
 { 
  s ret=""
  f i=1:1:colNum d
  .i ret="" s ret=result.%GetData(i)
  .e   s ret=ret_"^"_result.%GetData(i)
  
  s tmp=ret
  s count = count+1

  CONTINUE:count<(Start+1)
  CONTINUE:count>end            
    
  d json.InsertRowData(tmp)
 }
 d result.Close()
 s resultString = json.getJsonData(colNameStr,count)
 k json
 Q resultString
}

/// 检索库存转移主表信息
/// Author:zhwh
/// Date:2012-07-16
/// Argu:
///   StartDate - 起始日期
///   EndDate - 截止日期
///   FrLoc - 供应科室RowId
///   ToLoc - 请求科室RowId
///   Comp - 完成标志
///   Status - 状态
///   SCG - 类组RowId
///   d ##class(%ResultSet).RunQuery("web.DHCST.DHCINIsTrf","DHCINIsTrfM","^","6/9/2018","17/9/2018","320","","","","","","3","","")
Query DHCINIsTrfM(qPar As %String, StartDate As %String, EndDate As %String, FrLoc As %String, ToLoc As %String, Comp As %String = "", Status As %String = "", TrNo As %String = "", ReqNo As %String, SCG As %String = "", Inci As %String = "", OperateOutType As %String = "", MZJYFlag = "") As %Query(ROWSPEC = "init:%String,initNo:%String,frLoc:%String,frLocDesc:%String,toLoc:%String,toLocDesc:%String,dd:%String,tt:%String,userName:%String,comp:%String,status:%String,req:%String,reqNo:%String,RpAmt:%String,SpAmt:%String,MarginAmt:%String,Remark:%String,StatusCode:%String,scg:%String,scgDesc:%String,inAckDate:%String,inAckTime:%String,inAckUser:%String,OutMZJYAudit1,OutMZJYAudit2,InMZJYAudit1,InMZJYAudit2")
{
}

ClassMethod DHCINIsTrfMExecute(ByRef qHandle As %Binary, qPar As %String, StartDate As %String, EndDate As %String, FrLoc As %String, ToLoc As %String, Comp As %String = "", Status As %String = "", TrNo As %String = "", ReqNo As %String, SCG As %String = "", Inci As %String = "", OperateOutType As %String = "", MZJYFlag = "") As %Status
{
 n (qHandle,qPar,StartDate,EndDate,FrLoc,ToLoc,Comp,Status,TrNo,ReqNo, SCG, Inci, OperateOutType,MZJYFlag)
 s ^tmpdhy("DHCINIsTrfMExecute")=qPar_","_StartDate_","_EndDate_","_FrLoc_","_ToLoc_","_Comp_","_Status_","_TrNo_","_ReqNo_","_SCG_","_Inci_","_OperateOutType
 s repid=$I(^CacheTemp)
 s ind=1
 s qHandle=$lb(0,repid,0)

 s Sort=$p(qPar,"^",1)
 s Dir=$p(qPar,"^",2)
  
 s Comp=$G(Comp)
 s Status=$g(Status)    
 
 q:StartDate="" $$$OK
 q:EndDate="" $$$OK
 i StartDate'="" s StartDate=##class(web.DHCSTInterfaceFromElse).DateHtmlToLogical(StartDate)
 i EndDate'="" s EndDate=##class(web.DHCSTInterfaceFromElse).DateHtmlToLogical(EndDate)

 
 s orderFieldName=""
 s Sort=$$ALPHAUP^SSUTIL4(Sort)
 s:Sort="FRLOC" orderFieldName="frLoc"
 s:Sort="TOLOC" orderFieldName="toLoc"
 s:Sort="DATE" orderFieldName="dd"
 s:Sort="COMP" orderFieldName="comp"
 s:Sort="NO" orderFieldName="initNo"
 s:Sort="STATUS" orderFieldName="status"
 s:Sort="SCG" orderFieldName="scg"
 s Dir=$$ALPHAUP^SSUTIL4(Dir)
 s:(Dir="")&(Dir'="ASC")&(Dir'="DESC") Dir="DESC"
 
 s sql="select %ID init,"
 s sql=sql_"init_no initNo,"
 s sql=sql_"init_frloc_dr frLoc,"
 s sql=sql_"init_frloc_dr->ctloc_desc frLocDesc,"
 s sql=sql_"init_toloc_dr toLoc,"
 s sql=sql_"init_toloc_dr->ctloc_desc toLocDesc,"
 s sql=sql_"init_date dd,"
 s sql=sql_"init_time tt,"
 s sql=sql_"init_ssusr_dr->ssusr_name userName,"
 s sql=sql_"init_usercompleted comp,"
 s sql=sql_"init_state status,"
 s sql=sql_"init_inrq_dr req,"
 s sql=sql_"init_inrq_dr->inrq_no reqNo,"
 s sql=sql_"INIT_StkType StkType,"
 s sql=sql_"INIT_Remarks Remark,"
 s sql=sql_"INIT_SCG_DR scg,"
 s sql=sql_"INIT_SCG_DR->SCG_Desc scgDesc,"
 s sql=sql_"INIT_InAckDate inAckDate,"
 s sql=sql_"INIT_InAckTime inAckTime,"
 s sql=sql_"INIT_InAckUser_DR->SSUSR_Name inAckUser"
 s sql=sql_" from dhc_inistrf"
 s sql=sql_" where init_date between "_StartDate_" and "_EndDate
 i OperateOutType'="" d
 .s sql=sql_"and INIT_OperateType="_OperateOutType
 i orderFieldName'="" d
 .s sql=sql_" Order By "_orderFieldName_" "_Dir
 
 s xrs=##class(%Library.ResultSet).%New()
 d xrs.Prepare(sql)
 s sc=xrs.Execute()
 i $$$ISERR(sc) q $$$OK
 
 while (xrs.Next())
 {
  s frLoc=xrs.Data("frLoc") //供应科室RowId，
  i FrLoc'="" continue:frLoc'=FrLoc
  s toLoc=xrs.Data("toLoc") //请求科室RowId，
  i ToLoc'="" continue:toLoc'=ToLoc
  s comp=xrs.Data("comp")  //完成标志，
  i Comp'="" continue:comp'=Comp
  s status=xrs.Data("status") //状态，
  i Status=32 continue:status'=21   //部分接收
  e  i Status'="" continue:'$f(Status,status)
  s Type=xrs.Data("StkType")  //StkType
  s:Type="" Type=..sssCode()
  continue:Type'=..sssCode()
  s scg=xrs.Data("scg")  //类组rowid
  i SCG'="" continue:scg'=SCG
  
  s init=xrs.Data("init")  //Rowid
  s chl=""
  s:Inci'="" chl=$o(^DHCINIT(0,"OutsINCI",Inci,init,0))
  continue:(Inci'="")&(chl="")
  s initNo=xrs.Data("initNo")  //库存转移单号
  i TrNo'="" continue:initNo'[TrNo
  s statusRet=..JudPart(status,init)
  continue:(Status=32)&(statusRet'=Status)
  i (status=21)&&(statusRet=32) s status=32
  s frLocDesc=xrs.Data("frLocDesc")  //供应科室名称，
  s toLocDesc=xrs.Data("toLocDesc") //请求科室名称，
  s dd=xrs.Data("dd") //制单日期，
  i dd'="" s dd=##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(dd,"ST")
  
  s tt=xrs.Data("tt") //制单时间，
  i tt'="" s tt=##class(web.DHCSTInterfaceFromElse).TimeLogicalToHtml(tt,"ST")
  
  s userName=xrs.Data("userName")  //制单人，
  
  s req=xrs.Data("req") //库存转移请求单RowId，
  s reqNo=xrs.Data("reqNo") //库存转移请求单号
  i ReqNo'="" continue:reqNo'=ReqNo
  s Remark=xrs.Data("Remark") 
  s Remark=$LTS(Remark)
  s StatusCode=$s(status=10:"未完成",status=11:"完成",status=20:"出库审核不通过",status=21:"出库审核",status=30:"拒绝接收",status=31:"已接收",status=32:"部分接收",status=40:"重转作废")
  &sql(select sum(DHCITI_RPAmount),sum(DHCITI_SPAmount) into :RpAmt,:SpAmt from DHC_InIsTrfItm
   where INITI_INIT_ParRef=:init)
  s MarginAmt=SpAmt-RpAmt
  s inAckDate=xrs.Data("inAckDate")	//入库确认日期
  s:inAckDate'="" inAckDate=##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(inAckDate,"ST")
  s inAckTime=xrs.Data("inAckTime")	//入库确认时间
  s:inAckTime'="" inAckTime=##class(web.DHCSTInterfaceFromElse).TimeLogicalToHtml(inAckTime,"ST")
  s inAckUser=xrs.Data("inAckUser")	//入库确认人desc
  continue:(MZJYFlag = "Y")&&(..CheckMZJYExsit(init) '= "Y")
  s OutMZJYAudit1 = ##Class(BS.PHA.IN.Status).GetUser("User.DHCInIsTrf" ,init, "OutMZJY1")
  s OutMZJYAudit2 = ##Class(BS.PHA.IN.Status).GetUser("User.DHCInIsTrf" ,init, "OutMZJY2")
  s InMZJYAudit1  = ##Class(BS.PHA.IN.Status).GetUser("User.DHCInIsTrf" ,init, "InMZJY1")
  s InMZJYAudit2  = ##Class(BS.PHA.IN.Status).GetUser("User.DHCInIsTrf" ,init, "InMZJY2")
  
  d OutPutRow1
 }
 q $$$OK
 
OutPutRow1
 s Data=$lb(init,initNo,frLoc,frLocDesc,toLoc,toLocDesc,dd,tt,userName,comp,status,req,reqNo,RpAmt,SpAmt,MarginAmt,Remark,StatusCode,scg,scgDesc,inAckDate,inAckTime,inAckUser,OutMZJYAudit1,OutMZJYAudit2,InMZJYAudit1,InMZJYAudit2)   
 s ^CacheTemp(repid,ind)=Data
 s ind=ind+1
 q
}

ClassMethod DHCINIsTrfMClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = DHCINIsTrfMExecute ]
{
 Set repid=$LIST(qHandle,2)
 Kill ^CacheTemp(repid)
 Quit $$$OK
}

ClassMethod DHCINIsTrfMFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = DHCINIsTrfMExecute ]
{
 Set AtEnd=$LIST(qHandle,1)
 Set repid=$LIST(qHandle,2)
 Set ind=$LIST(qHandle,3)
 Set ind=$o(^CacheTemp(repid,ind))
 If ind="" {                // if there are no more rows, finish fetching
    Set AtEnd=1
    Set Row=""
 }
 Else {         
        Set Row=^CacheTemp(repid,ind)
 }
 s qHandle=$lb(AtEnd,repid,ind)
 Quit $$$OK
}

/// 取请求单主表数据串(json)
/// Author:zhangdongmei
/// Date:2012-07-24
/// Argu:
///   Start
///   Limit
///   Sort
///   Dir
///   sPar - 参数串
/// Return:
///  Json数据串
///  w ##class(web.DHCST.DHCINIsTrf).jsINReqForTransfer("0","30","","","2020-08-02^2020-09-01^106^165^保存,完成,部分转移,全部转移,部分作废,全部作废^1")
ClassMethod jsINReqForTransfer(Start As %String, Limit As %String, Sort As %String, Dir As %String, sPar As %String) As %String
{
 //s ^YSJTMP("jsINReqForTransfer")=$LB(Start , Limit , Sort , Dir , sPar)
 s StartDate=$p(sPar,"^",1)
 s EndDate=$p(sPar,"^",2)
 s FrLoc=$p(sPar,"^",3)
 s ToLoc=$p(sPar,"^",4)
 s PartlyTransfer="" //$p(sPar,"^",5) //条件统一整合到下方 ReqStatus 中
 s ReqStatus=$p(sPar,"^",5)
 s Transfered=$p(sPar,"^",6)

 ;
 s qPar=Sort_"^"_Dir
 s result=##class(%Library.ResultSet).%New("web.DHCST.DHCINIsTrf:INReqForTransfer")
 s sc=result.Execute(qPar,StartDate,EndDate,FrLoc,ToLoc,PartlyTransfer,Transfered,ReqStatus)  
 i $$$ISERR(sc) q ""

 s colNum=result.GetColumnCount()
 s colNameStr=""
 f i=1:1:colNum d
 .i colNameStr="" s colNameStr=result.GetColumnName(i)
 .e  s colNameStr=colNameStr_"^"_result.GetColumnName(i)

 s count = 0
 s resultString = ""
 s end = Start+Limit
 s json = ##class(Code.JsonObj).%New()
 While(result.Next())
 { 
  s ret=""
  f i=1:1:colNum d
  .i ret="" s ret=result.%GetData(i)
  .e   s ret=ret_"^"_result.%GetData(i)
  
  s tmp=ret
  s count = count+1

  CONTINUE:count<(Start+1)
  CONTINUE:count>end            
    
  d json.InsertRowData(tmp)
 }
 d result.Close()
 s resultString = json.getJsonData(colNameStr,count)
 k json
 Q resultString
}

/// 检索需要出库的请求单
/// Author:zhwh
/// Date:2012-07-18
/// Argu:
///   StartDate - 起始日期
///   EndDate - 截止日期
///   FrLoc - 供方科室rowid
///   ToLoc - 接收科室rowid
///   PartlyTransfer - 包含部分转移(1,0)
///   
Query INReqForTransfer(qPar As %String, StartDate As %String, EndDate As %String, FrLoc As %String, ToLoc As %String, PartlyTransfer As %String, Transfered As %String, ReqStatus As %String) As %Query(ROWSPEC = "req:%String,toLoc:%String,toLocDesc:%String,frLoc:%String,frLocDesc:%String,reqUser:%String,userName:%String,date:%String,time:%String,status:%String,comp:%String,transferStatus:%String,reqNo:%String,StkTypeDesc:%String")
{
}

ClassMethod INReqForTransferExecute(ByRef qHandle As %Binary, qPar As %String, StartDate As %String, EndDate As %String, FrLoc As %String, ToLoc As %String, PartlyTransfer As %String, Transfered As %String, ReqStatus As %String) As %Status
{
 s repid=$I(^CacheTemp)
 s ind=1
 s qHandle=$lb(0,repid,0)
    
 q:StartDate="" $$$OK
 q:EndDate="" $$$OK
 q:FrLoc="" $$$OK
 i ReqStatus="" s ReqStatus="完成,部分转移,部分拒绝"  //如果请求单状态为空，则默认

 i StartDate'="" s StartDate=##class(web.DHCSTInterfaceFromElse).DateHtmlToLogical(StartDate)
 i EndDate'="" s EndDate=##class(web.DHCSTInterfaceFromElse).DateHtmlToLogical(EndDate)

 
 s Sort=$p(qPar,"^",1)
 s Dir=$p(qPar,"^",2)
 
  s orderFieldName=""
  s Sort=$$ALPHAUP^SSUTIL4(Sort)
 s:Sort="DATE" orderFieldName="d"
 s:Sort="FRLOC" orderFieldName="frLocDesc"
 s:Sort="TOLOC" orderFieldName="toLocDesc"
 s:Sort="COMP" orderFieldName="comp"
 s:Sort="USER" orderFieldName="userName"
 
 s Dir=$$ALPHAUP^SSUTIL4(Dir)
 s:(Dir="")&(Dir'="ASC")&(Dir'="DESC") Dir="DESC"
  
 s sql="select %ID req,"
 s sql=sql_"inrq_recloc_dr toLoc,"
 s sql=sql_"inrq_recloc_dr->ctloc_Desc toLocDesc,"
 s sql=sql_"inrq_reqloc_dr frLoc,"
 s sql=sql_"inrq_reqloc_dr->ctloc_desc frLocDesc,"
 s sql=sql_"inrq_ssusr_dr reqUser,"
 s sql=sql_"inrq_ssusr_dr->ssusr_name userName,"
 s sql=sql_"inrq_date d,"
 s sql=sql_"inrq_time t,"
 s sql=sql_"inrq_status status,"
 s sql=sql_"inrq_usercompleted comp,"
 s sql=sql_"INRQ_No reqNo "
 s sql=sql_" from in_request"
 s sql=sql_" where inrq_date between "_StartDate_" and "_EndDate
 
 i orderFieldName'="" d
 . s sql=sql_" order by "_orderFieldName_" "_Dir
 ;b ;1
 s xrs=##class(%Library.ResultSet).%New()
 d xrs.Prepare(sql)
 s sc=xrs.Execute()
 i $$$ISERR(sc) q $$$OK
 
 while (xrs.Next())
 {
  s comp=xrs.Data("comp")
  ;b ;11
  continue:comp'="Y"  //未"完成"者滤除
  s req=xrs.Data("req")  
  s frLoc=xrs.Data("frLoc")
  continue:frLoc'=FrLoc
  s frLocDesc=xrs.Data("frLocDesc")
  s toLoc=xrs.Data("toLoc")
  i ToLoc'="" continue:toLoc'=ToLoc
  s toLocDesc=xrs.Data("toLocDesc")
  s reqUser=xrs.Data("reqUser")  
  s userName=xrs.Data("userName")
  s date=xrs.Data("d")
  i date'="" s date=##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(date,"ST")
  s time=xrs.Data("t")
  i time'="" s time=##class(web.DHCSTInterfaceFromElse).TimeLogicalToHtml(time,"ST")
  s reqNo=xrs.Data("reqNo")
  s rettype=##class(web.DHCSTTRREQ).GetReqType(req)
  //continue:(rettype="1")||(rettype="2") //1 基数补货 2 精神毒麻补货
  ;s status=xrs.Data("status")
  &sql(select INRQ_Type into status from DHC_INRequest where INRQ_INRQ_DR=:req)
  ;b ;2
  /*
  s transStatus=..TransferStatus(req)
  s itm=0
  s cnt=0
  f  s itm=$o(^INRQ(req,"RQI",itm)) q:(itm="")||(cnt'=0)  d
  .s refuse=$p(^INRQ(req,"RQI",itm),"^",6)
  .i refuse'="Y" s cnt=cnt+1
  .
  i cnt=0 s transStatus="2" //wyx add 2014-07-01如果为全部作废状态为已转移
  ;b ;3
  i 'Transfered continue:transStatus="2"  //已经转移
  i 'PartlyTransfer continue:transStatus="1"  //不包括部分转移
  */
  
  s transStatus=##Class(web.DHCST.INRequest).GetInReqStatus(req)
  //continue:(ReqStatus="完成")&&(transStatus'="完成")   //仅
  s ExistFlag=##Class(web.DHCST.INRequest).CheckReqStatus(req, ReqStatus)
  continue:ExistFlag="N"
  
  //add wyx 过滤作废全部明细的请求单 2014-06-24
  s itm=0
  s stkgrpdesc=""
  i $d(^DHCINRQ(0,"INRQ",req)) d
  .s dhcreq=$o(^DHCINRQ(0,"INRQ",req,""),-1)
  .s stkgrp=$p($g(^DHCINRQ(dhcreq)),"^",10)
  .s stkgrpdesc=$p($g(^DHCSCG(+stkgrp)),"^",2)
  d OutPutRow2   
 }
 Quit $$$OK
 
OutPutRow2
 s Data=$lb(req,toLoc,toLocDesc,frLoc,frLocDesc,reqUser,userName,date,time,status,comp,transStatus,reqNo,stkgrpdesc)   
 s ^CacheTemp(repid,ind)=Data
 s ind=ind+1
 q
}

ClassMethod INReqForTransferClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = INReqForTransferExecute ]
{
 Set repid=$LIST(qHandle,2)
 Kill ^CacheTemp(repid)
 Quit $$$OK
}

ClassMethod INReqForTransferFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = INReqForTransferExecute ]
{
 Set AtEnd=$LIST(qHandle,1)
 Set repid=$LIST(qHandle,2)
 Set ind=$LIST(qHandle,3)
 Set ind=$o(^CacheTemp(repid,ind))
 If ind="" {                // if there are no more rows, finish fetching
    Set AtEnd=1
    Set Row=""
 }
 Else {         
        Set Row=^CacheTemp(repid,ind)
 }
 s qHandle=$lb(AtEnd,repid,ind)
 Quit $$$OK
}

/// 取库存转移请求单的转移状态
/// Author:zhwh
/// Date:2012-07-18
/// Argu:
///  req - 请求单主表RowId
/// Return:
///      0 - 未完成
///      1 - 部分完成
///  2 - 完成
ClassMethod TransferStatus(req As %String) As %String
{
 n (req)
 s init=$O(^DHCINIT(0,"REQ",req,""))
 i init="" q 0  //未完成
 
 s InrqiTrans=0
 s ch=0
 f  s ch=$o(^INRQ(req,"RQI",ch)) q:(ch="")!(InrqiTrans=1)  d
 .s INRQI=req_"||"_ch
 .s init=$O(^DHCINIT(0,"RQI",INRQI,0))
 .q:(init'="")&&($P(^DHCINIT(init),"^",14)=40)  ///过滤作废的转移单
 .s:init'="" InrqiTrans=1 
 i InrqiTrans=0 q 0		;若每个请求明细均没有^DHCINIT索引,返回0(未转移)
 
 s ret=2  ;默认转移完成
 s ch=0
 f  s ch=$o(^INRQ(req,"RQI",ch)) q:(ch="")!(ret=1)  d
 .s INRQI=req_"||"_ch
 .s inci=$P(^INRQ(req,"RQI",ch),"^",4)
 .s reqQty=$P(^INRQ(req,"RQI",ch),"^",3)
 .s uom=$P(^INRQ(req,"RQI",ch),"^",5)
 .s refuse=$p(^INRQ(req,"RQI",ch),"^",6)
 .q:refuse="Y" 
 .s fac=##class(web.DHCST.Common.UtilCommon).UOMFac(uom,$p(^INCI(inci,1),"^",10))
 .s reqQty=reqQty*fac
 .s transQty=..TransQty(INRQI)
 .i transQty<reqQty s ret=1  q  //部分完成
 q ret
}

/// 查找请求单明细的转移数
/// Author:zhwh
/// Date:2012-07-18
/// Argu:
///  INRQI - 请求单明细rowid
/// Return:
///  转移数
ClassMethod TransQty(INRQI As %String) As %String
{
 
 n (INRQI)
 s sumQty=0
 s init=""
 f  s init=$O(^DHCINIT(0,"RQI",INRQI,init)) q:init=""  d
 .q:($P(^DHCINIT(init),"^",14)=40)||($P(^DHCINIT(init),"^",14)=30)   ///过滤作废和拒绝的转移单的转移单
 .s ch=0
 .f  s ch=$O(^DHCINIT(0,"RQI",INRQI,init,ch)) q:ch=""  d
 ..s inclb=$P(^DHCINIT(init,"ITI",ch),"^",3)
 ..
 ..s qty=$P(^DHCINIT(init,"ITI",ch),"^",1)
 ..s uom=$P(^DHCINIT(init,"ITI",ch),"^",7)
 ..s buom=$P(^INCI(+inclb,1),"^",10)
 ..s fac=##class(web.DHCST.Common.UtilCommon).UOMFac(uom,buom)
 ..s qty=qty*fac
 ..s sumQty=sumQty+qty
 q sumQty
}

/// Descript:取库存转移相关界面参数配置属性
/// Creater:    ZhangDongmei
/// CreateDate: 2012-10-17
/// Table:
/// Input:安全组id,科室id,用户id
/// Output:     
/// Return：出库审核默认天数^默认查找起始日期^默认查找截止日期^保存后自动打印出库单^出库审核后自动打印出库单
/// ^入库审核后自动打印出库单^启动制单时自动调出请求单^库存转移是否必须依据请求单^打印类型^批量作废请求明细
/// ^过期药品限制出库
/// w ##class(web.DHCST.DHCINIsTrf).GetParamProp("142","102","590")
ClassMethod GetParamProp(GroupId As %String, LocId As %String, UserId As %String) As %Library.String
{
    n (GroupId,LocId,UserId)
    ;s ^zdm("GetParamProp")=GroupId_"^"_LocId_"^"_UserId
    s:LocId'="" HospId=$p(^CTLOC(LocId),"^",22)
    s Param=GroupId_"^"_LocId_"^"_UserId_"^"_$g(HospId)
    s AppName=..%GetParameter("AppName")
    s DefaDaysAudit=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"DefaDaysAudit",Param)
    s DefaStartDate=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"DefaStartDate",Param)
    s DefaEndDate=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"DefaEndDate",Param)
    s AutoPrintAfterSave=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"AutoPrintAfterSave",Param)
    s AutoPrintAfterAudit=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"AutoPrintAfterAckOut",Param)
    s AutoPrintAfterAckIn=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"AutoPrintAfterAckIn",Param)
    s AutoLoadRequest=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"AutoLoadRequest",Param)
    s RequestNeeded=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"RequestNeeded",Param)
    s PrintType=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"PrintType",Param)
    s CancelReqItm=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"CancelReqItm",Param)
    s ExpLimitFlag=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"ExpLimitFlag",Param)
    s StockAllowDecimal=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"StockAllowDecimal",Param)
    s Data1=DefaDaysAudit_"^"_DefaStartDate_"^"_DefaEndDate_"^"_AutoPrintAfterSave_"^"_AutoPrintAfterAudit
    s Data2=AutoPrintAfterAckIn_"^"_AutoLoadRequest_"^"_RequestNeeded_"^"_PrintType_"^"_CancelReqItm
    s Data3=ExpLimitFlag_"^"_StockAllowDecimal  //12
    q Data1_"^"_Data2_"^"_Data3
}

/// Descript:验证库存转移单数据是否正确(出库单完成、审核调用)
/// Creater:ZhangDongmei
/// CreateDate: 2012-10-19
/// Table:DHC_InIsTrf,DHC_InIsTrfItm
/// Input:转移主表id
/// Output:     
/// Return：数据验证通过:0
/// 数据验证不通过:DHC_StkSysErrorRecord rowid
ClassMethod CheckDataValid(Init) As %Library.String
{
    n (Init)
    q:Init="" 0
    s AppCode=..%GetParameter("AppName")
    s KeyValue=$p(^DHCINIT(Init),"^",1)   ;转移单号
    s ret=0
    s FrLoc=$p(^DHCINIT(Init),"^",5)
    i FrLoc=""  d
    .s ErrInfo=..Trans("出库科室为空")
    .s ret=$$ErrorRecord^DHCSTERROR(AppCode,KeyValue,ErrInfo)
    .
    q:ret'=0 ret    ;出库科室验证不通过
    s ToLoc=$p(^DHCINIT(Init),"^",6)
    i ToLoc=""  d
    .s ErrInfo=..Trans("接收科室为空")
    .s ret=$$ErrorRecord^DHCSTERROR(AppCode,KeyValue,ErrInfo)
    .
    q:ret'=0 ret    ;接收科室验证不通过
    ;
    s Chl=0
    f  s Chl=$o(^DHCINIT(Init,"ITI",Chl)) q:(Chl="")!(ret'=0)  d
    .s Initi=Init_"||"_Chl
    .s ret=##class(web.DHCST.DHCINIsTrfItm).CheckTransferDetail(Initi,"")
    .q:ret'=0
    .
    q:ret'=0 ret    ;明细验证不通过
    ;
    q 0    ;验证通过
}

ClassMethod SetRemarks(init As %String, remark As %String)
{
    
  n (init,remarks)
  s init=+init
  i init'>0 q -1
  
  i ##class(web.DHCST.Common.AppCommon).Lock(..%GetParameter("AppName")_init)<0 q -99
  s obj=##class(User.DHCInIsTrf).%OpenId(init) 
  d obj.%Reload()
  d obj.INITRemarks.Clear()
  s memoDelim=##class(web.DHCST.Common.UtilCommon).MemoDelim()
  f i=1:1:$l(remarks,memoDelim) d
  .s rem1=$p(remarks,memoDelim,i)
  .d obj.INITRemarks.Insert(rem1)
  .
  s ret= obj.%Save()
  d ##class(web.DHCST.Common.AppCommon).UnLock(..%GetParameter("AppName")_init)
  i $$$ISERR(ret) q -2
  ;
  q 0
}

/// 设置库存转移单部分记录“入库审核通过”状态
/// Author:ct
/// Date:2013-11-26
/// Argu:
///   init - 库存转移主表 RowId
/// Return:
/// w ##class(web.DHCST.DHCINIsTrf).TransInAuditYesPart(13,13609,"")
ClassMethod TransInAuditYesPart(init As %String, user As %String, strrowid As %String) As %String
{
  n (init,user,strrowid)
 //加锁
 q:..lock(init)<0 -99  
  
 //检查状态
 s status=""
 &sql(select init_state into :status from dhc_inistrf where %ID=:init)
 i status'="21" d ..uLock(init) q -100
 ts
 i strrowid'="" s newStatus="21" 
 e  s newStatus="31"
 s d=+$h,t=$p($h,",",2)
 &sql(UPDATE dhc_inistrf set init_state=:newStatus,init_inackdate=:d,init_inacktime=:t,init_inackuser_dr=:user 
   where %ID=:init)
 i SQLCODE'=0 tro  d ..uLock(init) q -1 
 //处理库存，台账记录
 s toloc=$p(^DHCINIT(init),"^",6)
 s CustStr=##Class(web.DHCSTCOMMO).GetLocCust(toloc)
 s HospID=$p(CustStr,"^",5)
 s CustID=$p(CustStr,"^",1)
 s status="31"
 s err=0,ret=0
 s initNo=$p(^DHCINIT(init),"^",1)
 s type="K"
 s ch=0
 f  s ch=$o(^DHCINIT(init,"ITI",ch)) q:(ch="")!(err'=0)  d
 .s initi=init_"||"_ch
 .s inistate=$p(^DHCINIT(init,"ITI",ch),"^",23)
 .q:inistate="31"
 .s result=..QuitNOTMATCH(initi,strrowid)
 .q:result'=0
 .s ret=..UpdInIsTrfItm(initi,status)
 .i ret'=0 d ..uLock(init)
 .i ret'=0 tro  s err=-2 q
 .s inclb=$p(^DHCINIT(init,"ITI",ch),"^",3)
 .
 .s toInclb=..GetToLocINCLB(initi)  //取入方科室的库存批次rowid
 .
 .s qty=$p(^DHCINIT(init,"ITI",ch),"^",1)
 .s trQty=qty
 .s uom=$p(^DHCINIT(init,"ITI",ch),"^",7)
 .s inci=+inclb
 .s buom=$P(^INCI(inci,1),"^",10)
 .s fac=##class(web.DHCST.Common.UtilCommon).UOMFac(uom,buom)
 .s qty=qty*fac
 .s rp=$p(^DHCINIT(init,"ITI",ch),"^",15)
 .s rpAmt=$p(^DHCINIT(init,"ITI",ch),"^",16)
 .s sp=$p(^DHCINIT(init,"ITI",ch),"^",17)
 .s spAmt=$p(^DHCINIT(init,"ITI",ch),"^",18)
 .// 跨院区价格补充
 .s UpdatePriceFlag = ..UpdatePriceForInitByHosp(initi,toInclb)
 .i (UpdatePriceFlag '= 0) s err = UpdatePriceFlag tro  q
 
 .s ret=##class(web.DHCST.Common.StockHandle).UpdateStock(toInclb,qty)
 .i ret<0 tro  s err=-3  q 
 .
 .s trData=type
 .s trData=trData_"^"_initNo
 .s trData=trData_"^"_toInclb
 .s trData=trData_"^"_+trQty
 .s trData=trData_"^"_uom
 .s trData=trData_"^"_+sp
 .s trData=trData_"^"_user
 .s trData=trData_"^"_initi
 .s trData=trData_"^"_+rp
 .s trData=trData_"^"_+rpAmt
 .s trData=trData_"^"_+spAmt
 .
 .s ret=##class(web.DHCST.Common.StockHandle).IntoTrans(trData)
 .i ret<0 tro   s err=-4  q 
 .//出库审核-调价生效-转移入库接收插入损益 zzd添加
 .s LocID=toloc
 .s sPrice=sp
 .s sTrRowID=ret
 .s DataStr=toInclb_"^"_inci_"^"_LocID_"^"_+sp_"^"_+trQty_"^"_+spAmt_"^"_user_"^"_initi_"^"_type_"^"_+rp_"^"_+rpAmt_"^"_HospID_"^"_uom_"^"_CustID
 .s ret=..InsertRetAsp(DataStr)
 .i ret<0 tro   s err=-5 q 
 b  ;tccc
 i err=0  tc
 d ..uLock(init)
 q err
}

ClassMethod QuitNOTMATCH(subrowid, strrowid)
{
 n (subrowid,strrowid)
 s rowidlen=$LENGTH(strrowid,"!") 
 s rett=0
 f rowidcnt=1:1:rowidlen d 
 .s tranitmrowid=$p(strrowid,"!",rowidcnt)
 .i subrowid=tranitmrowid  d
 ..s rett=""
 q rett
}

ClassMethod UpdInIsTrfItm(initi, status)
{
 n (initi,status)
 q:initi="" -1
 s initID=$p(initi,"||",1)
 s initSub=$p(initi,"||",2)
 q:(initID="")||(initSub="") -1
 q:'$D(^DHCINIT(initID,"ITI",initSub)) -1
 &sql(Update DHC_INIsTrfItm set DHCITI_State=:status
                          where INITI_RowID=:initi)
 q SQLCODE
}

/// description:根据子表全部记录判断是否部分接收
/// 21(出库),32(部分接收:目前没这状态于主表)
/// return:		32或空
ClassMethod JudPart(stat, rowid)
{
 n (stat, rowid)
 s retstatus=""
 q:stat="30" ""
 i (stat="32")||(stat="21") d
 .s trdetaildr=""
 .f  s trdetaildr=$o(^DHCINIT(rowid,"ITI",trdetaildr)) q:(trdetaildr="")||(retstatus'="")  d
 ..s substate=$p(^DHCINIT(rowid,"ITI",trdetaildr),"^",23)
 ..i substate="31" d
 ...s retstatus="32"
 q retstatus
}

/// 出库审核-调价生效-接收时增加接收方转入损益
/// 调价时间在出库时间之后,直接比较出库时价格与最新价格,一个损益即可,如果存在不应该是更新??
ClassMethod InsertAsp(inti As %String) As %String
{
	
	q:inti="" 0	
	q:$l(inti,"||")<2 0
	s main=+inti
	s ch=$p(inti,"||",2)
	s toloc=$p(^DHCINIT(main),"^",5)  //损益算供给部门
 	s CustStr=##Class(web.DHCSTCOMMO).GetLocCust(toloc)
 	s HospID=$p(CustStr,"^",5)
 	s CustID=$p(CustStr,"^",1)
 	s outackdate=$p(^DHCINIT(main),"^",9)
 	s outacktime=$p(^DHCINIT(main),"^",10)
 	s nowdate=+$h
 	s Inclb=$p(^DHCINIT(main,"ITI",ch),"^",3)
	s inci=+Inclb
 	s date=""
 	s date=$o(^INASP(0,"INCI",inci,date),-1) 
 	q:date<outackdate 0
 	s aspid=""
 	s aspid=$o(^INASP(0,"INCI",inci,date,aspid),-1) 
 	q:aspid="" 0
 	s aspd=$o(^DHCINASPD(0,"INASP",aspid,""),-1)
 	q:aspd="" 0
 	s asptime=$p(^DHCINASPD(aspd),"^",3)
 	q:(date=outackdate)&(asptime<outacktime) 0
	s ret=0
	s buom=$p(^INCI(inci,1),"^",10)
	s Uom=$p(^DHCINIT(main,"ITI",ch),"^",7)
 	s ConFac=##class(web.DHCST.Common.UtilCommon).UOMFac(+Uom,+buom)	
 	s rp=$p(^DHCINIT(main,"ITI",ch),"^",15)
 	s rp=rp/ConFac
 	s sp=$p(^DHCINIT(main,"ITI",ch),"^",17)
 	s sp=sp/ConFac
 	s qty=$p(^DHCINIT(main,"ITI",ch),"^",1)
	s CurSp=+##Class(web.DHCSTPRICE).GetCurSp(Inclb,buom,HospID)
 	s CurRp=+##Class(web.DHCSTPRICE).GetCurRp(Inclb,buom,HospID)
	s AspNo=$p(^INASP(aspid),"^",5)
 	s LocId=toloc
 	s DiffSp=CurSp-sp
 	s Rowid=aspid
 	s InciId=inci
 	s Qty=qty*ConFac
 	s SpAmt=(+Qty)*(DiffSp)
 	s CurDate=+$h
 	s CurTime=$p($h,",",2)
 	s AdjUserId=$p(^INASP(aspid),"^",3)
 	s DiffRp =CurRp-rp
 	s RpAmt=(+Qty)*(DiffRp)
	S SpAmt=+##class(web.DHCST.Common.AppCommon).FormatSpAmt(SpAmt,HospID)
    S RpAmt=+##class(web.DHCST.Common.AppCommon).FormatRpAmt(RpAmt,HospID)
	 &sql(insert into dhc_aspamount(aspa_no,aspa_ctloc_dr,aspa_adjprice,aspa_inasp_dr,
      aspa_inci_dr,aspa_stkqty,aspa_amount,aspa_date,aspa_time,aspa_ssusr_dr,ASPA_AdjRP,ASPA_RPAmt)
      values(:AspNo,:LocId,:DiffSp,:Rowid,:InciId,:Qty,:SpAmt,:CurDate,:CurTime,:AdjUserId,:DiffRp,:RpAmt))                     
	i SQLCODE'=0 d
    .s rett=$$ErrorRecord^DHCSTERROR(..%GetParameter("AppName"),AspNo_":"_Inclb_":拒绝注意入库："_inti,SQLCODE_":"_%msg)
    .s ret=SQLCODE
    q:ret'=0 ret
    
    s Aspa=$p(%ROWID,$c(1)) 
    s AspalbCh=1+$o(^ASPA(Aspa,"LB",""),-1) 
    s Inclb=Inclb
    s InclbQty=Qty
    s PrioRp=rp
    
    
	 &sql(insert into Dhc_AspAmountLB (aspalb_aspa_parref,aspalb_childsub,aspalb_inclb_dr,
        aspalb_qty,aspalb_adjdiff,aspalb_adjamt,ASPALB_AdjRP,ASPALB_RPAmt,ASPALB_PriorRP)
        values(:Aspa,:AspalbCh,:Inclb,:InclbQty,:DiffSp,:SpAmt,:DiffRp,:RpAmt,:PrioRp) )
    i SQLCODE'=0 d
    .s rett=$$ErrorRecord^DHCSTERROR(..%GetParameter("AppName"),Aspa_":"_Inclb_":拒绝注意入库：Dhc_AspAmountLB",SQLCODE_":"_%msg)
    .s ret=SQLCODE
    q:ret'=0 ret
    q ret
}

ClassMethod InsertRetAsp(DataStr As %String) As %String
{
 n (DataStr)
 s inclb=$p(DataStr,"^",1)
 s inci=$p(DataStr,"^",2)
 s locdr=$p(DataStr,"^",3)
 s retSp=$p(DataStr,"^",4)
 s qty=$p(DataStr,"^",5)
 s retSpAmt=$p(DataStr,"^",6)
 s userdr=$p(DataStr,"^",7)
 s rowid=$p(DataStr,"^",8)
 s rettype=$p(DataStr,"^",9)
 s retRp=$p(DataStr,"^",10)
 s retRpAmt=$p(DataStr,"^",11)
 s HospID=$p(DataStr,"^",12)
 s Uom=$p(DataStr,"^",13)
 s CustID=$p(DataStr,"^",14)
 s CurSp=+##Class(web.DHCSTPRICE).GetCurSp(inclb,Uom,HospID)
 s CurRp=+##Class(web.DHCSTPRICE).GetCurRp(inclb,Uom,HospID)
 s buom=$p(^INCI(inci,1),"^",10)
 q:(retSp=CurSp)&(retRp=CurRp) 0
 s adjSp=CurSp-retSp    ;损益价格
 s adjRp=CurRp-retRp
 s CurSpAmt=CurSp*qty
 s CurRpAmt=CurRp*qty
 s CatGrpStr=##Class(web.DHCSTCOMINC).GetIncStkCatGrp(+inclb)
 s StkTypeDesc=$P(CatGrpStr,"^",4)
 s Perv="^^^"_StkTypeDesc_"^"_CustID_"^DHC"
 s CurSpAmt=##Class(web.DHCSTCOMMPARA).GetNumbDec(CurSpAmt,Perv,"FmtSA",1)
 s CurRpAmt=##Class(web.DHCSTCOMMPARA).GetNumbDec(CurRpAmt,Perv,"FmtRA",1)
 s AdjSpAmt=CurSpAmt-retSpAmt
 s AdjRpAmt=CurRpAmt-retRpAmt
 s date=+$h               ;date is the current date
 s time=$p($h,",",2) ;time is the current time
 ;
 &sql(insert into  DHC_RetAspAmount(RETA_INCI_DR,RETA_CTLOC_DR,RETA_AdjPrice,RETA_Qty,
 RETA_Amount,RETA_SSUSR_DR,RETA_Date,RETA_Time,RETA_Pointer,RETA_Type,RETA_RpDiff,RETA_RpAmt,RETA_Uom_Dr) 
  values (:inci,:locdr,:adjSp,:qty,:AdjSpAmt,:userdr,:date,:time,:rowid,:rettype,:adjRp,:AdjRpAmt,:Uom))
 i SQLCODE'=0 d
 .s ret=$$SqlErrorRecord^DHCSTERROR("InsertRetAsp:DHC_RetAspAmount",rowid,SQLCODE_":"_$g(%msg))
 q:SQLCODE'=0 -2
 q 0
}

/// creator:yunhaibao
/// createdate:20150512
/// description:供给科室批次信息,不分页
/// w ##class(web.DHCST.DHCINIsTrf).GetDrugInvInfo("393||7||1","",243,"",0,15)
ClassMethod GetDrugInvInfo(InciDr, ProLocId, ReqLocId, QtyFlag, Start, Limit)
{
	n (InciDr,ProLocId,ReqLocId,QtyFlag,Start,Limit)
	s ^tmpdhy("GetDrugInvInfo")=InciDr_","_ProLocId_","_ReqLocId_","_QtyFlag_","_Start_","_Limit
	s QtyFlag=1
	q:InciDr="" ""
	s StkType="G"
	s ProLocId=$p(^INCI(+InciDr,"IL",$p(InciDr,"||",2)),"^",1)
	q:ProLocId="" ""
	i ProLocId'="" s HospId=$p($g(^CTLOC(ProLocId)),"^",22)
	s Params=""_"^"_ProLocId_"^"_""_"^"_$g(HospId)
    s AppName=..%GetParameter("AppName")
    s ExpLimitFlag=##class(web.DHCST.Common.AppCommon).GetAppPropValue(AppName,"ExpLimitFlag",Params)
    s InciDr=+InciDr
    s end = Start+Limit
    s count = 0
    s orderflag=-1
    s resultString = ""
    s json = ##class(Code.JsonObj).%New()
    s chl=""
    f  s chl=$o(^INCI("IL_LOC",ProLocId,InciDr,chl),orderflag)  q:chl=""  d
    .q:chl=0
    .s lb=""
    .f  s lb=$o(^INCI(InciDr,"IL",chl,"LB",lb),orderflag)  q:lb=""  d
    ..q:lb=0
    ..s RowId =InciDr_"||"_chl_"||"_lb
    ..s IncibRowId =$p(^INCI(InciDr,"IL",chl,"LB",lb),"^",1)
    ..s IncilRowId =InciDr_"||"_chl
    ..s BatNo=$p(^INCI(+IncibRowId,"IB",$p(IncibRowId,"||",2)),"^",1)
    ..s ExpDate=$p(^INCI(+IncibRowId,"IB",$p(IncibRowId,"||",2)),"^",2)
    ..q:(+ExpDate'=0)&&(ExpLimitFlag="Y")&&(+ExpDate<=+$h)
    ..s ExpDateH=+ExpDate
    ..s ExpDate=##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(ExpDate,"ST")
    ..s BatExp = BatNo_"~"_ExpDate
    ..s Manf = ##class(web.DHCST.Common.DrugStkCommon).GetManfInfoByInclb(RowId)
    ..s ManfDr=$P(Manf,"^",1)
    ..s ManfName=$P(Manf,"^",2)
    ..s BUomId=$p(^INCI(InciDr,1),"^",10)
    ..s:BUomId'="" BUomDesc=$p(^CT("UOM",BUomId),"^",2)
    ..s PurUomId=$p(^INCI(InciDr,3),"^",6)
    ..s:PurUomId'="" PurUomDesc=$p(^CT("UOM",PurUomId),"^",2)
    ..s ConFac=##class(web.DHCST.Common.UtilCommon).UOMFac(+PurUomId,+BUomId)
    ..s InclbQty = ##class(web.DHCST.Common.DrugStkCommon).CurQtyINCLBURid(RowId,PurUomId)
    ..q:(QtyFlag=1)&(InclbQty<=0)
    ..S InitQty = 0
    ..s Date = $P($H, ",", 1)
    ..S HospID=$P(^CTLOC(ProLocId),"^",22)
    ..s Sp=##class(web.DHCST.Common.PriceCommon).GetPriceElse(RowId,+$h,PurUomId,HospID,StkType,"")
    ..s BatSp=##class(web.DHCST.Common.PriceCommon).BatSpUom(RowId,PurUomId,HospID,StkType)
    ..S ReqQty = 0
    ..s Rp = ##class(web.DHCST.Common.PriceCommon).GetClbRp(RowId,PurUomId,HospID,StkType,+$h,"")
    ..s stkbinret=##class(web.DHCST.Common.DrugInfoCommon).GetInciBinStr(IncilRowId,",","","") //改为取新的科室货位表DHCIncItmLocBin（可多货位）add wyx 2013-11-21
    ..s stkchkflag=$p(stkbinret,":",1)
    ..s stkbinstr=$p(stkbinret,":",2)
    ..s StkBin=stkbinstr
    ..s DirtyQty=##class(web.DHCST.Common.DrugStkCommon).CurInclbResQty(RowId,PurUomId)
    ..s AvaQty = InclbQty - DirtyQty
    ..s SupplyStockQty = ##class(web.DHCST.Common.DrugStkCommon).LocDayQtyUom(InciDr,ProLocId,PurUomId,Date)
    ..S:ReqLocId'="" RequrstStockQty = ##class(web.DHCST.Common.DrugStkCommon).LocDayQtyUom(InciDr,ReqLocId,PurUomId,Date)
    ..s IngrId =  ##class(web.DHCST.Common.DrugStkCommon).GetClbDHCIngr(RowId,+$h)
    ..s IngrDate=""
    ..i IngrId'=""  d
    ...s IngrDate=$p(^DHCINGR(+IngrId),"^",4)
    ...s:IngrDate'="" IngrDate=##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(IngrDate,"ST")
    ..q:'$d(^DHCINCLB(0,"LB",RowId))
    ..s dhcinclb=$o(^DHCINCLB(0,"LB",RowId,""),-1)
    ..s inclbactive=$p($g(^DHCINCLB(dhcinclb)),"^",4)
    ..s InclbWarnFlag=0  //效期警示级别,目前仅控制批次库存颜色变化,yunhaibao20151201
    ..i (ExpDateH'=0)&&(ExpDateH<=+$h) s InclbWarnFlag=1
    ..i inclbactive'="Y" s InclbWarnFlag=2 
    ..s incidesc=$p(^INCI(+RowId,1),"^",2)
    ..s incicode=$p(^INCI(+RowId,1),"^",1)
    ..s spec=##class(web.DHCST.Common.DrugInfoCommon).GetSpec("",+RowId)
    ..s genename=##class(web.DHCST.Common.DrugInfoCommon).GetGene(+RowId)
    ..s genename=$p(genename,"^",2)
    ..s count = count+1
    ..s tmp1=RowId_"^"_+RowId_"^"_incicode_"^"_incidesc_"^"_BatExp
    ..s tmp2=ManfName_"^"_InclbQty_"^"_0_"^"_$g(PurUomDesc)_"^"_Sp
    ..s tmp3=""_"^"_0_"^"_BUomDesc_"^"_Rp_"^"_""
    ..s tmp4=SupplyStockQty_"^"_RequrstStockQty_"^"_""_"^"_spec_"^"_genename
    ..s tmp5=""_"^"_PurUomId_"^"_BUomId_"^"_ConFac_"^"_DirtyQty
    ..s tmp6=AvaQty_"^"_BatSp_"^"_InclbWarnFlag
    ..s tmp=tmp1_"^"_tmp2_"^"_tmp3_"^"_tmp4_"^"_tmp5_"^"_tmp6
    ..i (count>Start)&(count<=end) d
    ...d json.InsertRowData(tmp)
	s Title1="Inclb^IncRowId^IncCode^IncName^BatExp"
	s Title2= "Manf^InclbQty^InitQty^PurUomDesc^Sp"
	s Title3= "Transfer^ReqQty^BUomDesc^Rp^StkBin"
	s Title4="SupplyStockQty^RequrstStockQty^IngrDate^Sepc^GeneDesc"
	s Title5="FormDesc^PurUomId^BUomId^ConFac^DirtyQty"
	s Title6="AvaQty^BatSp^InclbWarnFlag"
    s Title=Title1_"^"_Title2_"^"_Title3_"^"_Title4_"^"_Title5_"^"_Title6
    if count>0 d
    .s resultString = json.getJsonData(Title,count)
    k json
    q resultString
}

/// Description:判断库存转移单是否已经做了部分转移（写于东营二院）
/// Creator:	hulihua
/// CreateDate:	2016-01-07
/// Table:      DHC_InIsTrf,DHC_InIsTrfItm
/// Input:      init-库存转移主表ID
/// Output:
/// Return：    1-是,0-否
/// w ##class(web.DHCST.DHCINIsTrf).IfAuditPart("54309")
ClassMethod IfAuditPart(init As %String) As %String
{
	n (init)
	q:init="" 0
	s ch=0,flag=0
	f  s ch=$o(^DHCINIT(init,"ITI",ch)) q:(ch="")!(flag'=0)  d
	.s initi=init_"||"_ch
	.s status=$p(^DHCINIT(init,"ITI",ch),"^",23)
	.s:status="31" flag=1
	q flag
}

/// description: 获取默认出库类型
/// w ##class(web.DHCST.DHCINIsTrf).DefaultOpType()
ClassMethod DefaultOpType()
{
	&SQL(SELECT IPT_RowId INTO :iptId FROM DHC_OperateType WHERE IPT_Type='O' AND IPT_Default='Y')
	q:iptId'="" iptId
	&SQL(SELECT IPT_RowId INTO :iptId FROM DHC_OperateType WHERE IPT_Type='O' AND IPT_Desc='正常出库')
	q:iptId'="" iptId
	&SQL(SELECT IPT_RowId INTO :iptId FROM DHC_OperateType WHERE IPT_Type='O')
	q iptId
}

/// Description:改造库存转移拒绝接收为新业务
/// Creator:yangsj
/// CreateDate:2020-04-14
/// Input:init - 库存转移主表 RowId ; user 用户
/// Output: 0 成功； 其它 失败
/// Other: w ##class(web.DHCST.DHCINIsTrf).TransInAuditRefuse(84,10213)
ClassMethod TransInAuditRefuse(init As %String, user As %String) As %String
{
 n (init,user)
 //加锁
 q:..lock(init)<0 -99  
 //检查状态
 s status=""
 &sql(select init_state into :status from dhc_inistrf where %ID=:init)
 i status'="21" d ..uLock(init) q -100
 s Todate=0
 s frloc=$p(^DHCINIT(init),"^",5)
 s arcdate=$p(^DHCINIT(init),"^",9)
 s initNo=$p(^DHCINIT(init),"^",1)
 i ..IfAuditPart(init)=1 d ..uLock(init) q -202     //hulihua 2016-01-07 做了部分接收的不能"拒绝入库"！
 s ret = ##class(PHA.IN.MonSettle.Save).CheckCanRefuse(init)
 i (ret = "N") d ..uLock(init) q -7
 ts
 s newStatus="30"
 s d=+$h,t=$p($h,",",2),Completed="N"
 s AuditNoDate=+$h
 s AuditNoTime=$p($h,",",2)

 &sql(UPDATE DHC_InIsTrf set INIT_State=:newStatus, INIT_RefuseDate=:AuditNoDate,
 INIT_RefuseTime=:AuditNoTime,INIT_RefuseUser_DR=:user where %ID=:init)
 i SQLCODE'=0 tro  d ..uLock(init) q -1
  //处理库存和台账
 s err=0,ret=0
 s type="K"
 s ch=0
 f  s ch=$o(^DHCINIT(init,"ITI",ch)) q:(ch="")!(ret'=0)  d
 .s initi=init_"||"_ch
 .
 .s status=$p(^DHCINIT(init,"ITI",ch),"^",23)
 .q:status'="21"
 . s inclb=$p(^DHCINIT(init,"ITI",ch),"^",3)
 .s qty=$p(^DHCINIT(init,"ITI",ch),"^",1)
 .s trQty=qty
 .s uom=$p(^DHCINIT(init,"ITI",ch),"^",7)
 .s inci=+inclb
 .s buom=$P(^INCI(inci,1),"^",10)
 .s fac=##class(web.DHCST.Common.UtilCommon).UOMFac(uom,buom)
 .s qty=qty*fac
 .s rp=$p(^DHCINIT(init,"ITI",ch),"^",15)
 .s rpAmt=$p(^DHCINIT(init,"ITI",ch),"^",16)
 .s sp=$p(^DHCINIT(init,"ITI",ch),"^",17)
 .s spAmt=$p(^DHCINIT(init,"ITI",ch),"^",18)
 .s ret=##class(web.DHCST.Common.StockHandle).UpdateStock(inclb,qty)
 .i ret<0 tro  s err=-3  q 
 .
 .s trData=type
 .s trData=trData_"^"_initNo_"^"_inclb_"^"_+trQty_"^"_uom_"^"_+sp
 .s trData=trData_"^"_user_"^"_initi_"^"_+rp_"^"_+rpAmt_"^"_+spAmt
 .s ret=##class(web.DHCST.Common.StockHandle).IntoTrans(trData)
 .i ret<0 tro  s err=-4  q 
 .//拒绝接收,损益添加到对应的调价损益
 .s ret=..InsertAsp(initi)
 .i ret<0 tro  s err=-5 q
 .&sql(update dhc_inistrfitm set dhciti_state=:newStatus where %ID=:initi)
 .i SQLCODE<0 tro  s err=-6,ret=SQLCODE  q 
 .
 b ;001
 i err=0  tc
 d ..uLock(init)
 q err
}

/// Decription:选取拒绝接收的库存转移单从新制作新的转移单
/// Creator:yangsj
/// CreateDate:2020-07-31
/// Input:RefuseINIT，User
/// Output:NewINIT  Other:作废重转失败
/// Table:
/// Debugger: w ##class(web.DHCST.DHCINIsTrf).TransByRefuseINIT(101,10213)
ClassMethod TransByRefuseINIT(RefuseINIT, User)
{
	n (RefuseINIT, User)
	q:RefuseINIT="" "-1^"_..Trans("作废重转单据为空")
	q:User="" "-2^建单人为空"
	s status=$P(^DHCINIT(RefuseINIT),"^",14)
	q:status'=30 "-3^"_..Trans("作废重转的单据不是拒绝接收状态")
	
	s supplyPhaLoc=$P(^DHCINIT(RefuseINIT),"^",5)
	s requestPhaLoc=$P(^DHCINIT(RefuseINIT),"^",6)
	s reqid=$P(^DHCINIT(RefuseINIT),"^",7)
	s ReqActiveFlag=..CheckReqIfActive(RefuseINIT)
	i ReqActiveFlag="N" s reqid=""
	s operatetype=$P(^DHCINIT(RefuseINIT),"^",19)
	s Complete=""
	s Status=10  //保存状态	 
	s StkGrpId=$P(^DHCINIT(RefuseINIT),"^",23)
	s StkType=$P(^DHCINIT(RefuseINIT),"^",24)
	s remark=$G(^DHCINIT(RefuseINIT,"REM"))  
	s MainInfo=supplyPhaLoc _ "^" _ requestPhaLoc _ "^" _ reqid _ "^" _ operatetype _ "^"_ Complete _ "^" _ Status _ "^" _ User _ "^"_StkGrpId_"^"_StkType_"^"_remark
	//w MainInfo,!
	//s MainInfo = supplyPhaLoc + "^" + requestPhaLoc + "^" + reqid + "^" + operatetype + "^"+ Complete + "^" + Status + "^" + userId + "^"+StkGrpId+"^"+StkType+"^"+remark
	//s str = Initi + "^" + Inclb + "^"	+ Qty + "^" + UomId + "^"+ ReqItmId + "^" + Remark
	
	s ListData=""
	s sub=0
	f  s sub=$O(^DHCINIT(RefuseINIT,"ITI",sub)) q:sub=""  d
	.s Data=^DHCINIT(RefuseINIT,"ITI",sub)
	.s Inclb=$P(Data,"^",3)
	.s Qty=$P(Data,"^",1)
	.s UomId=$P(Data,"^",7)
	.s AvaQty=##class(web.DHCST.Common.DrugStkCommon).CurInclbAvaQty(Inclb,UomId)
    .q:Qty>AvaQty
	.s ReqItmId=$P(Data,"^",2)	 //请求明细
	.s ReqActiveFlag=..CheckReqIIfActive(ReqItmId)
	.i ReqActiveFlag="N" s ReqItmId=""
	.s Remark=$P(Data,"^",24)
	.s DetailStr="^" _ Inclb _ "^"	_ Qty _ "^" _ UomId _ "^"_ ReqItmId _ "^" _ Remark
	.s ListData=$S(ListData="":DetailStr,1:ListData_$c(1)_DetailStr)
	//w ListData,!
	
	s NewINIT = ..Save("", MainInfo, ListData ) 
	q:+NewINIT<0 NewINIT
	ts
	s status="40" 
	&sql(UPDATE DHC_InIsTrf SET INIT_AgainINIT_DR=:NewINIT,INIT_State=:status WHERE INIT_RowId =:RefuseINIT)  //将新的转移主表id插入在旧转移单的新单指向中
	i SQLCODE'=0 tro
	q:SQLCODE'=0 SQLCODE
	&SQL(UPDATE DHC_InIsTrfItm SET DHCITI_State=:status WHERE INITI_INIT_ParRef =:RefuseINIT)
	i SQLCODE'=0 tro
	q:SQLCODE'=0 SQLCODE
	
	tc
	q NewINIT
}

/// Decription:检查转移单可用库存不足的明细
/// Creator:yangsj
/// CreateDate:2020-07-31
/// Input:RefuseINIT
/// Output:InciDescStr
/// Table:
/// Debugger: w ##class(web.DHCST.DHCINIsTrf).GetNotEnoughStorByINIT(101)
ClassMethod GetNotEnoughStorByINIT(RefuseINIT)
{
	n (RefuseINIT)
	s state=$P(^DHCINIT(RefuseINIT),"^",14)
	q:state'=30 ""
	s title=..Trans("拒绝转移单据将重新生成新的转移单")
	s detailStr=""
	s sub=0
	f  s sub=$O(^DHCINIT(RefuseINIT,"ITI",sub)) q:sub=""  d
	.s Data=^DHCINIT(RefuseINIT,"ITI",sub)
	.s Inclb=$P(Data,"^",3)
	.s Qty=$P(Data,"^",1)
	.s UomId=$P(Data,"^",7)
	.s AvaQty=##class(web.DHCST.Common.DrugStkCommon).CurInclbAvaQty(Inclb,UomId)
    .q:Qty<=AvaQty
    .s inci=+Inclb
  	.s inciDesc=$P(^INCI(inci,1),"^",2)
  	.s detailStr=$S(detailStr="":inciDesc,1:detailStr_"##"_inciDesc)
  	
  	i detailStr'=""  s detailStr=..Trans("，并将自动过滤以下库存不足药品: ##")_detailStr
  	q title_detailStr
}

/// Decription:检查请求明细是否可用
/// Creator:yangsj
/// CreateDate:2020-08-12
/// Input:ReqI
/// Output:Y/N
/// Table:
/// Debugger: w ##class(web.DHCST.DHCINIsTrf).CheckReqIIfActive("80||2")
ClassMethod CheckReqIIfActive(ReqI)
{
	n (ReqI)
	q:ReqI="" "N"
	s ActiveFlag="Y"
	s Init=""
	f  s Init=$o(^DHCINIT(0,"RQI",ReqI,Init)) q:(Init="")||(ActiveFlag="N")  d
	.s status=$P(^DHCINIT(Init),"^",14)
	.q:(status=30)||(status=40)
	.s ActiveFlag="N"
	
	q ActiveFlag
}

/// Decription:检查一张转移单中的请求明细是否可用
/// Creator:yangsj
/// CreateDate:2020-08-12
/// Input:Init
/// Output:Y/N
/// Table:
/// Debugger: w ##class(web.DHCST.DHCINIsTrf).CheckReqIfActive(60)
ClassMethod CheckReqIfActive(INIT)
{
	n (INIT)
	s ActiveFlag="N"
	q:INIT="" ActiveFlag
	s ReqID=$P(^DHCINIT(INIT),"^",7)
	q:ReqID="" ActiveFlag
	s sub=0
	f  s sub=$O(^DHCINIT(INIT,"ITI",sub)) q:(sub="")||(ActiveFlag="Y")  d
	.s ReqI=$P(^DHCINIT(INIT,"ITI",sub),"^",2)
	.q:ReqI=""
	.s activei=..CheckReqIIfActive(ReqI)
	.i activei="Y" s ActiveFlag="Y"  q
	
	q ActiveFlag
}

/// Description:跨院区转移时补充接收院区的价格
/// Creator:yangsj 
/// CreateDate:2021-03-17
/// Input: INITI
/// Output:0 成功/其他失败
/// Table:
/// Debugger: W ##class(web.DHCST.DHCINIsTrf).UpdatePriceForInitByHosp("22||1","2080||11||1")
ClassMethod UpdatePriceForInitByHosp(INITI, ToInclb)
{
	n (INITI, ToInclb)
	s Ret		= 0
	q:INITI="" Ret
	s INIT		= +INITI
	s Inci 	    = +ToInclb
	s FrLoc 	= $p(^DHCINIT(INIT), "^", 5)
	s FrHosp 	= $P(^CTLOC(FrLoc), "^", 22)
	s ToLoc 	= $p(^DHCINIT(INIT), "^", 6)
	s ToHosp 	= $P(^CTLOC(ToLoc), "^", 22)
	q:(FrHosp = ToHosp) Ret
	s RuleFlag	= ##Class(web.DHCSTCOMMPARA).GetRpRule(ToHosp, +$h)	//进价规则,加日期
	i RuleFlag	= 1  d
	.s INGDrp 	= ##Class(web.DHCSTPRICE).LastInPrice(ToInclb, "", ToHosp)	//入库进价
	.s Ingd		= ..InsertINGDI(INITI, ToInclb)
	.i (Ingd <= 0) s Ret = Ingd q
	.s UnitePriceFlag = ..CheckUniteInAdjPrice(Inci, ToHosp)
	.i UnitePriceFlag = "N" s Ret=..InsertUniteInAdjPrice(INITI, Inci, ToHosp)
	.q:(Ret '= 0)
	e  i (RuleFlag = 2)  d 
	.s UnitePriceFlag = ..CheckUniteInAdjPrice(Inci, ToHosp)
	.i (UnitePriceFlag = "N") s Ret=..InsertUniteInAdjPrice(INITI, Inci, ToHosp)
	.q:(Ret '= 0)
	e  i (RuleFlag = 3)  d
	.s BatchPriceFlag = ..CheckBatchInAdjPrice(ToInclb, ToHosp)
	.i BatchPriceFlag = "N" s Ret=..InsertBatchInAdjPrice(INITI, ToInclb, ToHosp)
	
	q Ret
}

/// Description:插入入库记录(补充入库价格)
/// Creator:yangsj 
/// CreateDate:2021-03-17
/// Input: INITI
/// Output:>0成功/其他失败
/// Table:
/// Debugger: W ##class(web.DHCST.DHCINIsTrf).UpdatePriceForInitByHosp("22||1", "2080||11||1")
ClassMethod InsertINGDI(INITI, ToInclb)
{
 	n (INITI, ToInclb)
 	//组织入库主表数据
 	s INIT     = +INITI
 	s Inci     = +ToInclb
 	s sub      = $P(INITI, "||", 2)
 	s INITData = ^DHCINIT(INIT)
 	s INITIData= ^DHCINIT(INIT, "ITI", sub)
 	s ToLoc    = $p(INITData, "^", 6)
 	s FrInclb  = $P(INITIData, "^", 3)
 	s Incib    = $P(^INCI(Inci, "IL", $P(FrInclb, "||", 2), "LB", $P(FrInclb, "||", 3)), "^", 1)
 	s DHCIncib = $O(^DHCINCIB(0, "INCIB", Incib, ""))
 	s Vendor   = $P(^DHCINCIB(DHCIncib), "^", 8)
 	s Manf     = $P(^DHCINCIB(DHCIncib), "^", 7)
 	s Scg	   = ""
 	s User	   = $p(INITData, "^", 17)
 	s IngdNo   = ""
 	s MainInfo = $LB(ToLoc, Vendor, Scg, User, IngdNo)	
 	s MainInfo = $LTS(MainInfo, "^")
 	//组织子表数据
 	s inciCode = $P(^INCI(Inci, 1), "^", 1)
 	s inciDesc = $P(^INCI(Inci, 1), "^", 2)
 	s Chl  	   = $P(Incib, "||", 2)
 	s BatNo    = $p(^INCI(Inci, "IB", Chl), "^", 1)
 	s ExpDate  = $p(^INCI(Inci, "IB", Chl), "^", 2)
 	s ExpDate  = ##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(ExpDate, "ST")
 	s Uom	   = $P(INITIData, "^", 7)
 	s UomDesc  = $P(^CT("UOM", Uom), "^", 2)  //这里传入单位描述
 	s StkQty   = ""
 	s Qty      = $P(INITIData, "^", 1)
 	s rp	   = $p(INITIData, "^", 15)
 	s sp	   = $p(INITIData, "^", 17)
 	s DetailStr= $LB(ToInclb, inciCode, inciDesc, BatNo, ExpDate, UomDesc, rp, sp, StkQty, Qty, Manf)
 	s DetailStr= $LTS(DetailStr, "^")
 	// 借用虚拟入库方法
 	q ##class(web.DHCST.DHCVIRTUALIMP).Save(MainInfo, DetailStr)
}

/// 判断是否有统一价调价记录
/// Creator:yangsj 
/// CreateDate:2021-03-17
/// Input: Inci, Hosp
/// Output:Y/N
/// Table:
/// Debugger: W ##class(web.DHCST.DHCINIsTrf).CheckUniteInAdjPrice(2080,2)
ClassMethod CheckUniteInAdjPrice(Inci, Hosp)
{
	n (Inci, Hosp)
	s ExistFlag = "N"
    q:(Inci = "") ExistFlag
    q:'$D(^INCI(Inci)) ExistFlag
    s GroupFlag = ##Class(web.DHCSTCOMMPARA).GetGroupFlag() 
    s excudate  = +$H + 1
    s dirFlag   = -1 
    s adjrow = ""
    I (Hosp '= "")&&(GroupFlag = 2) D
    .s aexcudate = $o(^INASP(0, "HOSPI", Hosp, Inci, excudate), dirFlag)
    .q:aexcudate=""
    .s adjrow=$o(^INASP(0, "HOSPI", Hosp, Inci, aexcudate, ""), dirFlag)
    i (GroupFlag '= 2)&&(adjrow = "") d
    .s aexcudate = $o(^INASP(0, "INCI", Inci, excudate), dirFlag)
    .q:(aexcudate = "")
    .s adjrow = $o(^INASP(0, "INCI", Inci, aexcudate, ""), dirFlag)
    q:(adjrow '= "") "Y"
    q "N"
}

/// 插入统一调价表
/// Creator:yangsj 
/// CreateDate:2021-03-17
/// Input: INITI
/// Output:>0成功/其他失败
/// Table:
/// Debugger: W ##class(web.DHCST.DHCINIsTrf).InsertUniteInAdjPrice("21||1", 2080, 2)
ClassMethod InsertUniteInAdjPrice(INITI, Inci, ToHosp)
{
	n (INITI, Inci, ToHosp)  
	s Ret		  = 0
	s INIT		  = +INITI     
	s Chl		  = $P(INITI, "||", 2) 
	s INITData 	  = ^DHCINIT(INIT)
 	s INITIData	  = ^DHCINIT(INIT, "ITI", Chl)
 	s ToLoc 	  = $p(INITData, "^", 6)
 	s preexedate  = ##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(+$h, "ST")
 	s ItmRowid	  = Inci
 	s AdjUomId	  = $p(INITIData, "^", 7)
 	s ResultSp	  = $p(INITIData, "^", 17)
    s ResultRp	  = $p(INITIData, "^", 15)
 	s AdjUserId	  = $p(INITData, "^", 17)
 	s AdjReasonId = ""
 	s Remark	  = "跨院区转移补充接收院区价格"
 	
 	// 借用入库自动调价方法	
 	s AppName = ##class(web.DHCST.DHCINIsTrf).%GetParameter("AppName")
	s AdjNo = ##class(web.DHCST.Common.AppCommon).GetAppNo(AppName, "", ToLoc)
    q:(AdjNo = "") -1 						;生成单号失败
 	s data=preexedate_"^"_ItmRowid_"^"_AdjUomId_"^"_ResultSp_"^"_ResultRp_"^"_AdjUserId_"^"_AdjReasonId_"^"_ToHosp_"^^^"_Remark_"^^^"_0_"^"_0
	s AspId	= ##class(web.DHCST.INAdjSalePrice).Insert(AdjNo, data, "Y")  //增加入库标志 "Y" 入参 ，方法中不判断计划生效日期
	q:(AspId <= 0) AspId 
	s ret	= ##class(web.DHCST.INAdjSalePrice).Audit(AspId, AdjUserId)
	q:(ret < 0) ret 
	
 	q Ret
}

/// 判断是否有批次价调价记录
/// Creator:yangsj 
/// CreateDate:2021-03-17
/// Input: Inci, Hosp
/// Output:Y/N
/// Table:
/// Debugger: W ##class(web.DHCST.DHCINIsTrf).CheckBatchInAdjPrice("2080||2||3",2)
ClassMethod CheckBatchInAdjPrice(ToInclb, ToHosp)
{
	n (ToInclb, ToHosp)
	s ExistFlag = "N"
    s dirFlag	= -1
    s Inci = +ToInclb
    s incib = $P(^INCI(Inci, "IL", $P(ToInclb, "||", 2), "LB", $P(ToInclb, "||", 3)), "^", 1)
	q:(incib = "") ExistFlag
	s dateh = +$h
	s timeh = 86399 //23:59:59
	s (retrp, retsp) = 0
	s apbID = ""
	s nTime = timeh + 1
	s GroupFlag = ##Class(web.DHCSTCOMMPARA).GetGroupFlag() //yunhaibao20151222, 集团化医院各自管理价格
	i (ToHosp '= "")&&(GroupFlag = 2) D
	.s execTime = nTime
	.f  s execTime = $o(^DHCSTINAPB(0, "HOSPINCIB", ToHosp, incib, dateh, execTime), dirFlag) q:(execTime="")!(apbID '= "")  d
	..s apbID = $o(^DHCSTINAPB(0, "HOSPINCIB", ToHosp, incib, dateh, execTime, ""), dirFlag)
	.i (apbID = "") d
	..s execDate = dateh
	..f  s execDate = $o(^DHCSTINAPB(0, "HOSPINCIB", ToHosp, incib, execDate), dirFlag) q:(execDate="")!(apbID '= "")  d
	...s execTime = $o(^DHCSTINAPB(0, "HOSPINCIB", ToHosp, incib, execDate, ""), dirFlag)
	...s apbID = $o(^DHCSTINAPB(0, "HOSPINCIB", ToHosp, incib, execDate, execTime, ""), dirFlag)
	i (GroupFlag '= 2)&&(apbID = "") d
	.s execTime = nTime
	.f  s execTime = $o(^DHCSTINAPB(0, "INCIB", incib, dateh, execTime), dirFlag) q:(execTime = "")!(apbID '= "")  d
	..s apbID = $o(^DHCSTINAPB(0, "INCIB", incib, dateh, execTime, ""), dirFlag)
	.i apbID = "" d
	..s execDate = dateh
	..f  s execDate = $o(^DHCSTINAPB(0, "INCIB", incib, execDate), dirFlag) q:(execDate = "")!(apbID '= "")  d
	...s execTime = $o(^DHCSTINAPB(0, "INCIB", incib, execDate, ""), dirFlag)
	...s apbID = $o(^DHCSTINAPB(0, "INCIB", incib, execDate, execTime, ""), dirFlag)
	q:(apbID '= "") "Y"
    q ExistFlag
}

/// 插入批次调价表
/// Creator:yangsj 
/// CreateDate:2021-03-17
/// Input: INITI
/// Output:>0成功/其他失败
/// Table:
/// Debugger: W ##class(web.DHCST.DHCINIsTrf).InsertBatchInAdjPrice("21||1", 2080, 2)
ClassMethod InsertBatchInAdjPrice(INITI, ToInclb, ToHosp)
{
	n (INITI, ToInclb, ToHosp)
	s AspBatId		= ""
	s Inci			= +ToInclb
	s Incib  		= $P(^INCI(Inci, "IL", $P(ToInclb, "||", 2), "LB", $P(ToInclb, "||", 3)), "^", 1)
	s INIT			= +INITI     
	s Chl			= $P(INITI, "||", 2) 
	s INITData 		= ^DHCINIT(INIT)
 	s INITIData		= ^DHCINIT(INIT, "ITI", Chl)
 	s ToLoc 		= $p(INITData, "^", 6)
 	s preexedate	= ##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(+$h+1, "ST")
 	s AdjUomId		= $p(INITIData, "^", 7)
 	s ResultSp		= $p(INITIData, "^", 17)
    s ResultRp		= $p(INITIData, "^", 15)
 	s AdjUserId		= $p(INITData, "^", 17)
 	s AdjReasonId	= ""
 	s PriceFileNo	= ""
 	s PriceFileDate	= ""
 	s Remark 		= "跨院区转移补充接收院区价格"
 	s PriorRp		= 0
 	s PriorSp		= 0
 	s DataLB		= $LB(AspBatId, Incib, preexedate, Inci, AdjUomId, ResultSp, ResultRp, AdjUserId, AdjReasonId, ToHosp, PriceFileNo, PriceFileDate, Remark, PriorRp, PriorSp)
 	s DataStr		= $LTS(DataLB, "^")
 	s Ret			= 0
 	s adjNo			= ##class(web.DHCST.INAdjPriceBatch).Save("", "", ToLoc, DataStr)
 	i ($P(adjNo, "^", 1) < 0) q adjNo 
 	s AspId 		= $O(^DHCSTINAPB(0, "ASPNO", $$ALPHAUP^SSUTIL4(adjNo), 0)) //一个单号只对应一条调价记录
 	s Params		= ""_"^"_ToLoc
 	s Ret			= ##class(web.DHCST.INAdjPriceBatch).Audit(AspId, AdjUserId, Params)
	q:(Ret '= 0) Ret
	s Ret			= ##class(web.DHCST.INAdjPriceBatch).SetExe(AspId, Params)
	q:(Ret '= 0) Ret
	
	q Ret
}

/// Decription:	判断转移单是否存在麻醉精一药品
/// Creator   :	yangsj
/// CreateDate:	2021-07-19
/// Input     :
/// Output    : Y/N
/// Table     : 
/// Debugger  : w ##Class(web.DHCST.DHCINIsTrf).CheckMZJYExsit(2)
ClassMethod CheckMZJYExsit(INIT)
{
	s Exsit ="N"
	s Itm = $O(^DHCINIT(0, "POISON", "Y", INIT, 0)) 
	i Itm '= "" s Exsit = "Y"
	q Exsit
}

/// Decription:	保存麻醉精一操作状态
/// Creator   :	yangsj
/// CreateDate:	2021-07-19
/// Input     :
/// Output    : Y/N
/// Table     : 
/// Debugger  : w ##Class(web.DHCST.DHCINIsTrf).SaveStatus(2, 4, 5)
ClassMethod SaveStatus(Type, Pointer, Status, User, Remark = "", CheckRepeat = "N", InitState = "")
{
	s MZJYFlag = ..CheckMZJYExsit(Pointer)
	q:(MZJYFlag '= "Y") "-1^转移单中不包含麻醉精一药品"
	s State = $P(^DHCINIT(Pointer), "^", 14)
	q:(InitState = 21)&&(State '= 21)&&(State '= 31) "-1^转移单不是出库审核或者转移接收状态"
	q:(InitState = 31)&&(State '= 31) "-1^转移单不是转移接收状态" 
	q ##Class(BS.PHA.IN.Status).Save(Type, Pointer, Status, User, Remark, CheckRepeat)
}

/// 翻译 
/// yangsj 2020-11-05
ClassMethod Trans(Text)
{
	q ##class(websys.Translation).Get("dhcst.dhcinistrf.csp",Text)
}

}
