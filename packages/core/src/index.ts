export { format, formatObjectScript, defaultOptions, mergeOptions, convertDotSyntaxToBlock } from "./format.js";
export type { ConvertDotSyntaxOptions } from "./format.js";
export { convertDotSyntaxToBlockCore } from "./dotToBlock.js";
export { computeBraceDepthAtLine } from "./formatter.js";
export {
  findAllMethodRanges,
  findMethodRangeAtLine,
} from "./methodRange.js";
export type { MethodRange } from "./methodRange.js";
export type { FormatOptions } from "./options.js";
export type { FormatResult } from "./formatter.js";
