export interface FormatOptions {
  printWidth: number;
  useTabs: boolean;
  tabWidth: number;
  braceStyle: "allman";
  sqlKeywordCase: "lower" | "preserve";
  expandBlockCommands: boolean;
  /** 后置 `q:` / `s:` 等：有括号则格式化括号内运算符空格，无括号则不改 */
  formatPostfixConditions: boolean;
  convertDotSyntax: boolean;
  convertCommaLogic: boolean;
  blankBetweenMethods: boolean;
  blankLogicalSections: boolean;
  /** 格式化选中片段：假定处于方法体内，从该块层级（Tab 层数）开始缩进 */
  fragmentBraceDepth?: number;
}

export const defaultOptions: FormatOptions = {
  printWidth: 120,
  useTabs: true,
  tabWidth: 4,
  braceStyle: "allman",
  sqlKeywordCase: "lower",
  expandBlockCommands: true,
  formatPostfixConditions: true,
  convertDotSyntax: false,
  convertCommaLogic: false,
  blankBetweenMethods: true,
  blankLogicalSections: true,
};

export function mergeOptions(
  partial?: Partial<FormatOptions>
): FormatOptions {
  return { ...defaultOptions, ...partial };
}
