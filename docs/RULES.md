# iris-prettier 可执行规则索引

> 来源：`代码规范 - 格式.md`、`代码规范 - 空行.md`  
> 原则：仅排版（Prettier），不做 Lint。

## 默认配置

| 选项 | 值 |
|------|-----|
| `printWidth` | 120 |
| `useTabs` | true |
| `tabWidth` | 4 |
| `braceStyle` | allman |
| `sqlKeywordCase` | lower |
| `expandBlockCommands` | true |
| `convertDotSyntax` | false（默认关；组合命令 `Ctrl+Shift+Alt+F` 会先格式化再点转块） |
| 点转块命令 | 默认**先格式化**再转换（`preFormat: true`） |
| `convertCommaLogic` | false（三期，默认关） |

## MVP 规则

| ID | 规则 | Fixture |
|----|------|---------|
| `brace-allman` | 方法 `{` 单独一行 | `tests/fixtures/brace-allman/` |
| `operator-spacing` | `=` `+` `-` `*` `/` `_` `:` 两侧空格；`,` 后空格 | `tests/fixtures/operator-spacing/` |
| `tab-indent` | 方法体内每级 1 Tab | `tests/fixtures/tab-indent/` |
| `command-lowercase` | 行首命令小写 | `tests/fixtures/command-lowercase/` |
| `system-function` | `$` 系统函数小写；有缩写用缩写（`$P`→`$p`，`$ListBuild`→`$lb`）；无缩写仅小写；不处理 `$$$` 宏 | `tests/fixtures/operator-spacing/` |
| `expand-commands` | 块内 `i`→`if`、`f`→`for`、`e`→`else`；`e i`/`else i`→`elseif` | `tests/fixtures/expand-commands/` |
| `postfix-condition` | 后置 `q:`/`s:` 等：有 `(...)` 则括号内运算符加空格，无括号则不改 | `tests/fixtures/postfix-condition/` |
| `blank-between-methods` | 方法之间 1 空行 | `tests/fixtures/blank-between-methods/` |
| `if-block-braces` | 已有 `if` 块换行与 `{}` 排版 | `tests/fixtures/if-block-braces/` |

## 二期规则

| ID | 规则 | Fixture |
|----|------|---------|
| `sql-multiline` | `&sql` 内 SQL 折行、小写、逗号行末 | `tests/fixtures/sql-multiline/` |
| `string-wrap` | 长 `_` 拼接赋值保持单行（不自动折行） | — |
| `blank-logical-sections` | 逻辑段、`#;`、事务块空行 | `tests/fixtures/blank-logical-sections/` |
| `dot-to-block` | 点语法 `.cmd` / 行末 `d` → 块级 `if`/`for`/`{ }`；`,`→`&&` | `tests/fixtures/dot-to-block/` |

## VS Code 快捷键

| 操作 | 命令 | 默认快捷键 |
|------|------|------------|
| 仅格式化 | `iris-prettier.formatDocument` / 默认 Formatter | **Shift+Alt+F** |
| 仅点语法→块语法 | `iris-prettier.convertDotToBlock` | **Ctrl+Shift+Alt+B** |
| 点转块 + 格式化 | `iris-prettier.formatDocumentWithDotConversion` | **Ctrl+Shift+Alt+F** |

## 排除（Lint / 不实现）

- 变量命名 `str1`/`str2`
- 返回值结构（数组/JSON vs `^` 拼接）
- `s` 与 `set` 混搭
- 对仗词命名
- `if` 嵌套层数
- 强制 `$CASE` 替换 `if-else` 链
- 强制 `$s` 三元
- 默认不将 `,` 改为 `&&`/`||`
