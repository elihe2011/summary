# 1. 概述

## 1.1 简介

Deep Agents is an open source agent harness built for **long-running tasks**. It handles **planning, context management**, and **multi-agent orchestration** for complex work like research and coding.

三个关键词：

- **long-running tasks**：不是一问一答的 Chatbot，而是长时间运行的复杂任务
- **planning, context management**：自动拆任务、自己管记忆，不会干到一般忘了前面做了什么
- **multi-agent orchestration**：多 Agent 协作，像团队一样分工干活

Deep Agents 不是一个简单的 Agent 框架，而是一个套在模型外面的“装备系统”，让模型能干长任务、管上下文、调度子Agent



## 1.2 三层架构

Deep Agents 在 `LangChain` 生态里的位置：

```
┌─────────────────────────────────────────────────────────┐
│  Deep Agents (Agent Harness) - 套件层                    │
│  规划、文件系统、子代理、上下文管理、Skills...                │
└──────────────────┬──────────────────────────────────────┘
                   │ 底层依赖
┌──────────────────▼──────────────────────────────────────┐
│  LangGraph (Agent Runtime) - 运行时层                    │
│  状态机、持久化、流式输出、检查点                            │
└──────────────────┬──────────────────────────────────────┘
                   │ 底层依赖
┌──────────────────▼──────────────────────────────────────┐
│  LangChain (Core Framework) - 框架层                     │
│  模型抽象、工具定义、消息格式                                │
└─────────────────────────────────────────────────────────┘
```



## 1.3 Harness 能力

An opinionated, batteries-included agent out of the box.  一款自带预设、功能完备、开箱即用的代理。

- 规划能力
- 虚拟文件系统
- 文件系统权限
- 任务委派
- 上下文管理
- 代码执行
- 人工审核
- Harness 配置

除此外，Deep Agents 还利用技能和记忆来获取额外的上下文与指令。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-core-capabilities.png)



### 1.3.1 规划能力

通过 `write_todos` 工具生成和维护一个结构化的任务列表

特性：

- Track multiple tasks with statuses (`'pending'`, `'in_progress'`, `'completed'`)
- Persisted in agent state
- Helps agent organize complex multi-step work
- Useful for long-running tasks and planning



### 1.3.2 虚拟文件系统访问

提供一个可配置的虚拟文件系统，该系统可由不同的可插拔后端提供支持，这些后端支持以下文件系统操作：

| Tool         | Description                                                  |
| :----------- | :----------------------------------------------------------- |
| `ls`         | List files in a directory with metadata (size, modified time) |
| `read_file`  | Read file contents with line numbers, supports offset/limit for large files. Also supports returning multimodal content blocks for non-text files (images, video, audio, and documents). See supported extensions below. |
| `write_file` | Create new files                                             |
| `edit_file`  | Perform exact string replacements in files (with global replace mode) |
| `glob`       | Find files matching patterns (e.g., `**/*.py`)               |
| `grep`       | Search file contents with multiple output modes (files only, content with context, or counts) |
| `execute`    | Run shell commands in the environment (available with [sandbox backends](https://docs.langchain.com/oss/python/deepagents/sandboxes) only) |

虚拟文件系统被 Harness 的多项功能使用，例如技能、记忆、代码执行以及上下文管理，自定义工具和中间件时，也可以利用该文件系统。



### 1.3.3 **文件系统权限**

支持声明式权限规则，控制 Agent 可读取或写入哪些文件和目录。这些权限适用于内置文件系统工具，并按照声明的先后顺序进行评估，遵循“首个匹配优先”的语义。

工作原理：

- 创建 agent 时，通过 `permissions=` 参数传入规则列表
- 每条规则指定了 `operations` （“read”、“write”）、`paths`（glob patterns）及 `mode`（“allow”、“deny”）
- 首条匹配规则优先生效。若无规则匹配，则允许该操作。

用途：

- 限制 Agent 访问指定目录 (e.g. `/workspace/`)
- 保护敏感文件 (e.g. `.env`)
- 赋予 subagents 比 main agent 更小的访问权限



### 1.3.4 **任务委派 (subagents)**

主 agent 创建临时的 subagent，用于执行相互隔离的多步骤任务。

用途：

- 上下文隔离：subagent 不会干扰和污染 main agent 的上下文
- 并行执行：多个 subagent 可同时运行
- 专业化分工：subagent 可以配备不同的工具集和配置
- token效率：庞大的 subagent 上下文会被压缩为一个单一的最终结果

工作原理：

- main agent 通过内置的 `task` 工具创建 subagent，并为其分配独立的上下文
- subagent 自主执行，执行完毕后，向 main agent 返回一份单一的最终报告
- subagent 是无状态的，即无法向 main agent 发送多条连续消息

两类 subagent：

- 默认 subagent
  - 系统自主提供一个“通用型” subagent
  - 默认配备文件系统操作工具
  - 支持通过添加额外的工具或中间件进行自定义扩展
- 自定义 subagent
  - 支持自定义具备特定工具的专业化 subagent
  - 通过 `subagents` 参数进行配置



### 1.3.5 **上下文管理**

解决大模型输入 token 大小限制问题

工作原理：

- 输入上下文：系统提示、记忆、skills 及工具提示 共同构成
- 上下文压缩：通过内置的卸载和摘要机制，确保上下文始终维持在窗口限制范围内
- 任务隔离：subagent 负载隔离并处理繁重的工作负载，仅向 main agent 返回最终结果
- 长期记忆：借助虚拟文件系统，实现跨线程的持久化存储

用途：

- 支持执行超出单个上下文窗口容量的多步骤复杂任务
- 无需人工干预进行裁剪，确保最相关的信息始终处于智能体的感知范围内
- 通过自动摘要和卸载机制，有效降低 token 的消耗



### 1.3.6 **代码执行**

通过沙盒后端，在隔离环境中运行代码

工作原理：

- 如果沙盒后端实现了 `SandboxBackendProtocolV2` 协议，“执行”工具将会被添加到 Agent 的可用工具列表中
- 若未配置沙盒后端，将仅拥有文件系统工具（如 `read_file`、`write_file` 等），而无法运行命令
- “执行”工具会返回合并后的 `stdout`、`stderr`及退出码；对于过大的输出内容，工具会自动进行截断处理

用途：

- 安全性：代码在隔离环境中运行，从而保护宿主系统免受 Agent 操作影响
- 纯净环境：无需在本地进行繁琐的配置，即可使用特定的依赖项或操作系统设置
- 可复现性：确保不同团队之间拥有高度一致的代码执行环境。



### 1.3.7 人工介入

支持在指定的工具处暂停 Agent 的执行，以便进行人工审核或修改

配置方法：

- 通过 `interrupt_on` 参数，它是一个`dict`，配置工具名和bool(是否中断)
- 示例：`interrupt_on={"edit_file": True}`，每次编辑文件操作前暂停

用途：

- 敏感操作需要确认
- 流程性任务等待审批



### 1.3.8 Skills

支持各类技能，为 agent 提供专业化的工作流与领域知识

工作原理：

- skill 遵循 Agent Skills 标准
- 每个 skill 对应一个目录，其中包含一个名为 `SKILL.md` 的文件，用于存放操作指令及元数据。
- skill 目录中可包含额外的脚本、参考文档、模板及其他辅助资源。
- 采用“渐进式披露”机制——仅当智能体判定某项技能对当前任务确有助益时，才会将其加载。
- 智能体在启动时会读取每个 `SKILL.md` 文件中的“前置元数据”（frontmatter）；仅在确有需要时，才会进一步查阅完整的技能内容。

用途：

- 仅在必要时加载相关技能，降低 Token 的消耗
- 将各项能力打包整合为更宏大的操作单元，并为其注入更丰富的上下文信息
- 在不致使系统提示内容冗余繁杂的前提下，为智能体赋予了专业化的特长
- 实现了智能体能力的模块化构建，使其具备了高度的可复用性。



### 1.3.9 记忆

支持使用“持久化记忆文件”，为 agent 在跨会话交互中提供额外的上下文信息。这些文件中通常包含通用的编程风格、个人偏好、惯例及规范，旨在帮助 Agent 理解代码库协同工作，并循序你的个人偏好

工作原理：

- 利用 `AGENTS.md` 文件来提供持久化的上下文信息。
- 记忆文件总是会被加载（这一点不同于“技能”功能，后者采用的是渐进式披露机制）。
- 在创建 Agent 时，只需向 `memory` 参数传入一个或多个文件路径即可。
- 这些文件会被存储在智能体的后端存储中
  - `StateBackend`：内存存储，重启丢失
  - `StoreBackend`：
  - `FilesystemBackend`：映射到物理磁盘
  - **CompositeBackend**：不同路径用不同存储

用途：

- 提供了持久化的上下文信息，无需在每次会话开始时重复指定
- 非常适合用于存储用户偏好设置、项目规范指南或特定领域的专业知识
- 这些信息对智能体始终保持可用状态，从而确保智能体在各项任务中都能表现出一致的行为模式。



### 1.3.10 配置文件

每当选中特定的提供商（Provider）或模型时，Harness 即可应用一套声明式配置包（即 HarnessProfile）。这些配置文件用于在模型构建完成后调整其运行时行为，且无需编写针对单个代理（Agent）的独立设置代码。
工作原理：

- 在指定的提供商名称（例如“openai”）或“提供商:模型”组合键（例如“openai:gpt-5.4”）下注册配置文件。
- `create_deep_agent` 函数在解析模型时，会自动查找并应用相应的配置文件。
- 提供商层级与模型层级的配置文件会在解析阶段进行合并。

实用价值：

- 将针对特定提供商或模型的默认配置（如系统提示词微调、工具重写、中间件等）集中统一管理。
- 在切换模型时，无需修改 `create_deep_agent` 函数的调用代码。
- 通过“入口点”（Entry Points）机制，将可复用的配置文件作为插件进行分发。



## 1.4 设计思想

DeepAgents 三大设计原则：

- **封装通用能力**：任务规划、子智能体管理、文件系统等复杂逻辑全部隐藏在 `create_deep_agent` 内部，开发者无需编写任何 LangGraph 节点和边的代码。
- **简化开发**：原本需要数百行 LangGraph 才能实现的深度研究智能体，现在只需几十行配置即可完成。开发者只需要关注提示词工程和工具定义。
- **模块化组合**：主智能体、子智能体、工具都是独立模块，可以像搭积木一样自由组合、复用。可以为其它领域 (如数据分析、代码生成) 定义不同的子代理，轻松扩展智能体的能力。



通过 `agent.get_graph().draw_meraid_png()` 绘制 deep research 智能体的图结构如下，可以看到该图同样是 ReAct 的经典结构，并通过 `PathToolCallsMiddleware` 和 `SummarizationMiddleware` 等中间件扩展了 LangChain create_agent 的能力：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deep-research-graph.png)



# 2. Context

## 2.1 Input Context

### 2.1.1 System prompt

用于定义 agent 的角色、行为和知识领域

```python
agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    system_prompt=(
        "You are a research assistant specializing in scientific literature. "
        "Always cite sources. Use subagents for parallel research on different topics."
    ),
)
```



### 2.1.2 Memory

`AGENTS.md` 存储项目规范、用户偏好，及适用于所有对话的关键准则

```python
agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    memory=["/project/AGENTS.md", "~/.deepagents/preferences.md"],
)
```



### 2.1.3 Skills

按需提供能力，agent启动时会读取每个 `SKILL.md` 文件中的元数据 (frontmatter)，随后仅在判定某项技能相关性时，才会加载该金额跟的完整内容。这种渐进式披露机制既能降低 token 的消耗，又能确保提供专业的任务流程

```python
agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    skills=["/skills/research/", "/skills/web-search/"],
)
```



### 2.1.4 Tool prompts

用于规范模型如何使用工具的指令。所有工具都会公开元数据，供模型在接收提示时读取。这些元数据通常包括工具的 Schema 和描述。通过 `tools` 参数传递的工具，会将这些工具元数据呈现给模型。

```python
@tool(parse_docstring=True)
def search_orders(
    user_id: str,
    status: str,
    limit: int = 10
) -> str:
    """Search for user orders by status.

    Use this when the user asks about order history or wants to check
    order status. Always filter by the provided status.

    Args:
        user_id: Unique identifier for the user
        status: Order status: 'pending', 'shipped', or 'delivered'
        limit: Maximum number of results to return
    """
    # Implementation here
    ...
```



### 2.1.5 完整系统提示

Deep Agent 系统提示词组成：

- 指定 `system_prompt` 参数
- 未指定  `system_prompt` ，使用 deep agents 内置的 `BASE_AGENT_PROMPT`
- To-do list prompt: Instructions for how to plan with to do lists
- Memory prompt: `AGENTS.md` + memory usage guidelines (only when `memory` provided)
- Skills prompt: Skills locations + list of skills with frontmatter information + usage (only when skills provided)
- Virtual filesystem prompt (filesystem + execute tool docs if applicable)
- Subagent prompt: Task tool usage
- User-provided middleware prompts (if custom middleware is provided)
- Human-in-the-loop prompt (when `interrupt_on` is set)



## 2.2 Runtime context

运行时上下文指的是调用 Agent 时传入的、针对单次运行的配置信息。它不会自动被包含在模型提示词（Prompt）中；只有当工具、中间件或其他逻辑读取了这些上下文，并将其添加到消息列表或系统提示词中时，模型才能感知到它的存在。

可以利用运行时上下文来传递用户元数据（如 ID、偏好设置、角色）、API 密钥、数据库连接信息、功能开关（Feature flags），以及工具集或运行框架所需的其他数值。
通过 `context_schema` 参数来定义这些数据的结构：`dataclasses.dataclass` 或 `typing.TypedDict`。在调用 `invoke` 或 `ainvoke` 方法时，请通过 `context` 参数来传入具体的数值。

```python
from dataclasses import dataclass

from deepagents import create_deep_agent
from langchain.tools import tool, ToolRuntime

@dataclass
class Context:
    user_id: str
    api_key: str

@tool
def fetch_user_data(query: str, runtime: ToolRuntime[Context]) -> str:
    """Fetch data for the current user."""
    user_id = runtime.context.user_id
    return f"Data for user {user_id}: {query}"

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    tools=[fetch_user_data],
    context_schema=Context,
)

result = agent.invoke(
    {"messages": [{"role": "user", "content": "Get my recent activity"}]},
    context=Context(user_id="user-123", api_key="sk-..."),
)
```



## 2.3 Context compression

长时间运行的任务往往会产生大量的工具输出和冗长的对话历史。上下文压缩技术能够缩减智能体工作内存中的信息体量，同时保留与当前任务相关的关键细节。



### 2.3.1 Offloading

Deep Agents 利用内置的文件系统工具，自动卸载内容，并根据需要搜索及检索这些已卸载的内容。当工具调用的输入或结果超出特定的 Token 阈值（默认为 20,000）时，即会触发内容卸载。

1. **工具调用输入超出 20,000 个 Token**：文件写入和编辑操作会在 agent 对话历史中留下包含完整文件内容的工具调用记录。鉴于这些内容已持久化保存至文件系统，此类记录往往显得多余。当会话上下文占用量超过模型可用窗口的 85% 时，Deep Agents 会截断较早的工具调用记录，将其替换为指向磁盘文件的指针，从而减小当前活跃上下文的规模。

   ![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-offloading-inputs.avif)

2. **工具调用结果超出 20,000 个 Token** ：Deep Agent 会将响应卸载至已配置的后端，并将其替换为文件路径引用及前 10 行内容的预览。随后，agent 可根据需要重新读取或搜索该内容。

​	![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-offloading-results.avif)



### 2.3.2 Summarization

当上下文大小超过模型的上下文窗口限制（例如达到 max_input_tokens 的 85%），且没有更多上下文可供卸载时，deep agents 会总结消息历史记录。此过程包含两个部分：

- **上下文内摘要**：LLM 生成对话的结构化摘要，包括会话意图、创建的工件和后续步骤，该摘要会替换代理工作内存中的完整对话历史记录。

- **文件系统保存**：完整的原始对话消息作为规范记录写入文件系统。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-summarization.avif)

配置：

- 触发阈值设定为模型配置 `max_input_tokens`的 85%
- 保留 10% 的令牌作为近期上下文
- 若模型配置不可用，则回退至 170,000 令牌的触发阈值，并保留最近的 6 条消息 
- 若任何模型调用引发标准的 `ContextOverflowError`，Deep Agent 将立即回退至摘要模式，利用摘要内容加上近期保留的消息进行重试 
- 较早的消息将由模型进行摘要处理

streaming tokens:

```python
for chunk in agent.stream(
    {"messages": [...]},
    stream_mode="messages",
    version="v2",
):
    token, metadata = chunk["data"]
    if metadata.get("lc_source") == "summarization":
        continue
    else:
        ...
```

使用摘要中间件：

```python
from deepagents import create_deep_agent
from deepagents.backends import StateBackend
from deepagents.middleware.summarization import (
    create_summarization_tool_middleware,
)

backend = StateBackend  # if using default backend

model = "google_genai:gemini-3.1-pro-preview"
agent = create_deep_agent(
    model=model,
    middleware=[
        create_summarization_tool_middleware(model, backend),
    ],
)
```



## 2.4 Context isolation

subagents 解决了“上下文膨胀”的问题。当 main agent 使用那些会产生大量输出的工具（如网页搜索、文件读取或数据库查询）时，其上下文窗口往往会迅速被填满。subagent 通过隔离此类工作来解决这一问题，main agent 接收到的仅是最终结果，而无需接收生成该结果所需的数十次工具调用过程。此外，还可以针对每个 subagent 进行独立配置（例如，设定其所使用的模型、工具、系统提示词及技能），使其与主代理区分开来。

工作原理：

- main agent 拥有用于委派工作的任务工具
- subagent 在独立的全新上下文中运行
- subagent 自主执行直至任务完成
- subagent 向主代理返回一份单一的最终报告
- main agent 的上下文保持纯净

```python
research_subagent = {
    "name": "researcher",
    "description": "Conducts research on a topic",
    "system_prompt": """You are a research assistant.
    IMPORTANT: Return only the essential summary (under 500 words).
    Do NOT include raw search results or detailed tool outputs.""",
    "tools": [web_search],
}
```



## 2.5 Long-term memory

在使用默认文件系统时，Deep Agent 会将其工作记忆文件存储在 Agent State 中，而这种状态仅在单个线程的生命周期内保持持久。相比之下，长期记忆功能使Deep Agent 能够在不同的线程和对话之间持久化信息。Deep Agent 可以利用长期记忆来存储用户偏好、累积的知识、研究进度，或任何需要在单个会话结束后依然保持持久的信息。
若要使用长期记忆功能，必须采用 `CompositeBackend`，该后端能够将特定路径（通常为 `/memories/`）路由至一个 LangGraph 存储库（Store），从而提供跨线程的持久化存储能力。本质上，复合后端是一种混合存储系统：其中的部分文件能够无限期地保持持久，而另一些文件则仅局限于单个线程的范围内。

```python
from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, StateBackend, StoreBackend
from langgraph.store.memory import InMemoryStore

def make_backend(runtime):
    return CompositeBackend(
        default=StateBackend(runtime),
        routes={"/memories/": StoreBackend(runtime)},
    )

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    store=InMemoryStore(),
    backend=make_backend,
    system_prompt="""When users tell you their preferences, save them to
    /memories/user_preferences.txt so you remember them in future conversations.""",
)
```



# 3. Backends

预构建的文件系统后端：

| 内置后端                        | 示例                                                         | 描述                                                         |
| :------------------------------ | :----------------------------------------------------------- | ------------------------------------------------------------ |
| Default                         | `agent = create_deep_agent(model="gpt4.5")`                  | **Ephemeral in state**. The default filesystem backend for an agent is stored in `langgraph` state. Note that this filesystem **only persists *for a single thread*.** |
| Local filesystem persistence    | `agent = create_deep_agent(model="gpt4.5", backend=FilesystemBackend(root_dir="/Users/nh/Desktop/"))` | This gives the deep agent **access to your local machine’s filesystem**. You can specify the root directory that the agent has access to. Note that any provided `root_dir` must be an absolute path. |
| Durable store (LangGraph store) | `agent = create_deep_agent(model="gpt4.5", backend=StoreBackend())` | This gives the agent access to **long-term storage that is *persisted across threads*.** This is great for storing longer term memories or instructions that are applicable to the agent over multiple executions. |
| Sandbox                         | `agent = create_deep_agent(model="gpt4.5", backend=sandbox)` | Execute code in **isolated environments**. Sandboxes provide filesystem tools plus the `execute` tool for running shell commands. Choose from Modal, Daytona, Deno, or local VFS. |
| Local shell                     | `agent = create_deep_agent(model="gpt4.5", backend=LocalShellBackend(root_dir=".", env={"PATH": "/usr/bin:/bin"}))` | Filesystem and shell execution **directly on the host. No isolation**—use only in controlled development environments. |
| Composite                       | Ephemeral by default, `/memories/` persisted.                | The Composite backend is maximally flexible. You can specify **different routes** in the filesystem to point towards different backends. |

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-backends.svg)



## 3.1 内置后端

### 3.1.1 `StateBackend` (ephemeral)

```python
# By default we provide a StateBackend
agent = create_deep_agent(model="google_genai:gemini-3.1-pro-preview")

# Under the hood, it looks like
from deepagents.backends import StateBackend

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    backend=StateBackend()
)
```

工作原理：

- 通过 `StateBackend`，将文件存储在当前线程的 `LangGraph` Agent State 中

- 通过 `checkpoints`，在同一线程的 agent 实现多轮次之间的持久化



### 3.1.2 `FilesystemBackend` (local disk)

```python
from deepagents.backends import FilesystemBackend

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    backend=FilesystemBackend(root_dir=".", virtual_mode=True)
)
```

工作原理：

- 通过 `root_dir` 配置读写文件
- 设置`virtual_mode=True`，以便对 `root_dir` 下的路径进行沙箱隔离和规范化处理
- 采用安全路径解析机制，尽可能防范不安全的符号链接穿透风险；此外，还可以利用 `ripgrep` 实现快速文本搜索 (grep) 功能



### 3.1.3 `LocalShellBackend` (local shell) 

```python
from deepagents.backends import LocalShellBackend

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    backend=LocalShellBackend(root_dir=".", env={"PATH": "/usr/bin:/bin"})
)
```

工作原理：

- 通过引入 `execute` 工具，扩展 `FilesystemBackend` 的功能，使其能够在宿主机上执行 Shell 命令
- 命令之间在本地宿主机上执行，底层调用 `subprocess.run(shell=True)`，且不进行任何沙箱隔离
- 支持设置超时时间 (默认120s)、最大输出字节数 (默认100,000)，以及用于配置环境变量的 `env` 和 `inherit_env` 参数
- shell 命令将 `root_dir` 作为其工作目录，但仍可访问系统上的任意路径



### 3.1.4 `StoreBackend` (LangGraph store)

```python
from langgraph.store.memory import InMemoryStore
from deepagents.backends import StoreBackend

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    backend=StoreBackend(
        namespace=lambda ctx: (ctx.runtime.context.user_id,),
    ),
    store=InMemoryStore()  # Good for local dev; omit for LangSmith Deployment
)
```

工作原理：

- 将文件存储在由运行时提供的 LangGraph `BaseStore` 中，实现跨线程的持久化存储



#### 3.1.4.1 Namespace factories

命名空间工厂负责控制 `StoreBackend` 进行数据读写的具体位置。它接收一个 LangGraph Runtime 实例作为输入，并返回一个字符串元组，该元组用于存储命名空间。

可以使用命名空间工厂来隔离不同用户、租户或助手之间的数据。

```python
NamespaceFactory = Callable[[Runtime], tuple[str, ...]]
```

Runtime 提供：

- `rt.context`通过 LangGraph 的 `ContextSchema` 提供的上下文信息，例如 user_id
- `rt.server_info` 由 LangGraph Server 提供的特定元数据 (assistant ID, graph ID, authenticated user)
- `rt.execution_info` 执行身份信息 (thread ID, run ID, checkpoint ID)

```python
from deepagents.backends import StoreBackend

# Per-user: each user gets their own isolated storage
backend = StoreBackend(
    namespace=lambda rt: (rt.server_info.user.identity,),
)

# Per-assistant: all users of the same assistant share storage
backend = StoreBackend(
    namespace=lambda rt: (
        rt.server_info.assistant_id,
    ),
)

# Per-thread: storage scoped to a single conversation
backend = StoreBackend(
    namespace=lambda rt: (
        rt.execution_info.thread_id,
    ),
)
```



### 3.1.5 `CompositeBackend` (router)

```python
from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, StateBackend, StoreBackend
from langgraph.store.memory import InMemoryStore

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    backend=CompositeBackend(
        default=StateBackend(),
        routes={
            "/memories/": StoreBackend(),
        }
    ),
    store=InMemoryStore()  # Store passed to create_deep_agent, not backend
)
```

工作原理：

- 根据路径前缀将文件操作路由至不同的后端
- 在列表显示及搜索结果中，保留原始的路径前缀



## 3.2 定制后端

构建一个自定义后端，将远程文件系统或数据库文件系统（例如 S3 或 Postgres）映射并投射到工具（tools）的命名空间中。

设计原则：

- 使用绝对路径 (/x/y.txt)，确定如何将其映射至存储键 (keys) 或数据行 (rows)
- 高效实现 ls 和 glob，若底层存储支持，优先在服务器端进行过滤；否则在本地进行过滤
- 重新父类 `BackendProtocol` 的方法

- 返回结构化的结果对象，并包含一个专门的错误字段（error field），用于标识文件缺失或模式无效的情况（切勿直接抛出异常）



### 3.2.1 S3

```python
from deepagents.backends.protocol import (
    BackendProtocol, WriteResult, EditResult, LsResult, ReadResult, GrepResult, GlobResult,
)

class S3Backend(BackendProtocol):
    def __init__(self, bucket: str, prefix: str = ""):
        self.bucket = bucket
        self.prefix = prefix.rstrip("/")

    def _key(self, path: str) -> str:
        return f"{self.prefix}{path}"

    def ls(self, path: str) -> LsResult:
        # List objects under _key(path); build FileInfo entries (path, size, modified_at)
        ...

    def read(self, file_path: str, offset: int = 0, limit: int = 2000) -> ReadResult:
        # Fetch object; return ReadResult(file_data=...) or ReadResult(error=...)
        ...

    def grep(self, pattern: str, path: str | None = None, glob: str | None = None) -> GrepResult:
        # Optionally filter server‑side; else list and scan content
        ...

    def glob(self, pattern: str, path: str = "/") -> GlobResult:
        # Apply glob relative to path across keys
        ...

    def write(self, file_path: str, content: str) -> WriteResult:
        # Enforce create‑only semantics; return WriteResult(path=file_path, files_update=None)
        ...

    def edit(self, file_path: str, old_string: str, new_string: str, replace_all: bool = False) -> EditResult:
        # Read → replace (respect uniqueness vs replace_all) → write → return occurrences
        ...
```



### 3.2.2 Postgres

- 表结构

  ```sql
  create table files
  (
  	path text primary key,
      content text,
      created_at timestamptz,
      modified_at timestamptz
  )
  ```

- 工具映射为 SQL

  - ls -> `WHERE path like $1 || '%'`
  - glob -> filter in SQL or fetch then apply glob in Python
  - grep -> can fetch candidate rows by extension or last modified time, then scan lines



## 3.3 权限

通过权限配置，控制 agent 可以读取或写入哪些文件和目录

```python
from deepagents import create_deep_agent, FilesystemPermission

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    backend=CompositeBackend(
        default=StateBackend(),
        routes={
            "/memories/": StoreBackend(
                namespace=lambda rt: (rt.server_info.user.identity,),
            ),
            "/policies/": StoreBackend(
                namespace=lambda rt: (rt.context.org_id,),
            ),
        },
    ),
    permissions=[
        FilesystemPermission(
            operations=["write"],
            paths=["/policies/**"],
            mode="deny",
        ),
    ],
)
```



## 3.4 策略钩子

对于超出基于路径的 “允许/拒绝” 规则之外的自定义验证逻辑 (限流、审查日志、内容审核)，可通过对后端进行 子类 或 包装 来实现规则



### 3.4.1 子类重写规则 

示例：禁止对指定前缀的数据进行写入或编辑

```python
from deepagents.backends.filesystem import FilesystemBackend
from deepagents.backends.protocol import WriteResult, EditResult

class GuardedBackend(FilesystemBackend):
    def __init__(self, *, deny_prefixes: list[str], **kwargs):
        super().__init__(**kwargs)
        self.deny_prefixes = [p if p.endswith("/") else p + "/" for p in deny_prefixes]

    def write(self, file_path: str, content: str) -> WriteResult:
        if any(file_path.startswith(p) for p in self.deny_prefixes):
            return WriteResult(error=f"Writes are not allowed under {file_path}")
        return super().write(file_path, content)

    def edit(self, file_path: str, old_string: str, new_string: str, replace_all: bool = False) -> EditResult:
        if any(file_path.startswith(p) for p in self.deny_prefixes):
            return EditResult(error=f"Edits are not allowed under {file_path}")
        return super().edit(file_path, old_string, new_string, replace_all)
```



### 3.4.2 通用包装器 (适用于任何后端)

```python
from deepagents.backends.protocol import (
    BackendProtocol, WriteResult, EditResult, LsResult, ReadResult, GrepResult, GlobResult,
)

class PolicyWrapper(BackendProtocol):
    def __init__(self, inner: BackendProtocol, deny_prefixes: list[str] | None = None):
        self.inner = inner
        self.deny_prefixes = [p if p.endswith("/") else p + "/" for p in (deny_prefixes or [])]

    def _deny(self, path: str) -> bool:
        return any(path.startswith(p) for p in self.deny_prefixes)

    def ls(self, path: str) -> LsResult:
        return self.inner.ls(path)

    def read(self, file_path: str, offset: int = 0, limit: int = 2000) -> ReadResult:
        return self.inner.read(file_path, offset=offset, limit=limit)
    def grep(self, pattern: str, path: str | None = None, glob: str | None = None) -> GrepResult:
        return self.inner.grep(pattern, path, glob)
    def glob(self, pattern: str, path: str = "/") -> GlobResult:
        return self.inner.glob(pattern, path)
    def write(self, file_path: str, content: str) -> WriteResult:
        if self._deny(file_path):
            return WriteResult(error=f"Writes are not allowed under {file_path}")
        return self.inner.write(file_path, content)
    def edit(self, file_path: str, old_string: str, new_string: str, replace_all: bool = False) -> EditResult:
        if self._deny(file_path):
            return EditResult(error=f"Edits are not allowed under {file_path}")
        return self.inner.edit(file_path, old_string, new_string, replace_all)
```



# 4. Subagents

Deep agent 支持通过 `subagents` 参数指定自定义的 subagent，subagent 有助于实现“上下文隔离” (保持 main agent 上下文干净)，以及提供专门的指令

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-subagents.svg)



在构建复杂的 Agent 应用时，常面临的一个难题：随着任务步骤增多，单一智能体的上下文会变得臃肿，不仅影响性能，还容易让模型“迷失”在细节中。

在 `DeepAgents` 中，主智能体可以将任务委派给各个子智能体，从而：

- **保持主智能体的上下文清爽**

  子任务的执行细节不会挤占主智能体上下文 token 窗口，实现上下文隔离

- **子智能体更专注**

  每个子智能体只负责某一特定职责，配合针对性的工具，可以显著提升任务执行的效率与成功率



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-sub-agent.png)



## 4.1 配置说明

### 4.1.1 默认 subagent

默认情况下，deep agents 会自动添加一个同步名称为 `general-purpose` 的通用用途 subagent

- 拥有与 main agent 相同的系统提示
- 可访问所有相同的工具
- 使用相同的模型（除非被覆盖）
- 继承 main agent 的技能（当已配置技能时）

 

### 4.1.2 禁用 subagents

运行一个没有 `task` 工具的 agent，需要做两件事：

- harness profile

  ```python
  from deepagents import (
      GeneralPurposeSubagentProfile,
      HarnessProfile,
      register_harness_profile,
  )
  
  register_harness_profile(
      "openai:gpt-5.4",
      HarnessProfile(
          system_prompt_suffix="Respond in under 100 words.",
          excluded_tools={"execute"},
          excluded_middleware={"SummarizationMiddleware"},
          general_purpose_subagent=GeneralPurposeSubagentProfile(enabled=False),  # 禁用subagents
      ),
  )
  ```

- create_deep_agent

  ```python
  agent = create_deep_agent(
      model="claude-sonnet-4-6",
      subagents=[],    # 空列表或不传该参数
  )
  ```

  

### 4.1.3 SubAgent (Dictionary-based)

| Field             | Type                         | Description                                                  |
| :---------------- | :--------------------------- | :----------------------------------------------------------- |
| `name`            | `str`                        | Required. **Unique identifier for the subagent**. The main agent uses this name when calling the `task()` tool. The subagent name becomes metadata for `AIMessage`s and for streaming, which helps to differentiate between agents. |
| `description`     | `str`                        | Required. Description of what this subagent does. Be specific and action-oriented. **The main agent uses this to decide when to delegate.** |
| `system_prompt`   | `str`                        | Required. **Instructions for the subagent**. Custom subagents must define their own. Include tool usage guidance and output format requirements. **Does not inherit from main agent**. |
| `tools`           | `list[Callable]`             | Optional. Tools the subagent can use. Keep this minimal and include only what’s needed. Inherits from main agent by default. When specified, overrides the inherited tools entirely. |
| `model`           | `str` | `BaseChatModel`      | Optional. Overrides the main agent’s model. Omit to use the main agent’s model. **Inherits from main agent by default.** |
| `middleware`      | `list[Middleware]`           | Optional. Additional middleware for custom behavior, logging, or rate limiting. **Does not inherit from main agent.** |
| `interrupt_on`    | `dict[str, bool]`            | Optional. Configure **Human-in-the-Loop** for specific tools. Subagent value overrides main agent. Requires checkpointer. **Inherits from main agent by default. Subagent value overrides the default.** |
| `skills`          | `list[str]`                  | Optional. Skills source paths. When specified, the subagent will load skills from these directories (e.g., `["/skills/research/", "/skills/web-search/"]`). This allows subagents to have different skill sets than the main agent. **Does not inherit from main agent. Only the general-purpose subagent inherits the main agent’s skills**. When a subagent has skills, it runs its own independent `SkillsMiddleware` instance. Skill state is fully isolated—a subagent’s loaded skills are not visible to the parent, and vice versa. |
| `response_format` | `ResponseFormat`             | Optional. Structured output schema for the subagent. When set, the parent receives the subagent’s result as JSON instead of free-form text. Accepts Pydantic models, `ToolStrategy(...)`, `ProviderStrategy(...)`, or a raw schema type. |
| `permissions`     | `list[FilesystemPermission]` | Optional. Filesystem permission rules for the subagent. When set, **replaces** the parent agent’s permissions entirely. **Inherits from main agent by default.** |



### 4.1.4  CompiledSubAgent

| Field         | Type       | Description                                                  |
| :------------ | :--------- | :----------------------------------------------------------- |
| `name`        | `str`      | Required. Unique identifier for the subagent. The subagent name becomes metadata for `AIMessage`s and for streaming, which helps to differentiate between agents. |
| `description` | `str`      | Required. What this subagent does.                           |
| `runnable`    | `Runnable` | Required. A compiled LangGraph graph (must call `.compile()` first). |



## 4.2 SubAgent

```python
import os
from typing import Literal
from tavily import TavilyClient
from deepagents import create_deep_agent

tavily_client = TavilyClient(api_key=os.environ["TAVILY_API_KEY"])

def internet_search(
    query: str,
    max_results: int = 5,
    topic: Literal["general", "news", "finance"] = "general",
    include_raw_content: bool = False,
):
    """Run a web search"""
    return tavily_client.search(
        query,
        max_results=max_results,
        include_raw_content=include_raw_content,
        topic=topic,
    )

research_subagent = {
    "name": "research-agent",
    "description": "Used to research more in depth questions",
    "system_prompt": "You are a great researcher",
    "tools": [internet_search],
    "model": "openai:gpt-5.4",  # Optional override, defaults to main agent model
}
subagents = [research_subagent]

agent = create_deep_agent(
    model="claude-sonnet-4-6",
    subagents=subagents
)
```



## 4.3 CompiledSubAgent

```python
from deepagents import create_deep_agent, CompiledSubAgent
from langchain.agents import create_agent

# Create a custom agent graph
custom_graph = create_agent(
    model=your_model,
    tools=specialized_tools,
    prompt="You are a specialized agent for data analysis..."
)

# Use it as a custom subagent
custom_subagent = CompiledSubAgent(
    name="data-analyzer",
    description="Specialized agent for complex data analysis tasks",
    runnable=custom_graph
)

subagents = [custom_subagent]

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    tools=[internet_search],
    system_prompt=research_instructions,
    subagents=subagents
)
```



## 4.4 Override general-purpose subagent

```python
from deepagents import create_deep_agent

# Main agent uses Gemini; general-purpose subagent uses GPT
agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    tools=[internet_search],
    subagents=[
        {
            "name": "general-purpose",   # 通过名称覆盖默认的
            "description": "General-purpose agent for research and multi-step tasks",
            "system_prompt": "You are a general-purpose assistant.",
            "tools": [internet_search],
            "model": "openai:gpt-5.4",  # Different model for delegated tasks
        },
    ],
)
```



## 4.5 最佳实践

### 4.5.1 描述清晰

main agent 通过 description 来决定调用哪一个 subagent，所以 description 必须清晰具体

✅ **Good:** `"Analyzes financial data and generates investment insights with confidence scores"`

❌ **Bad:** `"Does finance stuff"`



### 4.5.2 系统提示词详细

包含工具如何使用、格式化输出等具体指引

```python
research_subagent = {
    "name": "research-agent",
    "description": "Conducts in-depth research using web search and synthesizes findings",
    "system_prompt": """You are a thorough researcher. Your job is to:

    1. Break down the research question into searchable queries
    2. Use internet_search to find relevant information
    3. Synthesize findings into a comprehensive but concise summary
    4. Cite sources when making claims

    Output format:
    - Summary (2-3 paragraphs)
    - Key findings (bullet points)
    - Sources (with URLs)

    Keep your response under 500 words to maintain clean context.""",
    "tools": [internet_search],
}
```



### 4.5.3 最小工具集

```python
# ✅ Good: Focused tool set
email_agent = {
    "name": "email-sender",
    "tools": [send_email, validate_email],  # Only email-related
}

# ❌ Bad: Too many tools
email_agent = {
    "name": "email-sender",
    "tools": [send_email, web_search, database_query, file_upload],  # Unfocused
}
```



### 4.5.4 按任务选择模型

```python
subagents = [
    {
        "name": "contract-reviewer",
        "description": "Reviews legal documents and contracts",
        "system_prompt": "You are an expert legal reviewer...",
        "tools": [read_document, analyze_contract],
        "model": "google_genai:gemini-3.1-pro-preview",  # Large context for long documents
    },
    {
        "name": "financial-analyst",
        "description": "Analyzes financial data and market trends",
        "system_prompt": "You are an expert financial analyst...",
        "tools": [get_stock_price, analyze_fundamentals],
        "model": "openai:gpt-5.4",  # Better for numerical analysis
    },
]
```



### 4.5.5 返回简洁结果

```python
data_analyst = {
    "system_prompt": """Analyze the data and return:
    1. Key insights (3-5 bullet points)
    2. Overall confidence score
    3. Recommended next actions

    Do NOT include:
    - Raw data
    - Intermediate calculations
    - Detailed tool outputs

    Keep response under 300 words."""
}
```



## 4.6 上下文管理

main agent 的运行时 Context，会自动传播至所有的 subagent

```python
from dataclasses import dataclass

from deepagents import create_deep_agent
from langchain.messages import HumanMessage
from langchain.tools import tool, ToolRuntime

@dataclass
class Context:
    user_id: str
    session_id: str

@tool
def get_user_data(query: str, runtime: ToolRuntime[Context]) -> str:
    """Fetch data for the current user."""
    user_id = runtime.context.user_id
    return f"Data for user {user_id}: {query}"

research_subagent = {
    "name": "researcher",
    "description": "Conducts research for the current user",
    "system_prompt": "You are a research assistant.",
    "tools": [get_user_data],
}

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    subagents=[research_subagent],
    context_schema=Context,
)

# Context flows to the researcher subagent and its tools automatically
result = await agent.invoke(
    {"messages": [HumanMessage("Look up my recent activity")]},
    context=Context(user_id="user-123", session_id="abc"),
)
```



### 4.6.1 Per-subagent conext

所有 subagent 均接收相同的父级上下文。如果要为某个 sub agent 指定上下文，可以在扁平化的上下文映射中使用命名空间键 (键名前加 sub agent 名称做前缀，如 `researcher:max_depth`)，或将这些设置建模为上下文类型的独立字段

```python
from dataclasses import dataclass

from langchain.messages import HumanMessage
from langchain.tools import tool, ToolRuntime

@dataclass
class Context:
    user_id: str
    researcher_max_depth: int | None = None
    fact_checker_strict_mode: bool | None = None

result = await agent.invoke(
    {"messages": [HumanMessage("Research this and verify the claims")]},
    context=Context(
        user_id="user-123",
        researcher_max_depth=3,
        fact_checker_strict_mode=True,
    ),
)

@tool
def verify_claim(claim: str, runtime: ToolRuntime[Context]) -> str:
    """Verify a factual claim."""
    strict_mode = runtime.context.fact_checker_strict_mode or False
    if strict_mode:
        return strict_verification(claim)
    return basic_verification(claim)
```



### 4.6.2 标识哪个 subagent 调用工具

同一个工具被 main agent 或 多个 subagent 调用时，可使用 `lc_agent_name`  元数据来确定谁发起的调用

```python
from langchain.tools import tool, ToolRuntime

@tool
def shared_lookup(query: str, runtime: ToolRuntime) -> str:
    """Look up information."""
    agent_name = runtime.config.get("metadata", {}).get("lc_agent_name")
    if agent_name == "fact-checker":
        return strict_lookup(query)
    return general_lookup(query)
```



结合两种模式：从 `runtime.context` 中读取特定 agent 的设置，并从 `runtime.config` 中读取 `lc_agent_name`

```python
from langchain.tools import tool, ToolRuntime

@tool
def flexible_search(query: str, runtime: ToolRuntime[Context]) -> str:
    """Search with agent-specific settings."""
    agent_name = runtime.config.get("metadata", {}).get("lc_agent_name", "unknown")
    ctx = runtime.context
    if agent_name == "researcher":
        max_results = ctx.researcher_max_depth or 5
    else:
        max_results = 5
    include_raw = False

    return perform_search(query, max_results=max_results, include_raw=include_raw)
```



## 4.7 异步 subagent

| Dimension            | Sync subagents                                               | Async subagents                                              |
| :------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| **Execution model**  | Supervisor blocks until subagent completes                   | Returns job ID immediately; supervisor continues             |
| **Concurrency**      | Parallel but blocking                                        | Parallel and non-blocking                                    |
| **Mid-task updates** | Not possible                                                 | Send follow-up instructions via `update_async_task`          |
| **Cancellation**     | Not possible                                                 | Cancel running tasks via `cancel_async_task`                 |
| **Statefulness**     | Stateless — no persistent state between invocations          | Stateful — maintains state on its own thread across interactions |
| **Best for**         | Tasks where the agent should wait for results before continuing | Long-running, complex tasks managed interactively in a chat  |



### 4.7.1 AsyncSubAgent

```python
from deepagents import AsyncSubAgent, create_deep_agent

async_subagents = [
    AsyncSubAgent(
        name="researcher",
        description="Research agent for information gathering and synthesis",
        graph_id="researcher",
        # No url → ASGI transport (co-deployed in the same deployment)
    ),
    AsyncSubAgent(
        name="coder",
        description="Coding agent for code generation and review",
        graph_id="coder",
        # url="https://coder-deployment.langsmith.dev"  # Optional: HTTP transport for remote
    ),
]

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    subagents=async_subagents,
)
```



参数：

| Field         | Type             | Description                                                  |
| :------------ | :--------------- | :----------------------------------------------------------- |
| `name`        | `str`            | Required. Unique identifier. The supervisor uses this when launching tasks. |
| `description` | `str`            | Required. What this subagent does. The supervisor uses this to decide which agent to delegate to. |
| `graph_id`    | `str`            | Required. The graph ID (or assistant ID) on the Agent Protocol server. For LangGraph-based deployments, this must match a graph registered in `langgraph.json`. |
| `url`         | `str`            | Optional. When omitted, uses ASGI transport (in-process). When set, uses HTTP transport to a remote Agent Protocol server. |
| `headers`     | `dict[str, str]` | Optional. Additional headers for requests to the remote server. Use for custom authentication with self-hosted Agent Protocol servers. |



### 4.7.2 AsyncSubAgentMiddleware

| Tool                | Purpose                                   | Returns                       |
| :------------------ | :---------------------------------------- | :---------------------------- |
| `start_async_task`  | Start a new background task               | Task ID (immediately)         |
| `check_async_task`  | Get current status and result of a task   | Status + result (if complete) |
| `update_async_task` | Send new instructions to a running task   | Confirmation + updated status |
| `cancel_async_task` | Stop a running task                       | Confirmation                  |
| `list_async_tasks`  | List all tracked tasks with live statuses | Summary of all tasks          |



# 5. Human-in-the-Loop

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-hitl.svg)



## 5.1 基础配置

`interruor_on` 参数接收一个字典，key 为工具名称，value取值如下：

- True：启用中断，并采用默认行为 (允许执行 approval, edit, reject, respond 操作)
- False：禁用中断
- `{"allowed_decisions": [...]`}：自定义配置，指定允许执行的特定决策

```python
from langchain.tools import tool
from deepagents import create_deep_agent
from langgraph.checkpoint.memory import MemorySaver

@tool
def delete_file(path: str) -> str:
    """Delete a file from the filesystem."""
    return f"Deleted {path}"

@tool
def read_file(path: str) -> str:
    """Read a file from the filesystem."""
    return f"Contents of {path}"

@tool
def send_email(to: str, subject: str, body: str) -> str:
    """Send an email."""
    return f"Sent email to {to}"

# Checkpointer is REQUIRED for human-in-the-loop
checkpointer = MemorySaver()

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    tools=[delete_file, read_file, send_email],
    interrupt_on={
        "delete_file": True,  # Default: approve, edit, reject, respond
        "read_file": False,   # No interrupts needed
        "send_email": {"allowed_decisions": ["approve", "reject"]},  # No editing
    },
    checkpointer=checkpointer  # Required!
)
```



## 5.2 决策类型

`allowed_decisions` 控制人工审核工具调用时可执行的操作：

- **`approve`**：按 agent 提议的原始参数执行该工具

- **`edit`**：执行前修改工具参数

- **`reject`**：完全跳过该工具调用的执行
- **`respond`**：直接将人工输入的消息作为工具结果返回，跳过执行。适用于“向用户提问”类型的工具

```python
interrupt_on = {
    # Sensitive operations: allow all options
    "delete_file": {"allowed_decisions": ["approve", "edit", "reject"]},

    # Moderate risk: approval or rejection only
    "write_file": {"allowed_decisions": ["approve", "reject"]},

    # Must approve (no rejection allowed)
    "critical_operation": {"allowed_decisions": ["approve"]},
}
```



## 5.3 处理中断

当中断触发，agent 会暂停执行并交还控制权。检查结果中是否存在中断，并据此进行相应的处理

```python
from langchain_core.utils.uuid import uuid7
from langgraph.types import Command

# Create config with thread_id for state persistence
config = {"configurable": {"thread_id": str(uuid7())}}

# Invoke the agent
result = agent.invoke(
    {"messages": [{"role": "user", "content": "Delete the file temp.txt"}]},
    config=config,
    version="v2",
)

# Check if execution was interrupted
if result.interrupts:
    # Extract interrupt information
    interrupt_value = result.interrupts[0].value  
    action_requests = interrupt_value["action_requests"]
    review_configs = interrupt_value["review_configs"]

    # Create a lookup map from tool name to review config
    config_map = {cfg["action_name"]: cfg for cfg in review_configs}

    # Display the pending actions to the user
    for action in action_requests:
        review_config = config_map[action["name"]]
        print(f"Tool: {action['name']}")
        print(f"Arguments: {action['args']}")
        print(f"Allowed decisions: {review_config['allowed_decisions']}")

    # Get user decisions (one per action_request, in order)
    decisions = [
        {"type": "approve"}  # User approved the deletion
    ]

    # Resume execution with decisions
    result = agent.invoke(
        Command(resume={"decisions": decisions}),
        config=config,  # Must use the same config!
        version="v2",
    )

# Process final result
print(result.value["messages"][-1].content)
```



## 5.4 多工具调用

当 agent 调用多个需要审批的工具时，所有的中断请求将被批量合并为一个单一的中断。必须按顺序对其中的每一项做出决策

```python
config = {"configurable": {"thread_id": str(uuid7())}}

result = agent.invoke(
    {"messages": [{
        "role": "user",
        "content": "Delete temp.txt and send an email to admin@example.com"
    }]},
    config=config,
    version="v2",
)

if result.interrupts:
    interrupt_value = result.interrupts[0].value  
    action_requests = interrupt_value["action_requests"]

    # Two tools need approval
    assert len(action_requests) == 2

    # Provide decisions in the same order as action_requests
    decisions = [
        {"type": "approve"},  # First tool: delete_file
        {"type": "reject"}    # Second tool: send_email
    ]

    result = agent.invoke(
        Command(resume={"decisions": decisions}),
        config=config,
        version="v2",
    )
```



## 5.5 编辑工具参数

当 edit 在允许的决策中，可以在执行前修改工具参数

```python
if result.interrupts:
    interrupt_value = result.interrupts[0].value  
    action_request = interrupt_value["action_requests"][0]

    # Original args from the agent
    print(action_request["args"])  # {"to": "everyone@company.com", ...}

    # User decides to edit the recipient
    decisions = [{
        "type": "edit",
        "edited_action": {
            "name": action_request["name"],  # Must include the tool name
            "args": {"to": "team@company.com", "subject": "...", "body": "..."}
        }
    }]

    result = agent.invoke(
        Command(resume={"decisions": decisions}),
        config=config,
        version="v2",
    )
```



## 5.6 Subagents 中断

### 5.6.1 Interrupts on tool calls

可以为 sub agent 配置独立的 `interrupt_on`，覆盖 main agent 的配置：

```python
agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    tools=[delete_file, read_file],
    interrupt_on={
        "delete_file": True,
        "read_file": False,
    },
    subagents=[{
        "name": "file-manager",
        "description": "Manages file operations",
        "system_prompt": "You are a file management assistant.",
        "tools": [delete_file, read_file],
        "interrupt_on": {
            # Override: require approval for reads in this subagent
            "delete_file": True,
            "read_file": True,  # Different from main agent!
        }
    }],
    checkpointer=checkpointer
)
```



### 5.6.2 Interrupts with tool calls

subagent 工具可直接调用 `interrupt()` 来暂停执行，并等待批准

```python
from langchain.agents import create_agent
from langchain_anthropic import ChatAnthropic
from langchain.messages import HumanMessage
from langchain.tools import tool
from langgraph.checkpoint.memory import InMemorySaver
from langgraph.types import Command, interrupt

from deepagents.graph import create_deep_agent
from deepagents.middleware.subagents import CompiledSubAgent


@tool(description="Request human approval before proceeding with an action.")
def request_approval(action_description: str) -> str:
    """Request human approval using the interrupt() primitive."""
    # interrupt() pauses execution and returns the value passed to Command(resume=...)
    approval = interrupt({
        "type": "approval_request",
        "action": action_description,
        "message": f"Please approve or reject: {action_description}",
    })

    if approval.get("approved"):
        return f"Action '{action_description}' was APPROVED. Proceeding..."
    else:
        return f"Action '{action_description}' was REJECTED. Reason: {approval.get('reason', 'No reason provided')}"


def main():
    checkpointer = InMemorySaver()
    model = ChatAnthropic(
        model_name="claude-sonnet-4-6",
        max_tokens=4096,
    )

    compiled_subagent = create_agent(
        model=model,
        tools=[request_approval],
        name="approval-agent",
    )

    parent_agent = create_deep_agent(
        model="google_genai:gemini-3.1-pro-preview",
        checkpointer=checkpointer,
        subagents=[
            CompiledSubAgent(
                name="approval-agent",
                description="An agent that can request approvals",
                runnable=compiled_subagent,
            )
        ],
    )

    thread_id = "test_interrupt_directly"
    config = {"configurable": {"thread_id": thread_id}}

    print("Invoking agent - sub-agent will use request_approval tool...")

    result = parent_agent.invoke(
        {
            "messages": [
                HumanMessage(
                    content="Use the task tool to launch the approval-agent sub-agent. "
                    "Tell it to use the request_approval tool to request approval for 'deploying to production'."
                )
            ]
        },
        config=config,
        version="v2",
    )

    # Check for interrupt
    if result.interrupts:
        interrupt_value = result.interrupts[0].value  
        print(f"\nInterrupt received!")
        print(f"  Type: {interrupt_value.get('type')}")
        print(f"  Action: {interrupt_value.get('action')}")
        print(f"  Message: {interrupt_value.get('message')}")

        print("\nResuming with Command(resume={'approved': True})...")
        result2 = parent_agent.invoke(
            Command(resume={"approved": True}),
            config=config,
            version="v2",
        )

        if not result2.interrupts:
            print("\nExecution completed!")
            # Find the tool response
            tool_msgs = [m for m in result2.value.get("messages", []) if m.type == "tool"]
            if tool_msgs:
                print(f"  Tool result: {tool_msgs[-1].content}")
        else:
            print("\nAnother interrupt occurred")
    else:
        print("\n  No interrupt - the model may not have called request_approval")


if __name__ == "__main__":
    main()
```



## 5.7 最佳实践

### 5.7.1 Checkpointer 

Human-in-the-Loop 模型必须使用 checkpointer，以便在中断与恢复之间持久化 agent 状态

```python
from langgraph.checkpoint.memory import MemorySaver

checkpointer = MemorySaver()
agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    tools=[...],
    interrupt_on={...},
    checkpointer=checkpointer  # Required for HITL
)
```



### 5.7.2 使用相同的 thread ID

恢复时，必须使用相同的配置和相同的 `thread_id`

```python
# First call
config = {"configurable": {"thread_id": "my-thread"}}
result = agent.invoke(input, config=config, version="v2")

# Resume (use same config)
result = agent.invoke(Command(resume={...}), config=config, version="v2")
```



### 5.7.3 决策顺序与操作匹配

决策列表必须与 `action_requests` 的顺序一致

```python
if result.interrupts:
    interrupt_value = result.interrupts[0].value  
    action_requests = interrupt_value["action_requests"]

    # Create one decision per action, in order
    decisions = []
    for action in action_requests:
        decision = get_user_decision(action)  # Your logic
        decisions.append(decision)

    result = agent.invoke(
        Command(resume={"decisions": decisions}),
        config=config,
        version="v2",
    )
```



### 5.7.4 按风险定制配置

根据风险等级配置不同的工具：

```python
interrupt_on = {
    # High risk: full control (approve, edit, reject)
    "delete_file": {"allowed_decisions": ["approve", "edit", "reject"]},
    "send_email": {"allowed_decisions": ["approve", "edit", "reject"]},

    # Medium risk: no editing allowed
    "write_file": {"allowed_decisions": ["approve", "reject"]},

    # Low risk: no interrupts
    "read_file": False,
    "list_files": False,
}
```



# 6. Permissions

利用声明式权限规则，可精确控制 agent 能够读取或写入哪些文件和目录

权限规则仅适用于内置的文件系统工具：`ls`、`read_file`、`glob`、`grep`、`write_file` 和 `edit_file`

自定义的工具、MCP工具、Sandbox后端 均不受此权限规则的约束



## 6.1 基本用法

向 `create_deep_agent` 传入一个 `FilesystemPermission` 规则列表。规则将按声明顺序进行评估。首条匹配规则将生效。如果没有任何规则匹配，则允许执行该操作。

```python
from deepagents import FilesystemPermission, create_deep_agent

# Read-only agent: deny all writes
agent = create_deep_agent(
    model=model,
    backend=backend,
    permissions=[
        FilesystemPermission(
            operations=["write"],
            paths=["/**"],
            mode="deny",
        ),
    ],
)
```



## 6.2 规则结构
每个 FilesystemPermission 包含三个字段：

| Field        | Type                     | Description                                                  |
| :----------- | :----------------------- | :----------------------------------------------------------- |
| `operations` | `list["read" | "write"]` | Operations this rule applies to. `"read"` covers `ls`, `read_file`, `glob`, `grep`. `"write"` covers `write_file`, `edit_file`. |
| `paths`      | `list[str]`              | Glob patterns for matching file paths (e.g., `["/workspace/**"]`). Supports `**` for recursive matching and `{a,b}` for alternation. |
| `mode`       | `"allow" | "deny"`       | Whether to allow or deny matching operations. Defaults to `"allow"`. |



## 6.3 示例

### 6.3.1 隔离至工作区目录

仅允许对 `/workspace/` 目录进行读写操作，拒绝其它一切访问：

```python
agent = create_deep_agent(
    model=model,
    backend=backend,
    permissions=[
        FilesystemPermission(
            operations=["read", "write"],
            paths=["/workspace/**"],
            mode="allow",
        ),
        FilesystemPermission(
            operations=["read", "write"],
            paths=["/**"],
            mode="deny",
        ),
    ],
)
```



### 6.3.2 保护特定文件

```python
agent = create_deep_agent(
    model=model,
    backend=backend,
    permissions=[
        FilesystemPermission(
            operations=["read", "write"],
            paths=["/workspace/.env", "/workspace/examples/**"],
            mode="deny",
        ),
        FilesystemPermission(
            operations=["read", "write"],
            paths=["/workspace/**"],
            mode="allow",
        ),
        FilesystemPermission(
            operations=["read", "write"],
            paths=["/**"],
            mode="deny",
        ),
    ],
)
```



### 6.3.3 只读记忆

允许 agent 读取 memory 文件，但禁止器进行修改。

```python
from deepagents.backends import CompositeBackend, StateBackend, StoreBackend

agent = create_deep_agent(
    model=model,
    backend=CompositeBackend(
        default=StateBackend(),
        routes={
            "/memories/": StoreBackend(
                namespace=lambda rt: (rt.server_info.user.identity,),
            ),
            "/policies/": StoreBackend(
                namespace=lambda rt: (rt.context.org_id,),
            ),
        },
    ),
    permissions=[
        FilesystemPermission(
            operations=["write"],
            paths=["/memories/**", "/policies/**"],
            mode="deny",
        ),
    ],
)
```



### 6.3.4 拒绝所有访问

```python
agent = create_deep_agent(
    model=model,
    backend=backend,
    permissions=[
        FilesystemPermission(
            operations=["read", "write"],
            paths=["/**"],
            mode="deny",
        ),
    ],
)
```



### 6.3.5 规则排序

由于采用“首个匹配获胜”的原则，规则的排列顺序至关重要。请将更具体的规则置于更宽泛的规则之前：

```python
# Correct: deny .env, allow workspace, deny everything else
correct_permissions = [
    FilesystemPermission(
        operations=["read", "write"],
        paths=["/workspace/.env"],
        mode="deny",
    ),
    FilesystemPermission(
        operations=["read", "write"],
        paths=["/workspace/**"],
        mode="allow",
    ),
    FilesystemPermission(
        operations=["read", "write"],
        paths=["/**"],
        mode="deny",
    ),
]

# Bug: /workspace/** matches .env first, so the deny never triggers
incorrect_permissions = [
    FilesystemPermission(
        operations=["read", "write"],
        paths=["/workspace/**"],
        mode="allow",
    ),
    FilesystemPermission(
        operations=["read", "write"],
        paths=["/workspace/.env"],
        mode="deny",  # never reached
    ),
    FilesystemPermission(
        operations=["read", "write"],
        paths=["/**"],
        mode="deny",
    ),
]
```



## 6.4 Subagent 权限

subagent 默认继承 main agent 的权限，可通过为 subagent 指定 permission 来覆盖默认权限

```python
agent = create_deep_agent(
    model=model,
    backend=backend,
    permissions=[
        FilesystemPermission(
            operations=["read", "write"],
            paths=["/workspace/**"],
            mode="allow",
        ),
        FilesystemPermission(
            operations=["read", "write"],
            paths=["/**"],
            mode="deny",
        ),
    ],
    subagents=[
        {
            "name": "auditor",
            "description": "Read-only code reviewer",
            "system_prompt": "Review the code for issues.",
            "permissions": [
                FilesystemPermission(
                    operations=["write"],
                    paths=["/**"],
                    mode="deny",
                ),
                FilesystemPermission(
                    operations=["read"],
                    paths=["/workspace/**"],
                    mode="allow",
                ),
                FilesystemPermission(
                    operations=["read"],
                    paths=["/**"],
                    mode="deny",
                ),
            ],
        }
    ],
)
```



## 6.5 组合后端

当使用带有沙箱默认设置的 CompositeBackend 时，每一个权限路径都必须限定在已知的路由前缀之下。由于沙箱支持执行任意命令，仅凭基于路径的限制无法阻止通过 Shell 命令对文件系统进行访问。将权限限定在特定路由对应的后端上，即可避免这一冲突。

```python
from deepagents.backends import CompositeBackend


composite = CompositeBackend(
    default=sandbox,
    routes={"/memories/": memories_backend},
)

# Works: permissions are scoped to the /memories/ route
agent = create_deep_agent(
    model=model,
    backend=composite,
    permissions=[
        FilesystemPermission(
            operations=["write"],
            paths=["/memories/**"],   # 必须指定路径
            mode="deny",
        ),
    ],
)
```



包含位于任何路由之外的路径的权限，将引发 `NotImplementedError`

```python
# Raises NotImplementedError: /workspace/** hits the sandbox default
try:
    create_deep_agent(
        model=model,
        backend=composite,
        permissions=[
            FilesystemPermission(
                operations=["write"],
                paths=["/workspace/**"],
                mode="deny",
            ),
        ],
    )
except NotImplementedError:
    pass

# Also raises: /** covers both routes and the default
try:
    create_deep_agent(
        model=model,
        backend=composite,
        permissions=[
            FilesystemPermission(
                operations=["read"],
                paths=["/**"],
                mode="deny",
            ),
        ],
    )
except NotImplementedError:
    pass
```



# 7. Memory

记忆功能使 agent 能够在跨对话过程中进行学习与改进。Deep Agents 通过基于文件系统的记忆机制，将记忆提升为“一级公民”：agent 以文件的形式读写记忆，可以通过后端配置来掌控这些文件的存储位置

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-memory.png)



## 7.1 Scoped memory

agent 的记忆可以设定作用域：既可以设置为让所有使用该 agent 的用户都能访问同一份内存文件，也可以设置为让每位用户拥有各自独立的内存文件。



### 7.1.1 Agent-scoped memory

赋予 agent 一个随时间演进的、专属的持久化身份。由所有用户共享，因此 agent 能够通过每一次对话，逐步构建起属于自己的个性特征、积累的知识以及习得的偏好。在与用户互动的过程中，它不断提升专业能力，优化其交互方式，并牢记哪些策略行之有效。此外，若具备写入权限，它还能学习并更新自身技能。
其关键在于后端的命名空间（namespace）设置：若将其设定为 `(assistant_id,)`，则意味着该 agent 的所有对话都将对同一份内存文件进行读写操作。

```python
from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, StateBackend, StoreBackend

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    memory=["/memories/AGENTS.md"],
    skills=["/skills/"],
    backend=CompositeBackend(
        default=StateBackend(),
        routes={
            "/memories/": StoreBackend(
                namespace=lambda rt: (
                    rt.server_info.assistant_id,
                ),
            ),
            "/skills/": StoreBackend(
                namespace=lambda rt: (
                    rt.server_info.assistant_id,
                ),
            ),
        },
    ),
)
```



完整示例：

```python
from langchain_core.utils.uuid import uuid7

from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, StateBackend, StoreBackend
from deepagents.backends.utils import create_file_data
from langgraph.store.memory import InMemoryStore

store = InMemoryStore()  # Use platform store when deploying to LangSmith

# Seed the memory file
store.put(
    ("my-agent",),
    "/memories/AGENTS.md",
    create_file_data("""## Response style
- Keep responses concise
- Use code examples where possible
"""),
)

# Seed a skill
store.put(
    ("my-agent",),
    "/skills/langgraph-docs/SKILL.md",
    create_file_data("""---
name: langgraph-docs
description: Fetch relevant LangGraph documentation to provide accurate guidance.
---

# langgraph-docs

Use the fetch_url tool to read https://docs.langchain.com/llms.txt, then fetch relevant pages.
"""),
)

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    memory=["/memories/AGENTS.md"],
    skills=["/skills/"],
    backend=lambda rt: CompositeBackend(
        default=StateBackend(rt),
        routes={
            "/memories/": StoreBackend(
                rt, namespace=lambda rt: ("my-agent",)
            ),
            "/skills/": StoreBackend(
                rt, namespace=lambda rt: ("my-agent",)
            ),
        },
    ),
    store=store,
)

# Thread 1: the agent learns a new preference and saves it to memory
config1 = {"configurable": {"thread_id": str(uuid7())}}
agent.invoke(
    {"messages": [{"role": "user", "content": "I prefer detailed explanations. Remember that."}]},
    config=config1,
)

# Thread 2: the agent reads memory and applies the preference
config2 = {"configurable": {"thread_id": str(uuid7())}}
agent.invoke(
    {"messages": [{"role": "user", "content": "Explain how transformers work."}]},
    config=config2,
)
```



### 7.1.2 User-scoped memory

为每位用户分配独立的 memory 文件。agent 会对每位用户单独记忆其偏好设置、对话上下文及历史记录，而核心指令则保持固定不变。若存储与用户级后端，用户还可拥有专属的个性化技能。

该命名框架采用 `(user_id,)` 格式，确保每位用户都能获得一份相互隔离的 memory 文件副本。

```python
from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, StateBackend, StoreBackend

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    memory=["/memories/preferences.md"],
    skills=["/skills/"],
    backend=CompositeBackend(
        default=StateBackend(),
        routes={
            "/memories/": StoreBackend(
                namespace=lambda rt: (rt.server_info.user.identity,),
            ),
            "/skills/": StoreBackend(
                namespace=lambda rt: (rt.server_info.user.identity,),
            ),
        },
    ),
)
```

完整示例：

```python
from langchain_core.utils.uuid import uuid7

from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, StateBackend, StoreBackend
from deepagents.backends.utils import create_file_data
from langgraph.store.memory import InMemoryStore


store = InMemoryStore()  # Use platform store when deploying to LangSmith

# Seed preferences for two users
store.put(
    ("user-alice",),
    "/memories/preferences.md",
    create_file_data("""## Preferences
- Likes concise bullet points
- Prefers Python examples
"""),
)
store.put(
    ("user-bob",),
    "/memories/preferences.md",
    create_file_data("""## Preferences
- Likes detailed explanations
- Prefers TypeScript examples
"""),
)

# Seed a skill for Alice
store.put(
    ("user-alice",),
    "/skills/langgraph-docs/SKILL.md",
    create_file_data("""---
name: langgraph-docs
description: Fetch relevant LangGraph documentation to provide accurate guidance.
---

# langgraph-docs

Use the fetch_url tool to read https://docs.langchain.com/llms.txt, then fetch relevant pages.
"""),
)

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    memory=["/memories/preferences.md"],
    skills=["/skills/"],
    backend=lambda rt: CompositeBackend(
        default=StateBackend(rt),
        routes={
            "/memories/": StoreBackend(
                rt,
                namespace=lambda rt: (rt.server_info.user.identity,),
            ),
            "/skills/": StoreBackend(
                rt,
                namespace=lambda rt: (rt.server_info.user.identity,),
            ),
        },
    ),
    store=store,
)

# When deployed, each authenticated request resolves
# `rt.server_info.user.identity` to the calling user, so Alice and Bob
# automatically see only their own preferences.
agent.invoke(
    {"messages": [{"role": "user", "content": "How do I read a CSV file?"}]},
    config={"configurable": {"thread_id": str(uuid7())}},
)
```



## 7.2 高级用法

| Dimension             | Question it answers             | Options                                                      |
| :-------------------- | :------------------------------ | :----------------------------------------------------------- |
| **Duration**          | How long does it last?          | Short-term or long-term                                      |
| **Information type**  | What kind of information is it? | Episodic (past experiences), procedural (instructions and skills), or semantic (facts) |
| **Scope**             | Who can see and modify it?      | User, agent, or organization                                 |
| **Update strategy**   | When are memories written?      | During conversation (default) or between conversations       |
| **Retrieval**         | How are memories read?          | Loaded into prompt (default) or on demand (e.g., skills)     |
| **Agent permissions** | Can the agent write to memory?  | Read-write (default) or read-only (for shared policies)      |



### 7.2.1  Episodic memory

情景记忆存储着过往经历的记录：包括发生了什么、发生的顺序以及最终的结果。与语义记忆（存储在诸如 AGENTS.md 文件中的事实与偏好）不同，情景记忆保留了完整的对话上下文，从而使 agent 能够回溯问题的解决过程，而不仅仅是记住从中习得的知识。
Deep Agents 采用 Checkpoints 机制为情景记忆提供了底层支持：每一段对话都会被持久化保存为一个带有检查点的线程。

为了使过往对话具备可搜索性，需要将“线程搜索”功能封装为一个工具（Tool）。其中，`user_id` 参数将直接从运行时上下文中提取，而非作为显式参数进行传递：

```python
from langgraph_sdk import get_client
from langchain.tools import tool, ToolRuntime

client = get_client(url="<DEPLOYMENT_URL>")


@tool
async def search_past_conversations(query: str, runtime: ToolRuntime) -> str:
    """Search past conversations for relevant context."""
    user_id = runtime.server_info.user.identity  
    threads = await client.threads.search(
        metadata={"user_id": user_id},
        limit=5,
    )
    results = []
    for thread in threads:
        history = await client.threads.get_history(thread_id=thread["thread_id"])
        results.append(history)
    return str(results)
```



通过调整元数据过滤器，按用户或组织限定话题搜索范围:

```python
# Search conversations for a specific user
threads = await client.threads.search(
    metadata={"user_id": user_id},
    limit=5,
)

# Search conversations across an organization
threads = await client.threads.search(
    metadata={"org_id": org_id},
    limit=5,
)
```



### 7.2.2 Organization-level memory

组织级记忆遵循与用户级记忆相同的模式，但使用的是组织范围内的命名空间，而非针对单个用户的命名空间。建议将其用于存储那些应适用于组织内所有用户及代理的策略或知识。

组织级记忆通常设置为只读模式，旨在防止通过共享状态实施“提示注入”（Prompt Injection）攻击。

```python
from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, StateBackend, StoreBackend

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    memory=[
        "/memories/preferences.md",
        "/policies/compliance.md",
    ],
    backend=CompositeBackend(
        default=StateBackend(),
        routes={
            "/memories/": StoreBackend(
                namespace=lambda rt: (rt.server_info.user.identity,),
            ),
            "/policies/": StoreBackend(
                namespace=lambda rt: (rt.context.org_id,),
            ),
        },
    ),
)
```

在应用代码中植入组织记忆：

```python
from langgraph_sdk import get_client
from deepagents.backends.utils import create_file_data

client = get_client(url="<DEPLOYMENT_URL>")

await client.store.put_item(
    (org_id,),
    "/compliance.md",
    create_file_data("""## Compliance policies
- Never disclose internal pricing
- Always include disclaimers on financial advice
"""),
)
```



### 7.2.3 后台整合
默认下，agent 会在对话进行期间写入记忆（即“热路径”）。另一种可选方案是，将记忆处理作为一项后台任务在对话间隙执行——这种模式有时被称为“睡眠时间计算”。此时，一个独立的 deep agent 会负责审阅近期对话，从中提取关键事实，并将其与现有记忆进行整合。

| Approach                               | Pros                                                         | Cons                                                         |
| :------------------------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| **Hot path** (during conversation)     | Memories available immediately, transparent to user          | Adds latency, agent must multitask                           |
| **Background** (between conversations) | No user-facing latency, can synthesize across multiple conversations | Memories not available until next conversation, requires a second agent |



#### 7.2.3.1  Consolidation agent

整合 agent 会读取近期的对话历史，并将关键事实整合至记忆存储中。需要在 `langgraph.json` 中，将其与 main agent 一同注册：

```python
from datetime import datetime, timedelta, timezone

from deepagents import create_deep_agent
from langchain.tools import tool, ToolRuntime
from langgraph_sdk import get_client

sdk_client = get_client(url="<DEPLOYMENT_URL>")


@tool
async def search_recent_conversations(query: str, runtime: ToolRuntime) -> str:
    """Search this user's conversations updated in the last 6 hours."""
    user_id = runtime.server_info.user.identity  

    since = datetime.now(timezone.utc) - timedelta(hours=6)
    threads = await sdk_client.threads.search(
        metadata={"user_id": user_id},
        updated_after=since.isoformat(),
        limit=20,
    )
    conversations = []
    for thread in threads:
        history = await sdk_client.threads.get_history(
            thread_id=thread["thread_id"]
        )
        conversations.append(history["values"]["messages"])
    return str(conversations)


agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    system_prompt="""Review recent conversations and update the user's memory file.
Merge new facts, remove outdated information, and keep it concise.""",
    tools=[search_recent_conversations],
)
```



`langgraph.json`

```json
{
  "dependencies": ["."],
  "graphs": {
    "agent": "./agent.py:agent",
    "consolidation_agent": "./consolidation_agent.py:agent"
  },
  "env": ".env"
}
```



#### 7.2.3.2 Cron

Cron 作业会按固定计划运行整合 agent。该 agent 负责检索近期对话，并将其整合至记忆中。支持根据使用模式调整计划安排，以确保整合任务的运行节奏大致与实际活动保持同步。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-memory-cron.svg)

```python
from langgraph_sdk import get_client

client = get_client(url="<DEPLOYMENT_URL>")

cron_job = await client.crons.create(
    assistant_id="consolidation_agent",
    schedule="0 */6 * * *",
    input={"messages": [{"role": "user", "content": "Consolidate recent memories."}]},
)
```



### 7.2.4 只读记忆和读写记忆

| Permission               | Use case                                                     | How it works                                                 |
| :----------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| **Read-write** (default) | User preferences, agent self-improvement, learned skills     | Agent updates files via `edit_file` tool                     |
| **Read-only**            | Organization policies, compliance rules, shared knowledge bases, developer-defined skills | Populate via application code or the Store API. Use permissions to deny writes to specific paths, or policy hooks for custom validation logic. |



# 8. Skills

## 8.1 Agent Skills

Agent Skills 就像一份“**带目录的说明书**”，更专业地说，它是一种**渐进式披露的提示词管理机制**。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/agent-skills-layers.png)



**Skills 与 MCP 是两个目标不同、互为补充的规范**：

- Skills：带目录的说明书

  核心在于**提示词的管理与组织**，通过“渐进式披露”机制，以轻量、结构化方式扩展模型能力。

- MCP：标准化工具箱

  核心在于**工具与服务的标准化接入**，旨在为模型提供统一、安全的外部工具调用能力。



agent skills 目录结构：

```
my-skill/                        # 技能根目录
├── SKILL.md                     # ⭐ 核心文件（必须）：Claude 读取的指令文档
├── LICENSE.txt                  # 许可证（必须）
│
├── agents/                      # 可选：子 Agent 的 prompt 文件
│   ├── analyzer.md
│   ├── comparator.md
│   └── grader.md
│
├── assets/                      # 可选：静态资源（HTML模板、图片等）
│   └── eval_review.html
│
├── references/                  # 可选：参考文档、schema 定义
│   └── schemas.md
│
├── scripts/                     # 可选：Python 工具脚本
│   ├── __init__.py
│   ├── run_eval.py
│   ├── generate_report.py
│   └── utils.py
│
└── canvas-fonts/                # 可选：其他静态资源（字体、数据等）
    ├── Lora-Regular.ttf
    └── ...
```

每个 Skill 文件夹中必选包含 `SKILL.md` 文件，示例内容如下：

```markdown
---
name: pdf-processing
description: Extract text and tables from PDF files, fill forms, merge documents.
---

# PDF Processing  

## When to use this skill
Use this skill when the user needs to work with PDF files...  

## How to extract text
1. Use pdfplumber for text extraction...  

## How to fill forms
...
```

其中，`name` 是 Skill 的名称，`description` 是它的简短描述，这两项不可为空。

`SKILL.md` 的正文部分用于定义该 Skill 的专业知识、操作流程和解决思路。此外，用户还可以在文件夹下增加 `scripts` 工具脚本、`references` 参考文档、`assets` 资源文件，以进一步丰富 Skill 的能力。

Skill 的核心设计理念是“**渐进式加载**”，即：智能体在初始化时，之后将每个 Skill 的基本信息 (`name` 和 `description`) 加载到系统提示词中。只有在后续对话中，智能体根据用户意图判断出需要用到某个具体 Skill 时，才会进一步加载该 Skill 的详细信息 (即 `SKILL.md` 的正文内容)，甚至按需加载脚本、模板等额外资源。



### 8.1.1 实现思路

Agent Skill 的工程化实现基本遵循以下四个步骤：

- **发现与识别 Skills**

  Agent 需要能够管理文件系统，在配置好的目录中发现 Skills 文件夹。系统会扫描每个子文件夹，读取其中的 `SKILL.md`，并提取文件头部的 YAML 元数据 (即 `name` 和 `description`)

  

- **系统提示词注入**

  将所有 Skill 的元数据 (名称 + 描述) 注入到系统提示词中，使得大模型在每一轮对话开始时能清楚看到有哪些技能可用，以及各自得简要用途

  

- **渐进式加载**

  当模型决定使用某个 Skill 时，系统才会进一步读取该 Skill 得完整说明 (即 `SKILL.md` 的正文)，将其加载到上下文中，使后续行动有据可依

  

- **任务执行与完成**

  模型按照 `SKILL.md` 中的详细说明，调用必须的工具来访问附加资源，并最终完成任务



### 8.1.2 实现机制

`DeepAgents` 基于 `LangChain` 1.0 的 create_agent 进行深度定制，并通过中间件机制完成了对 Skills 的工程化支持

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/langchain-middleware-mechanism.png)

按 Agent Skill 实现步骤进行解析：

1. **发现与识别 Skills**

   `DeepAgents` 通过 `FileSystemMiddleware` 获得了操作本地文件系统目录的能力。框架内置的实现代码会扫描指定的 Skills 目录，读取每个子目录内的 `SKILL.md`，解析器顶部的 YAML 区域，提取 `name`、`description` 等信息，并格式化为一个 `SkillMetadata` 列表

   

2. **系统提示词注入**

   `DeepAgents` 通过 `SkillsMiddleware` 中间件。在 `before_agent` 钩子函数中，该中间件会将 `SkillMetadata` 列表组合成一段文本，并附上使用 Skills 的指令和提升。最终形成的提示片段类似如下结构：

   ```
   ** 可用Skill:
   fullstack-template-generator: 
   ......
   web-research: 
   ......
   ** 如何使用(渐进式加载原则):
   Skills follow a progressive disclosure pattern
   ......
   ** 什么时候使用Skill:
   ......
   ** 如何执行Skill中的脚本:
   ......
   ** Skill使用流程示例
   ......
   ** Skill使用注意点
   ......
   ```

   同时该中间件还会在 `wrap_model_call` 方法中将上述 Skills 提示附加到 `system_prompt` 中，确保模型在每次调用时都能看到这些信息。

   

3. **渐进式加载**

   模型通过 `SkillMeatadata` 已经知道了如何选择和使用某个 Skill。当模型的输出与使用某个 Skill 相关时，就会触发渐进式加载流程。由于 DeepAgents 的 `FileSystemMiddleware` 已经配置了 `read_file` 等文件系统读取工具，此时系统可以读取对应 `SKILL.md` 的完整文本，从而获得该 Skill 的详细说明书。

   

4. **任务执行与完成**

   拿到完整的 Skill 说明后，智能体会在任务执行过程中，按需要加载必要的附加资源 (如 `scripts/`、`references/`、`assets/` 中的文件)，并调用相应的工具来完成任务





## 8.2 用法

### 8.2.1 StateBackend

```python
from urllib.request import urlopen
from deepagents import create_deep_agent
from deepagents.backends.utils import create_file_data
from langgraph.checkpoint.memory import MemorySaver

checkpointer = MemorySaver()

skill_url = "https://raw.githubusercontent.com/langchain-ai/deepagents/refs/heads/main/libs/cli/examples/skills/langgraph-docs/SKILL.md"
with urlopen(skill_url) as response:
    skill_content = response.read().decode('utf-8')

skills_files = {
    "/skills/langgraph-docs/SKILL.md": create_file_data(skill_content)
}

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    skills=["/skills/"],
    checkpointer=checkpointer,
)

result = agent.invoke(
    {
        "messages": [
            {
                "role": "user",
                "content": "What is langgraph?",
            }
        ],
        # Seed the default StateBackend's in-state filesystem (virtual paths must start with "/").
        "files": skills_files
    },
    config={"configurable": {"thread_id": "12345"}},
)
```



### 8.2.2 StoreBackend

```python
from urllib.request import urlopen
from deepagents import create_deep_agent
from deepagents.backends import StoreBackend
from deepagents.backends.utils import create_file_data
from langgraph.store.memory import InMemoryStore


store = InMemoryStore()

skill_url = "https://raw.githubusercontent.com/langchain-ai/deepagents/refs/heads/main/libs/cli/examples/skills/langgraph-docs/SKILL.md"
with urlopen(skill_url) as response:
    skill_content = response.read().decode('utf-8')

store.put(
    namespace=("filesystem",),
    key="/skills/langgraph-docs/SKILL.md",
    value=create_file_data(skill_content)
)

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    backend=StoreBackend(),
    store=store,
    skills=["/skills/"]
)

result = agent.invoke(
    {
        "messages": [
            {
                "role": "user",
                "content": "What is langgraph?",
            }
        ]
    },
    config={"configurable": {"thread_id": "12345"}},
)
```



### 8.2.3 FilesystemBackend

```python
from deepagents import create_deep_agent
from langgraph.checkpoint.memory import MemorySaver
from deepagents.backends.filesystem import FilesystemBackend

# Checkpointer is REQUIRED for human-in-the-loop
checkpointer = MemorySaver()

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    backend=FilesystemBackend(root_dir="/Users/user/{project}"),
    skills=["/Users/user/{project}/skills/"],
    interrupt_on={
        "write_file": True,  # Default: approve, edit, reject
        "read_file": False,  # No interrupts needed
        "edit_file": True    # Default: approve, edit, reject
    },
    checkpointer=checkpointer,  # Required!
)

result = agent.invoke(
    {
        "messages": [
            {
                "role": "user",
                "content": "What is langgraph?",
            }
        ]
    },
    config={"configurable": {"thread_id": "12345"}},
)
```



## 8.3 来源优先级
当多个 skill 来源包含同名的技能时，位于技能数组中靠后位置的来源所提供的技能将具有优先权（即“**后者优先**”原则）。这一机制允许叠加来自不同来源的技能。

```python
# If both sources contain a skill named "web-search",
# the one from "/skills/project/" wins (loaded last).
agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    skills=["/skills/user/", "/skills/project/"],
    ...
)
```



## 8.4 Subagents Skill

subagent 访问的 skills：

- **general-purpose subagent**：自动继承 main agent 的 skill
- **自定义 subagent**：不继承 main agent 的 skill，需要在创建 subagent 时添加 skills 参数

skill 状态完全隔离：main agent 的 skill 对 subagent 不可见，subagent 的 skill 对 main agent 也不可见。

```python
from deepagents import create_deep_agent

research_subagent = {
    "name": "researcher",
    "description": "Research assistant with specialized skills",
    "system_prompt": "You are a researcher.",
    "tools": [web_search],
    "skills": ["/skills/research/", "/skills/web-search/"],  # Subagent-specific skills
}

agent = create_deep_agent(
    model="google_genai:gemini-3.1-pro-preview",
    skills=["/skills/main/"],  # Main agent and GP subagent get these
    subagents=[research_subagent],  # Researcher gets only its own skills
)
```



## 8.5 在沙箱中运行 skill 脚本
除了 `SKILL.md` 文件之外，skill 还可以包含配套的脚本——例如，用于执行搜索或数据转换的 Python 文件。Agent 可以从任何后端读取这些脚本，但若要执行它们，agent 必须能够访问 Shell 环境——而只有沙箱后端才能提供这种环境。

当使用 `CompositeBackend`（复合后端）时，如果将其配置为将 skill 路由至 `StoreBackend`（存储后端）以进行持久化存储，同时将沙箱用作默认的执行后端，那么 skill 文件实际上是存放在存储后端中，而非代码实际运行所在的沙箱环境中。为了确保沙箱能够调用并使用这些脚本，必须利用自定义中间件，在 agent 启动之前将 skill 脚本上传至沙箱中：

```python
import asyncio
from pathlib import Path
from typing import Any

from daytona import Daytona
from deepagents import create_deep_agent
from deepagents.backends import CompositeBackend, StoreBackend
from deepagents.backends.utils import create_file_data
from langchain.agents.middleware import AgentMiddleware, AgentState

from langchain_daytona import DaytonaSandbox
from langgraph.runtime import Runtime
from langgraph.store.memory import InMemoryStore

# Identical skill bundles for every user: one shared store namespace.
SKILLS_SHARED_NAMESPACE = ("skills", "builtin")


class SkillSandboxSyncMiddleware(AgentMiddleware[AgentState, Any, Any]):
    """Copy shared skill files from the store into the sandbox before each agent run."""

    def __init__(self, backend: CompositeBackend) -> None:
        super().__init__()
        self.backend = backend

    async def abefore_agent(self, state: AgentState, runtime: Runtime[Any]) -> None:
        store = runtime.store

        files: list[tuple[str, bytes]] = []
        for item in await store.asearch(SKILLS_SHARED_NAMESPACE):
            key = str(item.key)
            if ".." in key or any(c in key for c in ("*", "?")):
                msg = f"Invalid key: {key}"
                raise ValueError(msg)
            normalized = key if key.startswith("/") else f"/{key}"
            # CompositeBackend routes paths and batches uploads to the right backend.
            files.append((f"/skills{normalized}", item.value["content"].encode()))

        if files:
            await self.backend.aupload_files(files)


async def seed_skill_store(store: InMemoryStore) -> None:
    """Load canonical skill files from disk into the shared store namespace (run once at deploy).
    You can retrieve skills from any source (local filesystem, remote URL, etc.).
    """
    skills_dir = Path(__file__).resolve().parent / "skills"
    for file_path in sorted(p for p in skills_dir.rglob("*") if p.is_file()):
        rel = file_path.relative_to(skills_dir).as_posix()
        key = f"/{rel}"
        await store.aput(
            SKILLS_SHARED_NAMESPACE,
            key,
            create_file_data(file_path.read_text(encoding="utf-8")),
        )


async def main() -> None:
    store = InMemoryStore()
    await seed_skill_store(store)

    daytona = Daytona()
    sandbox = daytona.create()
    sandbox_backend = DaytonaSandbox(sandbox=sandbox)

    backend = CompositeBackend(
        default=sandbox_backend,
        routes={
            "/skills/": StoreBackend(
                store=store,
                namespace=lambda _rt: SKILLS_SHARED_NAMESPACE,
            ),
        },
    )

    try:
        agent = create_deep_agent(
            model="openai:gpt-5.4",
            backend=backend,
            skills=["/skills/"],
            store=store,
            middleware=[SkillSandboxSyncMiddleware(backend)],
        )

    finally:
        sandbox.stop()


if __name__ == "__main__":
    asyncio.run(main())
```



## 8.6 Skills 和 Memory

|              | Skills                                                       | Memory                                                       |
| :----------- | :----------------------------------------------------------- | ------------------------------------------------------------ |
| **Purpose**  | On-demand capabilities discovered through **progressive disclosure** | Persistent context always loaded at startup                  |
| **Loading**  | Read only when the agent determines relevance                | Always injected into system prompt                           |
| **Format**   | `SKILL.md` in named directories                              | `AGENTS.md` files                                            |
| **Layering** | User → project (last wins)                                   | User → project (combined)                                    |
| **Use when** | Instructions are task-specific and potentially large         | Context is always relevant (project conventions, preferences) |



## 8.7 何时使用技能与工具

使用工具与技能的一些通用准则：

- 当涉及大量上下文信息时，应使用技能，以减少系统提示（System Prompt）中的 Token 数量。
- 利用技能将各项能力打包整合为更宏大的操作，并提供超越单一工具描述的额外上下文信息。
- 若 Agent 无法访问文件系统，则应使用工具。



# 9. Streaming

流式输出让 agent 在执行过程中，每一刻都能向用户汇报进度：模型正在推理、subagent 已启动、工具正在调用、Token 逐字生成……这些实时信号不仅能安抚用户的等待焦虑，更是构建大模型应用的基础能力。

`DeepAgents` 底层采用 **协调器-工作者** 架构：主 Agent 负责任务规划与委派，每个子 Agent 在自己隔离的沙箱中独立执行，彼此互不干扰。流式输出建立在这套架构之上，通过调用 `agent.stream()` 方法驱动整改工作流，框架会源源不断地向外产出结构化的**事件块 (chunk)**。

在 `version='v2'` 格式下，每个 chunk 都是一个统一的 `StreamPart` 字典，包含三个字段：`type` (事件类型), `ns` (命名空间), `data` (主要数据部分)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-stream-output.png)



## 9.1 启用 subgraph 流

```python
agent = create_deep_agent(
    model=llm,
    system_prompt="You are a helpful research assistant.",
    subagents=[
        {
            "name": "researcher",
            "description": "Researches a topic in depth",
            "system_prompt": "You are a through researcher.",
        }
    ],
)

for chunk in agent.stream(
    {"messages": [{"role": "user", "content": "研究量子计算的进展"}]},
    stream_mode="updates",
    subgraphs=True,
    version="v2",
):
    if chunk["type"] == "updates":
        if chunk["ns"]:
            print(f"[subagent: {chunk['ns']}]")
        else:
            print("[main agent]")
        print(chunk["data"])
```



## 9.2 Namespaces

`subagents=True` 被启用后，每个流式事件均包含一个命名空间，用于标识生成该事件的 agent。该命名空间由节点名称和任务ID构成的路径组成，代表了 agent 的层级结构：

| Namespace                                  | Source                                                       |
| :----------------------------------------- | :----------------------------------------------------------- |
| `()` (empty)                               | Main agent                                                   |
| `("tools:abc123",)`                        | A subagent spawned by the main agent’s `task` tool call `abc123` |
| `("tools:abc123", "model_request:def456")` | The model request node inside a subagent                     |



## 9.3 Subagent progress

```python
agent = create_deep_agent(
    model=llm,
    system_prompt=(
        "You are a project coordinator. Always delegate research tasks "
        "to your researcher subagent using the task tool. Keep your final response to one sentence."
    ),
    subagents=[
        {
            "name": "researcher",
            "description": "Researches a topic throughly",
            "system_prompt": (
                "You are a through researcher. Research the given topic "
                "and provide a concise summary in 2-3 sentences."
            ),
        }
    ],
)

for chunk in agent.stream(
    {"messages": [{"role": "user", "content": "Write a short summary about AI safety"}]},
    stream_mode="updates",
    subgraphs=True,
    version="v2",
):
    if chunk["type"] == "updates":
        # main agent updates (empty namespace)
        if not chunk["ns"]:
            for node_name, data in chunk["data"].items():
                if node_name == "tools":
                    # Subagent results returned to main agent
                    for msg in data.get("messages", []):
                        if msg.type == "tool":
                            print(f"\nSubagent complete: {msg.name}")
                            print(f"  Result: {str(msg.content)[:200]}...")
                else:
                    print(f"[main agent] step: {node_name}")
        # subagent updates (non-empty namespace)
        else:
            for node_name, data in chunk["data"].items():
                print(f"  [{chunk['ns'][0]}] step: {node_name}")
```

输出：

```
[main agent] step: PatchToolCallsMiddleware.before_agent
[main agent] step: model
[main agent] step: TodoListMiddleware.after_model
  [tools:25e3f597-a470-9fdb-0dc7-78ca853c182b] step: PatchToolCallsMiddleware.before_agent
  [tools:25e3f597-a470-9fdb-0dc7-78ca853c182b] step: model
  [tools:25e3f597-a470-9fdb-0dc7-78ca853c182b] step: TodoListMiddleware.after_model

Subagent complete: task
  Result: AI safety focuses on ensuring artificial intelligence systems operate reliably, align with human values, and avoid unintended harm as their capabilities advance, serving as the backbone of responsible...
[main agent] step: model
[main agent] step: TodoListMiddleware.after_model
```



## 9.4 LLM Tokens

 使用 `stream_mode="messages"` 模式，可从 main agent 和 subagents 流式传输单个 Token。每个消息事件均包含元数据，用于标识其来源 agent。

```python
current_source = ""

for chunk in agent.stream(
    {"messages": [{"role": "user", "content": "Research quantum computing advances"}]},
    stream_mode="messages",
    subgraphs=True,
    version="v2",
):
    if chunk["type"] == "messages":
        token, metadata = chunk["data"]

        # Check if this event came from a subagent (namespace contains "tools:")
        is_subagent = any(s.startswith("tools:") for s in chunk["ns"])

        if is_subagent:
            # Token from a subagent
            subagent_ns = next(s for s in chunk["ns"] if s.startswith("tools:"))
            if subagent_ns != current_source:
                print(f"\n\n--- [subagent: {subagent_ns}] ---")
                current_source = subagent_ns
            if token.content:
                print(token.content, end="", flush=True)
        else:
            # Token from the main agent
            if "main" != current_source:
                print("\n\n--- [main agent] ---")
                current_source = "main"
            if token.content:
                print(token.content, end="", flush=True)
```



## 9.5 Tool calls

当 subagent 使用工具时，可流式传输工具调用事件，实时展示每个 subagent 正在执行的操作

```python
for chunk in agent.stream(
    {"messages": [{"role": "user", "content": "Research recent quantum computing advances"}]},
    stream_mode="messages",
    subgraphs=True,
    version="v2",
):
    if chunk["type"] == "messages":
        token, metadata = chunk["data"]

        # Identify source: "main" or the subagent namespace segment
        is_subagent = any(s.startswith("tools:") for s in chunk["ns"])
        source = next((s for s in chunk["ns"] if s.startswith("tools:")), "main") if is_subagent else "main"

        tool_call_chunks = getattr(token, "tool_call_chunks", None) or []

        # Tool call chunks (streaming tool invocations)
        if tool_call_chunks:
            for tc in tool_call_chunks:
                if tc.get("name"):
                    print(f"\n[{source}] Tool call: {tc['name']}")
                # Args stream in chunks - write them incrementally
                if tc.get("args"):
                    print(tc["args"], end="", flush=True)

        # Tool results
        if token.type == "tool":
            print(f"\n[{source}] Tool result [{token.name}]: {str(token.content)[:150]}")

        # Regular AI content (skip tool call messages)
        if token.type == "ai" and token.content and not tool_call_chunks:
            print(token.content, end="", flush=True)
```



## 9.6 Custom updates

在工具中使用 `get_stream_writer` 来发送自定义进度事件

```python
import os
import time

from deepagents import create_deep_agent
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.config import get_stream_writer


@tool
def analyze_data(topic: str) -> str:
    """
    Run a data analysis on a given topic.

    This tool performs the actual analysis and emits progress updates.
    You MUST call this ctool for any analysis request.
    """
    writer = get_stream_writer()

    writer({"status": "starting", "topic": topic, "progress": 0})
    time.sleep(0.5)

    writer({"status": "analyzing", "progress": 50})
    time.sleep(0.5)

    writer({"status": "complete", "progress": 100})
    return (
        f"Analysis of \"{topic}\": Customer sentiment is 85% positive, "
        "driven by product quality and support response times."
    )

llm = ChatOpenAI(
    api_key=os.getenv("ARK_API_KEY"),
    base_url=os.getenv("ARK_BASE_URL"),
    model="doubao-seed-2-0-pro-260215",
    # model="glm-4-7-251222",
    temperature=0,
)

agent = create_deep_agent(
    model=llm,
    system_prompt=(
        "You are a coordinator. For any analysis request, you MUST delegate "
        "to the analyst subagent using the task tool. Never try to answer directly. "
        "After receiving the result, summarize it in one sentence."
    ),
    subagents=[
        {
            "name": "analyst",
            "description": "Performs data analysis with real-time progress tracking",
            "system_prompt": (
                "You are a data analyst. You MUST call the analyze_data tool "
                "for every analysis request. Do not use any other tools. "
                "After the analysis completes, report the result."
            ),
            "tools": [analyze_data],
        }
    ],
)

for chunk in agent.stream(
    {"messages": [{"role": "user", "content": "Analyze customer satisfaction trends"}]},
    stream_mode="custom",
    subgraphs=True,
    version="v2",
):
    if chunk["type"] == "custom":
        is_subagent = any(s.startswith("tools:") for s in chunk["ns"])
        if is_subagent:
            subagent_ns = next(s for s in chunk["ns"] if s.startswith("tools:"))
            print(f"[{subagent_ns}]", chunk["data"])
        else:
            print("[main]", chunk["data"])
```

输出：

```
[tools:8bca0b82-d50a-e4ff-75c1-3a0770e2473b] {'status': 'starting', 'topic': 'Customer satisfaction trends analysis including patterns in satisfaction scores over time, key drivers of changes in satisfaction, notable segments with differing satisfaction trends, and actionable insights from the data', 'progress': 0}
[tools:8bca0b82-d50a-e4ff-75c1-3a0770e2473b] {'status': 'analyzing', 'progress': 50}
[tools:8bca0b82-d50a-e4ff-75c1-3a0770e2473b] {'status': 'complete', 'progress': 100}
```



## 9.7  Stream multiple modes

```python
# Skip internal middleware steps - only show meaningful node names
INTERESTING_NODES = {"model_request", "tools"}

last_source = ""
mid_line = False  # True when we've written tokens without a trailing newline

for chunk in agent.stream(
    {"messages": [{"role": "user", "content": "Analyze the impact of remote work on team productivity"}]},
    stream_mode=["updates", "messages", "custom"],
    subgraphs=True,
    version="v2",
):
    is_subagent = any(s.startswith("tools:") for s in chunk["ns"])
    source = "subagent" if is_subagent else "main"

    if chunk["type"] == "updates":
        for node_name in chunk["data"]:
            if node_name not in INTERESTING_NODES:
                continue
            if mid_line:
                print()
                mid_line = False
            print(f"[{source}] step: {node_name}")

    elif chunk["type"] == "messages":
        token, metadata = chunk["data"]
        if token.content:
            # Print a header when the source changes
            if source != last_source:
                if mid_line:
                    print()
                    mid_line = False
                print(f"\n[{source}] ", end="")
                last_source = source
            print(token.content, end="", flush=True)
            mid_line = True

    elif chunk["type"] == "custom":
        if mid_line:
            print()
            mid_line = False
        print(f"[{source}] custom event:", chunk["data"])

print()
```



## 9.8 Track subagent lifecycle

```python
active_subagents = {}

for chunk in agent.stream(
    {"messages": [{"role": "user", "content": "Research the latest AI safety developments"}]},
    stream_mode="updates",
    subgraphs=True,
    version="v2",
):
    if chunk["type"] == "updates":
        for node_name, data in chunk["data"].items():
            # --- Phase 1: Detect subagent starting -------------------
            if not chunk["ns"] and node_name == "model_request":
                for msg in data.get("messages", []):
                    for tc in getattr(msg, "tool_calls", []):
                        if tc["name"] == "task":
                            active_subagents[tc["id"]] = {
                                "type": tc["args"].get("subagent_type"),
                                "description": tc["args"].get("description", "")[:80],
                                "status": "pending",
                            }
                            print(
                                f'[lifecycle] PENDING → subagent "{tc["args"].get("subagent_type")}" '
                                f'({tc["id"]})'
                            )

            # --- Phase 2: Detect subagent running -------------------
            if chunk["ns"] and chunk["ns"][0].startswith("tools:"):
                pregel_id = chunk["ns"][0].split(":")[1]
                for sub_id, sub in active_subagents.items():
                    if sub["status"] == "pending":
                        sub["status"] = "running"
                        print(
                            f'[lifecycle] RUNNING → subagent "{sub["type"]}" '
                            f"(pregel: {pregel_id})"
                        )
                        break

            # --- Phase 3: Detect subagent completing -------------------
            if not chunk["ns"] and node_name == "tools":
                for msg in data.get("messages", []):
                    if msg.type == "tool":
                        sub = active_subagents.get(msg.tool_call_id)
                        if sub:
                            sub["status"] = "complete"
                            print(
                                f'[lifecycle] COMPLETE → subagent "{sub["type"]}" '
                                f"({msg.tool_call_id})"
                            )
                            print(f"  Result preview: {str(msg.content)[:120]}...")

# Print final state
print("\n--- Final subagent states ---")
for sub_id, sub in active_subagents.items():
    print(f"  {sub['type']}: {sub['status']}")
```



## 9.9 Streaming format

**v1 (legacy):**

```python
# Must handle (namespace, (mode, data)) nested tuples
for namespace, chunk in agent.stream(
    {"messages": [{"role": "user", "content": "Research quantum computing"}]},
    stream_mode=["updates", "messages", "custom"],
    subgraphs=True,
):
    mode, data = chunk[0], chunk[1]
    print(mode)       # "updates", "messages", or "custom"
    print(namespace)  # () for main agent, ("tools:<id>",) for subagent
    print(data)       # payload
```



**v2 (recommended)**:

```python
# Unified format — no nested tuple unpacking
for chunk in agent.stream(
    {"messages": [{"role": "user", "content": "Research quantum computing"}]},
    stream_mode=["updates", "messages", "custom"],
    subgraphs=True,
    version="v2",
):
    print(chunk["type"])  # "updates", "messages", or "custom"
    print(chunk["ns"])    # () for main agent, ("tools:<id>",) for subagent
    print(chunk["data"])  # payload
```



## 9.10 模式对比

| 模式       | 粒度       | 输出内容                                        | 典型用途                        |
| ---------- | ---------- | ----------------------------------------------- | ------------------------------- |
| `updates`  | 节点级别   | 每个节点完成后的状态快照                        | 追踪执行进度、子 Agent 生命周期 |
| `messages` | Token 级别 | 逐 Token 文本 + 工具调用块 + 工具结果           | 聊天式 UI、工具调用实时监控     |
| `custom`   | 自定义     | 开发者通过 `get_stream_writer()` 写入的任意数据 | 领域特定进度、阶段性通知        |
| 多模式组合 | 混合       | 以上全部事件类型，按到达顺序交织                | 生产级应用、全维度可观测性      |
