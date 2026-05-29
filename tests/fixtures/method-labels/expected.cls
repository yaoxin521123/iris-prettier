ClassMethod GetTransAdvice(ReportType, ExamNo, OEOrdId, LisRowid = "")
{
	s $zt = "GetTransAdviceErr"
	s reportID = ..GetReportID4MTS(ReportType, ExamNo, OEOrdId, LisRowid)
	q trAdvice
GetTransAdviceErr
	q "-1^" _ $ze
}
