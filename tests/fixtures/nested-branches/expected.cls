ClassMethod GetCVByAdm(Adm = "")
{
	if UseType = "NURSE-TODO" {
		if AllowNurExec = 1  s Status = "C,Rec"
		else  s Status = "C"
	} elseif UseType = "NURSE-DONE" {
		if AllowNurExec = 1  s Status = "F"
		else  s Status = "Rec,F"
	}
	if Status '= ""  s Status = "," _ Status _ ","
	s ret = ""
	q ret
}
