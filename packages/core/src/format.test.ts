import { describe, it, expect } from "vitest";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { format, formatObjectScript } from "./format.js";
import { computeBraceDepthAtLine } from "./formatter.js";
import {
  findAllMethodRanges,
  findMethodRangeAtLine,
} from "./methodRange.js";
import {
  convertDotSyntaxToBlockCore,
  commaToAndInCondition,
  convertLoopQuitToContinue,
} from "./dotToBlock.js";
import { convertDotSyntaxToBlock } from "./format.js";
import type { FormatOptions } from "./options.js";
import {
  formatPostfixCondition,
  formatPostfixLine,
  isHashSemicolonCommentLine,
  isRoutineLabelLine,
  isSlashSlashCommentLine,
} from "./rules.js";

const root = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const fixturesDir = join(root, "tests/fixtures");

function loadFixture(name: string): { input: string; expected: string } {
  const dir = join(fixturesDir, name);
  return {
    input: readFileSync(join(dir, "input.cls"), "utf8"),
    expected: readFileSync(join(dir, "expected.cls"), "utf8"),
  };
}

describe("format fixtures", () => {
  const dirs = existsSync(fixturesDir)
    ? readdirSync(fixturesDir, { withFileTypes: true })
        .filter((d) => d.isDirectory())
        .map((d) => d.name)
    : [];

  for (const name of dirs) {
    if (name === "dot-to-block" || name === "audit-dot") continue;
    it(`formats ${name}`, () => {
      const { input, expected } = loadFixture(name);
      expect(format(input)).toBe(expected);
    });
  }
});

describe("dot to block", () => {
  it("converts nested if/else and for per fixture", () => {
    const { input, expected } = loadFixture("dot-to-block");
    expect(convertDotSyntaxToBlockCore(input)).toBe(expected);
  });

  it("is idempotent when block syntax already", () => {
    const { expected } = loadFixture("dot-to-block");
    expect(convertDotSyntaxToBlockCore(expected)).toBe(expected);
  });

  it("converts selected fragment without method header", () => {
    const fragment = `if RuleFlag = 1  d
  .s INGDrp = ##Class(web.DHCSTPRICE).LastInPrice(ToInclb, "", ToHosp)\t//入库进价
  .s Ingd = ..InsertINGDI(INITI, ToInclb)
  .i (Ingd<= 0)  s Ret = Ingd q
  .s UnitePriceFlag = ..CheckUniteInAdjPrice(Inci, ToHosp)
  .i UnitePriceFlag = "N"  s Ret = ..InsertUniteInAdjPrice(INITI, Inci, ToHosp)
  .q:(Ret '= 0)
e  i (RuleFlag = 2)  d
  .s UnitePriceFlag = ..CheckUniteInAdjPrice(Inci, ToHosp)
  .i (UnitePriceFlag = "N")  s Ret = ..InsertUniteInAdjPrice(INITI, Inci, ToHosp)
  .q:(Ret '= 0)
e  i (RuleFlag = 3)  d
  .s BatchPriceFlag = ..CheckBatchInAdjPrice(ToInclb, ToHosp)
  .i BatchPriceFlag = "N"  s Ret = ..InsertBatchInAdjPrice(INITI, ToInclb, ToHosp)`;
    const out = convertDotSyntaxToBlock(fragment);
    expect(out).toContain("if (RuleFlag = 1) {");
    expect(out).toContain("} elseif (RuleFlag = 2) {");
    expect(out).toContain("} elseif (RuleFlag = 3) {");
    expect(out).not.toMatch(/\s+d\s*$/m);
    expect(out).not.toMatch(/^\s*\./m);
  });

  it("convertDotSyntaxToBlock pre-formats source before conversion by default", () => {
    const input = `ClassMethod M() {
  s ret = 2
  for  s ch = $o(^INRQ(req, "RQI", ch)) q:(ch = "")!(ret = 1)  d
  .i transQty < reqQty s ret = 1  q  //部分完成
  q ret
}`;
    const out = convertDotSyntaxToBlock(input);
    expect(out).toContain("if (transQty < reqQty) {");
    expect(out).toMatch(/s ret = 1 continue[\s\S]*\/\/部分完成/);
    expect(out).not.toContain("if (transQty < reqQty s ret = 1)");
  });

  it("format with convertDotSyntax runs format then dot then format", () => {
    const { input } = loadFixture("dot-to-block");
    const once = format(input, { convertDotSyntax: true });
    const twice = format(once, { convertDotSyntax: true });
    expect(twice).toBe(once);
    expect(once).toContain("for {");
    expect(once).toContain("} else {");
  });

  it("keeps ts/tc and rest of dot body inside for (Audit-style)", () => {
    const input = readFileSync(
      join(fixturesDir, "audit-dot", "input.cls"),
      "utf8"
    );
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toContain("for {");
    expect(out).toContain("ts");
    expect(out).toContain("tc");
    expect(out).not.toMatch(/^\s*\.ts/m);
    expect(out).not.toMatch(/^\s*\.tc/m);
    expect(out).toContain("continue:$d(^DHCINTR");
    expect(out).not.toMatch(/\bq:\$d\(\^DHCINTR/);
    expect(out).toContain("s ret=SQLCODE continue");
    expect(out).toContain("s err=3 continue");
    expect(out).toContain("s trans=trType");
    expect(out).toContain("UpdateStock(inclb,bqty)");
    expect(out).toContain("//更新进售价");
    expect(out).toMatch(
      /for\s*\{[\s\S]*\bts\b[\s\S]*s trans=trType[\s\S]*UpdateStock\(inclb,bqty\)[\s\S]*\btc\b[\s\S]*\}/
    );
    expect(out).not.toMatch(/^\s*\.ts/m);
  });

  it("converts loop-body q: to continue: but keeps for-header q:", () => {
    expect(convertLoopQuitToContinue("q:'$d(^INGRT(ingrtid))")).toBe(
      "continue:'$d(^INGRT(ingrtid))"
    );
    expect(convertLoopQuitToContinue("q:Ret'=0")).toBe("continue:Ret'=0");
    expect(convertLoopQuitToContinue("q:LocDr=\"\"")).toBe('continue:LocDr=""');
    expect(convertLoopQuitToContinue("s x=1 q:x=2")).toBe("s x=1 continue:x=2");
    expect(convertLoopQuitToContinue("i SQLCODE'=0 s ret=SQLCODE q")).toBe(
      "i SQLCODE'=0 s ret=SQLCODE continue"
    );
    expect(convertLoopQuitToContinue("//q:skip")).toBe("//q:skip");

    const input = `ClassMethod T()
{
\tq:LocId="" 0
\tf date=a:1:b d
\t. s x=""  f  s x=$o(^INGRT) q:x=""  d
\t.. q:'$d(^INGRT(x))
\t.. q:(StartDate=date)&&(StartTime'="")
\tq 1
}`;
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toContain("q:LocId=\"\" 0");
    expect(out).toMatch(/s x=\$o\(\^INGRT\) q:x=""/);
    expect(out).toContain("continue:'$d(^INGRT(x))");
    expect(out).toContain("continue:(StartDate=date)&&(StartTime'=\"\")");
    expect(out).toContain("q 1");
  });

  it("converts .i cond s ret = 1  q in for body without swallowing s ret into condition", () => {
    const input = `ClassMethod M() {
  s ret = 2
  s ch = 0
  for  s ch = $o(^INRQ(req, "RQI", ch)) q:(ch = "")!(ret = 1)  d
  .s transQty = ..TransQty(INRQI)
  .i transQty < reqQty s ret = 1  q  //部分完成
  q ret
}`;
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toContain("if (transQty < reqQty) {");
    expect(out).toMatch(
      /if \(transQty < reqQty\)\s*\{[\s\S]*s ret = 1[\s\S]*continue[\s\S]*\/\/部分完成/
    );
    expect(out).not.toMatch(/s ret = 1\s+q\s+\/\/部分完成/);
    expect(out).not.toContain("if (transQty < reqQty s ret = 1)");
  });

  it("keeps range-for header on for line when end is $l(...) expression", () => {
    const input = `ClassMethod SetRemarks(init As %String, remark As %String)
{
  s memoDelim = ##class(web.DHCST.Common.UtilCommon).MemoDelim()
  for i = 1 : 1 : $l(remarks, memoDelim)  d
  .s rem1 = $p(remarks, memoDelim, i)
  .d obj.INITRemarks.Insert(rem1)
  .
  q 0
}`;
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toContain("for i = 1 : 1 : $l(remarks, memoDelim) {");
    expect(out).not.toMatch(/for \{\s*\n\s*i = 1 : 1 : \$l/);
    expect(out).toContain("s rem1 = $p(remarks, memoDelim, i)");
  });

  it("does not turn for-index i into if after dot-to-block and format", () => {
    const input = `ClassMethod M() {
 for i = 1 : 1 : rowcnt  q:err<0  d
 .s row = $p(rows, rowDelim, i)
 .i err < 0  tro
 .q:err<0
}`;
    const out = format(convertDotSyntaxToBlockCore(input), { convertDotSyntax: true });
    expect(out).toMatch(/i = 1 : 1 : rowcnt\s+q:err<0/);
    expect(out).not.toMatch(/if = 1/);
    expect(out).toContain("$p(rows, rowDelim, i)");
  });

  it("keeps q: inside if block when not in for loop", () => {
    const input = `ClassMethod M() {
 i LocID="" d
 .s asub=$o(^DHCINAD(adj,"ADI",0))
 .q:asub=""
 .s LocID=$p(^DHCINAD(adj,"ADI",asub),"^",11)
}`;
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toContain('if (LocID="")');
    expect(out).toContain('q:asub=""');
    expect(out).not.toContain("continue:asub");
  });

  it("converts dot-loop body .q:Ret'=0 to continue (DHCINAD pattern)", () => {
    const input = `ClassMethod M() {
 f  s Ch=$o(^DHCINAD(inadj,"ADI",Ch)) q:(Ch="")!(Ret'=0)  d
 .s inadjrowid=inadj_"||"_Ch
 .q:LocDr=""
 .q:Ret'=0
}`;
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toMatch(/s Ch=\$o\(\^DHCINAD\(inadj,"ADI",Ch\)\) q:\(Ch=/);
    expect(out).toContain('continue:LocDr=""');
    expect(out).toContain("continue:Ret'=0");
    expect(out).not.toMatch(/\n\s+q:Ret'/);
  });

  it("does not turn commas inside ^TMP into &&", () => {
    const cond = "'$d(^TMP(\"DHCST\",\"DHCINGRTRetStat\",pid))";
    expect(commaToAndInCondition(cond)).toBe(cond);
  });

  it("preserves full INGRTRetStat body (no dropped lines)", () => {
    const src = readFileSync(
      join(root, "tests/fixtures/ingr-ret-stat-source.cls"),
      "utf8"
    );
    const wrapped = `Class web.T {\n${src}\n}`;
    const out = convertDotSyntaxToBlockCore(wrapped);
    expect(out).toContain("s retstr=^INGRT(ingrtid)");
    expect(out).toContain("GetGene(inciid)");
    expect(out).toContain("if '$d(^TMP");
    expect(out).toContain("} else {");
    expect(out.split("\n").length).toBeGreaterThan(140);
    expect(convertDotSyntaxToBlockCore(out)).toBe(out);
  });

  it("keeps i ($g(gmanfid)) d and following lines inside nested for", () => {
    const input = `ClassMethod T()
{
\tf date=a:1:b d
\t. s x=""  f  s x=$o(^A) q:x=""  d
\t.. s retch="" f  s retch=$o(^B,retch)) q:retch=""  d
\t... s gmanf=""
\t... i ($g(gmanfid)'="") d
\t.... i $d(^PHMNF(gmanfid))  s gmanf=$p(^PHMNF(gmanfid),"^",2)
\t... s buom=1
\t... s data=1
\tq 1
}`;
    const out = convertDotSyntaxToBlockCore(input);
    const gmanf = out.indexOf("if ($g(gmanfid)");
    const buom = out.indexOf("s buom=1");
    const close = out.lastIndexOf("q 1");
    expect(gmanf).toBeGreaterThan(-1);
    expect(buom).toBeGreaterThan(gmanf);
    expect(close).toBeGreaterThan(buom);
    expect(out).not.toMatch(/\}\s*\n\s*\.\.\.\s+i \(\$g\(gmanfid\)/);
  });

  it("converts nested range-for, inner f-s-q loops, and if/else on INGRTRetStat-style code", () => {
    const input = `ClassMethod INGRTRetStat()
{
\tf date=datefrom:1:dateto d
\t. s ingrtid=""  f  s ingrtid=$o(^INGRT(0,"AUDITDATE",date,ingrtid))  q:ingrtid=""  d
\t.. q:'$d(^INGRT(ingrtid))
\t.. s retch="" f  s retch=$o(^INGRT(ingrtid,"DHCGRR",retch)) q:retch=""  d
\t...i '$d(^TMP("DHCST","DHCINGRTRetStat",pid,indexData)) d
\t....s ^TMP("DHCST","DHCINGRTRetStat",pid,indexData)=1
\t...e  d
\t....s incicntnum=1
\tq pid
}`;
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toContain("for date=datefrom:1:dateto {");
    expect(out).toContain("s ingrtid=\"\"");
    expect(out).toMatch(/for \{\s*\n[\s\S]*s ingrtid=\$o\(\^INGRT/);
    expect(out).toMatch(/for \{\s*\n[\s\S]*s retch=\$o\(\^INGRT/);
    expect(out).toContain("if '$d(^TMP(\"DHCST\",\"DHCINGRTRetStat\",pid,indexData)) {");
    expect(out).toContain("} else {");
    expect(out).not.toContain(")&&(");
    expect(convertDotSyntaxToBlockCore(out)).toBe(out);
  });
});

describe("idempotency", () => {
  it("format(format(x)) === format(x)", () => {
    const sample = `ClassMethod Foo(a, b)
{
s x = a + b
q x
}`;
    const once = format(sample);
    expect(format(once)).toBe(once);
  });
});

describe("long _ concatenation lines", () => {
  it("does not split long s var = a _ \"^\" _ b assignments across lines", () => {
    const src = `        s Data1 = Ingri _ "^" _ BatchNo _ "^" _ IngrUomId _ "^" _ $g(IngrUom) _ "^" _ ExpDate _ "^" _ Inclb _ "^" _ Inpoi
        s Data2 = Margin _ "^" _ RecQty _ "^" _ Remarks _ "^" _ IncId _ "^" _ IncCode _ "^" _ IncDesc _ "^" _ InvMoney _ "^" _ InvNo
        s Data = Data1 _ "^" _ Data2 _ "^" _ Data3 _ "^" _ Data4 _ "^" _ Data5
`;
    const out = format(src);
    expect(out).not.toMatch(/s Data2 = Data2 _/);
    expect(out).toMatch(
      /s Data2 = Margin _ "\^" _ RecQty _ "\^" _ Remarks _ "\^" _ IncId/
    );
    expect(out).toMatch(/s Data = Data1 _ "\^" _ Data2/);
    expect(out.split("\n").filter((l) => /s Data2/.test(l)).length).toBe(1);
  });
});

describe("if +variable conditions", () => {
  it("does not add spaces around +var= in if condition", () => {
    expect(format('i +sortNum=0 s index="1"\n')).toBe(
      'if +sortNum=0  s index = "1"\n'
    );
    expect(format("i +sortNum=0\n")).toBe("if +sortNum=0\n");
    expect(format("if +sortNum=0\n")).toBe("if +sortNum=0\n");
  });
});

describe("command lowercase", () => {
  it("lowercases ZN namespace command", () => {
    expect(format('\tZN "DHC-APP"\n')).toContain('zn "DHC-APP"');
    expect(format('\tZN "DHC-APP"\n')).not.toMatch(/\bZN\b/);
  });

  it("abbreviates full commands at line start and mid-line", () => {
    expect(format('if $$$ISERR(sc) Quit "-306^" _ sc\n')).toMatch(
      /if \$\$\$ISERR\(sc\)\s+q "-306\^" _ sc/
    );
    expect(format('if $g(ind) = ""  set ind = 0\n')).toContain('s ind = 0');
    expect(format("if DobDate '= \"\"  Do\n\t.set PAPMIDOB = 1\n")).toContain(
      "if DobDate '= \"\"  d"
    );
    expect(format("if DobDate '= \"\"  Do\n\t.set PAPMIDOB = 1\n")).toContain(
      ".s PAPMIDOB = 1"
    );
    expect(format('else  Set PAPMIDOB = "", PAPMIAge = ""\n')).toContain(
      'else  s PAPMIDOB = "", PAPMIAge = ""'
    );
    expect(format("\t\t.e s ret = ret _ \"^\" _ df\n")).toContain(".e  s ret");
    expect(format("\t\te s ret = ret\n")).toContain("else  s ret");
    expect(format("d ##class(Foo).DoBar()\n")).toBe("d ##class(Foo).DoBar()\n");
    expect(format("return status\n")).toBe("ret status\n");
    expect(format("if $$$ISERR(sc) Tro  q \"-1\"\n")).toContain("tro  q");
    expect(format("if ret<0 tro s err=3 q\n")).toContain("if ret < 0  tro");
    expect(format("if ret<0 tro s err=3 q\n")).toMatch(/tro\s{2}s err/);
    expect(format("Tro\n")).toBe("tro\n");
    expect(format("d exeextobj.%Close()\n")).toBe("d exeextobj.%Close()\n");
    expect(format("d obj.%Close()\n")).not.toContain(".%c()");
    expect(format("xecute ##class(Foo).Bar()\n")).toBe(
      "x ##class(Foo).Bar()\n"
    );
    expect(format("trollback\n")).toBe("tro\n");
    expect(format("Trollback\n")).toBe("tro\n");
  });

  it("preserves %Close() inside method body (line 246 pattern)", () => {
    const src = `ClassMethod M() As %Status
{
\tif $$$ISERR(sc) {
\t\ttro
\t\ts ErrMsg = ..%GetErrCodeMsg("-100021")
\t\tq "-100021"
\t}
\td objext.%Close()
}`;
    const out = format(src);
    expect(out).toContain("d objext.%Close()");
    expect(out).not.toContain("objext.%c()");
    expect(format(out)).toBe(out);
  });

  it("lowercases and abbreviates system $ functions", () => {
    expect(format("s repid = $I(^CacheTemp)\n")).toContain("$i(^CacheTemp)");
    expect(format('s x = $P(^a, "^", 1)\n')).toContain('$p(^a, "^", 1)');
    expect(format("s x = $ListBuild(a, b)\n")).toContain("$lb(a, b)");
    expect(format("s ind = $list(qHandle, 3)\n")).toContain("$li(qHandle, 3)");
    expect(format("s x = $listget(h, i)\n")).toContain("$lg(h, i)");
    expect(format("s x = $IsObject(obj)\n")).toContain("$isobject(obj)");
    expect(format("if $$$ISERR(sc)  q 1\n")).toContain("$$$ISERR");
  });
});

describe("operator spacing", () => {
  it("spaces colons in for loop range", () => {
    expect(format("for i = 1:1:n {\n")).toContain("1 : 1 : n");
    expect(format("\ti = 1 : 1 : rowcnt  q:err<0\n")).toContain(
      "i = 1 : 1 : rowcnt"
    );
    expect(format("\ti = 1 : 1 : rowcnt  q:err<0\n")).not.toContain("if = 1");
    expect(format("q:(i = 1)\n")).toContain("q:(i = 1)");
    expect(format("q:(i = 1)\n")).not.toMatch(/q\s+:\s+\(/);
  });

  it("spaces colons in for range with $function", () => {
    expect(format("for len = 1:1:$l(OrderStr, \"^\")\n")).toContain("1 : 1 : $l(");
  });

  it("spaces colons in $s and $case expressions", () => {
    expect(
      format('s TotalBillFalg = $s(Conf \'= "":$p(^DHCTarC("CF", Conf), "^", 5), 1:"")\n')
    ).toContain('Conf \'= "" : $p(');
    expect(
      format('s TotalBillFalg = $s(Conf \'= "":$p(^DHCTarC("CF", Conf), "^", 5), 1:"")\n')
    ).toContain('5), 1 : "")');
    expect(format('s x = $s(NewStatus = "I":"Y", 1:"N")\n')).toContain('"I" : "Y"');
    expect(format('s x = $s(NewStatus = "I":"Y", 1:"N")\n')).toContain('1 : "N"');
    expect(
      format(
        's OldStatusCode = $case(OldStatusRowId, "":"C", :$p($g(^OEC("STAT", OldStatusRowId)), "^", 1))\n'
      )
    ).toContain('"" : "C"');
    expect(
      format(
        's OldStatusCode = $case(OldStatusRowId, "":"C", :$p($g(^OEC("STAT", OldStatusRowId)), "^", 1))\n'
      )
    ).toContain(", : $p(");
    expect(
      format('s SynStatusCode = $case(NewStatusCode, "F":"EXEC", "D":"SEXEC", "C":"REXEC", :"")\n')
    ).toContain(', : "")');
  });

  it("spaces comparison operators in if conditions", () => {
    expect(format("if DateFrom'=\"\"  s x = 1\n")).toContain("DateFrom '= \"\"");
    expect(format("if DateFrom'=\"\"  s x = 1\n")).not.toContain("DateFrom' =");
    expect(format("if TimeFrom[\":\"  s x = 1\n")).toContain("TimeFrom '[");
    expect(format('if (dispqty \'[".")  s dispqty = 1\n')).toContain("'[ \".");
    expect(format("if AdmHosp>0  s x = 1\n")).toContain("AdmHosp > 0");
    expect(format("if x>=1  s y = 2\n")).toContain("x>= 1");
    expect(format(".i (Ingd<= 0)  s Ret = Ingd q\n")).toContain("(Ingd <= 0)");
  });
});

describe("postfix conditions", () => {
  it("spaces operators inside parentheses only", () => {
    expect(formatPostfixCondition('q:(inci = "") && (arcim = "")')).toBe(
      'q:(inci = "")&&(arcim = "")'
    );
    expect(formatPostfixCondition("continue:(DateFrom>0)&&(repDate<DateFrom)")).toBe(
      "continue:(DateFrom > 0)&&(repDate < DateFrom)"
    );
    expect(
      formatPostfixCondition(
        'q:(prescForm\'="")&&(..CheckIfIncludeId(prescTypeStr,prescForm,",")="N")'
      )
    ).toBe(
      'q:(prescForm \'= "")&&(..CheckIfIncludeId(prescTypeStr, prescForm, ",") = "N")'
    );
  });

  it("tightens operators in unparenthesized postfix conditions", () => {
    expect(formatPostfixCondition('q:EpisodeId="" rtn')).toBe('q:EpisodeId="" rtn');
    expect(formatPostfixCondition("q:EpisodeId'>0 flag")).toBe("q:EpisodeId'>0 flag");
    expect(formatPostfixCondition('s:usercode\'="" userid=$o(^X)')).toBe(
      's:usercode\'="" userid=$o(^X)'
    );
    expect(
      formatPostfixCondition('s:security = "" security=$zbitstr(50000, 0)')
    ).toBe('s:security="" security=$zbitstr(50000, 0)');
    expect(formatPostfixCondition("q:seq = \"\"")).toBe('q:seq=""');
    expect(formatPostfixCondition("q:cateId = \"\"")).toBe('q:cateId=""');
    const line = 'q:phl="" -1_"^"_"不是药房"';
    expect(formatPostfixLine(line)).toBe(line);
    expect(format(line + "\n").trimEnd()).toBe(line);
    const forLine = format(".for  s ID = $o(^X)  q:ID=\"\"  d\n");
    expect(forLine).toContain("q:ID");
    expect(forLine).not.toMatch(/q:\(/);
  });

  it("formats inside existing parentheses without adding or removing parens", () => {
    expect(formatPostfixCondition('q:(EpisodeId = "" rtn)')).toBe(
      'q:(EpisodeId = "" rtn)'
    );
    expect(formatPostfixCondition('q:(EpisodeId\'>0 flag)')).toBe(
      "q:(EpisodeId '> 0 flag)"
    );
    expect(formatPostfixLine("q:(itmCount=1) $$$YES")).toBe(
      "q:(itmCount = 1) $$$YES"
    );
    expect(format("q:(itmCount=1) $$$YES\n").trimEnd()).toBe(
      "q:(itmCount = 1) $$$YES"
    );
    expect(format('q:(phl="") -1_"^"_"不是药房"\n').trimEnd()).toBe(
      'q:(phl = "") -1_"^"_"不是药房"'
    );
    expect(formatPostfixLine('q:(SQLCODE "更新住院配药表失败")')).toBe(
      'q:(SQLCODE "更新住院配药表失败")'
    );
  });

  it("does not add extra open paren in multi-part continue", () => {
    const line =
      'continue:(TimeFrom\'="")&&(DateFrom = repDate)&&(TimeFrom>repTime) //c';
    const out = formatPostfixCondition(line)!;
    expect(out).not.toContain("&&((");
    expect(out).toContain("(TimeFrom > repTime)");
  });

  it("formats nested parentheses and keeps tail text", () => {
    expect(
      formatPostfixLine(
        '..s:(flag MissTip = "(" _ $s(MaxMissionWind> = 20:"++++", 1:"-") _ ")")'
      )
    ).toMatch(/MaxMissionWind>=\s*20/);
    expect(
      formatPostfixLine(
        '..s:(^DHCDocConfig("AllergyCureItem", "EditCombo")[ItmMastdr MissionWind = MissionWind1)'
      )
    ).toContain('^DHCDocConfig("AllergyCureItem", "EditCombo")');
  });

  it("keeps concat inside q: postfix (tmpqty PackQty pattern)", () => {
    const line = 'q:($g(tmpqty)<0 "-" _ PackQty)';
    const once = formatPostfixLine(line)!;
    expect(once).toContain("tmpqty) < 0");
    expect(formatPostfixLine(once)).toBe(once);
  });

  it("is idempotent when parentheses are present", () => {
    const qLine = '..q:(PatientID \'= "") && (PapmiID \'= PatientID)';
    const qOnce = formatPostfixLine(qLine)!;
    expect(formatPostfixLine(qOnce)).toBe(qOnce);

    const line =
      'q:(FirstDate\'="")&(FirstDate\'= +$h)||((FirUsr\'="")&&(FirUsr\'= User)) -112';
    const once = formatPostfixCondition(line)!;
    expect(once).toContain("-112");
    expect(formatPostfixCondition(once)).toBe(once);
  });

  it("does not wrap $d(...) quit condition in extra parentheses", () => {
    const line =
      'q:$d(^ABN.DHCNurSkinTestRecSubI("OrdRowId"," "_OeordItemID)) -100\t;已保存过的';
    const once = formatPostfixCondition(line)!;
    expect(once).toContain('"OrdRowId", " "_OeordItemID');
    expect(once).not.toMatch(/^q:\(\$d/);
    expect(formatPostfixCondition(once)).toBe(once);
  });

  it("spaces commas inside unparenthesized q:$d(...) postfix", () => {
    const line = 'q:$d(^DHCINTR(0,"TypePointer",trType,Pointer))';
    const once = formatPostfixCondition(line)!;
    expect(once).toBe('q:$d(^DHCINTR(0, "TypePointer", trType, Pointer))');
    expect(formatPostfixCondition(once)).toBe(once);
    expect(format(".q:$d(^DHCINTR(0,\"TypePointer\",trType,Pointer))\n").trim()).toBe(
      '.q:$d(^DHCINTR(0, "TypePointer", trType, Pointer))'
    );
  });
});

describe("method header with attributes", () => {
  it("indents body when ClassMethod has [ PlaceAfter = ... ]", () => {
    const src = `ClassMethod BreathListLookupFetch(ByRef qHandle As %Binary) As %Status [ PlaceAfter = BreathListLookupExecute ]
{
s AtEnd = $list(qHandle, 1)
if ind = "" {
s AtEnd = 1
}
q $$$OK
}`;
    const out = format(src);
    expect(out).toContain(
      "ClassMethod BreathListLookupFetch(ByRef qHandle As %Binary) As %Status [ PlaceAfter = BreathListLookupExecute ]"
    );
    expect(out).toMatch(/\{\n\ts AtEnd = \$li/);
    expect(out).toMatch(/\n\tif ind = "" \{/);
    expect(out).toMatch(/\n\tq \$\$\$OK/);
  });
});

describe("routine labels", () => {
  it("detects label-only and label+command lines", () => {
    expect(isRoutineLabelLine("GetTransAdviceErr")).toBe(true);
    expect(isRoutineLabelLine("MyTag(arg1, arg2)")).toBe(true);
    expect(isRoutineLabelLine("ErrTag q \"-1^\" _ $ze")).toBe(true);
    expect(isRoutineLabelLine("s x = 1")).toBe(false);
    expect(isRoutineLabelLine("q trAdvice")).toBe(false);
    expect(isRoutineLabelLine("ts")).toBe(false);
    expect(isRoutineLabelLine("tro")).toBe(false);
    expect(isRoutineLabelLine("Tro")).toBe(false);
    expect(isRoutineLabelLine("b")).toBe(false);
    expect(isRoutineLabelLine("MyLabel")).toBe(true);
    expect(isRoutineLabelLine("unlock")).toBe(true);
    expect(isRoutineLabelLine("UnLock")).toBe(true);
    expect(isRoutineLabelLine('f s chl = $o(^X)  q:(chl = "")  d')).toBe(false);
  });

  it("keeps multiline &sql insert inside if/else when SQL spans non-dot lines", () => {
    const input = `ClassMethod M() {
 i $d(^DHCRETA(0,"TypePointer","G",rowid)) d
 .s retarowid=$o(^DHCRETA(0,"TypePointer","G",rowid,""))
 .&SQL(UPDATE DHC_RetAspAmount SET RETA_RpDiff=:adjRp,RETA_RpAmt=:AdjRpAmt WHERE RETA_RowId=:retarowid)
 e  d
 .&sql(insert into  DHC_RetAspAmount(RETA_INCI_DR,RETA_CTLOC_DR,RETA_AdjPrice,RETA_Qty,
 RETA_Amount,RETA_SSUSR_DR,RETA_Date,RETA_Time,RETA_Pointer,RETA_Type,RETA_RpDiff,RETA_RpAmt,RETA_Uom_Dr,RETA_INCLB_DR) 
  values (:inci,:locdr,:adjSp,:qty,:AdjSpAmt,:userdr,:date,:time,:rowid,:rettype,:adjRp,:AdjRpAmt,:Uom,:inclb))
 i SQLCODE'=0  d
 .s ret=$$SqlErrorRecord^DHCSTERROR("InsertRetA:DHC_RetAspAmount",rowid,SQLCODE_":"_$g(%msg))
 q:SQLCODE'=0 -2
 q 0
}`;
    const dotOut = convertDotSyntaxToBlockCore(input);
    expect(dotOut).toContain("if $d(^DHCRETA(0,\"TypePointer\",\"G\",rowid)) {");
    expect(dotOut).toContain("} else {");
    expect(dotOut).toMatch(/&sql\(insert[\s\S]*values[\s\S]*\)\)/i);
    expect(dotOut).not.toMatch(/\}\s*\nRETA_Amount/);
    expect(dotOut).toContain("if (SQLCODE'=0) {");
    expect(dotOut).toContain("q:SQLCODE'=0 -2");

    const full = format(input, { convertDotSyntax: true });
    expect(full).toMatch(/&sql\(\s*\n[\s\S]*update DHC_RetAspAmount/i);
    expect(full).toMatch(/&sql\(\s*\n[\s\S]*insert into DHC_RetAspAmount/i);
    expect(full).toContain("q:SQLCODE'=0 -2");
  });

  it("does not convert existing If cond { } Else { } block syntax", () => {
    const input = `ClassMethod QueryDetailFetch() As %Status
{
    Set ind=$o(^CacheTemp(repid,ind))
    If ind="" {             // if there are no more rows, finish fetching
    Set AtEnd=1
    Set Row=""
    }
    Else {
        Set Row=^CacheTemp(repid,ind)
    }
    s qHandle=$lb(AtEnd,repid,ind)
}`;
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toContain('If ind="" {');
    expect(out).toContain("// if there are no more rows, finish fetching");
    expect(out).toContain("Set AtEnd=1");
    expect(out).toContain("Else {");
    expect(out).not.toContain('if (ind="" {)');
    expect(out).not.toMatch(/if \(ind="" \{\)\s*\{/);
  });

  it("converts i count=0  w ... q \"\" inline if with multiple commands", () => {
    const input = `ClassMethod M() {
 i count=0  w ##class(web.DHCSTEXTCOMMON).GetNoJson() q ""
}`;
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toContain("if (count=0) {");
    expect(out).toMatch(
      /if \(count=0\)\s*\{[\s\S]*w ##class\(web\.DHCSTEXTCOMMON\)\.GetNoJson\(\)[\s\S]*q ""/
    );
    expect(out).not.toMatch(/^ i count=0/m);
  });

  it("converts i +sortNum=0 s index and e d dot body inside While", () => {
    const input = `ClassMethod M() {
 While(result.Next())
 {
  s Data=Data1_"^"_Data2
  i +sortNum=0 s index="1"
  e  d
  .s index=$p(Data,"^",sortNum)
  .i sortAsNum="Y" s index=+index
  .i index="" s index="ZZZZZZ"
  s QueryDATA(index,count)=Data
 }
}`;
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toContain("if (+sortNum=0) {");
    expect(out).toContain('s index="1"');
    expect(out).toMatch(/\}\s*else\s*\{[\s\S]*s index=\$p\(Data/);
    expect(out).toContain('if (sortAsNum="Y") {');
    expect(out).toContain('if (index="") {');
    expect(out).toContain("s QueryDATA(index,count)=Data");
    expect(out).not.toMatch(/\}\s*\n\s*\}\s*\n\s*\}/);
  });

  it("converts if d with dot body and inline else s to } else {", () => {
    const input = `ClassMethod M() {
 if (setInvDays '= "")  d
 .s invDate = +$h + setInvDays
 .s invDate = ##class(web.DHCSTInterfaceFromElse).DateLogicalToHtml(invDate)
 else  s invDate = ""
}`;
    const out = convertDotSyntaxToBlockCore(input);
    expect(out).toContain("if (setInvDays '= \"\") {");
    expect(out).toContain("s invDate = +$h + setInvDays");
    expect(out).toMatch(
      /\}\s*else\s*\{\s*\n[\s\S]*s invDate = ""\s*\n[\s\S]*\}/
    );
    expect(out).not.toMatch(/\}\s*\n\s*else\s+s invDate/);
  });

  it("converts .e  i cond d to elseif block on dot-to-block only", () => {
    const input = `ClassMethod M() {
 .i cond1=1  d
 .s x=1
 .e  i uomflag=0  d
 .s y=2
}`;
    const dotOut = convertDotSyntaxToBlockCore(input);
    expect(dotOut).toMatch(/if \(cond1=1\)\s*\{[\s\S]*s x=1/);
    expect(dotOut).toContain("} elseif (uomflag=0) {");
    expect(dotOut).toMatch(/elseif \(uomflag=0\)\s*\{[\s\S]*s y=2/);
    expect(format(dotOut)).not.toMatch(/\be\s{2}i\s+uomflag/);
  });

  it("keeps e  i abbreviation as-is during format (not elseif)", () => {
    const src = `ClassMethod GetType(params)
{
\ts str=""
\ts prescType=$p(params,"^",1)
\ti (prescType="自煎")||(prescType="自加工") d
\t.s str="自煎"
\te  i (prescType[ "加工膏滋") || (prescType[ "外用膏") d
\t.s str="膏方"
\te  s str="代煎"
\tq str
}`;
    const out = format(src);
    expect(out).toMatch(/\be\s{2}i\s+\(prescType/);
    expect(out).not.toContain("elseif");
    expect(format("\te  i ExpProp=2  d\n")).toMatch(/\be\s{2}i\s+ExpProp\s*=\s*2/);
    expect(format("\t.e  i ExpProp=2  d\n")).toMatch(/\.e\s{2}i\s+ExpProp\s*=\s*2/);
  });

  it("formats StartDispUpdPhar if+lock line (line 965 pattern)", () => {
    const src = `ClassMethod StartDispUpdPhar(params)
{
\ts getFlag = ..IfCanGet(phar,pUserID)
\ti getFlag="N" l -^DHCPHAUPDATE("UpdatePhar",phar)
\tq:getFlag="N" -2
}`;
    const out = format(src);
    expect(out).toContain('if getFlag = "N" l -^DHCPHAUPDATE("UpdatePhar", phar)');
    expect(out).toContain('q:getFlag="N" -2');
    expect(out).not.toMatch(/\ti getFlag/);
  });

  it("expands f/i/e line-start abbrev and indents for loop (getUserLoc line 71)", () => {
    const src = `ClassMethod getUserLoc(userID As %String)
{
\ts chl = ""
f s chl = $o(^SSU("SSUSR", userID, "OTHLL", chl))  q:(chl = "")  d
\t.s locID = 1
}`;
    const out = format(src);
    expect(out).toContain(
      '\tfor  s chl = $o(^SSU("SSUSR", userID, "OTHLL", chl))  q:(chl = "")  d'
    );
    expect(out).not.toMatch(/\nf s chl/);
  });

  it("formats standalone unlock as UnLock label (not unlock command)", () => {
    const src = `ClassMethod M()
{
\ttc
\td UnLock
\tq phd
\tunlock
\tl -^DHCPHARWINLOCK(phar)
\tq
}`;
    const out = format(src);
    expect(out).toContain("d UnLock");
    expect(out).toMatch(/\nUnLock\n/);
    expect(out).not.toMatch(/\n\tunlock\n/);
    expect(out).not.toMatch(/\n\tUnLock\n/);
  });

  it("detects // and #; comment lines", () => {
    expect(isSlashSlashCommentLine("//计费自己判断了母亲数据")).toBe(true);
    expect(isHashSemicolonCommentLine("#; d foo")).toBe(true);
    expect(isHashSemicolonCommentLine(";not hash")).toBe(false);
  });

  it("does not format or count braces in // and #; comment blocks", () => {
    const src = `ClassMethod M() As %Status
{
\tif (EpisodeID '= "") {
\t\t//如果计费设置的是包含新生儿费用
\t\t#; if (TotalBillFalg = "Y") && (MotherEpisodeID '= "") {
\t\t\t#; \td ##Class(web.UDHCJFBILL).BILLN(MotherEpisodeID, UserRowId, "")
\t\t\t#; } else {
\t\t\t\t#; \td ##Class(web.UDHCJFBILL).BILLN(EpisodeID, UserRowId, "")
\t\t\t\t#; }
\t\td ..InvokeBill(EpisodeID, UserRowId, "")
\t}
}`;
    const out = format(src);
    expect(out).toContain("//如果计费设置的是包含新生儿费用");
    expect(out).toMatch(/#;.*##Class\(web\.UDHCJFBILL\)/);
    expect(out).not.toMatch(/#;.*##class\(web\.UDHCJFBILL\)/);
    expect(out).toContain('\td ..InvokeBill(EpisodeID, UserRowId, "")');
    expect(out).not.toContain("\t\t\td ..InvokeBill");
  });

  it("does not re-indent semicolon comment lines or count their braces", () => {
    const src = `ClassMethod M() As %Status
{
\t;if x {
\t\t;\ts y = 1
\t\t\ts x = 1
}`;
    const out = format(src);
    expect(out).toContain("\t;if x {\n\t;s y = 1\n\ts x = 1");
    expect(out).not.toMatch(/\t\t;if /);
    expect(out).not.toMatch(/\t\t\ts x = 1/);
  });

  it("indents standalone break abbreviation b in method body", () => {
    const src = `ClassMethod M() As %Status
{
\tif 1  break
\ts x = 1
}`;
    expect(format(src)).toContain("\tif 1  b\n\ts x = 1");
    expect(format(src)).not.toMatch(/\nif 1  b\n/);
  });

  it("does not indent error trap labels in method body", () => {
    const src = `ClassMethod GetTransAdvice()
{
q trAdvice
GetTransAdviceErr
q "-1^" _ $ze
}`;
    const out = format(src);
    expect(out).toContain("\tq trAdvice\nGetTransAdviceErr\n\tq \"-1^\"");
    expect(out).not.toMatch(/\tGetTransAdviceErr/);
  });
});

describe("&sql blocks", () => {
  it("is idempotent for values :OEDISP( host-variable insert", () => {
    const src = `ClassMethod M() As %Status
{
    &sql(
    	insert into SQLUser.DHC_OEDispensing values :OEDISP(
    )
	s DspRowId = ""
	q 0
}`;
    const once = format(src);
    const twice = format(once);
    expect(twice).toBe(once);
    expect(once).toContain("values :OEDISP(");
    expect(once).toMatch(/&sql\([\s\S]*\)\s*\n\s*s DspRowId/);
    expect(once.match(/\n\s*\)\s*\n\s*\)/g)).toBeNull();
  });

  it("closes &sql before following q: line (GetINCIL pattern)", () => {
    const src = `ClassMethod GetINCIL(inci As %String, stk As %String) As %String
{
	s inci = $p(inci, $c(1))
	s stk = $p(stk, $c(1))
	&sql(
		select INCIL_RowId into :INCILrow from SQLUser.INC_ItmLoc where INCIL_INCI_Parref=:inci and INCIL_CTLOC_DR=:stk
	q $g(INCILrow)
}`;
    const once = format(src);
    const twice = format(once);
    expect(twice).toBe(once);
    expect(once).toMatch(
      /select INCIL_RowId[\s\S]*INCIL_CTLOC_DR=:stk\s*\n\t\)\s*\n\tq \$g\(INCILrow\)/
    );
    expect(once).not.toContain(":stk q $g");
  });

  it("recognizes . &sql with space after dot prefix", () => {
    const src = `ClassMethod M()
{
\tif x = 0 d
\t. &sql(update DHC_PHDISPEN s PHD_FineHerbFlag = 0 where PHD_ROWID = :phd)
\tif SQLCODE '= 0 tro
}`;
    const out = format(src);
    expect(out).toContain(".&sql(");
    expect(out).toContain("PHD_FineHerbFlag");
    expect(out).not.toMatch(/\. &sql\(update/);
  });

  it("preserves SQL identifiers on ..&sql lines (InsItmData pattern)", () => {
    const src = `ClassMethod InsItmData() {
\t..&sql(insert into SQLUSER.DHC_PHDISITEM (phdi_phd_parref, phdi_childsub, phdi_qty) values (:phd, :count, :qty))
\t..i SQLCODE '= 0 s err = -105
}`;
    const out = format(src);
    expect(out).toContain("DHC_PHDISITEM");
    expect(out).toContain("phdi_phd_parref");
    expect(out).not.toMatch(/DHC\s+_\s+PHDISITEM/);
    expect(out).not.toMatch(/phdi\s+_\s+phd/);
  });

  it("keeps values line inside multiline ..&sql insert", () => {
    const src = `ClassMethod InsItmData() {
\t..&sql(insert into SQLUSER.DHC_PHDISITEM (phdi_phd_parref, phdi_qty) values (:phd, :qty))
\t..i SQLCODE '= 0
}`;
    const out = format(src);
    expect(out).toContain("values");
    expect(out).toMatch(/&sql\([\s\S]*values[\s\S]*\)/);
    expect(out).not.toMatch(/\n\tvalues \(/);
  });

  it("drops redundant ) line after SQL line already closes &sql(", () => {
    const src = `ClassMethod M() {
\t&sql(
\t\tupdate DHC_PHDISPEN set PHD_PYFLAG=1 where PHD_ROWID=:phd) //comment
\t)
\tif SQLCODE '= 0 tro
}`;
    const out = format(src);
    expect(out).toContain("PHD_ROWID=:phd");
    expect(out).toContain(") //comment");
    expect(out).not.toContain(":phd //comment");
    expect(out).not.toContain(":phd) //");
    expect(out).toMatch(/\n\t\) \/\/comment\s*\n\s*if SQLCODE/);
    expect(out.match(/\n\t\)\s*\n/g)).toBeNull();
  });

  it("closes single-line &sql with trailing // comment (INIT_State pattern)", () => {
    const src = `ClassMethod M() {
\ts status="40"
\t&sql(UPDATE DHC_InIsTrf SET INIT_AgainInit_DR=:NewINIT,INIT_State=:status WHERE INIT_RowId =:RefuseINIT)  //将新的转移主表id插入在旧转移单的新单指向中
\ti SQLCODE'=0 tro
\tq:SQLCODE'=0 SQLCODE
}`;
    const out = format(src);
    expect(out).toMatch(
      /&sql\(\s*\n[\s\S]*update DHC_InIsTrf[\s\S]*\n\t\) \/\/将新的转移主表id插入/
    );
    expect(out).toMatch(/\)\s*\/\/将新的转移主表id插入[\s\S]*\nif SQLCODE/);
    expect(out).not.toMatch(/INIT_RowId =:RefuseINIT\s*\nif SQLCODE/);
  });

  it("places trailing // comment after &sql closing paren (PHD_PRINTFLAG pattern)", () => {
    const src = `ClassMethod M() {
\t&sql(update DHC_PHDISPEN set
\t\tPHD_PYFLAG=1,PHD_PYEDDATE=:sysDate,PHD_PYEDTIME=:sysTime,PHD_PRINTFLAG=0
\t\twhere PHD_ROWID=:phd)\t\t\t\t\t//PHD_PRINTFLAG 为0标记配药完成
\tif SQLCODE '= 0 tro
}`;
    const out = format(src);
    expect(out).toContain("//PHD_PRINTFLAG 为0标记配药完成");
    expect(out).toMatch(
      /PHD_ROWID=:phd\s*\n\t\) \/\/PHD_PRINTFLAG 为0标记配药完成/
    );
    expect(out).not.toMatch(/:phd \/\//);
  });

  it("keeps multiline insert+values inside ..&sql; close with ) not ..)", () => {
    const src = `ClassMethod M() {
\t..&sql(
\t\tinsert into SQLUSER.DHC_PHDISITEM
\t\t(
\t\t\tphdi_phd_parref, phdi_qty
\t\t)
\t\tvalues
\t\t(
\t\t\t:phd, :qty
\t\t)
\t..)
\t..i SQLCODE '= 0 s err = -105
}`;
    const out = format(src);
    expect(out).toMatch(/\.\.&sql\([\s\S]*values[\s\S]*\)\s*\n\s*\.{2}i/);
    expect(out).not.toMatch(/\.\.\)\s*\n/);
    expect(out).not.toMatch(/\.\.\)\s*\n\s*values/);
  });

  it("does not space underscores inside identifiers (only concat operator)", () => {
    expect(format("s x = DHC_PHDISITEM\n")).toContain("DHC_PHDISITEM");
    expect(format('q err _ "#" _ count\n')).toContain('err _ "#" _ count');
  });

  it("indents &sql blocks to match method body when source line has wrong leading space", () => {
    const src = `ClassMethod Audit() As %String
{
 s TrNo = ""
 &sql(
  select inad_no into :TrNo from dhc_inadj where %ID=:adj
 )
 s err = 0
 for  s ch = 1:1:2  d
 .i x d
 ..&sql(
  update DHC_INAdjItm set INADI_UCost=:CurSp where INADI_RowId=:adjitm
 )
 ..i SQLCODE '= 0 s ret = SQLCODE q
}`;
    const out = format(src);
    expect(out).toMatch(/\ts TrNo = ""\n\t&sql\(\n\t\tselect inad_no/);
    expect(out).toMatch(/\n\t\)\n\ts err = 0/);
    expect(out).toMatch(
      /\t\.\.&sql\(update DHC_INAdjItm set INADI_UCost=:CurSp where INADI_RowId=:adjitm\)/
    );
    expect(out).not.toMatch(/\t\.\.&sql\(\n\t\tupdate/);
    expect(out).toMatch(/\n\t\.\.i SQLCODE/);
  });

  it("does not abbreviate SQL set inside inline i ... &sql(update ... set ...)", () => {
    const src = `ClassMethod M() {
 .i loc'="" &sql(update dhc_inadj set inad_ctloc_dr=:loc where %ID=:inad)
}`;
    const out = format(src);
    expect(out).toMatch(/&sql\(update dhc_inadj set inad_ctloc_dr/i);
    expect(out).not.toMatch(/&sql\(update dhc_inadj s inad_ctloc_dr/i);
    expect(out).toMatch(/loc\s+'=\s+""\s{2}&sql\(/i);
  });

  it("keeps single-line ..&sql(UPDATE ...) on one physical line in dot syntax", () => {
    const sql =
      "UPDATE DHC_INAdjItm SET INADI_UCost=:CurSp ,INADI_SPAmt=:NewSpAmt WHERE INADI_RowId=:adjitm";
    const src = `ClassMethod M() {
 for  s ch=1:1:2  d
 ..&Sql(${sql})
 ..i SQLCODE'=0 s ret=SQLCODE q
}`;
    const out = format(src);
    expect(out).toMatch(
      /\.\.&sql\(update DHC_INAdjItm set INADI_UCost=:CurSp ,INADI_SPAmt=:NewSpAmt where INADI_RowId=:adjitm\)/
    );
    expect(out).not.toMatch(/\.\.&sql\(\n/);
  });

  it("keeps and/or lines inside multiline &sql after a lone ) line", () => {
    const src = `ClassMethod M() As %Status
{
\t\t&sql(
\t\t\tselect id into :X from t where a=:b
\t\t)
\t\tand c = :d
\t\tand e = :f)
\tif 1 s x=1
}`;
    const out = format(src);
    expect(out).toContain(
      "select id into :X from t where a=:b and c = :d and e = :f"
    );
    expect(out.match(/\t\t\)\n\t\t\)/g)).toBeNull();
  });
});

describe("if condition layout", () => {
  it("joins multiline if conditions into one line", () => {
    const src = `ClassMethod M() As %Status
{
\tif (OrderInsertTime > DosingEndTime)&&
\t(((OrderInsertDate = ExcuteDate))
\t||(((OrderInsertDate + 1) = ExcuteDate)&&(ExcuteTime < DosingStartTime))) {
\t\td GetDefRecLoc
\t}
}`;
    const out = format(src);
    expect(out).toMatch(
      /if \(OrderInsertTime > DosingEndTime\) && \(\(\(OrderInsertDate = ExcuteDate\)\)/
    );
    expect(out).not.toMatch(/DosingEndTime\) &&\n/);
  });
});

describe("comma spacing", () => {
  it("formats continue date comparisons", () => {
    const out = format("continue:(DateFrom>0)&&(repDate<DateFrom)");
    expect(out).toBe("continue:(DateFrom > 0)&&(repDate < DateFrom)");
  });

  it("adds space after comma before string arguments", () => {
    expect(format('s examno = $replace(repLabno,"--","||")')).toBe(
      's examno = $replace(repLabno, "--", "||")'
    );
    expect(format('s repDate = $p(repInfo,"\\", 1)')).toBe(
      's repDate = $p(repInfo, "\\", 1)'
    );
  });
});

describe("fragment formatting", () => {
  it("computeBraceDepthAtLine tracks nested blocks", () => {
    const src = `ClassMethod M()
{
\tif x {
\t\ts a=1
\t}
}`;
    const lines = src.split("\n");
    expect(computeBraceDepthAtLine(lines, 2)).toBe(1);
    expect(computeBraceDepthAtLine(lines, 3)).toBe(2);
    expect(computeBraceDepthAtLine(lines, 4)).toBe(2);
  });

  it("applies method body indent when fragmentBraceDepth is set", () => {
    const fragment = "s a=1\ns b=2";
    const out = format(fragment, { fragmentBraceDepth: 2 });
    expect(out).toBe("\t\ts a = 1\n\t\ts b = 2");
  });
});

describe("method range", () => {
  const src = `Class foo Extends %Persistent
{
ClassMethod Alpha() As %Status
{
Set x=1
Quit $$$OK
}

ClassMethod Beta() As %Status
{
Set y=2
}
}`;

  it("findMethodRangeAtLine locates method by cursor line", () => {
    const lines = src.split("\n");
    const beta = findMethodRangeAtLine(lines, 10);
    expect(beta?.name).toBe("Beta");
    expect(beta?.startLine).toBe(8);
    expect(lines[beta!.endLine]?.trim()).toBe("}");
    const alpha = findMethodRangeAtLine(lines, 4);
    expect(alpha?.name).toBe("Alpha");
  });

  it("formats a single method slice", () => {
    const lines = src.split("\n");
    const range = findMethodRangeAtLine(lines, 4)!;
    const slice = lines.slice(range.startLine, range.endLine + 1).join("\n");
    const out = format(slice);
    expect(out).toContain("ClassMethod Alpha() As %Status");
    expect(out).toContain("s x = 1");
    expect(out).not.toContain("Beta");
  });
});

describe("fallback", () => {
  it("returns text for empty input", () => {
    expect(format("")).toBe("");
  });
});
