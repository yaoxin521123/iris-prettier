# IRIS Prettier

<p align="center">
  <img src="images/icon.png" alt="IRIS Prettier" width="128" />
</p>

**语言：** [English](README.en.md) | 简体中文

面向 **InterSystems IRIS ObjectScript** 的 Prettier 风格格式化器，支持 `.cls`、`.mac`、`.int` 等文件。

只做**排版**，不做 Lint。适合在 VS Code 中配合 InterSystems 官方 ObjectScript 扩展使用。

## 安装

在 VS Code 扩展市场搜索 **IRIS Prettier**，或：

```
ext install iris-prettier.iris-prettier-vscode
```

**前置依赖**：需已安装提供 `objectscript` / `objectscript-class` 语言 ID 的扩展（如 [InterSystems ObjectScript](https://marketplace.visualstudio.com/items?itemName=intersystems-community.vscode-objectscript)）。

## 快速开始

1. 打开 `.cls` 类文件
2. 右键 → **格式化文档**，或 `Shift+Alt+F`
3. 选中代码后，右键可使用 **格式化选定内容** / **转换选定内容语法**；也可用 **预览格式化** / **预览语法转换** 在 diff 中确认后再应用
4. 推荐在 `settings.json` 中设为默认格式化器（见下方）

## 功能概览

### 格式化

| 能力 | 说明 |
|------|------|
| Allman 大括号 | `ClassMethod Foo()` 与 `{` 分行 |
| 运算符空格 | `=`、`+`、`-`、`*`、`/`、`_`、`:` 等两侧空格 |
| 括号内比较符 | `(Ingd <= 0)`、`(x >= 1)` 等 `<=` / `>=` 两侧空格 |
| 命令小写 | `Set` → `s`，`If` → `if` |
| 块命令展开 | `i` → `if`，`f` → `for`，`e` → `else` |
| 后置条件 | `q:cond`、`s:cond` 括号内运算符排版 |
| 方法间空行 | 相邻 `ClassMethod` / `Method` 之间插入空行 |
| `&sql(...)` | 多行 SQL 折行、关键字小写、注释跟在 `)` 后 |
| Tab 缩进 | 方法体内默认 Tab，IRIS 约定 1 Tab = 4 空格 |
| 选中格式化 | 根据方法体嵌套层级自动补全缩进，不只排版字面量 |

**示例：**

格式化前：

```objectscript
ClassMethod Foo() {
Set ret=1
If x=1  s y=2
.i (Ingd<= 0)  s Ret=Ingd q
.q:(info="")&&(flag="Y")
}
```

格式化后：

```objectscript
ClassMethod Foo() {
	s ret = 1
	if x = 1  s y = 2
	.i (Ingd <= 0)  s Ret = Ingd q
	.q:(info = "")&&(flag = "Y")
}
```

**块语法示例（非点语法）：**

格式化前：

```objectscript
ClassMethod M() {
If (count>0)&&(status="Y") {
Set ret=1
} Else {
Set ret=0
}
}
```

格式化后：

```objectscript
ClassMethod M() {
	if (count > 0) && (status = "Y") {
		s ret = 1
	} else {
		s ret = 0
	}
}
```

### 点语法转块（Dot → Block）

将 IRIS 传统点语法转为块级 `{ }` 写法，例如：

**转换前：**

```objectscript
i $d(^DHCRETA(0,"TypePointer","G",rowid)) d
.s retarowid=$o(^DHCRETA(0,"TypePointer","G",rowid,""))
.e  d
.&sql(insert into DHC_RetAspAmount ...)
i SQLCODE'=0  d
.s ret=$$SqlErrorRecord^DHCSTERROR(...)
```

**转换后：**

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

**`for` 点语法示例：**

转换前：

```objectscript
f  s info = $o(^IRIS("info", info)) q:info=""  d
.s flag = $p(^IRIS("info", info), "^", 1)
.i flag = "1"  d
.// todo
```

转换后：

```objectscript
for {
	s info = $o(^IRIS("info", info)) q:info=""
	s flag = $p(^IRIS("info", info), "^", 1)
	if (flag = "1") {
		// todo
	}
}
```

支持的常见模式包括：

- `i ... d` / `.i ... d` → `if (...) { }`
- `e d` / `else` / `e  i` → `} else {` / `} elseif (...) {`
- `for i = 1 : 1 : $l(...)` → 循环头保留在 `for` 行
- `for s x=$o(...) q:... d` → `for { s x=... q:... }`
- for 循环内 `q:` → `continue:`（含行内 `if` 体中的 `q`）
- 行内 `i cond s cmd`、`i count=0  w ... q ""` 等
- **选中片段**可直接转换，无需包含 `ClassMethod` 方法头

> **提示**：点转块会**先自动格式化再转换**，与手动「先格式化、再转块」效果一致。可用 **预览语法转换** 在并排 diff 中查看效果，确认后点 **应用语法转换** 写入。

## 命令与快捷键

| 操作 | 命令面板 | 右键菜单 | 快捷键 |
|------|----------|----------|--------|
| 仅格式化（全文） | `IRIS Prettier: Format Document` | — | `Shift+Alt+F` |
| 格式化当前方法 | `IRIS Prettier: 格式化当前方法` | ✓ | — |
| 预览格式化 | `IRIS Prettier: 预览格式化` | ✓ | — |
| 预览语法转换 | `IRIS Prettier: 预览语法转换` | ✓ | — |
| 格式化选定内容 | `IRIS Prettier: 格式化选定内容` | ✓ | `Ctrl+K` `Ctrl+F` |
| 转换选定内容语法 | `IRIS Prettier: 转换选定内容语法` | ✓ | — |
| 点语法转块（全文） | `IRIS Prettier: Convert Dot Syntax to Block` | — | `Ctrl+Shift+Alt+B` |
| 格式化 + 点转块 | `IRIS Prettier: Format + Convert Dot to Block` | — | `Ctrl+Shift+Alt+F` |

**选中操作说明**：

- 选区会自动扩展到整行
- 根据选中行之前的 `{` / `}` 推算当前块层级，输出与方法体内一致的缩进
- 「转换选定内容语法」流程：格式化 → 点转块 → 再格式化

**输出日志**：执行后在「输出」面板选择 **IRIS Prettier**，可查看方法名、行范围、变更行数；无变化时显示 `[skip]`。

**预览**：「预览格式化」在并排 diff 中对比修改前后；通知栏可点 **应用格式化** 一键写入（语法转换预览同理）。

## 推荐设置

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

扩展会为 ObjectScript 语言默认设置 `editor.tabSize: 4`。若全局 `editor.tabSize` 为 `2`，建议在上述语言块中显式覆盖。

## 配置项

| 配置项 | 类型 | 默认 | 说明 |
|--------|------|------|------|
| `irisPrettier.enable` | boolean | `true` | 是否启用格式化 |
| `irisPrettier.printWidth` | number | `120` | 参考行宽（长 `_` 拼接不自动折行） |
| `irisPrettier.useTabs` | boolean | `true` | 方法体内使用 Tab 缩进 |
| `irisPrettier.tabWidth` | number | `4` | `useTabs` 为 `false` 时每级缩进的空格数（IRIS 默认 1 Tab = 4 空格） |
| `irisPrettier.formatPostfixConditions` | boolean | `true` | 后置 `q:` / `s:` 条件排版 |

缩进由 `irisPrettier.useTabs` / `irisPrettier.tabWidth` 决定，**不**跟随 VS Code 全局 `editor.tabSize` 或 `insertSpaces`。

## 设计原则

- **只排版，不改语义**：不检查变量命名、不强制改写业务逻辑
- **保留 IRIS 习惯**：如 `e  i` 在纯格式化时保持缩写；点转块时才展开为 `elseif`
- **已有块语法不破坏**：`If ind="" { ... } Else { ... }` 等原样保留

## 已知限制

- 复杂嵌套点语法、极端边界情况可能需人工微调
- 默认不把条件里的 `,` 改为 `&&`（可通过 API 选项开启）
- 需 ObjectScript 语言扩展提供语法高亮与语言 ID

## 反馈与交流

- **GitHub Issues**：[yaoxin521123/iris-prettier](https://github.com/yaoxin521123/iris-prettier/issues)
- **QQ 交流群**：**410039091**
- **规范说明**：[docs/RULES.md](https://github.com/yaoxin521123/iris-prettier/blob/main/docs/RULES.md)

## 许可证

MIT
