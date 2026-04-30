# 1. 知识回顾

一个 Agent 包含哪些核心要素？

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/openclaw/agent-core-elements.svg)

- **身份 (Identity)**：Agent 是谁，叫什么？用什么风格说话？定义在 `IDENTITY.md` 中。
- **灵魂 (Soul)**：Agent 的思维方式、行为准则、专业能力范围，即遇到问题怎么想、怎么做。定义在 `SOUL.md` 中。
- **工具 (Tools)**：Agent 能调用哪些工具？搜索、画图、发消息、写文档等等，由 Skills 决定
- **记忆 (Memory)**：Agent 需要记住什么？短期靠对话、长期靠文件。对应 `MEMORY.md` 和 `memory/` 目录
- **上下文 (Context)**：每次对话的历史、当前任务的背景信息。由 OpenClaw 自动维护会话上下文。
- **执行环境 (Workspace)**：Agent 的工作目录，有自己的文件系统。



# 2. Agent 的具体构成

每个 Agent 是一个目录，结构如下：

```
~/.openclaw/agents/draw/
├── agent/              ← Agent 核心配置目录
│   ├── IDENTITY.md     ← 身份定义
│   └── SOUL.md         ← 灵魂/行为准则
├── workspace/          ← 工作区
│   ├── skills/         ← 可用的技能目录
│   │   └── prompt-templates/
│   │       └── SKILL.md
│   ├── AGENTS.md       ← 工作区说明
│   ├── IDENTITY.md     ← 工作区身份（可继承）
│   └── SOUL.md         ← 工作区规则（可覆盖）
└── sessions/           ← 会话历史
```



**关键文件说明：**

| 文件        | 作用                                      |
| ----------- | ----------------------------------------- |
| IDENTITY.md | 定义 Agent 的名字、头像、说话风格         |
| SOUL.md     | 定义 Agent 的专业能力、工作流程、行为规范 |
| AGENTS.md   | 工作区的 AI 团队宪章                      |
| skills/     | 技能目录，存放可复用的工具包              |



**全局配置文件** `~/.openclaw/openclaw.json` 里面定义了：

- Agent 列表

- 工具配置（web search、QQ channel 等）

- 插件和扩展

- Gateway 配置



# 3. 三种方式构建Agent

## 3.1 命令行

```bash
openclaw agents add <agent-id> \  
    --workspace ~/.openclaw/agents/<agent-id>/workspace \
    --non-interactive
```

会在 `openclaw.json` 里注册一个新 Agent，并创建目录结构。



## 3.2 手动配置

步骤1：创建工作目录

```bash
mkdir -p ~/.openclaw/agents/draw
```



步骤2：编写 markdown 文件

```bash
cd ~/.openclaw/agents/draw

touch IDENTITY.md
touch SOUL.md
```



步骤3：注册

```bash
vi ~/.openclaw/openclaw.json
{
    // ...
    "agents": {
        "list": [
            {
                "id": "draw",
                "name": "draw",
                "workspace": "/root/.openclaw/agents/draw/workspace",
                "agentDir": "/root/.openclaw/agents/draw/agent"
            }
        ]
    }
}
```



## 3.3 对话创建

示例：

```
帮忙创建一个叫 '生图虾' 的Agent，专门负责生成图片，风格包括插画和学术图标
```

OpenClaw 自动完成：

1. 创建 Agent 目录结构
2. 编写 `IDENTITY.md`（定义名字、风格）
3. 编写 `SOUL.md`（定义工作流程）
4. 配置好技能目录和链接
5. 告诉你创建完成，可以直接使用

:warning: 通过对话创建的 agent，会自动生成在 `~/.openclaw/workspace` 下面，不符合官方规范



# 4. 实战：多agent协作

## 4.1 生图虾 Agent

**需求**：一个专门负责画图的 Agent，输入描述就能生成图片。支持的风格包括：

- 插画风格（二次元）

- 严谨学术三线表风

- 模块化信息卡片流风



**步骤 1：创建 Agent**

```bash
openclaw agents add draw \
   --workspace ~/.openclaw/agents/draw/workspace \
   --non-interactive
```



**步骤 2：编写 IDENTITY.md**

```markdown
# IDENTITY.md - Who Am I?

- **Name:**
  生图虾
- **Creature:**
  一只专业的AI图片生成助手 🦐
- **Vibe:**
  创意十足、热情满满、专注细节
- **Emoji:**
  🦐
- **Avatar:**
  https://media.craiyon.com/2025-10-16/OEOX_ZnpQm-CfhTV6HHQ2w.webp
```



**步骤 3：编写 SOUL.md**

核心流程：**先查 prompt-templates 技能 → 填充内容 → 调用 Doubao API 生成图片**

```markdown
## 工作流程
1. 识别用户指定的风格（插画/学术三线表/模块化卡片）
2. 到 prompt-templates 技能查找对应模板
3. 将用户描述填入模板，生成完整英文提示词
4. 调用 Doubao Seedream API 生成图片
5. 展示结果，询问是否需要调整
```



**步骤 4：配置技能**

为了支持多种风格，创建了一个 `prompt-templates` 技能：

```
mkdir -p ~/.openclaw/agents/draw/workspace/skills/prompt-templates
vi ~/.openclaw/agents/draw/workspace/skills/prompt-templates/SKILL.md
```

SKILL.md 里定义了三种风格的提示词模板。以**插画风格**为例：

~~~markdown
### 1. 插画风格（illustration）
**适用场景**：二次元插画、角色立绘、绘本风格

**模板结构**：
```
{A} with {B}, {C} style, {D} background, {E} lighting, high quality, detailed, anime illustration style, vibrant colors
```

**占位符说明**：
- `{A}` = 主体（人物/角色描述）
- `{B}` = 服装/装饰细节
- `{C}` = 风格修饰词（如 anime, fantasy, children's book）
- `{D}` = 背景场景
- `{E}` = 光影效果

**完整模板 Prompt**：
```
{A}, wearing {B}, {C} style, {D} background, {E} lighting, high quality, detailed, anime illustration style, vibrant colors
```
~~~

当用户说"画一只穿汉服的猫娘，插画风格"，生图虾就把"穿汉服的猫娘"填入 `{A}`，生成完整提示词后调用 API。



**步骤 5：配置 Doubao API**

在 Agent 工作区创建 `.env` 文件：

```
cat > ~/.openclaw/agents/draw/workspace/.env <<EOF
ARK_API_KEY=你的API密钥
VOLCENGINE_BASE_URL=https://ark.cn-beijing.volces.com/api/v3
EOF
```



## 4.2 写作虾 Agent

**需求：**写作虾要能完成完整的技术文章撰写流水线：

```
需求确认 → 调研(Tavily) → 大纲确认 → 逐节撰写→ 联网补充 → 自查润色 → 去AI味(humanize-zh)→ 生图(draw) → 发公众号
```



**步骤 1：创建 Agent**

```
openclaw agents add article-writer \
    --workspace ~/.openclaw/agents/article-writer/workspace \
    --non-interactive
```



**步骤 2：编写 SOUL.md**

写作虾的 SOUL.md 是整篇文章的核心。它定义了：

~~~markdown
**人设**：程序员出身，技术深厚，文笔流畅。

**九步工作流**（严格遵守）：
```
1. 需求理解 — 确认主题、受众、风格、篇幅
2. 初步调研 — 通过 Tavily Search 搜集资料
3. 大纲拟定 — 输出结构化大纲供用户确认
4. 逐节撰写 — 每个章节独立完成
5. 联网补充 — 深挖技术细节，验证数据
6. 自查润色 — 检查逻辑一致性、数据准确性
7. 去 AI 味 — 使用 humanize-zh 技能改写
8. 生成配图 — 调用生图虾子 Agent
9. 格式交付 — 输出 Markdown
```
~~~

**步骤 3：配置子 Agent 调用**

在 `~/.openclaw/openclaw.json` 文件中找到 `article-writer` agent 注册位置，添加 `subagents`：

```
vi ~/.openclaw/openclaw.json
{
  "agents": {
     ...
     "list": [
       ...
       {
         "id": "article-writer",
          "name": "article-writer",
          "workspace": "/root/.openclaw/agents/article-writer/workspace",
          "agentDir": "/root/.openclaw/agents/article-writer/agent",
          "subagents: {
             "allowAgents": ["draw"]
          }
       }
     ]
  }
}
...
```



写作虾在需要配图时，会通过 `sessions_spawn` 启动生图虾：

```python
sessions_spawn(
  task="画一张...",       # 生图任务描述
  runtime="subagent",  
  agentId="draw"           # 调用生图虾
)
```

这就是**多 Agent 协作**的核心机制。



**步骤 4：配置技能链接**

写作虾的工作区需要能访问其他技能和 Agent，通过**目录链接**实现：

```
~/.openclaw/agents/article-writer/workspace/skills/
├── tavily/              → 链接到全局 tavily 技能
├── humanize-zh/        → 链接到全局去AI味技能
├── wechat-article-publisher/  → 链接到公众号发布技能
└── draw/                → 链接到生图虾的工作区（调用而非读取）
```

实际操作：

```bash
# 安装缺失技能
npx clawhub@latest install humanize-zh

# 建立链接
mkdir -p ~/.openclaw/agents/article-writer/workspace/skills/
ln -s ~/.openclaw/workspace/skills/tavily ~/.openclaw/agents/article-writer/workspace/skills/tavily
ln -s ~/.openclaw/workspace/skills/humanize-zh ~/.openclaw/agents/article-writer/workspace/skills/humanize-zh
ln -s ~/.openclaw/agents/draw/workspace ~/.openclaw/agents/article-writer/workspace/skills/draw
```



## 4.3 多 Agent 协作

当你对写作虾说："帮我写一篇 RAG 技术科普文，配几张插图"

写作虾的内部执行流程是这样的：

```
用户请求
   ↓
[写作虾] 调研 → 写文章 → 去AI味
   ↓ 发现需要配图
[写作虾] 通过 sessions_spawn 启动生图虾
   ↓
[生图虾] 接收图片描述 → 查模板 → 填充提示词 → 调用Doubao API → 返回图片URL
   ↓
[写作虾] 将图片URL插入文章 → 格式调整 → 输出Markdown
   ↓
[写作虾] 调用 wechat-article-publisher → 发布到公众号草稿箱
```

技术实现上，这种协作依赖 OpenClaw 的几个机制：

1.sessions_spawn — 在独立 session 中启动子 Agent

2.共享 skills 目录 — 子 Agent 能访问父 Agent 的技能

3.Workspace 文件系统 — 图片 URL 通过文件传递

