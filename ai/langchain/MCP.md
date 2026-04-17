# 1. 概述

Model Context Protocol (MCP，模型上下文协议) 是一种开源协议，它标准化了大模型语义与外部工具和数据源通信的方式，允许开发者和工具提供商只集成一次，就能与任何兼容 MCP 的系统交互。MCP 就像 USB-C 标准：不需要为每个设备使用不同的连接器，而是使用一个端口来处理多种类型的连接

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/mcp.png)



# 2. 架构

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



# 3. 工作流程

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



# 4. SDK

## 4.1 Stdio 传输

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



## 4.2 Streamable HTTP

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



## 4.3 整合 Streamable HTTP

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



# 5. LangChain 集成

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



