Include websys
Class websys.DHCChartStyle Extends %RegisteredObject
{
/// ##Class(websys.DHCChartStyle).GetPatOEUrl()

ClassMethod GetPatOEUrl()
{
	s EpisodeID = $g(%request.Data("EpisodeID", 1))
	s UserId = $g(%session.Data("LOGON.USERID"))
	s DoctorType = ##class(web.SSUser).GetDefaultCareProviderType(UserId)
	if (DoctorType '= "DOCTOR") {
		q "oeorder.oplistcustom.new.csp"
	}
	s tmprtn = ##class(web.DHCCPW.MR.Interface).GetInPathWayName(EpisodeID)
	if tmprtn = "" {
		q "oeorder.oplistcustom.new.csp"
	} else { //入径
		q "dhccpw.mr.clinpathway.csp"
	}

	;Quit "dhcipbillpatfeeinfo.csp?Wanghc="_EpisodeID //oeorder.oplistcustom.new.csp
}
/// 过敏记录  websys.DHCChartStyle.GetAllergyStyle
/// s val=##class(websys.DHCChartStyle).GetAllergyStyle($G(%request.Data("PatientID",1)),$G(%request.Data("EpisodeID",1)),$G(%request.Data("mradm",1)))
/// s val=##class(websys.DHCChartStyle).GetAllergyStyle("",9,"")

ClassMethod GetAllergyStyle(PatientID = "", EpisodeID = "", mradm = "")
{
	;Set ^Wanghc("menu","GetAllergyStyle")=PatientID_","_EpisodeID
	s:(EpisodeID > 0) PatientID = +^PAADM(EpisodeID)
	s count = 0
	// d ##class(%ResultSet).RunQuery("web.DHCPAAllergy","Allergies",PatientID)
	s rs = ##class(%ResultSet).%New("web.DHCPAAllergy:Allergies")
	s sc = rs.Execute(PatientID)
	while (rs.Next()) {
		s count = count + 1
	}
	d rs.Close()
	s rs = ""
	//set count=5
	if (count > 0) {
		s obj = ##class(websys.dto.Menu).%New()
		s obj.className = "x-tab-strip-red"
		s obj.count = count
		s val = ##class(ext.util.JsonObject).ObjToJson(obj)
		q val
	}
	q 1
}
/// 审核实习医嘱 websys.DHCChartStyle.GetVerifyStyle
/// s val=##Class(websys.DHCChartStyle).GetVerifyStyle($G(%request.Data("PatientID",1)),$G(%request.Data("EpisodeID",1)),$G(%request.Data("mradm",1)))

ClassMethod GetVerifyStyle(PatientID = "", EpisodeID = "", mradm = "")
{
	s count = 0
	s rs = ##class(%ResultSet).%New("web.DHCOEOrdItem:FindUnActiveOrderItems")
	s sc = rs.Execute(EpisodeID)
	while (rs.Next()) {
		s count = count + 1
	}
	d rs.Close()
	s rs = ""
	s obj = ##class(websys.dto.Menu).%New()
	if (count > 0) {
		s obj.className = "x-tab-strip-red"
		s obj.count = count
		s val = ##class(ext.util.JsonObject).ObjToJson(obj)
		q val
	} else {
		s obj.className = "x-tab-strip-gray"
		s obj.disabled = 1
		//Set obj.count=count
		s val = ##class(ext.util.JsonObject).ObjToJson(obj)
		q val
	}
	q 0
}
/// 病人入径则显示医政组--医嘱录入
/// s val=##class(websys.DHCChartStyle).IsPathWayRecord()
/// 医嘱录入(入径)
/// dhc.side.oe.oerecord.cpw
/// dhccpw.mr.clinpathway.csp
/// 条件表达式 s val=##class(websys.DHCChartStyle).IsPathWayRecord()

ClassMethod IsPathWayRecord()
{
	s EpisodeID = $g(%request.Data("EpisodeID", 1))
	s val = 1
	s tmprtn = ##class(web.DHCCPW.MR.Interface).GetInPathWayName(EpisodeID)
	if tmprtn = "" {
		s val = 0
	}
	q val
}
/// 病人[没有]入径则显示医生站--医嘱录入
/// s val=##class(websys.DHCChartStyle).IsDoctorRecord()

ClassMethod IsDoctorRecord()
{
	s EpisodeID = $g(%request.Data("EpisodeID", 1))
	s val = 1
	s tmprtn = ##class(web.DHCCPW.MR.Interface).GetInPathWayName(EpisodeID)
	if tmprtn '= "" {
		s val = 0
	}
	q val
}
/// 临床路径菜单判断，如果入径则自动打开菜单

ClassMethod IsCPWStatusToDOC()
{
	s EpisodeID = $g(%request.Data("EpisodeID", 1))
	s val = 1
	s tmprtn = ##class(DHCMA.CPW.CPS.InterfaceSrv).GetCPWStatusToDOC(EpisodeID)
	if tmprtn { // 宁夏医科大不自动打开临床路径, 增加NotAutoOpenCPW配置，20200812
		s obj = ##class(websys.dto.Menu).%New()
		s autoOpen = 1
		if $$$GetConfig("websys", "NotAutoOpenCPW") = 1 s autoOpen = 0
		s obj.autoOpen = autoOpen
		s val = ##class(ext.util.JsonObject).ObjToJson(obj)
		q val
	}
	q val
}
/*对外取目录状态的方法：
w ##Class(EMRservice.BIEMRService).GetCategoryStatus(6, 100, 112, 3)
第一个参数 科室ID
第二个参数 安全组ID
第三个参数 就诊号
第四个参数 配置目录分类ID
返回值：
{"Visible" : "1", "Sequence" : "2"}
*/
/// s val=##class(websys.DHCChartStyle).GetEMRCategoryStatus(1)
/// 判断病历相关菜单,是否显示,顺序方法
/// @param CategoryiD编目Id
/// @param EMRType 病历类型 0：流水病历，1：留观病历，2：抢救病历

ClassMethod GetEMRCategoryStatus(CategoryID = "", EMRType = "")
{
	//s val=##class(websys.DHCChartStyle).GetEMRCategoryStatus(21,0)

	s EpisodeID = $g(%request.Data("EpisodeID", 1))
	s val = 1, autoOpen = 0
	;Set PatientID = +^PAADM(EpisodeID)
	s CTLocID = %session.Data("LOGON.CTLOCID")
	s GroupID = %session.Data("LOGON.GROUPID")
	;Set ^Wanghc("menu","EprInRecord",CategoryID)=CTLocID_","_GroupID_","_EpisodeID_","_CategoryID
	s emrJson = ##Class(EMRservice.BIEMRService).GetCategoryStatus(CTLocID, GroupID, EpisodeID, CategoryID)
	;Set ^Wanghc("menu","EprInRecord",CategoryID,CTLocID,GroupID," "_EpisodeID)=emrJson
	s emrJsonObj = ##class(ext.util.JsonObject).FromJSON(emrJson)
	s Visible = emrJsonObj.GetValue("Visible")
	s Sequence = emrJsonObj.GetValue("Sequence")
	s Num = emrJsonObj.GetValue("Num")
	s Num2 = emrJsonObj.GetValue("signNum") // ##Class(EMRservice.BL.BLTemplateSign).GetSignWaitStatus(96, 31, "", "MEDICAL", 1, 456449, 879, 11, "Y")
	s Num3 = emrJsonObj.GetValue("PrintNum")
	/*if (CategoryID = 18)||(CategoryID = 19)||(CategoryID = 20) {
		s obj = ##class(websys.dto.Menu).%New()
		s obj.sort = CategoryID
		s val = ##class(ext.util.JsonObject).ObjToJson(obj)
		q val
		}*/
		if (Visible = 0) {
			s val = 0
		} else {
			if (EMRType '= "") {
				if ##class(websys.Conversions).IsValidMethodName("web.DHCEMPatChange", "GetStayStatus") {
					//ret=-1表示流水病人
					s ret = ##class(web.DHCEMPatChange).GetStayStatus(EpisodeID)
					// 如果是流水病人则隐藏留观与抢救病历
					//i (EMRType=0) set val=1 流水病历一直打开
					if (EMRType = 1) && (ret = -1)  s val = 0
					if (EMRType = 2) && (ret = -1)  s val = 0
					//i (EMRType=0)&&(ret'=-1) set val=0 // 如果是留观或抢救病人则隐藏流水病历 [6758331]
					if (EMRType = 0) && (ret = -1)  s autoOpen = 1  //如果是流水病人则要回写病历，此时固定打开门诊病历
					;Set PatStayMenuStatus = ##class(web.DHCEMInterfaceCom).GetPatStayStatusForMenu(EpisodeID,EMRType)
					;if (PatStayMenuStatus="N"){
					;Set val=0
					;}
				}
			}
			if val = 1 {
				s obj = ##class(websys.dto.Menu).%New()
				s obj.sort = Sequence
				s obj.autoOpen = autoOpen
				s obj.count = Num
				if (Num3 > 0)  s obj.count = Num3 _ "/" _ Num
				if (Num2 > 0)  s obj.signCount = Num2
				s val = ##class(ext.util.JsonObject).ObjToJson(obj)
			}
		}
		q val
	}

	/// 是会诊病人且当前为会诊科室时.只能写病历，其它都禁用

ClassMethod IsConsPat(EpisodeID)
{
	s PatientID = 0, val = 1
	;Set ^Wanghc("menu","IsConsPat")=PatientID_","_EpisodeID
	s:(EpisodeID > 0) PatientID = +^PAADM(EpisodeID)
	s LocId = %session.Data("LOGON.CTLOCID")
	s AdmLocId = $p(^PAADM(EpisodeID), "^", 4) //当前科室
	q:LocId=AdmLocId val
	s rs = ##class(%ResultSet).%New("web.DHCEMConsInterface:QryPatConsList")
	s sc = rs.Execute(EpisodeID)
	while (rs.Next()) {
		s CLoc = rs.Data("CsLocDesc")
		s CUserId = rs.Data("CsUserID")
		s CLocId = ##class(web.CTLoc).GetIdFromCodeDescriptionHosp(CLoc)
		if (CLocId = LocId) {
			s obj = ##class(websys.dto.Menu).%New()
			s obj.disabled = 1
			s obj.className = "x-tab-strip-gray"
			s val = ##class(ext.util.JsonObject).ObjToJson(obj)
			q
		}
	}
	d rs.Close()
	s rs = ""
	q val
}
/// 公共卫生事件--病人 疑似未处理,感染未上报时 变红 websys.DHCChartStyle.GetPHEStyle()

ClassMethod GetPHEStyle(PatientID, EpisodeID, mradm)
{
	s count = 0
	s myrtn = ##Class(DHCHAI.CUS.IconProfile).CheckIcon(EpisodeID, 0)
	if myrtn '= "" {
		s tmpJsonObj = ##class(ext.util.JsonObject).%New()
		d tmpJsonObj.Clear()
		d tmpJsonObj.Put("className", "x-tab-strip-red") //.Put("count", 1)
		q tmpJsonObj.Json()
	}
	q ""
}
/// d ##class(websys.DHCChartStyle).grantMenu(56864,56878,"住院医师")

ClassMethod grantMenu(stMenuId, endMenuId, groupDesc)
{
	s ssGroupID = ##class(web.SSGroup).GetIdFromCodeOrDescription(groupDesc)
	s eprGroupID = ##class(epr.GroupSettings).GetIdFromGroupId(ssGroupID)
	s objEprGroupSetting = ##class(epr.GroupSettings).%OpenId(eprGroupID)
	s security = objEprGroupSetting.MenuSecurity
	s:security="" security=$zbitstr(50000,0)
	s:$zbitlen(security)<endMenuId security=$zbitor(security,$zbitstr(endMenuId,0))
	for i = stMenuId : 1 : endMenuId {
		s security = $zbitset(security, i, 1)
	}
	s objEprGroupSetting.MenuSecurity = security
	s sc = objEprGroupSetting.%Save()
	if $$$ISOK( sc)  w "grant menu success"
	else  w "grant menu fail"
}

ClassMethod InitMenu()
{
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf, Image
 	)
 	values
 	(
 		'病历文书', 'dhc.side.emr', 'SideMenu', 1, '../images/uiimages/AppDep.png'
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf, Image
 	)
 	values
 	(
 		'诊疗操作', 'dhc.side.oe', 'SideMenu', 1, '../images/uiimages/blood_bag.png'
 	)
 )
	s oeId = %ROWID
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf, Image
 	)
 	values
 	(
 		'辅助查询', 'dhc.side.find', 'SideMenu', 1, '../images/uiimages/search.png'
 	)
 )
	s findId = %ROWID
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf, LinkComponent
 	)
 	values
 	(
 		'医嘱处理', 'dhc.side.oe.oemanage', 'SideMenu', :oeId, 54468
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf, LinkComponent
 	)
 	values
 	(
 		'诊断录入', 'dhc.side.oe.diagrecord', 'SideMenu', :oeId, 54468
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf, LinkComponent
 	)
 	values
 	(
 		'医嘱录入', 'dhc.side.oe.oerecord', 'SideMenu', :oeId, 54468
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf, LinkComponent
 	)
 	values
 	(
 		'中草药录入', 'dhc.side.oe.herbrecord', 'SideMenu', :oeId, 54468
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf, LinkComponent
 	)
 	values
 	(
 		'过敏记录', 'dhc.side.oe.allergy', 'SideMenu', :oeId, 54468
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf, LinkComponent
 	)
 	values
 	(
 		'公共卫生事件', 'dhc.side.oe.pubhealth', 'SideMenu', :oeId, 54468
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf, LinkComponent
 	)
 	values
 	(
 		'审核实习医嘱', 'dhc.side.oe.studoeaudit', 'SideMenu', :oeId, 54468
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf
 	)
 	values
 	(
 		'检验结果', 'dhc.side.find.lablist', 'SideMenu', :findId
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf
 	)
 	values
 	(
 		'检查报告', 'dhc.side.find.rislist', 'SideMenu', :findId
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf
 	)
 	values
 	(
 		'病理报告', 'dhc.side.find.pislist', 'SideMenu', :findId
 	)
 )
 &sql(
 	insert into websys.menu
 	(
 		Caption, Name, Type, SubMenuOf
 	)
 	values
 	(
 		'就诊列表', 'dhc.side.find.admlist', 'SideMenu', :findId
 	)
 )
}
/// w ##class(websys.DHCChartStyle).ImportMenuByEMRCate("住院医师")

ClassMethod ImportMenuByEMRCate(GroupDesc)
{
	s stMenuId = 0, endMenuId = 0
	s parentMenu = "dhc.side.emr"
	s parentMenuId = ##class(websys.Menu).GetIdFromCodeOrDescription(parentMenu)
	s seq = ""
	for {
		// select ID,CategoryName from emrmeta.emrtemplatecategOry WHERE CategoryType="Category"
		s seq = $o(^DHCEMRM.EMRTemplateCategoryI("IdxParentCateogryIDAndSeq", " 0", seq))
		q:seq=""
		s cateId = ""
		for {
			s cateId = $o(^DHCEMRM.EMRTemplateCategoryI("IdxParentCateogryIDAndSeq", " 0", seq, cateId))
			q:cateId=""
			s menuCaption = $lg(^DHCEMRM.EMRTemplateCategoryD(cateId), 2)
			s menuCode = "dhc.side.emr.cate" _ cateId
			s menuId = $o(^websys.MenuI("UniqueNameIndex", $zu(28, menuCode, 7, 32768), ""))
			if (menuId > 0) {
				s MenuObj = ##class(websys.Menu).%OpenId(menuId)
			} else {
				s MenuObj = ##class(websys.Menu).%New()
			}
			if (MenuObj) {
				s MenuObj.Caption = menuCaption
				s MenuObj.Name = menuCode
				d MenuObj.SubMenuOfSetObjectId(parentMenuId)
				s MenuObj.ConditionalExpression = "s val=##class(websys.DHCChartStyle).GetEMRCategoryStatus(" _ cateId _ ")"
				s MenuObj.Target = "EMR"
				s MenuObj.LinkUrl = "emr.ip.main.csp"
				s MenuObj.ValueExpression = """" _ "&CategoryID=" _ cateId _ """"
				s MenuObj.Image = "" // "../images/uiimages/updatediag.png"
				s MenuObj.IsXhrRefresh = 1
				s MenuObj.JavascriptFunction = ""
				d MenuObj.%Save()
			}
			s menuId = MenuObj.%Id()
			if (stMenuId = 0)  s stMenuId = menuId
			if (endMenuId = 0)  s endMenuId = menuId
			if menuId < stMenuId s stMenuId = menuId
			if menuId > endMenuId s endMenuId = menuId
		}
	}
	d ..grantMenu(stMenuId, endMenuId, GroupDesc)
	q 1
}
}
