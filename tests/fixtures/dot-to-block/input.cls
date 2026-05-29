ClassMethod IfElseDemo()
{
s firstName = "Yao"
s lastNmae = "Xin"
if firstName = "Yao",lastNmae = "Xin" d
.w "true",!
e  d
.w "false",!
}

ClassMethod Login()
{
	s info =""
	f  s info = $o(^IRIS("info", info)) q:info="" d
	.s flag = $p(^IRIS("info", info), "^", 1)
	.i flag = "1" d
	..// todo 
}
