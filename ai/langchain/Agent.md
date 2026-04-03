# 1. 概述

通用人工智能 AGI 将是 AI 的终极形态，同样，构建 Agent 则是 AI 工程应用当下的终极形态。

LLM 本身无法采取行动，它们只输出文本。Agent 则将 LLM 作为推理引擎，由 LLM 决定要采取哪些行动及这些行动的输入是什么，最后将这些行动的结果反馈给 Agent，由 Agent 决定是否需要采取更多行动，或者是否可以完成。

Agent 核心能力和组件：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/llm-agent-system.png)

Agent = LLM + Memory + Tools + Planning + Action

- **大模型 (LLM)**：作为“大脑”，提供推理、规划和知识理解能力，是 AI Agent 的决策中枢
- **记忆 (Memory)**：像人类一样，留存学到的知识及交互习惯等，让 Agent 在处理重复工作时调用以前的经验，从而避免用户进行大量重复交互
  - **短期记忆**：存储单次对话周期的上下文信息，属于临时信息存储机制。受限于模型的上下文窗口长度
  - **长期记忆**：可以跨多个任务和时间周期，可存储并调用核心知识，非即时任务。长期记忆可以通过模型参数微调 (固化知识)、知识图谱 (结构化语义网络) 或向量数据库实现
- **工具 (Tools)**：调用外部工具 (如API、数据库) 扩展能力边界
- **规划决策 (Planning)**：通过任务分解、反思与自省框架实现复杂任务处理。例如，利用思维链 (Chain of Thought) 将目标拆解为子任务，并通过反馈优化策略
- **行动 (Action)**：实际执行决策的模块，涵盖软件接口操作 (如自定订票) 和物理交互 (机器人执行搬运）



# 2. Tool

工具封装了一个可调用函数及其输入模式。这些参数可以传递给兼容的聊天模型，从而允许模型决定是否调用工具及调用哪些参数。在这种情况下，工具调用使用模型能生成符合直到输入模式的请求



## 2.1 创建工具

一个工具通常包含工具名称、描述、参数的类型注释等



示例1：通过 `@tool` 创建工具

```python
from langchain.tools import tool

@tool
def add_number(a: int, b: int) -> int:
    """两个整数相加"""
    return a + b

if __name__ == "__main__":
    print(f"{add_number.name}")
    print(f"{add_number.description}")
    print(f"{add_number.args}")
```



示例2：通过 `@tool` 的参数修改属性

```python
class FieldInfo(BaseModel):
    a: int = Field(description="第一个参数")
    b: int = Field(description="第二个参数")

@tool(
    name_or_callable="add_two_number",
    description="计算两个整数之和",
    args_schema=FieldInfo,   # 定义参数模式
)
def add_number(a: int, b: int) -> int:
    """两个整数相加"""
    return a + b

if __name__ == "__main__":
    print(f"{add_number.name}")
    print(f"{add_number.description}")
    print(f"{add_number.args}")
```



## 2.2 绑定工具

创建模型实例，并通过 `bind_tools` 方法将工具绑定到大模型

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/llm-bind-tools.png)

- 大模型通过分析用户需求，判断是否需要调用工具
- 如果需要则在响应的 addtional_kwargs 参数中包含工具调用的详细信息
- 使用模型提供的参数执行工具



```python
import os

from langchain.chat_models import init_chat_model
from langchain.tools import tool

@tool
def query_user_info(user_id: int) -> str:
    """查询用户信息"""
    return {1001: "Jack", 1002: "Tom", "1003": "Alice"}[user_id]

# 大模型
llm = init_chat_model(
    model="qwen3-vl-flash-2025-10-15",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

# 绑定工具
tools = [query_user_info]
llm_with_tools = llm.bind_tools(tools)

if __name__ == "__main__":
    # 调用大模型
    resp = llm_with_tools.invoke(input="帮忙查下1002用户的信息")
    print(resp)

    # print(globals().keys())

    # # 手动执行工具
    for tool_call in resp.tool_calls:
        tool_name = tool_call["name"]
        tool_args = tool_call["args"]
        result = globals()[tool_name].invoke(tool_args)
        print(tool_name, tool_args, result)
```



# 3. 构建 Agent

使用 create_agent 来创建 Agent，它使用 LangGraph 构建基于图的 Agent 运行时，此 Agent 会在一个循环中反复调用模型和工具，直到某次模型输出中不再包含工具调用则结束

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/create_agent.png)



## 3.1 普通响应

使用 Tavily (搜索引擎) 作为工具：

```bash
uv add langchain-tavily
```

示例：搜索实时天气

```python
import os

from langchain.agents import create_agent
from langchain.chat_models import init_chat_model
from langchain_tavily import TavilySearch

# 大模型
llm = init_chat_model(
    # model="qwen3-vl-flash-2025-10-15",
    model="qwen3-max",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

# Tavily 搜索工具
search = TavilySearch(max_results=5)
tools = [search]

# 创建 Agent
agent = create_agent(
    model=llm,
    tools=tools,
    system_prompt="你是一个助手，需要调用工具来帮助用户"
)

if __name__ == "__main__":
    resp = agent.invoke(
        {"messages": [{"role": "user", "content": "今天南京的天气怎么样？"}]}
    )
    print(resp)
    print(resp["messages"][-1].content)
```



## 3.2 流式响应

如果 Agent 执行多个步骤，可能需要一些时间，为了显示中间进度，可以使用 stream 流式返回消息

```python
import os

from langchain.agents import create_agent
from langchain.chat_models import init_chat_model
from langchain_tavily import TavilySearch

# 大模型
llm = init_chat_model(
    model="qwen3-max",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

# Tavily 搜索工具
search = TavilySearch(max_results=5)
tools = [search]

# 创建 Agent
agent = create_agent(
    model=llm,
    tools=tools,
)

if __name__ == "__main__":
    for chunk in agent.stream(
            {
                "messages": [
                    {"role": "system", "content": "你是一个助手，需要调用工具来帮助用户"},
                    {"role": "user", "content": "今天南京的天气怎么样？"}
                ]
            }
    ):
        print(chunk, end="\n\n")
```



# 4. LangSmith

使用 LangChain 构建的许多应用程序都包含多个步骤，需要多次调用 LLM。随着这些应用程序变得越来越复杂，能够检查链或 Agent 内部的具体情况变得至关重要，最好的办法是使用 LangSmith

注册LangSmith，在Settings ➡️ API Keys 下创建 API-Key 并复制。之后在环境变量中添加以开始记录跟踪：

```
LANGSMITH_TRACING="true"
LANGSMITH_API_KEY="..."
```

配置好环境变量之后，可在LangSmith 的 Tracing Projects 中查看跟踪记录。

LangSmith 默认将跟踪记录到 default 项目，可通过 LANGSMITH_PROJECT 环境变量设置 LangSmith 跟踪记录保存到哪个项目，如果该项目不存在则会创建。



# 5. 记忆

为了给 Agent 添加短期记忆 (线程持久化)，在创建 Agent 时，需要指定一个 checkpointer，并在调用 Agent 时指定线程 IO。这个短期记忆的能力是借助 LangGraph 的状态和检查点实现的

```python
import datetime
import os

from langchain.agents import create_agent
from langchain.chat_models import init_chat_model
from langchain_tavily import TavilySearch
from langgraph.checkpoint.memory import InMemorySaver

# 大模型
llm = init_chat_model(
    model="qwen3-max",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

# Tavily 搜索工具
search = TavilySearch(max_results=5)
tools = [search]

# 创建 Agent
agent = create_agent(
    model=llm,
    tools=tools,
    checkpointer=InMemorySaver(),  # 写到内存中
)

if __name__ == "__main__":
    for chunk in agent.stream(
        input={
            "messages": [
                {"role": "system", "content": f"当时时间：{datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"},
                {"role": "user", "content": "今天南京的天气怎么样？"}
            ]
        },
        config={"configurable": {"thread_id": "1"}},
    ):
        print(chunk, end="\n\n")

    for chunk in agent.stream(
        input={
            "messages": [
                {"role": "system", "content": f"当时时间：{datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"},
                {"role": "user", "content": "杭州呢？"}
            ]
        },
        config={"configurable": {"thread_id": "1"}},
    ):
        print(chunk, end="\n\n")
```



# 6. MCP

## 6.1 简介

Model Context Protocol (MCP，模型上下文协议) 是一种开源协议，它标准化了大模型语义与外部工具和数据源通信的方式，允许开发者和工具提供商只集成一次，就能与任何兼容 MCP 的系统交互。MCP 就像 USB-C 标准：不需要为每个设备使用不同的连接器，而是使用一个端口来处理多种类型的连接

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/mcp.png)



MCP 架构：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/mcp-arch.png)



MCP 分为两个层级：

- **数据层**：实现了一个基于 JSON-RPC 2.0 的交互协议，该协议定义了消息结构和语义
  - 生命周期管理：连接初始化、能力协商、连接终止
  - 服务器功能：提供工具、资源和提示模板
  - 客户端功能：调用 LLM、获取输入、记录消息
  - 其它功能：实时更新通知、长时允许操作跟踪
- **传输层**：定义客户端和服务器之间数据交换的通信机制和通道，包括特定传输方式的连接建立、消息帧界定和授权，包含多种传输机制
  - **Stdio**：使用标准输入和输出流，与在终端输入命令并看到响应使用的机制相同，适用于本地开发
  - **Streamable HTTP**：使用 HTTP POST 和 GET请求，服务器可以选择使用 SSE 来流式传递多个服务器消息。支持流式传输和服务器到客户端通知，并支持标准 HTTP 身份验证方法，包括授权令牌、API密钥和自定义头信息
  - **SSE**：带 SSE (Server-Sent Events 服务器发送事件) 的 HTTP，MCP 早期传输机制，已逐渐被 Streamable HTTP 取代



## 6.2 工作流程

**第一步：初始化**

在初始化过程中，AI 应用程序的 MCP 客户端管理器连接到配置的服务器，并将它们的能力存储起来以供后续使用。

初始化几个重要的作用：

|功能| 解释|
| ------------ | ---- |
| **协议版本协商** | 确保客户端和服务器使用兼容的协议版本，避免因版本不一致导致的通信问题 |
| **能力发现** | 声明各自支持的功能，包括它们能处理的基本类型 (工具、资源、提示) 以及是否支持通知等特性 |
| **身份交换** | 交换客户端和服务器的身份和版本信息，以便后续的调试与兼容性管理 |



**第二步：工具发现**

AI 应用程序从所有连接的 MCP 服务器中获取可用工具，并将它们组合成一个语言模型可以访问的统一工具注册表。

连接建立之后，客户端可以通过发送tools/list 请求来发现可用的工具。

响应中的每个工具包括几个关键字段：

| 字段            | 用途                                                         |
| --------------- | ------------------------------------------------------------ |
| **name**        | 工具标识符                                                   |
| **title**       | 工具的易读显示名称                                           |
| **description** | 工具描述                                                     |
| **inputSchema** | 一个定义预期输入参数的 JSON Schema，支持类型验证并提供关于必需和可选参数的清晰文档 |



**第三步：工具执行**

当语言模型在对话中决定使用工具时，AI 应用程序会拦截工具调用，将其路由到合适的 MCP 服务器，执行该工具，并将结果作为对话流程的一部分返回给 LLM。这使 LLM 能够访问实时数据并在外部世界中执行操作。

客户端使用tools/call 方法执行一个工具。tools/call 请求遵循结构化格式，确保客户端和服务器之间的类型安全和清晰通信。请求结构包括几个重要组件：

| 字段          | 用途                                  |
| ------------- | ------------------------------------- |
| **name**      | 工具标识符                            |
| **arguments** | 包含工具的 inputSchema 定义的输入参数 |



**第四步：实时更新**

MCP 支持实时通知，使服务器能够在未经明确请求的情况下通知客户端有关变更。当 AI 应用程序收到关于工具变更的通知时，它会立即刷新其工具注册表并更新 LLM 的可用功能。这确保了正在进行的对话始终能够访问最新的一组工具，并且 LLM 可以随着新功能的可用而动态适应。



## 6.3 SDK

### 6.3.1 Stdio 传输

服务端：

```python
from fastmcp import FastMCP

# 创建 MCP 实例
mcp = FastMCP("Demo")

# 添加工具
@mcp.tool()
def add(a: int, b: int) -> int:
    return a + b

# 添加资源
@mcp.resource("greeting://default")
def get_greeting() -> str:
    return "Hello from static resource!"

# 添加提示词
@mcp.prompt()
def greet_user(name: str, style: str = "friendly") -> str:
    styles = {
        "friendly": "写一句友善的问候",
        "formal": "写一句正式的问候",
        "casual": "写一句轻松的问候",
    }

    return f"为{name}{styles.get(style, styles['friendly'])}"

if __name__ == "__main__":
    mcp.run(transport="stdio")
```



客户端：

```python
import asyncio

from mcp import StdioServerParameters, stdio_client, ClientSession

async def stdio_run():
    server_params = StdioServerParameters(
        command="python",
        args=["mcp_server.py"],
    )

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            # 初始化
            await session.initialize()

            # 获取可用工具
            tools = await session.list_tools()
            print(tools, end="\n\n")

            # 测试工具
            call_res = await session.call_tool("add", {"a": 1, "b": 2})
            print(call_res, end="\n\n")

            # 获取可用资源
            resources = await session.list_resources()
            print(resources, end="\n\n")

            # 调用资源
            read_res = await session.read_resource("greeting://default")
            print(read_res, end="\n\n")

            # 获取可用提示
            prompts = await session.list_prompts()
            print(prompts, end="\n\n")

            # 调用提示
            prompt = await session.get_prompt("greet_user", {"name": "Jack"})
            print(prompt, end="\n\n")

if __name__ == '__main__':
    asyncio.run(stdio_run())
```



### 6.3.2 Streamable HTTP

服务端：

```python
from fastmcp import FastMCP

# 创建 MCP 实例
mcp = FastMCP("Demo")

# 添加工具
@mcp.tool()
def add(a: int, b: int) -> int:
    return a + b

# 添加资源
@mcp.resource("greeting://default")
def get_greeting() -> str:
    return "Hello from static resource!"

# 添加提示词
@mcp.prompt()
def greet_user(name: str, style: str = "friendly") -> str:
    styles = {
        "friendly": "写一句友善的问候",
        "formal": "写一句正式的问候",
        "casual": "写一句轻松的问候",
    }

    return f"为{name}{styles.get(style, styles['friendly'])}"

if __name__ == "__main__":
    mcp.run(transport="streamable-http", host="localhost", port=3000)
```



客户端：

```python
import asyncio

from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client


async def streamable_http_run():
    url = "http://localhost:3000/mcp"

    async with streamable_http_client(url) as (read, write, _):
        async with ClientSession(read, write) as session:
            # 初始化
            await session.initialize()

            # 获取可用工具
            tools = await session.list_tools()
            print(tools, end="\n\n")

            # 测试工具
            call_res = await session.call_tool("add", {"a": 1, "b": 2})
            print(call_res, end="\n\n")

            # 获取可用资源
            resources = await session.list_resources()
            print(resources, end="\n\n")

            # 调用资源
            read_res = await session.read_resource("greeting://default")
            print(read_res, end="\n\n")

            # 获取可用提示
            prompts = await session.list_prompts()
            print(prompts, end="\n\n")

            # 调用提示
            prompt = await session.get_prompt("greet_user", {"name": "Jack"})
            print(prompt, end="\n\n")

if __name__ == '__main__':
    asyncio.run(streamable_http_run())
```



### 6.3.3 整合 Streamable HTTP

**ASGI（Asynchronous Server Gateway Interface）**是Python 的 异步 Web 服务器接口标准，定义了服务器与应用之间的通信协议，支持异步调用，能够处理高并发和长连接。

可以使用`streamable_http_app` 方法将 `StreamableHTTP` 服务器挂载到现有的 `ASGI` 服务器。这允许将 `StreamableHTTP` 服务器与其他 ASGI 应用程序集成。

服务器：

```python
import contextlib

import uvicorn
from fastapi import FastAPI
from mcp.server.fastmcp import FastMCP

# 创建 MCP 实例
tool_mcp = FastMCP("tool server")
resource_mcp = FastMCP("resource server")
prompt_mcp = FastMCP("prompt server")

# 添加工具
@tool_mcp.tool()
def add(a: int, b: int) -> int:
    return a + b

# 添加资源
@resource_mcp.resource("greeting://default")
def get_greeting() -> str:
    return "Hello from static resource!"

# 添加提示词
@prompt_mcp.prompt()
def greet_user(name: str, style: str = "friendly") -> str:
    styles = {
        "friendly": "写一句友善的问候",
        "formal": "写一句正式的问候",
        "casual": "写一句轻松的问候",
    }

    return f"为{name}{styles.get(style, styles['friendly'])}"

# 设置MCP的HTTP根路径
tool_mcp.settings.streamable_http_path = "/"
resource_mcp.settings.streamable_http_path = "/"
prompt_mcp.settings.streamable_http_path = "/"

# 创建一个组合生命周期来管理会话管理器
@contextlib.asynccontextmanager
async def lifespan(app: FastAPI):
    async with contextlib.AsyncExitStack() as stack:
        await stack.enter_async_context(tool_mcp.session_manager.run())
        await stack.enter_async_context(resource_mcp.session_manager.run())
        await stack.enter_async_context(prompt_mcp.session_manager.run())
        yield

app = FastAPI(lifespan=lifespan)

# 挂载MCP服务器
app.mount("/tool", tool_mcp.streamable_http_app())
app.mount("/resource", resource_mcp.streamable_http_app())
app.mount("/prompt", prompt_mcp.streamable_http_app())

if __name__ == "__main__":
    uvicorn.run(app, host="localhost", port=3000)
```

客户端：

```python
import asyncio

from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client

async def streamable_http_run():
    tool_mcp_url = "http://localhost:3000/tool"
    async with streamable_http_client(tool_mcp_url) as (read, write, _):
        async with ClientSession(read, write) as session:
            # 初始化
            await session.initialize()

            # 获取可用工具
            tools = await session.list_tools()
            print(tools, end="\n\n")

            # 测试工具
            call_res = await session.call_tool("add", {"a": 1, "b": 2})
            print(call_res, end="\n\n")

    resource_mcp_url = "http://localhost:3000/resource"
    async with streamable_http_client(resource_mcp_url) as (read, write, _):
        async with ClientSession(read, write) as session:
            # 初始化
            await session.initialize()

            # 获取可用资源
            resources = await session.list_resources()
            print(resources, end="\n\n")

            # 调用资源
            read_res = await session.read_resource("greeting://default")
            print(read_res, end="\n\n")

    prompt_mcp_url = "http://localhost:3000/prompt"
    async with streamable_http_client(prompt_mcp_url) as (read, write, _):
        async with ClientSession(read, write) as session:
            # 初始化
            await session.initialize()

            # 获取可用提示
            prompts = await session.list_prompts()
            print(prompts, end="\n\n")

            # 调用提示
            prompt = await session.get_prompt("greet_user", {"name": "Jack"})
            print(prompt, end="\n\n")

if __name__ == '__main__':
    asyncio.run(streamable_http_run())
```



## 6.4 LangChain 集成

LangChain Agent 可以通过 langchain-mcp-adapters 包使用 MCP 服务器上定义的工具。

调用工具：

- WebSearch：https://bailian.console.aliyun.com/?tab=mcp#/mcp-market/detail/WebSearch

- 12306：https://dashscope.aliyuncs.com/api/v1/mcps/china-railway/sse

```python
import asyncio
import json
import os

from langchain.agents import create_agent
from langchain.chat_models import init_chat_model
from langchain_core.tools import tool
from langchain_mcp_adapters.client import MultiServerMCPClient

# 配置MCP客户端
mcp_client = MultiServerMCPClient(
    {
        "WebSearch": {
            "transport": "streamable_http",
            "url": "https://dashscope.aliyuncs.com/api/v1/mcps/WebSearch/mcp",
            "headers": {"Authorization": f"Bearer {os.getenv('DASHSCOPE_API_KEY')}"},
        },
        "RailService": {
            "transport": "sse",
            "url": "https://dashscope.aliyuncs.com/api/v1/mcps/china-railway/sse",
            "headers": {"Authorization": f"Bearer {os.getenv('DASHSCOPE_API_KEY')}"},
        }
    }
)

# 获取工具
mcp_tools = asyncio.run(mcp_client.get_tools())
print(mcp_tools)

# 大模型
llm = init_chat_model(
    # model="qwen3-vl-flash-2025-10-15",
    model="qwen3-max",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

def wrap_mcp_tool(mcp_tool):
    name = mcp_tool.name
    description = mcp_tool.description
    args_schema = mcp_tool.args_schema

    @tool(name, description=description, args_schema=args_schema)
    async def safe_tool(**kwargs):
        try:
            res = await mcp_tool.ainvoke(kwargs)
            print(f"res: {res}")

            # ✅ 1. None
            if res is None:
                return "⚠️ empty result"

            # ✅ 2. 字符串
            if isinstance(res, str):
                return res

            # ✅ 3. MCP 标准格式
            if isinstance(res, dict):
                # content_and_artifact 常见结构
                if "content" in res:
                    content = res["content"]

                    # content 可能是 list
                    if isinstance(content, list):
                        texts = []
                        for item in content:
                            if isinstance(item, dict):
                                if item.get("type") == "text":
                                    texts.append(item.get("text", ""))
                                else:
                                    texts.append(json.dumps(item, ensure_ascii=False))
                            else:
                                texts.append(str(item))
                        return "\n".join(texts)

                    return str(content)

                # 标准 MCP
                if "result" in res:
                    return json.dumps(res["result"], ensure_ascii=False)

                # 错误
                if "error" in res:
                    return f"⚠️ MCP error: {res['error']}"

            # ✅ 4. fallback
            return json.dumps(res, ensure_ascii=False)

        except Exception as e:
            # ❗关键：不能 raise（astream 会炸）
            return f"⚠️ tool error: {str(e)}"

    return safe_tool

safe_tools = [wrap_mcp_tool(t) for t in mcp_tools]

# 创建 Agent
agent = create_agent(
    model=llm,
    tools=safe_tools,
)

# 调用 Agent
async def run():
    messages: list = [
        {"role": "system", "content": "你是一个助手，需要调用工具来帮助用户"},
        {"role": "user", "content": "今天黄山天气怎么样，要是不错的化，帮忙看看今天从南京到黄山的火车票"},
    ]

    async for event in agent.astream(
            {"messages": messages},
            stream_mode="updates",
    ):
        if "tools" in event:
            print("TOOL:", event["tools"])

        if "agent" in event:
            print("AGENT:", event["agent"])


if __name__ == "__main__":
    asyncio.run(run())
```



# 7. 多 Agent 架构

监督者模式是一种多 Agent 架构，其中主管 Agent 负责协调各专业工具 Agent。当任务需要不同类型的专业知识时，这个方法非常有效。与其构建一个管理跨领域工具选择的 Agent，不如创建由了解整体工作流程的主管协调的、专注的专家。

在 LangChain 中可以将 Agent 封装为工具，将工具绑定到主管 Agent 来实现主管多个 Agent 模式

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/supervisor-agent.png)

示例：创建两个子 Agent，分别带有搜索功能和发送邮件功能，并通过主管 Agent 调用子 Agent

```python
import asyncio
import os
import smtplib
from email.mime.text import MIMEText

from langchain.agents import create_agent
from langchain.chat_models import init_chat_model
from langchain_core.tools import tool
from langchain_mcp_adapters.client import MultiServerMCPClient

# 大模型
llm = init_chat_model(
    # model="qwen3-vl-flash-2025-10-15",
    model="qwen3-max",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

# 创建一个有搜索功能的子Agent
class SearchSubAgent:
    """带搜索功能的子Agent"""

    def __init__(self):
        self.tools = asyncio.run(
            MultiServerMCPClient(
                {
                    "WebSearch": {
                        "transport": "streamable_http",
                        "url": "https://dashscope.aliyuncs.com/api/v1/mcps/WebSearch/mcp",
                        "headers": {"Authorization": f"Bearer {os.getenv('DASHSCOPE_API_KEY')}"},
                    },
                    "RailService": {
                        "transport": "sse",
                        "url": "https://dashscope.aliyuncs.com/api/v1/mcps/china-railway/sse",
                        "headers": {"Authorization": f"Bearer {os.getenv('DASHSCOPE_API_KEY')}"},
                    }
                }
            ).get_tools()
        )

        self.agent = create_agent(model=llm, tools=self.tools)

    async def __call__(self, text: str) -> str:
        return await self.agent.ainvoke(
            {"messages": [{"role": "user", "content": text}]}
        )

# 创建一个能发邮件的子Agent
@tool
async def send_email(to: list[str], subject: str, body: str) -> str:
    """
    发送邮件，需要自动生成邮件主题
    :param to: 收件人列表
    :param subject: 邮件主题
    :param body: 邮件正文
    :return:
    """
    SMTP_HOST = "smtp.qq.com"
    SMTP_USER = os.getenv("SMTP_USER")
    SMTP_PASS = os.getenv("SMTP_PASS")

    msg = MIMEText(body, "plain", "utf-8")
    msg["From"] = SMTP_USER
    msg["Subject"] = subject

    try:
        server = smtplib.SMTP_SSL(SMTP_HOST, 465, timeout=10)
        server.set_debuglevel(1)
        server.login(SMTP_USER, SMTP_PASS)
        server.sendmail(SMTP_USER, to, msg.as_string())

        try:
            server.quit()
        except smtplib.SMTPResponseException as e:
            if e.smtp_code == -1 and e.smtp_error == b"\x00\x00\x00":
                pass # 忽略无害的关闭异常
            else:
                raise

        return "success"
    except Exception as e:
        return f"Send email error: {type(e).__name__} {e}"

class EmailSubAgent:
    """带发送邮件功能的子Agent"""

    def __init__(self):
        self.tools = [send_email]
        self.agent = create_agent(model=llm, tools=self.tools)

    async def __call__(self, text: str) -> str:
        return await self.agent.ainvoke(
            {"messages": [{"role": "user", "content": text}]}
        )

# 子Agent
search_subagent = SearchSubAgent()
email_subagent = EmailSubAgent()

# 将子Agent包装为工具
@tool
async def search(text: str) -> str:
    """
    一个具有搜索功能的子Agent，功能包括：
    - 搜索网页
    - 搜索火车票相关信息
    """
    return await search_subagent(text)

@tool
async def email(text: str) -> str:
    """
    一个具有发送邮件功能的子Agent
    """
    return await email_subagent(text)

# 创建监督 Agent
supervisor_agent = create_agent(
    model=llm,
    tools=[search, email],
    system_prompt="你是一个主管，需要调用子Agent来帮助用户"
)

async def run():
    messages: list = [
        {"role": "user", "content": "明天杭州的天气怎么样，要是不错的话，帮忙看看明天从南京到杭州的火车票。如果天气好的话，发送邮件给 xxxx@outlook.com 告诉他我明天去杭州；如果天气不好，就告诉他我明天不去杭州了"},
    ]

    async for event in supervisor_agent.astream(
            {"messages": messages},
            stream_mode="updates",
    ):
        print(event)


if __name__ == "__main__":
    asyncio.run(run())
```

