ClassMethod Execute(params)
{
	s $zt="ErrExecute"
	s prescNo = $p(params, ..#Del, 1)
	s exeCode = $p(params, ..#Del, 2)
	ts
	s ret = 1
	tc
	q ret
}
