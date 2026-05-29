import type { FormatOptions } from "./options.js";

const SQL_KW =
  /\b(SELECT|INSERT|UPDATE|DELETE|INTO|FROM|WHERE|SET|VALUES|JOIN|LEFT|RIGHT|INNER|OUTER|ON|AND|OR|ORDER|BY|GROUP|HAVING|AS|DISTINCT|UNION|ALL)\b/gi;

function lowerSql(text: string, options: FormatOptions): string {
  if (options.sqlKeywordCase !== "lower") return text;
  return text.replace(SQL_KW, (m) => m.toLowerCase());
}

/** 误拆开的 SQL 表名/字段名：`DHC _ PHDISITEM` → `DHC_PHDISITEM` */
function collapseSpacedSqlIdentifiers(text: string): string {
  let result = text;
  let prev: string;
  do {
    prev = result;
    result = result.replace(
      /([%]?[A-Za-z_][\w.]*)\s+_\s+([%]?[A-Za-z_][\w.]*)/g,
      "$1_$2"
    );
  } while (result !== prev);
  return result;
}

const SQL_OPEN_RE = /^(\s*)((?:\.\s*)*)&sql\s*\(/i;

/** 从首个 `&sql(` 起统计括号深度；>0 表示该行（或合并文本）上 &sql 未闭合 */
export function embeddedSqlParenDepth(text: string): number {
  const open = text.search(/&sql\s*\(/i);
  if (open < 0) return 0;
  const parenStart = text.indexOf("(", open);
  if (parenStart < 0) return 0;
  let depth = 0;
  for (let j = parenStart; j < text.length; j++) {
    if (text[j] === "(") depth++;
    else if (text[j] === ")") depth--;
  }
  return depth;
}

function normalizeDotPrefix(dots: string): string {
  return dots.replace(/\s+/g, "");
}

function wrapFields(
  fields: string[],
  innerIndent: string,
  contIndent: string
): string[] {
  const lines: string[] = [`${innerIndent}(`];
  for (let f = 0; f < fields.length; f += 5) {
    const chunk = fields.slice(f, f + 5);
    const comma = f + 5 < fields.length ? "," : "";
    lines.push(`${contIndent}${chunk.join(", ")}${comma}`);
  }
  lines.push(`${innerIndent})`);
  return lines;
}

/** 单行 SQL 正文：压缩空白、可选小写关键字（用于点语法内联 &sql，避免折行打断循环） */
function formatSqlInlineBody(sqlText: string, options: FormatOptions): string {
  return lowerSql(
    collapseSpacedSqlIdentifiers(sqlText.replace(/\s+/g, " ").trim()),
    options
  );
}

/** Format SQL text extracted from &sql(...). */
export function formatSqlContent(
  sqlText: string,
  options: FormatOptions,
  baseIndent: string
): string[] {
  const innerIndent = baseIndent + "\t";
  const contIndent = baseIndent + "\t\t";
  const text = lowerSql(
    collapseSpacedSqlIdentifiers(sqlText.replace(/\s+/g, " ").trim()),
    options
  );

  const insertMatch = text.match(
    /^insert\s+into\s+(\S+)\s*\(([^)]+)\)\s*values\s*\(([^)]+)\)\s*$/i
  );
  if (insertMatch) {
    const [, table, cols, vals] = insertMatch;
    const colFields = cols!.split(",").map((c) => c.trim());
    const valFields = vals!.split(",").map((v) => v.trim());
    return [
      `${innerIndent}insert into ${table}`,
      ...wrapFields(colFields, innerIndent, contIndent),
      `${innerIndent}values`,
      ...wrapFields(valFields, innerIndent, contIndent),
    ];
  }

  return [`${innerIndent}${text}`];
}

/** Detect &sql( ... ) span in lines; returns formatted replacement lines. */
export function formatEmbeddedSql(
  lines: string[],
  startIdx: number,
  options: FormatOptions,
  baseIndentOverride?: string
): { endIdx: number; lines: string[] } | null {
  const line = lines[startIdx] ?? "";
  const match = line.match(SQL_OPEN_RE);
  if (!match) return null;

  const baseIndent = baseIndentOverride ?? match[1] ?? "\t";
  const dotPrefix = normalizeDotPrefix(match[2] ?? "");
  const sqlHead = `${baseIndent}${dotPrefix}&sql(`;

  /** 本行 `&sql(` 的括号是否已全部闭合（列清单末尾的 `)` 不算单行结束） */
  function isSqlClosedOnLine(text: string): boolean {
    const open = text.search(/&sql\s*\(/i);
    if (open < 0) return false;
    const parenStart = text.indexOf("(", open);
    if (parenStart < 0) return false;
    let depth = 0;
    for (let j = parenStart; j < text.length; j++) {
      if (text[j] === "(") depth++;
      else if (text[j] === ")") depth--;
    }
    return depth === 0;
  }

  // Single-line &sql( ... ) — 须整行括号平衡；允许行末 `//` 注释
  const single = line.match(
    /^(\s*)((?:\.\s*)*)&sql\s*\(([\s\S]+)\)\s*(\/\/[^\n]*)?\s*$/i
  );
  if (single && isSqlClosedOnLine(line)) {
    const sqlBody = formatSqlInlineBody(single[3]!, options);
    const trailComment = single[4]?.trim() ?? "";
    if (dotPrefix) {
      const inline = trailComment
        ? `${baseIndent}${dotPrefix}&sql(${sqlBody}) ${trailComment}`
        : `${baseIndent}${dotPrefix}&sql(${sqlBody})`;
      return {
        endIdx: startIdx,
        lines: [inline],
      };
    }
    const closeLine = trailComment
      ? `${baseIndent}) ${trailComment}`
      : `${baseIndent})`;
    const formatted = [
      sqlHead,
      ...formatSqlContent(single[3]!, options, baseIndent),
      closeLine,
    ];
    return { endIdx: startIdx, lines: formatted };
  }

  function isSqlContinuationLine(idx: number): boolean {
    const next = lines[idx + 1]?.trim() ?? "";
    return /^(and|or)\b/i.test(next);
  }

  /** `&sql` 未闭合时，下一行已是 ObjectScript 命令（非 SQL 的 and/or 续行） */
  function isObjectScriptLineAfterSql(trimmed: string): boolean {
    if (trimmed === "}" || trimmed === "{") return true;
    if (/^(and|or)\b/i.test(trimmed)) return false;
    return /^(?:#|;|\/\/|q|s|d|i|b|g|if|for|while|do|continue)\b/i.test(trimmed);
  }

  // Multi-line: collect until closing paren at depth 0 (&sql( 已开括号，depth 从 1 起)
  const sqlLines: string[] = [];
  let trailingComment = "";
  let i = startIdx;
  let depth = 1;
  let emitClosing = true;

  for (; i < lines.length; i++) {
    const l = lines[i]!;
    if (/^\s*\)\s*$/.test(l) && isSqlContinuationLine(i)) {
      continue;
    }
    // 源码 `..)` / `.)` 仅作 &sql 结束标记；输出闭合行只用 `)`，不加 `..`
    const dotClose = l.trim().match(/^((?:\.\s*)+)\)\s*$/);
    if (i > startIdx && dotClose && depth === 1) {
      break;
    }
    if (i > startIdx && depth === 1 && isObjectScriptLineAfterSql(l.trim())) {
      i--;
      break;
    }
    const chunk = i === startIdx ? l.replace(SQL_OPEN_RE, "") : l;
    for (const ch of chunk) {
      if (ch === "(") depth++;
      else if (ch === ")") depth--;
    }
    let trimmed = chunk.trim();
    // 仅去掉闭合 &sql( 的外层 `)`；行末 `//` 注释移到输出时的 `)` 之后
    if (depth <= 0 && /\)(?:\s*\/\/|$)/.test(trimmed)) {
      trimmed = trimmed
        .replace(/\)\s*(\/\/[^\n]*)?$/, (_, comment = "") => {
          if (comment) trailingComment = comment.trim();
          return "";
        })
        .trim();
    }
    if (trimmed && !/^\.+$/.test(trimmed)) {
      sqlLines.push(trimmed);
    }
    if (i === startIdx && depth <= 0 && chunk.includes(")")) {
      // 单行 `&sql(...)//comment` 已剥离 `)` 到 trailingComment，仍需输出闭合行
      if (!trailingComment) {
        emitClosing = false;
      }
      break;
    }
    if (i > startIdx && depth <= 0) {
      // SQL 行末已有 `)` 闭合 &sql( 时，下一行单独的 `)` 为多余（如 :phd) 后再跟一行 )）
      if (
        i + 1 < lines.length &&
        /^\s*\)\s*$/.test(lines[i + 1]!.trim()) &&
        !isSqlContinuationLine(i)
      ) {
        i++;
      }
      break;
    }
  }

  const sqlJoined = sqlLines.join(" ");
  if (dotPrefix) {
    const sqlBody = formatSqlInlineBody(sqlJoined, options);
    const inline = trailingComment
      ? `${baseIndent}${dotPrefix}&sql(${sqlBody}) ${trailingComment}`
      : `${baseIndent}${dotPrefix}&sql(${sqlBody})`;
    return { endIdx: i, lines: [inline] };
  }

  const closeLine = trailingComment
    ? `${baseIndent}) ${trailingComment}`
    : `${baseIndent})`;
  const formatted = [
    sqlHead,
    ...formatSqlContent(sqlJoined, options, baseIndent),
    ...(emitClosing ? [closeLine] : []),
  ];

  return { endIdx: i, lines: formatted };
}
