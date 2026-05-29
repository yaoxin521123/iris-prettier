import { splitByStrings } from "./tokenize.js";
import { embeddedSqlParenDepth } from "./sql.js";

const BLOCK_CMD =
  /^(if|for|elseif|else|i|f|e|while|try|catch)\b(?=\s|$)/i;

/** IRIS 区间 for：`i = 1 : 1 : n` / `i = 1 : 1 : $l(a,b)` / `date = from : 1 : to` */
const RANGE_FOR_HEADER =
  /^\w+\s*=\s*[^:]+\s*:\s*[^:]+\s*:\s*.+$/;

/** 已打开的区间 for：`for i = 1 : 1 : n {` 后紧跟 `}` 再跟点行（二次转换修复） */
const RANGE_FOR_OPEN =
  /^\s*for\s+(\w+\s*=\s*[^:]+\s*:\s*[^:]+\s*:\s*.+?)\s*\{\s*$/i;

/** `..GetName()` / `..#prop` — 非点块语法（排除 `i (` / `f s` 等块命令） */
function isMethodDotCall(dots: string, content: string): boolean {
  if (dots.length < 2) return false;
  const t = content.trimStart();
  if (/^(i|if|f|for|e|else)\b/i.test(t)) return false;
  if (t.startsWith("#")) return true;
  if (/^[A-Z][A-Za-z0-9]*\s*\(/.test(t)) return true;
  if (/^[A-Z][A-Za-z0-9]*$/.test(t)) return true;
  return false;
}

export interface ParsedLine {
  indent: string;
  dotDepth: number;
  content: string;
  raw: string;
  isDotSyntax: boolean;
  opensBlock: boolean;
  isElse: boolean;
  isFor: boolean;
  isIf: boolean;
  bodyWithoutD: string;
}

export function parseDotLine(line: string): ParsedLine {
  const m = line.match(/^(\s*)(.*)$/);
  const indent = m?.[1] ?? "";
  const body = m?.[2] ?? line;
  let dotDepth = 0;
  let content = body;
  let isDotSyntax = false;

  const dotM = body.match(/^(\.+)(.*)$/s);
  if (dotM) {
    const dots = dotM[1]!;
    const rest = dotM[2] ?? "";
    if (isMethodDotCall(dots, rest)) {
      return {
        indent,
        dotDepth: 0,
        content: body,
        raw: line,
        isDotSyntax: false,
        opensBlock: false,
        isElse: false,
        isFor: false,
        isIf: false,
        bodyWithoutD: body.trimEnd(),
      };
    }
    dotDepth = dots.length;
    content = rest;
    isDotSyntax = true;
  }

  const opensBlock =
    /\s+d(\s*\/\/[^\n]*)?\s*$/i.test(content) && !/\{\s*$/.test(content.trim());
  const bodyWithoutD = (
    opensBlock
      ? content.replace(/\s+d(\s*\/\/[^\n]*)?\s*$/i, "")
      : content
  ).trim();

  const isElse = /^(e|else)\s*$/i.test(bodyWithoutD);
  const isFor =
    /^(f|for)\b/i.test(bodyWithoutD) &&
    !/^\s*(s|q|w|h|k|g|b|d)\b/i.test(bodyWithoutD);
  const isIf =
    /^(i|if)\b/i.test(bodyWithoutD) &&
    !/^\s*(s|q|w|h|k|g|b|d|f)\b/i.test(bodyWithoutD);

  return {
    indent,
    dotDepth,
    content,
    raw: line,
    isDotSyntax,
    opensBlock,
    isElse,
    isFor,
    isIf,
    bodyWithoutD,
  };
}

/** 条件中的 `,` → `&&`（跳过字符串；含全局 `^` / `$d(` 时不转换） */
export function commaToAndInCondition(cond: string): string {
  const trimmed = cond.trim();
  if (/\^|\$[a-z]+\(/i.test(trimmed)) {
    return trimmed;
  }

  const segments = splitByStrings(trimmed);
  const joined = segments
    .map((seg) => {
      if (seg.type === "string") return seg.text;
      const parts = seg.text.split(",");
      if (parts.length <= 1) return seg.text;
      return parts
        .map((p, i) => (i === 0 ? p.trimEnd() : p.trimStart()))
        .join(")&&(");
    })
    .join("");
  if (joined.includes(")&&(")) {
    return `(${joined})`;
  }
  return joined;
}

function formatIfCondition(cond: string): string {
  const c = cond.trim();
  if (!c) return "()";
  if (/^['$!]/.test(c) || /\^/.test(c)) {
    return c;
  }
  const converted = commaToAndInCondition(c);
  if (converted.startsWith("(") && converted.endsWith(")")) {
    return converted;
  }
  if (converted.includes(")&&(")) {
    return converted;
  }
  return `(${converted})`;
}

function expandBlockKeyword(body: string): string {
  return body
    .replace(/^i\b/i, "if")
    .replace(/^f\b/i, "for")
    .replace(/^e\b/i, "else");
}

function stripBlockPrefix(body: string, kind: "if" | "for" | "else"): string {
  const t = body.trimStart();
  if (kind === "if") {
    return t.replace(/^(if|i)\s+/i, "").trim();
  }
  if (kind === "for") {
    return t.replace(/^(for|f)\s+/i, "").trim();
  }
  return t.replace(/^(else|e)\s*/i, "").trim();
}

/** 行内 `s x="" f s y=$o() q:y=""` → 前缀语句 + for 头（`;` 注释行不参与） */
function splitEmbeddedFor(
  bodyWithoutD: string
): { prefix: string; forHeader: string } | null {
  const t = bodyWithoutD.trimStart();
  if (t.startsWith(";") || t.startsWith("//")) return null;

  const m = bodyWithoutD.match(/^(.+?)\s+\bf\b\s+(s\s.+)$/i);
  if (!m) return null;
  const prefix = m[1]!.trim();
  const forHeader = m[2]!.trim();
  if (!prefix || !/^s\s/i.test(forHeader)) return null;
  if (/^;/.test(prefix)) return null;
  return { prefix, forHeader };
}

/**
 * for 循环体内 quit 语义（不含 for 头 `f s x=$o() q:cond d` 中的 q:，该头由 splitEmbeddedFor 原样输出）：
 * - 独立行 `q:cond` → `continue:cond`
 * - 同行多命令后的 ` q:` / 行末 ` q` → ` continue:` / ` continue`
 * 普通 if 块内不调用本函数，保留 `q:`。
 */
export function convertLoopQuitToContinue(text: string): string {
  const trimmed = text.trimStart();
  if (/^\/\//.test(trimmed) || /^;\s*/.test(trimmed)) {
    return text;
  }
  let out = text.replace(/^q:/i, "continue:");
  out = out.replace(/\s+q:/gi, " continue:");
  out = out.replace(/\s+q(\s*(?:\/\/.*)?)$/i, " continue$1");
  return out;
}

/** 合并无点前缀的 &sql 物理续行（列清单 / values 换行） */
function mergeEmbeddedSqlContinuations(
  lines: string[],
  startIdx: number,
  end: number
): { mergedRaw: string; index: number } {
  let merged = lines[startIdx]!;
  let i = startIdx + 1;
  while (i < end && embeddedSqlParenDepth(merged) > 0) {
    const next = lines[i]!;
    if (/^\s*$/.test(next)) {
      i++;
      continue;
    }
    if (parseDotLine(next).isDotSyntax) {
      break;
    }
    merged = `${merged.trimEnd()} ${next.trim()}`;
    i++;
  }
  return { mergedRaw: merged, index: i };
}

function dotLinePlainText(p: ParsedLine, inForLoop: boolean): string {
  let t = p.bodyWithoutD.trimStart();
  if (/^;\s*/.test(t) || t === ";") {
    t = t.replace(/^;\s*/, "; ");
  }
  if (inForLoop) {
    t = convertLoopQuitToContinue(t);
  }
  return t.trimEnd();
}

function isElseAtDepth(pe: ParsedLine, depth: number): boolean {
  if (!pe.isElse || !pe.opensBlock) return false;
  if (pe.isDotSyntax) return pe.dotDepth === depth;
  return depth === 0;
}

/** `else  s x=""` / `.e  s x=""`：无行末 `d`，else 体为同行后续命令 */
function elseInlineBodyFromLine(pe: ParsedLine): string | null {
  const m = pe.bodyWithoutD.match(/^(e|else)\s+(.+)$/is);
  if (!m?.[2]) return null;
  const rest = m[2]!.trim();
  if (/^(i|if)\b/i.test(rest)) return null;
  return rest;
}

function isElseInlineAtDepth(pe: ParsedLine, depth: number): boolean {
  if (elseInlineBodyFromLine(pe) === null) return false;
  if (pe.isDotSyntax) return pe.dotDepth === depth;
  return depth === 0;
}

function formatElseInlineBody(pe: ParsedLine, inForLoop: boolean): string {
  const body = elseInlineBodyFromLine(pe)!;
  return inForLoop ? convertLoopQuitToContinue(body) : body.trimEnd();
}

/** 行内 if 条件后的首个 ObjectScript 命令（用于从条件中切分 then 体） */
const IF_INLINE_CMD_WORD =
  "s|q|w|h|k|g|b|f|t|d|c|n|j|v|o";
const IF_INLINE_CMD_SPLIT = new RegExp(
  `\\s+(${IF_INLINE_CMD_WORD})\\b`,
  "i"
);

/** 剥掉行首 `if` / `i` 命令字；`i = 1:1:n` 为 for 下标，不是 if */
function stripIfCommandPrefix(bodyWithoutD: string): string | null {
  if (/^if\s+/i.test(bodyWithoutD)) {
    return bodyWithoutD.replace(/^if\s+/i, "").trimStart();
  }
  if (/^i\s+/i.test(bodyWithoutD) && !/^i\s*=/i.test(bodyWithoutD)) {
    return bodyWithoutD.replace(/^i\s+/i, "").trimStart();
  }
  return null;
}

/**
 * `i +sortNum=0 s index="1"` / `i count=0  w ... q ""` / `.i cond s cmd`：
 * 无行末 `d`，then 为条件后的全部命令（可含 `w` + `q` 等多命令）。
 */
function ifInlinePartsFromLine(pe: ParsedLine): { cond: string; body: string } | null {
  const rest = stripIfCommandPrefix(pe.bodyWithoutD);
  if (pe.opensBlock || rest === null) {
    return null;
  }
  const codePart = rest.split("//")[0]!.trimEnd();

  // 已是块级 `If ind="" {` / `If ind="" { // …`（非 `i cond  cmd` 行内写法）
  if (/\{/.test(codePart)) {
    return null;
  }

  // `for i = 1 : 1 : n  q:…` 拆出后的 for 头，不是 `if i = …`
  if (RANGE_FOR_HEADER.test(codePart.replace(/\s+q:.*/i, "").trim())) {
    return null;
  }

  const dbl = codePart.match(/^([^\s].*?)\s{2,}([\s\S]+)$/);
  if (dbl?.[1] && dbl[2]) {
    const left = dbl[1]!.trim();
    // 仅 `i count=0  w ...`：条件与命令之间双空格；`s ret = 1  q` 中尾部双空格不算
    if (!new RegExp(`\\s+(${IF_INLINE_CMD_WORD})\\b`, "i").test(left)) {
      return { cond: left, body: dbl[2]!.trim() };
    }
  }

  const cmdRe = new RegExp(IF_INLINE_CMD_SPLIT.source, IF_INLINE_CMD_SPLIT.flags);
  let m: RegExpExecArray | null;
  while ((m = cmdRe.exec(codePart)) !== null) {
    const cond = codePart.slice(0, m.index).trim();
    if (!cond) continue;
    return { cond, body: rest.slice(m.index).trim() };
  }
  return null;
}

function ifInlineMatchesDepth(pe: ParsedLine, depth: number): boolean {
  if (ifInlinePartsFromLine(pe) === null) return false;
  if (pe.isDotSyntax) return pe.dotDepth === depth;
  return depth === 0;
}

function formatIfInlineBody(body: string, inForLoop: boolean): string {
  if (inForLoop) {
    return convertLoopQuitToContinue(body.trimEnd());
  }
  return body.trimEnd();
}

/** if 体之后衔接的 else / elseif */
function appendElseBranches(
  lines: string[],
  startIdx: number,
  to: number,
  depth: number,
  lineIndent: string,
  childIndent: string,
  inForLoop: boolean,
  out: string[]
): number {
  let i = startIdx;
  if (i >= to) return i;
  const pe = parseDotLine(lines[i]!);
  if (isElseIfAtDepth(pe, depth)) {
    out.push(
      `${lineIndent}} elseif ${formatIfCondition(elseIfConditionFromLine(pe))} {`
    );
    const elseifChild = collectBlockBody(
      lines,
      i + 1,
      to,
      pe,
      depth,
      childIndent,
      inForLoop
    );
    out.push(...elseifChild.output);
    i = elseifChild.index;
    if (i < to) {
      i = appendElseBranches(
        lines,
        i,
        to,
        depth,
        lineIndent,
        childIndent,
        inForLoop,
        out
      );
    }
    return i;
  }
  if (isElseAtDepth(pe, depth)) {
    out.push(`${lineIndent}} else {`);
    const elseChild = collectBlockBody(
      lines,
      i + 1,
      to,
      pe,
      depth,
      childIndent,
      inForLoop
    );
    out.push(...elseChild.output);
    return elseChild.index;
  }
  if (isElseInlineAtDepth(pe, depth)) {
    out.push(`${lineIndent}} else {`);
    out.push(`${childIndent}${formatElseInlineBody(pe, inForLoop)}`);
    return i + 1;
  }
  return i;
}

/** 点语法 `.e  i cond d` / `e  i cond d` → 块级 elseif */
function isElseIfAtDepth(pe: ParsedLine, depth: number): boolean {
  if (!pe.opensBlock || !/^(e|else)\s+(i|if)\s+/i.test(pe.bodyWithoutD)) {
    return false;
  }
  if (pe.isDotSyntax) return pe.dotDepth === depth;
  return depth === 0;
}

function elseIfConditionFromLine(pe: ParsedLine): string {
  const m = pe.bodyWithoutD.match(/^(e|else)\s+(i|if)\s+(.+)$/is);
  return m?.[3]?.trim() ?? "";
}

/** 同级块命令：`.e  i d`、`.i d`、`.e d`、`.f d` */
function isDotBlockSiblingOpener(p: ParsedLine): boolean {
  if (!p.opensBlock) return false;
  if (/^(e|else)\s+(i|if)\s+/i.test(p.bodyWithoutD)) return true;
  return p.isElse || p.isIf || p.isFor;
}

/** `.i d` 块体：同深度 `.s` 等直到同级 `.e  i` / `.e` / `.i` */
function convertDotBodyLines(
  lines: string[],
  from: number,
  to: number,
  bodyDotDepth: number,
  indent: string,
  inForLoop: boolean
): { output: string[]; index: number } {
  const out: string[] = [];
  let i = from;

  while (i < to) {
    const p0 = parseDotLine(lines[i]!);
    if (!p0.isDotSyntax) {
      break;
    }
    if (p0.dotDepth < bodyDotDepth) {
      break;
    }
    if (p0.dotDepth === bodyDotDepth && isDotBlockSiblingOpener(p0)) {
      break;
    }
    if (p0.dotDepth > bodyDotDepth) {
      const deeper = convertDotLines(
        lines,
        i,
        to,
        p0.dotDepth,
        indent + "\t",
        inForLoop
      );
      out.push(...deeper.output);
      i = deeper.index;
      continue;
    }
    let rawLine = lines[i]!;
    let nextIdx = i + 1;
    if (/&sql\s*\(/i.test(rawLine) && embeddedSqlParenDepth(rawLine) > 0) {
      const mc = mergeEmbeddedSqlContinuations(lines, i, to);
      rawLine = mc.mergedRaw;
      nextIdx = mc.index;
    }
    const pLine = parseDotLine(rawLine);
    if (ifInlineMatchesDepth(pLine, bodyDotDepth)) {
      const parts = ifInlinePartsFromLine(pLine)!;
      const cond = stripBlockPrefix(
        expandBlockKeyword(`if ${parts.cond}`),
        "if"
      );
      out.push(`${indent}if ${formatIfCondition(cond)} {`);
      out.push(`${indent}\t${formatIfInlineBody(parts.body, inForLoop)}`);
      i = nextIdx;
      out.push(`${indent}}`);
      continue;
    }
    out.push(`${indent}${dotLinePlainText(pLine, inForLoop)}`);
    i = nextIdx;
  }

  return { output: out, index: i };
}

function collectBlockBody(
  lines: string[],
  from: number,
  to: number,
  opener: ParsedLine,
  blockDepth: number,
  indent: string,
  inForLoop: boolean
): { output: string[]; index: number } {
  if (opener.isDotSyntax) {
    return convertDotBodyLines(
      lines,
      from,
      to,
      opener.dotDepth,
      indent,
      inForLoop
    );
  }
  return convertDotLines(lines, from, to, blockDepth + 1, indent, inForLoop);
}

function methodHasDotSyntax(slice: string[]): boolean {
  return slice.some((l) => {
    const p = parseDotLine(l);
    return (
      p.isDotSyntax ||
      (p.dotDepth === 0 && p.opensBlock && (p.isIf || p.isFor)) ||
      ifInlinePartsFromLine(p) !== null ||
      elseInlineBodyFromLine(p) !== null
    );
  });
}

/** 跳过已转换的 `{ ... }` 块（避免在点语法区域内误断） */
function skipBraceBlock(lines: string[], from: number, to: number): number {
  let depth = 0;
  let started = false;
  for (let i = from; i < to; i++) {
    const t = lines[i]!;
    for (let k = 0; k < t.length; k++) {
      if (t[k] === "{") {
        depth++;
        started = true;
      } else if (t[k] === "}") {
        depth--;
      }
    }
    if (started && depth === 0) return i + 1;
  }
  return from;
}

/**
 * 按点深度递归转换：区间 for、行内 `f s … q:… d`、嵌套 `i … d` / `e d`。
 */
function convertDotLines(
  lines: string[],
  from: number,
  to: number,
  depth: number,
  indent: string,
  inForLoop = false
): { output: string[]; index: number } {
  const out: string[] = [];
  let i = from;

  while (i < to) {
    let rawLine = lines[i]!;
    let nextIdx = i + 1;
    if (/&sql\s*\(/i.test(rawLine) && embeddedSqlParenDepth(rawLine) > 0) {
      const mc = mergeEmbeddedSqlContinuations(lines, i, to);
      rawLine = mc.mergedRaw;
      nextIdx = mc.index;
    }
    const p = parseDotLine(rawLine);

    if (p.isDotSyntax && p.dotDepth < depth) {
      break;
    }

    const atDepth = p.isDotSyntax ? p.dotDepth : 0;

    if (!p.isDotSyntax && depth > 0) {
      if (/^\s*$/.test(lines[i]!)) {
        i++;
        continue;
      }
      if (/^\s*for\s/i.test(lines[i]!) && lines[i]!.includes("{")) {
        i = skipBraceBlock(lines, i, to);
        continue;
      }
      break;
    }

    if (atDepth > depth) {
      const deeper = convertDotLines(
        lines,
        i,
        to,
        atDepth,
        indent + "\t",
        inForLoop
      );
      out.push(...deeper.output);
      i = deeper.index;
      continue;
    }

    if (atDepth < depth) {
      break;
    }

    const lineIndent = indent;
    const childIndent = indent + "\t";

    if (!p.isDotSyntax && depth === 0) {
      const rangeOpen = lines[i]!.match(RANGE_FOR_OPEN);
      if (rangeOpen && i + 1 < to && lines[i + 1]!.trim() === "}") {
        const nextDot = parseDotLine(lines[i + 2] ?? "");
        if (nextDot.isDotSyntax && nextDot.dotDepth >= 1) {
          out.push(`${p.indent}for ${rangeOpen[1]!.trim()} {`);
          const child = convertDotLines(
            lines,
            i + 2,
            to,
            1,
            p.indent + "\t",
            true
          );
          out.push(...child.output);
          out.push(`${p.indent}}`);
          i = child.index;
          continue;
        }
      }
    }

    if (ifInlineMatchesDepth(p, depth)) {
      const parts = ifInlinePartsFromLine(p)!;
      const cond = stripBlockPrefix(
        expandBlockKeyword(`if ${parts.cond}`),
        "if"
      );
      out.push(`${lineIndent}if ${formatIfCondition(cond)} {`);
      out.push(`${childIndent}${formatIfInlineBody(parts.body, inForLoop)}`);
      i = nextIdx;
      i = appendElseBranches(
        lines,
        i,
        to,
        depth,
        lineIndent,
        childIndent,
        inForLoop,
        out
      );
      out.push(`${lineIndent}}`);
      continue;
    }

    if (p.opensBlock) {
      const embedded = splitEmbeddedFor(p.bodyWithoutD);
      if (embedded) {
        out.push(`${lineIndent}${embedded.prefix}`);
        out.push(`${lineIndent}for {`);
        out.push(`${childIndent}${embedded.forHeader}`);
        const child = convertDotLines(
          lines,
          i + 1,
          to,
          depth + 1,
          childIndent,
          true
        );
        out.push(...child.output);
        out.push(`${lineIndent}}`);
        i = child.index;
        continue;
      }

      if (p.isElse && depth > 0) {
        break;
      }

      if (p.isIf) {
        const cond = stripBlockPrefix(
          expandBlockKeyword(p.bodyWithoutD),
          "if"
        );
        out.push(`${lineIndent}if ${formatIfCondition(cond)} {`);
        const child = collectBlockBody(
          lines,
          i + 1,
          to,
          p,
          depth,
          childIndent,
          inForLoop
        );
        out.push(...child.output);
        i = child.index;
        i = appendElseBranches(
          lines,
          i,
          to,
          depth,
          lineIndent,
          childIndent,
          inForLoop,
          out
        );
        out.push(`${lineIndent}}`);
        continue;
      }

      if (p.isFor) {
        const header = stripBlockPrefix(
          expandBlockKeyword(p.bodyWithoutD),
          "for"
        );
        if (RANGE_FOR_HEADER.test(header)) {
          out.push(`${lineIndent}for ${header} {`);
        } else {
          out.push(`${lineIndent}for {`);
          if (header) {
            out.push(`${childIndent}${header}`);
          }
        }
        const child = convertDotLines(
          lines,
          i + 1,
          to,
          depth + 1,
          childIndent,
          true
        );
        out.push(...child.output);
        out.push(`${lineIndent}}`);
        i = child.index;
        continue;
      }
    }

    if (depth === 0 && !p.isDotSyntax) {
      out.push(rawLine);
    } else {
      out.push(`${lineIndent}${dotLinePlainText(p, inForLoop)}`);
    }
    i = nextIdx;
  }

  return { output: out, index: i };
}

function convertMethodBodyRecursive(
  lines: string[],
  start: number,
  end: number
): string[] {
  const baseIndent = lines[start]?.match(/^(\s*)/)?.[1] ?? "";
  return convertDotLines(lines, start, end, 0, baseIndent).output;
}

const METHOD_HEADER =
  /^(ClassMethod|Method)\s+(\w+)\s*(\([^)]*\))?\s*(As\s+[\w.%]+)?\s*(\[[^\]]*\])?\s*$/i;

function parseMethodHeaderLine(trimmed: string): {
  headerLine: string;
  hasInlineBrace: boolean;
} | null {
  const hasInlineBrace = /\{\s*$/.test(trimmed);
  const headerLine = hasInlineBrace
    ? trimmed.replace(/\{\s*$/, "").trimEnd()
    : trimmed;
  if (!METHOD_HEADER.test(headerLine)) {
    return null;
  }
  return { headerLine, hasInlineBrace };
}

function findBodyEnd(lines: string[], start: number): number {
  let depth = 0;
  for (let j = start; j < lines.length; j++) {
    const t = lines[j]!;
    for (let k = 0; k < t.length; k++) {
      if (t[k] === "{") depth++;
      else if (t[k] === "}") depth--;
    }
    if (depth < 0) return j;
  }
  return lines.length;
}

/** 将方法体内的 IRIS 点语法转为块级 `{ }` 语法（不经过格式化） */
export function convertDotSyntaxToBlockCore(source: string): string {
  const lines = source.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");

  const hasMethodHeader = lines.some(
    (l) => parseMethodHeaderLine(l.trim()) !== null
  );
  if (!hasMethodHeader && methodHasDotSyntax(lines)) {
    return convertMethodBodyRecursive(lines, 0, lines.length).join("\n");
  }

  const out: string[] = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i]!;
    const trimmed = line.trim();

    const methodHdr = parseMethodHeaderLine(trimmed);
    if (methodHdr) {
      out.push(methodHdr.headerLine);
      if (methodHdr.hasInlineBrace) {
        out.push("{");
        i++;
      } else {
        i++;
        if (i < lines.length && lines[i]!.trim() === "{") {
          out.push(lines[i]!);
          i++;
        } else {
          continue;
        }
      }

      const bodyStart = i;
      const bodyEnd = findBodyEnd(lines, bodyStart);
      const slice = lines.slice(bodyStart, bodyEnd);

      if (methodHasDotSyntax(slice)) {
        out.push(...convertMethodBodyRecursive(lines, bodyStart, bodyEnd));
      } else {
        out.push(...slice);
      }

      if (bodyEnd < lines.length) {
        out.push(lines[bodyEnd]!);
      }
      i = bodyEnd + 1;
      continue;
    }

    out.push(line);
    i++;
  }

  return out.join("\n");
}
