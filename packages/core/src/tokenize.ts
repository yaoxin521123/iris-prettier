/** Split a line into string literals and code segments (strings left untouched). */
export type Segment = { type: "code" | "string"; text: string };

export function splitByStrings(line: string): Segment[] {
  const segments: Segment[] = [];
  let i = 0;
  let codeStart = 0;

  while (i < line.length) {
    if (line[i] === '"') {
      if (i > codeStart) {
        segments.push({ type: "code", text: line.slice(codeStart, i) });
      }
      let j = i + 1;
      while (j < line.length) {
        if (line[j] === '"') {
          if (line[j + 1] === '"') {
            j += 2;
            continue;
          }
          break;
        }
        j++;
      }
      segments.push({ type: "string", text: line.slice(i, j + 1) });
      i = j + 1;
      codeStart = i;
      continue;
    }
    i++;
  }

  if (codeStart < line.length) {
    segments.push({ type: "code", text: line.slice(codeStart) });
  }
  if (segments.length === 0) {
    segments.push({ type: "code", text: line });
  }
  return segments;
}

/** 分离行尾 `;` 注释（保留 `;` 前的空白，如 `-100\t;备注`） */
export function splitTrailingComment(line: string): { code: string; suffix: string } {
  const segments = splitByStrings(line);
  let offset = 0;
  for (const seg of segments) {
    if (seg.type === "code") {
      const semi = seg.text.indexOf(";");
      const slash = seg.text.search(/\s\/\//);
      const pick =
        semi >= 0 && slash >= 0
          ? Math.min(semi, slash)
          : semi >= 0
            ? semi
            : slash;
      if (pick >= 0) {
        const at = offset + pick;
        const before = line.slice(0, at);
        const after = line.slice(at);
        const ws = before.match(/(\s+)$/);
        const code = ws ? before.slice(0, -ws[1]!.length).trimEnd() : before.trimEnd();
        const suffix = (ws?.[1] ?? "") + after;
        return { code, suffix };
      }
    }
    offset += seg.text.length;
  }
  return { code: line.trimEnd(), suffix: "" };
}

/** $s/$case 分支：字符串与代码段之间的 `:`（如 `"" : $p`、`1 : ""`、`"I" : "Y"`） */
function formatColonAtSegmentEdges(
  code: string,
  prev: Segment | undefined,
  next: Segment | undefined
): string {
  let result = code;
  if (prev?.type === "string" && /^:\s*/.test(result)) {
    result = result.replace(/^:\s*/, " : ");
  }
  if (next?.type === "string") {
    result = result.replace(/(\d)\s*:\s*$/, "$1 : ");
    result = result.replace(/(\))\s*:\s*$/, "$1 : ");
    result = result.replace(/,\s*:\s*$/, ", : ");
  }
  return result;
}

/** 逗号在代码段与字符串字面量边界处补空格（如 `foo,"bar"` → `foo, "bar"`） */
function formatCommaAtSegmentEdges(
  code: string,
  prev: Segment | undefined,
  next: Segment | undefined
): string {
  let result = code;
  if (next?.type === "string" && /,\s*$/.test(result)) {
    result = result.replace(/,\s*$/, ", ");
  }
  if (prev?.type === "string" && /^,/.test(result)) {
    result = result.replace(/^,\s*/, ", ");
  }
  return result;
}

function isWhitespaceOnlyString(seg: Segment | undefined): boolean {
  return seg?.type === "string" && /^"\s*"$/.test(seg.text);
}

export function mapCodeSegments(
  line: string,
  fn: (code: string) => string
): string {
  const segments = splitByStrings(line);
  let out = "";
  for (let i = 0; i < segments.length; i++) {
    const seg = segments[i]!;
    if (seg.type === "string") {
      out += seg.text;
      continue;
    }
    const prev = segments[i - 1];
    const next = segments[i + 1];
    let code = fn(seg.text);
    if (isWhitespaceOnlyString(prev)) {
      code = code.replace(/^\s*_\s*/, "_");
    }
    if (isWhitespaceOnlyString(next)) {
      code = code.replace(/\s*_\s*$/, "_");
    }
    code = formatColonAtSegmentEdges(code, prev, next);
    code = formatCommaAtSegmentEdges(code, prev, next);
    if (next?.type === "string") {
      // 保留 ObjectScript 不等于运算符 '=，仅对普通赋值 = 加空格
      // `if +sortNum=0 s index="1"` 中 `+变量=` 不加空格
      code = code.replace(
        /(\S)(?<!['><])(?<!')=/g,
        (match, pre, offset, str) => {
          const left = str.slice(0, offset);
          if (/\+\s*[A-Za-z_%][\w.]*$/.test(left)) {
            return `${pre}=`;
          }
          return `${pre} = `;
        }
      );
    }
    out += code;
  }
  return out;
}
