ClassMethod InsBox(str As %String)
{
	&SQL(Insert Into DHC_PHBox (PHB_No, PHB_Num, PHB_Status, PHB_FLoc_Dr,PHB_TLoc_Dr,PHB_UserCreate_Dr, PHB_DateCreate, PHB_TimeCreate, PHB_PrintFlag, PHB_Remark) values(:boxNo, 1, :status, :fromLocID, :toLocID,:userID, :date, :time, "Y", :remark))
	q SQLCODE
}
