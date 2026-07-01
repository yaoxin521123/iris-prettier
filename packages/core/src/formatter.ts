import type { FormatOptions } from "./options.js";
import { mergeOptions } from "./options.js";
import { convertDotSyntaxToBlockCore } from "./dotToBlock.js";
import { formatEmbeddedSql } from "./sql.js";
import {
  ensureAllmanBrace,
  expandBlockCommands as expandCmd,
  normalizeElseIf,
  formatMethodHeader,
  formatPostfixLine,
  applyLineSpacingPreservingPostfix,
  isBlank,
  isMethodHeader,
  isRoutineLabelLine,
  formatRoutineLabelLine,
  isDisabledOrCommentLine,
  isDocCommentLine,
  isHashSemicolonCommentLine,
  isSemicolonCommentLine,
  isSlashSlashCommentLine,
  normalizeHashSemicolonCommentLine,
  normalizeSemicolonCommentLine,
  lowercaseCommand,
  normalizeContainsBracketSyntax,
} from "./rules.js";
import { findMethodRangeAtLine } from "./methodRange.js";
import { mapCodeSegments } from "./tokenize.js";
import {
  formatBlockBraceSpacing,
  formatMultiCommandSpacingLine,
  formatOperatorSpacing,
  maskEmbeddedSqlSpans,
  unmaskEmbeddedSqlSpans,
} from "./rules.js";

export interface FormatResult {
  text: string;
  changed: boolean;
  warnings: string[];
}

function indentUnit(options: FormatOptions): string {
  return options.useTabs ? "\t" : " ".repeat(options.tabWidth);
}

function opensBlock(line: string): boolean {
  return /\{(?:\s*\/\/.*)?\s*$/.test(line.trim());
}

function isCloseElseBranch(line: string): boolean {
  return /^\}\s*(else|elseif|catch)\b/i.test(line.trim());
}

function methodIndent(level: number, unit: string): string {
  return level > 0 ? unit.repeat(level) : "";
}

/** 根据方法体 `{` 与块命令，推算某行应有的 methodBraceDepth（供选中格式化） */
export function computeBraceDepthAtLine(
  lines: string[],
  lineIndex: number
): number {
  const method = findMethodRangeAtLine(lines, lineIndex);
  if (!method) {
    return 0;
  }

  let braceLine = method.startLine;
  const headerTrimmed = lines[method.startLine]?.trim() ?? "";
  if (!/\{\s*$/.test(headerTrimmed)) {
    braceLine = -1;
    for (let j = method.startLine + 1; j <= method.endLine; j++) {
      if (lines[j]?.trim() === "{") {
        braceLine = j;
        break;
      }
    }
  }

  // 方法头、`{` 行、或方法头与 `{` 之间的 /// 文档注释
  if (braceLine < 0 || lineIndex <= braceLine) {
    return 0;
  }

  let depth = 1;
  for (let i = braceLine + 1; i < lineIndex; i++) {
    const trimmed = lines[i]!.trim();
    if (!trimmed) {
      continue;
    }
    if (trimmed === "{") {
      depth++;
      continue;
    }
    if (trimmed === "}") {
      depth = Math.max(1, depth - 1);
      continue;
    }
    if (isCloseElseBranch(trimmed)) {
      depth = Math.max(1, depth - 1);
      if (opensBlock(trimmed)) {
        depth++;
      }
      continue;
    }
    if (opensBlock(trimmed)) {
      depth++;
    }
  }
  return depth;
}

function formatLineContent(line: string, options: FormatOptions): string {
  if (isDocCommentLine(line)) {
    return line.trimStart();
  }
  if (isDisabledOrCommentLine(line)) {
    if (isSemicolonCommentLine(line)) {
      return normalizeSemicolonCommentLine(line.trimStart());
    }
    if (isHashSemicolonCommentLine(line)) {
      return normalizeHashSemicolonCommentLine(line.trimStart());
    }
    return line.trimStart();
  }
  let s = formatBlockBraceSpacing(line);
  if (isMethodHeader(s.trim())) {
    return formatMethodHeader(s.trim());
  }
  s = lowercaseCommand(s);
  if (options.expandBlockCommands) {
    s = expandCmd(s);
  }
  s = normalizeElseIf(s);
  const postfix = options.formatPostfixConditions ? formatPostfixLine(s) : null;
  let body = postfix ?? s;

  const applyLineSpacing = (code: string) => {
    const { text: sqlMasked, spans } = maskEmbeddedSqlSpans(code);
    let r = mapCodeSegments(
      normalizeContainsBracketSyntax(sqlMasked),
      formatOperatorSpacing
    );
    if (/^(if|elseif)\s*\(/i.test(r.trim())) {
      r = r.replace(/\s*&&\s*/g, "&&").replace(/\s*\|\|\s*/g, "||");
    }
    r = formatMultiCommandSpacingLine(r);
    return unmaskEmbeddedSqlSpans(r, spans);
  };

  body = options.formatPostfixConditions
    ? applyLineSpacingPreservingPostfix(body, applyLineSpacing)
    : applyLineSpacing(body);
  return body;
}

function needsSectionBlankBefore(line: string): boolean {
  return /^\s*(ts|TSTART|tc|TCOMMIT)\b/i.test(line) || /^\s*#;/.test(line);
}

/** 将 `if (a)&&\n(b)||(c) {` 等多行条件合并为一行 */
function joinIfConditionContinuations(lines: string[]): string[] {
  const result: string[] = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i]!;
    const lead = line.match(/^(\s*)/)?.[1] ?? "";
    let combined = line.trimEnd();

    while (i + 1 < lines.length) {
      const next = lines[i + 1]!.trim();
      if (
        next === "" ||
        next.startsWith(";") ||
        next.startsWith("//") ||
        next.startsWith("#;")
      ) {
        break;
      }

      const cur = combined.trim();
      const endsContinuator = /(?:&&|\|\|)\s*$/.test(cur);
      const ifNeedsMore =
        /^(if|elseif)\b/i.test(cur) && !/\)\s*(\{|\b[sdqbcf])/i.test(cur);
      const nextContinues =
        /^(?:\|\||&&|\()/.test(next) || (ifNeedsMore && /^\(/.test(next));

      if (!endsContinuator && !nextContinues) break;

      i++;
      combined = `${combined.trimEnd()} ${next}`;
      if (/\{\s*$/.test(next)) break;
    }

    result.push(lead + combined.trimStart());
    i++;
  }
  return result;
}

/** 将 `}\nelseif\n{` 合并为 `} elseif {`（`else` / `catch` 同理） */
function joinCloseElseBranchLines(lines: string[]): string[] {
  const result: string[] = [];
  let i = 0;
  while (i < lines.length) {
    const line = lines[i]!;
    if (line.trim() !== "}") {
      result.push(line);
      i++;
      continue;
    }

    let j = i + 1;
    while (j < lines.length && isBlank(lines[j]!)) {
      j++;
    }
    const branchRaw = lines[j];
    if (!branchRaw || !/^(else|elseif|catch)\b/i.test(branchRaw.trim())) {
      result.push(line);
      i++;
      continue;
    }

    let branch = branchRaw.trim();
    let end = j;

    if (!opensBlock(branch)) {
      let m = j + 1;
      while (m < lines.length && isBlank(lines[m]!)) {
        m++;
      }
      if (lines[m]?.trim() !== "{") {
        result.push(line);
        i++;
        continue;
      }
      branch = `${branch} {`;
      end = m;
    }

    const lead = line.match(/^(\s*)/)?.[1] ?? "";
    result.push(`${lead}} ${branch}`);
    i = end + 1;
  }
  return result;
}

export function formatObjectScript(
  source: string,
  partial?: Partial<FormatOptions>
): FormatResult {
  const options = mergeOptions(partial);
  let normalized = source.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  if (options.convertDotSyntax) {
    const { text } = formatObjectScript(source, {
      ...options,
      convertDotSyntax: false,
    });
    normalized = convertDotSyntaxToBlockCore(text);
  }
  let lines = joinIfConditionContinuations(normalized.split("\n"));
  lines = joinCloseElseBranchLines(lines);

  // Allman braces: split `Method Foo() {` only when brace on same line
  for (let i = 0; i < lines.length; i++) {
    if (isMethodHeader(lines[i]!)) {
      lines = ensureAllmanBrace(lines, i);
    }
  }

  const output: string[] = [];
  let depth = 0;
  let inMethodBody = false;
  let pendingMethodBrace = false;
  /** 方法体内嵌套块层级（1 = 方法直接子级，每多一层 { 加 1） */
  let methodBraceDepth = 0;
  const fragmentDepth = options.fragmentBraceDepth ?? 0;
  if (fragmentDepth >= 1) {
    inMethodBody = true;
    methodBraceDepth = fragmentDepth;
  }
  const unit = indentUnit(options);
  let i = 0;

  while (i < lines.length) {
    const raw = lines[i]!;

    if (/&sql\s*\(/i.test(raw)) {
      const sqlIndent =
        inMethodBody && !isRoutineLabelLine(raw.trim())
          ? methodIndent(methodBraceDepth, unit)
          : undefined;
      const block = formatEmbeddedSql(lines, i, options, sqlIndent);
      if (block) {
        for (const l of block.lines) {
          output.push(l);
        }
        i = block.endIdx + 1;
        continue;
      }
    }

    const trimmed = raw.trim();

    if (isMethodHeader(trimmed)) {
      const lastOut = output[output.length - 1] ?? "";
      if (
        options.blankBetweenMethods &&
        output.length > 0 &&
        lastOut !== "" &&
        lastOut !== "{" &&
        !isDisabledOrCommentLine(lastOut)
      ) {
        output.push("");
      }
      output.push(formatMethodHeader(trimmed));
      inMethodBody = false;
      pendingMethodBrace = true;
      i++;
      continue;
    }

    if (trimmed === "{") {
      if (pendingMethodBrace) {
        output.push("{");
        inMethodBody = true;
        pendingMethodBrace = false;
        methodBraceDepth = 1;
      } else if (inMethodBody) {
        output.push(methodIndent(methodBraceDepth, unit) + "{");
        methodBraceDepth++;
      } else {
        output.push("{");
      }
      depth++;
      i++;
      continue;
    }

    if (trimmed === "}") {
      depth = Math.max(0, depth - 1);
      if (inMethodBody) {
        if (methodBraceDepth > 1) {
          methodBraceDepth--;
          output.push(methodIndent(methodBraceDepth, unit) + "}");
        } else {
          output.push("}");
          methodBraceDepth = 0;
          inMethodBody = false;
        }
      } else {
        output.push("}");
      }
      i++;
      continue;
    }

    if (inMethodBody && isCloseElseBranch(trimmed)) {
      methodBraceDepth = Math.max(1, methodBraceDepth - 1);
      const branchLine = formatLineContent(trimmed, options);
      output.push(methodIndent(methodBraceDepth, unit) + branchLine);
      if (opensBlock(branchLine)) {
        methodBraceDepth++;
      }
      i++;
      continue;
    }

    if (isBlank(raw)) {
      const nextLine = lines[i + 1];
      const prevOut = output[output.length - 1];
      const prevIsComment =
        prevOut !== undefined && isDisabledOrCommentLine(prevOut);
      const nextIsComment =
        nextLine !== undefined && isDisabledOrCommentLine(nextLine);
      if (inMethodBody && (prevIsComment || nextIsComment)) {
        output.push("");
      }
      i++;
      continue;
    }

    if (isDocCommentLine(raw) && !inMethodBody) {
      output.push(formatLineContent(trimmed, options));
      i++;
      continue;
    }

    if (inMethodBody && isDisabledOrCommentLine(raw)) {
      let commentBody = trimmed;
      if (isSemicolonCommentLine(raw)) {
        commentBody = normalizeSemicolonCommentLine(trimmed);
      } else if (isHashSemicolonCommentLine(raw)) {
        commentBody = normalizeHashSemicolonCommentLine(trimmed);
      } else if (isDocCommentLine(raw)) {
        commentBody = formatLineContent(trimmed, options);
      }
      output.push(methodIndent(methodBraceDepth, unit) + commentBody);
      i++;
      continue;
    }

    if (
      options.blankLogicalSections &&
      inMethodBody &&
      needsSectionBlankBefore(raw) &&
      output.length > 0 &&
      output[output.length - 1] !== ""
    ) {
      output.push("");
    }

    const formattedLines =
      inMethodBody && isRoutineLabelLine(trimmed)
        ? [
            formatRoutineLabelLine(trimmed, lines, i, (seg) =>
              formatLineContent(seg, options)
            ),
          ]
        : [formatLineContent(trimmed, options)];

    for (const fl of formattedLines) {
      if (!inMethodBody) {
        output.push(fl);
        continue;
      }
      const indentLevel = isRoutineLabelLine(fl) ? 0 : methodBraceDepth;
      output.push(methodIndent(indentLevel, unit) + fl);
      if (opensBlock(fl)) {
        methodBraceDepth++;
      }
    }
    i++;
  }

  const text = output.join("\n");
  return {
    text,
    changed: text !== normalized,
    warnings: [],
  };
}
