# 1. 入门

## 1.1 概述

**什么是 OpenCode**

- 终端里运行的 AI 编程助手
- 说一句话 -> 读懂项目 -> 修改代码 -> 执行命令
- 不是 IDE，是 TUI (终端用户界面)



Vibe Coding 核心思想：改代码或写文章，动嘴不动手



AI 编程工具：

- IDE 类
  - Cursor
  - Windsurf
  - GitHub Copilot
  - Trae
- TUI 类
  - Claude Code
  - Codex CLI
  - OpenCode



## 1.2 安装

### 1.2.1 scoop

推荐普通用户权限下操作

```powershell
# 安装 scoop 
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# 指定 scoop 安装路径 (C:\Users\<username>\scoop)
$env:SCOOP='D:\dev\scoop'
$env:SCOOP_GLOBAL='D:\dev\scoop\global'
irm get.scoop.sh | iex  # 重新安装

# 永久环境变量
[Environment]::SetEnvironmentVariable("SCOOP","D:\dev\scoop","User")
[Environment]::SetEnvironmentVariable("SCOOP_GLOBAL","D:\dev\scoop\global","User")
```



### 1.2.2 opencode

```powershell
# 安装 opencode
scoop install opencode

# 查询版本
opencode --version

# 桌面版应用
scoop bucket add extras
scoop install extras/opencode-desktop
```



## 1.3 连接模型

方式一：TUI

```powershell
# 打开 TUI 终端界面
opencode

# 在 OpenCode 界面输入
/connect

# 切换模型
/models
```



方式二：终端

```powershell
# 直接在终端上输入
opencode auth login

# 查看已配置的提供商
opencode auth list
... Credentials ~\.local\share\opencode\auth.json
```



## 1.4 升级

```powershell
# 升级到最新版本
opencode upgrade

# 升级到指定版本
opencode upgrade 1.2.1
```



配置自动升级：`$env:USERPROFILE\.config\opencode\opencode.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "autoupdate": true  // true/false/notify
}
```



# 2. 日常使用

## 2.1 界面与操作

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-basic-operations.png)

核心操作：

- `@文件名` 引用到项目文件
- `!命令` 执行系统命令
- `/help` 查看帮助信息
- `Tab` 切换 Plan/Build 模式



**内容复制**：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-copy-paste.png)



**基础工具**：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-basic-tools.png)

**10个核心工具**：

| 工具      | 作用                       | 详情 |
| --------- | -------------------------- | ---- |
|read	|读取文件/目录	|大文件自动分段，支持图片和 PDF，可用 @ 提及目录|
|write	|创建/覆盖文件	|必须先读后写，写完自动 LSP 检查|
|edit	|精确字符串替换	|9 层智能匹配，不怕缩进差异|
|bash	|执行 Shell 命令	|有超时和安全检查，别用它操作文件|
|grep	|搜索文件内容	|正则表达式，最多 100 条结果|
|glob	|搜索文件名	|glob 模式，最多 100 条结果|
| Task      | 创建子 Agent 处理复杂任务  |      |
| WebFetch  | 获取网页内容               |      |
| TodoWrite | 任务清单管理 (AI 自动使用) |      |
| Skill     | 加载专业知识包             |      |

**TodoWrite**：创建一个任务清单，做完一项勾选一项，防止 AI “忘事”或“走偏”。当给 AI 一个复杂任务时，可能会看到它自动列出这样的计划

```
1. [ ] 分析代码结构
2. [x] 读取配置文件
3. [ ] 修改入口文件
4. [ ] 运行测试验证
```



**图片分析**：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-images.png)



## 2.2 管理对话

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-sessions.png)

多个会话的作用：

- **隔离上下文**：不同任务用不同会话，避免 AI 混淆
- **并行工作**：一边让 AI 写代码，一边让 AI 分析文档
- **保留历史**：重要对话可以保留，随时回看

会话数据存储在本地文件系统中：

```
~/.local/share/opencode/storage/
├── session/           # 会话信息
│   └── <project-id>/
│       └── <session-id>.json
├── message/           # 消息记录
│   └── <session-id>/
│       └── <message-id>.json
└── part/              # 消息片段（文本、工具调用等）
    └── <message-id>/
        └── <part-id>.json
```



## 2.3 常用快捷键

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-shortcuts.png)

**示例**：

| 要做什么     | 完整操作                | 错误操作                    |
| :----------- | :---------------------- | :-------------------------- |
| 新建会话     | 按 Ctrl+X → 松开 → 按 N | ❌ 同时按 Ctrl+X+N           |
| 打开会话列表 | 按 Ctrl+X → 松开 → 按 L | ❌ 按住 Ctrl 不放按 X 再按 L |
| 切换模型     | 按 Ctrl+X → 松开 → 按 M | ❌ 按太快没松开              |

高频快捷键：

| 快捷键      | 功能                         | 说明                                           |
| :---------- | :--------------------------- | :--------------------------------------------- |
| Enter       | 发送消息                     | 回车发送                                       |
| Shift+Enter | **换行（不发送）**           | 写多行提示词时用                               |
| Ctrl+C      | 清空输入 / 关闭对话框 / 退出 | 详见下方说明                                   |
| Escape      | 中断 AI 响应                 | AI 在生成时按，立即停止。**按两次可强制中断**  |
| ↑ / ↓       | 翻阅历史输入                 | **输入框为空时**，按上下键可找回之前发过的消息 |
| Tab         | 切换 Agent                   | 在 Plan/Build/不同 Agent 间切换                |
| Ctrl+X → N  | 新建会话                     | Leader 键 + N = **N**ew                        |
| Ctrl+X → L  | 会话列表                     | Leader 键 + L = **L**ist                       |



## 2.4 全局提示词

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-global-rules.png)

**三种作用域：**

| 作用域       | 位置                                   | 适用场景           |
| :----------- | :------------------------------------- | :----------------- |
| **全局规则** | `~/.config/opencode/AGENTS.md`         | 所有项目通用的偏好 |
| **项目规则** | 项目根目录 `AGENTS.md`                 | 项目特定的规范     |
| **配置文件** | `opencode.json` 的 `instructions` 字段 | 引用多个规则文件   |

🤔 为什么叫 AGENTS.md？

OpenCode 同时支持 `AGENTS.md` 和 `CLAUDE.md`（兼容 Claude Code）。推荐用 `AGENTS.md`，这是 OpenCode 的标准名称。



**规则加载顺序：**

规则按以下顺序加载，后加载的会**补充**（不是覆盖）前面的：

```
1. 全局 ~/.config/opencode/AGENTS.md
2. 全局 ~/.claude/CLAUDE.md（兼容模式）
3. 项目目录向上查找 AGENTS.md / CLAUDE.md
4. 配置文件 instructions 指定的文件
```



示例-1：全局规则 (`~/.config/opencode/AGENTS.md`)

```markdown
## 语言和风格

- 始终使用简体中文回复
- 直接回答问题，不要客套话
- 代码注释也用中文

## 代码规范

- 使用 2 空格缩进
- 变量名用驼峰命名（camelCase）
- 函数名用动词开头（如 getUserById）

## 工作习惯

- 修改代码前先阅读相关文件
- 不确定时先问，不要猜测
- 每次只做最小必要的修改
```



示例-2：项目规则 (`./AGENTS.md`)

```markdown
# 项目规则

## 技术栈
- 前端：React + TypeScript
- 后端：NestJS
- 数据库：PostgreSQL

## 代码规范
- 使用项目的 ESLint 配置
- 组件文件用 PascalCase 命名
- API 路由用 kebab-case
```

也可以用 `/init` 命令生成内容，AI 会分析并生成的规则大约 150 行，涵盖项目最重要的规范。

- 项目的构建/测试命令
- 代码风格（缩进、命名规范等）
- 使用的框架和库
- 已有的 Cursor/Copilot 规则（如果有）



**通用开发规则：**

```markdown
## 工作态度

- 每次工作都要用严谨的工作态度，保证完美的质量标准

## 沟通风格

- 直接输出代码或方案，禁止客套话（"抱歉"、"我明白了"等）
- 除非明确要求，否则不提供代码摘要

## 求真原则（禁止瞎猜）

- 不确定/信息不足时先查证或提问澄清
- 对环境/配置/源码/行为的结论必须有证据
- 回答里把"事实"和"推测/假设"分开写
```



**代码质量规则：**

```markdown
## 代码质量原则

- 优先代码可读性，做最简单的修改
- 禁止使用 `eslint-disable` 或 `@ts-ignore` 绕过问题
- 禁止使用 `any` 类型，必须定义明确的类型
- 不要为了向后兼容而保留废弃代码
- 删除未使用的代码，不要注释掉

## 复用优先

- 编写新代码前，先确认项目中是否已有类似实现
- 优先复用现有组件和工具函数，而非新建
```



**工作流程规则：**

```markdown
## 执行规范

- 任何非平凡任务，先制定计划再动手
- 修改代码前必须先阅读相关文件
- 修改完成后自行运行测试验证

## 子代理调度策略

- 尽可能调用子代理完成任务
- 能派给专家的就派，不要什么都自己干
```



配置文件引用：如果规则分散在多个文件，可以用配置文件统一引用

```json
// opencode.json
{
  "instructions": [
    "CONTRIBUTING.md",
    "docs/coding-standards.md",
    ".cursor/rules/*.md",
    "~/my-rules/common.md"
  ]
}
```



## 2.5 环境管理

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-manage-env.png)



# 3. 高效工作流

## 3.1 Plan vs Build

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-plan-build.png)

OpenCode 默认提供的两个主 Agent：

| Agent     | 类型    | 说明                                 |
| :-------- | :------ | :----------------------------------- |
| **Build** | Primary | 默认助手，所有工具可用，适合开发工作 |
| **Plan**  | Primary | 受限助手，权限询问，适合分析和规划   |



Plan Agent 使用**权限隔离**机制保护你的代码——它被禁止编辑源代码，只能编辑计划文件：

| 权限                      | Plan Agent                             | Build Agent |
| :------------------------ | :------------------------------------- | :---------- |
| `edit`（写/改文件）       | **deny**（禁止源代码，仅允许计划文件） | allow       |
| `bash`（执行命令）        | allow                                  | allow       |
| `read`、`grep`、`glob` 等 | allow                                  | allow       |

> ⚠️ **注意**：Plan Agent 可以编辑 `.opencode/plans/*.md` 计划文件，但不能编辑项目源代码。



**什么时候用 Plan：**

- 分析代码结构，但**不要改动**
- 让 AI 做规划和设计
- 代码审查
- 理解陌生代码库



**什么时候用 Build：**

- 让 AI 写新功能
- 让 AI 修 Bug
- 让 AI 重构代码
- 让 AI 创建/修改文件



**模式选择速查表：**

| 你的需求       | 推荐模式         | 原因                   |
| :------------- | :--------------- | :--------------------- |
| 写新功能       | Build            | 直接开发效率高         |
| 修简单 Bug     | Build            | 影响范围明确           |
| 重构核心模块   | 先 Plan 后 Build | 先分析影响，再动手     |
| 学习新代码库   | Plan             | 安全探索，不会误改     |
| 不确定改动影响 | Plan             | 分析完再决定           |
| 快速原型验证   | Build            | 迭代速度优先           |
| 团队协作任务   | 先 Plan 后 Build | 计划可审核，执行可追溯 |
| 代码审查       | Plan             | 只读分析，不修改       |

**简单口诀**：不确定 → 先用 Plan；确定了 → 直接 Build



**自定义 Agent，可在 `opencode.json` 中配置**：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    // Build Agent 配置
    "build": {
      "mode": "primary",
      "model": "anthropic/claude-opus-4-5-thinking",
      "temperature": 0.3,
      "permission": {
        "edit": "allow",
        "bash": "allow"
      }
    },
    // Plan Agent 配置
    "plan": {
      "mode": "primary",
      "model": "anthropic/claude-opus-4-5-thinking",
      "temperature": 0.1,
      "permission": {
        "edit": {
          "*": "deny",                    // 禁止编辑所有源代码
          ".opencode/plans/*.md": "allow" // 只允许编辑计划文件
        },
        "bash": "allow"
      }
    }
  }
}
```



## 3.2 Agent

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-agents.png)

**内置 Agent：**

| Agent   | 类型     | 擅长                                           | 默认权限                                                 |
| :------ | :------- | :--------------------------------------------- | :------------------------------------------------------- |
| Build   | Primary  | 全能开发（默认主 Agent）                       | 全能（可读写文件、执行命令）                             |
| Plan    | Primary  | 分析代码、规划方案、审查建议                   | 受限（默认禁止编辑，仅 `.opencode/plans/*.md` 允许写入） |
| Explore | Subagent | 快速找到文件、搜索代码、回答代码库问题         | 只读（可搜索、浏览代码）                                 |
| General | Subagent | 复杂研究、多步骤任务、不确定能否快速找到答案时 | 多任务执行（可用 Todo 工具）                             |



**3 个隐藏的内部 Agent，自动在后台工作**：

| Agent          | 作用         | 触发时机                                     |
| :------------- | :----------- | :------------------------------------------- |
| **compaction** | 上下文压缩   | 当对话接近模型上下文限制时，自动压缩历史消息 |
| **title**      | 会话标题生成 | 创建新会话后，自动生成描述性标题             |
| **summary**    | 会话摘要生成 | 压缩会话时，生成摘要替代历史消息             |



示例：

```bash
# 调用 Explore Agent
@explore 帮我梳理这个项目的整体结构
@explore 彻底分析这个项目的认证和鉴权实现，要非常全面

# 调用 General Agent
@general 帮我研究 Node.js 和 Python 的性能对比，并输出总结报告
```



## 3.3 项目初始化

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/opencode-init.png)

操作步骤：

```bash
# 进入项目目录
cd ~/your-project
opencode

# 执行初始化
/init
/init 特别关注 TypeScript 类型安全和错误处理

# 审核生成的规则
cat > AGENTS.md <<EOF
# SST v3 Monorepo Project
This is an SST v3 monorepo with TypeScript. The project uses bun workspaces for package management.
## Project Structure
- `packages/` - Contains all workspace packages (functions, core, web, etc.)
- `infra/` - Infrastructure definitions split by service (storage.ts, api.ts, web.ts)
- `sst.config.ts` - Main SST configuration with dynamic imports
## Code Standards
- Use TypeScript with strict mode enabled
- Shared code goes in `packages/core/` with proper exports configuration
- Functions go in `packages/functions/`
- Infrastructure should be split into logical files in `infra/`
## Monorepo Conventions
- Import shared modules using workspace names: `@my-app/core/example`
EOF
```































