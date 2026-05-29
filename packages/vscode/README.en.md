# IRIS Prettier

<p align="center">
  <img src="images/icon.png" alt="IRIS Prettier" width="128" />
</p>

**Languages:** English | [简体中文](README.zh-CN.md)

Prettier-style formatter for **InterSystems IRIS ObjectScript** (`.cls`, `.mac`, `.int`, etc.).

Formatting only — no linting. Works with the official InterSystems ObjectScript VS Code extension.

## Install

Search **IRIS Prettier** in the marketplace:

```
ext install iris-prettier.iris-prettier-vscode
```

**Requires** an extension that provides `objectscript` / `objectscript-class` language IDs (e.g. [InterSystems ObjectScript](https://marketplace.visualstudio.com/items?itemName=intersystems-community.vscode-objectscript)).

## Quick start

1. Open a `.cls` file
2. Right-click → **Format Document**, or `Shift+Alt+F`
3. Select code → right-click **Format Selection** / **Convert Selection Syntax**
4. Set as default formatter in `settings.json` (see below)

## Features

### Formatting

| Feature | Description |
|---------|-------------|
| Allman braces | `ClassMethod Foo()` and `{` on separate lines |
| Operator spacing | Spaces around `=`, `+`, `-`, `*`, `/`, `_`, `:`, etc. |
| Comparisons in `()` | `(Ingd <= 0)`, `(x >= 1)` — spaces on both sides of `<=` / `>=` |
| Lowercase commands | `Set` → `s`, `If` → `if` |
| Block expansion | `i` → `if`, `f` → `for`, `e` → `else` |
| Postfix conditions | Spacing inside `q:(...)` / `s:(...)` |
| Method blank lines | Blank line between adjacent methods |
| `&sql(...)` | Multiline SQL, lowercase keywords, `//` after `)` |
| Tab indent | Default tabs in method bodies (1 tab = 4 spaces in IRIS) |
| Selection format | Indent from enclosing `{` / `}` context |

### Dot syntax → block

**Before:**

```objectscript
i $d(^DHCRETA(0,"TypePointer","G",rowid)) d
.s retarowid=$o(^DHCRETA(0,"TypePointer","G",rowid,""))
.e  d
.&sql(insert into DHC_RetAspAmount ...)
i SQLCODE'=0  d
.s ret=$$SqlErrorRecord^DHCSTERROR(...)
```

**After:**

```objectscript
if $d(^DHCRETA(0,"TypePointer","G",rowid)) {
    s retarowid=$o(^DHCRETA(0,"TypePointer","G",rowid,""))
} else {
    &sql(insert into DHC_RetAspAmount ...)
}
if (SQLCODE'=0) {
    s ret=$$SqlErrorRecord^DHCSTERROR(...)
}
```

Also supports: `.e  i` → `elseif`, range `for`, inline `i cond s cmd`, `q:` → `continue:` in loops, and **selection** conversion without a method header.

> Dot-to-block **pre-formats** source before conversion.

## Commands

| Action | Command palette | Context menu | Shortcut |
|--------|-----------------|----------------|----------|
| Format document | `IRIS Prettier: Format Document` | — | `Shift+Alt+F` |
| Format selection | `IRIS Prettier: 格式化选定内容` | ✓ | `Ctrl+K` `Ctrl+F` |
| Convert selection | `IRIS Prettier: 转换选定内容语法` | ✓ | — |
| Dot → block | `IRIS Prettier: Convert Dot Syntax to Block` | — | `Ctrl+Shift+Alt+B` |
| Format + convert | `IRIS Prettier: Format + Convert Dot to Block` | — | `Ctrl+Shift+Alt+F` |

**Selection notes:** range expands to full lines; indent depth is inferred from `{` / `}` above the selection.

## Recommended settings

```json
{
  "irisPrettier.enable": true,
  "irisPrettier.useTabs": true,
  "irisPrettier.tabWidth": 4,
  "irisPrettier.printWidth": 120,
  "irisPrettier.formatPostfixConditions": true,
  "editor.insertSpaces": false,
  "editor.tabSize": 4,
  "[objectscript-class]": {
    "editor.defaultFormatter": "iris-prettier.iris-prettier-vscode",
    "editor.formatOnSave": true,
    "editor.tabSize": 4,
    "editor.insertSpaces": false
  },
  "[objectscript]": {
    "editor.defaultFormatter": "iris-prettier.iris-prettier-vscode",
    "editor.formatOnSave": true,
    "editor.tabSize": 4,
    "editor.insertSpaces": false
  }
}
```

## Configuration

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `irisPrettier.enable` | boolean | `true` | Enable formatting |
| `irisPrettier.printWidth` | number | `120` | Reference line width |
| `irisPrettier.useTabs` | boolean | `true` | Tabs in method bodies |
| `irisPrettier.tabWidth` | number | `4` | Spaces per level when `useTabs` is false |
| `irisPrettier.formatPostfixConditions` | boolean | `true` | Format postfix `q:` / `s:` conditions |

Indentation uses `irisPrettier.*` settings, not VS Code global `editor.tabSize`.

## Design principles

- **Format only** — no semantic linting
- **Preserve IRIS idioms** — e.g. `e  i` kept in format-only mode; expanded on dot-to-block
- **Do not break existing blocks** — `If ind="" { ... }` left intact

## Known limitations

- Very complex nested dot syntax may need manual touch-up
- Commas in conditions are not converted to `&&` by default
- Requires ObjectScript language extension for language IDs

## Feedback

- **GitHub Issues**: [yaoxin521123/iris-prettier](https://github.com/yaoxin521123/iris-prettier/issues)
- **QQ group** (Chinese community): **410039091**
- **Rules**: [docs/RULES.md](https://github.com/yaoxin521123/iris-prettier/blob/main/docs/RULES.md)

## License

MIT
