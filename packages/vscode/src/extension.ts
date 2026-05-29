import * as vscode from "vscode";
import {
  format,
  convertDotSyntaxToBlock,
  mergeOptions,
  computeBraceDepthAtLine,
  findMethodRangeAtLine,
} from "@iris-prettier/core";

const EXTENSION_ID = "iris-prettier.iris-prettier-vscode";

/** .cls 实际是 objectscript-class，不是 objectscript */
const FORMAT_SELECTOR: vscode.DocumentSelector = [
  { language: "objectscript-class", scheme: "file" },
  { language: "objectscript", scheme: "file" },
  { language: "objectscript-int", scheme: "file" },
  { language: "objectscript-macros", scheme: "file" },
  { pattern: "**/*.cls", scheme: "file" },
  { pattern: "**/*.mac", scheme: "file" },
  { pattern: "**/*.int", scheme: "file" },
];

const output = vscode.window.createOutputChannel("IRIS Prettier");

function getOptions(): Partial<import("@iris-prettier/core").FormatOptions> {
  const cfg = vscode.workspace.getConfiguration("irisPrettier");
  return {
    printWidth: cfg.get<number>("printWidth", 120),
    useTabs: cfg.get<boolean>("useTabs", true),
    tabWidth: cfg.get<number>("tabWidth", 4),
    formatPostfixConditions: cfg.get<boolean>(
      "formatPostfixConditions",
      true
    ),
    convertDotSyntax: false,
  };
}

function fullRange(doc: vscode.TextDocument): vscode.Range {
  const last = doc.lineAt(doc.lineCount - 1);
  return new vscode.Range(0, 0, last.lineNumber, last.text.length);
}

function countChangedLines(before: string, after: string): number {
  const a = before.split(/\r\n|\r|\n/);
  const b = after.split(/\r\n|\r|\n/);
  const n = Math.max(a.length, b.length);
  let changed = 0;
  for (let i = 0; i < n; i++) {
    if ((a[i] ?? "") !== (b[i] ?? "")) {
      changed++;
    }
  }
  return changed;
}

function logFormatResult(info: {
  action: string;
  filePath: string;
  before: string;
  after: string;
  methodName?: string;
  startLine?: number;
  endLine?: number;
}): void {
  const rangePart =
    info.startLine !== undefined && info.endLine !== undefined
      ? `  行 ${info.startLine + 1}–${info.endLine + 1}`
      : "";
  const methodPart = info.methodName ? `  方法 ${info.methodName}` : "";

  if (info.before === info.after) {
    output.appendLine(
      `[skip] ${info.action} — ${info.filePath}${methodPart}${rangePart} — 无变化`
    );
    return;
  }

  const beforeLines = info.before.split(/\r\n|\r|\n/).length;
  const afterLines = info.after.split(/\r\n|\r|\n/).length;
  const changed = countChangedLines(info.before, info.after);

  output.appendLine(`[ok] ${info.action} — ${info.filePath}`);
  if (info.methodName) {
    output.appendLine(`  方法: ${info.methodName}`);
  }
  if (info.startLine !== undefined && info.endLine !== undefined) {
    output.appendLine(`  范围: 第 ${info.startLine + 1}–${info.endLine + 1} 行`);
  }
  output.appendLine(`  行数: ${beforeLines} → ${afterLines}，变更 ${changed} 行`);
}

function replaceRangeEdit(
  document: vscode.TextDocument,
  range: vscode.Range,
  after: string,
  log: Omit<Parameters<typeof logFormatResult>[0], "before" | "after">
): vscode.TextEdit[] {
  const before = document.getText(range);
  logFormatResult({ ...log, before, after });
  if (after === before) {
    return [];
  }
  return [vscode.TextEdit.replace(range, after)];
}

function applyText(
  document: vscode.TextDocument,
  after: string,
  label: string
): vscode.TextEdit[] {
  const range = fullRange(document);
  return replaceRangeEdit(document, range, after, { action: label, filePath: document.uri.fsPath });
}

function formatDocument(
  document: vscode.TextDocument,
  _formatting?: vscode.FormattingOptions,
  convertDotSyntax = false
): vscode.TextEdit[] {
  const merged = mergeOptions({
    ...getOptions(),
    convertDotSyntax,
  });
  const after = format(document.getText(), merged);
  return applyText(document, after, convertDotSyntax ? "format+dot" : "formatDocument");
}

function documentLines(document: vscode.TextDocument): string[] {
  return document.getText().split(/\r\n|\r|\n/);
}

function rangeForLines(
  document: vscode.TextDocument,
  startLine: number,
  endLine: number
): vscode.Range {
  return new vscode.Range(
    startLine,
    0,
    endLine,
    document.lineAt(endLine).text.length
  );
}

function formatMethod(
  document: vscode.TextDocument,
  lineIndex: number
): vscode.TextEdit[] {
  const lines = documentLines(document);
  const method = findMethodRangeAtLine(lines, lineIndex);
  if (!method) {
    output.appendLine(
      `[skip] formatMethod — ${document.uri.fsPath} — 第 ${lineIndex + 1} 行不在方法内`
    );
    return [];
  }

  const range = rangeForLines(document, method.startLine, method.endLine);
  const merged = mergeOptions(getOptions());
  const after = format(document.getText(range), merged);

  return replaceRangeEdit(document, range, after, {
    action: "formatMethod",
    filePath: document.uri.fsPath,
    methodName: method.name,
    startLine: method.startLine,
    endLine: method.endLine,
  });
}

function expandRangeToFullLines(
  document: vscode.TextDocument,
  range: vscode.Range
): vscode.Range {
  const startLine = range.start.line;
  const endLine = range.end.line;
  return new vscode.Range(
    startLine,
    0,
    endLine,
    document.lineAt(endLine).text.length
  );
}

function formatSelection(
  document: vscode.TextDocument,
  range: vscode.Range,
  _formatting?: vscode.FormattingOptions
): vscode.TextEdit[] {
  const fullRange = expandRangeToFullLines(document, range);
  const selected = document.getText(fullRange);
  if (!selected.trim()) {
    output.appendLine(
      `[skip] formatSelection — ${document.uri.fsPath} — 选区为空`
    );
    return [];
  }
  const formatOptions = selectionFormatOptions(document, fullRange);
  const after = format(selected, formatOptions);

  return replaceRangeEdit(document, fullRange, after, {
    action: "formatSelection",
    filePath: document.uri.fsPath,
    startLine: fullRange.start.line,
    endLine: fullRange.end.line,
  });
}

function selectionFormatOptions(
  document: vscode.TextDocument,
  fullRange: vscode.Range
): Partial<import("@iris-prettier/core").FormatOptions> {
  const allLines = documentLines(document);
  const braceDepth = computeBraceDepthAtLine(allLines, fullRange.start.line);
  return mergeOptions({
    ...getOptions(),
    convertDotSyntax: false,
    ...(braceDepth >= 1 ? { fragmentBraceDepth: braceDepth } : {}),
  });
}

function convertDotToBlockSelection(
  document: vscode.TextDocument,
  range: vscode.Range,
  _formatting?: vscode.FormattingOptions
): vscode.TextEdit[] {
  const fullRange = expandRangeToFullLines(document, range);
  const selected = document.getText(fullRange);
  if (!selected.trim()) {
    output.appendLine(
      `[skip] convertDotSelection — ${document.uri.fsPath} — 选区为空`
    );
    return [];
  }
  const formatOptions = selectionFormatOptions(document, fullRange);
  const converted = convertDotSyntaxToBlock(selected, { formatOptions });
  const after = format(converted, formatOptions);

  return replaceRangeEdit(document, fullRange, after, {
    action: "convertDotSelection",
    filePath: document.uri.fsPath,
    startLine: fullRange.start.line,
    endLine: fullRange.end.line,
  });
}

interface FormatPlan {
  range: vscode.Range;
  before: string;
  after: string;
  scopeLabel: string;
  methodName?: string;
  startLine?: number;
  endLine?: number;
}

/** 按 选中 → 当前方法 → 全文 决定格式化范围 */
function buildFormatPlan(
  editor: vscode.TextEditor,
  opts: { convertDot?: boolean } = {}
): FormatPlan | null {
  const { document, selection } = editor;
  const line = selection.active.line;

  if (!selection.isEmpty) {
    const fullRange = expandRangeToFullLines(document, selection);
    const before = document.getText(fullRange);
    if (!before.trim()) {
      return null;
    }
    const formatOptions = selectionFormatOptions(document, fullRange);
    const after = opts.convertDot
      ? format(
          convertDotSyntaxToBlock(before, { formatOptions }),
          formatOptions
        )
      : format(before, formatOptions);
    return {
      range: fullRange,
      before,
      after,
      scopeLabel: "选中内容",
      startLine: fullRange.start.line,
      endLine: fullRange.end.line,
    };
  }

  const method = findMethodRangeAtLine(documentLines(document), line);
  if (method) {
    const range = rangeForLines(document, method.startLine, method.endLine);
    const before = document.getText(range);
    const merged = mergeOptions(getOptions());
    const after = opts.convertDot
      ? format(
          convertDotSyntaxToBlock(before, { formatOptions: merged }),
          merged
        )
      : format(before, merged);
    return {
      range,
      before,
      after,
      scopeLabel: `方法 ${method.name}`,
      methodName: method.name,
      startLine: method.startLine,
      endLine: method.endLine,
    };
  }

  const range = fullRange(document);
  const before = document.getText(range);
  const merged = mergeOptions({
    ...getOptions(),
    convertDotSyntax: !!opts.convertDot,
  });
  const after = format(before, merged);
  return {
    range,
    before,
    after,
    scopeLabel: "全文",
  };
}

async function showFormatPreview(
  editor: vscode.TextEditor,
  opts: { convertDot?: boolean } = {}
): Promise<void> {
  const plan = buildFormatPlan(editor, opts);
  const filePath = editor.document.uri.fsPath;
  const action = opts.convertDot ? "previewConvert" : "previewFormat";

  if (!plan) {
    output.appendLine(`[skip] ${action} — ${filePath} — 无有效范围`);
    vscode.window.showInformationMessage("IRIS Prettier：无可预览的内容");
    return;
  }

  logFormatResult({
    action,
    filePath,
    before: plan.before,
    after: plan.after,
    methodName: plan.methodName,
    startLine: plan.startLine,
    endLine: plan.endLine,
  });

  if (plan.before === plan.after) {
    vscode.window.showInformationMessage("IRIS Prettier：无需更改");
    return;
  }

  const lang = editor.document.languageId;
  const rel = vscode.workspace.asRelativePath(editor.document.uri);
  const left = await vscode.workspace.openTextDocument({
    content: plan.before,
    language: lang,
  });
  const right = await vscode.workspace.openTextDocument({
    content: plan.after,
    language: lang,
  });
  const title = opts.convertDot
    ? `IRIS Prettier 语法转换预览 · ${plan.scopeLabel} · ${rel}`
    : `IRIS Prettier 格式化预览 · ${plan.scopeLabel} · ${rel}`;

  await vscode.commands.executeCommand(
    "vscode.diff",
    left.uri,
    right.uri,
    title
  );

  const applyLabel = opts.convertDot ? "应用语法转换" : "应用格式化";
  const choice = await vscode.window.showInformationMessage(
    `IRIS Prettier：已打开预览（${plan.scopeLabel}）`,
    applyLabel
  );

  if (choice === applyLabel) {
    const success = await editor.edit((builder) => {
      builder.replace(plan.range, plan.after);
    });
    if (success) {
      output.appendLine(
        `[ok] applyPreview — ${filePath} — ${plan.scopeLabel}`
      );
      output.show(true);
      vscode.window.showInformationMessage(
        opts.convertDot
          ? "IRIS Prettier：语法转换已应用"
          : "IRIS Prettier：格式化已应用"
      );
    }
  }
}

async function runEdits(
  editor: vscode.TextEditor,
  edits: vscode.TextEdit[],
  doneMessage: string
): Promise<void> {
  if (edits.length === 0) {
    vscode.window.showInformationMessage("IRIS Prettier：无需更改");
    return;
  }
  const success = await editor.edit((builder) => {
    for (const edit of edits) {
      builder.replace(edit.range, edit.newText);
    }
  });
  if (success) {
    output.show(true);
    vscode.window.showInformationMessage(doneMessage);
  }
}

export function activate(context: vscode.ExtensionContext): void {
  const enabled = () =>
    vscode.workspace.getConfiguration("irisPrettier").get<boolean>("enable", true);

  const editorOpts = (_editor: vscode.TextEditor): vscode.FormattingOptions => ({
    insertSpaces: !vscode.workspace
      .getConfiguration("irisPrettier")
      .get<boolean>("useTabs", true),
    tabSize: vscode.workspace
      .getConfiguration("irisPrettier")
      .get<number>("tabWidth", 4),
  });

  const provider: vscode.DocumentFormattingEditProvider = {
    provideDocumentFormattingEdits(
      document,
      options,
      _token
    ): vscode.TextEdit[] {
      if (!enabled()) return [];
      return formatDocument(document, options, false);
    },
  };

  const rangeProvider: vscode.DocumentRangeFormattingEditProvider = {
    provideDocumentRangeFormattingEdits(
      document,
      range,
      options,
      _token
    ): vscode.TextEdit[] {
      if (!enabled()) return [];
      return formatSelection(document, range, options);
    },
  };

  context.subscriptions.push(
    vscode.languages.registerDocumentFormattingEditProvider(
      FORMAT_SELECTOR,
      provider
    ),
    vscode.languages.registerDocumentRangeFormattingEditProvider(
      FORMAT_SELECTOR,
      rangeProvider
    ),
    vscode.commands.registerCommand("iris-prettier.formatDocument", async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor || !enabled()) return;
      await runEdits(
        editor,
        formatDocument(editor.document, editorOpts(editor), false),
        "IRIS Prettier：格式化完成"
      );
    }),
    vscode.commands.registerCommand(
      "iris-prettier.formatMethod",
      async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor || !enabled()) return;
        const line = editor.selection.active.line;
        await runEdits(
          editor,
          formatMethod(editor.document, line),
          "IRIS Prettier：当前方法已格式化"
        );
      }
    ),
    vscode.commands.registerCommand(
      "iris-prettier.formatSelection",
      async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor || !enabled()) return;
        const { selection, document } = editor;
        if (selection.isEmpty) {
          vscode.window.showInformationMessage(
            "IRIS Prettier：请先选中要格式化的代码"
          );
          return;
        }
        await runEdits(
          editor,
          formatSelection(document, selection, editorOpts(editor)),
          "IRIS Prettier：选中内容已格式化"
        );
      }
    ),
    vscode.commands.registerCommand(
      "iris-prettier.convertDotToBlockSelection",
      async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor || !enabled()) return;
        const { selection, document } = editor;
        if (selection.isEmpty) {
          vscode.window.showInformationMessage(
            "IRIS Prettier：请先选中要转换的代码"
          );
          return;
        }
        await runEdits(
          editor,
          convertDotToBlockSelection(document, selection, editorOpts(editor)),
          "IRIS Prettier：选中内容已转换语法"
        );
      }
    ),
    vscode.commands.registerCommand(
      "iris-prettier.convertDotToBlock",
      async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor || !enabled()) return;
        const before = editor.document.getText();
        const after = convertDotSyntaxToBlock(before, {
          formatOptions: getOptions(),
        });
        await runEdits(
          editor,
          applyText(editor.document, after, "convertDotToBlock"),
          "IRIS Prettier：点语法已转为块语法"
        );
      }
    ),
    vscode.commands.registerCommand(
      "iris-prettier.formatDocumentWithDotConversion",
      async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor || !enabled()) return;
        await runEdits(
          editor,
          formatDocument(editor.document, editorOpts(editor), true),
          "IRIS Prettier：点转块 + 格式化完成"
        );
      }
    ),
    vscode.commands.registerCommand(
      "iris-prettier.previewFormat",
      async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor || !enabled()) return;
        await showFormatPreview(editor, { convertDot: false });
      }
    ),
    vscode.commands.registerCommand(
      "iris-prettier.previewConvertSyntax",
      async () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor || !enabled()) return;
        await showFormatPreview(editor, { convertDot: true });
      }
    )
  );

  output.appendLine(`IRIS Prettier 已加载 (${EXTENSION_ID})`);
}

export function deactivate(): void {}
