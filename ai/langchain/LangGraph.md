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



### 2.1.1 Reducer

状态管理与 Reducers：

- **默认覆盖**：节点返回的字段会**直接覆盖** state 中同名的字段

- **Reducer**：自定义合并逻辑。当需要追加而不是覆盖时，用 Annotated + reducer

  ```python
  class State(TypedDict):
      # values 字段用 add reducer — 新值会追加到列表
      values: Annotated[list[int], operator.add]
      total: int
  ```



Reducer 工作原理：

- 无 Reducer：`state[field] = new_value` （覆盖）
- 有 Reducer：`state[field] = reducer(old_value, new_value)`



自定义 Reducer：

```python
def keep_max(current: int, new: int) -> int:
    """保留最大值"""
    return max(current, new)

class State(TypedDict):
    score: Annotated[int, keep_max]
```



### 2.1.2 MessageState

LangGraph 预定了 MessageState，专门用于对话场景：

```python
from langgraph.graph import MessagesState

# MessagesState 等价于：
# class MessagesState(TypedDict):
#     messages: Annotated[list[BaseMessage], add_messages]
#
# add_messages reducer 的特殊之处：
# 1. 新消息会追加到列表末尾
# 2. 如果新消息的 id 与已有消息相同，则替换（用于编辑）
```

示例：

```python
import os

os.environ.setdefault("HTTPS_PROXY", "http://127.0.0.1:7890")

from langchain_core.messages import SystemMessage, HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.graph import MessagesState, StateGraph

llm = ChatOpenAI(
    # model="deepseek-ai/deepseek-v4-pro",
    # model="z-ai/glm-5.1",
    # model="google/gemma-4-31b-it",
    model="qwen/qwen3.5-122b-a10b",
    api_key=os.getenv("NVIDIA_API_KEY"),
    base_url=os.getenv("NVIDIA_BASE_URL"),
    temperature=0,
)

# 节点
def chatbot(state: MessagesState) -> dict:
    """调用 LLM 生成回复"""
    response = llm.invoke([SystemMessage(content="你是一个友好的 AI 助手，回答问题简洁有趣。")] + state["messages"])
    return {"messages": response}   # add_messages reducer 自动追加

# 构建图
graph = StateGraph(MessagesState)
graph.add_node("chatbot", chatbot)
graph.set_entry_point("chatbot")
graph.set_finish_point("chatbot")

app = graph.compile()


if __name__ == "__main__":
    result = app.invoke({
        "messages": [HumanMessage(content="一句话简单介绍 Rust 语言")]
    })
    print(result["messages"][-1].content)

    result = app.invoke({
        "messages": [
            HumanMessage(content="Rust 的创始人是谁？"),
            result["messages"][-1],  # 上一轮的回复
            HumanMessage("他还有什么贡献？")
        ]
    })
    print(result["messages"][-1].content)
```



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



`add_conditional_edges` 参数说明：

```python
workflow.add_conditional_edges(
	source,          # str：从哪个节点出发
    path,            # callable：路由函数，返回目标节点名称
    path_map,        # dict：可选，{返回值：目标节点名} 的映射
)
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

没有持久化，图每次 invoke 都是独立的。加上持久化后：

- **多轮对话**：Agent 记住之前的消息
- **中断恢复**：程序崩溃后可恢复执行
- **状态回溯**：可查看历史状态



### 4.1.1 `InMemorySaver`

开发阶段使用内存持久化：

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



### 4.1.2 会话隔离

```python
# 不同的 thread_id 完全隔离
config_a = {"configurable": {"thread_id": "user-A"}}
config_b = {"configurable": {"thread_id": "user-B"}}

app.invoke({"messages": ["A的第一条"]}, config_a)
app.invoke({"messages": ["B的第一条"]}, config_b)

result_a = app.invoke({"messages": []}, config_a)
result_b = app.invoke({"messages": []}, config_b)

print(result_a["messages"])  # ["A的第一条", "收到第 2 条消息"]
print(result_b["messages"])  # ["B的第一条", "收到第 2 条消息"]
```



### 4.1.3 状态历史回溯

```python
# 获取某个 thread 的所有历史状态
history = list(app.get_state_history(config))

for state in history:
    print(f"步骤 {state.metadata.get('step', '?')}: {state.values}")
```



### 4.1.4 生产级别持久化

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

**三种 Stream 模式**:

| 模式         | 输出内容             | 适用场景           |
| ------------ | -------------------- | ------------------ |
| `"values"`   | 每步后的**完整状态** | 调试、查看状态变化 |
| `"updates"`  | 每步的**增量更新**   | 监控节点输出       |
| `"messages"` | **token 级流式**     | 前端逐字显示       |



### 4.2.1 stream() 方法

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

### 4.3.1 场景

某些决策需要人工确认，例如：

- 金融交易：大额转账前需要确认
- 内容发布：自动生成的文章需要审核
- 工具调用：删除操作需要人工授权



### 4.3.2 实现原理

LangGraph 用 `interrupt()` 暂停执行，用 `Command(resume=)` 恢复

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/langgraph-HITL-diagram.png)



### 4.3.3 应用示例

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



## 4.4 ToolNode 工具执行节点

### 4.4.1 create_agent 手动实现 

用 ToolNode 和 tools_conditions，模拟 create_agent 的实现原理

```python
import os

from langchain_core.messages import HumanMessage
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.constants import END
from langgraph.graph import MessagesState, StateGraph
from langgraph.prebuilt import ToolNode, tools_condition


# 1. 定义工具
@tool
def add(a: int, b: int) -> int:
    """两个数相加"""
    return a + b

@tool
def multiply(a: int, b: int) -> int:
    """两个数相乘"""
    return a * b

tools = [
    add,
    multiply,
]

# 2. LLM with tools
llm = ChatOpenAI(
    model="qwen/qwen3.5-122b-a10b",
    api_key=os.getenv("NVIDIA_API_KEY"),
    base_url=os.getenv("NVIDIA_BASE_URL"),
    temperature=0,
)
llm_with_tools = llm.bind_tools(tools)

# 3. 定义节点
## 3.1 大模型调用节点
def call_llm_node(state: MessagesState) -> dict:
    response = llm_with_tools.invoke(state["messages"])
    return {"messages": response}

## 3.2 工具节点
tool_node = ToolNode(tools)

# 4. 构建图
graph = StateGraph(MessagesState)

## 4.1 增加节点
graph.add_node("agent", call_llm_node)
graph.add_node("tools", tool_node)

## 4.2 入口边
graph.set_entry_point("agent")

## 4.3 条件边: 有 tool_calls -> tools，没有 -> END
graph.add_conditional_edges(
    "agent",
    tools_condition,  # 预构建的路由函数
    {
        "tools": "tools",
        "__end__": END,
    }
)

## 4.4 工具执行后返回 agent
graph.add_edge("tools", "agent")

## 4.5 编译
app = graph.compile()


if __name__ == "__main__":
    result = app.invoke({
        "messages": [HumanMessage(content="计算 (23 + 12) * 4")]
    })

    for msg in result["messages"]:
        msg_type = msg.__class__.__name__
        content = msg.content[:100] if msg.content else str(getattr(msg, "tool_calls", ""))
        print(f"[{msg_type}]: {content}")
```



### 4.4.2 tool_conditions 详解

tool_conditions 是一个预构建的路由函数，实现逻辑如下：

```python
def tools_condition(state):
    last_message = state["messages"][-1]
    if hasattr(last_message, "tool_calls") and last_message.tool_calls:
        return "tools"
    return "__end__"
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



## 6.4 Multi-Agent

| 特性       | Supervisor 模式         | Fan-out/Fan-in 模式   |
| :--------- | :---------------------- | :-------------------- |
| 执行方式   | 串行，逐个 Worker       | 并行，同时多个 Worker |
| 路由决策   | 动态决策（LLM 判断）    | 固定派发（同时触发）  |
| 适用场景   | 复杂多步骤任务          | 独立子任务并行        |
| 代码复杂度 | 高（需要 Command 路由） | 低（Send API 简单）   |



### 6.4.1 Supervisor 串行模式

```python
import os
import sys
from typing import TypedDict, Annotated, Literal, Any

from langchain_core.messages import BaseMessage, HumanMessage, SystemMessage, AIMessage
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.graph import add_messages, StateGraph
from langgraph.types import Command
from pydantic import BaseModel, Field

llm = ChatOpenAI(
    model="qwen/qwen3.5-122b-a10b",
    api_key=os.getenv("NVIDIA_API_KEY"),
    base_url=os.getenv("NVIDIA_BASE_URL"),
    temperature=0,
)


class AgentState(TypedDict):
    messages: Annotated[list[BaseMessage], add_messages]
    next: str
    task_results: dict


WORKERS = ["researcher", "coder", "reviewer"]
class RouterDecision(BaseModel):
    next: Literal["researcher", "coder", "reviewer", "FINISH"] = Field(description="下一个要执行的 Worker名称")
    reasoning: str = Field(description="选择该 Worker 的理由")

# 给 LLM 绑定结构化输出格式
llm_router = llm.with_structured_output(RouterDecision)


@tool
def search_knowledge_base(query: str) -> str:
    """
    检索知识库，返回相关文档片段
    Args:
      - query: 搜索关键词
    """

    # 模拟知识库检索（生产环境替换为 Chroma / BM25 混合检索）
    knowledge = {
        "python": "Python 是一种解释型高级编程语言，由 Guido van Rossum 于 1991 年创建。",
        "排序": "常用排序算法：冒泡排序 O(n²)、快速排序 O(n log n)、归并排序 O(n log n)。",
        "异步": "Python 异步编程使用 asyncio 库，async/await 语法，适用于 I/O 密集型任务。",
        "agent": "Agent 是一种能够感知环境、做出决策并执行行动的 AI 系统。",
        "langgraph": "LangGraph 是 LangChain 团队开发的 Agent 编排框架，基于 StateGraph。",
        "default": f"未找到 '{query}' 的直接匹配，建议补充相关文档。"
    }

    # 简单的关键词匹配
    for keyword, content in knowledge.items():
        if keyword.lower() in query.lower():
            return f"[知识库检索结果] {content}"

    return knowledge["default"]

@tool
def execute_code(code: str) -> str:
    """
    执行 Python 代码片段，返回执行结果
    Args:
      - code: Python 代码片段
    """

    # 安全沙箱 (生产环境需要更严格隔离，如 Docker)
    import io as _io
    import traceback

    # 捕获标准输出
    stdout_capture = _io.StringIO()
    old_stdout = sys.stdout
    sys.stdout = stdout_capture
    result = ""
    try:
        # 创建独立的执行环境，避免污染全局命名空间
        exec_globals: dict[str, Any] = {}
        exec(code, exec_globals)
        result = stdout_capture.getvalue() or "[代码执行成功，无输出]"
    except:
        result = f"[错误信息]\n{traceback.format_exc()}"
    finally:
        sys.stdout = old_stdout
    return result

@tool
def review_content(content: str) -> str:
    """
    审查内容质量，返回评审意见
    Args:
      - content: 需要审查的代码或文档
    """
    # 模拟审查逻辑，检查常见问题
    issues = []
    if "TODO" in content or "pass" in content.lower():
        issues.append("存在未完成的 TODO 或空实现")
    if len(content) < 50:
        issues.append("内容过于简短，建议补充细节")
    if not issues:
        return "[审查结果] PASS: 内容质量良好，逻辑清晰，无明显问题。"
    return f"[审查结果] 发现 {len(issues)} 个问题：\n" + "\n".join(f"  - {i}" for i in issues)

######################
def researcher_node(state: AgentState) -> dict:
    print("\n[Researcher] 开始工作...")

    # llm
    worker_llm = llm.bind_tools([search_knowledge_base])

    # 提取用户原始需求
    last_human = next(
        (m.content for m in reversed(state["messages"]) if isinstance(m, HumanMessage)),
        "请检索相关知识"
    )

    # 系统提示
    system_prompt = (
        "你是一个专业的知识检索员（Researcher）。"
        "你的工作是使用 search_knowledge_base 工具搜索相关信息，"
        "并整理成清晰的摘要返回给团队。"
    )

    # 调用大模型
    response = worker_llm.invoke([
        SystemMessage(content=system_prompt),
        HumanMessage(content=f"请检索以下任务所需的知识: {last_human}"),
    ])

    # 如果调用了工具，执行工具并收集结果
    tool_results = []
    if hasattr(response, "tool_calls") and response.tool_calls:
        for tc in response.tool_calls:
            if tc["name"] == "search_knowledge_base":
                # 调用实际工具函数
                result = search_knowledge_base.invoke(tc["args"])
                tool_results.append(result)
                print(f"  [Tool] search_knowledge_base({tc['args']}) -> {result[:60]}...")

    # 优先使用工具结果，否则使用 LLM 的文本回复
    result_text = "\n".join(tool_results) if  tool_results else response.content
    print(f"  [Result] {result_text[:100]}...")

    # 返回更新
    return {
        "messages": [AIMessage(content=f"[Researcher 输出]\n{result_text}")],
        "task_results": {**state.get("task_results", {}), "researcher": result_text},
    }

def coder_node(state: AgentState) -> dict:
    print("\n[Coder] 开始工作...")
    worker_llm = llm.bind_tools([execute_code])

    # 提取用户原始需求
    last_human = next(
        (m.content for m in reversed(state["messages"]) if isinstance(m, HumanMessage)),
        "请生成代码"
    )

    # 系统提示
    system_prompt = (
        "你是一个专业的 Python 开发者（Coder）。"
        "你的工作是根据需求编写高质量的 Python 代码，"
        "必要时使用 execute_code 工具验证代码逻辑。"
        "只输出代码和简短说明，不要废话。"
    )

    # 调用大模型
    response = worker_llm.invoke([
        SystemMessage(content=system_prompt),
        HumanMessage(content=f"请完成以下编程任务: {last_human}"),
    ])

    # 如果调用了工具，执行工具并收集结果
    tool_results = []
    if hasattr(response, "tool_calls") and response.tool_calls:
        for tc in response.tool_calls:
            if tc["name"] == "execute_code":
                # 调用实际工具函数
                result = execute_code.invoke(tc["args"])
                tool_results.append(result)
                print(f"  [Tool] execute_code({tc['args']}) -> {result[:60]}...")

    # 合并代码输出和执行结果
    result_text = response.content
    if tool_results:
        result_text += "\n[执行验证]\n" + "\n".join(tool_results)
    print(f"  [Result] {result_text[:100]}...")

    # 返回更新
    return {
        "messages": [AIMessage(content=f"[Coder 输出]\n{result_text}")],
        "task_results": {**state.get("task_results", {}), "coder": result_text},
    }

def reviewer_node(state: AgentState) -> dict:
    print("\n[Reviewer] 开始工作...")
    worker_llm = llm.bind_tools([review_content])

    # 收集所有 Worker 的输出作为生茶内容
    task_results = state.get("task_results", {})
    content_to_review = "\n\n".join(
        f"=== {k.upper()} 输出 ===\n{v}"
        for k, v in task_results.items()
    ) or "(暂无其它 Worker 的输出，请审查整体任务完成情况)"

    # 系统提示
    system_prompt = (
        "你是一个严格的代码和内容审查员（Reviewer）。"
        "使用 review_content 工具对以下内容进行质量审查，"
        "指出问题并给出改进建议。"
    )

    # 调用大模型
    response = worker_llm.invoke([
        SystemMessage(content=system_prompt),
        HumanMessage(content=f"请审查以下内容: \n\n{content_to_review}"),
    ])

    # 执行审查工具
    tool_results = []
    if hasattr(response, "tool_calls") and response.tool_calls:
        for tc in response.tool_calls:
            if tc["name"] == "review_content":
                # 调用实际工具函数
                result = review_content.invoke(tc["args"])
                tool_results.append(result)
                print(f"  [Tool] review_content({tc['args']}) -> {result[:60]}...")

    # 合并代码输出和执行结果
    result_text = response.content
    if tool_results:
        result_text += "\n[执行验证]\n" + "\n".join(tool_results)
    print(f"  [Result] {result_text[:100]}...")

    # 返回更新
    return {
        "messages": [AIMessage(content=f"[Reviewer 输出]\n{result_text}")],
        "task_results": {**state.get("task_results", {}), "reviewer": result_text},
    }

#####
SUPERVISOR_SYSTEM_PROMPT = """
你是一个任务调度 Supervisor。

你手下有三个专业 Worker：
- researcher：负责搜索知识库，获取背景信息
- coder：负责编写和执行 Python 代码
- reviewer：负责审查代码和输出的质量

你的工作流程：
1. 接收用户任务
2. 判断需要哪个 Worker 来处理下一步
3. 当所有必要的工作都完成后，返回 FINISH

决策原则：
- 如果任务需要背景知识 -> 先派 researcher
- 如果任务需要代码实现 -> 派 coder
- 如果已有代码或内容需要审查 -> 派 reviewer
- 如果任务已完整完成 -> 返回 FINISH

已完成的工作会在消息历史中体现，避免重复派遣同一个 Worker（除非有充分理由）。
"""

def  supervisor_node(state: AgentState) -> Command[Literal["researcher", "coder", "reviewer", "__end__"]]:
    print(f"\n[Supervisor] 分析任务，已完成： {list(state.get('task_results', {}).keys())}...")

    # 组装消息
    messages = [
        SystemMessage(content=SUPERVISOR_SYSTEM_PROMPT),
    ] + list(state["messages"])

    # 调用结构化输出，避免 LLM 输出格式不稳定
    try:
        decision: RouterDecision = llm_router.invoke(messages)
        next_worker = decision.next
        reasoning = decision.reasoning
    except Exception as e:
        print(f"  [WARN] 结构化输出失败，默认 FINISH: {e}")
        next_worker = "FINISH"
        reasoning = "解析失败，安全退出"
    print(f"  [Decision] -> {next_worker} (理由: {reasoning[:60]})")

    return Command(
        goto="__end__" if next_worker == "FINISH" else next_worker,
        update={"next": next_worker},
    )

###########
def build_graph(max_iterations: int = 10) -> Any:
    graph = StateGraph(AgentState)

    graph.add_node("supervisor", supervisor_node)
    graph.add_node("researcher", researcher_node)
    graph.add_node("coder", coder_node)
    graph.add_node("reviewer", reviewer_node)

    graph.set_entry_point("supervisor")
    graph.add_edge("researcher", "supervisor")
    graph.add_edge("coder", "supervisor")
    graph.add_edge("reviewer", "supervisor")

    return graph.compile()


def main():
    print("=" * 80)
    print("LangGraph Multi-Agent Supervisor Demo")
    print("=" * 80)

    # 构建图
    graph = build_graph()

    # 演示任务列表
    tasks = [
        "用 Python 写一个快速排序函数，并做代码审查",
        "查找 Python 异步编程的最佳实践，并给出示例代码",
    ]

    # 遍历任务
    for i, task in enumerate(tasks, 1):
        print(f"\n{'=' * 70}")
        print(f"\n[Task] {i}. {task}")
        print("=" * 70)

        initial_state: AgentState = {
            "messages": [HumanMessage(content=task)],
            "next": "",
            "task_results": {},
        }

        try:
            final_state = graph.invoke(
                initial_state,
                config={"recursion_limit": 10},
            )
            print(f"\n[RESULT] 任务完成！")

            # 显示执行链路 (Worker 执行顺序)
            print(f"执行链路: {' -> '.join(final_state.get('task_results', {}).keys())}")
            print("\n各 Worker 输出摘要: ")
            for worker, result in final_state.get("task_results", {}).items():
                print(f"  [{worker.upper()}] {result[:120]}...")
        except Exception as e:
            print(f"\n[ERROR] 任务执行失败: {e}")
            import traceback
            traceback.print_exc()

    print("=" * 80)
    print("[Done] LangGraph Multi-Agent Supervisor Demo")
    print("=" * 80)

if __name__ == "__main__":
    main()
```



### 6.4.2 Fan-out/Fan-in 模式

| 能力             | 描述                                           |
| :--------------- | :--------------------------------------------- |
| **Fan-out 模式** | 使用 Send API 同时触发多个 Worker 并行执行     |
| **Fan-in 模式**  | 使用 operator.add reducer 收集所有 Worker 结果 |
| **性能对比**     | 理解并行 vs 串行的执行时间差异                 |
| **状态合并**     | 掌握并发写入时的状态防覆盖机制                 |



```python
import operator
import os
import time
from typing import TypedDict, Annotated

from langchain_core.messages import BaseMessage, HumanMessage, SystemMessage, AIMessage
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.constants import START, END
from langgraph.graph import add_messages, StateGraph
from langgraph.types import Send


# llm = ChatOpenAI(
#     model="qwen/qwen3.5-122b-a10b",
#     api_key=os.getenv("NVIDIA_API_KEY"),
#     base_url=os.getenv("NVIDIA_BASE_URL"),
#     temperature=0,
# )

llm = ChatOpenAI(
    model="qwen3-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.environ["DASHSCOPE_BASE_URL"],
    temperature=0,
)

##### State ##############################
class SubTaskResult(TypedDict):
    worker: str       # Worker 名称标识
    task: str         # 接收到的子任务描述
    result: str       # Worker 执行结果内容
    elapsed: float    # 执行耗时 (s)

class ParallelState(TypedDict):
    messages: Annotated[list[BaseMessage], add_messages]
    task: str
    sub_results: Annotated[list[str], operator.add]   # Fan-in 汇总结果
    summary: str                                      # aggregator 生成的最终汇总

class WorkerInput(TypedDict):
    task: str
    worker_name: str

##### State ##############################
@tool
def search_docs(query: str) -> str:
    """搜索技术文档，返回相关片段"""
    import time as _time
    _time.sleep(1)  # 模拟 I/O 延迟
    docs = {
        "python": "Python 官方文档：https://docs.python.org, 支持 asyncio / dataclass / typing",
        "fastapi": "FastAPI 文档：https://fastapi.tiangolo.com, 基于 Pydantic 和 Starlette",
        "langgraph": "LangGraph 文档：https://langchain-ai.github.io/langgraph, 支持 StateGraph + Checkpointer",
        "default": "未找到精确匹配，建议查阅官方文档。"
    }
    for k, v in docs.items():
        if k.lower() in query.lower():
            return f"[文档检索] {v}"
    return docs["default"]

@tool
def generate_code(requirement: str) -> str:
    """根据需求描述，生成 Python 代码框架"""
    import time as _time
    _time.sleep(1)
    return f"""# 根据需求自动生成
# 需求：{requirement}
def solution():
    \"\"\"自动生成代码框架\"\"\"
    # TODO: 实现核心逻辑
    # 1. 初始化
    # 2. 执行业务逻辑
    # 3. 返回结果
    pass
    
if __name__ == '__main__':
    result = solution()
    print(f'Result: {{result}}')    
"""

##### Fan-out Worker ##############################
def researcher_parallel(state: ParallelState) -> dict:
    print(f"  [Researcher] 并行启动，任务：{state['task'][:40]}...")
    start = time.time()
    worker_llm = llm.bind_tools([search_docs])
    response = worker_llm.invoke([
        SystemMessage(content="你是一个文档检索专家，使用 search_docs 工具搜索相关文档，整理为简洁摘要"),
        HumanMessage(content=f"请检索以下任务所需的技术文档：{state['task']}"),
    ])

    tool_results = []
    if hasattr(response, "tool_calls") and response.tool_calls:
        for tc in response.tool_calls:
            if tc["name"] == "search_docs":
                result = search_docs.invoke(tc["args"])
                tool_results.append(result)
    result_text = response.content
    if tool_results:
        result_text += "\n".join(tool_results)

    elapsed = time.time() - start
    print(f"  [Researcher] 完成，耗时 {elapsed:.2f}s")
    return {
        "messages": [AIMessage(content=f"[Researcher] {result_text}")],
        "sub_results": [SubTaskResult(
            worker="researcher",
            task=state["task"],
            result=result_text,
            elapsed=elapsed
        )],
    }

def coder_parallel(state: ParallelState) -> dict:
    print(f"  [Coder] 并行启动，任务： {state['task'][:40]}...")
    start = time.time()
    woker_llm = llm.bind_tools([generate_code])
    response = woker_llm.invoke([
        SystemMessage(content="你是一个 Python 开发专家。使用 generate_code 工具生成代码框架，并补充说明"),
        HumanMessage(content=f"请为以下任务生成代码框架：{state['task']}"),
    ])

    tool_results = []
    if hasattr(response, "tool_calls") and response.tool_calls:
        for tc in response.tool_calls:
            if tc["name"] == "generate_code":
                result = generate_code.invoke(tc["args"])
                tool_results.append(result)
    result_text = response.content
    if tool_results:
        result_text += "\n".join(tool_results)
    elapsed = time.time() - start

    print(f"  [Coder] 完成，耗时 {elapsed:.2f}s")
    return {
        "messages": [AIMessage(content=f"[Coder] {result_text}")],
        "sub_results": [SubTaskResult(
            worker="coder",
            task=state["task"],
            result=result_text,
            elapsed=elapsed
        )]
    }

##### Fan-in 汇总 ##############################
def aggregator_node(state: ParallelState) -> dict:
    sub_results = state.get("sub_results", [])
    print(f"\n[Aggregator] 收到 {len(sub_results)} 个 Worker 的结果，开始汇总...")

    combined = "\n\n".join(
        f"=== {r['worker'].upper()} (耗时 {r['elapsed']:.2f}s) ===\n{r['result']}"
        for r in sub_results
    )

    response = llm.invoke([
        SystemMessage(content=(
            "你是一个技术文档整合专家。"
            "请将以下多个 Worker 的输出整合为一份清晰的技术报告，"
            "格式为：概述 + 关键发现 + 代码示例 + 建议"
        )),
        HumanMessage(content=f"任务: {state['task']}\n\n各 worker 输出: \n\n{combined}"),
    ])

    summary = response.content
    print(f"[Aggregator] 汇总完成，摘要：{summary[:80]}...")
    return {
        "messages": [AIMessage(content=f"[汇总报告]\n{summary}")],
        "summary": summary,
    }

##### Fan-out 路由 ##############################
def supervisor_fan_out(state: ParallelState) -> list[Send]:
    print(f"\n[Supervisor] 任务 Fan-out，并行派发给 researcher + coder")
    return [
        Send("researcher", {"task": state["task"], "messages": state["messages"], "sub_results": [], "summary": ""}),
        Send("coder", {"task": state["task"], "messages": state["messages"], "sub_results": [], "summary": ""}),
    ]

def start_node(state: ParallelState) -> dict:
    print(f"\n[START] 接收任务： {state['task'][:60]}...")
    return {"sub_results": [], "summary": ""}

##### 构建并行图 ##############################
def build_parallel_graph():
    graph = StateGraph(ParallelState)
    graph.add_node("start_node", start_node)
    graph.add_node("researcher", researcher_parallel)
    graph.add_node("coder", coder_parallel)
    graph.add_node("aggregator", aggregator_node)

    # 开始
    graph.add_edge(START, "start_node")

    # Fan-out 分发
    graph.add_conditional_edges(
        "start_node",
        supervisor_fan_out,
        ["researcher", "coder"],
    )

    # Fan-in 聚合
    graph.add_edge("researcher", "aggregator")
    graph.add_edge("coder", "aggregator")

    # 结束
    graph.add_edge("aggregator", END)

    return graph.compile()


##### 演示 ##############################
def main():
    print("=" * 70)
    print("LangGraph Fan-out/Fan-in 并行 Agent")
    print("=" * 70)

    graph = build_parallel_graph()
    tasks = [
        "用 Python 实现一个基于 FastAPI 的 REST API，包含 CRUD 操作",
        "用 LangGraph 构建一个支持多轮对话的智能助手",
    ]

    for i, task in enumerate(tasks):
        print(f"\n{'=' * 70}")
        print(f"[Task {i}] {task}")
        print(f"{'=' * 70}")

        print("\n[PARALLEL] 并行执行 (researcher + coder 同时工作) ...")
        start_parallel = time.time()
        initial_state: ParallelState = {
            "task": task,
            "messages": [HumanMessage(content=task)],
            "sub_results": [],
            "summary": "",
        }

        try:
            final_result = graph.invoke(
                initial_state,
                config={"recursion_limit": 20}
            )

            parallel_elapsed = time.time() - start_parallel
            print(f"\n[PARALLEL RESULT]")
            print(f"  总耗时：{parallel_elapsed:.2f}s")
            print(f"  收集到 {len(final_result.get("sub_results", []))} 个 Worker 结果")
            print(f"  汇总摘要：{final_result.get('summary', '')[:150]}...")

            for r in final_result.get("sub_results", []):
                print(f"    - {r['worker'].upper()} ({r['elapsed']:.2f}s)")

        except Exception as e:
            print(f"[ERROR] 并行任务执行失败：{e}")
            import traceback
            traceback.print_exc()
            parallel_elapsed = 999

        print(f"  并行执行耗时：{parallel_elapsed:.2f}s")

if __name__ == "__main__":
    main()
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



# 9. 总结

## 9.1 生态全景

```
                    ┌─────────────────────────────┐
                    │     LangChain 生态全景        │
                    └──────────────┬──────────────┘
                                   │
            ┌──────────────────────┼─────────────────────┐
            │                      │                     │
    ┌───────▼────────┐    ┌────────▼───────┐    ┌────────▼────────┐
    │    基础层       │    │     编排层      │    │     图编排层     │
    │                │    │                │    │                 │
    │ • ChatModel    │    │ • LCEL 管道     │    │ • StateGraph    │
    │ • PromptTemplate│───▶│ • Runnable    │    │ • Nodes & Edges │
    │ • OutputParser │    │ • Parallel     │───▶│ • Conditional   │
    │ • Tools        │    │ • Passthrough  │    │ • Persistence   │
    │ • Embeddings   │    │ • Lambda       │    │ • HITL          │
    │ • VectorStore  │    │ • Stream/Batch │    │ • Multi-Agent   │
    │ • Retriever    │    │                │    │ • Streaming     │
    └────────────────┘    └────────────────┘    └────────────────┘
```



## 9.2 LangChain

LangChain 的核心抽象是 **Chain(链)**，以流水线形式串联单向处理步骤，适配 RAG 等简单单向流程，复杂编排可通过 SequentialChain、RouterChain 实现。但链式设计过于简单，真实Agent场景包含条件分支、循环、动态路由等复杂控制流，用Chain实现十分勉强。

理解LangChain的价值，需要把它拆成两层来看：

- 第一层为组件层：LangChain 提供各类开箱即用模块包括各大LLM统一接口、文档加载器、文本切分器、Embedding封装、向量数据库集成、输出解析器等。这些是通用基础设施，不依赖编排框架，即便使用 LangGraph 编排，底层也大多复用 LangChain 的组件，价值持久
- 第二层为编排层：即Chain、Agent等抽象，也是 LangChain 饱受争议的部分。早期 AgentExecutor 将执行循环封装成黑箱，简单场景易用，但定制执行逻辑(如添加审批、失败降级)难以介入;后续LCEL用管道符|组合链，写法更优雅，本质仍为线性组合，对复杂控制流的支持依旧有限。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/langchain-vs-langgraph-layer.png)



## 9.3 LangGraph

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



# 10. 附录

## 10.1 可视化图

LangGraph 可以生成 Mermaid 图来可视化工作流:

```python
# Jupyter Notebook
from IPython.display import Image, display
display(Image(app.get_graph().draw_mermaid_png()))

# 直接生成 Mermaid 文本，然后复制到 Mermaid Live Editor 在线查看
print(app.get_graph().draw_mermaid())

# 生成复杂图可视化
graph_png = app.get_graph().draw_mermaid_png(
    curve_style="linear",  # 线性边，更清晰
    node_colors={"start": "#ffd700", "end": "#ff6347", "error_backoff": "#ff4444"}
)
with open("workflow_graph.png", "wb") as f:
    f.write(graph_png)
```



## 10.2 集成 Skills 实现 SQL Agent

### 10.2.1 为何选择 Skills 模式

**传统 SQL Agent 的局限性**：

在传统的 SQL Agent 架构中，我们通常需要在 System Prompt 中提供完整的 Database Schema。随着业务发展，当表数量扩展到数百张时，这种方式会带来显著问题：

- **Token 消耗巨大**：每次对话都携带大量无关的表结构，造成资源浪费。
- **幻觉风险增加**：过多的无关干扰信息会降低模型的推理准确性。
- **维护困难**：所有业务线的知识紧密耦合，难以独立迭代。



**Skills 模式：基于渐进式披露的解决方案**：

Skills 模式基于**渐进式披露（Progressive Disclosure）**原则，将知识获取过程分层处理：

- **Agent 初始状态**：仅掌握有哪些“技能”（Skills）及其简要描述（Description），保持轻量级。
- **运行时加载**：当面对具体问题（如“查询库存”）时，Agent 主动调用工具（`load_skill`）加载该技能详细的上下文（Schema + Prompt）。
- **执行任务**：基于加载的精确上下文，执行具体的任务（如编写并执行 SQL）。



### 10.2.2 核心实现步骤

**步骤一：定义领域技能 (The Knowledge)**

将技能定义为字典结构，模拟从文件系统或数据库加载的过程。注意区分 `description`（供 Agent 决策选型使用）和 `content`（实际加载的详细上下文）。

```
SKILLS = {
    "sales_analytics": {
        "description": "Useful for analyzing sales revenue, trends...",
        "content": """... Table Schema: sales_data ..."""
    },
    "inventory_management": {
        "description": "Useful for checking stock levels...",
        "content": """... Table Schema: inventory_items ..."""
    }
}
```



**步骤二：实现核心工具 (The Capabilities)**

Agent 依赖两个关键工具来完成任务：

- `load_skill(skill_name)`: 在运行时动态加载指定技能的详情。
- `run_sql_query(query)`: 执行具体的 SQL 语句。



**步骤三：编排 Agent 逻辑 (The Brain)**

利用 LangGraph 构建 ReAct Agent。System Prompt 在此处起着关键作用，它指导 Agent 严格遵循 `Identify -> Load -> Query` 的标准作业程序（SOP）。

```
system_prompt = """
1. Identify the relevant skill.
2. Use 'load_skill' to get schema.
3. Write and execute SQL using 'run_sql_query'.
...
Do not guess table names. Always load the skill first.
"""
```



### 10.2.3 源码参考

**1、数据库初始化:**

```python
import os

import psycopg2
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "change_me")
DB_NAME = os.getenv("DB_NAME", "testdb")

def create_database():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            dbname="postgres",   # 通过默认 postgres 库创建新库
        )
        conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
        cur = conn.cursor()

        # 检查库是否存在
        cur.execute(f"SELECT 1 FROM pg_catalog.pg_database WHERE  datname = '{DB_NAME}'")
        exists = cur.fetchone()
        if not exists:
            print(f"Creating database {DB_NAME}...")
            cur.execute(f"CREATE DATABASE {DB_NAME}")
        else:
            print(f"Database {DB_NAME} already exists.")

        cur.close()
        conn.close()
    except Exception as e:
        print(f"Error creating database: {e}")

def create_tables_and_data():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASSWORD,
            dbname=DB_NAME,
        )
        cur = conn.cursor()

        print(f"Creating tbl_sales table...")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS tbl_sales (
                id SERIAL PRIMARY KEY,
                transaction_date DATE,
                product_id VARCHAR(50),
                amount DECIMAL(10,2),
                region VARCHAR(50)
            )
        """)

        print(f"Creating tbl_inventories table...")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS tbl_inventories (
                id SERIAL PRIMARY KEY,
                product_id VARCHAR(50),
                product_name VARCHAR(100),
                stock_count INTEGER,
                warehouse_location VARCHAR(50)
            )
        """)

        print("Inserting mock data...")
        cur.execute("TRUNCATE TABLE tbl_sales, tbl_inventories")

        sales_data = [
            ('2026-04-01', 'P001', 95.00, 'South'),
            ('2026-04-02', 'P002', 51.03, 'West'),
            ('2026-04-03', 'P003', 32.67, 'Est'),
            ('2026-04-04', 'P004', 21.90, 'South'),
            ('2026-04-05', 'P005', 90.10, 'North'),
            ('2026-04-06', 'P006', 56.23, 'Southwest'),
        ]
        cur.executemany(
        "INSERT INTO tbl_sales (transaction_date, product_id, amount, region) VALUES (%s, %s, %s, %s)",
            sales_data
        )

        inventory_data = [
            ('P001', 'Mouse', 50, 'Warehouse A'),
            ('P002', 'Keyboard', 50, 'Warehouse B'),
            ('P003', 'Cable', 200, 'Warehouse C'),
            ('P004', 'Router', 10, 'Warehouse D'),
            ('P005', 'Monitor', 20, 'Warehouse E'),
            ('P006', 'Switch', 25, 'Warehouse F'),
        ]
        cur.executemany(
            "INSERT INTO tbl_inventories (product_id, product_name, stock_count, warehouse_location) VALUES (%s, %s, %s, %s)",
            inventory_data
        )

        conn.commit()
        cur.close()
        conn.close()
        print("Database setup complete.")

    except Exception as e:
        print(f"Error creating tables and data: {e}")

if __name__ == "__main__":
    create_database()
    create_tables_and_data()
```



**2、Agent 主程序：**

```python
import os
from typing import Dict

from dotenv import load_dotenv
from langchain_community.utilities import SQLDatabase
from langchain_core.messages import SystemMessage, HumanMessage, BaseMessage, AIMessage
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langgraph.constants import START
from langgraph.graph import MessagesState, StateGraph
from langgraph.prebuilt import ToolNode, tools_condition

load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "change_me")
DB_NAME = os.getenv("DB_NAME", "testdb")
DB_URI = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# --- Database Setup ---
db = SQLDatabase.from_uri(DB_URI)

# ---  Skills Definition ---
SKILLS: Dict[str, Dict[str, str]] = {
   "sales_analytics": {
     "description": "Useful for analyzing sales revenue, trends, and regional performance.",
     "content": """
You are a Sales Analytics Expert.
You have access to the 'sales_data' table.
Table Schema:
- id: integer (primary key)
- transaction_date: date
- product_id: varchar(50)
- amount: decimal(10, 2)
- region: varchar(50)

Common queries:
- Total revenue: SUM(amount)
- Revenue by region: GROUP BY region
- Sales trend: GROUP BY transaction_date
"""
  },
   "inventory_management": {
     "description": "Useful for checking stock levels, product locations, and warehouse management.",
     "content": """
You are an Inventory Management Expert.
You have access to the 'inventory_items' table.
Table Schema:
- id: integer (primary key)
- product_id: varchar(50)
- product_name: varchar(100)
- stock_count: integer
- warehouse_location: varchar(50)

Common queries:
- Check stock: WHERE product_name = '...'
- Low stock: WHERE stock_count < threshold
"""
   }
}

# -- Tools ---
@tool
def load_skills(skill_name: str) -> str:
    """
    Load the detailed prompt and schema for a specific skill.
    Available skills:
    - sales_analytics: For sales, revenue, and transaction analysis.
    - inventory_management: For stock, products, and warehouse queries.
    """
    skill = SKILLS.get(skill_name)
    if not skill:
        return f"Error: Skill {skill_name} not found. Available skills: {list(SKILLS.keys())}"
    return skill["content"]

@tool
def run_sql_query(query: str) -> str:
    """
    Execute a SQL query against the database.
    Only use this tool AFTER loading the appropriate skill to understand the schema.
    """
    try:
        return db.run(query)
    except Exception as e:
        return f"Error executing SQL: {e}"

@tool
def list_tables() -> str:
    """List all available tables in the database."""
    return str(db.get_usable_table_names())

tools = [load_skills, run_sql_query, list_tables]

# --- Agent Setup ---
llm = ChatOpenAI(
    model="qwen3-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.environ["DASHSCOPE_BASE_URL"],
    temperature=0,
)

llm_with_tools = llm.bind_tools(tools)

# --- Graph Definition ---
class AgentState(MessagesState):
    pass

def agent_node(state: AgentState):
    messages = state["messages"]
    response = llm_with_tools.invoke(messages)
    return {"messages": [response]}

workflow = StateGraph(AgentState)

workflow.add_node("agent", agent_node)
workflow.add_node("tools", ToolNode(tools))

workflow.add_edge(START, "agent")
workflow.add_conditional_edges("agent", tools_condition)
workflow.add_edge("tools", "agent")

app = workflow.compile()

# --- Main Execution ---
if __name__ == "__main__":
    system_prompt = """You are a helpful SQL Assistant.
You have access to specialized skills that contain database schemas and domain knowledge.
To answer a user's question:
1. Identify the relevant skill (sales_analytics or inventory_management).
2. Use the 'load_skill' tool to get the schema and instructions.
3. Based on the loaded skill, write and execute a SQL query using 'run_sql_query'.
4. Answer the user's question based on the query results.

Do not guess table names. Always load the skill first.
"""
    print("SQL Assistant initialized. Type 'quit' to exit.")
    print("-" * 50)

    messages: list[BaseMessage] = [SystemMessage(content=system_prompt)]

    # Pre-warm connection check
    try:
        print(f"Connected to database: {DB_URI.split('@')[-1]}")
    except Exception as e:
        print(f"Error connecting to database: {e}")
        exit(1)

    while True:
        try:
            user_input = input("User: ")
            if user_input.lower() in ["quit", "exit"]:
                break

            messages.append(HumanMessage(content=user_input))

            # Stream the execution
            print("Agent: ", end="", flush=True)
            final_response = None

            for event in app.stream({"messages": messages}, stream_mode="values"):
                last_message = event["messages"][-1]

                # Update our message history with the latest state
                pass

            # After stream finishes, the last state has the final answer
            final_state = app.invoke({"messages": messages})
            last_msg = final_state["messages"][-1]

            if isinstance(last_msg, AIMessage):
                print(last_msg.content)
                messages = final_state["messages"]  # Update history

            print("-" * 50)
        except Exception as e:
            print(f"\nError: {e}")
            break
```



## 10.3 错误重试与降级：让Agent学会"自救"

生产环境的API调用，就像在城市高峰期打车——**不是每次都能成功，但用户不能因此 stranded**。

### **10.3.1 错误分类处理策略**

不是所有错误都一样对待。LangGraph官方建议的分层策略：

| 错误类型                             | 处理者   | 策略                     | 适用场景                 |
| :----------------------------------- | :------- | :----------------------- | :----------------------- |
| 瞬态错误（网络抖动、限流）           | 系统自动 | 指数退避重试             | 临时故障，重试通常能解决 |
| LLM可恢复错误（工具失败、解析错误）  | LLM自己  | 把错误喂给模型，让它重试 | 模型能看到错误并调整策略 |
| 需人工介入错误（信息缺失、指令不清） | 人类     | 中断等待`interrupt()`    | 需要用户提供额外信息     |
| 未知错误                             | 开发者   | 抛出异常，记录日志       | 需要排查的新问题         |



### **10.3.2 实战：三层防御体系**

```python
from deepagents import create_deep_agent
from langchain.agents.middleware import (
    ModelFallbackMiddleware,
    ModelRetryMiddleware,
    ToolRetryMiddleware,
)

agent = create_deep_agent(
    model="claude-sonnet-4",  # 主力模型
    middleware=[
        # 🛡️ 第一层：瞬态错误自动重试
        ModelRetryMiddleware(
            max_retries=3,
            backoff_factor=2.0,  # 指数退避：1s, 2s, 4s
            initial_delay=1.0,
            retry_on=(RateLimitError, TimeoutError, ConnectionError)
        ),
        
        # 🛡️ 第二层：主力模型挂了，自动降级
        ModelFallbackMiddleware(
            fallback_model="gpt-4.1-mini",  # 便宜且稳定的备胎
            fallback_on=(ServiceUnavailableError, AuthenticationError)
        ),
        
        # 🛡️ 第三层：特定工具的错误隔离
        ToolRetryMiddleware(
            max_retries=2,
            tools=["search", "fetch_url"],  # 只重试外部API工具
            retry_on=(TimeoutError, ConnectionError),
            # 本地文件操作不重试，因为重试也没用
        ),
    ],
)
```



**关键原则**：

- **只对瞬态错误重试**：文件读取失败重试100次也没用
- **降级要果断**：主模型挂了立刻切备胎，别让用户干等
- **Scope要精确**：ToolRetryMiddleware只绑定到特定工具，别一刀切



### **10.3.3 让LLM自己"反省"错误**

有些错误，喂给模型比直接重试更有效：

```python
from langgraph.types import Command

def execute_tool(state, config):
    try:
        result = risky_operation(state["tool_call"])
        return Command(update={"results": result}, goto="agent")
    except Exception as e:
        # 把错误信息丢给LLM，让它自己想办法
        return Command(
            update={"results": f"执行出错：{str(e)}。请尝试其他方法或询问用户。"},
            goto="agent"# 回到Agent节点，让LLM决定下一步
        )
```



## 10.4 **性能监控与Token成本：每一分钱都要算清楚**

### **10.4.1 LangSmith：你的Agent"黑匣子"**

LangSmith不只是调试工具，它是生产环境的**成本监控仪表盘**。

**它能自动追踪：**

- 📊 每次调用的Token消耗和成本
- ⏱️ 响应延迟和瓶颈定位
- 🔍 完整的调用链路（Trace）
- 💰 按模型、按用户、按功能的成本分解

```python
import os

# 只需配置环境变量，零代码侵入
os.environ["LANGCHAIN_TRACING_V2"] = "true"
os.environ["LANGCHAIN_PROJECT"] = "production-agent"
os.environ["LANGCHAIN_API_KEY"] = "your-api-key"

# 然后正常调用你的Agent，数据自动上报
response = agent.invoke({"messages": user_input})
```



### **10.4.2 成本优化的四大实战技巧**

根据LangSmith的数据反馈，你可以做这些优化：

**技巧1：设置Token天花板**

```python
# 防止递归或循环导致Token爆炸
config = {
    "configurable": {
        "thread_id": "user_123",
        "max_tokens": 4000,  # 单次调用上限
        "max_iterations": 10 # ReAct循环上限
    }
}
```

**技巧2：模型路由——该省省该花花**

```python
def smart_model_router(query: str):
    """简单问题用便宜模型，复杂问题用好模型"""
    if is_simple_question(query):  # 基于关键词或分类判断
        return "gpt-4.1-mini"# $0.15/M tokens
    else:
        return "claude-sonnet-4"# $3/M tokens，但质量高

# 成本可能降低80%，但用户体验不打折
```

**技巧3：缓存高频查询**

```python
from functools import lru_cache

@lru_cache(maxsize=1000)
def cached_embedding(text: str):
    """嵌入向量计算很贵，缓存能省一大笔"""
    return embedding_model.embed(text)
```

**技巧4：失败也消耗Token——要算清楚** 

很多开发者不知道：**即使API调用失败，可能已经消耗了Prompt Tokens**。LangSmith能帮你识别这种"隐形浪费"。



## 10.5 **并发控制与限流：别让Agent变成"洪水猛兽"**

### **10.5.1 理解LangGraph的并发模型**

LangGraph基于**Super-step（超级步）**执行模型：

- 同一step中没有依赖关系的节点并行执行
- 所有节点完成后才进入下一步
- 默认没有并发上限，但你可以控制



### **10.5.2 实战：限流配置**

```python
from langgraph.types import Send

# 控制并行度，防止把API打挂
config = {
    "max_concurrency": 5,  # 同时最多5个节点在执行
    "recursion_limit": 25# 防止无限循环，最多25个super-step
}

# Map-Reduce模式的动态分发
def orchestrator(state):
    tasks = state["tasks"]
    # 动态创建worker节点，但受max_concurrency限制
    return [Send("worker", {"task": t}) for t in tasks]

workflow.add_node("orchestrator", orchestrator)
workflow.add_node("worker", process_task)
```



### **10.5.3 生产级限流策略**

```python
import asyncio
from asyncio import Semaphore

# 全局信号量，控制整个应用的LLM调用频率
llm_semaphore = Semaphore(10)  # 最多10个并发LLM请求

async def rate_limited_llm_call(prompt):
    async with llm_semaphore:
        # 这里还可以加更精细的速率控制
        await asyncio.sleep(0.1)  # 100ms间隔，防止突发流量
        return await llm.ainvoke(prompt)

# 在Node中使用
async def my_node(state):
    results = await rate_limited_llm_call(state["messages"])
    return {"results": results}
```

**为什么要限流？**

- 防止触发LLM提供商的Rate Limit
- 保护下游服务（数据库、搜索API）不被打挂
- 控制成本，避免突发流量导致账单爆炸

