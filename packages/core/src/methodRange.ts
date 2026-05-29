import { isMethodHeader } from "./rules.js";

export interface MethodRange {
  /** 方法头行（0-based） */
  startLine: number;
  /** 方法结束行（含闭合 `}`，0-based） */
  endLine: number;
  name: string;
}

function parseMethodHeaderLine(trimmed: string): {
  headerLine: string;
  hasInlineBrace: boolean;
} | null {
  const hasInlineBrace = /\{\s*$/.test(trimmed);
  const headerLine = hasInlineBrace
    ? trimmed.replace(/\{\s*$/, "").trimEnd()
    : trimmed;
  if (!isMethodHeader(headerLine)) {
    return null;
  }
  return { headerLine, hasInlineBrace };
}

function methodNameFromHeader(headerLine: string): string {
  const m = headerLine.match(/^(?:ClassMethod|Method)\s+(\w+)/i);
  return m?.[1] ?? "Unknown";
}

/** 从 `{` 行起找到方法体闭合 `}` 所在行 */
function findMethodCloseLine(lines: string[], braceLine: number): number {
  let depth = 0;
  for (let j = braceLine; j < lines.length; j++) {
    const t = lines[j]!;
    for (let k = 0; k < t.length; k++) {
      if (t[k] === "{") depth++;
      else if (t[k] === "}") depth--;
    }
    if (j > braceLine && depth <= 0) {
      return j;
    }
  }
  return lines.length - 1;
}

/** 扫描文件中所有 ClassMethod / Method 范围 */
export function findAllMethodRanges(lines: string[]): MethodRange[] {
  const ranges: MethodRange[] = [];
  let i = 0;

  while (i < lines.length) {
    const trimmed = lines[i]!.trim();
    const hdr = parseMethodHeaderLine(trimmed);
    if (!hdr) {
      i++;
      continue;
    }

    const startLine = i;
    const name = methodNameFromHeader(hdr.headerLine);
    let braceLine = i;

    if (hdr.hasInlineBrace) {
      const endLine = findMethodCloseLine(lines, braceLine);
      ranges.push({ startLine, endLine, name });
      i = endLine + 1;
      continue;
    }

    i++;
    if (i < lines.length && lines[i]!.trim() === "{") {
      braceLine = i;
      const endLine = findMethodCloseLine(lines, braceLine);
      ranges.push({ startLine, endLine, name });
      i = endLine + 1;
      continue;
    }
  }

  return ranges;
}

/** 光标/行号所在的方法范围；不在方法内则返回 null */
export function findMethodRangeAtLine(
  lines: string[],
  lineIndex: number
): MethodRange | null {
  if (lineIndex < 0 || lineIndex >= lines.length) {
    return null;
  }
  const ranges = findAllMethodRanges(lines);
  return (
    ranges.find(
      (r) => lineIndex >= r.startLine && lineIndex <= r.endLine
    ) ?? null
  );
}
