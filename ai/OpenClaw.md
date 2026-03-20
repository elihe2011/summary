

# 1. 概述

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



# 2. 安装

```powershell
# 设置代理
$env:HTTP_PROXY='http://127.0.0.1:7890'
$env:HTTPS_PROXY='https://127.0.0.1:7890'

# 检查nodejs版本，22+
node -v

# 查看openclaw
npm view openclaw

# 安装最新版本
npm install -g openclaw@latest
```



# 3. 配置

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

