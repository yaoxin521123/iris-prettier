# iris-prettier

**语言：** [English](README.en.md) | 简体中文

InterSystems IRIS **ObjectScript** 的 Prettier 风格格式化器（仅排版，不做 Lint）。

包含：

- **`@iris-prettier/core`**：格式化与点转块核心库
- **`iris-prettier-vscode`**：VS Code 扩展（[市场安装](https://marketplace.visualstudio.com/items?itemName=iris-prettier.iris-prettier-vscode)）

规范来源见 [`docs/RULES.md`](docs/RULES.md)。

## 功能

### 格式化

- 方法大括号 **Allman** 换行（`Method Foo()` 与 `{` 分行）
- 运算符与逗号空格：`=`、`+`、`-`、`*`、`/`、`_`、`:` 等
- 括号内比较符：`<=`、`>=` 两侧空格（如 `(Ingd <= 0)`）
- 方法体内 **Tab** 缩进（IRIS 默认 1 Tab = 4 空格）
- 命令小写；块内 `i`/`f`/`e` 展开为 `if`/`for`/`else`
- 后置 `q:` / `s:` / `continue:` 条件排版
- 方法之间空行、逻辑段空行
- 内嵌 **`&sql(...)`** 多行布局（关键字小写、行末 `//` 注释跟在 `)` 后）
- 长 `_` 字符串拼接**保持单行**（不自动折行）
- **选中片段格式化**：根据上下文块层级自动补全缩进

### 点语法转块

将 `i ... d`、`.s`、`.e d`、`.f ... d` 等 IRIS 点语法转为块级 `if { }` / `for { }` / `else { }`：

- 默认**先格式化再转换**
- 支持整文档、**选中片段**（无需包含 `ClassMethod` 方法头）
- 支持 `if/else`、`elseif`（`.e  i`）、区间 `for`、行内 `i cond s cmd`
- for 循环体内 `q:` → `continue:`

## VS Code 扩展

### 安装

市场搜索 **IRIS Prettier**，或：

```bash
code --install-extension iris-prettier.iris-prettier-vscode
```

需已安装 InterSystems 官方 ObjectScript 扩展（提供 `objectscript-class` 等语言 ID）。

扩展说明见 [`packages/vscode/README.zh-CN.md`](packages/vscode/README.zh-CN.md)。

### 命令

| 操作 | 快捷键 | 右键菜单 |
|------|--------|----------|
| 格式化文档 | `Shift+Alt+F` | — |
| 格式化选定内容 | `Ctrl+K` `Ctrl+F` | ✓ |
| 转换选定内容语法 | — | ✓ |
| 点语法转块（全文） | `Ctrl+Shift+Alt+B` | — |
| 格式化 + 点转块 | `Ctrl+Shift+Alt+F` | — |

### 推荐设置

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

> 缩进宽度由 `irisPrettier.useTabs` / `irisPrettier.tabWidth` 控制，不跟随全局 `editor.tabSize: 2` 等设置。

## 在代码中使用

```typescript
import { format, convertDotSyntaxToBlock } from "@iris-prettier/core";

const formatted = format(source);
const fragment = format(selected, { fragmentBraceDepth: 2 });
const blocked = convertDotSyntaxToBlock(source);
const all = format(source, { convertDotSyntax: true });
```

## 开发

```bash
npm install
npm run build
npm test
```

```bash
cd packages/vscode
npm run build    # 本地调试，F5 启动扩展开发宿主
npm run package  # 打包 VSIX 发布
```

## 项目结构

```
packages/
  core/          # 格式化引擎、点转块、&sql 排版
  vscode/        # VS Code 扩展
tests/fixtures/  # 格式化与点转块用例
docs/            # 规则说明
```

## 反馈与交流

- **GitHub Issues**：[yaoxin521123/iris-prettier](https://github.com/yaoxin521123/iris-prettier/issues)
- **QQ 交流群**：**410039091**
- 规范说明：[`docs/RULES.md`](docs/RULES.md)

## 许可证

MIT
