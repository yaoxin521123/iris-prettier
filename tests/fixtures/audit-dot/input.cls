Class M.TestDo Extends %RegisteredObject
{

ClassMethod Audit(adj As %String, user As %String) As %String
{
 n (adj,user)
 i ##class(web.DHCST.Common.AppCommon).Lock(..%GetParameter("AppName")_adj)<0 -99
 i ..AllowAudit(adj)<0 d ..uLock(adj) q -1
 s errMsg=..ChkAdjItmData(adj)
 i errMsg'="" d ..uLock(adj) q -100_"^"_errMsg
 s adjLoc=$P(^DHCINAD(adj),"^",16)
 s HospID=$P(^CTLOC(adjLoc),"^",22)
 s ret=0
 s TrNo=""
 &sql(select inad_no into :TrNo from dhc_inadj where %ID=:adj)
 s err=0
 s ch=0
 f  s ch=$o(^DHCINAD(adj,"ADI",ch)) q:(ch="")!(err>0)  d
 .s adjitm=adj_"||"_ch
 .s obj=##class(User.DHCINAdjItm).%OpenId(adjitm,0)
 .d obj.%Reload()
 .s inclb=obj.INADIINCLBDR.%Id()
 .s qty=obj.INADIQty
 .s uom=obj.INADICTUOMDR.%Id()
 .s sp=obj.INADIUCost
 .s spAmt=obj.INADISPAmt
 .s rp=obj.INADIRP
 .s rpAmt=obj.INADIRPAmt
 .s trType="A"
 .s TrNo=$G(TrNo)
 .s Pointer=adjitm
 .q:$d(^DHCINTR(0,"TypePointer",trType,Pointer))
 .ts
 .//更新进售价及金额为最新进售价金额
 .s CurSp=##class(web.DHCST.Common.PriceCommon).GetPriceElse(inclb,+$h,uom,HospID,..sssCode(),"")
 .s CurRp=##class(web.DHCST.Common.PriceCommon).GetClbRp(inclb,uom,HospID,..sssCode(),+$h,"")
 .i (CurSp'=sp)||(CurRp'=rp) d
 ..s NewSpAmt=CurSp*qty
 ..s NewRpAmt=CurRp*qty
 ..s NewSpAmt=##class(web.DHCST.Common.AppCommon).FormatSpAmt(NewSpAmt,HospID)
 ..s NewRpAmt=##class(web.DHCST.Common.AppCommon).FormatRpAmt(NewRpAmt,HospID)
 ..&Sql(UPDATE DHC_INAdjItm SET INADI_UCost=:CurSp ,INADI_SPAmt=:NewSpAmt, INADI_RP=:CurRp, INADI_RPAmt=:NewRpAmt WHERE INADI_RowId=:adjitm)
 ..i SQLCODE'=0 s ret=SQLCODE q
 ..s sp=CurSp
 ..s rp=CurRp
 ..s rpAmt=NewRpAmt
 ..s spAmt=NewSpAmt
 .i ret<0 tro   s err=3 q

 .s trans=trType
 .s trans=trans_"^"_TrNo
 .s trans=trans_"^"_inclb
 .s trans=trans_"^"_qty
 .s trans=trans_"^"_uom
 .s trans=trans_"^"_sp
 .s trans=trans_"^"_user
 .s trans=trans_"^"_Pointer
 .s trans=trans_"^"_rp
 .s trans=trans_"^"_rpAmt
 .s trans=trans_"^"_spAmt
 .
 .s inci=+inclb
 .s buom=$p(^INCI(inci,1),"^",10)
 .s fac=##class(web.DHCST.Common.UtilCommon).UOMFac(uom,buom)
 .s bqty=qty*fac
 .
 .s ret=##class(web.DHCST.Common.StockHandle).UpdateStock(inclb,bqty)
 .i ret<0 tro   s err=2 q
 .
 .s ret=##class(web.DHCST.Common.StockHandle).IntoTrans(trans)
 .i ret<0  tro   s err=1  q 
 .tc
 d ..uLock(adj)
 q:err=1 -3
 q:err=2 -4
 s status="20",chk="Y"
 s d=+$H,t=$p($h,",",2)
 &sql(update dhc_inadj set inad_chkflag=:chk,inad_chkDate=:d,inad_chktime=:t,INAD_ChkUSR_DR=:user,inad_state=:status where %ID=:adj )
 i SQLCODE'=0 d ..uLock(adj) q -2
 q 0
}

}
