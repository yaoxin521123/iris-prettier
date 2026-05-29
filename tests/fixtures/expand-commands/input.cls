ClassMethod Login()
{
    s info=""
    f  s info=$o(^IRIS("info",info)) q:info="" d
    .i flag="1" d
}
