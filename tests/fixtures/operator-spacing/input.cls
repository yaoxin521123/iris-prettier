Include web.DHCPE.FixParam

Class web.DHCPE.ResultNew Extends %RegisteredObject
{

Parameter FKStation = 4;

/// Debug: d ##class(%ResultSet).RunQuery("web.DHCPE.ResultNew","FindDiagnosisPatInfo","","2026-06-10","2026-06-15","","","","N","CanGS","2","","dhcpe.diagnosis.audit.csp","","","","","","","^^")
Query FindDiagnosisPatInfo(RegNo, BDate, EDate, VIP, PatName As %String = "", Group As %String = "", MainDoctor As %String = "", GenStatus As %String = "", HospID As %String = "", OtherPAADM As %String = "", CSPName As %String = "", OnlyRead As %String = "", HaveLock As %String = "", DocName As %String = "", IsResultDate As %String = "", TestFlag As %String = "", MDocName As %String = "", extstr As %String = "") As websys.Query(ROWSPEC = "PaadmID:%String,PAPMINo:%String,AdmDate:%String,Name:%String,Age:%String,Sex:%String,VIPLevel:%String,VIPDesc:%String,GName:%String,GSStatus:%String,ReMark:%String,TCAAuditFlag,TCAMainFlag,TPostPonedFlag,THPNo,GWFlag,LockUserDesc,TRecordDate:%String,TAuditDate:%String,TCancelLockUser:%String,PostPonedInfo:%String,JYFlag:%String,AIFlag:%String,CheckedFlag:%String,TLastSendDetail:%String")
{
}

ClassMethod FindDiagnosisPatInfoExecute(ByRef qHandle As %Binary, RegNo, BDate, EDate, VIP, PatName As %String = "", Group As %String = "", MainDoctor As %String = "", GenStatus As %String = "", HospID As %String = "", OtherPAADM As %String = "", CSPName As %String = "", OnlyRead As %String = "", HaveLock As %String = "", DocName As %String = "", IsResultDate As %String = "", TestFlag As %String = "", MDocName As %String = "", extstr As %String = "") As %Status
{
    s ^temp("dhcpe","FindDiagnosisPatInfo")=$lb(RegNo, BDate, EDate, VIP, PatName , Group , MainDoctor , GenStatus , HospID , OtherPAADM , CSPName , OnlyRead , HaveLock , DocName , IsResultDate, TestFlag, MDocName, extstr)
    
    Set repid=$I(^CacheTemp)
    If $g(ind)="" Set ind=1 
    s LoginDocName=""
    if $d(%session) {
        set langId=%session.Get("LOGON.LANGID")
        s LoginDocName=%session.Get("LOGON.USERNAME")
    }
    else
    { s langId=""}
    s CurUserID=##class(HS.BL.PECommon).GetDftSessionParam("USERID")
    s ^tempdhcpe("CurUserID")=CurUserID
    ;s CurUserID=21687
    i TestFlag="1" s CurUserID=21693
    
   	s IsZJ=$P(extstr,"^",1)
   	s AuditDate=$P(extstr,"^",2)
   	s DistributionDate=$P(extstr,"^",3)
    k ^TmpDHCPE("FindDiagnosisPatInfo",CurUserID)
    
    s LocID=##class(HS.BL.PECommon).GetDftSessionParam("LOCID")
    s GroupID=##class(HS.BL.PECommon).GetDftSessionParam("GROUPID")
    //超级安全组标记
    s SuperGroup=$g(^DHCPESetting("DHCPE","SuperGroup",LocID))
    
    i TestFlag="1" s SuperGroup=75
    i TestFlag="1" s LocID=15
    s SuperFlag=0
    i SuperGroup=GroupID 
    {
        s SuperFlag="1"
    }
    
    i (CurUserID="21573")&&(LocID=293) s SuperFlag=1   //吴琴琴主任不用分配可以看全部报告
    
    
    if (OtherPAADM'="")
    
    {  
    s PaPatID=+^PAADM(OtherPAADM)
    
    s PAPMINo=$P(^PAPER(PaPatID,"PAT",1),"^",1)
    s Name=$P(^PAPER(PaPatID,"ALL"),"^",1)
    q:(PatName'="")&&(PatName'[Name)
    s Sex=$P(^PAPER(PaPatID,"ALL"),"^",7)
    s:Sex'="" Sex=$P(^CT("SEX",Sex),"^",2)
    s Sex=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.CTSex",Sex,"CTSEXDesc","cls")
    s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检"),AuditUser=""
     
    s ID=$o(^User.DHCPEOtherPatientToHPI("OTHPAADMDRIndex",OtherPAADM,0))
    q:ID=""
    s AuditStatus=$LG(^User.DHCPEOtherPatientToHPD(ID),12) //状态 0：已删除  1：未审核   2：已审核  3：已打印  4：已取
    s AuditUser=$LG(^User.DHCPEOtherPatientToHPD(ID),13)
    s AdmDate=$LG(^User.DHCPEOtherPatientToHPD(ID),4)
    s AdmDate=##class(websys.Conversions).DateLogicalToHtml(AdmDate)
    s CAAuditFlag = 0,CAMainFlag = 0
    i (AuditUser'="")&&(AuditStatus="2") 
    {
        s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检")
        i ##class(web.DHCPE.CA.Main).GetSignName(2,OtherPAADM)'="" s CAAuditFlag = 1
    }
    i (AuditUser'="")&&(AuditStatus="1") s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检")
    s MainInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","MainDoctor",OtherPAADM))
    s MainUser=$P(MainInfo,"^",1)
    i MainUser'="" 
    {
        s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审")
        i ##class(web.DHCPE.CA.Main).GetSignName(3,OtherPAADM)'="" s CAMainFlag = 1
    }
    q:(MainDoctor="Y")&&(GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检"))
    ;i (MainDoctor="Y")&&(GSStatus=##class(websys.Translation).Get(CSPName,"已初审",langId)) s GSStatus="未初审"
    q:(GenStatus="NoGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检"))
    q:(GenStatus="HadGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检"))
    q:(GenStatus="HadMain")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审"))
    
    s Age=##class(web.DHCBillInterface).GetPapmiAge(PaPatID,"",HospID)
    s (VIPLevel,VIPDesc,ReMark,GName)=""
    s ArriveFlag=0
    s PaadmID=OtherPAADM
    
    s IADM=$O(^DHCPEIADM(0,"PAADM",PaadmID,0))
    q:IADM=""
    s AllRejectFlag=..AllItemReject(IADM)
	q:(AllRejectFlag="Y") //到达之后删除或弃检了所有项目的记录 20250702 qiaoyue
    
    s PostPonedFlag=##class(web.DHCPE.OrderPostPoned).GetHadDelayItems(PaadmID)
    s PostPonedInfo=PostPonedFlag
    i PostPonedFlag="" s PostPonedFlag="N"
    e  s PostPonedFlag="Y"
    
    Set JYFlag = ##class(web.DHCPE.ResultDiagnosis).GetGSJYFlag(PaadmID)
    Set CheckedFlag=##class(web.DHCPE.ResultDiagnosis).GetDHCPEStatusFlag("SendAudit",PaadmID)
    Set lastSendDetail = ##class(web.DHCPE.ResultDiagnosisNew).GetLastSendDetail(PaadmID)
    s ^CacheTemp(repid,ind)=$lb(PaadmID,PAPMINo,AdmDate,Name,Age,Sex,VIPLevel,VIPDesc,GName,GSStatus,ReMark,CAAuditFlag,CAMainFlag,PostPonedFlag,PostPonedInfo,CheckedFlag,lastSendDetail)
    s ind=ind+1
    
    Set qHandle=$lb(0,repid,0)
    Quit $$$OK
    }
    else
    {
    
    
     if (RegNo'="")
    {
   
    //优先按照体检号进行查询，查不到数据按照登记号查询
    s PreID=""
    s PreID=##class(web.DHCPE.HISUICommon).GetPreIDByHPNo(RegNo)
    i PreID'="" {
        s PIBIDR=$P($g(^DHCPEPreIADM(PreID)),"^",1)
        i PIBIDR'="" s RegNoIndex=$P($g(^DHCPEPreIBI(PIBIDR)),"^",1)
    }else{
        s RegNoIndex=RegNo
    }
	s:($L(RegNo)'=11)&($L(RegNo)'=10) RegNoIndex=##class(web.DHCPE.PreIBaseInfo).GetRegNoByIDCard(RegNo)  //身份证返回登记号
	s:$L(RegNo)=11 RegNoIndex=##class(web.DHCPE.PreIBaseInfo).GetRegNoByTell(RegNo) //手机号码返回登记号
	s RegNoStr=RegNoIndex

    s RegNoIndex=$ZCVT(RegNoIndex,"U")
    s:RegNoIndex'["^" PaPatID=$O(^PAPERi("PAPMI_PatNo",RegNoIndex,0))
    if (RegNoIndex'["^"){
       if (PaPatID="")
        {
            Set qHandle=$lb(0,repid,0)
            Quit $$$OK  
        }
     }
    for i=1:1:$L(RegNoStr,"^")
    {
	s RegNoIndex=$P(RegNoStr,"^",i)
	s RegNoIndex=$ZCVT(RegNoIndex,"U")
	s PaPatID=$O(^PAPERi("PAPMI_PatNo",RegNoIndex,0))
    s PAPMINo=$P($g(^PAPER(PaPatID,"PAT",1)),"^",1)
    s Name=$P($g(^PAPER(PaPatID,"ALL")),"^",1)
    //体检特殊客户类型
    s SpecialTypeCode=##class(web.DHCPE.SpecialType).GetSpecialType(PAPMINo)
    i SpecialTypeCode'="" s Name=Name_"("_SpecialTypeCode_")"

    s Sex=$P($g(^PAPER(PaPatID,"ALL")),"^",7)
    s:Sex'="" Sex=$P($g(^CT("SEX",Sex)),"^",2)
    b ;555555
    //s Age=##class(web.DHCBillInterface).GetPapmiAge(PaPatID,"")
    s Age=##class(web.DHCPE.DHCPECommon).GetPapmiAge(PaPatID,HospID)
    s (VIPLevel,VIPDesc)=""
    s ArriveFlag=0
    //s LocID=%session.Get("LOGON.CTLOCID")
    s LocID=##class(HS.BL.PECommon).GetDftSessionParam("LOCID")
    s PaadmID=""
    f  s PaadmID=$O(^PAPERdr(PaPatID,"ADM","H",PaadmID),-1) q:PaadmID=""  d
    .s LocFlag=##class(web.DHCPE.PreCommon).GetLocFlag("PAADM",PaadmID)
    .//q:(LocFlag=1)&&($D(^DHCPESetting("DHCPE","DefaultPAADM",LocID)))
    .s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检"),AuditUser="",Status=""
    .s SendAuditStatus=##class(web.DHCPE.ResultDiagnosis).IsCanSendAuditByPAADM(PaadmID)  //可核对 不可核对 已核对
    .q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(SendAuditStatus'=0)
    .q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanntCheck")&&(SendAuditStatus'=1)
    .q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="HadChecked")&&(SendAuditStatus'=2)
    .s ExistFlag= ##class(web.DHCPE.ResultDiagnosis).IsExistSendAuditByPAADM(PaadmID)  //存在核对未通过 1
    .q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(ExistFlag=1)  //可核对过滤核对未通过
    .q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="NoSendAudit")&&(ExistFlag'=1)
    .//s GSStatus=##class(web.DHCPE.ResultDiagnosis).IsAllItemExcByPAADM(PaadmID)  //可初审  不可初审
    .;q:(GSStatus="1")&&(GenStatus'["CanNoGS")&&(GenStatus'="") //过滤不可初审
    
    
    
    .//b ;1231233123
    .i ((SendAuditStatus=2)) s GSStatus=0 
    .i ((SendAuditStatus'=2)) s GSStatus=1  //未粘贴核对不允许主检
    .i GSStatus="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    .i (GSStatus="0") s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检")
    .//i (GSStatus="0")&&(SendAuditStatus="2") s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检")
    .//i (GSStatus="0")&&(SendAuditStatus'="2") s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    .s GSID=##class(web.DHCPE.ResultDiagnosis).GetSSId(PaadmID) 
    .s (TAuditDate,TAuditTime,TAuditDateTime)=""
    .i GSID'="" d
    ..s AuditUser=$P($G(^DHCPEGS(GSID,1)),"^",5)
    ..s Status=$P($G(^DHCPEGS(GSID,1)),"^",9)
    ..i AuditUser'="" d
    ...s TAuditDate=$P($G(^DHCPEGS(GSID,1)),"^",6)
    ...s:TAuditDate'="" TAuditDate=##class(websys.Conversions).DateLogicalToHtml(TAuditDate)
    ...s TAuditTime=$P($G(^DHCPEGS(GSID,1)),"^",7)
    ...s:TAuditTime'="" TAuditTime=##class(websys.Conversions).TimeLogicalToHtml(TAuditTime)
    ...s TAuditDateTime=TAuditDate_" "_TAuditTime
    
    .s CAAuditFlag = 0,CAMainFlag = 0
    .i AuditUser'="" d
    ..s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检")
    ..i ##class(web.DHCPE.CA.Main).GetSignName(2,PaadmID)'="" s CAAuditFlag = 1
    .i Status="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回主检")
    .s MainInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","MainDoctor",PaadmID))
    .s MainUser=$P(MainInfo,"^",1)
    .i MainUser'=""   d
    ..s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审")
    ..i ##class(web.DHCPE.CA.Main).GetSignName(3,PaadmID)'="" s CAMainFlag = 1
    .i Status="2" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回初审")
    .s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    .s LastUser=$P(LastInfo,"^",1)
    .s:LastUser'="" GSStatus="已终审"
    .;q:(MainDoctor="Y")&&(GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未初审"))
    .i (MainDoctor="Y")&&(GSStatus="已主检") s GSStatus="未初审"  
    .i OnlyRead="Y" d
    ..s:SendAuditStatus=0 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可核对")
    ..s:SendAuditStatus=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可核对")
    ..s:SendAuditStatus=2 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已核对")
    ..s:ExistFlag=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"核对不通过")
    
    
    .b ;666666
    .q:(OnlyRead="Y")&&(AuditUser'="")  //粘贴核对过滤已主检
    
    
    
    
    .q:(SuperFlag'="1")&&(OnlyRead="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))&&(GSStatus'="核对不通过")
    .q:(SuperFlag'="1")&&(OnlyRead="Y")&&(GenStatus="SelfNoSendAudit")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))   ////只看自己核对未通过记录
    .q:(GenStatus="SelfNoSendAudit")&&(ExistFlag'=1)
    .s PIADM=$O(^DHCPEIADM(0,"PAADM",PaadmID,0))
    .q:PIADM=""
    .s AllRejectFlag=..AllItemReject(PIADM)
	.q:(AllRejectFlag="Y") //到达之后删除或弃检了所有项目的记录 20250702 qiaoyue
    .s PreIADM=$P(^DHCPEIADM(PIADM),"^",4)
    .q:((PreID'="")&&(PreID'=PreIADM)) //体检号
    .//第一个为医生界面自动到达\第二个为打印条码自动到达
    .s AutoArrived=$G(^DHCPESetting("DHCPE","AutoArrived",LocID))
    .s AutoArrived=$p(AutoArrived,"^",1)
    .i AutoArrived="Y" d
    ..d:ArriveFlag=0 ##class(web.DHCPE.DHCPEIAdm).IAdmArrived(PreIADM)
    .s ArriveFlag=1
    .q:##class(web.DHCPE.ResultEdit).IsArrivedStatu(PaadmID)="0"
    .s AdmDate=$P(^PAADM(PaadmID),"^",6)
    .;q:(AdmDate<StartDate)||(AdmDate>EndDate)
    .s AdmDate=##class(websys.Conversions).DateLogicalToHtml(AdmDate)
    .;d ##class(web.DHCPE.TransResult).TransMain(PaadmID)
    .s VIPStr=##class(web.DHCPE.PreCommon).GetVIPLevel("PAADM",PaadmID)
    .i VIPStr'="" d
    ..s VIPLevel=$p(VIPStr,"^",1)
    ..s VIPDesc=$p(VIPStr,"^",2)
    .;q:(VIP'="")&&(VIP'=VIPLevel)
    .q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    .;q:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") //总检界面不显示单项体检记录
    .s:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    
    .s PGADMDR=$p($g(^DHCPEPreIADM(PreIADM)),"^",2) 
    .s THPNo= $p($g(^DHCPEPreIADM(PreIADM)),"^",27)
    .q:THPNo="0100003000"
    .S GName=""
    .i ""'=PGADMDR  d
    ..s GBIDR=$p($g(^DHCPEPreGADM(PGADMDR)),"^",1)
    ..i ""'=GBIDR s GName=$p($g(^DHCPEPreGBI(GBIDR)),"^",2)
    .i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s ReMark=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"有高危")
    .s PostPonedFlag=##class(web.DHCPE.OrderPostPoned).GetHadDelayItems(PaadmID)
    .s PostPonedInfo=PostPonedFlag
    .i PostPonedFlag="" s PostPonedFlag="N"
    .e  s PostPonedFlag="Y"
    
    
    .s GWFlag=""
    .i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s GWFlag="1"
    
    .s LockFlag=0
    .s LockUserDesc=""
    .s LockUser=""
    .i $d(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID)) d
    ..s LockFlag=1
    ..s LockUser=$p(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID),"^",1)
    ..s LockUserDesc=$p($g(^SSU("SSUSR",LockUser)),"^",2)
    
    
    ./***翻译 start***/
    .s Sex=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.CTSex",Sex,"CTSEXDesc","cls")
    .s VIPDesc=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.DHCPEVIPLevel",VIPDesc,"VLDesc","cls")
    ./***翻译 end***/
    .;;第一次获取结果时间
    .s RecordDate="",RecordTime="",RecordDateTime=""
    .s RecordID=$o(^User.DHCPEAdmRecordManagerI("AdmTypeIndex",PreIADM,"UPDATESTATIONS",0))
    .i RecordID'="" d
    ..s RecordDate=$LG(^User.DHCPEAdmRecordManagerD(RecordID),3)
    ..s:RecordDate'="" RecordDate=##class(websys.Conversions).DateLogicalToHtml(RecordDate)
    ..s RecordTime=$LG(^User.DHCPEAdmRecordManagerD(RecordID),5)
    ..s:RecordTime'="" RecordTime=##class(websys.Conversions).TimeLogicalToHtml(RecordTime)
    ..s RecordDateTime=RecordDate_" "_RecordTime
    .i GSStatus="已主检" s RecordDateTime=""
    .s TCancelLockUser=""
    .i $d(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID)) d
    ..s sort=+$O(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,""),-1)
    ..s CancelLockInfo=$g(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,sort))
    ..s CancelUserDR=$p(CancelLockInfo,"^",1)
    ..s:CancelUserDR'="" TCancelLockUser=$p(^SSU("SSUSR",CancelUserDR),"^",2)
    .q:(HaveLock="CancelLock")&&(TCancelLockUser="")
    .s JYFlag=##class(web.DHCPE.ResultDiagnosis).GetGSJYFlag(PaadmID)
    .s AIFlag="N"
    .s RPTID=$O(^DHCPERPT(0,"IADM",PIADM,""))
    .i RPTID'="" d
    ..s RPTAISendInfo=$P($G(^DHCPERPT(RPTID)),"^",20)
    ..i RPTAISendInfo'="" s AIFlag="Y"
    .Set CheckedFlag=##class(web.DHCPE.ResultDiagnosis).GetDHCPEStatusFlag("SendAudit",PaadmID)
    .Set lastSendDetail = ##class(web.DHCPE.ResultDiagnosisNew).GetLastSendDetail(PaadmID)
    .s ^CacheTemp(repid,ind)=$lb(PaadmID,PAPMINo,AdmDate,Name,Age,Sex,VIPLevel,VIPDesc,GName,GSStatus,ReMark,CAAuditFlag,CAMainFlag,PostPonedFlag,THPNo,GWFlag,LockUserDesc,RecordDateTime,TAuditDateTime,TCancelLockUser,PostPonedInfo,JYFlag,AIFlag,CheckedFlag,lastSendDetail)
    .s ind=ind+1
    }
    Set qHandle=$lb(0,repid,0)
    Quit $$$OK
    }elseif(PatName'=""){
	    
	
	s RegNoStr=##class(web.DHCPE.PreIADM).GetAllRegNoByName(PatName)

    if (RegNoStr=""){
            Set qHandle=$lb(0,repid,0)
            Quit $$$OK  
        
     }
    for i=1:1:$L(RegNoStr,"^")
    {
	s RegNoIndex=$P(RegNoStr,"^",i)
	s RegNoIndex=$ZCVT(RegNoIndex,"U")
	s PaPatID=$O(^PAPERi("PAPMI_PatNo",RegNoIndex,0))
    s PAPMINo=$P($g(^PAPER(PaPatID,"PAT",1)),"^",1)
    s Name=$P($g(^PAPER(PaPatID,"ALL")),"^",1)
    //体检特殊客户类型
    s SpecialTypeCode=##class(web.DHCPE.SpecialType).GetSpecialType(PAPMINo)
    i SpecialTypeCode'="" s Name=Name_"("_SpecialTypeCode_")"

    s Sex=$P($g(^PAPER(PaPatID,"ALL")),"^",7)
    s:Sex'="" Sex=$P($g(^CT("SEX",Sex)),"^",2)
    b ;555555
    //s Age=##class(web.DHCBillInterface).GetPapmiAge(PaPatID,"")
    s Age=##class(web.DHCPE.DHCPECommon).GetPapmiAge(PaPatID,HospID)
    s (VIPLevel,VIPDesc)=""
    s ArriveFlag=0
    //s LocID=%session.Get("LOGON.CTLOCID")
    s LocID=##class(HS.BL.PECommon).GetDftSessionParam("LOCID")
    s PaadmID=""
    f  s PaadmID=$O(^PAPERdr(PaPatID,"ADM","H",PaadmID),-1) q:PaadmID=""  d
    .s LocFlag=##class(web.DHCPE.PreCommon).GetLocFlag("PAADM",PaadmID)
    .//q:(LocFlag=1)&&($D(^DHCPESetting("DHCPE","DefaultPAADM",LocID)))
    .s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检"),AuditUser="",Status=""
    .s SendAuditStatus=##class(web.DHCPE.ResultDiagnosis).IsCanSendAuditByPAADM(PaadmID)  //可核对 不可核对 已核对
    .q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(SendAuditStatus'=0)
    .q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanntCheck")&&(SendAuditStatus'=1)
    .q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="HadChecked")&&(SendAuditStatus'=2)
    .s ExistFlag= ##class(web.DHCPE.ResultDiagnosis).IsExistSendAuditByPAADM(PaadmID)  //存在核对未通过 1
    .q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(ExistFlag=1)  //可核对过滤核对未通过
    .q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="NoSendAudit")&&(ExistFlag'=1)
    .//s GSStatus=##class(web.DHCPE.ResultDiagnosis).IsAllItemExcByPAADM(PaadmID)  //可初审  不可初审
    .;q:(GSStatus="1")&&(GenStatus'["CanNoGS")&&(GenStatus'="") //过滤不可初审
    
    
    
    .//b ;1231233123
    .i ((SendAuditStatus=2)) s GSStatus=0 
    .i ((SendAuditStatus'=2)) s GSStatus=1  //未粘贴核对不允许主检
    .i GSStatus="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    .i (GSStatus="0") s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检")
    .//i (GSStatus="0")&&(SendAuditStatus="2") s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检")
    .//i (GSStatus="0")&&(SendAuditStatus'="2") s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    .s GSID=##class(web.DHCPE.ResultDiagnosis).GetSSId(PaadmID) 
    .s (TAuditDate,TAuditTime,TAuditDateTime)=""
    .i GSID'="" d
    ..s AuditUser=$P($G(^DHCPEGS(GSID,1)),"^",5)
    ..s Status=$P($G(^DHCPEGS(GSID,1)),"^",9)
    ..i AuditUser'="" d
    ...s TAuditDate=$P($G(^DHCPEGS(GSID,1)),"^",6)
    ...s:TAuditDate'="" TAuditDate=##class(websys.Conversions).DateLogicalToHtml(TAuditDate)
    ...s TAuditTime=$P($G(^DHCPEGS(GSID,1)),"^",7)
    ...s:TAuditTime'="" TAuditTime=##class(websys.Conversions).TimeLogicalToHtml(TAuditTime)
    ...s TAuditDateTime=TAuditDate_" "_TAuditTime
    
    .s CAAuditFlag = 0,CAMainFlag = 0
    .i AuditUser'="" d
    ..s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检")
    ..i ##class(web.DHCPE.CA.Main).GetSignName(2,PaadmID)'="" s CAAuditFlag = 1
    .i Status="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回主检")
    .s MainInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","MainDoctor",PaadmID))
    .s MainUser=$P(MainInfo,"^",1)
    .i MainUser'=""   d
    ..s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审")
    ..i ##class(web.DHCPE.CA.Main).GetSignName(3,PaadmID)'="" s CAMainFlag = 1
    .i Status="2" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回初审")
    .s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    .s LastUser=$P(LastInfo,"^",1)
    .s:LastUser'="" GSStatus="已终审"
    .;q:(MainDoctor="Y")&&(GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未初审"))
    .i (MainDoctor="Y")&&(GSStatus="已主检") s GSStatus="未初审"  
    .i OnlyRead="Y" d
    ..s:SendAuditStatus=0 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可核对")
    ..s:SendAuditStatus=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可核对")
    ..s:SendAuditStatus=2 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已核对")
    ..s:ExistFlag=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"核对不通过")
    
    
    .b ;666666
    .q:(OnlyRead="Y")&&(AuditUser'="")  //粘贴核对过滤已主检
    
    
    
    
    .q:(SuperFlag'="1")&&(OnlyRead="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))&&(GSStatus'="核对不通过")
    .q:(SuperFlag'="1")&&(OnlyRead="Y")&&(GenStatus="SelfNoSendAudit")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))   ////只看自己核对未通过记录
    .q:(GenStatus="SelfNoSendAudit")&&(ExistFlag'=1)
    .s PIADM=$O(^DHCPEIADM(0,"PAADM",PaadmID,0))
    .q:PIADM=""
    .s AllRejectFlag=..AllItemReject(PIADM)
	.q:(AllRejectFlag="Y") //到达之后删除或弃检了所有项目的记录 20250702 qiaoyue
    .s PreIADM=$P(^DHCPEIADM(PIADM),"^",4)
    
    .//第一个为医生界面自动到达\第二个为打印条码自动到达
    .s AutoArrived=$G(^DHCPESetting("DHCPE","AutoArrived",LocID))
    .s AutoArrived=$p(AutoArrived,"^",1)
    .i AutoArrived="Y" d
    ..d:ArriveFlag=0 ##class(web.DHCPE.DHCPEIAdm).IAdmArrived(PreIADM)
    .s ArriveFlag=1
    .q:##class(web.DHCPE.ResultEdit).IsArrivedStatu(PaadmID)="0"
    .s AdmDate=$P(^PAADM(PaadmID),"^",6)
    .;q:(AdmDate<StartDate)||(AdmDate>EndDate)
    .s AdmDate=##class(websys.Conversions).DateLogicalToHtml(AdmDate)
    .;d ##class(web.DHCPE.TransResult).TransMain(PaadmID)
    .s VIPStr=##class(web.DHCPE.PreCommon).GetVIPLevel("PAADM",PaadmID)
    .i VIPStr'="" d
    ..s VIPLevel=$p(VIPStr,"^",1)
    ..s VIPDesc=$p(VIPStr,"^",2)
    .;q:(VIP'="")&&(VIP'=VIPLevel)
    .q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    .;q:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") //总检界面不显示单项体检记录
    .s:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    .s PGADMDR=$p($g(^DHCPEPreIADM(PreIADM)),"^",2) 
    .s THPNo= $p($g(^DHCPEPreIADM(PreIADM)),"^",27)
    .q:(THPNo="0100003000")||(THPNo="0300016870")||(THPNo="0300036410")||(THPNo="0300036919")||(THPNo="0300042669")||(THPNo="0300042646")||(THPNo="0300072500")
    .S GName=""
    .i ""'=PGADMDR  d
    ..s GBIDR=$p($g(^DHCPEPreGADM(PGADMDR)),"^",1)
    ..i ""'=GBIDR s GName=$p($g(^DHCPEPreGBI(GBIDR)),"^",2)
    .i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s ReMark=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"有高危")
    .s PostPonedFlag=##class(web.DHCPE.OrderPostPoned).GetHadDelayItems(PaadmID)
    .s PostPonedInfo=PostPonedFlag
    .i PostPonedFlag="" s PostPonedFlag="N"
    .e  s PostPonedFlag="Y"
    
    
    .s GWFlag=""
    .i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s GWFlag="1"
    
    .s LockFlag=0
    .s LockUserDesc=""
    .s LockUser=""
    .i $d(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID)) d
    ..s LockFlag=1
    ..s LockUser=$p(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID),"^",1)
    ..s LockUserDesc=$p($g(^SSU("SSUSR",LockUser)),"^",2)
    
    
    ./***翻译 start***/
    .s Sex=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.CTSex",Sex,"CTSEXDesc","cls")
    .s VIPDesc=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.DHCPEVIPLevel",VIPDesc,"VLDesc","cls")
    ./***翻译 end***/
    .;;第一次获取结果时间
    .s RecordDate="",RecordTime="",RecordDateTime=""
    .s RecordID=$o(^User.DHCPEAdmRecordManagerI("AdmTypeIndex",PreIADM,"UPDATESTATIONS",0))
    .i RecordID'="" d
    ..s RecordDate=$LG(^User.DHCPEAdmRecordManagerD(RecordID),3)
    ..s:RecordDate'="" RecordDate=##class(websys.Conversions).DateLogicalToHtml(RecordDate)
    ..s RecordTime=$LG(^User.DHCPEAdmRecordManagerD(RecordID),5)
    ..s:RecordTime'="" RecordTime=##class(websys.Conversions).TimeLogicalToHtml(RecordTime)
    ..s RecordDateTime=RecordDate_" "_RecordTime
    .i GSStatus="已主检" s RecordDateTime=""
    .s TCancelLockUser=""
    .i $d(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID)) d
    ..s sort=+$O(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,""),-1)
    ..s CancelLockInfo=$g(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,sort))
    ..s CancelUserDR=$p(CancelLockInfo,"^",1)
    ..s:CancelUserDR'="" TCancelLockUser=$p(^SSU("SSUSR",CancelUserDR),"^",2)
    .q:(HaveLock="CancelLock")&&(TCancelLockUser="")
    .s JYFlag=##class(web.DHCPE.ResultDiagnosis).GetGSJYFlag(PaadmID)
    .s AIFlag="N"
    .s RPTID=$O(^DHCPERPT(0,"IADM",PIADM,""))
    .i RPTID'="" d
    ..s RPTAISendInfo=$P($G(^DHCPERPT(RPTID)),"^",20)
    ..i RPTAISendInfo'="" s AIFlag="Y"
    .Set CheckedFlag=##class(web.DHCPE.ResultDiagnosis).GetDHCPEStatusFlag("SendAudit",PaadmID)
    .Set lastSendDetail = ##class(web.DHCPE.ResultDiagnosisNew).GetLastSendDetail(PaadmID)
    .s ^CacheTemp(repid,ind)=$lb(PaadmID,PAPMINo,AdmDate,Name,Age,Sex,VIPLevel,VIPDesc,GName,GSStatus,ReMark,CAAuditFlag,CAMainFlag,PostPonedFlag,THPNo,GWFlag,LockUserDesc,RecordDateTime,TAuditDateTime,TCancelLockUser,PostPonedInfo,JYFlag,AIFlag,CheckedFlag,lastSendDetail)
    .s ind=ind+1
    }
    Set qHandle=$lb(0,repid,0)
    Quit $$$OK
	}elseif(DistributionDate'="")
	{
        
		s DistributionDate=##class(websys.Conversions).DateHtmlToLogical(DistributionDate)
		i MainDoctor="N" s DistributionType="AR"
		i MainDoctor="Y" s DistributionType="MAR"
		i MainDoctor="Z" s DistributionType="ZAR"
		s time=""
	    f  s time=$O(^User.DHCPEWorkDistributionI("WDDocUpdateDateTimeIndex",DistributionType,CurUserID,DistributionDate,time)) q:time=""  d
		.s DistributionID=""
	    .f  s DistributionID=$O(^User.DHCPEWorkDistributionI("WDDocUpdateDateTimeIndex",DistributionType,CurUserID,DistributionDate,time,DistributionID)) q:DistributionID=""  d   
        ..s paadm=$lg(^User.DHCPEWorkDistributionD(DistributionID),2)
		..s IADM=$O(^DHCPEIADM(0,"PAADM",paadm,0))
		..s PIADM=$p($g(^DHCPEIADM(IADM)),"^",4)
		..s Status=$p($g(^DHCPEIADM(IADM)),"^",8)
    	..q:Status'="ARRIVED"
    	
    	
    	..s LocFlag=##class(web.DHCPE.PreCommon).GetLocFlag("PreADM",PIADM,LocID)
    		..q:LocFlag="1" 
    		..b:paadm="80187610"
    		..s PGADMDR=$p($g(^DHCPEPreIADM(PIADM)),"^",2) 
    		..s IGSort=1
    		..s:PGADMDR'="" IGSort=2
  
    		..q:(+Group'="0")&&(Group'=PGADMDR)
    		..q:((Group="ALLG")&&(PGADMDR=""))
    		..q:((Group="ALLI")&&(PGADMDR'=""))
    		..S GName=""
    		..i ""'=PGADMDR  d
    		...s GBIDR=$p($g(^DHCPEPreGADM(PGADMDR)),"^",1)
    		...i ""'=GBIDR s GName=$p($g(^DHCPEPreGBI(GBIDR)),"^",2)

    	
    		..s PBID=$p($g(^DHCPEPreIADM(PIADM)),"^",1)
    		..s THPNo= $p($g(^DHCPEPreIADM(PIADM)),"^",27)
    		..s VIPLevel=+##class(web.DHCPE.PreCommon).GetVIPLevel("Pre",PIADM)
    		..q:(VIP'="")&&(VIP'=VIPLevel)
    		..q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    		..;q:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") //总检界面不显示单项体检记录
    		..s:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    		..s PAPMINo=$p($g(^DHCPEPreIBI(PBID)),"^",1)
    		..s Name=$p($g(^DHCPEPreIBI(PBID)),"^",2)
    		..q:(PatName'="")&&(Name'[PatName)
    		..s PaadmID=##class(web.DHCPE.DHCPEIAdm).GetPAADMByPADM(PIADM) 
    	
           
    		.. //体检特殊客户类型
    		..s SpecialTypeCode=##class(web.DHCPE.SpecialType).GetSpecialType(PAPMINo)
   			..i SpecialTypeCode'="" s Name=Name_"("_SpecialTypeCode_")"
			..s GSStatus=1,AuditUser="",Status=""
			..s (TAuditDate,TAuditTime,TAuditDateTime)=""
			..s GSID= ##class(web.DHCPE.ResultDiagnosis).GetSSId(PaadmID) 
    		..i GSID'="" d
    		...s AuditUser=$P($G(^DHCPEGS(GSID,1)),"^",5)
    		...s Status=$P($G(^DHCPEGS(GSID,1)),"^",9)
    		...i AuditUser'="" d
   			....s TAuditDate=$P($G(^DHCPEGS(GSID,1)),"^",6)
    		....s:TAuditDate'="" TAuditDate=##class(websys.Conversions).DateLogicalToHtml(TAuditDate)
    		....s TAuditTime=$P($G(^DHCPEGS(GSID,1)),"^",7)
	    	....s:TAuditTime'="" TAuditTime=##class(websys.Conversions).TimeLogicalToHtml(TAuditTime)
	    	....s TAuditDateTime=TAuditDate_" "_TAuditTime
	    	..s MainInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","MainDoctor",PaadmID))
	    	..s MainUser=$P(MainInfo,"^",1)
	    	..s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    		..s LastUser=$P(LastInfo,"^",1)
	    	..q:(MDocName'="")&&(MDocName'=MainUser)
	    	..q:(OnlyRead="Y")&&(AuditUser'="")  //粘贴核对过滤已主检
	    	..q:(GenStatus="HadMain")&&(MainDoctor="Z")&&((MainUser="")||(LastUser'="")) //终审界面查询已初审的 
    		..s SendAuditStatus= ##class(web.DHCPE.ResultDiagnosis).IsCanSendAuditByPAADM(PaadmID)  //可核对 不可核对 已核对
    		..q:(MainDoctor'="")&&(SendAuditStatus'=2)&(HospID'="2") //三级审核 都必须核对通过
    	
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(SendAuditStatus'=0)
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanntCheck")&&(SendAuditStatus'=1)
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="HadChecked")&&(SendAuditStatus'=2)
    		..s ExistFlag= ##class(web.DHCPE.ResultDiagnosis).IsExistSendAuditByPAADM(PaadmID)  //存在核对未通过1  不存在为0
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(ExistFlag=1)  //可核对过滤核对未通过
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="NoSendAudit")&&(ExistFlag'=1)
    	
    	
    		..i ((SendAuditStatus=2)) s GSStatus=0  //未粘贴核对不允许主检
    		..q:(GSStatus="1")&&(GenStatus'["CanNoGS")&&(GenStatus'="")&&(OnlyRead'="Y") //过滤不可初审
    		..i GSStatus="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    		..i GSStatus="0" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检")
    		..s CAAuditFlag = 0,CAMainFlag = 0
	    	..i AuditUser'=""  d
	    	...s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检")
	    	...i ##class(web.DHCPE.CA.Main).GetSignName(2,PaadmID)'="" s CAAuditFlag = 1 
	    	..i Status="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回主检")
	  		..i MainUser'=""  d
    		...s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审")
    		...i ##class(web.DHCPE.CA.Main).GetSignName(3,PaadmID)'="" s CAMainFlag = 1
    		..i Status="2" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回初审")
    
    		..s:LastUser'="" GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已终审")
    		..i OnlyRead="Y" d
    		...s:SendAuditStatus=0 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可核对")
    		...s:SendAuditStatus=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可核对")
    		...s:SendAuditStatus=2 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已核对")
    		...s:ExistFlag=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"核对不通过")
    		..q:(MainDoctor="Y")&&(GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检"))
    		..;i (MainDoctor="Y")&&(GSStatus="已初审") s GSStatus="未复审"
    		..;q:(GenStatus="NoGS")&&(GSStatus'=##class(websys.Translation).Get("dhcpenewdiagnosis.hisui.csp","未初审",langId))
    		..q:(GenStatus="CanGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检"))
    		..q:(GenStatus="CanNoGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检"))
    		..q:(GenStatus="HadGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检"))
    		..q:(GenStatus="HadMain")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审"))
    		..q:(GenStatus="HadLast")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已终审"))
    		..q:(GenStatus="HadMainBack")&&(Status'="1")
    		..q:(GenStatus="HadLastBack")&&(Status'="2")
    		..q:(SuperFlag'="1")&&(OnlyRead="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))&&(GSStatus'="核对不通过")    
    		..q:(SuperFlag'="1")&&(OnlyRead="Y")&&(GenStatus="SelfNoSendAudit")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))   ////只看自己核对未通过记录
    		..q:(GenStatus="SelfNoSendAudit")&&(ExistFlag'=1)
    		..//b ;GSStatus	
    		..s PaPatID=$P($g(^PAADM(PaadmID)),"^",1)
    		..s Sex=$P($g(^PAPER(PaPatID,"ALL")),"^",7)
    		..s:Sex'="" Sex=$P($g(^CT("SEX",Sex)),"^",2)
    		..//s Age=##class(web.DHCBillInterface).GetPapmiAge(PaPatID,"")
    		..s Age= ##class(web.DHCPE.DHCPECommon).GetPapmiAge(PaPatID,HospID)
    		..s (VIPLevel,VIPDesc)=""
    		..s AdmDate=$P($g(^PAADM(PaadmID)),"^",6)
    		..s AdmDate=##class(websys.Conversions).DateLogicalToHtml(AdmDate)
    		..s VIPStr=##class(web.DHCPE.PreCommon).GetVIPLevel("PAADM",PaadmID)
    		..i VIPStr'="" d
    		...s VIPLevel=$p(VIPStr,"^",1)
    		...s VIPDesc=$p(VIPStr,"^",2)
    		..q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    		..s ReMark=""
    		..i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s ReMark=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"有高危")
    		..s PostPonedFlag=##class(web.DHCPE.OrderPostPoned).GetHadDelayItems(PaadmID)
    		..s PostPonedInfo=PostPonedFlag
    		..i PostPonedFlag="" s PostPonedFlag="N"
    		..e  s PostPonedFlag="Y"
    
    		..s GWFlag=""
    		..i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s GWFlag="1"

   
    
    		../***翻译 start***/
    		..s Sex=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.CTSex",Sex,"CTSEXDesc","cls")
    		..s VIPDesc=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.DHCPEVIPLevel",VIPDesc,"VLDesc","cls")
    		..s VIPSort=2
    		..s:(VIPDesc["VIP")||(VIPDesc["贵宾")||(VIPDesc["干部") VIPSort=1
    		../***翻译 end***/
    		..s JYSort="9999999"
    		..s JYFlag=##class(web.DHCPE.ResultDiagnosis).GetGSJYFlag(PaadmID)
    		..i JYFlag=1 s JYSort=1
    		..s LockFlag=0
    		..s LockUserDesc=""
    		..s LockUser=""
    		..i $d(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID)) d
    		...s LockFlag=1
    		...s LockUser=$p(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID),"^",1)
    		...s LockUserDesc=$p($g(^SSU("SSUSR",LockUser)),"^",2)
    
    		..s LockSort="9999999"
    		..i LockFlag="1" s LockSort="3"
    		..i CurUserID=LockUser s LockSort="2"
    
    		..q:(HaveLock="HaveLock")&&(LockFlag=0)
    		..q:(DocName'="")&&(LockUser'=DocName)
    		..;;第一次获取结果时间
    		..s RecordDate="",RecordTime="",RecordDateTime="",RecordUser="",RecordSort="Z"
    		..s RecordID=$o(^User.DHCPEAdmRecordManagerI("AdmTypeIndex",PIADM,"UPDATESTATIONS",0))
    		..i RecordID'="" d
    		...s RecordDate=$LG(^User.DHCPEAdmRecordManagerD(RecordID),3)
    		...s:RecordDate'="" RecordDate=##class(websys.Conversions).DateLogicalToHtml(RecordDate)
    		...s RecordTime=$LG(^User.DHCPEAdmRecordManagerD(RecordID),5)
    		...s:RecordTime'="" RecordTime=##class(websys.Conversions).TimeLogicalToHtml(RecordTime)
    		...s RecordDateTime=RecordDate_" "_RecordTime
    		...s RecordUserDR=$LG(^User.DHCPEAdmRecordManagerD(RecordID),7)
    		...s:RecordUserDR'="" RecordUser=$p($g(^SSU("SSUSR",RecordUserDR)),"^",2)
    		...i RecordUser=LoginDocName  s RecordSort="A"_RecordUserDR
    		...e  s RecordSort="Z"_RecordUserDR
    		..i GSStatus="已主检" s RecordDateTime=""
    		..s TCancelLockUser="",CancelSort=""
    		..i $d(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID)) d
    		...s sort=+$O(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,""),-1)
    		...s CancelLockInfo=$g(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,sort))
    		...s CancelUserDR=$p(CancelLockInfo,"^",1)
    		...s:CancelUserDR'="" TCancelLockUser=$p(^SSU("SSUSR",CancelUserDR),"^",2)
    		...;s:LockUser="" CancelSort="Z99"
    		...s CancelSort="Z99"
    		..q:(HaveLock="CancelLock")&&((TCancelLockUser="")||(LockFlag=1))
    		..;;;排序规则：急要标识-》本人获取结果队列-》本人锁定队列-》A医生获取结果队列-》A医生锁定队列-》到达队列-》撤销锁定队列
    
    
    		..i (MainDoctor="Y")||(MainDoctor="Z") s RecordSort=$zdh(AdmDate,3)
    
    		..s Sort=JYSort_"$"_RecordSort_"$"_LockSort_"$"_CancelSort
    		..;  粘贴核对界面排序：急要最优先，再先个人(先 Vip 后健康,均日期由远至近）；后团队(先 Vip 后健康,均日期由远至近
    		..s:OnlyRead="Y" Sort=JYSort_"$"_IGSort_"$"_VIPSort
    		..b:PaadmID=80017828
    		..//高危等级
			..s HighRiskLevel="无"
			..i $d(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID))=0 d
			... s HighRiskLevel="无"
			..e  d
			... &SQL(SELECT max(HRR_Level) into :HighRiskLevel FROM sqluser.DHC_PE_HighRiskResult WHERE HRR_PAAdm=:PaadmID)
			... s HighRiskLevel=$p($g(^DHCPEEDC(HighRiskLevel)),"^",2)
    		..q:(IsZJ="1")&&(HighRiskLevel="无")
			..q:(IsZJ="0")&&(HighRiskLevel'="无")
    		..s AllRejectFlag=..AllItemReject(IADM)
			..q:(AllRejectFlag="Y") //到达之后删除或弃检了所有项目的记录 20250702 qiaoyue
    		..s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    		..i LastInfo'="" d
    		...s lastDate=$p(LastInfo,"^",2)
    		...s lastTime=$p(LastInfo,"^",3)
    		...i GenStatus="HadLast" s Sort=lastDate_"$"_lastTime
    		..s AIFlag="N"
    		..s RPTID=$O(^DHCPERPT(0,"IADM",IADM,""))
    		..i RPTID'="" d
    		...s RPTAISendInfo=$P($G(^DHCPERPT(RPTID)),"^",20)
    		...i RPTAISendInfo'="" s AIFlag="Y"
    		..Set CheckedFlag=##class(web.DHCPE.ResultDiagnosis).GetDHCPEStatusFlag("SendAudit",PaadmID)
    		..Set lastSendDetail = ##class(web.DHCPE.ResultDiagnosisNew).GetLastSendDetail(PaadmID)
    		..s ^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,AdmDate,PaadmID)=PaadmID_"^"_PAPMINo_"^"_AdmDate_"^"_Name_"^"_Age_"^"_Sex_"^"_VIPLevel_"^"_VIPDesc_"^"_GName_"^"_GSStatus_"^"_ReMark_"^"_CAAuditFlag_"^"_CAMainFlag_"^"_PostPonedFlag_"^"_THPNo_"^"_GWFlag_"^"_LockUserDesc_"^"_RecordDateTime_"^"_TAuditDateTime_"^"_TCancelLockUser_"^"_PostPonedInfo_"^"_JYFlag_"^"_AIFlag_"^"_CheckedFlag_"^"_lastSendDetail
   			
   			
   			s Sort="" 
    		f  s Sort=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort)) q:Sort=""  d
    		.s SortAdmDate=""
    		.f  s SortAdmDate=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate)) q:SortAdmDate=""  d
    		..s PaadmID=""
    		..f  s PaadmID=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate,PaadmID)) q:PaadmID=""  d
    		...s SortInfo=$g(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate,PaadmID))
    		...s ^CacheTemp(repid,ind)=$lb($p(SortInfo,"^",1),$p(SortInfo,"^",2),$p(SortInfo,"^",3),$p(SortInfo,"^",4),$p(SortInfo,"^",5),$p(SortInfo,"^",6),$p(SortInfo,"^",7),$p(SortInfo,"^",8),$p(SortInfo,"^",9),$p(SortInfo,"^",10),$p(SortInfo,"^",11),$p(SortInfo,"^",12),$p(SortInfo,"^",13),$p(SortInfo,"^",14),$p(SortInfo,"^",15),$p(SortInfo,"^",16),$p(SortInfo,"^",17),$p(SortInfo,"^",18),$p(SortInfo,"^",19),$p(SortInfo,"^",20),$p(SortInfo,"^",21),$p(SortInfo,"^",22),$p(SortInfo,"^",23),$P(SortInfo,"^",24),$P(SortInfo,"^",25))
    
    		...s ind=ind+1
    
    		Set qHandle=$lb(0,repid,0)
   			Quit $$$OK
    	
		
		}elseif(AuditDate'="")
	{
		s AuditDate=##class(websys.Conversions).DateHtmlToLogical(AuditDate)
		i MainDoctor="N"
		{
			s time=""
			f  s time=$O(^DHCPEGS(0,"AuditDateTime",AuditDate,time))  q:time=""  d
			.s GSID=""
			.f  s GSID=$O(^DHCPEGS(0,"AuditDateTime",AuditDate,time,GSID))  q:GSID=""  d
			..s AuditUser=$P($G(^DHCPEGS(GSID,1)),"^",5)
			..q:(SuperFlag'="1")&&(AuditUser'=CurUserID)  //过滤非本人审核的记录
			..s IADM=$P($G(^DHCPEGS(GSID,1)),"^",1)
			..s PIADM=$p($g(^DHCPEIADM(IADM)),"^",4)
			..s Status=$p($g(^DHCPEIADM(IADM)),"^",8)
    		..q:Status'="ARRIVED"
    		..s LocFlag=##class(web.DHCPE.PreCommon).GetLocFlag("PreADM",PIADM)
    		..q:LocFlag="1" 
    		..s PGADMDR=$p($g(^DHCPEPreIADM(PIADM)),"^",2) 
    		..s IGSort=1
    		..s:PGADMDR'="" IGSort=2
  
    		..q:(+Group'="0")&&(Group'=PGADMDR)
    		..q:((Group="ALLG")&&(PGADMDR=""))
    		..q:((Group="ALLI")&&(PGADMDR'=""))
    		..S GName=""
    		..i ""'=PGADMDR  d
    		...s GBIDR=$p($g(^DHCPEPreGADM(PGADMDR)),"^",1)
    		...i ""'=GBIDR s GName=$p($g(^DHCPEPreGBI(GBIDR)),"^",2)

    	
    		..s PBID=$p($g(^DHCPEPreIADM(PIADM)),"^",1)
    		..s THPNo= $p($g(^DHCPEPreIADM(PIADM)),"^",27)
    		..b:THPNo="0100005090"
   			..q:THPNo="0100003000"
    		..s VIPLevel=+##class(web.DHCPE.PreCommon).GetVIPLevel("Pre",PIADM)
    		..q:(VIP'="")&&(VIP'=VIPLevel)
    		..q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    		..;q:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") //总检界面不显示单项体检记录
    		..s:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    		..s PAPMINo=$p($g(^DHCPEPreIBI(PBID)),"^",1)
    		..s Name=$p($g(^DHCPEPreIBI(PBID)),"^",2)
    		..q:(PatName'="")&&(Name'[PatName)
    		..s PaadmID=##class(web.DHCPE.DHCPEIAdm).GetPAADMByPADM(PIADM) 
    	
    		..q:(SuperFlag'="1")&&((LocID=293)||(LocID=292))&&(MainDoctor="N")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","AR",CurUserID,PaadmID)))  //主检分配 目前只有温江/本部启用主检分配 20250926 by yl
    		..q:(SuperFlag'="1")&&((LocID=293)||(LocID=292))&&(MainDoctor="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","MAR",CurUserID,PaadmID)))  //初审分配 目前只有温江/本部启用初审分配 20250926 by yl
    		..q:(SuperFlag'="1")&&((LocID=292)||(LocID=15)||(LocID=293))&&(MainDoctor="Z")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","ZAR",CurUserID,PaadmID)))    //终审分配目前只本部不启用
    
        	..q:(CurUserID="21573")&&(MainDoctor="Z")&&($d(^User.DHCPEWorkDistributionI("TypePAADMIndex","ZAR",PaadmID)))  //分配了终审的吴琴琴不显示
        
    		.. //体检特殊客户类型
    		..s SpecialTypeCode=##class(web.DHCPE.SpecialType).GetSpecialType(PAPMINo)
   			..i SpecialTypeCode'="" s Name=Name_"("_SpecialTypeCode_")"
			..s GSStatus=1,AuditUser="",Status=""
			..s (TAuditDate,TAuditTime,TAuditDateTime)=""
			..s GSID= ##class(web.DHCPE.ResultDiagnosis).GetSSId(PaadmID) 
    		..i GSID'="" d
    		...s AuditUser=$P($G(^DHCPEGS(GSID,1)),"^",5)
    		...s Status=$P($G(^DHCPEGS(GSID,1)),"^",9)
    		...i AuditUser'="" d
   			....s TAuditDate=$P($G(^DHCPEGS(GSID,1)),"^",6)
    		....s:TAuditDate'="" TAuditDate=##class(websys.Conversions).DateLogicalToHtml(TAuditDate)
    		....s TAuditTime=$P($G(^DHCPEGS(GSID,1)),"^",7)
	    	....s:TAuditTime'="" TAuditTime=##class(websys.Conversions).TimeLogicalToHtml(TAuditTime)
	    	....s TAuditDateTime=TAuditDate_" "_TAuditTime
	    	..s MainInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","MainDoctor",PaadmID))
	    	..s MainUser=$P(MainInfo,"^",1)
	    	..s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    		..s LastUser=$P(LastInfo,"^",1)
	    	..q:(MDocName'="")&&(MDocName'=MainUser)
	    	..q:(OnlyRead="Y")&&(AuditUser'="")  //粘贴核对过滤已主检
	    	..q:(GenStatus="HadMain")&&(MainDoctor="Z")&&((MainUser="")||(LastUser'="")) //终审界面查询已初审的 
    		..s SendAuditStatus= ##class(web.DHCPE.ResultDiagnosis).IsCanSendAuditByPAADM(PaadmID)  //可核对 不可核对 已核对
    		..q:(MainDoctor'="")&&(SendAuditStatus'=2)&(HospID'="2") //三级审核 都必须核对通过
    	
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(SendAuditStatus'=0)
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanntCheck")&&(SendAuditStatus'=1)
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="HadChecked")&&(SendAuditStatus'=2)
    		..s ExistFlag= ##class(web.DHCPE.ResultDiagnosis).IsExistSendAuditByPAADM(PaadmID)  //存在核对未通过1  不存在为0
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(ExistFlag=1)  //可核对过滤核对未通过
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="NoSendAudit")&&(ExistFlag'=1)
    	
    	
    		..i ((SendAuditStatus=2)) s GSStatus=0  //未粘贴核对不允许主检
    		..q:(GSStatus="1")&&(GenStatus'["CanNoGS")&&(GenStatus'="")&&(OnlyRead'="Y") //过滤不可初审
    		..i GSStatus="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    		..i GSStatus="0" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检")
    		..s CAAuditFlag = 0,CAMainFlag = 0
	    	..i AuditUser'=""  d
	    	...s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检")
	    	...i ##class(web.DHCPE.CA.Main).GetSignName(2,PaadmID)'="" s CAAuditFlag = 1 
	    	..i Status="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回主检")
	  		..i MainUser'=""  d
    		...s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审")
    		...i ##class(web.DHCPE.CA.Main).GetSignName(3,PaadmID)'="" s CAMainFlag = 1
    		..i Status="2" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回初审")
    
    		..s:LastUser'="" GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已终审")
    		..i OnlyRead="Y" d
    		...s:SendAuditStatus=0 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可核对")
    		...s:SendAuditStatus=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可核对")
    		...s:SendAuditStatus=2 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已核对")
    		...s:ExistFlag=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"核对不通过")
    		..q:(MainDoctor="Y")&&(GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检"))
    		..;i (MainDoctor="Y")&&(GSStatus="已初审") s GSStatus="未复审"
    		..;q:(GenStatus="NoGS")&&(GSStatus'=##class(websys.Translation).Get("dhcpenewdiagnosis.hisui.csp","未初审",langId))
    		..q:(GenStatus="CanGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检"))
    		..q:(GenStatus="CanNoGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检"))
    		..q:(GenStatus="HadGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检"))
    		..q:(GenStatus="HadMain")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审"))
    		..q:(GenStatus="HadLast")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已终审"))
    		..q:(GenStatus="HadMainBack")&&(Status'="1")
    		..q:(GenStatus="HadLastBack")&&(Status'="2")
    		..q:(SuperFlag'="1")&&(OnlyRead="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))&&(GSStatus'="核对不通过")    
    		..q:(SuperFlag'="1")&&(OnlyRead="Y")&&(GenStatus="SelfNoSendAudit")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))   ////只看自己核对未通过记录
    		..q:(GenStatus="SelfNoSendAudit")&&(ExistFlag'=1)
    		..//b ;GSStatus	
    		..s PaPatID=$P($g(^PAADM(PaadmID)),"^",1)
    		..s Sex=$P($g(^PAPER(PaPatID,"ALL")),"^",7)
    		..s:Sex'="" Sex=$P($g(^CT("SEX",Sex)),"^",2)
    		..//s Age=##class(web.DHCBillInterface).GetPapmiAge(PaPatID,"")
    		..s Age= ##class(web.DHCPE.DHCPECommon).GetPapmiAge(PaPatID,HospID)
    		..s (VIPLevel,VIPDesc)=""
    		..s AdmDate=$P($g(^PAADM(PaadmID)),"^",6)
    		..s AdmDate=##class(websys.Conversions).DateLogicalToHtml(AdmDate)
    		..s VIPStr=##class(web.DHCPE.PreCommon).GetVIPLevel("PAADM",PaadmID)
    		..i VIPStr'="" d
    		...s VIPLevel=$p(VIPStr,"^",1)
    		...s VIPDesc=$p(VIPStr,"^",2)
    		..q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    		..s ReMark=""
    		..i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s ReMark=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"有高危")
    		..s PostPonedFlag=##class(web.DHCPE.OrderPostPoned).GetHadDelayItems(PaadmID)
    		..s PostPonedInfo=PostPonedFlag
    		..i PostPonedFlag="" s PostPonedFlag="N"
    		..e  s PostPonedFlag="Y"
    
    		..s GWFlag=""
    		..i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s GWFlag="1"

   
    
    		../***翻译 start***/
    		..s Sex=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.CTSex",Sex,"CTSEXDesc","cls")
    		..s VIPDesc=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.DHCPEVIPLevel",VIPDesc,"VLDesc","cls")
    		..s VIPSort=2
    		..s:(VIPDesc["VIP")||(VIPDesc["贵宾")||(VIPDesc["干部") VIPSort=1
    		../***翻译 end***/
    		..s JYSort="9999999"
    		..s JYFlag=##class(web.DHCPE.ResultDiagnosis).GetGSJYFlag(PaadmID)
    		..i JYFlag=1 s JYSort=1
    		..s LockFlag=0
    		..s LockUserDesc=""
    		..s LockUser=""
    		..i $d(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID)) d
    		...s LockFlag=1
    		...s LockUser=$p(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID),"^",1)
    		...s LockUserDesc=$p($g(^SSU("SSUSR",LockUser)),"^",2)
    
    		..s LockSort="9999999"
    		..i LockFlag="1" s LockSort="3"
    		..i CurUserID=LockUser s LockSort="2"
    
    		..q:(HaveLock="HaveLock")&&(LockFlag=0)
    		..q:(DocName'="")&&(LockUser'=DocName)
    		..;;第一次获取结果时间
    		..s RecordDate="",RecordTime="",RecordDateTime="",RecordUser="",RecordSort="Z"
    		..s RecordID=$o(^User.DHCPEAdmRecordManagerI("AdmTypeIndex",PIADM,"UPDATESTATIONS",0))
    		..i RecordID'="" d
    		...s RecordDate=$LG(^User.DHCPEAdmRecordManagerD(RecordID),3)
    		...s:RecordDate'="" RecordDate=##class(websys.Conversions).DateLogicalToHtml(RecordDate)
    		...s RecordTime=$LG(^User.DHCPEAdmRecordManagerD(RecordID),5)
    		...s:RecordTime'="" RecordTime=##class(websys.Conversions).TimeLogicalToHtml(RecordTime)
    		...s RecordDateTime=RecordDate_" "_RecordTime
    		...s RecordUserDR=$LG(^User.DHCPEAdmRecordManagerD(RecordID),7)
    		...s:RecordUserDR'="" RecordUser=$p($g(^SSU("SSUSR",RecordUserDR)),"^",2)
    		...i RecordUser=LoginDocName  s RecordSort="A"_RecordUserDR
    		...e  s RecordSort="Z"_RecordUserDR
    		..i GSStatus="已主检" s RecordDateTime=""
    		..s TCancelLockUser="",CancelSort=""
    		..i $d(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID)) d
    		...s sort=+$O(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,""),-1)
    		...s CancelLockInfo=$g(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,sort))
    		...s CancelUserDR=$p(CancelLockInfo,"^",1)
    		...s:CancelUserDR'="" TCancelLockUser=$p(^SSU("SSUSR",CancelUserDR),"^",2)
    		...;s:LockUser="" CancelSort="Z99"
    		...s CancelSort="Z99"
    		..q:(HaveLock="CancelLock")&&((TCancelLockUser="")||(LockFlag=1))
    		..;;;排序规则：急要标识-》本人获取结果队列-》本人锁定队列-》A医生获取结果队列-》A医生锁定队列-》到达队列-》撤销锁定队列
    
    
    		..i (MainDoctor="Y")||(MainDoctor="Z") s RecordSort=$zdh(AdmDate,3)
    
    		..s Sort=JYSort_"$"_RecordSort_"$"_LockSort_"$"_CancelSort
    		..;  粘贴核对界面排序：急要最优先，再先个人(先 Vip 后健康,均日期由远至近）；后团队(先 Vip 后健康,均日期由远至近
    		..s:OnlyRead="Y" Sort=JYSort_"$"_IGSort_"$"_VIPSort
    		..b:PaadmID=80017828
    		..//高危等级
			..s HighRiskLevel="无"
			..i $d(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID))=0 d
			... s HighRiskLevel="无"
			..e  d
			... &SQL(SELECT max(HRR_Level) into :HighRiskLevel FROM sqluser.DHC_PE_HighRiskResult WHERE HRR_PAAdm=:PaadmID)
			... s HighRiskLevel=$p($g(^DHCPEEDC(HighRiskLevel)),"^",2)
    		..q:(IsZJ="1")&&(HighRiskLevel="无")
			..q:(IsZJ="0")&&(HighRiskLevel'="无")
    		..s AllRejectFlag=..AllItemReject(IADM)
			..q:(AllRejectFlag="Y") //到达之后删除或弃检了所有项目的记录 20250702 qiaoyue
    		..s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    		..i LastInfo'="" d
    		...s lastDate=$p(LastInfo,"^",2)
    		...s lastTime=$p(LastInfo,"^",3)
    		...i GenStatus="HadLast" s Sort=lastDate_"$"_lastTime
    		..s AIFlag="N"
    		..s RPTID=$O(^DHCPERPT(0,"IADM",IADM,""))
    		..i RPTID'="" d
    		...s RPTAISendInfo=$P($G(^DHCPERPT(RPTID)),"^",20)
    		...i RPTAISendInfo'="" s AIFlag="Y"
    		..Set CheckedFlag=##class(web.DHCPE.ResultDiagnosis).GetDHCPEStatusFlag("SendAudit",PaadmID)
    		..Set lastSendDetail = ##class(web.DHCPE.ResultDiagnosisNew).GetLastSendDetail(PaadmID)
    		..s ^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,AdmDate,PaadmID)=PaadmID_"^"_PAPMINo_"^"_AdmDate_"^"_Name_"^"_Age_"^"_Sex_"^"_VIPLevel_"^"_VIPDesc_"^"_GName_"^"_GSStatus_"^"_ReMark_"^"_CAAuditFlag_"^"_CAMainFlag_"^"_PostPonedFlag_"^"_THPNo_"^"_GWFlag_"^"_LockUserDesc_"^"_RecordDateTime_"^"_TAuditDateTime_"^"_TCancelLockUser_"^"_PostPonedInfo_"^"_JYFlag_"^"_AIFlag_"^"_CheckedFlag_"^"_lastSendDetail
   			
   			
   			s Sort="" 
    		f  s Sort=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort)) q:Sort=""  d
    		.s SortAdmDate=""
    		.f  s SortAdmDate=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate)) q:SortAdmDate=""  d
    		..s PaadmID=""
    		..f  s PaadmID=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate,PaadmID)) q:PaadmID=""  d
    		...s SortInfo=$g(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate,PaadmID))
    		...s ^CacheTemp(repid,ind)=$lb($p(SortInfo,"^",1),$p(SortInfo,"^",2),$p(SortInfo,"^",3),$p(SortInfo,"^",4),$p(SortInfo,"^",5),$p(SortInfo,"^",6),$p(SortInfo,"^",7),$p(SortInfo,"^",8),$p(SortInfo,"^",9),$p(SortInfo,"^",10),$p(SortInfo,"^",11),$p(SortInfo,"^",12),$p(SortInfo,"^",13),$p(SortInfo,"^",14),$p(SortInfo,"^",15),$p(SortInfo,"^",16),$p(SortInfo,"^",17),$p(SortInfo,"^",18),$p(SortInfo,"^",19),$p(SortInfo,"^",20),$p(SortInfo,"^",21),$p(SortInfo,"^",22),$p(SortInfo,"^",23),$P(SortInfo,"^",24),$P(SortInfo,"^",25))
    
    		...s ind=ind+1
    
    		Set qHandle=$lb(0,repid,0)
   			Quit $$$OK
		}
		elseif(MainDoctor="Y")
		{
			s time=""
			f  s time=$O(^DHCPEDataEx("DHCPEGeneralSummarize","MainDate",AuditDate,time))  q:time=""  d
			.s PAADM=""
			.f  s PAADM=$O(^DHCPEDataEx("DHCPEGeneralSummarize","MainDate",AuditDate,time,PAADM))  q:PAADM=""  d
			..s IADM=##class(web.DHCPE.DHCPECommon).GetIADMByPaadm(PAADM)
			..s MainUser=$G(^DHCPEDataEx("DHCPEGeneralSummarize","MainDate",AuditDate,time,PAADM))
			..q:(SuperFlag'="1")&&(MainUser'=CurUserID)  //过滤非本人审核的记录
			..s PIADM=$p($g(^DHCPEIADM(IADM)),"^",4)
			..s Status=$p($g(^DHCPEIADM(IADM)),"^",8)
    		..q:Status'="ARRIVED"
    		..s LocFlag=##class(web.DHCPE.PreCommon).GetLocFlag("PreADM",PIADM)
    		..q:LocFlag="1" 
    		..s PGADMDR=$p($g(^DHCPEPreIADM(PIADM)),"^",2) 
    		..s IGSort=1
    		..s:PGADMDR'="" IGSort=2
  
    		..q:(+Group'="0")&&(Group'=PGADMDR)
    		..q:((Group="ALLG")&&(PGADMDR=""))
    		..q:((Group="ALLI")&&(PGADMDR'=""))
    		..S GName=""
    		..i ""'=PGADMDR  d
    		...s GBIDR=$p($g(^DHCPEPreGADM(PGADMDR)),"^",1)
    		...i ""'=GBIDR s GName=$p($g(^DHCPEPreGBI(GBIDR)),"^",2)

    	
    		..s PBID=$p($g(^DHCPEPreIADM(PIADM)),"^",1)
    		..s THPNo= $p($g(^DHCPEPreIADM(PIADM)),"^",27)
    		..b:THPNo="0100005090"
   			..q:THPNo="0100003000"
    		..s VIPLevel=+##class(web.DHCPE.PreCommon).GetVIPLevel("Pre",PIADM)
    		..q:(VIP'="")&&(VIP'=VIPLevel)
    		..q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    		..;q:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") //总检界面不显示单项体检记录
    		..s:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    		..s PAPMINo=$p($g(^DHCPEPreIBI(PBID)),"^",1)
    		..s Name=$p($g(^DHCPEPreIBI(PBID)),"^",2)
    		..q:(PatName'="")&&(Name'[PatName)
    		..s PaadmID=##class(web.DHCPE.DHCPEIAdm).GetPAADMByPADM(PIADM) 
    	
    		..q:(SuperFlag'="1")&&((LocID=293)||(LocID=292))&&(MainDoctor="N")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","AR",CurUserID,PaadmID)))  //主检分配 目前只有温江/本部启用主检分配 20250926 by yl
    		..q:(SuperFlag'="1")&&((LocID=293)||(LocID=292))&&(MainDoctor="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","MAR",CurUserID,PaadmID)))  //初审分配 目前只有温江/本部启用初审分配 20250926 by yl
    		..q:(SuperFlag'="1")&&((LocID=292)||(LocID=15)||(LocID=293))&&(MainDoctor="Z")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","ZAR",CurUserID,PaadmID)))    //终审分配目前只本部不启用
    
        	..q:(CurUserID="21573")&&(MainDoctor="Z")&&($d(^User.DHCPEWorkDistributionI("TypePAADMIndex","ZAR",PaadmID)))  //分配了终审的吴琴琴不显示
        
    		.. //体检特殊客户类型
    		..s SpecialTypeCode=##class(web.DHCPE.SpecialType).GetSpecialType(PAPMINo)
   			..i SpecialTypeCode'="" s Name=Name_"("_SpecialTypeCode_")"
			..s GSStatus=1,AuditUser="",Status=""
			..s (TAuditDate,TAuditTime,TAuditDateTime)=""
			..s GSID= ##class(web.DHCPE.ResultDiagnosis).GetSSId(PaadmID) 
    		..i GSID'="" d
    		...s AuditUser=$P($G(^DHCPEGS(GSID,1)),"^",5)
    		...s Status=$P($G(^DHCPEGS(GSID,1)),"^",9)
    		...i AuditUser'="" d
   			....s TAuditDate=$P($G(^DHCPEGS(GSID,1)),"^",6)
    		....s:TAuditDate'="" TAuditDate=##class(websys.Conversions).DateLogicalToHtml(TAuditDate)
    		....s TAuditTime=$P($G(^DHCPEGS(GSID,1)),"^",7)
	    	....s:TAuditTime'="" TAuditTime=##class(websys.Conversions).TimeLogicalToHtml(TAuditTime)
	    	....s TAuditDateTime=TAuditDate_" "_TAuditTime
	    	..s MainInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","MainDoctor",PaadmID))
	    	..s MainUser=$P(MainInfo,"^",1)
	    	..s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    		..s LastUser=$P(LastInfo,"^",1)
	    	..q:(MDocName'="")&&(MDocName'=MainUser)
	    	..q:(OnlyRead="Y")&&(AuditUser'="")  //粘贴核对过滤已主检
	    	..q:(GenStatus="HadMain")&&(MainDoctor="Z")&&((MainUser="")||(LastUser'="")) //终审界面查询已初审的 
    		..s SendAuditStatus= ##class(web.DHCPE.ResultDiagnosis).IsCanSendAuditByPAADM(PaadmID)  //可核对 不可核对 已核对
    		..q:(MainDoctor'="")&&(SendAuditStatus'=2) //三级审核 都必须核对通过
    	
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(SendAuditStatus'=0)
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanntCheck")&&(SendAuditStatus'=1)
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="HadChecked")&&(SendAuditStatus'=2)
    		..s ExistFlag= ##class(web.DHCPE.ResultDiagnosis).IsExistSendAuditByPAADM(PaadmID)  //存在核对未通过1  不存在为0
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(ExistFlag=1)  //可核对过滤核对未通过
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="NoSendAudit")&&(ExistFlag'=1)
    	
    	
    		..i ((SendAuditStatus=2)) s GSStatus=0  //未粘贴核对不允许主检
    		..q:(GSStatus="1")&&(GenStatus'["CanNoGS")&&(GenStatus'="")&&(OnlyRead'="Y") //过滤不可初审
    		..i GSStatus="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    		..i GSStatus="0" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检")
    		..s CAAuditFlag = 0,CAMainFlag = 0
	    	..i AuditUser'=""  d
	    	...s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检")
	    	...i ##class(web.DHCPE.CA.Main).GetSignName(2,PaadmID)'="" s CAAuditFlag = 1 
	    	..i Status="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回主检")
	  		..i MainUser'=""  d
    		...s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审")
    		...i ##class(web.DHCPE.CA.Main).GetSignName(3,PaadmID)'="" s CAMainFlag = 1
    		..i Status="2" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回初审")
    
    		..s:LastUser'="" GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已终审")
    		..i OnlyRead="Y" d
    		...s:SendAuditStatus=0 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可核对")
    		...s:SendAuditStatus=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可核对")
    		...s:SendAuditStatus=2 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已核对")
    		...s:ExistFlag=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"核对不通过")
    		..q:(MainDoctor="Y")&&(GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检"))
    		..;i (MainDoctor="Y")&&(GSStatus="已初审") s GSStatus="未复审"
    		..;q:(GenStatus="NoGS")&&(GSStatus'=##class(websys.Translation).Get("dhcpenewdiagnosis.hisui.csp","未初审",langId))
    		..q:(GenStatus="CanGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检"))
    		..q:(GenStatus="CanNoGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检"))
    		..q:(GenStatus="HadGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检"))
    		..q:(GenStatus="HadMain")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审"))
    		..q:(GenStatus="HadLast")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已终审"))
    		..q:(GenStatus="HadMainBack")&&(Status'="1")
    		..q:(GenStatus="HadLastBack")&&(Status'="2")
    		..q:(SuperFlag'="1")&&(OnlyRead="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))&&(GSStatus'="核对不通过")    
    		..q:(SuperFlag'="1")&&(OnlyRead="Y")&&(GenStatus="SelfNoSendAudit")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))   ////只看自己核对未通过记录
    		..q:(GenStatus="SelfNoSendAudit")&&(ExistFlag'=1)
    		..//b ;GSStatus	
    		..s PaPatID=$P($g(^PAADM(PaadmID)),"^",1)
    		..s Sex=$P($g(^PAPER(PaPatID,"ALL")),"^",7)
    		..s:Sex'="" Sex=$P($g(^CT("SEX",Sex)),"^",2)
    		..//s Age=##class(web.DHCBillInterface).GetPapmiAge(PaPatID,"")
    		..s Age= ##class(web.DHCPE.DHCPECommon).GetPapmiAge(PaPatID,HospID)
    		..s (VIPLevel,VIPDesc)=""
    		..s AdmDate=$P($g(^PAADM(PaadmID)),"^",6)
    		..s AdmDate=##class(websys.Conversions).DateLogicalToHtml(AdmDate)
    		..s VIPStr=##class(web.DHCPE.PreCommon).GetVIPLevel("PAADM",PaadmID)
    		..i VIPStr'="" d
    		...s VIPLevel=$p(VIPStr,"^",1)
    		...s VIPDesc=$p(VIPStr,"^",2)
    		..q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    		..s ReMark=""
    		..i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s ReMark=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"有高危")
    		..s PostPonedFlag=##class(web.DHCPE.OrderPostPoned).GetHadDelayItems(PaadmID)
    		..s PostPonedInfo=PostPonedFlag
    		..i PostPonedFlag="" s PostPonedFlag="N"
    		..e  s PostPonedFlag="Y"
    
    		..s GWFlag=""
    		..i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s GWFlag="1"

   
    
    		../***翻译 start***/
    		..s Sex=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.CTSex",Sex,"CTSEXDesc","cls")
    		..s VIPDesc=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.DHCPEVIPLevel",VIPDesc,"VLDesc","cls")
    		..s VIPSort=2
    		..s:(VIPDesc["VIP")||(VIPDesc["贵宾")||(VIPDesc["干部") VIPSort=1
    		../***翻译 end***/
    		..s JYSort="9999999"
    		..s JYFlag=##class(web.DHCPE.ResultDiagnosis).GetGSJYFlag(PaadmID)
    		..i JYFlag=1 s JYSort=1
    		..s LockFlag=0
    		..s LockUserDesc=""
    		..s LockUser=""
    		..i $d(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID)) d
    		...s LockFlag=1
    		...s LockUser=$p(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID),"^",1)
    		...s LockUserDesc=$p($g(^SSU("SSUSR",LockUser)),"^",2)
    
    		..s LockSort="9999999"
    		..i LockFlag="1" s LockSort="3"
    		..i CurUserID=LockUser s LockSort="2"
    
    		..q:(HaveLock="HaveLock")&&(LockFlag=0)
    		..q:(DocName'="")&&(LockUser'=DocName)
    		..;;第一次获取结果时间
    		..s RecordDate="",RecordTime="",RecordDateTime="",RecordUser="",RecordSort="Z"
    		..s RecordID=$o(^User.DHCPEAdmRecordManagerI("AdmTypeIndex",PIADM,"UPDATESTATIONS",0))
    		..i RecordID'="" d
    		...s RecordDate=$LG(^User.DHCPEAdmRecordManagerD(RecordID),3)
    		...s:RecordDate'="" RecordDate=##class(websys.Conversions).DateLogicalToHtml(RecordDate)
    		...s RecordTime=$LG(^User.DHCPEAdmRecordManagerD(RecordID),5)
    		...s:RecordTime'="" RecordTime=##class(websys.Conversions).TimeLogicalToHtml(RecordTime)
    		...s RecordDateTime=RecordDate_" "_RecordTime
    		...s RecordUserDR=$LG(^User.DHCPEAdmRecordManagerD(RecordID),7)
    		...s:RecordUserDR'="" RecordUser=$p($g(^SSU("SSUSR",RecordUserDR)),"^",2)
    		...i RecordUser=LoginDocName  s RecordSort="A"_RecordUserDR
    		...e  s RecordSort="Z"_RecordUserDR
    		..i GSStatus="已主检" s RecordDateTime=""
    		..s TCancelLockUser="",CancelSort=""
    		..i $d(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID)) d
    		...s sort=+$O(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,""),-1)
    		...s CancelLockInfo=$g(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,sort))
    		...s CancelUserDR=$p(CancelLockInfo,"^",1)
    		...s:CancelUserDR'="" TCancelLockUser=$p(^SSU("SSUSR",CancelUserDR),"^",2)
    		...;s:LockUser="" CancelSort="Z99"
    		...s CancelSort="Z99"
    		..q:(HaveLock="CancelLock")&&((TCancelLockUser="")||(LockFlag=1))
    		..;;;排序规则：急要标识-》本人获取结果队列-》本人锁定队列-》A医生获取结果队列-》A医生锁定队列-》到达队列-》撤销锁定队列
    
    
    		..i (MainDoctor="Y")||(MainDoctor="Z") s RecordSort=$zdh(AdmDate,3)
    
    		..s Sort=JYSort_"$"_RecordSort_"$"_LockSort_"$"_CancelSort
    		..;  粘贴核对界面排序：急要最优先，再先个人(先 Vip 后健康,均日期由远至近）；后团队(先 Vip 后健康,均日期由远至近
    		..s:OnlyRead="Y" Sort=JYSort_"$"_IGSort_"$"_VIPSort
    		..b:PaadmID=80017828
    		..//高危等级
			..s HighRiskLevel="无"
			..i $d(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID))=0 d
			... s HighRiskLevel="无"
			..e  d
			... &SQL(SELECT max(HRR_Level) into :HighRiskLevel FROM sqluser.DHC_PE_HighRiskResult WHERE HRR_PAAdm=:PaadmID)
			... s HighRiskLevel=$p($g(^DHCPEEDC(HighRiskLevel)),"^",2)
    		..q:(IsZJ="1")&&(HighRiskLevel="无")
			..q:(IsZJ="0")&&(HighRiskLevel'="无")
    		..s AllRejectFlag=..AllItemReject(IADM)
			..q:(AllRejectFlag="Y") //到达之后删除或弃检了所有项目的记录 20250702 qiaoyue
    		..s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    		..i LastInfo'="" d
    		...s lastDate=$p(LastInfo,"^",2)
    		...s lastTime=$p(LastInfo,"^",3)
    		...i GenStatus="HadLast" s Sort=lastDate_"$"_lastTime
    		..s AIFlag="N"
    		..s RPTID=$O(^DHCPERPT(0,"IADM",IADM,""))
    		..i RPTID'="" d
    		...s RPTAISendInfo=$P($G(^DHCPERPT(RPTID)),"^",20)
    		...i RPTAISendInfo'="" s AIFlag="Y"
    		..Set CheckedFlag=##class(web.DHCPE.ResultDiagnosis).GetDHCPEStatusFlag("SendAudit",PaadmID)
    		..Set lastSendDetail = ##class(web.DHCPE.ResultDiagnosisNew).GetLastSendDetail(PaadmID)
    		..s ^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,AdmDate,PaadmID)=PaadmID_"^"_PAPMINo_"^"_AdmDate_"^"_Name_"^"_Age_"^"_Sex_"^"_VIPLevel_"^"_VIPDesc_"^"_GName_"^"_GSStatus_"^"_ReMark_"^"_CAAuditFlag_"^"_CAMainFlag_"^"_PostPonedFlag_"^"_THPNo_"^"_GWFlag_"^"_LockUserDesc_"^"_RecordDateTime_"^"_TAuditDateTime_"^"_TCancelLockUser_"^"_PostPonedInfo_"^"_JYFlag_"^"_AIFlag_"^"_CheckedFlag_"^"_lastSendDetail
   			
   			
   			s Sort="" 
    		f  s Sort=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort)) q:Sort=""  d
    		.s SortAdmDate=""
    		.f  s SortAdmDate=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate)) q:SortAdmDate=""  d
    		..s PaadmID=""
    		..f  s PaadmID=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate,PaadmID)) q:PaadmID=""  d
    		...s SortInfo=$g(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate,PaadmID))
    		...s ^CacheTemp(repid,ind)=$lb($p(SortInfo,"^",1),$p(SortInfo,"^",2),$p(SortInfo,"^",3),$p(SortInfo,"^",4),$p(SortInfo,"^",5),$p(SortInfo,"^",6),$p(SortInfo,"^",7),$p(SortInfo,"^",8),$p(SortInfo,"^",9),$p(SortInfo,"^",10),$p(SortInfo,"^",11),$p(SortInfo,"^",12),$p(SortInfo,"^",13),$p(SortInfo,"^",14),$p(SortInfo,"^",15),$p(SortInfo,"^",16),$p(SortInfo,"^",17),$p(SortInfo,"^",18),$p(SortInfo,"^",19),$p(SortInfo,"^",20),$p(SortInfo,"^",21),$p(SortInfo,"^",22),$p(SortInfo,"^",23),$P(SortInfo,"^",24),$P(SortInfo,"^",25))
    
    		...s ind=ind+1
    
    		Set qHandle=$lb(0,repid,0)
   			Quit $$$OK
		}
		elseif(MainDoctor="Z")
		{
			
			s time=""
			f  s time=$O(^DHCPEDataEx("DHCPEGeneralSummarize","LastDate",AuditDate,time))  q:time=""  d
			.s PAADM=""
			.f  s PAADM=$O(^DHCPEDataEx("DHCPEGeneralSummarize","LastDate",AuditDate,time,PAADM))  q:PAADM=""  d
			..s IADM=##class(web.DHCPE.DHCPECommon).GetIADMByPaadm(PAADM)
			..s LastUser=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDate",AuditDate,time,PAADM))
			..q:(SuperFlag'="1")&&(LastUser'=CurUserID)  //过滤非本人审核的记录
			..s PIADM=$p($g(^DHCPEIADM(IADM)),"^",4)
			..s Status=$p($g(^DHCPEIADM(IADM)),"^",8)
    		..q:Status'="ARRIVED"
    		..s LocFlag=##class(web.DHCPE.PreCommon).GetLocFlag("PreADM",PIADM)
    		..q:LocFlag="1" 
    		..s PGADMDR=$p($g(^DHCPEPreIADM(PIADM)),"^",2) 
    		..s IGSort=1
    		..s:PGADMDR'="" IGSort=2
  
    		..q:(+Group'="0")&&(Group'=PGADMDR)
    		..q:((Group="ALLG")&&(PGADMDR=""))
    		..q:((Group="ALLI")&&(PGADMDR'=""))
    		..S GName=""
    		..i ""'=PGADMDR  d
    		...s GBIDR=$p($g(^DHCPEPreGADM(PGADMDR)),"^",1)
    		...i ""'=GBIDR s GName=$p($g(^DHCPEPreGBI(GBIDR)),"^",2)

    	
    		..s PBID=$p($g(^DHCPEPreIADM(PIADM)),"^",1)
    		..s THPNo= $p($g(^DHCPEPreIADM(PIADM)),"^",27)
    		..b:THPNo="0100005090"
   			..q:(THPNo="0100003000")||(THPNo="0300016870")||(THPNo="0300036410")||(THPNo="0300036919")||(THPNo="0300042669")||(THPNo="0300042646")
    		..s VIPLevel=+##class(web.DHCPE.PreCommon).GetVIPLevel("Pre",PIADM)
    		..q:(VIP'="")&&(VIP'=VIPLevel)
    		..q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    		..;q:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") //总检界面不显示单项体检记录
    		..s:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    		..s PAPMINo=$p($g(^DHCPEPreIBI(PBID)),"^",1)
    		..s Name=$p($g(^DHCPEPreIBI(PBID)),"^",2)
    		..q:(PatName'="")&&(Name'[PatName)
    		..s PaadmID=##class(web.DHCPE.DHCPEIAdm).GetPAADMByPADM(PIADM) 
    	
    		..q:(SuperFlag'="1")&&((LocID=293)||(LocID=292))&&(MainDoctor="N")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","AR",CurUserID,PaadmID)))  //主检分配 目前只有温江/本部启用主检分配 20250926 by yl
    		..q:(SuperFlag'="1")&&((LocID=293)||(LocID=292))&&(MainDoctor="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","MAR",CurUserID,PaadmID)))  //初审分配 目前只有温江/本部启用初审分配 20250926 by yl
    		..q:(SuperFlag'="1")&&((LocID=292)||(LocID=15)||(LocID=293))&&(MainDoctor="Z")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","ZAR",CurUserID,PaadmID)))    //终审分配目前只本部不启用
    
        	..q:(CurUserID="21573")&&(MainDoctor="Z")&&($d(^User.DHCPEWorkDistributionI("TypePAADMIndex","ZAR",PaadmID)))  //分配了终审的吴琴琴不显示
        
    		.. //体检特殊客户类型
    		..s SpecialTypeCode=##class(web.DHCPE.SpecialType).GetSpecialType(PAPMINo)
   			..i SpecialTypeCode'="" s Name=Name_"("_SpecialTypeCode_")"
			..s GSStatus=1,AuditUser="",Status=""
			..s (TAuditDate,TAuditTime,TAuditDateTime)=""
			..s GSID= ##class(web.DHCPE.ResultDiagnosis).GetSSId(PaadmID) 
    		..i GSID'="" d
    		...s AuditUser=$P($G(^DHCPEGS(GSID,1)),"^",5)
    		...s Status=$P($G(^DHCPEGS(GSID,1)),"^",9)
    		...i AuditUser'="" d
   			....s TAuditDate=$P($G(^DHCPEGS(GSID,1)),"^",6)
    		....s:TAuditDate'="" TAuditDate=##class(websys.Conversions).DateLogicalToHtml(TAuditDate)
    		....s TAuditTime=$P($G(^DHCPEGS(GSID,1)),"^",7)
	    	....s:TAuditTime'="" TAuditTime=##class(websys.Conversions).TimeLogicalToHtml(TAuditTime)
	    	....s TAuditDateTime=TAuditDate_" "_TAuditTime
	    	..s MainInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","MainDoctor",PaadmID))
	    	..s MainUser=$P(MainInfo,"^",1)
	    	..s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    		..s LastUser=$P(LastInfo,"^",1)
	    	..q:(MDocName'="")&&(MDocName'=MainUser)
	    	..q:(OnlyRead="Y")&&(AuditUser'="")  //粘贴核对过滤已主检
	    	..q:(GenStatus="HadMain")&&(MainDoctor="Z")&&((MainUser="")||(LastUser'="")) //终审界面查询已初审的 
    		..s SendAuditStatus= ##class(web.DHCPE.ResultDiagnosis).IsCanSendAuditByPAADM(PaadmID)  //可核对 不可核对 已核对
    		..q:(MainDoctor'="")&&(SendAuditStatus'=2) //三级审核 都必须核对通过
    	
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(SendAuditStatus'=0)
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanntCheck")&&(SendAuditStatus'=1)
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="HadChecked")&&(SendAuditStatus'=2)
    		..s ExistFlag= ##class(web.DHCPE.ResultDiagnosis).IsExistSendAuditByPAADM(PaadmID)  //存在核对未通过1  不存在为0
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(ExistFlag=1)  //可核对过滤核对未通过
    		..q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="NoSendAudit")&&(ExistFlag'=1)
    	
    	
    		..i ((SendAuditStatus=2)) s GSStatus=0  //未粘贴核对不允许主检
    		..q:(GSStatus="1")&&(GenStatus'["CanNoGS")&&(GenStatus'="")&&(OnlyRead'="Y") //过滤不可初审
    		..i GSStatus="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    		..i GSStatus="0" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检")
    		..s CAAuditFlag = 0,CAMainFlag = 0
	    	..i AuditUser'=""  d
	    	...s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检")
	    	...i ##class(web.DHCPE.CA.Main).GetSignName(2,PaadmID)'="" s CAAuditFlag = 1 
	    	..i Status="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回主检")
	  		..i MainUser'=""  d
    		...s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审")
    		...i ##class(web.DHCPE.CA.Main).GetSignName(3,PaadmID)'="" s CAMainFlag = 1
    		..i Status="2" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回初审")
    
    		..s:LastUser'="" GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已终审")
    		..i OnlyRead="Y" d
    		...s:SendAuditStatus=0 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可核对")
    		...s:SendAuditStatus=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可核对")
    		...s:SendAuditStatus=2 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已核对")
    		...s:ExistFlag=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"核对不通过")
    		..q:(MainDoctor="Y")&&(GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检"))
    		..;i (MainDoctor="Y")&&(GSStatus="已初审") s GSStatus="未复审"
    		..;q:(GenStatus="NoGS")&&(GSStatus'=##class(websys.Translation).Get("dhcpenewdiagnosis.hisui.csp","未初审",langId))
    		..q:(GenStatus="CanGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检"))
    		..q:(GenStatus="CanNoGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检"))
    		..q:(GenStatus="HadGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检"))
    		..q:(GenStatus="HadMain")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审"))
    		..q:(GenStatus="HadLast")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已终审"))
    		..q:(GenStatus="HadMainBack")&&(Status'="1")
    		..q:(GenStatus="HadLastBack")&&(Status'="2")
    		..q:(SuperFlag'="1")&&(OnlyRead="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))&&(GSStatus'="核对不通过")    
    		..q:(SuperFlag'="1")&&(OnlyRead="Y")&&(GenStatus="SelfNoSendAudit")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))   ////只看自己核对未通过记录
    		..q:(GenStatus="SelfNoSendAudit")&&(ExistFlag'=1)
    		..//b ;GSStatus	
    		..s PaPatID=$P($g(^PAADM(PaadmID)),"^",1)
    		..s Sex=$P($g(^PAPER(PaPatID,"ALL")),"^",7)
    		..s:Sex'="" Sex=$P($g(^CT("SEX",Sex)),"^",2)
    		..//s Age=##class(web.DHCBillInterface).GetPapmiAge(PaPatID,"")
    		..s Age= ##class(web.DHCPE.DHCPECommon).GetPapmiAge(PaPatID,HospID)
    		..s (VIPLevel,VIPDesc)=""
    		..s AdmDate=$P($g(^PAADM(PaadmID)),"^",6)
    		..s AdmDate=##class(websys.Conversions).DateLogicalToHtml(AdmDate)
    		..s VIPStr=##class(web.DHCPE.PreCommon).GetVIPLevel("PAADM",PaadmID)
    		..i VIPStr'="" d
    		...s VIPLevel=$p(VIPStr,"^",1)
    		...s VIPDesc=$p(VIPStr,"^",2)
    		..q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    		..s ReMark=""
    		..i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s ReMark=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"有高危")
    		..s PostPonedFlag=##class(web.DHCPE.OrderPostPoned).GetHadDelayItems(PaadmID)
    		..s PostPonedInfo=PostPonedFlag
    		..i PostPonedFlag="" s PostPonedFlag="N"
    		..e  s PostPonedFlag="Y"
    
    		..s GWFlag=""
    		..i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s GWFlag="1"

   
    
    		../***翻译 start***/
    		..s Sex=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.CTSex",Sex,"CTSEXDesc","cls")
    		..s VIPDesc=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.DHCPEVIPLevel",VIPDesc,"VLDesc","cls")
    		..s VIPSort=2
    		..s:(VIPDesc["VIP")||(VIPDesc["贵宾")||(VIPDesc["干部") VIPSort=1
    		../***翻译 end***/
    		..s JYSort="9999999"
    		..s JYFlag=##class(web.DHCPE.ResultDiagnosis).GetGSJYFlag(PaadmID)
    		..i JYFlag=1 s JYSort=1
    		..s LockFlag=0
    		..s LockUserDesc=""
    		..s LockUser=""
    		..i $d(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID)) d
    		...s LockFlag=1
    		...s LockUser=$p(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID),"^",1)
    		...s LockUserDesc=$p($g(^SSU("SSUSR",LockUser)),"^",2)
    
    		..s LockSort="9999999"
    		..i LockFlag="1" s LockSort="3"
    		..i CurUserID=LockUser s LockSort="2"
    
    		..q:(HaveLock="HaveLock")&&(LockFlag=0)
    		..q:(DocName'="")&&(LockUser'=DocName)
    		..;;第一次获取结果时间
    		..s RecordDate="",RecordTime="",RecordDateTime="",RecordUser="",RecordSort="Z"
    		..s RecordID=$o(^User.DHCPEAdmRecordManagerI("AdmTypeIndex",PIADM,"UPDATESTATIONS",0))
    		..i RecordID'="" d
    		...s RecordDate=$LG(^User.DHCPEAdmRecordManagerD(RecordID),3)
    		...s:RecordDate'="" RecordDate=##class(websys.Conversions).DateLogicalToHtml(RecordDate)
    		...s RecordTime=$LG(^User.DHCPEAdmRecordManagerD(RecordID),5)
    		...s:RecordTime'="" RecordTime=##class(websys.Conversions).TimeLogicalToHtml(RecordTime)
    		...s RecordDateTime=RecordDate_" "_RecordTime
    		...s RecordUserDR=$LG(^User.DHCPEAdmRecordManagerD(RecordID),7)
    		...s:RecordUserDR'="" RecordUser=$p($g(^SSU("SSUSR",RecordUserDR)),"^",2)
    		...i RecordUser=LoginDocName  s RecordSort="A"_RecordUserDR
    		...e  s RecordSort="Z"_RecordUserDR
    		..i GSStatus="已主检" s RecordDateTime=""
    		..s TCancelLockUser="",CancelSort=""
    		..i $d(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID)) d
    		...s sort=+$O(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,""),-1)
    		...s CancelLockInfo=$g(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,sort))
    		...s CancelUserDR=$p(CancelLockInfo,"^",1)
    		...s:CancelUserDR'="" TCancelLockUser=$p(^SSU("SSUSR",CancelUserDR),"^",2)
    		...;s:LockUser="" CancelSort="Z99"
    		...s CancelSort="Z99"
    		..q:(HaveLock="CancelLock")&&((TCancelLockUser="")||(LockFlag=1))
    		..;;;排序规则：急要标识-》本人获取结果队列-》本人锁定队列-》A医生获取结果队列-》A医生锁定队列-》到达队列-》撤销锁定队列
    
    
    		..i (MainDoctor="Y")||(MainDoctor="Z") s RecordSort=$zdh(AdmDate,3)
    
    		..s Sort=JYSort_"$"_RecordSort_"$"_LockSort_"$"_CancelSort
    		..;  粘贴核对界面排序：急要最优先，再先个人(先 Vip 后健康,均日期由远至近）；后团队(先 Vip 后健康,均日期由远至近
    		..s:OnlyRead="Y" Sort=JYSort_"$"_IGSort_"$"_VIPSort
    		..b:PaadmID=80017828
    		..//高危等级
			..s HighRiskLevel="无"
			..i $d(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID))=0 d
			... s HighRiskLevel="无"
			..e  d
			... &SQL(SELECT max(HRR_Level) into :HighRiskLevel FROM sqluser.DHC_PE_HighRiskResult WHERE HRR_PAAdm=:PaadmID)
			... s HighRiskLevel=$p($g(^DHCPEEDC(HighRiskLevel)),"^",2)
    		..q:(IsZJ="1")&&(HighRiskLevel="无")
			..q:(IsZJ="0")&&(HighRiskLevel'="无")
    		..s AllRejectFlag=..AllItemReject(IADM)
			..q:(AllRejectFlag="Y") //到达之后删除或弃检了所有项目的记录 20250702 qiaoyue
    		..s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    		..i LastInfo'="" d
    		...s lastDate=$p(LastInfo,"^",2)
    		...s lastTime=$p(LastInfo,"^",3)
    		...i GenStatus="HadLast" s Sort=lastDate_"$"_lastTime
    		..s AIFlag="N"
    		..s RPTID=$O(^DHCPERPT(0,"IADM",IADM,""))
    		..i RPTID'="" d
    		...s RPTAISendInfo=$P($G(^DHCPERPT(RPTID)),"^",20)
    		...i RPTAISendInfo'="" s AIFlag="Y"
    		..Set CheckedFlag=##class(web.DHCPE.ResultDiagnosis).GetDHCPEStatusFlag("SendAudit",PaadmID)
    		..Set lastSendDetail = ##class(web.DHCPE.ResultDiagnosisNew).GetLastSendDetail(PaadmID)
    		..s ^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,AdmDate,PaadmID)=PaadmID_"^"_PAPMINo_"^"_AdmDate_"^"_Name_"^"_Age_"^"_Sex_"^"_VIPLevel_"^"_VIPDesc_"^"_GName_"^"_GSStatus_"^"_ReMark_"^"_CAAuditFlag_"^"_CAMainFlag_"^"_PostPonedFlag_"^"_THPNo_"^"_GWFlag_"^"_LockUserDesc_"^"_RecordDateTime_"^"_TAuditDateTime_"^"_TCancelLockUser_"^"_PostPonedInfo_"^"_JYFlag_"^"_AIFlag_"^"_CheckedFlag_"^"_lastSendDetail
   			
   			
   			s Sort="" 
    		f  s Sort=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort)) q:Sort=""  d
    		.s SortAdmDate=""
    		.f  s SortAdmDate=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate)) q:SortAdmDate=""  d
    		..s PaadmID=""
    		..f  s PaadmID=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate,PaadmID)) q:PaadmID=""  d
    		...s SortInfo=$g(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate,PaadmID))
    		...s ^CacheTemp(repid,ind)=$lb($p(SortInfo,"^",1),$p(SortInfo,"^",2),$p(SortInfo,"^",3),$p(SortInfo,"^",4),$p(SortInfo,"^",5),$p(SortInfo,"^",6),$p(SortInfo,"^",7),$p(SortInfo,"^",8),$p(SortInfo,"^",9),$p(SortInfo,"^",10),$p(SortInfo,"^",11),$p(SortInfo,"^",12),$p(SortInfo,"^",13),$p(SortInfo,"^",14),$p(SortInfo,"^",15),$p(SortInfo,"^",16),$p(SortInfo,"^",17),$p(SortInfo,"^",18),$p(SortInfo,"^",19),$p(SortInfo,"^",20),$p(SortInfo,"^",21),$p(SortInfo,"^",22),$p(SortInfo,"^",23),$P(SortInfo,"^",24),$P(SortInfo,"^",25))
    
    		...s ind=ind+1
    
    		Set qHandle=$lb(0,repid,0)
   			Quit $$$OK
		}
	}
    elseif (RegNo="")
    {
	    i CurUserID=21687 Set logStime = $Now()
		i (OnlyRead="Y")&&(BDate="")  s BDate=+$h-30
    	i (BDate="") s BDate=+$h-15
    	i (EDate="") s EDate=+$h
    
    	i BDate'="" s BDate=##class(websys.Conversions).DateHtmlToLogical(BDate) 
    	i EDate'=""  s EDate=##class(websys.Conversions).DateHtmlToLogical(EDate) 
    
       
    
    	s Date=BDate-1
    	i (OnlyRead="Y")&&(PatName'="") s EDate=+$h
    	f  s Date=$o(^DHCPEIADM(0,"AdmDateTime",Date)) q:(Date="")||(Date>EDate)  d
    	.s time=0
    	.f  s time=$o(^DHCPEIADM(0,"AdmDateTime",Date,time)) q:(time="")  d
    	..s IADM=0
    	..f  s IADM=$o(^DHCPEIADM(0,"AdmDateTime",Date,time,IADM)) q:(IADM="")  d
    	...s PIADM=$p($g(^DHCPEIADM(IADM)),"^",4)
    	...s Status=$p($g(^DHCPEIADM(IADM)),"^",8)
    	
    	...q:Status'="ARRIVED"
    	
    	...s LocFlag=##class(web.DHCPE.PreCommon).GetLocFlag("PreADM",PIADM,LocID)
    	...q:LocFlag="1" 
    	...s PGADMDR=$p($g(^DHCPEPreIADM(PIADM)),"^",2) 
    	...s IGSort=1
    	...s:PGADMDR'="" IGSort=2
        
    	...q:(+Group'="0")&&(Group'=PGADMDR)
    	...q:((Group="ALLG")&&(PGADMDR=""))
    	...q:((Group="ALLI")&&(PGADMDR'=""))
    	...S GName=""
    	...i ""'=PGADMDR  d
    	....s GBIDR=$p($g(^DHCPEPreGADM(PGADMDR)),"^",1)
    	....i ""'=GBIDR s GName=$p($g(^DHCPEPreGBI(GBIDR)),"^",2)

		
    	...s PBID=$p($g(^DHCPEPreIADM(PIADM)),"^",1)
    	...s THPNo= $p($g(^DHCPEPreIADM(PIADM)),"^",27)
    	...b:THPNo="0100005090"
   		...q:(THPNo="0100003000")||(THPNo="0300016870")||(THPNo="0300036410")||(THPNo="0300036919")||(THPNo="0300042669")||(THPNo="0300042646")||(THPNo="0300072500")
    	...s VIPLevel=+##class(web.DHCPE.PreCommon).GetVIPLevel("Pre",PIADM)
    	...q:(VIP'="")&&(VIP'=VIPLevel)
    	...q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    	
    	...;q:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") //总检界面不显示单项体检记录
    	...s:(VIPLevel="9")&&(CSPName="dhcpe.diagnosis.audit.csp") GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    	...s PAPMINo=$p($g(^DHCPEPreIBI(PBID)),"^",1)
    	...s Name=$p($g(^DHCPEPreIBI(PBID)),"^",2)
    	...q:(PatName'="")&&(Name'[PatName)
    	...s PaadmID=##class(web.DHCPE.DHCPEIAdm).GetPAADMByPADM(PIADM) 
    	...b:PIADM=86767
    	...q:(SuperFlag'="1")&&((LocID=293)||(LocID=292))&&(MainDoctor="N")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","AR",CurUserID,PaadmID)))  //主检分配 目前只有温江/本部启用主检分配 20250926 by yl
    	...q:(SuperFlag'="1")&&((LocID=293)||(LocID=292))&&(MainDoctor="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","MAR",CurUserID,PaadmID)))  //初审分配 目前只有温江/本部启用初审分配 20250926 by yl
    	...q:(SuperFlag'="1")&&((LocID=292)||(LocID=15)||(LocID=293))&&(MainDoctor="Z")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","ZAR",CurUserID,PaadmID)))    //终审分配目前只本部不启用
        
        
        
        ...q:(CurUserID="21573")&&((LocID=293))&&(MainDoctor="Z")&&($d(^User.DHCPEWorkDistributionI("TypePAADMIndex","ZAR",PaadmID)))  //分配了终审的吴琴琴不显示
        
    	... //体检特殊客户类型
    	...s SpecialTypeCode=##class(web.DHCPE.SpecialType).GetSpecialType(PAPMINo)
   		...i SpecialTypeCode'="" s Name=Name_"("_SpecialTypeCode_")"
		...s GSStatus=1,AuditUser="",Status=""
		...s (TAuditDate,TAuditTime,TAuditDateTime)=""
		...s GSID= ##class(web.DHCPE.ResultDiagnosis).GetSSId(PaadmID) 
    	...i GSID'="" d
    	....s AuditUser=$P($G(^DHCPEGS(GSID,1)),"^",5)
    	....s Status=$P($G(^DHCPEGS(GSID,1)),"^",9)
    	....i AuditUser'="" d
   		.....s TAuditDate=$P($G(^DHCPEGS(GSID,1)),"^",6)
    	.....s:TAuditDate'="" TAuditDate=##class(websys.Conversions).DateLogicalToHtml(TAuditDate)
    	.....s TAuditTime=$P($G(^DHCPEGS(GSID,1)),"^",7)
	    .....s:TAuditTime'="" TAuditTime=##class(websys.Conversions).TimeLogicalToHtml(TAuditTime)
	    .....s TAuditDateTime=TAuditDate_" "_TAuditTime
	    ...s MainInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","MainDoctor",PaadmID))
	    ...s MainUser=$P(MainInfo,"^",1)
	    ...s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    	...s LastUser=$P(LastInfo,"^",1)
	    ...q:(MDocName'="")&&(MDocName'=MainUser)
	    ...q:(OnlyRead="Y")&&(AuditUser'="")  //粘贴核对过滤已主检
	    
	    ...q:(GenStatus="HadMain")&&(MainDoctor="Z")&&((MainUser="")||(LastUser'="")) //终审界面查询已初审的
	    
	   
	    ...q:(GenStatus="HadLast")&&(MainDoctor="Z")&&(LastUser'=CurUserID)
		
    	
    	...//i CurUserID=21687  Set SendAuditStatus = 2  //测试用
    	...s SendAuditStatus= ##class(web.DHCPE.ResultDiagnosis).IsCanSendAuditByPAADM(PaadmID)  //可核对 不可核对 已核对
    	...q:(MainDoctor'="")&&(SendAuditStatus'=2)&(HospID'="2") //三级审核 都必须核对通过
    	
    	...q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(SendAuditStatus'=0)
    	...q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanntCheck")&&(SendAuditStatus'=1)
    	...q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="HadChecked")&&(SendAuditStatus'=2)
    	...s ExistFlag= ##class(web.DHCPE.ResultDiagnosis).IsExistSendAuditByPAADM(PaadmID)  //存在核对未通过1  不存在为0
    	...q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="CanCheck")&&(ExistFlag=1)  //可核对过滤核对未通过
    	...q:(OnlyRead="Y")&&(GenStatus'="")&&(GenStatus="NoSendAudit")&&(ExistFlag'=1)
    	
    	...//s GSStatus=##class(web.DHCPE.ResultDiagnosis).IsAllItemExcByPAADM(PaadmID)  //可初审  不可初审
    	...i ((SendAuditStatus=2)) s GSStatus=0  //未粘贴核对不允许主检
    	
    	
    	
    	
    	...q:(GSStatus="1")&&(GenStatus'["CanNoGS")&&(GenStatus'="")&&(OnlyRead'="Y") //过滤不可初审
    	
    	...i GSStatus="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检")
    	...i GSStatus="0" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检")
    	
	    ...s CAAuditFlag = 0,CAMainFlag = 0
	    ...i AuditUser'=""  d
	    ....s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检")
	    ....i ##class(web.DHCPE.CA.Main).GetSignName(2,PaadmID)'="" s CAAuditFlag = 1 
	    ...i Status="1" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回主检")
	    
	   
    
    
    
    ...i MainUser'=""  d
    ....s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审")
    ....i ##class(web.DHCPE.CA.Main).GetSignName(3,PaadmID)'="" s CAMainFlag = 1
    ...i Status="2" s GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"退回初审")
    
    ...s:LastUser'="" GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已终审")
    ...i OnlyRead="Y" d
    ....s:SendAuditStatus=0 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可核对")
    ....s:SendAuditStatus=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可核对")
    ....s:SendAuditStatus=2 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已核对")
    ....s:ExistFlag=1 GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"核对不通过")
    ...q:(MainDoctor="Y")&&(GSStatus=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"未主检"))
    ...;i (MainDoctor="Y")&&(GSStatus="已初审") s GSStatus="未复审"
    ...;q:(GenStatus="NoGS")&&(GSStatus'=##class(websys.Translation).Get("dhcpenewdiagnosis.hisui.csp","未初审",langId))
    ...q:(GenStatus="CanGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"可主检"))
    ...q:(GenStatus="CanNoGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"不可主检"))
    ...q:(GenStatus="HadGS")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已主检"))
    ...q:(GenStatus="HadMain")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已初审"))
    ...q:(GenStatus="HadLast")&&(GSStatus'=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"已终审"))
    ...q:(GenStatus="HadMainBack")&&(Status'="1")
    ...q:(GenStatus="HadLastBack")&&(Status'="2")
    
    ...q:(SuperFlag'="1")&&(OnlyRead="Y")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))&&(GSStatus'="核对不通过")    
    ...q:(SuperFlag'="1")&&(OnlyRead="Y")&&(GenStatus="SelfNoSendAudit")&&('$D(^User.DHCPEWorkDistributionI("TypeReceiverDRIndex","CC",CurUserID,PaadmID)))   ////只看自己核对未通过记录
    ...q:(GenStatus="SelfNoSendAudit")&&(ExistFlag'=1)
    ...//b ;GSStatus	
    ...s PaPatID=$P($g(^PAADM(PaadmID)),"^",1)
    ...s Sex=$P($g(^PAPER(PaPatID,"ALL")),"^",7)
    ...s:Sex'="" Sex=$P($g(^CT("SEX",Sex)),"^",2)
    ...//s Age=##class(web.DHCBillInterface).GetPapmiAge(PaPatID,"")
    ...s Age= ##class(web.DHCPE.DHCPECommon).GetPapmiAge(PaPatID,HospID)
    ...s (VIPLevel,VIPDesc)=""
    ...s AdmDate=$P($g(^PAADM(PaadmID)),"^",6)
    ...s AdmDate=##class(websys.Conversions).DateLogicalToHtml(AdmDate)
    ...s VIPStr=##class(web.DHCPE.PreCommon).GetVIPLevel("PAADM",PaadmID)
    ...i VIPStr'="" d
    ....s VIPLevel=$p(VIPStr,"^",1)
    ....s VIPDesc=$p(VIPStr,"^",2)
    ...q:(VIPLevel="9")&&(OnlyRead="Y")  //单项体检
    ...s ReMark=""
    ...i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s ReMark=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc(CSPName,"有高危")
    ...s PostPonedFlag=##class(web.DHCPE.OrderPostPoned).GetHadDelayItems(PaadmID)
    ...s PostPonedInfo=PostPonedFlag
    ...i PostPonedFlag="" s PostPonedFlag="N"
    ...e  s PostPonedFlag="Y"
    
    ...s GWFlag=""
    ...i $D(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID)) s GWFlag="1"

   
    
    .../***翻译 start***/
    ...s Sex=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.CTSex",Sex,"CTSEXDesc","cls")
    ...s VIPDesc=##class(web.DHCPE.CT.Public.PubFun).GetTranslationDesc("User.DHCPEVIPLevel",VIPDesc,"VLDesc","cls")
    ...s VIPSort=2
    ...s:(VIPDesc["VIP")||(VIPDesc["贵宾")||(VIPDesc["干部") VIPSort=1
    .../***翻译 end***/
    ...s JYSort="9999999"
    ...s JYFlag=##class(web.DHCPE.ResultDiagnosis).GetGSJYFlag(PaadmID)
    ...i JYFlag=1 s JYSort=1
    ...s LockFlag=0
    ...s LockUserDesc=""
    ...s LockUser=""
    ...i $d(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID)) d
    ....s LockFlag=1
    ....s LockUser=$p(^DHCPEDataEx("DHCPEGeneralSummarize","LockAudit",PaadmID),"^",1)
    ....s LockUserDesc=$p($g(^SSU("SSUSR",LockUser)),"^",2)
    
    ...s LockSort="9999999"
    ...i LockFlag="1" s LockSort="3"
    ...i CurUserID=LockUser s LockSort="2"
    
    ...q:(HaveLock="HaveLock")&&(LockFlag=0)
    ...q:(DocName'="")&&(LockUser'=DocName)
    ...;;第一次获取结果时间
    ...s RecordDate="",RecordTime="",RecordDateTime="",RecordUser="",RecordSort="Z"
    ...s RecordID=$o(^User.DHCPEAdmRecordManagerI("AdmTypeIndex",PIADM,"UPDATESTATIONS",0))
    ...i RecordID'="" d
    ....s RecordDate=$LG(^User.DHCPEAdmRecordManagerD(RecordID),3)
    ....s:RecordDate'="" RecordDate=##class(websys.Conversions).DateLogicalToHtml(RecordDate)
    ....s RecordTime=$LG(^User.DHCPEAdmRecordManagerD(RecordID),5)
    ....s:RecordTime'="" RecordTime=##class(websys.Conversions).TimeLogicalToHtml(RecordTime)
    ....s RecordDateTime=RecordDate_" "_RecordTime
    ....s RecordUserDR=$LG(^User.DHCPEAdmRecordManagerD(RecordID),7)
    ....s:RecordUserDR'="" RecordUser=$p($g(^SSU("SSUSR",RecordUserDR)),"^",2)
    ....i RecordUser=LoginDocName  s RecordSort="A"_RecordUserDR
    ....e  s RecordSort="Z"_RecordUserDR
    ...i GSStatus="已主检" s RecordDateTime=""
    ...s TCancelLockUser="",CancelSort=""
    ...i $d(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID)) d
    ....s sort=+$O(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,""),-1)
    ....s CancelLockInfo=$g(^DHCPEDataEx("DHCPEGeneralSummarize","CancelLock",PaadmID,sort))
    ....s CancelUserDR=$p(CancelLockInfo,"^",1)
    ....s:CancelUserDR'="" TCancelLockUser=$p(^SSU("SSUSR",CancelUserDR),"^",2)
    ....;s:LockUser="" CancelSort="Z99"
    ....s CancelSort="Z99"
    ...q:(HaveLock="CancelLock")&&((TCancelLockUser="")||(LockFlag=1))
    ...;;;排序规则：急要标识-》本人获取结果队列-》本人锁定队列-》A医生获取结果队列-》A医生锁定队列-》到达队列-》撤销锁定队列
    
    
    ...i (MainDoctor="Y")||(MainDoctor="Z") s RecordSort=$zdh(AdmDate,3)
    
    ...s Sort=JYSort_"$"_RecordSort_"$"_LockSort_"$"_CancelSort
    ...;  粘贴核对界面排序：急要最优先，再先个人(先 Vip 后健康,均日期由远至近）；后团队(先 Vip 后健康,均日期由远至近
    ...s:OnlyRead="Y" Sort=JYSort_"$"_IGSort_"$"_VIPSort
    ...b:PaadmID=80017828
    
    
    ...//高危等级
	...s HighRiskLevel="无"
	...i $d(^User.DHCPEHighRiskResultI("PAAdmIndex",PaadmID))=0 d
	.... s HighRiskLevel="无"
	...e  d
	.... &SQL(SELECT max(HRR_Level) into :HighRiskLevel FROM sqluser.DHC_PE_HighRiskResult WHERE HRR_PAAdm=:PaadmID)
	.... s HighRiskLevel=$p($g(^DHCPEEDC(HighRiskLevel)),"^",2)
    ...q:(IsZJ="1")&&(HighRiskLevel="无")
	...q:(IsZJ="0")&&(HighRiskLevel'="无")
    
    ...s AllRejectFlag=..AllItemReject(IADM)
	...q:(AllRejectFlag="Y") //到达之后删除或弃检了所有项目的记录 20250702 qiaoyue
    ...s LastInfo=$G(^DHCPEDataEx("DHCPEGeneralSummarize","LastDoctor",PaadmID))
    ...i LastInfo'="" d
    ....s lastDate=$p(LastInfo,"^",2)
    ....s lastTime=$p(LastInfo,"^",3)
    ....i GenStatus="HadLast" s Sort=lastDate_"$"_lastTime
    ...s AIFlag="N"
    ...s RPTID=$O(^DHCPERPT(0,"IADM",IADM,""))
    ...i RPTID'="" d
    ....s RPTAISendInfo=$P($G(^DHCPERPT(RPTID)),"^",20)
    ....i RPTAISendInfo'="" s AIFlag="Y"
    
    ...Set CheckedFlag=##class(web.DHCPE.ResultDiagnosis).GetDHCPEStatusFlag("SendAudit",PaadmID)
    ...Set lastSendDetail = ##class(web.DHCPE.ResultDiagnosisNew).GetLastSendDetail(PaadmID)
    ...s ^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,AdmDate,PaadmID)=PaadmID_"^"_PAPMINo_"^"_AdmDate_"^"_Name_"^"_Age_"^"_Sex_"^"_VIPLevel_"^"_VIPDesc_"^"_GName_"^"_GSStatus_"^"_ReMark_"^"_CAAuditFlag_"^"_CAMainFlag_"^"_PostPonedFlag_"^"_THPNo_"^"_GWFlag_"^"_LockUserDesc_"^"_RecordDateTime_"^"_TAuditDateTime_"^"_TCancelLockUser_"^"_PostPonedInfo_"^"_JYFlag_"^"_AIFlag_"^"_CheckedFlag_"^"_lastSendDetail
    
  
    
    s Sort="" 
    f  s Sort=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort)) q:Sort=""  d
    .s SortAdmDate=""
    .f  s SortAdmDate=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate)) q:SortAdmDate=""  d
    ..s PaadmID=""
    ..f  s PaadmID=$o(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate,PaadmID)) q:PaadmID=""  d
    ...s SortInfo=$g(^TmpDHCPE("FindDiagnosisPatInfo",CurUserID,Sort,SortAdmDate,PaadmID))
    ...s ^CacheTemp(repid,ind)=$lb($p(SortInfo,"^",1),$p(SortInfo,"^",2),$p(SortInfo,"^",3),$p(SortInfo,"^",4),$p(SortInfo,"^",5),$p(SortInfo,"^",6),$p(SortInfo,"^",7),$p(SortInfo,"^",8),$p(SortInfo,"^",9),$p(SortInfo,"^",10),$p(SortInfo,"^",11),$p(SortInfo,"^",12),$p(SortInfo,"^",13),$p(SortInfo,"^",14),$p(SortInfo,"^",15),$p(SortInfo,"^",16),$p(SortInfo,"^",17),$p(SortInfo,"^",18),$p(SortInfo,"^",19),$p(SortInfo,"^",20),$p(SortInfo,"^",21),$p(SortInfo,"^",22),$p(SortInfo,"^",23),$P(SortInfo,"^",24),$P(SortInfo,"^",25))
    
    ...s ind=ind+1
    
    
    //i CurUserID=21687 Set ^tmpwgy("LogTime") = $G(logStime)_"^"_ $Now()
    Set qHandle=$lb(0,repid,0)
    Quit $$$OK
      
    }
    
   
    }
}


}
