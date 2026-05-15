# 1. 简介

## 1.1 概述

Codex 是 OpenAI 推出的云端软件工程智能体（AI Agent）。

Codex 能自主理解、编写、调试与审查代码，可并行处理多项开发任务。

官方对 Codex 的描述是：**One agent for everywhere you code**。

Codex 像是一个能独立完成开发任务的工程师。

Copilot 是**代码补全工具**，即你写，它接着写。Codex 是**编程 Agent**，即你说话，它把活干完。



## 1.2 使用方式

提供四种使用方式，满足不同场景需求：

| 方式            | 说明                           | 适用场景               |
| :-------------- | :----------------------------- | :--------------------- |
| **Desktop App** | 桌面客户端                     | 完整功能、多项目并行   |
| **IDE 扩展**    | VS Code、Cursor、Windsurf 插件 | 深度集成开发环境       |
| **CLI**         | 终端交互式工具                 | 终端爱好者、脚本自动化 |
| **Web**         | chatgpt.com/codex 网页版       | 远程访问、并行任务     |



## 1.3 核心能力

| 能力           | 说明                                                         |
| :------------- | :----------------------------------------------------------- |
| **编写代码**   | 描述你想要构建的功能，Codex 生成匹配意图的代码，自动适应项目结构和规范 |
| **理解代码库** | 阅读和解释复杂或遗留代码，帮助你快速熟悉陌生项目             |
| **代码审查**   | 分析代码识别潜在 Bug、逻辑错误和未处理的边缘情况             |
| **调试修复**   | 追踪失败、诊断根因、提供针对性的修复方案                     |
| **自动化任务** | 执行重复性工作流：重构、测试、迁移、项目设置等               |



## 1.4 工作原理

每个任务运行在独立的**云端沙箱**中，流程如下：

```
输入任务 → 创建云环境 → 加载仓库 → 分析代码
        → 修改代码 → 运行测试 → 生成 PR → 等待审查
```

**两个关键优势：**

- **并行执行**：多个任务同时运行，不互相阻塞
- **安全隔离**：沙箱环境，不影响本地系统



## 1.5 系统架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/vibecoding/codex-system-arch.png)



# 2. 核心概念

## 2.1 Prompt

当提交 Prompt 后，Codex 按以下循环工作：

1. 调用语言模型理解任务
2. 执行模型输出指示的操作（读取文件、编辑代码、运行命令）
3. 将操作结果反馈给模型
4. 循环执行直到任务完成或你取消

*Codex 采用* **Agent 循环**模式工作——模型输出指示操作，操作结果反馈给模型，循环往复直到任务完成。



有效 Prompt 的原则：

| 原则             | 说明                           | 示例                                         |
| :--------------- | :----------------------------- | :------------------------------------------- |
| **包含验证步骤** | Codex 能验证工作时输出质量更高 | "写一个函数，包含测试用例验证它处理空列表"   |
| **拆解复杂任务** | 小任务更容易测试和审查         | "第一步：创建模型；完成后告诉我再继续第二步" |
| **提供上下文**   | 引用相关文件和图片             | "参考 src/auth.py 的风格，实现类似功能"      |



## 2.2 Thread

Thread 是单个任务会话：你的 Prompt 加上后续的模型输出和工具调用。



**线程类型**

| 类型         | 运行环境           | 特点                                   |
| :----------- | :----------------- | :------------------------------------- |
| **本地线程** | 你的机器（沙箱内） | 可读写文件、使用现有工具、执行命令     |
| **云端线程** | 云端隔离环境       | 克隆仓库运行、适合并行任务、跨设备委派 |



**线程使用规则**

运行中的线程可以并发，但需要注意：

- 避免两个线程同时修改同一文件
- 线程可以稍后通过继续另一个 Prompt 来恢复
- 长时间任务可能会自动压缩上下文



## 2.3 Context

当你提交 Prompt 时，包含 Codex 可以使用的上下文——对相关文件和图片的引用。

**上下文来源**：

- **IDE 扩展**：自动包含打开的文件列表和选中文本范围
- **手动指定**：在 Prompt 中引用文件路径或附加图片
- **对话历史**：线程中之前的对话内容



**上下文窗口：**

线程中的所有信息必须适合模型的上下文窗口。

Codex 会监控并报告剩余空间。当接近限制时，你会收到提示。



**自动 Compact**：

对于较长的任务，Codex 可能会自动压缩上下文。

压缩机制会总结相关信息，丢弃不太重要的细节，释放空间继续处理。



**管理上下文**：
```
# 开始新会话释放上下文
/new

# 查看当前上下文使用情况
/status
```

> 当 Codex 报告上下文使用量较高时，考虑开始新会话或减少历史消息。



## 2.4 Sandbox

Sandbox 是 Codex 的安全隔离机制，防止意外修改工作区外的文件。

**沙箱模式**:

| 模式                | 文件修改 | 网络访问 | 适用场景                   |
| :------------------ | :------- | :------- | :------------------------- |
| **Read-only**       | 禁止     | 禁止     | 只读分析、代码审查         |
| **Workspace-write** | 仅工作区 | 禁止     | 日常开发（默认）           |
| **Full-access**     | 允许     | 允许     | 完全信任的环境（谨慎使用） |



**Approval（审批）机制**:

某些操作需要你的确认才能执行：

- 执行 Shell 命令（特别是 rm、kill 等）
- 修改或删除文件
- 访问敏感目录（如 ~/.ssh/、/etc/）
- 网络请求



**设置沙箱模式**:

```
# 在 CLI 中切换沙箱模式
codex --sandbox workspace-write

# 或在 Prompt 中指定
"分析这个代码，不要修改任何文件"
```

> *沙箱是 Codex 安全策略的第一道防线，确保 AI 操作不会超出预期范围。*



## 2.5 Approval Policy（审批策略）

审批策略控制 Codex 执行操作前是否需要确认。

**策略类型**:

| 策略      | 说明     | 行为                           |
| :-------- | :------- | :----------------------------- |
| `ask`     | 每次询问 | 敏感操作前请求确认（默认）     |
| `approve` | 自动批准 | 自动执行，无需确认（谨慎使用） |
| `deny`    | 自动拒绝 | 拒绝所有可能产生副作用的操作   |



**配置审批策略**:

```bash
# ~/.codex/config.toml

approval_policy = "ask"
```



# 3. 安装

## 3.1 安装 CLI

```bash
npm install -g @openai/codex

codex --version

cat > ~/.codex/.env <<EOF
http_proxy="http://127.0.0.1:7890"
https_proxy="http://127.0.0.1:7890"
EOF

codex auth
```



## 3.2 三种运行模式

Codex CLI 提供三种安全模式。

| 模式      | 功能             |
| :-------- | :--------------- |
| Suggest   | 只建议修改，默认 |
| Auto Edit | 自动修改文件     |
| Full Auto | 自动执行所有操作 |



## 3.3 Windows 用户

### 3.3.1 沙盒模式

Windows 版有两种沙盒隔离级别：

- elevated：系统级隔离，权限完整，大多数场景用这个
- unelevated：权限受限，部分命令会报"权限不够"

设置位置：Codex 设置 → Sandbox → Elevated。



### 3.3.2 隔离桌面 (Private Desktop)

Windows 版默认开启隔离桌面——Codex 跑在一个独立的虚拟桌面里，和你正常使用电脑完全隔开。

这是为了安全，但意味着你看不到 Codex 在干什么，只能等它切回来才能看到结果。

**如果你想看着它干活**，去设置里把 Private Desktop 关掉，它就会在你的当前桌面里直接跑。



## 3.4 验证

安装 + 权限模式设好之后，跑一个最简单的测试命令，确认一切正常。

```
codex
```



# 4. 配置

## 4.1 配置文件

Codex 配置文件分层管理：

| 层级       | 路径                   | 作用范围     |
| :--------- | :--------------------- | :----------- |
| **用户级** | `~/.codex/config.toml` | 全局默认配置 |
| **项目级** | `.codex/config.toml`   | 项目特定配置 |
| **托管级** | 企业下发               | 企业统一配置 |

```toml
 ~/.codex/config.toml

# 默认模型
model = "gpt-5.4"

# 推理强度
model_reasoning_effort = "medium"  # minimal | low | medium | high | xhigh

# 推理摘要详细程度
model_reasoning_summary = "auto"  # auto | concise | detailed | none

# 服务层级
service_tier = "flex"  # flex | fast

# 审批策略
approval_policy = "suggest"  # suggest | auto-edit | full-auto
```



## 4.2 AGENTS.md

### 4.2.1 优先级

Codex 会在三个地方找 AGENTS.md，按优先级从高到低：

- **项目根目录的 `.codex/` 文件夹**（最近、最优先）

- **当前工作目录向上逐级查找**

- **用户全局目录 `~/.codex/`**

根目录的 AGENTS.md 写的是公司/团队规范，子目录的可以写项目专项规则。



### 4.2.2 示例

```markdown
# 项目开发规范

## 技术栈
- 前端：React + TypeScript
- 后端：Python FastAPI
- 数据库：PostgreSQL

## 代码规范
- 使用 4 空格缩进
- 每行最多 100 字符
- 所有函数必须有类型注解

## 测试要求
- 新功能必须包含测试
- 使用 pytest 运行测试

## Git 提交
- 使用 Conventional Commits 格式
- 提交信息描述"为什么"

## Review guidelines
- Don't log PII
- Verify authentication middleware
- Check for SQL injection
```



## 4.3 Skills

Skills 是可复用的自定义能力，封装常用任务逻辑。

### 4.3.1 技能目录位置

| 位置       | 路径                 | 作用         |
| :--------- | :------------------- | :----------- |
| **REPO**   | `.agents/skills/`    | 项目级技能   |
| **USER**   | `~/.agents/skills/`  | 用户级技能   |
| **ADMIN**  | `/etc/codex/skills/` | 系统级技能   |
| **SYSTEM** | 内置                 | 官方预置技能 |



### 4.3.2 技能结构

```
skill-name/
├── SKILL.md       # 技能定义（必需）
├── scripts/       # 可选脚本
├── references/    # 可选参考文档
└── assets/        # 可选资源
```



### 4.3.3 SKILL.md

```markdown
---
name: code-review-standard
description: 执行团队标准代码审查
---

# 代码审查标准

## 审查项目
1. 代码可读性
2. 潜在 Bug
3. 安全漏洞
4. 性能问题
5. 测试覆盖

## 输出格式
- 问题列表（按严重程度）
- 改进建议
- 评分（1-10）
```



### 4.3.4 技能触发

| 触发方式     | 示例                           |
| :----------- | :----------------------------- |
| **显式调用** | `$skill-name` 或 `/skill-name` |
| **隐式匹配** | 任务描述匹配技能 description   |



## 4.4 Subagents

Subagents 允许将复杂任务拆分给多个 Agent 并行处理。

### 4.4.1 内置代理类型

| 代理         | 功能                     |
| :----------- | :----------------------- |
| **default**  | 通用代理                 |
| **worker**   | 执行导向，适合实现和修复 |
| **explorer** | 探索导向，适合代码库分析 |



### 4.4.2 配置子代理

```toml
# ~/.codex/config.toml

[agents]
# 最大并行线程
max_threads = 6

# 最大嵌套深度
max_depth = 1

# 单任务超时
job_max_runtime_seconds = 1800
```



### 4.4.3 自定义代理

```toml
# ~/.codex/agents/reviewer.toml

name = "reviewer"
description = "专注代码审查和质量问题"
nickname_candidates = ["Reviewer", "QualityBot"]

developer_instructions = """
专注于代码质量审查：
- 检查代码风格一致性
- 发现潜在 Bug
- 评估测试覆盖
"""
```



## 4.5 Rules

Rules 定义命令执行策略，控制哪些命令可以自动执行。



### 4.5.1 规则文件

规则使用 Starlark 语言（类似 Python）：

```python
# ~/.codex/rules/default.rules

# 允许 Git 命令
prefix_rule(
    pattern = ["git"],
    decision = "allow",
    justification = "Git commands are safe"
)

# 禁止 rm -rf /
prefix_rule(
    pattern = ["rm", "-rf", "/"],
    decision = "forbidden",
    justification = "Prevent system damage"
)

# 询问 npm 命令
prefix_rule(
    pattern = ["npm"],
    decision = "prompt",
    justification = "npm may modify dependencies"
)
```



### 4.5.2 决策类型

| 决策        | 行为     |
| :---------- | :------- |
| `allow`     | 自动批准 |
| `prompt`    | 询问确认 |
| `forbidden` | 禁止执行 |



## 4.6 Hooks

Hooks 在特定事件时执行自定义脚本。



### 4.6.1 启用 Hooks

```toml
[features]
codex_hooks = true
```



### 4.6.2 Hook 事件

| 事件           | 触发时机   |
| :------------- | :--------- |
| `SessionStart` | 会话启动   |
| `PreToolUse`   | 工具调用前 |
| `PostToolUse`  | 工具调用后 |



### 4.6.3 配置 Hook

```json
{
  "hooks": [
    {
      "event": "PostToolUse",
      "matcher": {
        "toolName": "Bash"
      },
      "hooks": [
        {
          "type": "command",
          "command": "echo 'Command executed'",
          "timeout": 10
        }
      ]
    }
  ]
}
```



# 5. 进阶技巧

## 5.1 AGENT.md 项目级配置

在项目根目录创建 `AGENTS.md` 文件，可以为 Codex 提供项目特定的上下文和规则，Codex 启动时会自动读取：

```markdown
# AGENTS.md（放在项目根目录）

## 项目概述
这是一个基于 Next.js 14 + Prisma + PostgreSQL 的 SaaS 应用。
使用 App Router，不使用 Pages Router。

## 技术栈
- 前端：Next.js 14, React 18, TailwindCSS, shadcn/ui
- 后端：Next.js API Routes, Prisma ORM
- 数据库：PostgreSQL 15
- 认证：NextAuth.js

## 重要约定
- 所有数据库操作必须通过 lib/db.ts 中的 prisma 实例
- API 路由错误统一用 lib/api-error.ts 处理
- 环境变量在 .env.local 中，参考 .env.example

## 禁止事项
- 不要修改 prisma/schema.prisma，除非我明确要求
- 不要删除任何现有测试
- 生产环境的 .env 文件不要碰
```



## 5.2 会话管理

对于需要长期维护的大型任务，Codex CLI 支持会话的导出和恢复：

```bash
# 在交互界面中随时导出当前会话
/export session-2024-01-15.json

# 第二天继续工作时，恢复会话上下文
/load session-2024-01-15.json

# 或在启动时直接恢复上次会话
codex resume --last

# 查看所有保存的会话
ls ~/.codex/sessions/
```



## 5.3 提示词技巧

### 5.3.1 提供足够的上下文

```
# 模糊的提示
"修复 bug"

# 详细的提示
"用户登录时报错 TypeError: Cannot read properties of null，
报错发生在 src/auth/login.ts 第 42 行，
这个函数负责验证 JWT token，帮我找出并修复这个问题"
```



### 5.3.2 分步骤执行复杂任务

```
# 第一步：先让 Codex 分析，不要它直接改
"分析 src/api/ 目录的代码质量，列出主要问题，不要修改任何文件"

# 第二步：确认方案后再执行
"好，按你说的方案，先修复错误处理问题，然后我来 review"
```



### 5.3.3 利用 ask 模式探索

```
# 用 ask 模式（只读）先了解代码库
codex -a ask "这个项目是如何处理用户认证的？梳理完整的认证流程"

# 了解清楚后，再切换到 auto-edit 进行修改
/approvals  # 切换到 auto-edit 模式
```



### 5.3.4 善用否定指令

```
# 明确告诉 Codex 不要做什么，避免不必要的修改
"重构 utils/date.ts 中的日期格式化函数，不要修改函数签名，不要改变测试文件"
```



### 5.3.5 让 Codex 先汇报再执行

```
# 先让它列计划
"你打算怎么实现这个功能？先列出步骤，不要执行"

# 确认后再开始
"计划不错，开始执行第一步"
```



# 6. 速查表

## 6.1 命令速查表

### 6.1.1 CLI 基础命令

| 命令                | 说明               |
| :------------------ | :----------------- |
| `codex`             | 启动交互式 TUI     |
| `codex "任务"`      | 启动并执行指定任务 |
| `codex exec "任务"` | 非交互模式执行任务 |
| `codex --version`   | 显示版本信息       |
| `codex --help`      | 显示帮助信息       |



### 6.1.2 斜杠命令

| 命令               | 说明           |
| :----------------- | :------------- |
| `/model <name>`    | 切换模型       |
| `/fast`            | 切换 Fast 模式 |
| `/plan`            | 进入计划模式   |
| `/review`          | 审查代码变更   |
| `/new`             | 开始新会话     |
| `/resume`          | 恢复历史会话   |
| `/fork`            | 克隆当前会话   |
| `/compact`         | 压缩上下文     |
| `/status`          | 显示会话状态   |
| `/clear`           | 清除屏幕       |
| `/quit`            | 退出 Codex     |
| `/approval <mode>` | 切换审批模式   |



### 6.1.3 CLI 参数

| 参数                         | 说明               |
| :--------------------------- | :----------------- |
| `-m <model>`                 | 指定模型           |
| `--sandbox <mode>`           | 设置沙箱模式       |
| `--approval-mode <mode>`     | 设置审批模式       |
| `-i <file>`                  | 附加图片           |
| `-o <file>`                  | 输出到文件（exec） |
| `--full-auto`                | 全自动执行         |
| `--ephemeral`                | 不保存会话文件     |
| `--reasoning-effort <level>` | 推理强度           |



### 6.1.4 Shell 命令执行

| 格式           | 说明                       |
| :------------- | :------------------------- |
| `! <command>`  | 在 Codex 中执行 Shell 命令 |
| `! git status` | 查看 Git 状态              |
| `! npm test`   | 运行测试                   |



## 6.2 配置文件

### 6.2.1 配置文件位置

| 文件     | 路径                   | 作用         |
| :------- | :--------------------- | :----------- |
| 用户配置 | `~/.codex/config.toml` | 全局默认配置 |
| 项目配置 | `.codex/config.toml`   | 项目特定配置 |
| 项目指令 | `AGENTS.md`            | 项目行为规范 |
| 日志目录 | `~/.codex/log/`        | 运行日志     |
| 会话目录 | `~/.codex/sessions/`   | 会话记录     |



### 6.2.2 技能目录

| 位置   | 路径                 |
| :----- | :------------------- |
| 项目级 | `.agents/skills/`    |
| 用户级 | `~/.agents/skills/`  |
| 系统级 | `/etc/codex/skills/` |



## 6.3 快捷键

### 6.3.1 CLI 快捷键

| 快捷键          | 功能             |
| :-------------- | :--------------- |
| `Enter`         | 发送消息         |
| `Shift+Enter`   | 换行             |
| `Ctrl+C`        | 中断操作         |
| `Ctrl+C (两次)` | 退出 Codex       |
| `Ctrl+D`        | 退出（输入空时） |
| `Ctrl+R`        | 搜索历史         |
| `Up/Down`       | 浏览历史         |
| `Tab`           | 自动补全         |
| `Esc Esc`       | 编辑上一条消息   |
| `Ctrl+O`        | 复制最后回复     |



### 6.3.2 App 快捷键

| 快捷键             | 功能          |
| :----------------- | :------------ |
| `Cmd/Ctrl+N`       | 新建会话      |
| `Cmd/Ctrl+Shift+N` | 新建窗口      |
| `Cmd/Ctrl+W`       | 关闭窗口/标签 |
| `Cmd/Ctrl+[`       | 上一个标签    |
| `Cmd/Ctrl+]`       | 下一个标签    |



