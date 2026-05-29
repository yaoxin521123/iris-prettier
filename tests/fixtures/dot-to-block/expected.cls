ClassMethod IfElseDemo()
{
s firstName = "Yao"
s lastNmae = "Xin"
if (firstName = "Yao")&&(lastNmae = "Xin") {
	w "true",!
} else {
	w "false",!
}
}

ClassMethod Login()
{
	s info =""
	for {
		s info = $o(^IRIS("info", info)) q:info=""
		s flag = $p(^IRIS("info", info), "^", 1)
		if (flag = "1") {
				// todo
		}
	}
}
