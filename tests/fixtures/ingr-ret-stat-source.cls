ClassMethod INGRTRetStat(StartDate, EndDate, LocId, Others, StartTime, EndTime)
{
	n (StartDate,EndDate,LocId,Others,StartTime,EndTime)
	s datefrom=StartDate,dateto=EndDate
	s parGrpType=$p(Others,"^",1) //类组
	s parIncRowid=$p(Others,"^",2) //药品rowid
	s parVendorId=$p(Others,"^",3) //供应商id
	s parRetReasonid=$p(Others,"^",4) //退药原因id
	s parType=$p(Others,"^",5) //查询类型
	s rpsumcosts=0,spsumcosts=0,i=0
	q:LocId="" 0     
	s pid=..NewPid() 
	f date=datefrom:1:dateto d
	. ;s ingrtid="" f  s ingrtid=$o(^INGRT(0,"DATE",date,ingrtid))  q:ingrtid=""  d
	. ;改为使用"审核"日期
	. s ingrtid=""  f  s ingrtid=$o(^INGRT(0,"AUDITDATE",date,ingrtid))  q:ingrtid=""  d  //主表
	.. s rpsumcosts=0,spsumcosts=0
	.. s incicntnum=0  ;每张退货单中的品种数
	.. q:'$d(^INGRT(ingrtid))
	.. s retstr=^INGRT(ingrtid)
	.. s rettime=$p(retstr,"^",10)
	.. q:(StartDate=date)&&(StartTime'="")&&(rettime<StartTime)
	.. q:(EndDate=date)&&(EndTime'="")&&(rettime>EndTime)
	.. s retcom=$p(retstr,"^",6) q:retcom'="Y"   ; 未※完成＂
	.. s auditusr=$p(retstr,"^",8) q:auditusr=""   ;未审核的过滤
	.. s locid=$p(retstr,"^",7) q:locid'=LocId  ;非查询科室
	.. s change=$p(retstr,"^",11)
	.. //q:(change="1")&(flag3'="调价换票")
	.. //q:(change="0")&(flag3="调价换票")
	.. s retno=$p(retstr,"^",1)
	.. s retdate=$p(retstr,"^",3)
	.. s retdate=##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(retdate,"ST")
	.. s apcvmid=$p(^INGRT(ingrtid),"^",2)
	.. s vendor=..Vendor(apcvmid)
	.. //i flag2="1" q:flag1'=vendor   ;by vendor
	.. q:(parVendorId'=apcvmid)&(parVendorId'="")
	.. s retch="" f  s retch=$o(^INGRT(ingrtid,"DHCGRR",retch)) q:retch=""  d  //子表
	... q:'$d(^INGRT(ingrtid,"DHCGRR",retch))
	... ;任晓娜 增加 退货损益统计这一列
	... s AspAmount=0,aspRowid=""
	... i $d(^DHCRETA(0,"TypePointer","R",ingrtid_"||"_retch)) d //判断损益表是否有子表的ID，有则说明产生过损益
	....s aspRowid=$o(^DHCRETA(0,"TypePointer","R",ingrtid_"||"_retch,aspRowid))
	....s AspAmount=$p(^DHCRETA(aspRowid),"^",5)  //取出损益表的损益金额
	... s retistr=^INGRT(ingrtid,"DHCGRR",retch)
	... s retqty=$p(retistr,"^",2)
	... s retuom=$p(retistr,"^",3)
	... s retrp=+$p(retistr,"^",7)
	... s retrpamt=$p(retistr,"^",4) 
	... s retsp=+$p(retistr,"^",8)
	... s retspamt=$p(retistr,"^",9)
	... s retpp=$p(retistr,"^",10)
	... s retppamt=$p(retistr,"^",11)
	... s retinvono=$p(retistr,"^",12)
	... s retinvdate=$p(retistr,"^",14)
	... i retinvdate'="" s retinvdate=##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(retinvdate,"ST")
	... s retres=$p(retistr,"^",5)
	... s retresdesc=$p($g(^INC("RET",retres)),"^",2)      ;退货原因描述
	... q:(parRetReasonid'="")&(parRetReasonid'=retres)
	... s ingriid=$p(retistr,"^",1)
	... s inclbid=""
	... s inclbid=$p(^DHCINGR(+ingriid,"GRI",$p(ingriid,"||",2)),"^",1) q:inclbid=""
	... s inciid=""
	... s inciid=$p(inclbid,"||",1)
	... q:'$d(^INCI(inciid,1))
	... q:'$d(^INCI(inciid,2))
	... q:'$d(^INCI(inciid,3))
	... s incicode=$p(^INCI(inciid,1),"^",1) s incidesc=$p(^INCI(inciid,1),"^",2) 
	... //i flag4="1" q:flag3'=retresdesc   ;by 退货原因
	... //i flag6="1" q:flag5'=incidesc    ;by 库存项
	...s StkGrpInfo=##class(web.DHCST.Common.DrugInfoCommon).GetIncStkCatGrp(inciid)
	...s Scg=$p(StkGrpInfo,"^",5)
	...s ScgType=$p(StkGrpInfo,"^",3)
	...q:ScgType'=..sssCode()
	...q:(parGrpType'="")&(Scg'=parGrpType)
	... q:(parIncRowid'="")&(parIncRowid'=inciid)
	... s incibid=""
	... s incibid=$p(^INCI($p(inclbid,"||",1),"IL",$p(inclbid,"||",2),"LB",$p(inclbid,"||",3)),"^",1)
	... s batno="",expdate=""
	... i incibid'="" d
	.... s batno=$p(^INCI($p(incibid,"||",1),"IB",$p(incibid,"||",2)),"^",1)
	.... s expdate=$p(^INCI($p(incibid,"||",1),"IB",$p(incibid,"||",2)),"^",2)
	... i expdate'="" s expdate=##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(expdate,"ST")
	... s dhcingri=$p(ingriid,"||",1),dhcingrich=$p(ingriid,"||",2)
	... i dhcingrich'="" s gmanfid=$p(^DHCINGR(dhcingri,"GRI",dhcingrich),"^",29)
	... s gmanf=""
	... i ($g(gmanfid)'="") d
	.... i $d(^PHMNF(gmanfid))  s gmanf=$p(^PHMNF(gmanfid),"^",2)
	... s buom=+$p(^INCI(inciid,1),"^",10)
	... s puruom=$p(^INCI(inciid,3),"^",6)
	... i $g(puruom)="" s puruom=buom 
	... s puruomdesc=$p(^CT("UOM",puruom),"^",2)
	... s bfac=##class(web.DHCST.Common.UtilCommon).UOMFac(retuom,buom)
	... s pfac=##class(web.DHCST.Common.UtilCommon).UOMFac(puruom,buom)
	... s retuom=$p(^CT("UOM",retuom),"^",2) //退货单位
	... s cpcosts=retspamt-retrpamt
	... s rpsumcosts=rpsumcosts+retrpamt
	... s spsumcosts=spsumcosts+retspamt
	... s incil=$p(incibid,"||",1)_"||"_$p(incibid,"||",2)
	... //取新科室货位表过滤货位 add wyx 2013-11-21 //改为取新的科室货位表DHCIncItmLocBin（可多货位）
	... s stkbinret=##class(web.DHCST.Common.DrugInfoCommon).GetInciBinStr(incil,",","","") 
	... s stkbinstr=$p(stkbinret,":",2)
	... s stkbin=stkbinstr 
	... S GeneStr=##Class(web.DHCST.Common.DrugInfoCommon).GetGene(inciid)						//通用名
	... S GeneCode=$P(GeneStr,"^",1)									//通用名代码
	... S GeneName=$P(GeneStr,"^",2)	
	... s phcge=GeneName							//通用名描述
	... s spec=##class(web.DHCST.Common.DrugInfoCommon).GetSpec("",inciid)
	... s retqty=(retqty*bfac)/pfac
	... s retsp=(retsp*pfac)/bfac
	... s retrp=(retrp*pfac)/bfac
	... s i=i+1
	... s data=i_"||"_retno_"||"_retinvono_"||"_retdate_"||"_$g(incicode)_"||"_$g(incidesc)_"||"_puruomdesc_"||"_retqty_"||"_retrp_"||"_retrpamt_"||"_retsp_"||"_retspamt_"||"_$g(vendor)_"||"_$g(batno)_"||"_$g(gmanf)_"||"_$g(stkbin)_"||"_$g(retresdesc)_"||"_$g(retpp)_"||"_$g(retppamt)_"||"_$g(rpsumcosts)_"||"_$g(spsumcosts)_"||"_$g(spec)_"||"_AspAmount_"||"_expdate_"||"_retinvdate_"||"_phcge
	... i parType="1" s indexData=i
	... i parType="2" s indexData=retno
	... i parType="3" s indexData=incicode
	... i parType="4" s indexData=vendor
	...i '$d(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat",pid,indexData)) d
	....s ^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat",pid,indexData)=data
	...e  d
	....s $p(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat",pid,indexData),"||",8)=$p(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat",pid,indexData),"||",8)+retqty
	....s $p(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat",pid,indexData),"||",10)=$p(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat",pid,indexData),"||",10)+retrpamt
	....s $p(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat",pid,indexData),"||",12)=$p(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat",pid,indexData),"||",12)+retspamt 
	...;(按退货单汇总)
	...
	...
	...i parType="2"  d
	....i '$d(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","cnt",pid,indexData,incicode)) d
	.....s ^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","cnt",pid,indexData,incicode)=1
	.....s incicntnum=incicntnum+1  
	.....s ^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","incicnt",pid,indexData)=incicntnum  ;每张单中的品种数
	....
	... 
	...i parType="4" d
	....i '$d(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","cnt",pid,indexData,retno)) d
	.....s ^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","cnt",pid,indexData,retno)=1 
	.....i '$d(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","retnocnt",pid,indexData)) d
	......s ^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","retnocnt",pid,indexData)=1  ;退货单张数
	.....e  d
	......s ^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","retnocnt",pid,indexData)=^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","retnocnt",pid,indexData)+1  ;退货单张数 
	.....
	....i '$d(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","cnt",pid,indexData,incicode)) d
	.....s ^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","cnt",pid,indexData,incicode)=1
	.....i '$d(^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","incicnt",pid,indexData)) d
	......s ^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","incicnt",pid,indexData)=1
	.....e  d
	......s ^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","incicnt",pid,indexData)=^TMP("DHCST","DHCINGRTRetStat","INGRTRetStat","incicnt",pid,indexData)+1  ;按供应商汇总的品种数
	......
	q pid_"^"_i
}