

# 1. 概述

## 1.1  简介

**OpenClaw 能做什么：**

- 能自动打开浏览器，操作所有和网页相关的任务，想象空间很大；

- 能操作你的电脑，安装软件、开发程序、帮你监控任务，都没问题；

- 能 24 小时不间断运行，你给一个任务，它自己拼命干完等你审核；

- 有向量记忆模块，越用越懂你。



OpenClaw 通过 Gateway 网关将聊天应用连接到 AI 智能体。Gateway 是会话、路由和渠道连接的**唯一事实来源**。

**核心组件：**

1. Gateway 网关
   - 连接各个聊天平台（飞书、企微、QQ、Telegram等）
   - 管理会话和消息路由
   - 默认地址：`http://127.0.0.1:18789/`
   - 配置文件：`~/.openclaw/openclaw.json`
2. AI 智能体
   - 支持 Claude、GPT、Gemini、DeepSeek、Kimi 等多种模型
   - 可以本地运行或远程调用
3. Skills 技能系统
   - 文件管理、知识管理、自动化等
   - 可自定义开发
4. ClawHub
   - 技能市场，可以下载和分享 Skills



 **核心配置文件**

| 文件             | 作用      | 说明                         |
| :--------------- | :-------- | :--------------------------- |
| **SOUL.md**      | 人格/语气 | AI的性格、说话风格、行为准则 |
| **USER.md**      | 偏好设置  | 用户信息、习惯、偏好         |
| **AGENTS.md**    | 指令说明  | Agent的工作指令和任务说明    |
| **MEMORY.md**    | 长期记忆  | AI的长期记忆和学习内容       |
| **HEARTBEAT.md** | 检查清单  | 定期检查和维护任务           |
| **IDENTITY.md**  | 名称/主题 | AI的名称、身份、主题设定     |
| **BOOT.md**      | 启动配置  | 启动时的初始化配置           |



## 1.2 核心功能

从架构上，它本质是一个AI消息网关 + 智能体执行框架，核心干了三件事：

- **消息统一入口 (Gateway)，把所有聊天渠道统一起来**。WhatsApp、Telegram、Discord、iMessage 等以前需要打开一堆窗口，现在一个 Gateway 全部接管。这解决的是 AI 的“输入层”问题。
- **Skills 执行系统，让 AI 装上手脚**。Skills 是 AI可以调用的能力模块 —— 运行代码、调用 API、操作浏览器、读写文件、查询数据库等。
- **Agent 决策层，AI自己想清楚该做什么**。Agent 推理层载 Skills 之上，负责理解你说的是什么意思、决定调用那些工具，按什么顺序执行。这一步让 OpenClaw 从聊天机器人进化成行动型智能体。



## 1.3 核心架构

OpenClaw (Moltbot/Clawbot) 基于本地运行时的动态编排架构，打通了用户指令与大模型动态规划能力之间的壁垒。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/openclaw-agent-orchestration-arch.png)

- **动态上下文组装**：为模型提供“感知与装备”。在用户指令传递至大模型之前，Agent Runner 会动态组装一份详尽的 System Prompt.

  **注入工具箱**：注入当前可用工具列表 (如 read、edit、exec、browser 等) 及技能说明，明确告知模型的能力边界。

  **加载记忆与身份**：读取本地的 `SOUL.md` (性格设定)、`USER.md` (用户偏好)、 并从 `MEMORY.md` 中检索历史交互信息。

- **ReAct 动态编排模式**：实现“边想边做”。采用 **ReAct + Function Calling** 的工作范式，替代硬编码工作流：
  - **规划 (Plan/Resonng)**：大模型接收指令后，通过调用思维链 (Chain-of-Thought) 判断是否需要调用工具及调用何种工具。
  - **行动 (Act)**：若需要执行，模型输出结构化 JSON Schema (Tool Call)
  - **反馈与修正 (Reflect)**：模型根据工具返回结果评估任务状态，若未完成则跳转规划并进行下一轮循环，直至输出最终文本或达到最大轮数
- **基于 Lane 的串行化队列**：保证任务可靠性，未规避复杂规划中的竞态条件与异步混乱，通过引入 Lane 命令队列，**强行串行化**。每个会话拥有专用 Lane，确保所有工具调用与规划步骤顺序执行，避免日志交错与状态冲突。
- **任务拆解与子智能体 (Sub-Agents)**：面对复杂长石任务，主 Agent 通过 `session_spawn` 工具分裂出子智能体：
  - **独立上下文**：子 Agent 运行于独立的上下文，常采用精简提示词以节省 Token
  - **异步协同**：子 Agent 完成任务后回调通知主 Agent，支持“爬取并总结 10 个网站”等复杂指令的动态编排
- 系统特权与“夺舍”操作“：作为 Local-First 进程，OpenClaw 直接运行于宿主机并拥有 Shell 执行权限 (System Authority)：
  - **物理打通**：通过 `exec` 工具执行 `git` / `curl` / `npm` 等命令，或利用 **Bowser Relay** 等技术接管已打开的浏览器实例 (复用登录态与 Cookie)
  - **语义快照**：在网页操作中，将复杂页面转化为**可访问性树 (Accessibility Tree)** 的文本快照，以低成本高精度的感知方式，让模型理解网页结构并规划操作。



## 1.4 核心特性

OpenClaw是一个自托管的AI网关，通过单一Gateway同时连接WhatsApp、Telegram、Discord、iMessage、飞书等多个聊天渠道，让你随时随地通过熟悉的聊天应用访问AI助手。

核心特性包括：多渠道统一入口、多代理隔离架构、智能消息路由、子代理编排系统、安全隔离与权限控制、移动节点扩展、会话管理与持久化，以及灵活的部署方式。

每个代理拥有独立的Workspace、Session Store和Auth Profile，确保数据完全隔离。通过智能路由规则，不同消息可以自动路由到不同的代理，实现"一个AI，多个人格"的体验。

子代理系统支持并行任务处理，主代理可以spawn子代理进行复杂任务，完成后自动返回结果，提高效率。

移动节点支持iOS和Android设备，通过Pairing连接，提供Canvas、Camera、Voice等丰富功能，让你在手机上也能完整使用OpenClaw的能力。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/openclaw-message-gateway.png)



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/openclaw-multi-proxy-isolation.png)



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/openclaw-message-route-rules.png)



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/openclaw-sub-proxy-orchestration.png)



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/openclaw-security-access-control.png)



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/openclaw-mobile-node-extention.jpg)



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/openclaw-session-persistence.png)



## 1.5 OpenClaw 和 Agent

OpenClaw 本质是一个多 AI 助手管理工具，可以创建多个 Agent，每个 Agent 有独立的身份、工具和记忆系统。

Agent 即AI助手，可以给它设定角色 (比如“热点猎手”)、配置工具 (比如网络搜素)、写工作手册 (Agent.md)



# 2. 部署

## 2.1 安装

```powershell
# 设置代理
npm config set proxy http://127.0.0.1:7890
npm config set https-proxy http://127.0.0.1:7890

# 检查nodejs版本，22+
node -v

# 查看openclaw
npm view openclaw

# 安装最新版本
npm install -g openclaw@latest
```



## 2.2 配置

```powershell
# 进入配置向导
openclaw onboard --install-daemon

# 启动WebUI
openclaw gateway --port 18789 --verbose

# 重新配置
openclaw configure
```



常用命令

| 命令                     | 功能             |
| :----------------------- | :--------------- |
| `openclaw onboard`       | 重新进入配置向导 |
| `openclaw status`        | 查看运行状态     |
| `openclaw health`        | 健康检查         |
| `openclaw gateway start` | 启动服务         |
| `openclaw gateway stop`  | 停止服务         |
| `openclaw update`        | 更新到最新版本   |
| `openclaw doctor`        | 诊断问题         |
| `openclaw uninstall`     |                  |



# 4. Skills

OpenClaw 从三个地方加载 Skills：

- Bundled Skills：内置技能，由 OpenClaw 官方提供
- Managed Skills：托管技能，`~/.openclaw/skills`
- Workspace Skills：工作区技能，`<workspace>/skills`



## 4.1 常用 Skills

| skill                       | 类型         | 功能                                                         |
| --------------------------- | ------------ | ------------------------------------------------------------ |
| clawhub                     | 技能管理     | 当你有其他需要的时候让小龙虾自行检索并安装 Skill 即可        |
| self-improvement            | 自我改进     | 记录错误和学习                                               |
| desktop-control             | 桌面自动化   | 鼠标键盘控制                                                 |
| auto-updater                | 自动更新     | Clawdbot 和升级技能                                          |
| skill-vetter                | 安全扫描     | 扫描安装的技能是否安全，避免安装高风险技能把本地文件上传到非法云端 |
| subagent-driven-development | 任务分派     | 让你的 AI 学会委派，把子任务分配给其他 AI 并审核它们的工作，这样你就能专注于愿景，而不是苦力活 |
| vector-memory               | 向量记忆搜索 | 任务上下文太杂，导致记忆不准确的问题，通过它来解决           |
| browser                     | 浏览器自动化 | 登录网站、抓取信息、截图、导出PDF等                          |
| Brave Search                | 联网搜索     | 查资料、搜新闻、找答案                                       |
| Shell                       | 终端命令     | 文件操作、脚本执行 (权限极高，建议开启确认模式)              |
| Cron/Wake                   | 定时任务     | 每天推天气、周报提醒等                                       |
|                             |              |                                                              |



## 4.2 安装方式

### 4.2.1 ClawHub

```bash
# 安装ClawHub
npm i -g clawhub

# 搜索Skill
clawhub search "日历"

# 批量更新
clawhub update --all

# 安装 Browser
clawhub install browser

# 安装 Brave Search
clawhub install brave-search

# 安装 Shell
clawhub install shell

# 安装 Cron
clawhub install cron
```



### 4.2.2 Skills Cli

```bash
# 搜索 Skills
npx skills find [关键词]

# 安装 Skill
npx skills add <owner/repo@skill> -g -y

# 检查更新
npx skills check

# 更新所有 Skills
npx skills update
```



### 4.2.3 手动安装

```bash
# 1. 下载或复制 Skill 文件到本地
# 2. 放到 Skills 目录
cp -r /path/to/skill ~/.openclaw/skills/<skill-name>/

# 3. 验证安装
ls -la ~/.openclaw/skills/
```



## 4.3 安装Skills

### 4.3.1 Find Skills

Find Skills 是一个"元 Skill"，它的作用是帮你找到更多有用的 Skills。当你想知道"有没有能做 X 的 Skill"时，它就是你的好帮手。

| 命令                       | 说明            |
| :------------------------- | :-------------- |
| `npx skills find [query]`  | 搜索 Skills     |
| `npx skills add <package>` | 安装 Skill      |
| `npx skills check`         | 检查更新        |
| `npx skills update`        | 更新所有 Skills |



## 4.4 自建 Skills

### 4.4.1 Demo

步骤1：创建目录

```bash
# 进入你的 OpenClaw 工作区
cd ~/.openclaw/workspace

# 创建技能目录
mkdir -p skills/weather-reporter
cd skills/weather-reporter
touch SKILL.md
```



步骤2：编写 SKILL.md

```markdown
---
name: weather-reporter
description: 智能天气播报员，用生动的语言播报天气状况
---

# 天气播报员 Skill

当用户询问天气时，按以下流程播报：

## 播报流程

1. **获取天气数据**
   - 调用天气 API 获取当前天气
   - 记录：温度、湿度、风速、天气状况

2. **生成播报文案**
   - 用生动、拟人化的语言
   - 加入场景感（如"阳光正好，适合出门散步"）
   - 根据天气给出建议（穿衣、带伞等）

3. **格式化输出**
   - 使用 emoji 增强可读性
   - 结构清晰：今日天气 → 出行建议 → 温馨提示

## 示例输出

> 🌤️ 今日天气播报
>
> 天气：晴朗，微风拂面
> 温度：22°C，体感舒适
> 湿度：65%，空气清新
>
> 🚶 出行建议：
> - 阳光正好，适合户外活动
> - 轻薄外套即可，注意防晒
> - 风力较小，骑行很惬意
>
> 💡 温馨提示：今天是晒被子/洗车的好日子哦~ ☀️

## 注意事项

- 避免使用专业术语，用生活化语言
- 每条播报控制在 200 字以内
- 保持温暖、亲切的语气
```



步骤3：刷新 Skill

方法一：在 OpenClaw 对话中输入：

```
刷新技能列表
```



方法二：重启 Gateway

```powershell
openclaw gateway restart
```



步骤4：验证 Skill

用户："查一下北京今天的天气"

AI （使用 weather-reporter skill）:



### 4.4.2 SKILL.md

#### i. 最小可用格式

```markdown
---
name: my-skill
description: 简短描述这个技能做什么
---

# Skill 标题

这里是详细的指令内容...
```

必选字段：

- name：技能名称 (唯一标识符)
- description：简短描述 (告诉 AI 何时使用)



#### ii. 完整格式

```markdown
---
name: advanced-analyzer
description: 深度数据分析，支持多维度洞察和可视化建议
metadata:
  {
    "openclaw":
      {
        "emoji": "📊",
        "homepage": "https://github.com/example/analyzer",
        "requires":
          {
            "bins": ["python3"],
            "env": ["ANALYSIS_API_KEY"],
            "config": ["analysis.enabled"]
          },
        "primaryEnv": "ANALYSIS_API_KEY",
        "os": ["darwin", "linux"],
        "always": false
      }
  }
user-invocable: true
disable-model-invocation: false
command-dispatch: tool
command-tool: analyze
command-arg-mode: raw
---

# 高级数据分析 Skill

## 激活条件

当用户需要：
- 数据分析
- 趋势预测
- 报表生成
- 可视化建议

## 执行流程

1. **数据收集**
2. **数据清洗**
3. **多维度分析**
4. **生成报告**

## 使用工具

- `exec`：运行 Python 脚本
- `read`：读取数据文件
- `write`：输出分析报告
```



#### iii. 字段详解

**元数据：**

| 字段               | 类型    | 说明                                       |
| ------------------ | ------- | ------------------------------------------ |
| `emoji`            | string  | 在 macOS Skills UI 显示的表情符号          |
| `homepage`         | string  | 技能主页 URL                               |
| `requires.bins`    | array   | 必需的系统命令（必须存在 PATH 中）         |
| `requires.anyBins` | array   | 至少需要其中一个命令                       |
| `requires.env`     | array   | 必需的环境变量                             |
| `requires.config`  | array   | 必需的配置项（从 `openclaw.json`）         |
| `primaryEnv`       | string  | 主要环境变量名（用于 `apiKey` 配置）       |
| `os`               | array   | 支持的操作系统（`darwin`/`linux`/`win32`） |
| `always`           | boolean | 设为 `true` 则跳过其他过滤条件             |



**其他字段：**

| 字段                       | 说明                                         |
| -------------------------- | -------------------------------------------- |
| `user-invocable`           | 是否为用户可调用的（默认 `true`）            |
| `disable-model-invocation` | 是否在模型提示中隐藏（仍可通过命令调用）     |
| `command-dispatch`         | 命令分发模式（`tool` 直接调用工具）          |
| `command-tool`             | 当 `command-dispatch: tool` 时，调用的工具名 |
| `command-arg-mode`         | 参数传递模式（`raw` 原始参数）               |



### 4.4.3 使用工具

#### i. 声明工具依赖

```markdown
---
name: file-organizer
description: 自动整理文件到分类目录
---

# 文件整理 Skill

## 可用工具

你拥有以下工具：
- `exec`：执行 shell 命令
- `read`：读取文件内容
- `write`：写入文件
- `edit`：编辑文件（精确替换）

## 整理规则

### 1. 图片文件
- 命令：`mv *.jpg ~/Pictures`
- 规则： `.jpg`, `.png`, `.gif`, `.webp`

### 2. 文档文件
- 命令：`mv *.pdf ~/Documents`
- 规则：`.pdf`, `.doc`, `.docx`, `.txt`

### 3. 代码文件
- 命令：`mv *.py ~/Projects/code`
- 规则：`.py`, `.js`, `.ts`, `.go`

## 执行步骤

1. 列出当前目录的所有文件
2. 按类型分类
3. 创建目标目录（如果不存在）
4. 移动文件到对应目录
5. 生成整理报告

## 安全规则

- 先确认，再执行（避免误操作）
- 保留 `~/downloads` 目录结构
- 不移动隐藏文件（`.开头的文件）
```



#### ii. 使用系统命令

```markdown
## 步骤 3：数据分析

使用 Python 脚本分析数据：

```bash
python3 << 'EOF'
import json
import sys

data = json.load(open('data.json'))
# 分析逻辑...
print(json.dumps(result))
EOF
```

