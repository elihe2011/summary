

# 1. 概述

## 1.1  简介

**OpenClaw 能做什么：**

- 能自动打开浏览器，操作所有和网页相关的任务，想象空间很大；

- 能操作你的电脑，安装软件、开发程序、帮你监控任务，都没问题；

- 能 24 小时不间断运行，你给一个任务，它自己拼命干完等你审核；

- 有向量记忆模块，越用越懂你。



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/data-flow-diagram.png)

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





![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/dopenclaw-arch-v5.png)



消息队列和去重：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/message-queue-deduplication.png)



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

OpenClaw 整个系统由“三个核心 + 一个扩展”构成：**入口 — 大脑 — 手脚 — 技能包**

- **入口 (Gateway)**：统一接收来自各种即时通讯软件的消息，做统一格式化和路由分发
- **大脑 (Agent Runner)**：调用大模型理解意图、规划步骤、决定调用那些工具，并在多轮循环里把任务跑完
- **手脚 (本地执行器/沙箱执行环境)**：真正去操作文件、命令行、浏览器、接口调用等，并做权限与安全控制
- **技能包 (Skills)**：让能力可以像“插件”一样扩展，装一个技能，就多一项执行能力

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/openclaw-architecture-v4.svg)



## 1.3 案例分析

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/task-execution-pipeline.png)

- 入口做 “翻译 + 分发”

  微信消息先被适配器捕获，转成内部通用格式 (JSON)，交给 Gateway 处理

- 大脑开始 ReAct 循环

  - **获取上下文**：加载近期对话 (短期记忆) + 用户偏好 (长期记忆)
  - **对比技能清单(Skills)**：本次可用哪些技能 (工具)
  - **调用模型输出计划**：将”用户需求“拆解成”可执行步骤“
  - **逐步执行**：每一步执行完，把结果喂回模型，再决定下一步
  - **循环直到结束**：完成、失败、或触发循环次数/时间上限

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/task-sequence-diagram.png)



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



# 3. 工作原理

## 3.1 核心机制

OpenClaw 的架构，可以用一句话概括：

**每次对话前，把一堆 md 文件拼进 prompt；对话后，让 agent 把新学到的东西回写到这些 md 文件中**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/recyclable-learning.png)



### 3.1.1 骨架

OpenClaw 给每个 agent 的 workspace 预设了 7 类核心文件：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/7-core-md-files.png)

**1、SOUL.md  — Agent 是谁**

它定义了 agent 的人格：语气、风格、边界、价值观。“This file is yours to evolve. As you learn who you are, update it."



**2、USER.md  — 用户是谁**

agent 对你的画像：你的名字、时区、工作习惯、技术偏好、沟通风格。每次对话中 agent 了解到关于你的新信息，就会更新这个文件。用得越久，这个画像越精准，agent 就越懂你。



**3、AGENTS.md  — 做事的规矩和踩过的坑**

最关键的一个文件。它定义了 agent 的行为规范，更重要的是，**记录了所有踩过的坑**。

- When you learn a lesson → update AGENTS.md, TOOLS.md, or the relevant skill

- When you make a mistake → document it so future-you doesn't repeat it."



**4、TOOLS.md  — 环境备忘**

记录你的工作环境：SSH 主机名、摄像头设备名、文件路径习惯等。agent 踩坑后自己补充。



**5、SKILL.md x N  — 各领域的操作手册**

每个 SKILL.md 定义了一个特定领域的操作规范。OpenClaw 内置了 52 个 skill，覆盖 GitHub issue 管理、邮件处理、健康检查、代码审查等。

你可以自己写 skill，比如每周要出一份固定格式的周报，可以把格式要求、数据来源、输出模板写成一个 SKILL.md，放到 workspace 中，从此 agent 每次做周包都会按照这个规范来，不需要你每个重新描述。

skill 的加载优先级：内置优先级最低，workspace 中自定义的优先级最高



**6、memory/*.md  — 日常记忆**

agent 每天都会写一个日期命名的 md 文件，记录当天的对话要点、做了什么、学到什么。这些文件会被索引到 SQLite 数据库里，支持全文搜素和向量检索。



**7、MEMORY.md  — 提炼后的长期记忆**

agent 会定期把 daily memory 里重要内容提炼到这个文件里。相当于从日记中整理出来的笔记精华。这个文件每次对话都会被加载进 prompt。



### 3.1.2 血肉

workspace 是一个普通文件夹，agent 有文件读写能力，可以在里创建任何它需要的文件和目录。

示例：项目管理 agent 的 workspace

```
workspace/
├── SOUL.md
├── USER.md
├── AGENTS.md
├── TOOLS.md
├── MEMORY.md
├── memory
│   ├── 2026-03-01.md
│   └── 2026-03-02.md
├── projects/
│   ├── project-alpha/
│   │   ├── progress.md
│   │   ├── decisions.md
│   │   └── risks.md
│   └── project-beta/
│       └── progress.md
├── templates/
│   ├── weekly-report.md
│   └── meeting-notes.md
└── contacts/    
    └── team-preferences.md
```



## 3.2 自我进化闭环

OpenClaw 设计了一个 agent 自我进化的闭环：

```
对话开始
→ 加载 workspace 所有核心 md 文件到 system prompt
→ agent 根据用户问题，先 memory_search 检索相关记忆
→ agent 执行任务
→ 任务中学到新东西 / 犯了错 / 发现了用户新偏好
→ agent 写回相关文件（AGENTS.md / USER.md / memory/*.md / MEMORY.md）
→ 文件变更触发 Memory 索引重建（SQLite FTS5 + 向量索引）
→ 对话结束

下次对话开始
→ 加载更新后的 md 文件
→ 搜索到新索引的记忆
→ agent 行为更精准
→ 循环
```

两层循环：

- **外层循环：md文件读写**。每次对话加载，对话中更新。这是“经验”层面的积累 -- agent 知道了那些事该做、那些事不该做、你喜欢什么、你的环境是什么样的。
- **内层循环：向量索引检索**。当 memory 文件越来越多，agent 不可能把所有内容都塞进 prompt (token限制)，所以 OpenClaw 用 SQLite 的 FTS5 全文搜素和 sqlite-vec 向量检索做了一个混合搜素引擎。agent 每次对话前被指令要求先搜素相关记忆再回答，这样即使积累了几个百个 memory文件，也能精准找到相关的信息。

两层循环合在一起，形成一个完整的 “学习 - 记忆 - 检索 - 应用” 系统。而这个系统的存储介质，全是 md 文件。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/agent-exprience-loop.png)



## 3.3 技术实现关键细节

### 3.3.1 Bootstrap 加载机制

每次对话开始，`resolveBoostrapContextForRun()` 函数会：

- 读取 workspace 下所有核心文件
- 根据会话类型过滤 (子 agent 只加载精简子集)
- 允许插件通过 hook 修改内容
- 每个我呢见限制 20KB，总量限制 150KB，超出部分截断

预算机制很重要，它意味着你的 md 文件不能无限膨胀。写得太多太杂，反而会被截断。所以 agent 需要学会“提炼”，把最重要的经验浓缩再有限的空间里。这也是为什么 MEMORY.md (提炼后的长期记忆) 和 memory/*.md (原始日记) 要分开的原因。



### 3.3.2 Memory 混合搜素

memory 搜素引擎用了 70% 向量相似度 + 30% 关键词匹配的混合权重，还支持 MMR (Maximal Marginal Relevance) 多样性和时间衰减，也就是说最近的记忆权重更高，而且搜素结果会尽量多样化，不会全是相似的内容。



### 3.3.3 Skill 发现优先级

SKill 从 6 个来源扫描，优先级从低到高：

- 插件提供的 skill
- 内置 skill
- 托管 skill (`~/.openclaw/skills/`)
- 个人 skill (`~/.agents/skills/`)
- 项目 skill (`{workspace}/.agent/skillss/`)
- Workspace skill (`{workspace}/skills/`)

用户 workspace 的 skill 优先级最高，可以覆盖任何内置行为。这意味着你完全可以“调教” agent 的任何技能，而调教的方式就是**写一个 md 文件**



### 3.3.4 自毁式引导

首次使用时，agent 会执行 BOOTSTRAP.md 里的引导流程来设置 IDENTITY.md、USER.md、SOUL.md。设置完成后，agent 被指令要求删除 BOOTSTRAP.md 本身。这是一次性的初始化过程，完成后就不再需要了。workspace 的状态机会记录引导完成的时间戳。



## 3.4 结论

### 3.4.1 agent 的价值在 workspace

代码时公开的，模型是通用的，真正属于你的、不可替代的部分，是 workspace 里面那堆 md 文件。它们编码了你的偏好、你的工作流、你踩过的坑、你的项目上下文。

换台电脑，把 workspace 拷贝过去，体验原封不动。删掉那个文件夹，一切从零开始。



### 3.4.2 调教 agent 就是写 md

不需要学编程，不需要理解 prompt engineering 的技术细节。只需要用自然语言把你的经验、偏好、规范写成 md 文件，放到 workspace 里面即可。OpenClaw 代码会自动把它们在合适的时机注入到 prompt 中

甚至你不需要自己写 — 跟 agent 对话过程中，它自己就会把学到的东西写成 md，你要做的就是在它犯错时纠正它，他会自己记住



### 3.4.3 agent 之间的差距就是 md 文件的差距

同样版本的 openclaw、同样的模型、体验可能天差地别。差别就在于它们各自的 workspace 里积累了什么。一个人用了三个月，workspace 里有几十个 skill、上百条踩坑积累、完整的用户画像；另一个刚装上，workspace 只有默认模板。

这跟现实世界的专家差距时一样的 — 两个人智商差不多 (模型一样)，差距在于积累的经验和知识 (md文件)



### 3.4.4 可能时 AI agent 产品的通用范式

OpenClaw 这套 “md 文件即知识” 的架构，具有普遍适用性。任何 AI agent 产品，如果想做到“越用越好用”，最终要解决**知识持久化和检索的问题**。OpenClaw 的答案时用最朴素的文件格式 (markdown)、最通用的存储方式 (文件系统)、最直觉的组织方式 (文件夹)，再加上一个搜索引擎把它们串起来。

没花哨的知识图谱，没有复杂的向量数据库集群，就是一堆 md 文件。但这堆 md 文件承载的是一个不断进化的专家系统 —— 它知道你是谁、你要什么、怎么做你的事、那些坑不能踩。



## 3.5 实操建议

- **主动引导 agent 形成 SOP**。不要等 agent 自己慢慢摸索，再已有成熟工作流领域，直接告诉它“以后这类任务按照这个流程来”，让它写成 SKILL.md
- **定期审查 workspace 文件**。agent 写的东西不一定对，定期看看 AGENTS.md、USER.md 里有没有过时会在不准确的内容，及时修正
- **善用多 agent**。不同领域配置不同 agent，让每个 agent 的知识积累保持垂直和纯粹。一个专做代码的 agent 比一个什么都做的 agent 好用的多。
- **选对模型**。模型是基础。一堆精心打磨的 md 文件为给一个弱模型，效果也有限。
- **备份 workplace**。这是你最有价值的数字资产之一。建议使用 git 管理，定期推送到远程仓库。



# 4. Context

```
Context = System Prompt
  + User Input
  + 历史对话
  + 工具返回结果
  + 检索内容（RAG）
  + Memory（长期记忆）
```



上下文和提示词：

- 提示词工程：如何提问、优化指令本身的设计、格式和措辞
- 上下文工程：给什么背景、筛选、加工和注入模型完成任务所需的外部知识和信息



标准工作流程：

- 上下文过程先行：通过 RAG、记忆、工具，把最相关的背景资料筛选出来
- 提示词工程收尾：把资料 + 问题，用精心设计的模板组装，送给模型



## 4.1 上下文工程

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/context-arch.png)



### 4.1.1 三层架构

**第一层：资源管理层**

负责管理所有上下文的信息来源。核心工作：决定哪些信息必须留、哪些可以删、冲突信息怎么处理。

```
用户配置
工作区文档（AGENTS.md、TOOLS.md 等）
对话历史、工具列表、长期记忆
```



**第二层：组装层**

把收集到的所有资源，按固定格式、固定顺序拼装

```
模型格式兼容问题
历史消息脏数据清理
Token 预算内的取舍权衡
```



**第三层：保护层**

确保系统安全稳定运行

```
检测上下文是否即将溢出
自动触发压缩
防止系统因上下文过大崩溃
```



### 4.1.2 上下文引擎

可插拔标准接口，定义上下文管理全生命周期。

默认提供传统引擎，支持自定义扩展，比如接入 RAG:

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/context-data-flow.png)



### 4.1.3 系统提示词构造器

生成 Agent 的身份说明，一段高质量的系统提示词，决定了 Agent 的能力上限：

```
你是什么
你能做什么
你应该遵循什么规则
你的工作目录在哪里
```



**Bootstrap 加载器**：读取工作区里的特殊配置我呢见，自动注入提示词：

```
AGENTS.md：项目行为规则
TOOLS.md：工具使用说明
MEMORY.md：长期记忆
SOUL.md：人格风格
```



**会话清理器**：修复历史消息里的所有问题，保证送给模型的历史干净、合规、兼容

```
删除无效工具调用
压缩超限图片
修复消息顺序错乱
处理跨会话消息标记
```

当上下文快撑爆时，就启动 **上下文压缩器** 自动瘦身，不丢关键信息



## 4.2 上下文组装

在开始组装任何内容之前，系统需要确定模型的上下文窗口大小，即模型一次能处理的最大 token 数量。

不同的模型上下文窗口不一样：小模型可能只有 32K tokens，而大模型可能有 200K 甚至更多。

OpenClaw 通过 4 个来源获取这个数值，优先级从高到低：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/context-window-configuration.png)

```
1. 配置文件中的明确指定：开发者可以在 models.providers.{provider}.models[].contextWindow 中明确指定。这个值的优先级最高，因为它代表了开发者的明确意图。
2. 模型元数据：OpenClaw 的模型发现系统会自动从模型提供商获取元数据，其中包含上下文窗口信息。
3. 默认值：如果前两个来源都不可用，系统使用 200,000 作为默认值。
4. 配置上限：最后，系统会检查 agents.defaults.contextTokens 配置，如果这个值小于前面计算的值，会使用这个较小的值作为上限。这可以防止开发者不小心配置了过大的上下文窗口。
```

确定上下文窗口后，系统还需要执行保护检查。即使在模型配置中明确指定了 contextWindow，系统还会检查 `agents.defaults.contextTokens` 配置。如果它更小，回使用它作为实际上限，防止配置过大的上下文窗口导致内存问题。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/context-window-protection-mechanism.png)



### 4.2.1 加载项目上下文

在确定上下文窗口大小后，系统开始收集项目特定的上下文信息。这些新来自工作区中的特殊文件，被称为“Bootstrap 文件”

Bootstrap 文件时开发者为 Agent 提供的“项目说明书”，例如：

```
- AGENTS.md：告诉 Agent 在这个项目中应该如何表现，有哪些特殊的规则要遵循
- TOOLS.md：解释项目中使用的特殊工具或命令
- MEMORY.md（或 memory.md）：记录重要的决策、约定或历史信息，确保 Agent 能够记住关键细节
- SOUL.md：定义 Agent 的人格和语气，让它的回复更加一致和有个性
- IDENTITY.md：定义项目身份和边界，说明这个工作区是什么、做什么的
- USER.md：提供用户特定的偏好和习惯，让 Agent 更好地适配用户风格
- HEARTBEAT.md：用于定时检查任务的指令
- BOOTSTRAP.md：仅在新工作区首次运行时提供初始化引导
```

系统会按优先级加载这些文件：主会话加载全部，子 Agent 和心跳运行只加载核心文件 (AGENTS.md、TOOLS.md、SOUL.md)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/bootstrap-truncation-strategy.png)



### 4.2.2 管理记忆内容

OpenClaw 的记忆分两层：

**第一层：工作区 Markdown 文件**。记忆的数据来源

```
~/.openclaw/workspace/
├── MEMORY.md           # 长期记忆（决策、约定、持久事实）
└── memory/
    ├── 2026-03-20.md   # 每日日志
    ├── 2026-03-21.md   # 今天
    └── ...
```



**第二层：向量索引**。方便“搜素”这些文件

系统会监控这些文件的变化，把它们切分成小块 (chunks，每块约 400 tokens)，然后用嵌入模型 (embedding) 把每块转换成向量。

这个索引存在在 SQLite 中，位置 `~/.openclaw/memory/<agentId>.sqlite`

搜素时，系统通过**混合检索：向量(权重70%) + 关键词 (权重30%)**，然后可选地应用时间衰减，最近的笔记权重更高和 MMR 去重，避免返回几乎相同的内容



### 4.2.3 Agent 访问记忆的方式

不是所有的记忆都会自动注入上下文。系统只会在主会话中自动注入 MEMORY.md 的内容，memory/*.md 文件通过工具按需访问：

- memory_search：语义苏索，返回相关片段
- memory_get：精确读取某个文件的第几行到第几行

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/memory-access.png)



### 4.2.4 加载可用工具

工具列表不是写死的，而是根据配置动态生成。

工具来源：

- **核心工具**：内置的，read、write、exec、grep、web_search 等
- **插件工具**：由插件提供，如 memory-core 的 memory_search、memory_get
- **渠道工具**：由消息渠道提供，如 Discord、Telegram 的 message 工具

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/tools-strategy-pipeline.png)

最终筛选出的工具会被格式化进系统提示词：

```markdown
## Tooling
Tool availability (filtered by policy):
- read: Read file contents
- write: Create or overwrite files
- edit: Make precise edits to files
- grep: Search file contents for patterns
...
```



### 4.2.5 加载可用 Skills

按照优先级合并：**额外+插件 < 内置 < 用户安装 < Agents 通用 < 项目专属 < 工作区本地**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/skills-source.png)

加载 Skills 时，系统会做几件事：

- **扫描目录**：从各个来源收集所有带 SKILL.md 的目录
- **解析 Frontmatter**：读取每个 skill 的元数据 (名称、描述、是否允许模型调用等)
- **过滤筛选**：根据配置过滤掉不应该启用的 skill (如设置了 disableModelInvocation)
- **去重合并**：同名 skill 只保留优先级最高的
- **Token 预算检查**：
  - 先尝试完整格式 (名称 + 描述 + 路径)
  - 超出预算切换到紧凑格式 (名称 + 路径)
  - 还是超直接截断，只保留前面的

最终生成的 skills prompt 如下：

```xml
<available_skills>
  <skill>
    <name>commit</name>
    <location>~/.openclaw/skills/commit/SKILL.md</location>
    <description>Create git commits following project conventions</description>
</skill>
<skill>
    <name>review-pr</name>
    <location>~/.openclaw/skills/review-pr/SKILL.md</location>
    <description>Review and merge pull requests with quality checks</description>
</skill>
  ...
</available_skills>
```

这个列表会被注入到系统提示词的 **Skills** 部分，并附带指令：

```
Before replying: scan <available_skills> <description> entries. If exactly one skill clearly applies: read its SKILL.md at <location> with `read`, then follow it.
```



### 4.2.6 构建系统提示词

系统提示词事发送给大模型的消息，它定义了 Agent 的基础身份和行为准则

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/system-prompt-structure.png)

```markdown
基础身份声明：首先是一个简单的句子"You are a personal assistant running inside OpenClaw."这确立了 Agent 的基本定位。

工具列表：接下来是 Agent 可以使用的工具列表。这个列表不是简单地把所有工具都列出来，而是经过筛选的。系统会检查每个工具是否在当前会话的允许列表中，是否被当前的消息渠道支持。对于每个工具，系统会提供工具名称和简短描述。描述需要简洁明了，让 Agent 知道什么时候应该使用这个工具。

工具调用风格指南：这部分告诉 Agent 应该如何调用工具。OpenClaw 的设计理念是"默认不叙述"——对于常规的、低风险的工具调用，Agent 应该直接调用工具，而不是向用户解释它要做什么。只有在复杂的多步骤任务、或者在执行敏感操作（如删除文件）时，才需要向用户说明。这种平衡能够提升用户体验，避免不必要的对话噪音。

安全指令：这是一个非常重要的部分，它定义了 Agent 的安全边界。指令明确指出 Agent 没有独立的目标，不应该追求自我保存、资源获取或权力扩张。它被要求优先考虑安全和人类监督，当指令冲突时应该暂停并询问。这些规则受到了 Anthropic 宪法的启发。

Skills 引导：OpenClaw 支持技能（Skills）系统，允许开发者定义可重用的 Agent 行为模板。系统提示词会告诉 Agent 在回复前扫描可用的技能列表，如果发现某个技能明确适用于当前任务，应该读取该技能的文档（SKILL.md）并遵循其指导。但如果多个技能都可能适用，应该选择最具体的一个；如果没有技能明确适用，就不应该读取任何技能文档。

记忆召回指令：如果启用了记忆搜索功能，系统提示词会告诉 Agent 在回答任何关于之前工作、决策、日期、人员、偏好或待办事项的问题时，应该先运行记忆搜索，然后使用记忆获取工具来拉取需要的行。这确保了 Agent 能够利用长期记忆来提供更好的服务。

工作区信息：这部分告诉 Agent 它的工作目录在哪里，以及应该如何处理文件操作。如果启用了沙箱模式，系统会特别说明文件工具和命令执行工具使用的路径是不同的——文件工具使用主机路径，而命令执行工具使用容器内的路径。

运行时元数据：最后，系统会附加一些运行时的技术信息，包括 Agent ID、主机名、操作系统、架构、Node 版本、当前使用的模型、Shell 类型、消息渠道等。这些信息虽然不直接影响 Agent 的行为，但在调试和诊断问题时非常有用。
```

系统提示词的构建还考虑了不同的提示词模式:

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/system-prompt-mode-table.png)



### 4.2.7 清理会话历史

从会话文件中读取的历史消息不能直接发送给大模型，它们可鞥包含各种格式问题、不兼容内容、过时的信息等。系统需要对每条信息进行仔细的清理和修复。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/history-sanitize-pipeline.png)

```
跨会话消息标记：当消息从一个会话传递到另一个会话时（比如用户让 Agent A 向 Agent B 发送消息），接收方会话需要知道这条消息来自外部。系统会在这些消息的内容前添加"[Inter-session message]"前缀，并附加来源信息（源会话键、源渠道、源工具等），让 Agent 能够区分内部消息和外部消息。

图像处理：图像是非常消耗 token 的内容。系统需要检查每条消息中的图像块，确保它们的大小在可接受范围内。如果图像的像素数量或字节数超出了限制，系统会对图像进行缩放，如果仍然超出则丢弃该图像。这确保了不会因为一张过大的图片而导致整个上下文溢出。

思考块处理：一些模型（如 Claude 的 extended thinking）会在回复中包含 <thinking> 块，用于展示模型的内部推理过程。这些思考块对于调试很有用，但在某些场景下需要被移除。系统支持根据策略来决定是否保留这些块。

工具调用清理：历史消息中可能包含对已经不存在或被重命名的工具的调用记录。系统会验证每个工具调用的名称是否在当前的允许列表中，如果不允许则移除或标记。此外，系统还会确保工具调用和工具结果的正确配对——每个工具调用后面应该有对应的结果消息，如果配对关系被打乱，系统会尝试修复。

工具结果详情剥离：工具的结果消息可能包含大量详细信息，比如执行输出的完整日志。这些详细信息在某些情况下是有用的，但在大多数时候只需要知道操作是否成功。系统支持剥离这些详细信息，只保留最核心的结果，以节省 token。

Usage 快照处理：每次模型调用都会产生 token 使用数据（input、output、cache read、cache write），这些数据被存储在 assistant 消息的 usage 字段中。系统需要确保每个 assistant 消息都有有效的 usage 快照，并且在会话压缩后清理过时的快照，避免旧的使用数据干扰当前的状态显示。

提供商特定处理：不同的模型提供商对消息格式有不同的要求。对于 Google/Gemini 模型，如果对话以 assistant 消息开头，模型会拒绝请求。系统会检测这种情况并在会话开头添加一个引导性的用户消息。为了防止重复修复，系统会在会话中添加一个标记，记录已经执行过这个修复。

对于 OpenAI 的 Responses API，系统会将推理块（reasoning blocks）降级为普通文本，因为该 API 不支持原生的推理格式。

模型变更检测：系统会在会话中记录最后使用的模型信息（提供商、API、模型 ID）。当检测到模型变更时，这可能是提示词格式需要调整的信号，系统会相应地调整清理策略。
```



### 4.2.8 最终上下文组装

在收集系统提示词和清理历史消息后，系统将它们组装成最终的上下文。该阶段的核心工作：

- **消息排序**：会话历史中的消息可能不是按时间顺序排列的，特别是在跨会话传递或经过修复后，系统需要确保消息是按照正确的时间顺序排列的，这样模型才能理解对话的因果关系。
- **token 预算检查**：估算系统提示词和所有历史消息的总 token 数，与之前确定的预算进行比较。如果超出预算，系统有两种选择：触发压缩或者截断最老的消息。

最终，上下文引擎会返回一个组装结果，包含有序的消息数组、估计的 token 数量，以及可选的系统提示词附加内容（某些引擎可能会在这里添加额外的指令）。



### 4.2.9 最终颜值

在将组装好的上下文发送给大模型之前，系统会执行最后一次验证，确保一切符合模型的要求。

提供商验证：不同的提供商对消息格式有不同的验证规则。

例如，Anthropic 要求对话必须以 user 消息开头，交替的 user-assistant 轮次不能被打断。OpenAI 则对消息顺序的要求更宽松一些。系统会根据目标提供商执行相应的验证。

Schema 清理：对于某些提供商（如 Google），工具的参数定义不能包含某些 JSON Schema 关键字（如 patternProperties、additionalProperties、$ref 等）。

系统会扫描所有工具的定义，移除这些不支持的关键字。

魔法字符串清理：Anthropic 有一个特殊的安全机制，如果消息中包含特定的"魔法字符串"，模型会拒绝响应。系统会检测这些字符串并将它们替换为无害的文本。

**通过这六个阶段，原始的用户输入被转换成了一个结构完整、内容相关、格式兼容的提示词，准备好被发送给大语言模型。**



## 4.3 上下文压缩

长期对话一定会填满上下文窗口，此时会触发压缩：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/compression-trigger-conditions.png)

```
1、自动触发 - 上下文溢出：当大模型 API 返回上下文溢出错误时，系统会立即触发压缩。这是最常见的触发场景，表示当前的上下文已经超出了模型的处理能力。
2、自动触发 - 预算阈值：系统在每次运行后会检查当前的上下文大小。如果大小超过了预算的一定比例（通常是 90%），系统会主动触发压缩，防止在下一次运行时溢出。
3、手动触发：用户可以通过发送 /compact 命令来手动触发压缩。这在用户知道对话已经很长，想要主动清理历史时很有用。手动触发会跳过阈值检查，强制执行压缩。
压缩的策略
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/compression-strategy.png)

```
1、摘要压缩：这是最智能的策略。系统会使用大模型来生成早期消息的摘要。摘要会保留关键信息，比如讨论了什么任务、做了什么决策、创建了哪些文件。然后系统用摘要替换原始的详细消息，大幅减少 token 使用量，同时保留对话的连贯性。
摘要压缩的质量取决于生成摘要时使用的指令。系统会告诉模型专注于关键任务、决策和标识符（如文件名、API 密钥等），并保护这些重要信息不被概括掉。

2、截断压缩：这是最简单的策略。系统直接丢弃早期的消息，只保留最近的消息。这种策略速度快，不需要额外的模型调用，但会永久丢失被丢弃消息中的信息。
截断压缩适用于不需要历史上下文的场景，或者当摘要压缩本身也可能失败时（比如上下文已经大到连摘要请求都无法处理）。

3、混合压缩：这是两种策略的结合。对于非常早期的消息，使用摘要压缩；对于中期的消息，可能直接截断；对于最近的消息，完整保留。这种策略试图在信息保留和性能之间找到平衡。
```



### 4.3.1 压缩的执行过程

当触发压缩时，系统会执行以下步骤：

```
1、计算token用量:系统会计算当前的 token 数量。如果有调用方提供的实时 token 数（来自最近的模型调用），会使用这个值；否则，系统会估算历史消息的总 token 数。

2、设定压缩目标（默认压到预算 80%）:系统会确定压缩的目标。如果配置的压缩目标是"预算"，系统会尝试将上下文压缩到 token 预算的 80%（留出一些安全边际）。如果是"阈值"，则压缩到更低的比例。

3、生成高质量摘要:它会将早期的消息提取出来，构造一个特殊的摘要请求，发送给大模型。摘要请求包含明确的指令，告诉模型应该关注什么、应该保留什么类型的信息。
收到摘要后，系统会构建新的消息历史。新的历史以一个特殊的 compactionSummary 消息开头，包含生成的摘要文本。然后是那些被保留的未压缩消息（通常是最近的消息）。

4、原子替换会话历史（不破坏原始文件):系统会清空会话文件并将新的消息历史写入。这个过程是原子的，确保在压缩过程中如果出现错误，不会破坏原始的会话文件。

5、压缩的安全保护:压缩操作本身也可能消耗大量资源。如果压缩请求发送给大模型后迟迟没有响应，或者压缩本身因为上下文过大而失败，系统不应该无限期等待。
因此，OpenClaw 为压缩操作设置了安全超时。默认的超时时间是可以配置的，通常设置为几分钟。如果压缩在超时时间内没有完成，系统会取消压缩操作并返回错误。
此外，系统还会监听未捕获的压缩失败。如果压缩在一个无法被 try-catch 捕获的地方失败（比如在异步回调中），系统会通过事件机制来捕获这些失败，触发会话恢复流程。
```



## 4.4 上下文引擎的可扩展设计

### 4.4.1 上下文引擎接口

上下文引擎是通过 ContextEngine 接口定义。这个接口包含了一组方法，覆盖了上下文管理的完整生命周期：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/context-engine-lifespan.png)

```
引导阶段（bootstrap）：当一个新会话创建时，引擎有机会执行初始化工作。它可以读取会话文件，导入历史消息，建立内部的数据结构。这个方法是可选的，简单的引擎可能不需要特殊的引导逻辑。

消息摄入（ingest/ingestBatch）：每当有新消息产生时，引擎的 ingest 方法会被调用。引擎可以将消息存储在自己的数据库中，建立索引，或者执行任何其他需要的处理。ingestBatch 方法允许引擎批量处理一个完整对话轮次的所有消息，这比多次调用 ingest 更高效。

上下文组装（assemble）：这是引擎的核心方法。在每次调用大模型之前，这个方法会被调用，引擎需要返回一个消息列表，这些消息将作为模型的上下文。引擎可以在这里实现智能的上下文选择策略，比如使用检索系统找到最相关的历史消息。

上下文压缩（compact）：当需要减少 token 使用时，这个方法会被调用。引擎可以实现自己的压缩算法，不一定是基于摘要的。比如，一个基于向量数据库的引擎可能只是简单地减少检索到的消息数量。

轮次后处理（afterTurn）：每次模型调用完成后，这个方法会被调用。引擎可以在这里执行清理工作，更新索引，或者触发后台的压缩决策。

子代理管理（prepareSubagentSpawn/onSubagentEnded）：这些方法支持多 Agent 协作。当主 Agent 准备生成子 Agent 时，prepareSubagentSpawn 会被调用，引擎可以为子 Agent 准备隔离的上下文环境。当子 Agent 结束时，onSubagentEnded 会被调用，引擎可以聚合结果并清理状态。

资源释放（dispose）：当会话结束或应用关闭时，这个方法会被调用，引擎应该释放所有持有的资源，比如关闭数据库连接、清理缓存等。
```



## 4.5 配置与调优

OpenClaw 的上下文工程系统有丰富的配置选项，允许开发者根据自己的需求调整行为。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/performance-configuration.png)

```
contextTokens：上下文 Token 预算（默认值是 200,000,建议设为模型窗口的 80~90%）
bootstrapMaxChars：单个 Bootstrap 文件最大字符
bootstrapTotalMaxChars：所有 Bootstrap 总字符上限
compaction.mode：压缩模式（auto/manual/off）
compaction.target：压缩激进程度(budget/threshold)
```

在 `models.providers.{provider}.models[]` 配置中，可以为每个模型设置特定的上下文窗口大小。这会覆盖自动发现的值，适用于模型元数据不准确的情况。

```json
"models": {
  "providers": {
    "anthropic": {
      "models": [
        {
          "id": "claude-sonnet-4-20250514",
          "contextWindow": 200000
        }
      ]
    }
  }
}
```

调优建议：

- 监控 Token 使用，避免频繁溢出
- 精简 Bootstrap 文件，删除冗余内容
- 复杂任务用子 Agent，降低主上下文压力
- 根据业务调整压缩阈值，平衡连续性与性能







# 4. Skills

## 4.1 什么是 skill

一个典型的 Skill 包结构如下：

- `SKILL.md`：定义它能干什么、怎么用、输入输出是什么、哪些场景触发。描述越清晰，模型越容易对。
- `scripts/`：真正可执行脚本 (Python/Shell/JS等)
- `referenes/`：参考材料 (业务规则、字段含义、API文档等)，按需加载，避免上下文爆炸

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/skill_package_architecture.svg)



**渐进式加载**：一开不会加载skill的所有信息，只有当模型决定要用某技能时，才加载更完整的说明；必要时再加载 referneces

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/agent-skills-vm.png)



## 4.2 安全性问题

第三方技能包可能存在的问题：

- 质量低，误调用或操作
- 携带私货，外传key、运行高危命令
- 被投毒，供应链攻击



OpenClaw 的三道防线：

- **权限分级与用户授权**，高危操作必须显式允许
- **命令和路径策略**，白名单/黑名单/规则引擎
- **沙箱隔离 + 审计日志**，能做什么、做了什么，可追溯



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/skills-progressive-disclosure.png)



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



# 5. 记忆、心跳、语义快照

## 5.1 记忆

记忆分层：

- **短期记忆**：近期对话日志，保证任务连续
- **长期记忆**：用户偏好、常用目录、规则、重要信息、跨会话复用

检索：

- **语义检索(向量)**：解决“同义表达”的召回
- **关键词检索**：解决精确命中与低成本定位



## 5.2 心跳

通过定时任务系统，主动提醒：

- 启动一个周期性触发器 (定时器/cron/heartbeat)
- 定期把“待执行任务”喂给 Agent Runner
- 循环执行“计划—执行—回传”，直至结束



## 5.3 浏览器语义快照

将“看网页”变成“读结构”

- **传统做法**：截图 + OCR/视觉模型，成本高、token高、定位不稳定

- **工程化做法**：拿六千的可访问树 (Accessibility Tree) 或 DOM 语义结构，变成文本描述，让模型用“结构化定位”做操作



OpenClaw 能力层：

openclaw-ability-layer.png
