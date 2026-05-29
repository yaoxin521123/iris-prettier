import {
  mapCodeSegments,
  splitByStrings,
  splitTrailingComment,
  type Segment,
} from "./tokenize.js";

const COMMAND_ABBREV: Record<string, string> = {
  i: "if",
  f: "for",
  e: "else",
};

/** IRIS 使用 `elseif`，不用 `else if` / `else i` */
export function normalizeElseIf(code: string): string {
  return code.replace(/\belse\s+i\b/gi, "elseif");
}

/** 团队规范：行内/块内命令统一缩写（set→s、quit→q、do→d），块级 if/for/else 保持全拼 */
const COMMAND_CANONICAL: Record<string, string> = {
  set: "s",
  quit: "q",
  do: "d",
  return: "ret",
  halt: "h",
  write: "w",
  read: "r",
  kill: "k",
  break: "b",
  open: "o",
  close: "c",
  use: "u",
  view: "v",
  goto: "g",
  execute: "x",
  xecute: "x",
  tstart: "ts",
  tcommit: "tc",
  trollback: "tro",
  tro: "tro",
};

/** 行内缩写：不含 open/close，避免误改 %Open()、%Close() 等 % 方法名 */
const INLINE_COMMAND_KEYS = Object.keys(COMMAND_CANONICAL).filter(
  (k) => k !== "open" && k !== "close"
);

const COMMAND_CANONICAL_RE = new RegExp(
  `(?<![.%])\\b(${INLINE_COMMAND_KEYS.join("|")})\\b`,
  "gi"
);

/** 单独成行时是命令而非标签（如 break→b），避免与 isRoutineLabelLine 冲突 */
const STANDALONE_COMMAND_ABBREV = new Set(
  Object.values(COMMAND_CANONICAL).map((v) => v.toLowerCase())
);

/** 方法声明；允许 `As %Status [ PlaceAfter = X ]` 等类元数据 */
const METHOD_HEADER =
  /^(ClassMethod|Method)\s+(\w+)\s*(\([^)]*\))?\s*(As\s+[\w.%]+)?\s*(\[[^\]]*\])?\s*$/i;

const POSTFIX_CMD = /^(q|continue|b|g|goto|s)\s*:/i;

/** 后置条件 + 退出返回值（q / continue 等） */
const POSTFIX_QUIT = /^(q|continue|b|g|goto)$/i;
/** 后置条件 + 同行 set（s:cond var = val） */
const POSTFIX_SET = /^s$/i;

const POSTFIX_CMD_WORD = /\b(q|continue|b|g|goto|s)\s*:/gi;

/** 仅规范化行首 ObjectScript 命令，避免误改 SetDispEvent 等标识符 */
const LINE_COMMAND =
  /^(\s*)(s|i|e|q|d|w|h|k|t|j|g|ret|if|for|else|set|do|while|try|catch|quit|return|break|continue|halt|open|close|use|view|zn|zkill|xecute|read|write|kill|merge|order|sort|lock|unlock|ts|tc|tstart|tcommit|trollback|tro)\b/i;

/** 块级关键字仅小写，不缩写 */
const BLOCK_KEYWORD_RE = /\b(if|for|else|elseif|while|try|catch)\b/gi;

function canonicalizeCommandsInCode(code: string): string {
  let result = code.replace(LINE_COMMAND, (_, sp, cmd) => {
    const lower = cmd!.toLowerCase();
    const canonical = COMMAND_CANONICAL[lower] ?? lower;
    return `${sp}${canonical}`;
  });
  result = result.replace(BLOCK_KEYWORD_RE, (m) => m.toLowerCase());
  result = result.replace(COMMAND_CANONICAL_RE, (m) => {
    const canonical = COMMAND_CANONICAL[m.toLowerCase()];
    return canonical ?? m.toLowerCase();
  });
  return result;
}

/** 行首 / 行内 / .set 块内命令：小写 + 全拼→缩写 */
export function lowercaseCommand(line: string): string {
  const trimmed = line.trimStart();
  if (!trimmed || trimmed.startsWith("#") || trimmed.startsWith("//")) {
    return line;
  }

  return applyLineSpacingPreservingPostfix(line, (maskedLine) => {
    const { text: sqlMasked, spans } = maskEmbeddedSqlSpans(maskedLine);
    let result = sqlMasked.replace(
      /^(\s*)\.([a-zA-Z]+)\b/,
      (_, sp, cmd) => {
        const lower = cmd.toLowerCase();
        const canonical = COMMAND_CANONICAL[lower] ?? lower;
        return `${sp}.${canonical}`;
      }
    );

    result = mapCodeSegments(result, canonicalizeCommandsInCode);
    return unmaskEmbeddedSqlSpans(result, spans);
  });
}

export function expandBlockCommands(line: string): string {
  // 保持点语法 `e  i … d` / `.e  i … d` 原样，不转为 elseif，也不把 e 扩成 else
  if (/^(\s*)((?:\.)*)e\s+i\b/i.test(line)) {
    return line;
  }

  // 勿把 for 头 `i = 1 : 1 : n` 里的索引 `i` 扩成 `if`
  const m = line.match(/^(\s*)(i|f|e)\b(?!\s*=)(.*)$/i);
  if (!m) return line;
  const [, sp, cmd, rest] = m;
  const expanded = COMMAND_ABBREV[cmd.toLowerCase()];
  if (!expanded) return line;
  const trimmedRest = rest.trimStart();
  // `f s …` / `f d …` → `for  s …`（for 后双空格，与团队习惯一致）
  const gap =
    expanded === "for" && /^[sd]\b/i.test(trimmedRest) ? "  " : " ";
  return normalizeElseIf(`${sp}${expanded}${gap}${trimmedRest}`);
}

/** Format method signature: spaces after commas in parameter list. */
export function formatMethodHeader(line: string): string {
  const m = line.match(
    /^(\s*)(ClassMethod|Method)(\s+)(\w+)(\s*)(\(([^)]*)\))?(\s*As\s+[\w.%]+)?(\s*\[[^\]]*\])?\s*$/i
  );
  if (!m) return line;
  const [, sp, kw, s1, name, , , params, ret, attrs] = m;
  const keyword = kw!.toLowerCase() === "classmethod" ? "ClassMethod" : "Method";
  let sig = `${sp}${keyword}${s1}${name}`;
  if (params !== undefined) {
    const formatted = params
      .split(",")
      .map((p) => p.trim())
      .filter((p) => p.length > 0)
      .join(", ");
    sig += `(${formatted})`;
  }
  if (ret) sig += ret;
  if (attrs) sig += attrs;
  return sig;
}

const NEXT_COMMAND =
  "s|q|d|w|h|k|t|j|g|ret|if|for|else|elseif|set|do|while|continue|break|halt|open|close|use|view|read|write|kill|merge|order|sort|lock|unlock|rtn|return|tro|ts|tc|tstart|tcommit|trollback";

const TX_COMMAND = "tro|ts|tc|tstart|tcommit|trollback";

/**
 * 同一行多个 ObjectScript 命令之间保留两个空格（如 `else  s`、`))  s`）。
 * 不作用于 `} else {` 这类块级写法。
 */
export function formatMultiCommandSpacing(code: string): string {
  let result = normalizeElseIf(code);
  result = result.replace(
    new RegExp(
      `([)"'])(\\s+)(\\b(?:${NEXT_COMMAND})\\b)(?!\\s*\\{)`,
      "gi"
    ),
    "$1  $3"
  );
  result = result.replace(
    new RegExp(
      `\\b(else|elseif)(\\s+)(\\b(?:${NEXT_COMMAND})\\b)(?!\\s*\\{)`,
      "gi"
    ),
    "$1  $3"
  );
  // `.e  s` / 行首 `e  s`（else 缩写，非 else 单词内的 e）
  result = result.replace(
    new RegExp(
      `(\\.)(e)(\\s+)(\\b(?:${NEXT_COMMAND})\\b)(?!\\s*\\{)`,
      "gi"
    ),
    "$1$2  $4"
  );
  result = result.replace(
    new RegExp(
      `(^|\\s)(e)(\\s+)(\\b(?:${NEXT_COMMAND})\\b)(?!\\s*\\{)`,
      "gi"
    ),
    "$1$2  $4"
  );
  // `e  i ExpProp=2` — else/if 缩写组合，双空格，不合并为 elseif
  result = result.replace(
    /((?:\.\s*)?)(e)(\s+)(i)\b(?!\s*=)/gi,
    "$1$2  $4"
  );
  // `if ret < 0 tro`、`s err = 3 continue` 等：条件/字面量后的下一命令
  result = result.replace(
    new RegExp(
      `(\\d)(\\s+)(\\b(?:${NEXT_COMMAND})\\b)(?!\\s*\\{)`,
      "gi"
    ),
    "$1  $3"
  );
  // `tro s err`、`ts` 后接其它命令
  result = result.replace(
    new RegExp(
      `\\b(${TX_COMMAND})(\\s+)(\\b(?:${NEXT_COMMAND})\\b)(?!\\s*\\{)`,
      "gi"
    ),
    "$1  $3"
  );
  // `if loc="" &sql(...)` / `) &sql(...)` — 条件与内联 &sql 之间双空格
  result = result.replace(
    /([)"'])(\s*)((?:\.?\s*)*&sql\s*\()/gi,
    "$1  $3"
  );
  result = result.replace(
    /(\))(\s*)((?:\.?\s*)*&sql\s*\()/gi,
    "$1  $3"
  );
  return result;
}

/** 在保留字符串字面量的前提下，对整行应用多命令间距（含 `""` 与后续 `s` 的分段边界）。 */
export function formatMultiCommandSpacingLine(line: string): string {
  const segments = splitByStrings(line);
  let out = "";
  for (let i = 0; i < segments.length; i++) {
    let text = segments[i]!.text;
    if (segments[i]!.type === "code") {
      text = formatMultiCommandSpacing(text);
      const prev = segments[i - 1];
      if (
        prev &&
        ((prev.type === "string" && /["']$/.test(prev.text)) ||
          (prev.type === "code" && /[)"']\s*$/.test(prev.text)))
      ) {
        if (/^(\s*)((?:\.?\s*)*&sql\s*\(|__IRIS_EMBSQL_\d+__)/i.test(text)) {
          text = text.replace(/^(\s*)(.+)/, "  $2");
        } else {
          text = text.replace(
            new RegExp(`^(\\s*)(\\b(?:${NEXT_COMMAND})\\b)`, "i"),
            "  $2"
          );
        }
      }
    }
    out += text;
  }
  return out;
}

/** `for x{` / `}else{` → `for x {` / `} else {` */
export function formatBlockBraceSpacing(line: string): string {
  return line
    .replace(/([^\s{}])\{/g, "$1 {")
    .replace(/\}(\s*)(else|elseif)\b/gi, "} $2")
    .replace(/\}(\s*)\{/g, "} {");
}

const POSTFIX_CMD_COLON = /\b(q|continue|b|g|goto|s)\s*:/gi;

/**
 * `:` 两侧加空格（如 `for i = 1:1:n` → `1 : 1 : n`）。
 * 保留 `q:(`、`q:info` 等后置条件；for 范围仅处理数字/标识符边界，避免误拆 `1:prescLen` 语义。
 */
export function formatColonSpacing(code: string): string {
  const saved: string[] = [];
  let result = code.replace(POSTFIX_CMD_COLON, (m) => {
    saved.push(m.replace(/\s+/g, ""));
    return `__IRIS_POSTFIX_${saved.length - 1}__`;
  });

  result = result.replace(/(\d)\s*:\s*(\d)/g, "$1 : $2");
  while (/(\d):(\d)/.test(result)) {
    result = result.replace(/(\d):(\d)/g, "$1 : $2");
  }
  result = result.replace(/(\d)\s*:\s*([a-zA-Z_][\w]*)/g, "$1 : $2");
  result = result.replace(/(\d)\s*:\s*(\$)/g, "$1 : $2");
  result = result.replace(/([a-zA-Z_][\w]*)\s*:\s*(\d)/g, "$1 : $2");

  // $s(…)、$case(…) 分支：`"" : $p`、`1 : ""`、`"I" : "Y"`、`) : minTime`、`, :$p`、`, :""`
  result = result.replace(/""\s*:\s*(\$)/g, '"" : $1');
  result = result.replace(/(\d)\s*:\s*"/g, '$1 : "');
  result = result.replace(/"([^"]*)"\s*:\s*"/g, '"$1" : "');
  result = result.replace(/\)\s*:\s*([A-Za-z_$])/g, ") : $1");
  result = result.replace(/,\s*:\s*(\$)/g, ", : $1");
  result = result.replace(/,\s*:\s*"/g, ', : "');

  return result.replace(/__IRIS_POSTFIX_(\d+)__/g, (_, i) => saved[Number(i)]!);
}

/**
 * 判断/比较运算符两侧空格：'=、'[、>=、<=、>、<
 * - '> / '< / '= / '[：操作数与 ' 之间有空格，' 与运算符紧贴：DateFrom '= ""
 */
/** `InjectD["/"`、`TimeFrom[":"` → `InjectD'["/"`（后置包含运算符简写） */
export function normalizeContainsBracketSyntax(code: string): string {
  return code
    .replace(/(\w+)\[\s*"([^"]*)"/g, "$1'[\"$2\"")
    .replace(/\)\[([%]?[A-Za-z_]\w*)/g, (_m, id: string) => `)'[${id}`);
}

export function formatComparisonSpacing(code: string): string {
  let result = normalizeContainsBracketSyntax(code);
  result = result.replace(/([^'<>])\s*>\s*=\s*/g, "$1>= ");
  result = result.replace(/([\w)\]])'\s*>\s*(\S)/g, "$1 '> $2");
  result = result.replace(/([\w)\]])'\s*<\s*(\S)/g, "$1 '< $2");
  result = result.replace(/([\w)\]])'\s*=\s*/g, "$1 '= ");
  result = result.replace(/([\w)\]])'\[/g, "$1'[");
  result = result.replace(/([\w])\s*'\s*\[/g, "$1 '[");
  result = result.replace(/([^\s<>])\s*>=\s*/g, "$1>= ");
  result = result.replace(/([^\s<>])\s*<=\s*/g, "$1<= ");
  result = result.replace(/\[\s*"/g, '[ "');
  result = result.replace(/(\w+)\s*>\s*(?!=)(\w+)/g, "$1 > $2");
  result = result.replace(/(\w+)\s*<\s*(?!=)(\w+)/g, "$1 < $2");
  return result;
}

/** @deprecated 使用 formatComparisonSpacing */
export const formatNotRelationalSpacing = formatComparisonSpacing;

/**
 * 系统函数 `$` 名：有团队缩写则用缩写，否则仅小写（如 `$IsObject` → `$isobject`）。
 * 不处理 `$$` / `$$$` 宏（如 `$$$ISERR`、`$$method`）。
 */
const SYSTEM_FUNC_ABBREV: Record<string, string> = {
  i: "i",
  increment: "i",
  p: "p",
  piece: "p",
  g: "g",
  get: "g",
  o: "o",
  order: "o",
  d: "d",
  data: "d",
  l: "l",
  length: "l",
  f: "f",
  find: "f",
  e: "e",
  extract: "e",
  j: "j",
  justify: "j",
  h: "h",
  horolog: "h",
  n: "n",
  name: "n",
  q: "q",
  query: "q",
  r: "r",
  random: "r",
  s: "s",
  select: "s",
  t: "t",
  translate: "t",
  v: "v",
  view: "v",
  c: "c",
  char: "c",
  lb: "lb",
  listbuild: "lb",
  list: "li",
  listget: "lg",
  lg: "lg",
  fn: "fn",
  function: "fn",
  zd: "zd",
  zdate: "zd",
  zdh: "zdh",
  zth: "zth",
  ze: "ze",
  zerror: "ze",
  zt: "zt",
  ztrap: "zt",
  lts: "lts",
  listtostring: "lts",
  listtostrings: "lts",
};

function canonicalSystemFuncName(name: string): string {
  const key = name.toLowerCase();
  return SYSTEM_FUNC_ABBREV[key] ?? key;
}

/** `$Piece` / `$P` / `$ListBuild` → `$p` / `$lb`；跳过 `$$$` 预处理宏 */
export function formatSystemFunctionNames(code: string): string {
  return code.replace(/(?<!\$)\$(?!\$)([A-Za-z][\w]*)/g, (_, name: string) => {
    return `$${canonicalSystemFuncName(name)}`;
  });
}

const IF_PLUS_VAR_PH = "\u0000IRIS_IF_PLUS_";

/** `if +sortNum=0`：条件里 `+变量` 及紧贴的 `=` 不加空格（避免 `if` 末字 `f` 被当成 `f + sortNum`） */
function maskIfPlusVariableConditions(code: string): {
  text: string;
  saved: string[];
} {
  const saved: string[] = [];
  const save = (kw: string, name: string, rhs?: string) => {
    const expr = rhs !== undefined ? `+${name}=${rhs}` : `+${name}`;
    saved.push(expr);
    return `${kw} ${IF_PLUS_VAR_PH}${saved.length - 1}\u0000`;
  };

  let text = code.replace(
    /\b(if|elseif)\s+\+\s*([A-Za-z_%][\w.]*)(?:\s*=\s*([^\s"']+))?/gi,
    (_, kw, name, rhs) => save(kw, name, rhs)
  );
  text = text.replace(
    /(?:^|[^\w.])(i)\s+\+\s*([A-Za-z_%][\w.]*)(?:\s*=\s*([^\s"']+))?/gim,
    (full, kw, name, rhs, offset, str) => {
      const lead = str[offset] === "i" ? "" : str[offset]!;
      return `${lead}${save(kw, name, rhs)}`;
    }
  );
  return { text, saved };
}

function unmaskIfPlusVariableConditions(
  code: string,
  saved: string[]
): string {
  return code.replace(
    new RegExp(`${IF_PLUS_VAR_PH}(\\d+)\u0000`, "g"),
    (_, i) => saved[Number(i)]!
  );
}

export function formatOperatorSpacing(code: string): string {
  const { text: masked, saved: plusVarSaved } =
    maskIfPlusVariableConditions(code);
  let result = formatSystemFunctionNames(masked);
  result = formatColonSpacing(result);

  result = formatCommaSpacing(result);

  result = formatUnderscoreSpacing(result);

  result = formatComparisonSpacing(result);

  // 普通赋值 =（排除 '=）
  result = result.replace(/([^\s!<>='])\s*=\s*([^\s"'])/g, "$1 = $2");

  // Arithmetic — minus 不拆开日期/数字中的连字符（如 2016-1-26）
  result = result.replace(
    /([\w)\]"'])\s*([+*/])\s*([\w(\["'])/g,
    "$1 $2 $3"
  );
  result = result.replace(
    /([\w)\]"'])\s*-\s*([\w(\["'])/g,
    (match, left, right) => {
      if (/\d$/.test(left) && /^\d/.test(right)) return `${left}-${right}`;
      if (/^\d/.test(right)) return `${left} -${right}`;
      return `${left} - ${right}`;
    }
  );

  // .. property access — collapse spaces
  result = result.replace(/\.\s+\./g, "..");
  result = result.replace(/\.\s+#/g, ".#");

  result = result.replace(/   +/g, " ");
  result = formatParenthesizedGroupsInCode(result);
  result = unmaskIfPlusVariableConditions(result, plusVarSaved);
  return result;
}

/** `$$$ YES` / `$$$YES` → `$$$YES` */
function normalizePreprocessorMacro(macro: string): string {
  const m = macro.trim().match(/^\$\$\$\s*([A-Za-z_]\w*)\s*$/i);
  return m ? `$$$${m[1]}` : macro.trim();
}

/** @deprecated 旧版拆分逻辑；保守规则下未使用 */
function splitQuitMacroReturn(cond: string): {
  condition: string;
  trailing: string;
} | null {
  const t = cond.trim();
  let condPart: string;
  let macroRaw: string;

  const inParens = t.match(/^\((.+?)\s+(\$\$\$\s*[A-Za-z_]\w*)\)\s*$/is);
  if (inParens) {
    condPart = inParens[1]!.trim();
    macroRaw = inParens[2]!;
  } else {
    const bare = t.match(/^(.+?)\s+(\$\$\$\s*[A-Za-z_]\w*)\s*$/is);
    if (!bare) return null;
    condPart = bare[1]!.trim();
    macroRaw = bare[2]!;
  }

  if (
    !/['=<>]/.test(condPart) ||
    /'\s*\[\s*$/.test(condPart) ||
    /'\[$/.test(condPart) ||
    /'\[[^"']*\)\s*$/.test(condPart)
  ) {
    return null;
  }
  return {
    condition: `(${condPart})`,
    trailing: ` ${normalizePreprocessorMacro(macroRaw)}`,
  };
}

/** `q:(SQLCODE "…")` → 条件 `(SQLCODE)` + 尾部 ` "…"` */
function splitSqlcodeErrorReturn(cond: string): {
  condition: string;
  trailing: string;
} | null {
  const t = cond.trim();
  const inParens = t.match(
    /^\(SQLCODE\s+("(?:(?:"")|[^"])*")\)\s*$/is
  );
  if (inParens) {
    return { condition: "(SQLCODE)", trailing: ` ${inParens[1]}` };
  }
  const bare = t.match(/^(SQLCODE)\s+("(?:(?:"")|[^"])*")\s*$/is);
  if (bare) {
    return { condition: "(SQLCODE)", trailing: ` ${bare[2]}` };
  }
  return null;
}

/** 修正 `q:(EpisodeId = "" rtn)` / `q:(EpisodeId'>0 flag)` 括号包住后续词 */
function unwrapTrailingCommandParens(cond: string): string {
  const trimmed = cond.trim();
  if (splitQuitMacroReturn(trimmed) || splitSqlcodeErrorReturn(trimmed)) {
    return trimmed;
  }

  const cmd = trimmed.match(
    new RegExp(`^\\((.+)\\s+(\\b(?:${NEXT_COMMAND})\\b)\\s*\\)$`, "is")
  );
  if (cmd) return `${cmd[1]!.trim()} ${cmd[2]}`;

  const ident = trimmed.match(/^\((.+?)\s+([a-zA-Z_]\w*)\s*\)$/s);
  if (
    ident &&
    !isConcatInsidePostfixParens(trimmed) &&
    !/\$\$\$/.test(ident[1]!) &&
    !/&&|\|\|/.test(trimmed) &&
    /['=<>]/.test(ident[1]!) &&
    !/\bs\s+\w+\s*=/.test(ident[1]!) &&
    !/[\^=]\s*\([^)]*$/.test(ident[1]!)
  ) {
    return `${ident[1]!.trim()} ${ident[2]}`;
  }
  return trimmed;
}

/** 行末字符串是否为「赋值右值」而非 quit 返回值（如 IsExec = "N" 里的 "N"） */
function isAssignmentRhsBeforeLiteral(cond: string): boolean {
  return /\w\s*=\s*$/i.test(cond.trimEnd());
}

/** `q:(… "-" _ PackQty)` — 括号内仅为 quit 返回值拼接，勿拆到括号外（含赋值的 s: 尾部不在此列） */
function isConcatInsidePostfixParens(cond: string): boolean {
  const t = cond.trim();
  if (!t.startsWith("(") || !t.endsWith(")")) return false;
  const m = t.match(/^\((.+)\)\s*$/s);
  if (!m?.[1]) return false;
  const inner = m[1].trim();
  if (/\s[%]?[A-Za-z_][\w]*\s*=/.test(inner)) return false;
  return /\s_\s+[%]?[A-Za-z_][\w]*\s*$/i.test(inner);
}

/**
 * `q:(a)||((b)) rtn` — 复合条件行末的 quit 返回值（括号深度为 0，且不在 `||` 操作数内部）。
 * 与 `((ArcimId = "") FirstDayRecLoc)` 区分：后者 FirstDayRecLoc 在括号内，属于隐式 AND。
 */
function splitTopLevelQuitTrailing(cond: string): {
  condition: string;
  trailing: string;
} | null {
  const trimmed = cond.trim();
  if (isConcatInsidePostfixParens(trimmed)) return null;

  const m = trimmed.match(/^(.+?)\s+([A-Za-z_]\w*)\s*$/s);
  if (!m?.[1] || !m[2]) return null;

  const condPart = m[1].trim();
  const ident = m[2];

  if (
    /\$\$\$/.test(condPart) ||
    !/['=<>|($]/.test(condPart) ||
    isAssignmentRhsBeforeLiteral(condPart)
  ) {
    return null;
  }
  if (
    /\s(>=|<=|>|<|=)\s*$/.test(condPart) ||
    /\s'[<>]=?\s*$/.test(condPart) ||
    /'\s*(?:=|<|>|\[)?\s*$/.test(condPart)
  ) {
    return null;
  }

  let depth = 0;
  for (const ch of condPart) {
    if (ch === "(") depth++;
    else if (ch === ")") depth--;
  }
  if (depth !== 0) return null;

  if (/\|\||&&/.test(cond) && !condPart.endsWith(")")) {
    return null;
  }

  return { condition: condPart, trailing: ` ${ident}` };
}

/** `(ArcimId = "") flag` — 括号表达式后的标识符（仍在 `||` 段内，勿再外套一层 `(`） */
function splitParenGroupAndTrailingIdent(s: string): {
  expr: string;
  trailing: string;
} | null {
  const t = s.trim();
  if (!t.startsWith("(")) return null;
  let depth = 0;
  for (let i = 0; i < t.length; i++) {
    const ch = t[i]!;
    if (ch === "(") depth++;
    else if (ch === ")") depth--;
    if (depth === 0) {
      if (i === t.length - 1) {
        return null;
      }
      const rest = t.slice(i + 1).trimStart();
      const m = rest.match(/^([A-Za-z_]\w*)$/);
      if (m) {
        return { expr: t.slice(0, i + 1), trailing: ` ${m[1]}` };
      }
      return null;
    }
  }
  return null;
}

/** quit 数字返回值：`- 112` / `-112` → `-112`，`0` 保持 */
function normalizeQuitReturnNumber(raw: string): string {
  const t = raw.trim();
  if (t.startsWith("-")) {
    return "-" + t.replace(/[^\d]/g, "");
  }
  return t.replace(/\s/g, "");
}

/** 后置条件片段（含 '=、'[、比较符等），用于识别 s: 条件与赋值尾部分界 */
function looksLikePostfixCondition(expr: string): boolean {
  return (
    /'(?:=|<|>|\[)/.test(expr) ||
    /\[[\s"]/.test(expr) ||
    /\)\[/.test(expr) ||
    /\[[%]?[A-Za-z_]\w*/.test(expr) ||
    /(^|[^.'"])\s*[=<>]/.test(expr) ||
    /\|\||&&/.test(expr) ||
    /\$[a-z]/.test(expr) ||
    /^[%]?[A-Za-z_]\w*$/.test(expr.trim())
  );
}

/** 拆出开头的平衡括号条件 `( … )` 与后续尾部（用于已格式化的 `s:(cond) tail`） */
function splitLeadingBalancedParens(s: string): { head: string; tail: string } | null {
  const t = s.trimStart();
  if (!t.startsWith("(")) return null;
  let depth = 0;
  for (let i = 0; i < t.length; i++) {
    const ch = t[i]!;
    if (ch === "(") depth++;
    else if (ch === ")") {
      depth--;
      if (depth === 0) {
        const head = t.slice(0, i + 1);
        const tail = t.slice(i + 1).trimStart();
        return tail.length > 0 ? { head, tail } : null;
      }
    }
  }
  return null;
}

/** 从 `q:EpisodeId="" rtn` / `s:cond IsExec = "N"` 中拆出条件与括号外尾部 */
export function splitPostfixTail(
  cond: string,
  cmd: string
): {
  condition: string;
  trailing: string;
} {
  const trimmed = cond.trim();
  const cmdLower = cmd.toLowerCase();

  const tailRe = new RegExp(
    `^(.*)\\s+(\\b(?:${NEXT_COMMAND})\\b)\\s*$`,
    "is"
  );
  const m = trimmed.match(tailRe);
  if (m && m[1]!.trim()) {
    return { condition: m[1]!.trim(), trailing: ` ${m[2]}` };
  }

  // s: — 条件后的赋值（绝不要把 var = "x" 里的字面量当成 quit 返回值）
  if (POSTFIX_SET.test(cmdLower)) {
    const sParenFlagAssign = trimmed.match(
      /^\(([%]?[A-Za-z_]\w+)\s+([A-Za-z_]\w*\s*=\s*.+)$/s
    );
    if (sParenFlagAssign) {
      return {
        condition: sParenFlagAssign[1]!.trim(),
        trailing: ` ${sParenFlagAssign[2]!.trim()}`,
      };
    }

    const parenSplit = splitLeadingBalancedParens(trimmed);
    if (parenSplit && /[A-Za-z_]\w*\s*=/.test(parenSplit.tail)) {
      return {
        condition: parenSplit.head.trim(),
        trailing: ` ${parenSplit.tail}`,
      };
    }
    const assignTail = trimmed.match(/^(.+)\s+([A-Za-z_]\w*\s*=\s*.+)$/s);
    if (assignTail && looksLikePostfixCondition(assignTail[1]!)) {
      return {
        condition: assignTail[1]!.trim(),
        trailing: ` ${assignTail[2]!.trim()}`,
      };
    }
    return { condition: trimmed, trailing: "" };
  }

  // q / continue — 退出返回值或 flag（在条件括号外）
  if (POSTFIX_QUIT.test(cmdLower)) {
    const macroReturn = splitQuitMacroReturn(trimmed);
    if (macroReturn) {
      return macroReturn;
    }

    const sqlErrReturn = splitSqlcodeErrorReturn(trimmed);
    if (sqlErrReturn) {
      return sqlErrReturn;
    }

    const qSetInParens = trimmed.match(
      /^\((.+?"")\s+(s\s+\w+\s*=\s*.+)\)$/is
    );
    if (qSetInParens) {
      return {
        condition: `(${qSetInParens[1]!.trim()})`,
        trailing: ` ${qSetInParens[2]!.trim()}`,
      };
    }

    const returnStr = trimmed.match(/^(.+)\s+("(?:(?:"")|[^"])*")\s*$/);
    if (returnStr) {
      const condPart = returnStr[1]!.trim();
      const endsWithContainsPattern =
        /'\s*\[\s*$/.test(condPart) ||
        /'\[$/.test(condPart) ||
        /'\[[^"']*\)\s*$/.test(condPart);
      if (
        !endsWithContainsPattern &&
        /['=<>|($]/.test(condPart) &&
        !isAssignmentRhsBeforeLiteral(condPart)
      ) {
        return {
          condition: condPart,
          trailing: ` ${returnStr[2]}`,
        };
      }
    }

    const returnNum = trimmed.match(/^(.+)\s+(-\s*\d+|\d+)\s*$/);
    if (
      returnNum &&
      /['=<>|($]/.test(returnNum[1]!) &&
      !isAssignmentRhsBeforeLiteral(returnNum[1]!)
    ) {
      const tailNum = normalizeQuitReturnNumber(returnNum[2]!);
      return {
        condition: returnNum[1]!.trim(),
        trailing: ` ${tailNum}`,
      };
    }

    const topQuitTail = splitTopLevelQuitTrailing(trimmed);
    if (topQuitTail) {
      return topQuitTail;
    }

    if (!/&&|\|\|/.test(trimmed) && !isConcatInsidePostfixParens(trimmed)) {
      const identTail = trimmed.match(/^(.+?)\s+([a-zA-Z_]\w*)\s*$/);
      if (identTail && /['=<>]/.test(identTail[1]!)) {
        const condPart = identTail[1]!.trim();
        if (
          !/\$\$\$/.test(condPart) &&
          !/\s_\s*$/.test(condPart) &&
          !/\s(>=|<=|>|<|=)\s*$/.test(condPart) &&
          !/\s'[<>]=?\s*$/.test(condPart) &&
          !/'\s*(?:=|<|>|\[)?\s*$/.test(condPart)
        ) {
          return { condition: condPart, trailing: ` ${identTail[2]}` };
        }
      }
    }
  }

  return { condition: trimmed, trailing: "" };
}

/** 同一行多个后置命令（如 `q:(a)  s:(b)`）按命令拆段 */
export function splitLineIntoPostfixSegments(line: string): string[] | null {
  const starts: number[] = [];
  const re = new RegExp(POSTFIX_CMD_WORD.source, "gi");
  let m: RegExpExecArray | null;
  while ((m = re.exec(line)) !== null) {
    starts.push(m.index);
  }
  if (starts.length <= 1) return null;
  return starts.map((start, i) =>
    line.slice(start, i + 1 < starts.length ? starts[i + 1]! : line.length).trimEnd()
  );
}

/** 从 `open` 位置的 `(` 找到匹配的 `)` 下标 */
function indexOfBalancedClose(s: string, open: number): number {
  if (s[open] !== "(") return -1;
  let depth = 0;
  let inString = false;
  for (let i = open; i < s.length; i++) {
    const ch = s[i]!;
    if (inString) {
      if (ch === '"') {
        if (s[i + 1] === '"') {
          i++;
          continue;
        }
        inString = false;
      }
      continue;
    }
    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === "(") depth++;
    else if (ch === ")") {
      depth--;
      if (depth === 0) return i;
    }
  }
  return -1;
}

const EMBEDDED_SQL_OPEN = /((?:\.\s*)*)&sql\s*\(/gi;

/** 屏蔽行内 `&sql(...)`，避免 ObjectScript 缩写误改 SQL 关键字（如 set→s） */
export function maskEmbeddedSqlSpans(code: string): {
  text: string;
  spans: string[];
} {
  const spans: string[] = [];
  let out = "";
  let i = 0;
  const re = new RegExp(EMBEDDED_SQL_OPEN.source, "gi");
  let m: RegExpExecArray | null;
  while ((m = re.exec(code)) !== null) {
    out += code.slice(i, m.index);
    const parenStart = m.index + m[0].length - 1;
    const close = indexOfBalancedClose(code, parenStart);
    if (close < 0) {
      out += m[0];
      i = m.index + m[0].length;
      continue;
    }
    spans.push(code.slice(m.index, close + 1));
    out += `__IRIS_EMBSQL_${spans.length - 1}__`;
    i = close + 1;
    re.lastIndex = i;
  }
  out += code.slice(i);
  return { text: out, spans };
}

export function unmaskEmbeddedSqlSpans(text: string, spans: string[]): string {
  return text.replace(/__IRIS_EMBSQL_(\d+)__/g, (_, n) => spans[Number(n)] ?? "");
}

/** 含作为条件分组的 `(...)`（区别于 `$zbitstr(...)` 等函数括号） */
function hasPostfixConditionParens(code: string): boolean {
  const t = code.trim();
  if (/^\(/.test(t)) return true;
  if (/(?:&&|\|\|)\s*\(/.test(t)) return true;
  if (/\)\s*(?:&&|\|\|)/.test(t)) return true;
  return false;
}

function tightenPostfixOperatorsInCode(seg: string): string {
  let r = seg;
  r = r.replace(/'\s+=\s*/g, "'=");
  r = r.replace(/([^'!<>])\s+=\s*/g, "$1=");
  r = r.replace(/\s+>=\s+/g, ">=");
  r = r.replace(/\s+<=\s+/g, "<=");
  r = r.replace(/([^<>])\s+>\s*(?!=)/g, "$1>");
  r = r.replace(/([^<>])\s+<\s*(?!=)/g, "$1<");
  return r;
}

/** 无括号后置条件：收紧 `=` / `'=` / `>=` 等两侧空格（不用 mapCodeSegments，避免 `=""` 前被加空格） */
function tightenPostfixOperators(code: string): string {
  const segments: Segment[] = splitByStrings(code);
  return segments
    .map((s) =>
      s.type === "string" ? s.text : tightenPostfixOperatorsInCode(s.text)
    )
    .join("");
}

function formatCommaSpacingPreservingStrings(code: string): string {
  const segments = splitByStrings(code);
  let out = "";
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i]!;
    if (seg.type === "string") {
      out += seg.text;
      continue;
    }
    let text = formatCommaSpacing(seg.text);
    if (segments[i + 1]?.type === "string" && /,\s*$/.test(text)) {
      text = text.replace(/,\s*$/, ", ");
    }
    if (segments[i - 1]?.type === "string" && /^,\s*/.test(text)) {
      text = text.replace(/^,\s*/, ", ");
    }
    out += text;
  }
  return out;
}

function formatPostfixUnparenthesizedCond(condCode: string, cmd: string): string {
  const { condition, trailing } = splitPostfixTail(condCode, cmd);
  let cond = tightenPostfixOperators(condition);
  cond = formatCommaSpacingPreservingStrings(cond);
  return cond + trailing;
}

/** 单个 `(...)` 段：比较运算符两侧空格（含 `<=` / `>=` 左侧） */
function formatParenGroupSpacing(wrapped: string): string {
  const t = wrapped.trim();
  if (!t.startsWith("(") || !t.endsWith(")")) return wrapped;
  let body = formatParenthesizedGroupsInCode(t.slice(1, -1));
  body = formatComparisonSpacing(body);
  if (!/\(/.test(body)) {
    body = body.replace(/([^\s<>])\s*<=\s*/g, "$1 <= ");
    body = body.replace(/([^\s<>])\s*>=\s*/g, "$1 >= ");
  }
  body = body.replace(/\)\s*([<>]=?)\s*(\d)/g, ") $1 $2");
  body = mapCodeSegments(body, formatConditionSpacingInCode);
  return `(${body})`;
}

/** `(` 前为 `$p` / `##Class` / 普通标识符调用时，不作为条件括号排版 */
function isFunctionCallOpenParen(code: string, openIndex: number): boolean {
  const before = code.slice(0, openIndex).replace(/\s+$/, "");
  if (/\$[a-zA-Z][\w]*$/i.test(before)) return true;
  if (/##Class(\.[A-Za-z][\w]*)*$/i.test(before)) return true;
  const m = before.match(/([%]?[A-Za-z_][\w]*)$/);
  if (!m) return false;
  const name = m[1]!.toLowerCase();
  const blockCmd = new Set([
    "i",
    "if",
    "e",
    "else",
    "elseif",
    "f",
    "for",
    "q",
    "s",
    "w",
    "h",
    "d",
    "g",
    "b",
    "c",
    "k",
  ]);
  if (blockCmd.has(name)) return false;
  return true;
}

/** 代码段内每个 `(...)` 条件组：递归排版比较运算符 */
function formatParenthesizedGroupsInCode(code: string): string {
  if (!/\(/.test(code)) return code;

  let out = "";
  let i = 0;
  while (i < code.length) {
    if (code[i] === "(") {
      const end = indexOfBalancedClose(code, i);
      if (end < 0) {
        out += code[i]!;
        i++;
        continue;
      }
      if (isFunctionCallOpenParen(code, i)) {
        out += code.slice(i, end + 1);
      } else {
        out += formatParenGroupSpacing(code.slice(i, end + 1));
      }
      i = end + 1;
    } else {
      out += code[i]!;
      i++;
    }
  }
  return out;
}

/**
 * 后置条件排版（保守）：
 * - 无条件分组括号 → 由 formatPostfixUnparenthesizedCond 收紧运算符
 * - 含条件 `(...)` → 仅格式化括号内条件运算符两侧空格
 */
function formatPostfixCondSpacing(code: string): string {
  if (!/\(/.test(code)) return code;

  let out = "";
  let i = 0;
  while (i < code.length) {
    if (code[i] === "(") {
      const end = indexOfBalancedClose(code, i);
      if (end < 0) {
        out += code[i]!;
        i++;
        continue;
      }
      out += formatParenGroupSpacing(code.slice(i, end + 1));
      i = end + 1;
    } else {
      out += code[i]!;
      i++;
    }
  }
  return out.replace(/\s*&&\s*/g, "&&").replace(/\s*\|\|\s*/g, "||");
}

/** 格式化 `..s:cond tail` / `s:cond tail` 核心（不含行首空白） */
function formatPostfixCore(
  dots: string,
  cmd: string,
  condRaw: string
): string | null {
  if (!POSTFIX_CMD.test(`${cmd}:`)) {
    return null;
  }

  const { code: condCode, suffix: commentSuffix } = splitTrailingComment(condRaw);
  const formatted = hasPostfixConditionParens(condCode)
    ? formatPostfixCondSpacing(condCode)
    : formatPostfixUnparenthesizedCond(condCode, cmd);
  let result = `${dots}${cmd.toLowerCase()}:${formatted}`;

  if (commentSuffix) {
    result += commentSuffix;
  }

  return result;
}

/** 后置 `cmd:…` 片段结束位置（不吞掉括号外的下一命令，如 `q:(…)  d`） */
function findPostfixChunkEnd(tail: string): number {
  let depth = 0;
  const nextCmd = new RegExp(
    `^\\s+(\\b(?:${NEXT_COMMAND})\\b)(?=\\s|:|$)`,
    "i"
  );
  for (let i = 0; i < tail.length; i++) {
    const ch = tail[i]!;
    if (ch === "(") depth++;
    else if (ch === ")") depth--;
    if (depth === 0) {
      const m = tail.slice(i).match(nextCmd);
      if (m) return i;
    }
  }
  return tail.length;
}

function findPostfixStartsInCode(code: string): number[] {
  const starts: number[] = [];
  const re = new RegExp(POSTFIX_CMD_WORD.source, "gi");
  let m: RegExpExecArray | null;
  while ((m = re.exec(code)) !== null) {
    let start = m.index;
    while (start > 0 && code[start - 1] === ".") {
      start--;
    }
    if (!starts.includes(start)) {
      starts.push(start);
    }
  }
  return starts;
}

function getPostfixChunkRanges(code: string): { start: number; end: number }[] {
  const starts = findPostfixStartsInCode(code);
  const ranges: { start: number; end: number }[] = [];
  for (let i = 0; i < starts.length; i++) {
    const start = starts[i]!;
    let end = i + 1 < starts.length ? starts[i + 1]! : code.length;
    const chunk = code.slice(start, end);
    const colonAt = chunk.indexOf(":");
    if (colonAt >= 0) {
      const tail = chunk.slice(colonAt + 1);
      const chunkEnd = findPostfixChunkEnd(tail);
      end = start + colonAt + 1 + chunkEnd;
    }
    ranges.push({ start, end });
  }
  return ranges;
}

/**
 * 行级运算符排版时跳过整条后置 `q:`/`s:` 片段（括号内已由 formatPostfixLine 处理）。
 */
export function applyLineSpacingPreservingPostfix(
  line: string,
  apply: (code: string) => string
): string {
  const lead = line.match(/^(\s*)/)?.[1] ?? "";
  const rest = line.slice(lead.length);
  const ranges = getPostfixChunkRanges(rest);
  if (ranges.length === 0) {
    return apply(line);
  }

  const saved: string[] = [];
  let masked = rest;
  for (let i = ranges.length - 1; i >= 0; i--) {
    const { start, end } = ranges[i]!;
    const ph = `\u0000IRIS_PFCHUNK${saved.length}\u0000`;
    saved.push(rest.slice(start, end));
    masked = masked.slice(0, start) + ph + masked.slice(end);
  }

  let spaced = apply(lead + masked);
  for (let i = 0; i < saved.length; i++) {
    const ph = `\u0000IRIS_PFCHUNK${i}\u0000`;
    const chunk = saved[i]!;
    spaced = spaced.replace(ph, () => chunk);
  }
  return spaced;
}

/** 格式化一行内全部后置命令（含 `..s:`、行内 `q:…  d`） */
export function formatPostfixLine(line: string): string | null {
  const lead = line.match(/^(\s*)/)?.[1] ?? "";
  const rest = line.slice(lead.length);
  const starts = findPostfixStartsInCode(rest);
  if (starts.length === 0) {
    return null;
  }

  let result = rest;
  for (let i = starts.length - 1; i >= 0; i--) {
    const start = starts[i]!;
    let end = i + 1 < starts.length ? starts[i + 1]! : rest.length;
    let chunk = rest.slice(start, end);
    const colonAt = chunk.indexOf(":");
    if (colonAt >= 0) {
      const tail = chunk.slice(colonAt + 1);
      const chunkEnd = findPostfixChunkEnd(tail);
      if (chunkEnd < tail.length) {
        end = start + colonAt + 1 + chunkEnd;
        chunk = rest.slice(start, end);
      }
    }
    const cmdM = chunk.match(/^(\.+)?(\w+)\s*:\s*([\s\S]*)$/i);
    if (!cmdM) {
      return null;
    }
    const core = formatPostfixCore(cmdM[1] ?? "", cmdM[2]!, cmdM[3]!);
    if (core === null) {
      return null;
    }
    const tailWs = chunk.match(/\s+$/)?.[0] ?? "";
    result = result.slice(0, start) + core + tailWs + result.slice(end);
  }

  return lead + result;
}

export function formatPostfixCondition(line: string): string | null {
  const m = line.match(/^(\s*)(\.+)?(\w+)\s*:\s*(.+)$/is);
  if (!m) {
    return null;
  }

  const [, sp, dots = "", cmd, condRaw] = m;
  const core = formatPostfixCore(dots, cmd, condRaw);
  if (core === null) {
    return null;
  }
  return `${sp}${core}`;
}

/** 将多条件片段规范为单层括号 `( … )`，避免 `((TimeFrom>repTime)` 多余 `(` */
/** `_` 拼接：空白字面量 `" "_var` 保持紧贴；表达式间 `_` → ` _ `；标识符内 `_` 不拆开 */
export function formatUnderscoreSpacing(code: string): string {
  const ids: string[] = [];
  const us: string[] = [];
  let result = code.replace(
    /[%]?[A-Za-z_][\w.]*(?:_[%]?[A-Za-z_][\w.]*)+/g,
    (m) => {
      ids.push(m);
      return `\u0000ID${ids.length - 1}\u0000`;
    }
  );
  result = result.replace(
    /"(\s*)"\s*_\s*([%]?[A-Za-z_][\w]*)/g,
    (m) => {
      us.push(m.replace(/\s*_\s*/, "_"));
      return `\u0000US${us.length - 1}\u0000`;
    }
  );
  result = result.replace(/([%]?[A-Za-z_][\w]*)\s*_\s*"/g, '$1_"');
  result = result.replace(/\s*_\s*/g, " _ ");
  result = result.replace(/\u0000US(\d+)\u0000/g, (_, i) => us[Number(i)]!);
  return result.replace(/\u0000ID(\d+)\u0000/g, (_, i) => ids[Number(i)]!);
}

/** `((ArcimId = "") FirstDayRecLoc)` — 外层括号内为「条件 + 隐式 AND 标识符」 */
function splitDoubleParenImplicitAnd(core: string): {
  condition: string;
  ident: string;
} | null {
  const m = core.trim().match(/^\(\((.+?)\)\s+([A-Za-z_]\w*)\)$/s);
  if (!m?.[1] || !m[2]) return null;
  return { condition: m[1].trim(), ident: m[2] };
}

/** `((ArcimId = ""))` — 仅双层括号包裹单一条件 */
function splitDoubleParenCondition(core: string): string | null {
  const m = core.trim().match(/^\(\((.+)\)\)$/s);
  if (!m?.[1]) return null;
  const inner = m[1].trim();
  if (/&&|\|\||[&|]/.test(inner)) return null;
  return inner;
}

function formatPostfixConditionCore(core: string): string {
  core = formatComparisonSpacing(core);
  const spaced = mapCodeSegments(core, formatConditionSpacingInCode).trim();
  if (/^'/.test(spaced)) {
    return spaced;
  }
  if (isBalancedWrapped(spaced)) {
    return spaced;
  }
  if (spaced.startsWith("(")) {
    return spaced;
  }
  return `(${spaced})`;
}

/** `)` 是否属于 `'[…` / `'=…` 包含判断字面量，而非分组括号 */
function isContainsOperatorCloseParen(before: string): boolean {
  return /'\[\s*$/.test(before) || /'\[[^"]*$/.test(before) || /'=\s*$/.test(before);
}

/** 整段已被一对括号完整包裹（如 `((a)&&(b))`），避免重复叠括号 */
function isBalancedWrapped(s: string): boolean {
  const t = s.trim();
  if (!t.startsWith("(") || !t.endsWith(")")) return false;
  if (splitDoubleParenImplicitAnd(t)) return false;
  let depth = 0;
  let inString = false;
  for (let i = 0; i < t.length; i++) {
    const ch = t[i]!;
    if (inString) {
      if (ch === '"') {
        if (t[i + 1] === '"') {
          i++;
          continue;
        }
        inString = false;
      }
      continue;
    }
    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === "(") depth++;
    else if (ch === ")") {
      if (isContainsOperatorCloseParen(t.slice(0, i))) {
        continue;
      }
      depth--;
      if (depth === 0 && i < t.length - 1) return false;
    }
  }
  return depth === 0;
}

function normalizePostfixPart(part: string): string {
  const { code, suffix } = splitTrailingComment(part);
  let core = code.trim();

  const dblAnd = splitDoubleParenImplicitAnd(core);
  if (dblAnd) {
    const inner = formatPostfixConditionCore(`(${dblAnd.condition})`);
    return `((${inner.slice(1, -1)}) ${dblAnd.ident})${suffix}`;
  }

  const dblCond = splitDoubleParenCondition(core);
  if (dblCond) {
    const inner = formatPostfixConditionCore(`(${dblCond})`);
    return `(${inner})${suffix}`;
  }

  const parenIdent = splitParenGroupAndTrailingIdent(core);
  let trailingIdent = "";
  if (parenIdent) {
    core = parenIdent.expr;
    trailingIdent = parenIdent.trailing;
  } else {
    core = stripOuterParens(core);
  }

  const exprOut = formatPostfixConditionCore(core);
  return `${exprOut}${trailingIdent}${suffix}`;
}

function formatPostfixOrPart(cond: string): string {
  const parts = splitTopLevel(cond, "||");
  return parts.map((part) => normalizePostfixPart(part)).join("||");
}

export function formatPostfixExpression(cond: string): string {
  const parts = splitTopLevel(cond, "&&");
  return parts.map((part) => formatPostfixOrPart(part)).join("&&");
}

export function splitTopLevelAnd(cond: string): string[] {
  return splitTopLevel(cond, "&&");
}

function splitTopLevel(cond: string, op: "&&" | "||"): string[] {
  const parts: string[] = [];
  let depth = 0;
  let inString = false;
  let start = 0;
  let i = 0;
  const pattern = op === "&&" ? /^\s*&&\s*/ : /^\s*\|\|\s*/;
  while (i < cond.length) {
    const ch = cond[i]!;
    if (inString) {
      if (ch === '"') {
        if (cond[i + 1] === '"') {
          i += 2;
          continue;
        }
        inString = false;
      }
      i++;
      continue;
    }
    if (ch === '"') {
      inString = true;
      i++;
      continue;
    }
    if (ch === "(") depth++;
    else if (ch === ")") depth--;
    if (depth === 0) {
      const m = cond.slice(i).match(pattern);
      if (m) {
        parts.push(cond.slice(start, i).trim());
        start = i + m[0]!.length;
        i = start;
        continue;
      }
    }
    i++;
  }
  parts.push(cond.slice(start).trim());
  return parts.filter(Boolean);
}

export function stripOuterParens(s: string): string {
  const t = s.trim();
  if (isBalancedWrapped(t)) {
    return t.slice(1, -1).trim();
  }
  return t;
}

/** Spacing rules inside postfix / parenthesized conditions (no bare `)` tokens). */
export function formatCommaSpacing(code: string): string {
  let result = code.replace(/,([^\s])/g, ", $1");
  result = result.replace(/\s+,/g, ",");
  return result;
}

export function formatConditionSpacing(code: string): string {
  let result = formatColonSpacing(code);
  result = formatCommaSpacing(result);
  result = formatUnderscoreSpacing(result);
  result = formatComparisonSpacing(result);
  result = result.replace(/(\w)\s*=\s*"/g, '$1 = "');
  result = result.replace(/([^\s!<>='])\s*=\s*([^\s"'])/g, "$1 = $2");
  result = result.replace(/   +/g, " ");
  return result;
}

/** 后置条件括号内：代码段排版（比较符已在整段上处理过） */
function formatConditionSpacingInCode(code: string): string {
  let result = formatSystemFunctionNames(code);
  result = formatColonSpacing(result);
  result = formatCommaSpacing(result);
  result = formatUnderscoreSpacing(result);
  result = result.replace(/(\w)\s*=\s*"/g, '$1 = "');
  result = result.replace(/([^\s!<>='])\s*=\s*([^\s"'])/g, "$1 = $2");
  result = result.replace(/   +/g, " ");
  return result;
}

export function isMethodHeader(line: string): boolean {
  return METHOD_HEADER.test(line.trim());
}

/**
 * ObjectScript 标签行（须在列 1，不能与方法体命令同级缩进）。
 * 见 IRIS：标签为未缩进标识符，可单独一行或与命令同行（标签与命令间用空格分隔）。
 */
export function isRoutineLabelLine(line: string): boolean {
  const t = line.trim();
  if (!t || t === "{" || t === "}") return false;
  if (isMethodHeader(t)) return false;
  if (t.startsWith("#") || t.startsWith("//") || t.startsWith(".")) return false;
  if (/^&\w/i.test(t)) return false;

  const m = t.match(/^([%]?[A-Za-z][\w]*)(?:\([^)]*\))?(?:\s+(.*))?$/);
  if (!m) return false;

  const rest = m[2];
  // 单独成行的 unlock 多为标签（如 d UnLock 的入口），不是 unlock 命令
  if (
    (rest === undefined || rest === "") &&
    m[1]!.toLowerCase() === "unlock"
  ) {
    return true;
  }

  if (LINE_COMMAND.test(t)) return false;

  if (rest === undefined || rest === "") {
    const name = m[1]!.toLowerCase();
    if (STANDALONE_COMMAND_ABBREV.has(name)) return false;
    return true;
  }

  const restTrimmed = rest.trim();
  // `f s …` / `i …` / `e …` 为 for/if/else 缩写行，不是「标签 + 命令」
  if (/^[fie]$/i.test(m[1]!) && LINE_COMMAND.test(restTrimmed)) {
    return false;
  }
  if (restTrimmed.startsWith("//")) return true;
  if (LINE_COMMAND.test(restTrimmed)) return true;
  if (POSTFIX_CMD.test(restTrimmed)) return true;

  return false;
}

const GOTO_LABEL_REF = /\b(?:d|g|goto)\s+([%]?[A-Za-z][\w]*)/gi;

/** 在先前代码中查找 `d UnLock` / `g Label` 等处引用的标签名大小写 */
export function findLabelReferenceCase(
  lines: string[],
  beforeIndex: number,
  labelName: string
): string | undefined {
  const want = labelName.toLowerCase();
  for (let i = 0; i < beforeIndex && i < lines.length; i++) {
    const line = lines[i] ?? "";
    GOTO_LABEL_REF.lastIndex = 0;
    let m: RegExpExecArray | null;
    while ((m = GOTO_LABEL_REF.exec(line)) !== null) {
      if (m[1]!.toLowerCase() === want) return m[1];
    }
  }
  return undefined;
}

/** 标签行：保留标识符大小写；`ErrTag q …` 仅格式化标签后的命令部分 */
export function formatRoutineLabelLine(
  line: string,
  lines: string[],
  lineIndex: number,
  formatRest: (segment: string) => string
): string {
  const t = line.trim();
  const m = t.match(/^([%]?[A-Za-z][\w]*)(?:\([^)]*\))?(?:\s+(.*))?$/s);
  if (!m?.[1]) return formatRest(line);

  const label = findLabelReferenceCase(lines, lineIndex, m[1]) ?? m[1];
  const parenMatch = t.match(/^[%]?[A-Za-z][\w]*(\([^)]*\))/);
  const paren = parenMatch?.[1] ?? "";
  const rest = m[2];
  if (rest === undefined || rest.trim() === "") {
    return `${label}${paren}`;
  }
  return `${label}${paren} ${formatRest(rest)}`;
}

export function isBlank(line: string): boolean {
  return line.trim() === "";
}

/** 整行以 `;` 开头的 ObjectScript 注释（与方法体同级缩进，不参与 `{`/`}` 块层级）。 */
export function isSemicolonCommentLine(line: string): boolean {
  const t = line.trimStart();
  return t.length > 0 && t.startsWith(";") && !t.startsWith("#;");
}

/** `//` 行注释 */
export function isSlashSlashCommentLine(line: string): boolean {
  const t = line.trimStart();
  return t.startsWith("//");
}

/** 预处理器禁用代码 `#; …`（整段视为注释，不排版、不计入 `{`/`}` 层级） */
export function isHashSemicolonCommentLine(line: string): boolean {
  const t = line.trimStart();
  return t.startsWith("#;");
}

/** `;` / `//` / `#;` 注释行 */
export function isDisabledOrCommentLine(line: string): boolean {
  return (
    isSemicolonCommentLine(line) ||
    isSlashSlashCommentLine(line) ||
    isHashSemicolonCommentLine(line)
  );
}

/** 去掉 `;` / `;;` 之后用于对齐被注释代码的空白，输出顶格注释行。 */
export function normalizeSemicolonCommentLine(line: string): string {
  const m = line.match(/^(;+)(\s*)([\s\S]*)$/);
  if (!m) return line;
  const body = m[3]!.replace(/^\s+/, "");
  return body ? `${m[1]}${body}` : m[1]!;
}

/** `#;` 后保留原文，仅规范 `#;` 与正文之间的空白 */
export function normalizeHashSemicolonCommentLine(line: string): string {
  const m = line.match(/^(\s*#;)(\s*)([\s\S]*)$/);
  if (!m) return line.trimStart();
  const body = m[3] ?? "";
  return body ? `#; ${body.replace(/^\s+/, "")}` : "#;";
}

/** If header and `{` are on same line, split them. */
export function ensureAllmanBrace(lines: string[], idx: number): string[] {
  const line = lines[idx] ?? "";
  const trimmed = line.trim();
  if (!METHOD_HEADER.test(trimmed)) return lines;

  if (trimmed.endsWith("{")) {
    const out = [...lines];
    out[idx] = trimmed.slice(0, -1).trimEnd();
    out.splice(idx + 1, 0, "{");
    return out;
  }

  const next = lines[idx + 1]?.trim();
  if (next === "{") return lines;

  const out = [...lines];
  out.splice(idx + 1, 0, "{");
  return out;
}
