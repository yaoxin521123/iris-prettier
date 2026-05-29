import * as vscode from "vscode";
import { format, convertDotSyntaxToBlock, mergeOptions, computeBraceDepthAtLine } from "@iris-prettier/core";

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

function applyText(
  document: vscode.TextDocument,
  after: string,
  label: string
): vscode.TextEdit[] {
  const before = document.getText();
  if (after === before) {
    output.appendLine(`[skip] ${document.uri.fsPath} — 无变化`);
    return [];
  }
  output.appendLine(`[ok] ${document.uri.fsPath} (${label})`);
  return [vscode.TextEdit.replace(fullRange(document), after)];
}

function formatDocument(
  document: vscode.TextDocument,
  formatting?: vscode.FormattingOptions,
  convertDotSyntax = false
): vscode.TextEdit[] {
  const merged = mergeOptions({
    ...getOptions(),
    convertDotSyntax,
  });
  const after = format(document.getText(), merged);
  return applyText(document, after, document.languageId);
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
  formatting?: vscode.FormattingOptions
): vscode.TextEdit[] {
  const fullRange = expandRangeToFullLines(document, range);
  const selected = document.getText(fullRange);
  if (!selected.trim()) {
    return [];
  }
  const formatOptions = selectionFormatOptions(document, fullRange, formatting);
  const after = format(selected, formatOptions);
  if (after === selected) {
    return [];
  }
  return [vscode.TextEdit.replace(fullRange, after)];
}

function selectionFormatOptions(
  document: vscode.TextDocument,
  fullRange: vscode.Range,
  formatting?: vscode.FormattingOptions
): Partial<import("@iris-prettier/core").FormatOptions> {
  const allLines = document.getText().split(/\r\n|\r|\n/);
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
  formatting?: vscode.FormattingOptions
): vscode.TextEdit[] {
  const fullRange = expandRangeToFullLines(document, range);
  const selected = document.getText(fullRange);
  if (!selected.trim()) {
    return [];
  }
  const formatOptions = selectionFormatOptions(document, fullRange, formatting);
  const converted = convertDotSyntaxToBlock(selected, { formatOptions });
  const after = format(converted, formatOptions);
  if (after === selected) {
    return [];
  }
  return [vscode.TextEdit.replace(fullRange, after)];
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
        const after = convertDotSyntaxToBlock(editor.document.getText(), {
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
    )
  );

  output.appendLine(`IRIS Prettier 已加载 (${EXTENSION_ID})`);
}

export function deactivate(): void {}
