# iris-prettier

**Languages:** English | [简体中文](README.zh-CN.md)

Prettier-style formatter for InterSystems IRIS **ObjectScript** (formatting only, no linting).

Packages:

- **`@iris-prettier/core`** — formatting & dot-to-block engine
- **`iris-prettier-vscode`** — VS Code extension ([Marketplace](https://marketplace.visualstudio.com/items?itemName=iris-prettier.iris-prettier-vscode))

Formatting rules: [`docs/RULES.md`](docs/RULES.md).

## Features

### Formatting

- **Allman** braces (`ClassMethod Foo()` on its own line, `{` on the next)
- Operator & comma spacing: `=`, `+`, `-`, `*`, `/`, `_`, `:`, etc.
- Parenthesized comparisons: spaces around `<=` / `>=` (e.g. `(Ingd <= 0)`)
- **Tab** indentation in method bodies (IRIS default: 1 tab = 4 spaces)
- Lowercase commands; expand `i`/`f`/`e` to `if`/`for`/`else`
- Postfix `q:` / `s:` / `continue:` condition layout
- Blank lines between methods and logical sections
- Embedded **`&sql(...)`** multiline layout (lowercase keywords, trailing `//` after `)`)
- Long `_` concatenations stay on **one line**
- **Selection formatting** with context-aware indent depth

### Dot syntax → block

Converts IRIS dot syntax (`i ... d`, `.s`, `.e d`, `.f ... d`, etc.) to `if { }` / `for { }` / `else { }`:

- **Pre-format** before conversion by default
- Whole document or **selected fragment** (no `ClassMethod` header required)
- `if/else`, `elseif` (`.e  i`), range `for`, inline `i cond s cmd`
- `q:` inside `for` → `continue:`

## VS Code extension

### Install

Search **IRIS Prettier** in the marketplace, or:

```bash
code --install-extension iris-prettier.iris-prettier-vscode
```

Requires an ObjectScript language extension (e.g. [InterSystems ObjectScript](https://marketplace.visualstudio.com/items?itemName=intersystems-community.vscode-objectscript)).

Extension docs: [`packages/vscode/README.en.md`](packages/vscode/README.en.md).

### Commands

| Action | Shortcut | Context menu |
|--------|----------|--------------|
| Format document | `Shift+Alt+F` | — |
| Format selection | `Ctrl+K` `Ctrl+F` | ✓ |
| Convert selection syntax | — | ✓ |
| Dot → block (document) | `Ctrl+Shift+Alt+B` | — |
| Format + dot → block | `Ctrl+Shift+Alt+F` | — |

### Recommended settings

```json
{
  "irisPrettier.enable": true,
  "irisPrettier.useTabs": true,
  "irisPrettier.tabWidth": 4,
  "editor.tabSize": 4,
  "editor.insertSpaces": false,
  "[objectscript-class]": {
    "editor.defaultFormatter": "iris-prettier.iris-prettier-vscode",
    "editor.formatOnSave": true
  }
}
```

Indentation follows `irisPrettier.useTabs` / `irisPrettier.tabWidth`, not global `editor.tabSize`.

## API usage

```typescript
import { format, convertDotSyntaxToBlock } from "@iris-prettier/core";

const formatted = format(source);
const fragment = format(selected, { fragmentBraceDepth: 2 });
const blocked = convertDotSyntaxToBlock(source);
const all = format(source, { convertDotSyntax: true });
```

## Development

```bash
npm install
npm run build
npm test
```

```bash
cd packages/vscode
npm run build    # F5 to debug extension
npm run package  # build VSIX for publishing
```

## Project layout

```
packages/
  core/          # formatter, dot-to-block, &sql
  vscode/        # VS Code extension
tests/fixtures/
docs/
```

## Feedback

- **GitHub Issues**: [yaoxin521123/iris-prettier](https://github.com/yaoxin521123/iris-prettier/issues)
- **QQ group** (Chinese community): **410039091**
- Rules: [`docs/RULES.md`](docs/RULES.md)

## License

MIT
