# 1. 概述

## 1.1 LangGraph 是什么

LangGraph 是一个用于构建 **有状态、多步骤** LLM 应用框架，特别适合构建：

- 代理 (Agent) 工作流
- 多代理系统
- 复杂的对话系统
- 需要人工审核的工作流



LangGraph 专门用于构建**状态机驱动的复杂 Agent 系统**。它将 Agent 工作流建模为图结构，支持：

- ✅ **循环与分支**：复杂的条件逻辑
- ✅ **状态持久化**：断点续传、人工干预
- ✅ **多 Agent 协作**：清晰的通信模式
- ✅ **流式输出**：实时响应
- ✅ **可视化调试**：LangSmith Studio 集成



## 1.2 核心组件

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/langgraph-core-concepts.png)

```
StateGraph (状态图)
├── State (状态)：所有节点共享的数据结构
├── Nodes (节点)：执行具体任务的函数，比如“调用LLM、执行工具、处理数据等”
├── Edges (边)：决定下一步执行哪个节点
│   ├── Normal Edges (普通边)
│   └── Conditional Edges (条件边)
└── Checkpointer (检查点)：可实现状态持久化等功能
```



# 2. 核心概念

**图 = 节点 + 边 + 状态**

```
┌───────────────────────────────────────────────────────────────┐
│                    LangGraph 工作流示例                         │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│   ┌─────────┐        ┌─────────┐        ┌─────────┐           │
│   │  START  │───────▶|   分析  │───────▶│   判断   │           │
│   └─────────┘        └─────────┘        └────┬────┘           │
│                                             │                 │
│                              ┌──────────────┼──────────────┐  │
│                              │              │              │  │
│                              ▼              ▼              ▼  │
│                        ┌─────────┐   ┌─────────┐   ┌─────────┐│
│                        │  工具A   │   │  工具B  │   │   直接   ││
│                        └────┬────┘   └────┬────┘   │   回复   ││
│                             │              │       └────┬────┘│
│                             │              │            │     │
│                             └──────┬───────┘            │     │
│                                    │                    │     │
│                                    ▼                    │     │
│                             ┌─────────┐                 │     │
│                             │   整合   │◀───────────────┘     │
│                             └────┬────┘                       │
│                                  │                            │
│                                  ▼                            │
│                             ┌─────────┐                       │
│                             │   END   │                       │
│                             └─────────┘                       │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```



## 2.1 State (状态)

状态是图中所有节点共享的数据结构，通常使用 TypedDict 或 Pydantic 模型定义：

```python
from typing import TypedDict, Annotated, Sequence
from langchain_core.messages import BaseMessage
import operator

class AgentState(TypedDict):
    # 消息历史，使用 Annotated 实现自动合并
    messages: Annotated[Sequence[BaseMessage], operator.add]
    # 当前执行步骤
    current_step: str
    # 是否需要人工审核
    needs_review: bool
    # 执行结果
    result: str | None
    # 错误信息
    error: str | None
```

关键点：

- `Annotated[type, operator.add]` 表示这个字段会自动追加而非覆盖

- 状态在节点间传递，每个节点可以读取和修改

- 支持持久化到数据库，实现断点续传



## 2.2 Nodes (节点)

节点是工作流中的处理单元，接收状态、返回更新后的状态(以字典形式)：

```python
rom typing import Literal

def analyze_query(state: AgentState) -> dict:
    """分析用户查询，决定下一步行动"""
    messages = state["messages"]
    last_message = messages[-1]
    
    # 这里可以调用 LLM 进行分析
    # ...
    
    return {
        "current_step": "analyze",
        "needs_review": False
    }

def execute_tool(state: AgentState) -> dict:
    """执行工具调用"""
    # 获取最后一条消息中的工具调用
    last_message = state["messages"][-1]
    
    if last_message.tool_calls:
        # 执行工具...
        result = "工具执行结果"
        return {"result": result}
    
    return {}

def should_continue(state: AgentState) -> Literal["tools", "end"]:
    """条件边：决定是否继续调用工具"""
    last_message = state["messages"][-1]
    
    if last_message.tool_calls:
        return "tools"
    return "end"
```



## 2.3 Edges (边)

边定义节点之间的连接方式，分为三种类型：

```python
from langgraph.graph import StateGraph, START, END

# 创建图
workflow = StateGraph(AgentState)

# 添加节点
workflow.add_node("analyze", analyze_query)
workflow.add_node("tools", execute_tool)

# 1. 普通边 (Normal Edge): A → B，无条件转移
workflow.add_edge(START, "analyze")

# 2. 条件边 (Conditional Edge): 根据条件选择不同路径
workflow.add_conditional_edges(
    "analyze",
    should_continue,
    {
        "tools": "tools",
        "end": END
    }
)

# 3. 循环边: 从 tools 回到 analyze，形成循环
workflow.add_edge("tools", "analyze")
```



# 3. 实战示例

## 3.1 简单对话机器人

```python
import os
from typing import TypedDict, Annotated

from langchain_core.messages import SystemMessage, HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import add_messages, StateGraph


# ==================== 定义状态 ====================
class ChatState(TypedDict):
    messages: Annotated[list, add_messages]


# ==================== 定义节点 ====================
def chatbot(state: ChatState) -> dict:
    llm = ChatOpenAI(
        model="qwen3-max",
        api_key=os.getenv("DASHSCOPE_API_KEY"),
        base_url=os.getenv("DASHSCOPE_BASE_URL"),
        temperature=0,
    )

    system_prompt = """你是一个聊天机器人。
    - 负责回答用户问题
    - 尽量专业、正确
    """
    print(state["messages"])
    messages = [SystemMessage(content=system_prompt)] + list(state["messages"])
    response = llm.invoke(messages)
    return {"messages": [response]}


# ==================== 构建图 ====================
workflow = StateGraph(ChatState)

# 添加节点
workflow.add_node("chatbot", chatbot)

# 定义边
workflow.set_entry_point("chatbot")
workflow.set_finish_point("chatbot")

# 编译
app = workflow.compile()


# ====================== 运行示例 ===================
if __name__ == "__main__":
    # 第一轮
    dialog = {
        "messages": [HumanMessage(content="你好，我是Eli, 很高兴认识你")],
    }
    result = app.invoke(dialog)
    print(result["messages"][-1].content)

    # 第二轮
    dialog = {
        "messages": [HumanMessage(content="说说你具备哪些功能")],
    }
    result = app.invoke(dialog)
    print(result["messages"][-1].content)
```



## 3.2 带工具的 Agent

```python
import os
from typing import TypedDict, Annotated, Literal

from langchain_core.messages import SystemMessage, HumanMessage, ToolMessage
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.constants import END
from langgraph.graph import add_messages, StateGraph


# ==================== 定义状态 ====================
class AgentState(TypedDict):
    messages: Annotated[list, add_messages]


# ==================== 定义工具 ====================
@tool
def get_weather(location: str) -> str:
    """获取指定地点的天气"""
    return f"{location} 天气：晴朗，温度：25°C"

@tool
def search_web(query: str) -> str:
    """搜索网络"""
    return f"搜索结果：{query}"

tools = [get_weather, search_web]


# ==================== 定义节点 ====================
def agent(state: AgentState) -> dict:
    """调用 LLM"""
    llm = ChatOpenAI(
        model="qwen3-max",
        api_key=os.getenv("DASHSCOPE_API_KEY"),
        base_url=os.getenv("DASHSCOPE_BASE_URL"),
        temperature=0,
    ).bind_tools(tools)

    response = llm.invoke(state["messages"])
    return {"messages": [response]}

def tool_node(state: AgentState) -> dict:
    """执行工具"""
    messages = state["messages"]
    last_message = messages[-1]

    tool_calls = last_message.tool_calls
    results = []

    for tool_call in tool_calls:
        # 找到对应工具
        tool_name = tool_call["name"]
        tool_to_call = {t.name: t for t in tools}[tool_name]

        # 调用工具
        result = tool_to_call.invoke(tool_call["args"])

        # 工具消息
        results.append(
            ToolMessage(
                content=str(result),
                tool_call_id=tool_call["id"],
            )
        )

    return {"messages": results}

# 路由函数
def should_continue(state: AgentState) -> Literal["tools", "end"]:
    """判断是否需要调用工具"""
    last_message = state["messages"][-1]

    if hasattr(last_message, "tool_calls") and last_message.tool_calls:
        return "tools"

    return "end"

# ==================== 构建图 =====================
workflow = StateGraph(AgentState)

# 添加节点
workflow.add_node("agent", agent)
workflow.add_node("tools", tool_node)

# 设置边
workflow.set_entry_point("agent")
workflow.add_conditional_edges(
    "agent",
    should_continue,
    {
        "tools": "tools",
        "end": END,
    }
)
workflow.add_edge("agent", "tools")

app = workflow.compile()


# ==================== 运行示例 ====================
if __name__ == "__main__":
    # config = {"configurable": {"thread_id": "conversation-123"}}
    result = app.invoke({"messages": [HumanMessage(content="杭州天气怎么样？")]})
    for msg in result["messages"]:
        print(f"{msg.__class__.__name__}: {msg.content}")
```



## 3.3 多 Agent 协作

LangGraph 原生支持多 Agent 系统，常见的协作模式包括：

```
┌─────────────────────────────────────────────────────────────┐
│                    多 Agent 协作模式                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│    【模式1: 层级式】                 【模式2: 对等式】           │
│                                                             │
│      ┌─────────┐                  ┌─────────┐               │
│      │  主控    │                  │ Agent A │◀──────┐      │
│      │ Agent   │                  └────┬────┘        │      │
│      └────┬────┘                       │             │      │
│           │                            ▼             │      │
│     ┌─────┴─────┐                 ┌─────────┐        │      │
│     │           │                 │ Agent B │────────┘      │
│     ▼           ▼                 └────┬────┘               │
│ ┌───────┐  ┌───────┐                   │                    │
│ │Worker │  │Worker │                   ▼                    │
│ │  A    │  │  B    │              ┌─────────┐               │
│ └───────┘  └───────┘              │ Agent C │               │
│                                   └─────────┘               │
│                                                             │
│     【模式3: 顺序式】                【模式4: 专家路由】         │
│                                                             │
│  ┌───┐    ┌───┐     ┌───┐         ┌─────────┐               │
│  │ A │───▶│ B │───▶│ C │         │ Router  │               │
│  └───┘    └───┘     └───┘         └────┬────┘               │
│                                        │                    │
│                        ┌───────┬───────┼───────┐            │
│                        ▼       ▼       ▼       ▼            │
│                     ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐         │
│                     │专家1 │ │专家2 ││ 专家3│ │专家4 │         │
│                     └─────┘ └─────┘ └─────┘ └─────┘         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```



### 3.3.1 顺序式

```python
import operator
import os
from typing import TypedDict, Annotated, Sequence, Literal

from langchain_core.messages import BaseMessage, HumanMessage, AIMessage
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.constants import START, END
from langgraph.graph import StateGraph
from langgraph.prebuilt import ToolNode


# ==================== 定义状态 ====================
class ResearchState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], operator.add]
    research_queries: list[str]
    findings: list[str]
    iterations: int
    max_iterations: int


# ==================== 定义工具 ====================
@tool
def search_web(query: str) -> str:
    """搜索网络获取信息"""
    # TODO：调用搜索引擎 API
    return f"搜索结果：关于 '{query}' 的相关信息..."

@tool
def extract_key_points(text: str) -> str:
    """从文本中提取关键信息"""
    return f"关键点 {text[:100]}..."

tools = [search_web, extract_key_points]
tool_node = ToolNode(tools)


# ==================== 创建模型 ====================
llm = ChatOpenAI(
    model="qwen3-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    temperature=0,
)
llm_with_tools = llm.bind_tools(tools)


# ==================== 定义节点 ====================
def researcher_agent(state: ResearchState) -> dict:
    """研究员节点：分析问题、决定搜索策略"""
    messages = state["messages"]

    # 调用 LLM 进行分析
    response = llm_with_tools.invoke(messages)

    return {"messages": [response]}

def synthesizer_agent(state: ResearchState) -> dict:
    """综合节点：整合研究发现，生成最终答案"""
    findings = state["findings"]
    messages = state["messages"]

    synthesis_prompt = f"""
基于以下研究发现，请综合生成一个完整的回答：

研究发现：
{chr(10).join(f'- {f}' for f in findings)}

原始问题：{messages[0].content}
"""
    response = llm.invoke([HumanMessage(content=synthesis_prompt)])

    return {"messages": [response]}

def should_continue(state: ResearchState) -> Literal["tools", "synthesizer"]:
    """决定下一步行动"""
    last_message = state["messages"][-1]

    # 如果有工具调用，继续执行工具
    if last_message.tool_calls:
        return "tools"

    return "synthesizer"

def process_tool_results(state: ResearchState) -> dict:
    """处理工具执行结果"""
    last_message = state["messages"][-1]

    if isinstance(last_message, AIMessage) and last_message.tool_calls:
        # 可以添加逻辑来提取有用的发现
        return {
            "iterations": state["iterations"] + 1,
         }

    return {
        "iterations": state["iterations"] + 1,
    }


# ==================== 构建图 ====================
workflow = StateGraph(ResearchState)

# 添加节点
workflow.add_node("researcher", researcher_agent)
workflow.add_node("tools", tool_node)
workflow.add_node("process_results", process_tool_results)
workflow.add_node("synthesizer", synthesizer_agent)


# 添加边
workflow.add_edge(START, "researcher")
workflow.add_conditional_edges(
    "researcher",
    should_continue,
    {
        "tools": "tools",
        "synthesizer": "synthesizer",
    }
)
workflow.add_edge("tools", "process_results")
workflow.add_edge("process_results", "researcher")  # 循环回去
workflow.add_edge("synthesizer", END)

# 编译
app = workflow.compile()


# ==================== 运行示例 ====================
if __name__ == "__main__":
    # 初始状态
    initial_state = {
        "messages": [HumanMessage(content="请研究下 LangGraph 的主要特点和优势")],
        "research_queries": [],
        "findings": [],
        "iterations": 0,
        "max_iterations": 3,
    }

    result = app.invoke(initial_state)
    print(result["messages"][-1].content)
```



### 3.3.2 专家路由模式

```python
import os
from typing import TypedDict, Annotated

from langchain_core.messages import SystemMessage, HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.constants import START, END
from langgraph.graph import add_messages, StateGraph


# ==================== 定义状态 ====================
class RouterState(TypedDict):
    question: str
    expert_type: str
    answer: str


# ====================  LLM  ====================
llm = ChatOpenAI(
    model="qwen3-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    temperature=0,
)

# ==================== 定义节点 ====================
def router_node(state: RouterState) -> dict:
    """路由节点：分析问题，分配给合适的专家"""
    question = state["question"]

    prompt = f"""
分析以下问题，判断应该由哪位专家来回答：

问题：{question}

可选专家：
- math: 数学专家，处理计算、公式等问题
- code: 编程专家，处理代码、技术问题
- general: 通用专家，处理一般性问题

只回复专家类型 (math/code/general):
"""
    response = llm.invoke(prompt)
    expert_type = response.content.strip().lower()
    return {"expert_type": expert_type}

def math_expert(state: RouterState) -> dict:
    """数学专家"""
    response = llm.invoke(f"作为数学专家，请回答：{state['question']}")
    return {"answer": response.content}

def code_expert(state: RouterState) -> dict:
    """编程专家"""
    response = llm.invoke(f"作为编程专家，请回答：{state['question']}")
    return {"answer": response.content}


def general_expert(state: RouterState) -> dict:
    """通用专家"""
    response = llm.invoke(f"请回答：{state['question']}")
    return {"answer": response.content}


def route_to_expert(state: RouterState) -> str:
    """条件边：根据专家类型路由"""
    return state["expert_type"]


# ==================== 构建图 =====================
workflow = StateGraph(RouterState)
workflow.add_node("router", router_node)
workflow.add_node("math", math_expert)
workflow.add_node("code", code_expert)
workflow.add_node("general", general_expert)

workflow.add_edge(START, "router")
workflow.add_conditional_edges(
    "router",
    route_to_expert,
    {
        "math": "math",
        "code": "code",
        "general": "general",
    }
)
workflow.add_edge("math", END)
workflow.add_edge("code", END)
workflow.add_edge("general", END)

app = workflow.compile()


# ==================== 运行示例 ====================
if __name__ == "__main__":
    result = app.invoke({"question": "2加3等于多少？"})
    print(result)

    result = app.invoke({"question": "golang版冒泡算法"})
    print(result)

    result = app.invoke({"question": "马尔达夫简介"})
    print(result)
```



## 3.4 构建 RAG Agent

RAG（Retrieval-Augmented Generation） 检索增强生成

简单说：让AI先查资料，再回答问题。

流程：

- 用户提问

- AI判断是否需要查资料

- 如果需要，从知识库检索相关文档

- AI基于检索到的内容回答

```python
import os
from typing import Literal

from langchain_community.embeddings import DashScopeEmbeddings
from langchain_community.vectorstores import Chroma
from langchain_core.documents import Document
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.constants import END
from langgraph.graph import StateGraph, MessagesState
from langgraph.prebuilt import ToolNode

# ==================== 准备知识库 ====================
documents = [
    Document(page_content="LangGraph是LangChain生态中的图工作流框架", metadata={"source": "doc1"}),
    Document(page_content="LangGraph支持循环、分支和条件路由", metadata={"source": "doc2"}),
    Document(page_content="State是LangGraph中所有节点共享的数据结构", metadata={"source": "doc3"}),
]

embeddings = DashScopeEmbeddings(
    model="text-embedding-v4",
    dashscope_api_key=os.getenv("DASHSCOPE_API_KEY"),
)

vector_store = Chroma.from_documents(documents, embeddings)
retriever = vector_store.as_retriever()

# ==================== 定义工具 ====================
@tool
def search_knowledge_base(query: str) -> str:
    """搜索知识库获取相关信息"""
    docs = retriever.invoke(query)
    return "\n".join([doc.page_content for doc in docs])

tools = [search_knowledge_base]

# ==================== 定义节点 ====================
def agent(state: MessagesState) -> dict:
    llm = ChatOpenAI(
        api_key=os.getenv('DASHSCOPE_API_KEY'),
        base_url=os.getenv('DASHSCOPE_BASE_URL'),
        model="qwen-max",
        temperature=0.3,  # 保证摘要稳定、不发散
        max_tokens=500
    ).bind_tools(tools)

    system_prompt = """你是一个助手。
回答问题时：
- 如果设计 LangGraph、LangChain 相关知识，请使用 search_knowledge_base 工具
- 否则直接回答    
"""

    messages = [SystemMessage(content=system_prompt)] + state["messages"]
    response = llm.invoke(messages)
    return {"messages": [response]}

def should_continue(state: MessagesState) -> Literal["tools", "end"]:
    last_message = state["messages"][-1]

    if hasattr(last_message, "tool_calls") and last_message.tool_calls:
        return "tools"

    return "end"

# ==================== 构建图 =====================
workflow = StateGraph(MessagesState)

workflow.add_node("agent", agent)
workflow.add_node("tools", ToolNode(tools))

workflow.set_entry_point("agent")
workflow.add_conditional_edges(
    "agent",
    should_continue,
    {
        "tools": "tools",
        "end": END,
    }
)
workflow.add_edge("tools", "agent")

app = workflow.compile()

# ==================== 运行示例 ====================
if __name__ == "__main__":
    result = app.invoke({
        "messages": [HumanMessage(content="LangGraph的State是什么？")],
    })

    for msg in result["messages"]:
        msg.pretty_print()
```



# 4. 高级特性

## 4.1 状态持久化 (Checkpointing)

LangGraph 支持将状态持久化到数据库，实现端点续传和人工干预

```python
from langgraph.checkpoint.memory import MemorySaver

# 创建 checkpointer
checkpointer = MemorySaver()

# 编译时传入 checkpointer
app = workflow.compile(checkpointer=checkpointer)

# 运行时指定 thread_id (对话ID)
config = {"configurable": {"thread_id": "conversation-123"}}

# 第一轮对话
result1 = app.invoke(
	{"messages": [HumanMessage(content="我是ELI")]},
    config=config,
)

# 第二轮对话
result2 = app.invoke(
	{"messages": [HumanMessage(content="我是谁")]},
    config=config,
)
```



生产级别持久化：

```bash
pip install langgraph-checkpoint-sqlite
pip install langgraph-checkpoint-mysql  // MySQL >= 8.0.19 < 9.x
pip install langgraph-checkpoint-redis  // Redis 8.0+ or use Redis Stack
pip install langgraph-checkpoint-postgres
```



使用总结：

```python
from langgraph.checkpoint.memory import MemorySaver
from langgraph.checkpoint.sqlite import SqliteSaver

# 使用内存存储（开发调试）
with MemorySaver() as memory_checkpointer: 
	app = workflow.compile(checkpointer=memory_checkpointer)

# 使用 SQLite 持久化（生产环境）- 推荐写法
with SqliteSaver.from_conn_string("checkpoints.db") as sqlite_checkpointer:
    app = workflow.compile(checkpointer=sqlite_checkpointer)

# 或者使用内存数据库（测试用）
with SqliteSaver.from_conn_string(":memory:") as memory_sqlite:
	app = workflow.compile(checkpointer=memory_sqlite)

# 执行时指定 thread_id
config = {"configurable": {"thread_id": "conversation-123"}}
result = app.invoke(initial_state, config)

# 恢复执行（断点续传）
result = app.invoke(None, config)  # 从上次断点继续
```



## 4.2 流式输出 (Streaming)

### 4.2.1 stream() 方法

**stream_mode**：

- "values"：每次状态更新后输出完整状态

- "updates"：只输出节点的更新部分

- "debug"：包含详细的调试信息

```python
# 流式输出token
for chunk in app.stream(
    {"messages": [HumanMessage(content="写一首关于春天的诗")]},
    stream_mode="values"
):
    chunk["messages"][-1].pretty_print()

# 流式更新
for update in app.stream(
{"messages": [HumanMessage(content="写一首关于秋天的诗")]},
    stream_mode="updates"
):
    for node_name, node_output in update.items():
        print(f"节点 {node_name} 输出:")
        print(node_output)
```



### 4.2.2 astream_events() 方法

```python
# ==================== 流式输出 ===================
async def stream_response(initial_state: dict):
    """流式响应输出"""
    async for event in app.astream_events(initial_state, version="v2"):
        kind = event["event"]

        match kind:
            case "on_chain_start":
                print(f"\n▶ 开始执行: {event['name']}")
            case "on_chain_end":
                print(f"✓ 完成执行: {event['name']}")
            case "on_chat_model_stream":
                # 流式输出 LLM token
                content = event["data"]["chunk"].content
                if content:
                    print(content, end="", flush=True)
            case "on_tool_start":
                print(f"\n🔧 调用工具: {event['name']}")
            case "on_tool_end":
                print(f"✓ 工具完成: {event['name']}")


# ==================== 运行示例 ====================
async def main():
    await stream_response({"question": "2加3等于多少？"})
    await stream_response({"question": "golang版冒泡算法"})
    await stream_response({"question": "马尔达夫简介"})

if __name__ == "__main__":
    asyncio.run(main())
```



## 4.3 人工干预 (Human-in-the-Loop)

```python
import operator
import os
from typing import TypedDict, Annotated, Sequence, Literal

from langchain_core.messages import BaseMessage, HumanMessage, AIMessage
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.checkpoint.memory import InMemorySaver
from langgraph.constants import START, END
from langgraph.graph import StateGraph
from langgraph.prebuilt import ToolNode


# ==================== 定义状态 ====================
class ResearchState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], operator.add]
    research_queries: list[str]
    findings: list[str]
    iterations: int
    max_iterations: int
    needs_review: bool  # ✅ 新增
    approved: bool      # ✅ 新增


# ==================== 定义工具 ====================
@tool
def search_web(query: str) -> str:
    """搜索网络获取信息"""
    # TODO：调用搜索引擎 API
    return f"搜索结果：关于 '{query}' 的相关信息..."

@tool
def extract_key_points(text: str) -> str:
    """从文本中提取关键信息"""
    return f"关键点 {text[:100]}..."

tools = [search_web, extract_key_points]
tool_node = ToolNode(tools)


# ==================== 创建模型 ====================
llm = ChatOpenAI(
    model="qwen3-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    temperature=0,
)
llm_with_tools = llm.bind_tools(tools)


# ==================== 定义节点 ====================
def researcher_agent(state: ResearchState) -> dict:
    """研究员节点：分析问题、决定搜索策略"""
    messages = state["messages"]

    # 调用 LLM 进行分析
    response = llm_with_tools.invoke(messages)

    return {"messages": [response]}

def synthesizer_agent(state: ResearchState) -> dict:
    """综合节点：整合研究发现，生成最终答案"""
    findings = state["findings"]
    messages = state["messages"]

    synthesis_prompt = f"""
基于以下研究发现，请综合生成一个完整的回答：

研究发现：
{chr(10).join(f'- {f}' for f in findings)}

原始问题：{messages[0].content}
"""
    response = llm.invoke([HumanMessage(content=synthesis_prompt)])

    return {"messages": [response]}

# ✅ 路由到 synthesizer 改为 human_review
def should_continue(state: ResearchState) -> Literal["tools", "human_review"]:
    """决定下一步行动"""
    last_message = state["messages"][-1]

    # 如果有工具调用，继续执行工具
    if last_message.tool_calls:
        return "tools"

    return "human_review"

def process_tool_results(state: ResearchState) -> dict:
    """处理工具执行结果"""
    last_message = state["messages"][-1]

    if isinstance(last_message, AIMessage) and last_message.tool_calls:
        # 可以添加逻辑来提取有用的发现
        return {
            "iterations": state["iterations"] + 1,
         }

    return {
        "iterations": state["iterations"] + 1,
    }

# ✅ 新增人工审核节点
def human_review_node(state: ResearchState) -> dict:
    """等待人工审核"""
    # 该节点会暂停执行，等待人工输入
    print("进入人工审核环节...")
    return {"needs_review": True}

# ==================== 构建图 ====================
workflow = StateGraph(ResearchState)

# 添加节点
workflow.add_node("researcher", researcher_agent)
workflow.add_node("tools", tool_node)
workflow.add_node("process_results", process_tool_results)
workflow.add_node("synthesizer", synthesizer_agent)
workflow.add_node("human_review", human_review_node)  # ✅ 新增节点

# 添加边
workflow.add_edge(START, "researcher")
workflow.add_conditional_edges(
    "researcher",
    should_continue,
    {
        "tools": "tools",
        "human_review": "human_review",   # ✅ 由 synthesizer 改为 human_review，即综述前进行人工审核
    }
)
workflow.add_edge("tools", "process_results")
workflow.add_edge("process_results", "researcher")

workflow.add_edge("human_review", "synthesizer")   # ✅ 人工审核后，再综述
workflow.add_edge("synthesizer", END)

# 编译
app = workflow.compile(
    checkpointer=InMemorySaver(),       # ✅ HITL 必须有记忆功能
    interrupt_before=["human_review"]   # ✅ 在 human_review 前暂停
)


# ==================== 运行示例 ====================
if __name__ == "__main__":
    # ✅ 会话配置
    config = {"configurable": {"thread_id": "conversation-123"}}

    # 初始状态
    initial_state = {
        "messages": [HumanMessage(content="LangGraph的主要特点和优势")],
        "research_queries": [],
        "findings": [],
        "iterations": 0,
        "max_iterations": 3,
    }

    # 第一次执行，在human_review 前暂停
    result = app.invoke(initial_state, config=config)
    print(result["messages"][-1].content)
    print("=" * 30)
    print("等待人工审核...")

    # ✅ 人工审核后继续执行
    app.update_state(config, {"approved": True}) # 更新状态
    result = app.invoke(None, config=config)
    print(result["messages"][-1].content)
```



# 5. 新特性

## 5.1 Command

Command 允许节点同时完成**状态更新**和**路由决策**，大幅简化代码，的优势**：

- ✅ 代码更简洁：状态和路由逻辑在一起
- ✅ 更灵活：每个节点可以动态决定下一步
- ✅ 减少错误：不需要同步多个地方的逻辑
- ✅ 适合复杂流程：轻松实现复杂的决策树

```python
# ❌ 旧方法：需要分开处理
def my_node(state):
    return {"counter": state["counter"] + 1}

def router(state):
    if state["counter"] > 5:
        return "end"
    return "continue"

workflow.add_conditional_edges("my_node", router, {...})


# ✅ 新方法：一步完成
from langgraph.types import Command

def my_node(state):
    if state["counter"] > 5:
        return Command(
            update={"counter": state["counter"] + 1},
            goto=END
        )

    return Command(
        update={"counter": state["counter"] + 1},
        goto="my_node"
    )
```



## 5.2 interrupt() 函数

中断流程，让人工介入 (Human-in-the-Loop) 变得极其简单

```python
# ❌ 旧方法：需要在编译时指定
app = workflow.compile(
    checkpointer=checkpointer,
    interrupt_before=["approval_node"]  # 硬编码，不够灵活
)

# ✅ 新方法：在节点内部动态中断
from langgraph.types import interrupt, Command

def approval_node(state):
    # 暂停并请求审批
    user_decision = interrupt({
        "question": "是否批准此操作？",
        "details": state["details"],
        "options": ["approve", "reject", "modify"]
    })
    
    # 根据用户决策继续
    if user_decision == "approve":
        return Command(goto="execute")
    elif user_decision == "reject":
        return Command(goto=END)
    else:
        modifications = interrupt("请输入修改内容：")
        return Command(
            update={"details": modifications},
            goto="reprocess"
        )
```



**高级用法：工具调用审批**

```python
def review_tool_calls(state):
    """逐个审核 AI 要调用的工具"""
    
    tool_calls = state["messages"][-1].tool_calls
    approved_calls = []
    
    for tool_call in tool_calls:
        # 展示工具调用详情
        approval = interrupt({
            "tool": tool_call["name"],
            "args": tool_call["args"],
            "question": f"允许调用 {tool_call['name']} 工具吗？",
            "risk_level": assess_tool_risk(tool_call)
        })
        
        if approval["decision"] == "approve":
            # 用户可能修改了参数
            if "modified_args" in approval:
                tool_call["args"] = approval["modified_args"]
            approved_tools.append(tool_call)
            
        elif approval["decision"] == "skip":
            continue  # 跳过当前工具
            
        else:
            return Command(goto=END)  # 拒绝调用工具
        
    return Command(
    	update={"approved_tool_calls": approved_calls},
        goto="execute_tools"
    )
```



## 5.3 工具直接更新状态

工具可以返回 Command，直接更新图的状态和控制流程

```python
from langchain_core.tools import tool
from langgraph.types import Command


@tool
def smart_search(query: str, state) -> Command:
    """智能搜索 - 可以更新状态和决定路由"""

    results = search_api(query)

    # 根据结果质量决定下一步
    if len(results) == 0:
        return Command(
            update={
                "search_results": [],
                "needs_refinement": True,
            },
            goto="refine_query",  # 需要优化查询
        )
    elif len(results) > 100:
        return Command(
            update={
                "search_results": results[:10],
                "too_broad": True,
            },
            goto="narrow_query",
        )
    else:
        return Command(
            update={
                "search_results": results,
                "search_count": state.get("search_count", 0) + 1,
            },
            goto="process_results",
        )

@tool
def validate_then_route(data: str) -> Command:
    """验证数据并决定路由"""

    result = validate(data)

    if result["valid"]:
        return Command(
            update={"validated_data": data},
            goto="process",
        )
    elif result["can_fix"]:
        return Command(
            update={"errors": result["errors"]},
            goto="auto_fix",
        )
    else:
        return Command(
            update={"errors": result["errors"]},
            goto="human_review",
        )
```



## 5.4 Node Caching (性能优化)

缓存节点结果，避免重复计算

```python
from langgraph.graph import StateGraph

def expensive_analysis(state):
    """耗时的分析任务"""
    # 假设这个操作需要很长时间
    result = run_heavy_computation(state["data"])
    return {"analysis": result}

# 构建图
workflow = StateGraph(State)

# 启用缓存
workflow.add_node(
	"analyze",
    expensive_analysis,
    cache=True,  # 缓存结果
)

# 编译时配置
app = workflow.compile(
	cache_config={
        "ttl": 3600,
        "max_size": 100,
    }
)

# 第一次：很慢
result1 = app.invoke({"data": "..."})

# 第二次：毫秒级
result2 = app.invoke({"data": "..."})
```



**高级缓存策略**：

```python
# 自定义缓存键
workflow.add_node(
	"process",
	"process_node",
    cache=True,
    cache_key=lambda state: f"{state['user_id']}:{state['query']}"
)

# 条件缓存
workflow.add_node(
	"compute",
	expensive_computation,
    cache=lambda state: state.get("mode") == "production"
)
```



## 5.5 Deferred Nodes (并行任务同步)

**等待所有并行分支完成后再执行**

```python
import random
import time
from typing import TypedDict

from langgraph.constants import START, END
from langgraph.graph import StateGraph


class State(TypedDict):
    query: str
    user_id: int
    user_data: dict
    product_id: int
    product_data: dict
    analytics: str

def fetch_from_db(user_id: int):
    time.sleep(random.randint(1, 3))
    return {
        "id": user_id,
        "name": "Tom",
        "age": 15,
        "gender": "male",
    }

def fetch_from_api(product_id: int):
    time.sleep(random.randint(1, 5))
    return {
        "id": product_id,
        "name": "intel",
        "type": "cpu"
    }

def run_analytics(query: str):
    time.sleep(random.randint(1, 2))
    return {
        "analytics": f"关于 {query} 的分析...",
    }

def generate_report(result: dict):
    report = ""
    for key, value in result.items():
        report += f"{key}: {value}\n"
    return report

def fetch_user_data(state: State):
    """获取用户数据"""
    return {"user_data": fetch_from_db(state["user_id"])}

def fetch_product_data(state: State):
    """获取产品数据"""
    return {"product_data": fetch_from_api(state["product_id"])}

def fetch_analytics(state: State):
    """获取分析数据"""
    return {"analytics": run_analytics(state["query"])}

def combine_all_data(state: State):
    """汇总所有数据 - 需要等待所有并行任务"""
    combined = {
        "user": state["user_data"],
        "product": state["product_data"],
        "analytics": state["query"],
    }
    return {"result": generate_report(combined)}

# 构建图
workflow = StateGraph(State)

# 添加并行任务
workflow.add_node("fetch_user", fetch_user_data)
workflow.add_node("fetch_product", fetch_product_data)
workflow.add_node("fetch_analytics", fetch_analytics)

# 添加聚合节点，标记为 defer
workflow.add_node(
    "combine",
    combine_all_data,
    defer=True,
)

# 三个任务并行启动
workflow.add_edge(START, "fetch_user")
workflow.add_edge(START, "fetch_product")
workflow.add_edge(START, "fetch_analytics")

# 都连到 combine，等待全部完成
workflow.add_edge("fetch_user", "combine")
workflow.add_edge("fetch_product", "combine")
workflow.add_edge("fetch_analytics", "combine")
workflow.add_edge("combine", END)

# 编译
app = workflow.compile()

if __name__ == "__main__":
    initial_state = {
        "user_id": 1,
        "product_id": 2,
        "query": "用户关联产品金额统计"
    }

    result = app.invoke(initial_state)
    print(result)
```



## 5.6 LangGraph Supervisor (多代理协调)

**简化层级多代理系统**

```python
# pip install langgraph-supervisor
from langgrap_supervisor import create_supervisor
from langchain_anthropic import ChatAnthropic

llm = ChatAnthropic(model="")

# 专家 Agent
researcher = create_agent(
	"researcher",
    llm,
    tools=[web_search, academic_search],
    system_prompt="你是研究专家"
)

coder = create_agent(
	"coder",
    llm,
    tools=[python_repl, code_review],
    system_prompt="你是编程专家"
)

writer = create_agent(
	"writer",
    llm,
    tools=[grammer_check],
    system_prompt="你是写作专家"
)

# 创建 supervisor
supervisor = create_supervisor(
	agents={
        "researcher": researcher,
        "coder": coder,
        "writer": writer,
    },
    workflow_type="dynamic",  # 动态决定调用顺序
    llm=llm,  # 使用 LLM 做决策
)

# supervisor 自动协调
result = supervisor.invoke({
    "task": "研究最新的 AI 框架，写代码示例，然后写一篇教程"
})
```



**不同的 Supervisor 模式**：

```python
# 1. 顺序模式
supervisor = create_supervisor(
	agents={...},
    workflow_type="sequential",
    sequence=["researcher", "coder", "writer"]
)

# 2. 并行模式
supervisor = create_supervisor(
	agents={...},
    workflow_type="parallel",
    parallel_tasks=["research", "data_collection", "analysis"]
)

# 3. 层级模式
supervisor = create_supervisor(
	agents={
        "manager": manager_agent,
        "workers": [worker1, worker2, worker3]
    },
    workflow_type="hierarchical"
)
```



# 6. 实战示例

## 6.1 智能客服系统

```python
import operator
import os
from datetime import datetime
from typing import TypedDict, Annotated, Sequence, Literal

from langchain_core.messages import BaseMessage, SystemMessage, AIMessage, HumanMessage
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.checkpoint.memory import MemorySaver
from langgraph.constants import START, END
from langgraph.graph import StateGraph
from langgraph.prebuilt import ToolNode


# ====================== 状态定义 ===================
class CustomerServiceState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], operator.add]
    customer_id: str | None
    issue_type: str | None   # "technical", "billing", "general", "escalate"
    resolved: bool
    escalation_reason: str | None
    satisfaction_score: int | None


# ====================== 工具定义 ===================
@tool
def check_order_status(order_id: str) -> str:
    """查询订单状态"""
    # 模拟数据库查询
    orders = {
        "12345": {"status": "已发货", "tracking": "SF123456789"},
        "56789": {"status": "处理中", "tracking": None},
    }
    order = orders.get(order_id)
    if order:
        return f"订单状态：{order['status']}, 物流单号：{order['tracking'] or '暂无'}"
    return "未找到该订单"

@tool
def create_ticket(customer_id: str, issue: str, priority: str = "normal") -> str:
    """创建工单"""
    ticket_id = f"TK-{datetime.now().strftime('%Y%m%d%H%M%S')}"
    return f"已创建工单 {ticket_id}, 问题描述：{issue}, 优先级：{priority}"

@tool
def get_customer_info(customer_id: str) -> str:
    """获取客户信息"""
    customers = {
        "C001": {"name": "张三", "vip": True, "orders": 15},
        "C002": {"name": "李四", "vip": False, "orders": 3},
    }
    info = customers.get(customer_id)
    if info:
        return f"客户：{info['name']}, VIP：{info['vip']}, 历史订单数：{info['orders']}"
    return "未找到客户信息"

@tool
def transfer_to_human(reason: str) -> str:
    """转人工客服"""
    return f"已提交转人工请求，原因：{reason}，预计等待 3 分钟"

tools = [check_order_status, create_ticket, get_customer_info, transfer_to_human]
tool_node = ToolNode(tools)


# ====================== 节点定义 ===================
def classify_intent(state: CustomerServiceState) -> dict:
    """分类用户意图"""
    messages = state["messages"]
    last_message = messages[-1].content if messages else ""

    prompt = f"""分析用户问题，判断问题类型：

问题：{last_message}

类型选项：
- technical: 技术问题
- billing: 订单/支付问题
- general: 一般咨询
- escalate: 要求转人工

只回复类型 (technical/billing/general/escalate):
"""

    llm = ChatOpenAI(
        model="qwen3-max",
        api_key=os.getenv("DASHSCOPE_API_KEY"),
        base_url=os.getenv("DASHSCOPE_BASE_URL"),
        temperature=0,
    )
    response = llm.invoke(prompt)
    issue_type = response.content.strip().lower()
    return {"issue_type": issue_type}

def technical_agent(state: CustomerServiceState) -> dict:
    """技术支持 Agent"""
    llm = ChatOpenAI(
        model="qwen3-max",
        api_key=os.getenv("DASHSCOPE_API_KEY"),
        base_url=os.getenv("DASHSCOPE_BASE_URL"),
        temperature=0,
    ).bind_tools(tools)

    system_prompt ="""你是一个技术支持专家。
- 优先使用 check_order_status 查询订单状态
- 如果问题复杂无法解决，使用 transfer_to_human 转人工
- 回答要专业、清晰
"""

    messages = [SystemMessage(content=system_prompt)] + list(state["messages"])
    response = llm.invoke(messages)
    return {"messages": [response]}


def billing_agent(state: CustomerServiceState) -> dict:
    """账单/订单 Agent"""
    llm = ChatOpenAI(
        model="qwen3-max",
        api_key=os.getenv("DASHSCOPE_API_KEY"),
        base_url=os.getenv("DASHSCOPE_BASE_URL"),
        temperature=0,
    ).bind_tools(tools)

    system_prompt = """你是一个订单和账单专家。
- 使用 check_order_status 查询订单
- 使用 get_customer_info 了解客户信息
- 确保回答准确、及时
"""

    messages = [SystemMessage(content=system_prompt)] + list(state["messages"])
    response = llm.invoke(messages)
    return {"messages": [response]}


def general_agent(state: CustomerServiceState) -> dict:
    """通用客服 Agent"""
    llm = ChatOpenAI(
        model="qwen3-max",
        api_key=os.getenv("DASHSCOPE_API_KEY"),
        base_url=os.getenv("DASHSCOPE_BASE_URL"),
        temperature=0,
    ).bind_tools(tools)

    system_prompt = """你是一个友好的客服代表。
- 耐心回答用户问题
- 如果问题无法处理，使用 transfer_to_human 转人工
"""

    messages = [SystemMessage(content=system_prompt)] + list(state["messages"])
    response = llm.invoke(messages)
    return {"messages": [response]}

def escalate_handler(state: CustomerServiceState) -> dict:
    """升级处理"""
    return {
        "escalation_reason": "用户请求转人工",
        "messages": [AIMessage(content="好的，我正在为你转接人工客服，请稍等...")]
    }

def should_continue(state: CustomerServiceState) -> Literal["tools", "check_resolved"]:
    """判断是否继续"""
    messages = state["messages"]
    last_message = messages[-1]

    if isinstance(last_message, AIMessage) and last_message.tool_calls:
        return "tools"

    return "check_resolved"

def route_by_intent(state: CustomerServiceState) -> str:
    """根据意图路由到不同 Agent"""
    return state["issue_type"]

def check_resolved(state: CustomerServiceState) -> Literal["end", "continue"]:
    """检查是否已解决 (用于复杂的多轮对话场景)"""
    last_message = state["messages"][-1]
    if isinstance(last_message, HumanMessage):
        content = last_message.content.lower()
        if any(word in content for word in ["谢谢", "再见", "好的"]):
            return "end"
    return "continue"


# ====================== 构建图 ===================
workflow = StateGraph(CustomerServiceState)

# 添加节点
workflow.add_node("classify", classify_intent)
workflow.add_node("technical", technical_agent)
workflow.add_node("billing", billing_agent)
workflow.add_node("general", general_agent)
workflow.add_node("escalate", escalate_handler)
workflow.add_node("tools", tool_node)

# 入口边
workflow.add_edge(START, "classify")

# 根据意图路由到不同 Agent
workflow.add_conditional_edges(
    "classify",
    route_by_intent,
    {
        "technical": "technical",
        "billing": "billing",
        "general": "general",
        "escalate": "escalate",
    }
)

# 技术 Agent 后续流程
workflow.add_conditional_edges(
    "technical",
    should_continue,
    {
        "tools": "tools",
        "check_resolved": END,  # 简化：无工具调用则结束
    }
)

# 账单 Agent 后续流程
workflow.add_conditional_edges(
    "billing",
    should_continue,
    {
        "tools": "tools",
        "check_resolved": END,  # 简化：无工具调用则结束
    }
)

# 通用 Agent 后续流程
workflow.add_conditional_edges(
    "general",
    should_continue,
    {
        "tools": "tools",
        "check_resolved": END,  # 简化：无工具调用则结束
    }
)

# 工具调用后回归分类
workflow.add_edge("tools", "classify")

# 升级处理直接结束
workflow.add_edge("escalate", END)

# 编译
checkpointer = MemorySaver()
app = workflow.compile(checkpointer=checkpointer)


# ====================== 运行示例 ===================
if __name__ == "__main__":
    initial_state = {
        "messages": [HumanMessage(content="我的订单 12345 现在什么状态？")],
        "customer_id": "C001",
        "issue_type": None,
        "resolved": False,
        "escalation_reason": None,
        "satisfaction_score": None,
    }

    config = {"configurable": {"thread_id": "conversation-123"}}

    result = app.invoke(initial_state, config=config)
    print(result["messages"][-1].content)
```



## 6.2 智能审批流程

```python
import json
import os
from typing import TypedDict

from anthropic import Anthropic
from langgraph.checkpoint.memory import MemorySaver
from langgraph.constants import END
from langgraph.graph import StateGraph
from langgraph.types import Command, interrupt


# ==================== 定义状态 ====================
class ApprovalState(TypedDict):
    request: str
    approved: bool
    retry_count: int
    reason: str

# ==================== 调用模型 ====================
def call_ai_model(request: str) -> dict:
    """调用 AI 模型进行决策"""
    prompt = f"""你是一个请求审批助手，请分析以下请求并决定是否批准。

请求内容：{request}

请从以下维度评估：
1. 操作的必要性和合理性
2. 潜在风险和影响范围
3. 是否符合常规业务流程

请以 JSON 格式返回，格式如下：
{{
    "approved": true/false,
    "reason": "决策理由（50字以内）",
    "confidence": 0.0-1.0
}}

只返回 JSON，不要其他内容。"""

    client = Anthropic(
        api_key=os.getenv("DASHSCOPE_API_KEY"),
        # base_url=os.getenv("DASHSCOPE_BASE_URL"),
        base_url="https://dashscope.aliyuncs.com/apps/anthropic",
    )

    response = client.messages.create(
        model="qwen-max",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": prompt,
            },
        ]
    )

    return json.loads(response.content[0].text)

def assess_risk(request: str) -> str:
    """
    评估请求风险等级
    返回: "low" | "medium" | "high
    """
    prompt = f"""你是一个风险评估专家，请分析以下请求的风险等级。

请求内容：{request}

风险等级标准：
- low（低风险）：只读操作、查询、获取信息、无副作用的操作
- medium（中等风险）：修改非关键数据、可撤销的操作、影响范围有限
- high（高风险）：删除数据、涉及资金/权限变更、不可撤销操作、影响范围广

请只返回 JSON，格式如下：
{{
    "risk_level": "low" | "medium" | "high",
    "reason": "判断依据（30字以内）"
}}"""

    client = Anthropic(
        api_key=os.getenv("DASHSCOPE_API_KEY"),
        # base_url=os.getenv("DASHSCOPE_BASE_URL"),
        base_url="https://dashscope.aliyuncs.com/apps/anthropic",
    )

    response = client.messages.create(
        model="qwen-max",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": prompt,
            },
        ]
    )

    result = json.loads(response.content[0].text)
    risk_level = result["risk_level"]

    # 防御性校验，确保返回值合法
    if risk_level not in ["low", "medium", "high"]:
        risk_level = "high"  # 无法识别时默认高风险

    return risk_level

# ==================== 定义节点 ====================
def ai_review_node(state: ApprovalState):
    """AI 辅助决策 - 中等风险请求"""

    # 调用 AI 模型进行风险评估
    ai_decision = call_ai_model(state["request"])

    if ai_decision["approved"]:
        return Command(
            update={
                "approved": True,
                "reason": f"AI 审批通过 - {ai_decision['reason']}",
            },
            goto="execute",
        )
    else:
        return Command(
            update={
                "approved": False,
                "reason": f"AI 建议拒绝 - {ai_decision['reason']}",
            },
            goto="human_approval",  # 降级到人工审批
        )

def analyze_request(state: ApprovalState):
    """分析请求并决定是否需要审批"""
    risk_level = assess_risk(state["request"])

    if risk_level == "low":
        # 低风险：自动批准
        return Command(
            update={
                "approved": True,
                "reason": "自动批准 - 低风险操作"
            },
            goto="execute",
        )
    elif risk_level == "high":
        # 高风险：需要人工审批
        return Command(
            update={"approved": False},
            goto="human_approval",
        )
    else:
        # 中风险：AI 辅助决策
        return Command(
            goto="ai_review"
        )

def human_approval(state: ApprovalState):
    """人工审批"""
    # ... 等待人工输入
    print("waiting for human approval...")

    # ⬇ 挂起图，把请求内容暴露给外部
    decision = interrupt({
        "request": state["request"],
        "message": "请审批以下请求，返回 {'approved': True/False, 'reason': '...'}"
    })

    approved = decision.get("approved", False)
    reason = decision.get("reason", "")

    if approved:
        return Command(
            update={"approved": True, "reason": reason},
            goto="execute",
        )
    else:
        if state["retry_count"] < 3:
            return Command(
                update={
                    "approved": False,
                    "reason": reason,
                    "retry_count": state["retry_count"] + 1
                },
                goto="analyze_request",  # 重新分析
            )
        else:
            return Command(
                update={"approved": False, "reason": "超过最大重试次数"},
                goto=END
            )

def execute(state: ApprovalState):
    """执行操作"""
    if state["approved"]:
        # 执行逻辑
        print(f"执行: {state['request']}")
    return {}

# ==================== 构建图 =====================
workflow = StateGraph(ApprovalState)

workflow.add_node("analyze_request", analyze_request)
workflow.add_node("human_approval", human_approval)
workflow.add_node("ai_review", ai_review_node)
workflow.add_node("execute", execute)

# 不再需要 conditional_edges
workflow.set_entry_point("analyze_request")

# 引入HITL，需要挂载 checkpointer，interrupt 才能持久化挂起状态
app = workflow.compile(checkpointer=MemorySaver())

# 引入配置
config = {"configurable": {"thread_id": "user-001"}}

# ==================== 运行示例 ====================
if __name__ == "__main__":
    # ======== 示例 1：低风险（自动批准）================
    print("=== 示例 1：查询操作（低风险）===")
    result = app.invoke({
        "request": "查询用户 ID=123 的账户余额",
        "approved": False,
        "retry_count": 0,
        "reason": ""
    }, config=config)
    print(result)

    # ======== 示例 2：中等风险（AI 审批）================
    print("\n=== 示例 2：修改配置（中等风险）===")
    result = app.invoke({
        "request": "将用户 ID=123 的邮件通知频率改为每日一次",
        "approved": False,
        "retry_count": 0,
        "reason": ""
    }, config=config)
    print(result)

    # ======== 示例 3：高风险（人工审批）================
    print("\n=== 示例 3：删除数据（高风险）===")
    result = app.invoke(
        {
            "request": "永久删除用户 ID=123 的所有订单记录",
            "approved": False,
            "retry_count": 0,
            "reason": ""
        },
        config=config,
    )
    print("已挂起，等待人工审批")
    print("interrupt payload:", result)

    # 模拟人工审批：通过
    print("注入审批结果，恢复执行")
    human_decision = {
        "approved": True,
        "reason": "已确认操作合规，用户本人申请"
    }
    final = app.invoke(
        Command(resume=human_decision),  # 不再传 state，直接 resume
        config=config
    )
    print("最终状态:", final)

    # ======== 示例 4：高风险被拒，触发重试上限 ================
    print("\n=== 示例 4：多次拒绝达到上限 ===")
    result = app.invoke({
        "request": "清空生产数据库所有表",
        "approved": False,
        "retry_count": 0,  # 已达上限，直接 END
        "reason": ""
    }, config=config)
    print("已挂起，等待人工审批")
    print("interrupt payload:", result)

    # 模拟人工审批：拒绝
    for i in range(3):
        print(f"第{i+1}次审批，拒绝")
        result = app.invoke(
            Command(resume={"approved": False, "reason": "风险过高，拒绝"}),  # 不再传 state，直接 resume
            config=config
        )
        print("当前状态:", result)
    final = app.invoke(None, config=config)
    print("最终状态:", final)
```



## 6.3 邮件审核系统

```python
import json
import os
from typing import TypedDict

from anthropic import Anthropic
from langgraph.checkpoint.memory import MemorySaver
from langgraph.constants import END
from langgraph.graph import StateGraph
from langgraph.types import interrupt, Command


class EmailState(TypedDict):
    to: str
    subject: str
    body: str
    approved: bool


def generate_email_with_ai(to: str):
    """使用 AI 根据收件人生成邮件草稿"""
    prompt = f"""请为以下收件人起草一封专业的商务邮件：
收件人邮箱：{to}

要求：
1. 根据收件人邮箱推断其身份（如 boss@company.com 说明是公司领导）
2. 使用礼貌、专业的语气
3. 邮件内容简洁明了

请严格按照以下 JSON 格式返回，不要包含任何其他内容：
{{
    "subject": "邮件主题",
    "body": "邮件正文内容"
}}"""

    client = Anthropic(
        api_key=os.getenv("DASHSCOPE_API_KEY"),
        # base_url=os.getenv("DASHSCOPE_BASE_URL"),
        base_url="https://dashscope.aliyuncs.com/apps/anthropic",
    )

    message = client.messages.create(
        model="qwen-max",
        max_tokens=1024,
        messages=[
            {"role": "user", "content": prompt}
        ]
    )

    response_text = message.content[0].text.strip()

    # 清理可能的 markdown 代码块
    if response_text.startswith("```"):
        lines = response_text.split("\n")
        response_text = "\n".join(lines[1:-1])

    draft = json.loads(response_text)

    return {
        "subject": draft.get("subject", ""),
        "body": draft.get("body", "")
    }

def draft_email(state: EmailState):
    """AI 起草邮件"""
    draft = generate_email_with_ai(state["to"])
    return {
        "subject": draft["subject"],
        "body": draft["body"]
    }

def review_email(state: EmailState):
    """人工审核邮件"""

    # 第一次中断：展示邮件给用户
    approval = interrupt({
        "message": "请审核以下邮件",
        "to": state["to"],
        "subject": state["subject"],
        "body": state["body"],
        "actions": ["send", "edit", "cancel"]
    })

    if approval["action"] == "send":
        return Command(
            update={"approved": True},
            goto="send_email",
        )
    elif approval["action"] == "edit":
        # 第二次中断：获取编辑内容
        edits = interrupt({
            "message": "请修改邮件内容",
            "current_subject": state["subject"],
            "current_body": state["body"],
        })

        return Command(
            update={
                "subject": edits.get("subject", state["subject"]),
                "body": edits.get("body", state["body"]),
            },
            goto="review_email",  # 重新审核
        )
    else:
        # 撤销
        return Command(goto=END)

def send_email(state: EmailState):
    """发送邮件"""
    if state["approved"]:
        # 发送邮件，待实现
        print(f"✓ 邮件已发送到 {state['to']}")
    return {}

# 构建图
workflow = StateGraph(EmailState)
workflow.add_node("draft_email", draft_email)
workflow.add_node("review_email", review_email)
workflow.add_node("send_email", send_email)

workflow.set_entry_point("draft_email")
workflow.add_edge("draft_email", "review_email")

# 编译
app = workflow.compile(checkpointer=MemorySaver())


if __name__ == "__main__":
    config = {"configurable": {"thread_id": "C001"}}

    # 第一次运行，将在审核处暂停
    result = app.invoke({
        "to": "test@example.com",
    }, config=config)
    print("已挂起，等待审批", result.get("__interrupt__"))

    # 用户决策
    result = app.invoke(
        Command(resume={"action": "send"}),
        config=config
    )
    print(result)
```



# 7. 最佳实践

## 7.1 状态设计

```python
# ✅ 推荐
class GoodState(TypedDict):
    messages: Annotated[Sequence[BaseMessage], add_messages]
    errors: Annotated[list[str], operator.add]
    metadata: dict   # 元数据
    current_step: int

# ❌ 不推荐
class BadState(TypedDict):
    entire_conversation_history: dict  # 太大
    every_possible_field: str  # 冗余
```



## 7.2 节点设计

```python
# ✅ 推荐: 单一职责
def fetch_data(state):
    """只负责获取数据"""
    data = api_call()
    return {"data": data}

def process_data(state):
    """只负责处理数据"""
    processed = process(state["data"])
    return {"result": processed}

# ❌ 不推荐: 节点做太多事情
def do_everything(state):
    # 获取数据、处理、保存、通知...
    pass
```



## 7.3 错误处理

```python
from langgraph.pregel import GraphRecursionError

def safe_node(state: AgentState) -> dict:
    """带错误处理的节点"""
    try:
        # 业务逻辑
        result = do_something_risky(state)
        return {"result": result, "error": None}
    except Exception as e:
        # 返回错误状态而非抛出异常
        return {
            "error": str(e),
            "current_step": "error_recovery"
        }

# 在图中添加错误恢复路径
workflow.add_conditional_edges(
    "safe_node",
    lambda s: "error_recovery" if s.get("error") else "next_step",
    {"error_recovery": "error_handler", "next_step": "next_node"}
)
```

另一种方式：

```python
def robust_node(state: AgentState):
    try:
        result = risky_operation(state)
        return {"messages": [result], "error": None}
    except Exception as e:
        return {
            "messages": [HumanMessage(content=f"错误: {str(e)}")],
            "error": str(e)
        }

# 使用 Command 处理错误路由
def robust_node_with_command(state):
    try:
        result = risky_operation(state)
        return Command(
            update={"result": result},
            goto="success"
        )
    except Exception as e:
        return Command(
            update={"error": str(e)},
            goto="error_handler"
        )
```



## 7.4 Command 和 Condintional Edges

**使用 Command**：

- ✅ 节点内部逻辑决定路由
- ✅ 需要同时更新状态和路由
- ✅ 动态、复杂的决策树

**使用 Conditional Edges**：

- ✅ 简单的二选一路由
- ✅ 路由逻辑独立于节点
- ✅ 多个节点共用同一路由逻辑

```python
# 适合 Command
def complex_node(state):
    result = process(state)
    
    if result.needs_review:
        return Command(update={...}, goto="review")
    elif resuly.needs_retry:
        return Command(update={...}, goto="retry")
    else:
        return Command(update={...}, goto="finalize")
    
# 适合 Conditional Edges
def simple_router(state):
    return "a" if state["flag"] else "b"

workflow.add_condition_edges(
	"node",
    simple_router,
    {
        "a": "handler_a",
        "b": "handler_b"
    }
)
```



## 7.5 限制迭代次数

```python
class AgentState(TypedDict):
    # ... 其他字段
    iteration_count: int
    max_iterations: int  # 默认值如 10

def check_iteration_limit(state: AgentState) -> str:
    """防止无限循环"""
    if state["iteration_count"] >= state["max_iterations"]:
        return "end"
    return "continue"
```



## 7.6 使用类型注解

```python
from typing import TypedDict, Literal

# 明确的类型注解有助于 IDE 补全和静态检查
class MyState(TypedDict):
    status: Literal["pending", "processing", "completed", "failed"]
    count: int
    data: dict[str, str]
```



## 7.7 调试技巧

```python
# 1. 使用 LangSmith 追踪
import os
os.environ["LANGSMITH_API_KEY"] = "your-api-key"
os.environ["LANGSMITH_TRACING_V2"] = "true"
os.environ["LANGSMITH_PROJECT"] = "my-project"
os.environ["LANGSMITH_ENDPOINT"] = "https://api.smith.langchain.com"

# 2. 查看执行历史
config = {"configurable": {"thread_id": "1"}}
app.invoke(input, config)

history = app.get_state_history(config)
for state in history:
    print(state)
    
# 3. 调试图的执行，使用stream_mode="debug"
for event in app.stream(inputs, stream_mode="debug"):      
    print(event)
```



## 7.8 限制循环次数

设置递归限制：

```python    
result = app.invoke(inputs, config={"recursion_limit": 10})
```



# 8. 常见模式

## 8.1 ReAct Agent (推理-行动 循环)

```python
def react_pattern():
    """思考 -> 行动 -> 观察 -> 思考..."""
    
    def agent_think(state):
        # LLM 决定下一步行动
        response = llm.invoke(state["messages"])
        return {"messages": [response]}
    
    def agent_act(state):
        # 执行动作
        last_message = state["messages"][-1]
        if hasattr(last_message, "tool_calls"):
            # 调用工具...
            return {"messages": [tool_result]}
        return state
    
    workflow = StateGraph(AgentState)
    workflow.add_node("think", agent_think)
    workflow.add_node("act", agent_act)
    
    workflow.add_conditional_edges(
    	"think",
    	lambda s: "act" if has_tool_calls(s) else END,
        {"act": "act", END: END}
    )
    workflow.add_edge("act", "think")
```



## 8.2 Map-Reduce

```python
def map_reduce_pattern():
    """并行处理多个任务，然后汇总结果"""
    
    class MapReduceState(TypedDict):
        inputs: list
        mapped_results: list
        final_result: str
        
    def map_node(state):
        # 并行处理每个输入
        results = [process(item) for item in state["inputs"]]
        return {"mapped_results": results}
    
    def reduce_node(state):
        # 汇总结果
        final = combine(state["mapped_results"])
        return {"final_result": final}
    
    workflow = StateGraph(MapReduceState)
    workflow.add_node("map", map_node)
    workflow.add_node("reduce", reduce_node)
    workflow.add_edge("map", "reduce")
```



## 8.3 审批流程 (Command + interrupt)

```python
def approval_workflow():
    """流程审批"""
    
    def submit(state):
        """提交请求"""
        return Command(
        	update={"status": "pending"},
            goto="auto_review",
        )
        
    def auto_review(state):
        """自动审核"""
        risk = assess_risk(state["request"])
        
        if risk == "low":
            return Command(
            	update={"status": "auto_approved"},
                goto="approved"
            )
        else:
            return Command(goto="human_review")
        
    def human_review(state):
        """人工审核"""
        decision = interrupt({
            "request": state["request"],
            "risk": "high",
            "question": "是否批准？"
        })
        
        if decision == "approve":
            return Command(
            	update={"status", "approved"},
                goto="approved"
            )
        else:
            return Command(
            	update={"status": "rejected"},
                goto="rejected"
            )
            
	def approved(state):
        execute_action(state["request"])
        return {}
    
    def rejected(state):
        notify_rejection(state["request"])
        return {}
    
    workflow = StateGraph(State)
    workflow.add_node("submit", submit)
    workflow.add_node("auto_review", auto_review)
    workflow.add_node("human_review", human_review)
    workflow.add_node("approved", approved)
    workflow.add_node("rejected", rejected)
    
    workflow.set_entry_point("submit")
    
    app = workflow.compile(checkpointer=MemorySaver())
```



# 9. LangChain 和 LangGraph

## 9.1 LangChain

LangChain 的核心抽象是 **Chain(链)**，以流水线形式串联单向处理步骤，适配 RAG 等简单单向流程，复杂编排可通过 SequentialChain、RouterChain 实现。但链式设计过于简单，真实Agent场景包含条件分支、循环、动态路由等复杂控制流，用Chain实现十分勉强。

理解LangChain的价值，需要把它拆成两层来看：

- 第一层为组件层：LangChain 提供各类开箱即用模块包括各大LLM统一接口、文档加载器、文本切分器、Embedding封装、向量数据库集成、输出解析器等。这些是通用基础设施，不依赖编排框架，即便使用 LangGraph 编排，底层也大多复用 LangChain 的组件，价值持久
- 第二层为编排层：即Chain、Agent等抽象，也是 LangChain 饱受争议的部分。早期 AgentExecutor 将执行循环封装成黑箱，简单场景易用，但定制执行逻辑(如添加审批、失败降级)难以介入;后续LCEL用管道符|组合链，写法更优雅，本质仍为线性组合，对复杂控制流的支持依旧有限。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/langchain-vs-langgraph-layer.png)



## 9.2 LangGraph

LangGraph 的出发点完全不同。它把工作流建模成一个**有向图(Graph)**：每个处理步骤是图中的一个 **Node(节点)**，步骤之间的流转关系是 **Edge(边)**，整个系统运行的中间数据存放在一个全局的 **State(状态)** 对象里。节点可以读写State，边可以是无条件的(永远走这条路)也可以是条件边(根据State中的某个字段决定走哪条路)

LangGraph 的三个核心设计：

- **显式状态管理**。LangChain 的 Chain 通过参数隐式传递数据，步骤较少时尚可，复杂流程下数据流难以追溯。LangGraph 采用集中式State对象，通过TypedDict 或 Pydantic 定义结构，节点仅接收当前状态并更新字段，由引擎统一合并，实现状态可追踪、可查看快照，还能从中间状态重新执行。
- **Checkpointing检查点机制**。LangGraph 内置持久化能力，节点执行后自动保存完整状态快照，支持对话中断恢复、人工审批暂停续跑、线上问题状态重放，这种“可暂停、可恢复、可回放”的特性，对生产级Agent应用价值极高。
- **原生循环与条件路由支持**。LangGraph 的图结构天然支持环路，Agent的 ReAct 循环可直接建模，无需额外变通;条件边能依据运行时状态动态决定执行路径，在错误处理、降级策略、分支逻辑等场景中十分实用。



## 9.3 对比分析

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/langchain-vs-langgraph.png)

**选择 LangChain 当：**

- ✅ 快速原型开发，验证想法
- ✅ 工作流相对简单、线性
- ✅ 不需要复杂的状态管理
- ✅ 单一 Agent 即可完成任务
- ✅ 团队成员对 Agent 开发不熟悉

**选择 LangGraph 当：**

- ✅ 构建生产级 Agent 系统
- ✅ 工作流复杂，有循环、分支、条件判断
- ✅ 需要状态持久化和断点续传
- ✅ 多 Agent 协作场景
- ✅ 需要人工干预（Human-in-the-Loop）
- ✅ 需要详细的执行追踪和调试

**实践中：** 很多项目从 LangChain 开始快速验证，然后迁移到 LangGraph 进行生产化。两者可以无缝集成。






