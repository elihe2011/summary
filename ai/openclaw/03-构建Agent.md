# 1. 构建Agent

创建 Agent 的三种方式



## 1.1 命令行

```bash
openclaw agents add <agent-id> \  
    --workspace ~/.openclaw/agents/my-agent-1/workspace \
    --non-interactive
```

会在 `openclaw.json` 里注册一个新 Agent，并创建目录结构。



## 1.2 手动配置

步骤1：创建工作目录

```bash
mkdir -p ~/.openclaw/agents/my-agent-2
```



步骤2：编写 markdown 文件

```bash
cd ~/.openclaw/agents/my-agent-2

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
                "workspace": "C:\\Users\\username\\.openclaw\\agents\\my-agent-2\\workspace",
                "agentDir": "C:\\Users\\username\\.openclaw\\agents\\my-agent-2\\agent"
            }
        ]
    }
}
```



## 1.3 对话创建

示例：

```
帮忙创建一个叫 '图片生成器' 的Agent，专门负责生成图片，风格包括插画和学术图标
```

OpenClaw 自动完成：

1. 创建 Agent 目录结构
2. 编写 `IDENTITY.md`（定义名字、风格）
3. 编写 `SOUL.md`（定义工作流程）
4. 配置好技能目录和链接
5. 告诉你创建完成，可以直接使用

:warning: 通过对话创建的 agent，会自动生成在 `~/.openclaw/workspace` 下面，不符合官方规范



# 2. 示例：多agent协作

## 2.1 图片生成 Agent

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
- **Name:** 生图虾
- **Creature:** 一只专业的AI图片生成助手 🦐
- **Vibe:** 创意十足、热情满满、专注细节
- **Emoji:** 🦐
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
touch ~/.openclaw/agents/draw/workspace/skills/prompt-templates/SKILL.md
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
ARK_API_KEY=你的API密钥
VOLCENGINE_BASE_URL=https://ark.cn-beijing.volces.com/api/v3
```













