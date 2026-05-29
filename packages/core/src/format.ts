import type { FormatOptions } from "./options.js";
import { mergeOptions } from "./options.js";
import { formatObjectScript } from "./formatter.js";
import { convertDotSyntaxToBlockCore } from "./dotToBlock.js";

export interface ConvertDotSyntaxOptions {
  /** 转换前先格式化（默认 true） */
  preFormat?: boolean;
  formatOptions?: Partial<FormatOptions>;
}

/** 点语法转块：默认先格式化再转换 */
export function convertDotSyntaxToBlock(
  source: string,
  opts?: ConvertDotSyntaxOptions
): string {
  const preFormat = opts?.preFormat !== false;
  let input = source.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  if (preFormat) {
    const { text } = formatObjectScript(input, {
      ...mergeOptions(opts?.formatOptions),
      convertDotSyntax: false,
    });
    input = text;
  }
  const out = convertDotSyntaxToBlockCore(input);
  if (source.endsWith("\n") && !out.endsWith("\n")) {
    return out + "\n";
  }
  return out;
}

export function format(
  source: string,
  options?: Partial<FormatOptions>
): string {
  const { text } = formatObjectScript(source, options);
  if (source.endsWith("\n") && !text.endsWith("\n")) {
    return text + "\n";
  }
  return text;
}

export { formatObjectScript } from "./formatter.js";
export { defaultOptions, mergeOptions } from "./options.js";
export type { FormatOptions } from "./options.js";
