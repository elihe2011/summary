# 1. 概览

## 1.1 概述

**LangChain 是一个用于构建 LLM（大语言模型）应用的开发框架**，它将"调用模型"、"组织提示词"、"连接外部数据"、"编排工具调用"等常见操作抽象为可组合的标准化组件。

它解决了三个核心问题：

| 痛点                      | LangChain 的解决方案                               |
| ------------------------- | -------------------------------------------------- |
| 每个模型厂商的 API 不同   | 统一的 `ChatModel` 接口，切换模型只需改一行        |
| 提示词管理混乱            | `PromptTemplate` 模板化 + 变量注入                 |
| 与外部数据/工具的集成繁琐 | 标准化的 `Tool`、`Retriever`、`Document Loader` 等 |
| 组件之间难以组合          | LCEL（管道语法）让组合像拼积木                     |



## 1.2 生态全景

```
┌─────────────────────────────────────────────────────────┐
│                    LangChain 生态全景                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐    ┌─────────────────────────────┐    │
│  │ langchain-core│───▶│ ChatModel, Runnable,       │   │
│  │  (核心抽象)   │    │ BaseMessage, Tool, Parser    │   │
│  └──────┬───────┘    └─────────────────────────────┘    │
│         │                                               │
│  ┌──────▼───────┐    ┌─────────────────────────────┐    │
│  │  langchain    │───▶│ Agents, Chains (高层编排)   │    │
│  │  (编排层)     │    │ LCEL 表达式语言               │    │
│  └──────┬───────┘    └─────────────────────────────┘    │
│         │                                               │
│  ┌──────▼───────┐    ┌─────────────────────────────┐    │
│  │langchain-    │───▶│ 第三方向量数据库、文档加载器、   │    │
│  │ community    │    │ 检索器、Embeddings 等         │    │
│  └──────────────┘    └─────────────────────────────┘    │
│                                                         │
│  ┌──────────────┐    ┌─────────────────────────────┐    │
│  │langchain-    │───▶│ OpenAI 专用集成              │    │
│  │ openai       │    │ ChatOpenAI, OpenAIEmbeddings │   │
│  └──────────────┘    └─────────────────────────────┘    │
│                                                         │
│  ┌──────────────┐    ┌─────────────────────────────┐    │
│  │  langgraph   │───▶│ 图编排框架 (独立)             │    │
│  │  (图引擎)     │    │ 状态机、持久化、人机协作        │    │
│  └──────────────┘    └─────────────────────────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```



**各包的职责**:

| 包名                       | 职责                                                         | 用途               |
| -------------------------- | ------------------------------------------------------------ | ------------------ |
| `langchain-core`           | `Runnable`、`BaseMessage`、`ChatModel`、`Tool`、`OutputParser` | 定义接口、核心抽象 |
| `langchain`                | LCEL 链、Agent（`create_react_agent` 等）                    | 高层编排           |
| `langchain-community`      | FAISS、Chroma、各种 DocumentLoader                           | 社区集成           |
| `langchain-openai`         | `ChatOpenAI`、`OpenAIEmbeddings`                             | OpenAI 集成        |
| `langchain-anthropic`      | `ChatAnthropic`                                              | Anthropic 集成     |
| `langgraph`                | 图编排：状态机、Agent、持久化                                | 复杂图编排         |
| `langchain-text-splitters` | 文本分割器                                                   | 文本分割           |



## 1.3 LLM 通用应用架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/llm-app-generic-architecture.svg)

每一层，LangChain 都提供了对应的抽象：

| 层       | LangChain 组件                             | 作用                     |
| -------- | ------------------------------------------ | ------------------------ |
| 输入处理 | `ChatPromptTemplate`                       | 组装系统提示 + 用户输入  |
| 模型调用 | `ChatOpenAI` / `ChatAnthropic`             | 统一接口调用不同 LLM     |
| 工具集成 | `@tool` + `bind_tools()`                   | 让模型调用外部函数       |
| 输出解析 | `StrOutputParser` / `PydanticOutputParser` | 将模型输出转为所需格式   |
| 数据检索 | `Retriever` + `VectorStore`                | 从外部知识库检索相关内容 |
| 编排     | LCEL `|` 管道 / LangGraph `StateGraph`     | 将以上组件串联成完整流程 |



## 1.4 应用场景

LangChain 让 LLM 不再只是一个 “聊天机器人”，而是一个能执行任务、调用工具、与外部世界交互的 智能 AI 助手。

| 场景                            | 技术点                           |
| ------------------------------- | -------------------------------- |
| 文档问答助手                    | Prompt + Embedding + RetrievalQA |
| 智能日程规划助手                | Agent + Tool + Memory            |
| LLM + 数据库文档                | SQLDatabaseToolkit + Agent       |
| 多模型对话系统                  | RouterChain + 多 LLM             |
| 互联网智能客服                  | ConversationChain + RAG  + Agent |
| 企业知识库助手 (RAG + 本地模型) | VectorDB + LLM + Streamlit       |



![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/omniverse-knowledge-base.png)



# 2. 核心概念

## 2.1 Chat Models (与大模型对话)  

通过聊天模型接口访问 LLM，该接口通常以消息列表作为输入并返回一条消息作为输出：

- 输入：接收文本 `PromptValue` 或消息列表 `List[BaseMessage]`，每条消息需指定角色 (如 `SystemMessage`、`HumanMessage`、`AIMessage`)
- 输出：返回带角色的消息对象 (`BaseMessage` 子类)，通常是 `AIMessage`

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/chatmodel-input-output.png)



### 2.1.1 基本使用

LangChain 通过统一的 ChatModel 接口，对接不同的大模型厂商

```python
# ===== OpenAI ========
from langchain_openai import ChatOpenAI

# 创建模型实例
llm = ChatOpenAI(
	model="qwen-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    temperature=0,   # 0-确定性输出 1-随机性更强
    max_tokens=1024, # 最大输出 token 数
)

# ===== Anthropic ========
from langchain_anthropic import ChatAnthropic
llm = ChatAnthropic(
    model="qwen-max",
	api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url="https://dashscope.aliyuncs.com/apps/anthropic"
    max_tokens=1024,
)
```



### 2.1.2 消息类型

ChatModel 不接受纯字符串，而是接受 消息对象列表

```python
from langchain_core.messages import SystemMessage, HumanMessage, AIMessage

messages = [
    SystemMessage(content="你精通 Golang 编程，回答要简洁准确。"),
    HumanMessage(content="什么是Goroutine"),
]

response = llm.invoke(messages)
print(response.content)
```



| 消息类型        | 作用                      | 示例            |
| --------------- | ------------------------- | --------------- |
| `SystemMessage` | 设定 AI 的角色和行为规则  | "你是翻译专家"  |
| `HumanMessage`  | 用户输入                  | "翻译这句话"    |
| `AIMessage`     | AI 的回复（系统自动生成） | "以下是翻译..." |
| `ToolMessage`   | 工具调用的结果            | "查询结果：..." |



### 2.1.3 模型参数说明

```python
llm = ChatOpenAI(
    model="gpt-4o-mini",     # 模型名称
    temperature=0.7,         # 创造性（0-1），越高越随机
    max_tokens=2048,         # 最大输出长度
    timeout=30,              # 请求超时（秒）
    max_retries=3,           # 失败重试次数
    api_key="sk-...",        # 可选，优先读取环境变量
    base_url="https://...",  # 可选，使用兼容 API（如 DeepSeek）
)
```



## 2.2 Prompt Templates (提示词模板)

### 2.2.1 模板

直接拼接字符串容易错误且难以维护，`ChatPromptTemplate` 将提示词结构化：

```python
# 方式一：from_messages (推荐)
from langchain_core.prompts import ChatPromptTemplte
prompt = ChatPromptTemplate.from_messages([
    ("system": "你是一位{role}。请用{style}的语气回答问题。"),
    ("human": "{question}")
])

# 方式二：from_template (简单场景)
from langchain_core.prompts import PromptTemplate
prompt = PromptTemplate.from_template(
	"请用一句话解释：{concept}"
)
```



### 2.2.2 变量注入

模板中的 `{variable}` 会在调用时被替换：

```python
# 使用 from_messages 创建的模板
formatted = prompt.invoke({
    "role": "Python 编程专家",
    "style": "通俗易懂",
    "question": "什么是装饰器？"
})

# formatted 是 ChatPromptValue，包含格式化后的消息列表
print(formatted.messages)
# [SystemMessage(content='你是一位Python 编程专家。请用通俗易懂的语气回答问题。'),
#  HumanMessage(content='什么是装饰器？')]
```



### 2.2.3 `MessagesPlaceHolder` （对话历史）

多轮对话时，需要将历史消息注入到 prompt 中：

```python
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder

prompt = ChatPromptTemplate.from_messages([
    ("system", "你是一个友好的助手。"),
    MessagesPlaceholder(variable_name="history"),  # 对话历史插入点
    ("human", "{input}"),
])

# 模拟调用
from langchain_core.messages import HumanMessage, AIMessage

result = prompt.invoke({
    "history": [
        HumanMessage(content="我是Tom"),
        AIMessage(content="你好Tom！有什么可以帮你的？")
    ],
    "input": "我是谁？"
})

for msg in result.messages:
    print(f"{msg.__class__.__name__}: {msg.content}")
```

输出：

```
SystemMessage: 你是一个友好的助手。
HumanMessage: 我是Tom
AIMessage: 你好Tom！有什么可以帮你的？
HumanMessage: 我是谁？
```



### 2.2.4 外部加载 Prompt

将 prompt 保存为 JSON 或 YAML 等格式的文件，通过读取指定路径的格式化文件，获取相应的 prompt.



#### 2.2.4.1 json

```json
{
    "_type": "prompt",
    "input_variables": ["name", "what"],
    "template": "请{name}讲一个{what}的故事"
}
```

```python
from langchain_core.prompts import load_prompt

template = load_prompt("prompts/prompt.json", encoding="utf-8")
print(template.format(name="张三", what="搞笑的"))
```



#### 2.2.4.2 yaml

```yaml
_type: "prompt"
input_variables: ["name", "what"]
template: "请{name}讲一个{what}的故事"
```

```python
from langchain_core.prompts import load_prompt

template = load_prompt("prompts/prompt.yaml", encoding="utf-8")
print(template.format(name="年轻人", what="滑稽"))
```



## 2.3 Output Parsers (输出解析器)

LLM 返回的是 `AIMessage` 对象，通常需要提取纯文本或结构化数据



### 2.3.1 `StrOutputParser` (提取纯文本)

将 `AIMessage` 转为 str

```python
from langchain_core.messages import AIMessage
from langchain_core.output_parsers import StrOutputParser

parser = StrOutputParser()
msg = AIMessage(content="列表推导式是 Python 的一种简洁语法...")

text = parser.invoke(msg)
assert isinstance(text, str)
```



### 2.3.2 `PydanticOutputParser` (结构化输出)

当需要 LLM 返回 JSON 格式的数据时，它继承于 `JsonOutputParser` ，但更合适结构化输出

```python
import os

from langchain_core.output_parsers import PydanticOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI
from pydantic import BaseModel, Field

# 1. 提示词
prompt = ChatPromptTemplate.from_messages([
    ("system", "你是一位电影评论家。{format_instructions}"),
    ("human", "请评价电影：{movie}"),
])

# 2. 大模型
llm = ChatOpenAI(
    model="qwen-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    temperature=0,
)

# 3. 解析器 (关键)
## 3.1 定义输出结构
class MovieReview(BaseModel):
    movie_name: str = Field(description="电影名称")
    rating: int = Field(description="评分 1-10")
    summary: str = Field(description="一句话评价")
    pros: list[str] = Field(description="优点列表")
    cons: list[str] = Field(description="缺点列表")

## 3.2 创建解析器
parser = PydanticOutputParser(pydantic_object=MovieReview)

# 4. 调用链
chain = prompt | llm | parser

result = chain.invoke({
    "movie": "第一滴血",
    "format_instructions": parser.get_format_instructions(),
})

assert isinstance(result, MovieReview)

if __name__ == "__main__":
    print(result.model_dump())
```



### 2.3.3 `CommaSeparatedListOutputParser` (列表输出)

```python
import os

from langchain_core.output_parsers import CommaSeparatedListOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI

# 1. 提示词
prompt = ChatPromptTemplate.from_messages([
    ("system", "你是一个知识助手。{format_instructions}"),
    ("human", "列出5个{category}"),
])

# 2. 大模型
llm = ChatOpenAI(
    model="qwen-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    temperature=0,
)

# 3. 解析器 (关键)
parser = CommaSeparatedListOutputParser()

# 4. 调用链
chain = prompt | llm | parser

result = chain.invoke({
    "category": "Rust 应用领域",
    "format_instructions": parser.get_format_instructions(),
})

assert isinstance(result, list)

if __name__ == "__main__":
    print(result)  # ['系统编程', '游戏开发', '嵌入式设备', '网络服务', '并行与分布式计算']
```



## 2.4 Structured Outputs

### 2.4.1 TypedDict

TypedDict 提供了一个使用 Python 内置类型的简单方案，但没有验证功能

```python
import os
from typing import TypedDict, Annotated, List

from langchain.chat_models import init_chat_model

llm = init_chat_model(
    model="qwen3-vl-flash-2025-10-15",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

class Animal(TypedDict):
    animal: Annotated[str, "动物"]
    emoji: Annotated[str, "表情"]

class AnimalList(TypedDict):
    animals: Annotated[List[Animal], "动物与表情列表"]

messages = [
    {
        "role": "user",
        "content": "任意生成三种动物，以及它们的 emoji 表情",
    }
]

llm_with_structured_output = llm.with_structured_output(AnimalList)

if __name__ == "__main__":
    resp = llm_with_structured_output.invoke(messages)
    print(resp)
```



### 2.4.2 Pydantic

Pydantic 模型提供了丰富的功能集，包括字段验证、描述和嵌套结构

```python
from pydantic import BaseModel, Field

class Animal(BaseModel):
    animal: str = Field(description="动物")
    emoji: str = Field(description="表情")

class AnimalList(BaseModel):
    animals: list[Animal] = Field(description="动物与表情列表")
```



### 2.4.3 JSON Schema

若需最大程度的控制或互操作性，可以提供一个原始的 JSON Schema，将原始响应与解析后的表示一起返回，可在调用 `with_structured_ouput` 时设置 `include_raw=True` 来实现

```python
import os

from langchain.chat_models import init_chat_model

llm = init_chat_model(
    model="qwen3-vl-flash-2025-10-15",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

schema = {
    "name": "animal_list",
    "schema": {
        "type": "array",
        "items": {
            "type": "object",
            "properties": {
                "animal": {"type": "string", "description": "动物名称"},
                "emoji": {"type": "string", "description": "动物emoji表情"},
            },
            "required": ["animal", "emoji"],
        }
    }
}

messages = [
    {
        "role": "user",
        "content": "任意生成三种动物，以及它们的 emoji 表情",
    }
]

llm_with_structured_output = llm.with_structured_output(
    schema=schema,
    include_raw=True,
    method="json_schema"
)

if __name__ == "__main__":
    resp = llm_with_structured_output.invoke(messages)
    print(resp)
    print(resp["raw"])
    print(resp["parsed"])
```



## 2.5 LCEL (LangChain 表达式语言)

LCEL（LangChain Expression Language）是 LangChain 最强大的特性。它用 `|`（管道）操作符将组件串联起来，像 Unix 管道一样简洁。



### 2.5.1 核心理念

数据从左向右，每个组件处理数据后传给下一个

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/chain-workflow.svg)



### 2.5.2 基本链

```python
import os

from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_openai import ChatOpenAI

# 三个组件
prompt = ChatPromptTemplate.from_messages([
    ("system", "你是一位{role}"),
    ("human", "{input}"),
])

llm = ChatOpenAI(
    model="qwen-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    temperature=0,
)

parser = StrOutputParser()

# 管道组合 LCEL
chain = prompt | llm | parser

# 调用
result = chain.invoke({
    "role": "资深 Rust 开发者",
    "input": "零拷贝是什么"
})

if __name__ == '__main__':
    print(result)
```

**实现原理**：

- **统一接口**：所有实现了 Runnable 的组件都可以用 `|` 连接
- **自动类型转换**：每个组件知道如何处理上游输出
- **统一方法**：`invoke`、`stream`、`batch` 自动调用



### 2.5.3 `RunnableSequence` 

`RunnableSequence` 按顺序“链接”多个可运行对象，其中一个对象的输出作为下一个对象的输入

```python
chain = RunnableSequence([runnable1, runnable2])

# LCEL重载“|”运算符，实现两个Runnable创建RunnableSequence
chain = runnale1 | runnable2
```

示例：提示模板 => 模型 => 输出解析器

```python
import os

from langchain.chat_models import init_chat_model
from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import PromptTemplate

prompt = PromptTemplate(
    template="简单介绍下{topic}的概况",
    input_variables=["topic"],
)

llm = init_chat_model(
    model="qwen3-vl-flash-2025-10-15",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

parser = StrOutputParser()

chain = prompt | llm | parser

if __name__ == "__main__":
    resp = chain.invoke({"topic": "突尼斯"})
    print(resp)
```



### 2.5.4 `RunnableParallel` (并行执行)

`RunnableParallel`支持同时运行多个可运行对象，并为每个对象提供相同的输入

- 同步执行：使用 `ThreadPoolExecutor` 来同时执行可运行对象
- 异步执行：使用 `asyncio.gather` 来同时执行可运行对象

```python
import os

from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableParallel, RunnablePassthrough
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model="qwen-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    temperature=0,
)

# 定义多条链
summary_chain = (
    ChatPromptTemplate.from_template("一句话总结：{topic}")
    | llm
    | StrOutputParser()
)

detail_chain = (
    ChatPromptTemplate.from_template("详细解释：{topic}")
    | llm
    | StrOutputParser()
)

# 并行执行
parallel = RunnableParallel({
    "summary": summary_chain,
    "detail": detail_chain,
    "original": RunnablePassthrough()  # 透传原生输入
})

result = parallel.invoke({"topic": "星链"})

if __name__ == '__main__':
    print(result["original"])
    print(result["summary"])
    print(result["detail"])
```



### 2.5.5 `RunnablePassthrough` (透传数据)

原样传递数据，常用于在链中保留原始数据

```python
from langchain_core.runnables import RunnableParallel, RunnablePassthrough

# 场景：RAG 链中，question 需要透传，同时从 retriever 获取 context
chain = RunnableParallel({
    "context": retriever,                  # 从向量数据库检索
    "question": RunnablePassthrough(),     # 原样传递问题
}) | prompt | llm | StrOutputParser()

chain.invoke("什么是 RAG？")
# "context" = retriever.invoke("什么是 RAG？")
# "question" = "什么是 RAG？"
```



示例：使用 `assign()` 向输出中添加键

```python
from langchain_core.runnables import RunnableParallel, RunnablePassthrough
from pygments.lexer import words

chain = {
    "text1": lambda x: x + " world",
    "text2": lambda x: x + ", how are you",
} | RunnablePassthrough.assign(word_count=lambda x: len(x["text1"]) + len(x["text2"]))

if __name__ == "__main__":
    result = chain.invoke("hello")
    print(result)
    # {'text1': 'hello world', 'text2': 'hello, how are you', 'word_count': 29}
```



### 2.5.6 `RunnableLambda` (自定义函数)

当需要在链中插入自定义逻辑

```python
import os

from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableLambda
from langchain_openai import ChatOpenAI

llm = ChatOpenAI(
    model="qwen-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    temperature=0,
)

def word_count(text: str) -> dict:
    return {
        "text": text,
        "char_count": len(text),
        "word_count": len(text.split("\n")),
    }

chain = (
    ChatPromptTemplate.from_template("写一首关于{topic}的诗")
    | llm
    | StrOutputParser()
    | RunnableLambda(word_count) # 自定义处理函数
)

result = chain.invoke({"topic": "桃花"})

if __name__ == '__main__':
    print(result)
```



通过装饰器：

```python
from langchain_core.runnables import RunnableLambda

@RunnableLambda
def total_len(x):
    return len(x["text1"]) + len(x["text2"])

chain = {
    "text1": lambda x: x + " world",
    "text2": lambda x: x + ", how are you",
} | total_len

if __name__ == '__main__':
    result = chain.invoke("hello")
    print(result)
```



### 2.5.7 `RunnableBranch`

`RunnableBranch` 使用 (条件，Runnable) 对列表和默认分支进行初始化。对输入进行操作时，选择第一个计算结果为 True 的条件，并在输入上运行相应的 Runnable。如果没有条件为 True，则在输入上运行默认分支

```python
from langchain_core.runnables import RunnableBranch

chain = RunnableBranch(
    (lambda x: isinstance(x, str), lambda x: x.upper()),
    (lambda x: isinstance(x, int), lambda x: x + 1),
    (lambda x: isinstance(x, float), lambda x: x * 2),
    lambda _: "goodbye",
)

if __name__ == "__main__":
    result = chain.invoke("hello")
    print(result) # HELLO

    result = chain.invoke(0.3)
    print(result) # 0.6

    result = chain.invoke(None)
    print(result) # goodbye
```



### 2.5.8 `RunnableWithFallbacks`

`RunnableWithFallbacks` 使得 Runnable 失败后可以回退到其它 Runnable。可以直接在 Runnable 上使用 `with_fallbacks` 方法

```python
import os

from langchain.chat_models import init_chat_model
from langchain_core.prompts import PromptTemplate
from langchain_core.runnables import RunnableLambda

llm = init_chat_model(
    model="qwen3-vl-flash-2025-10-15",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

chain = PromptTemplate.from_template("hello") | llm
chain_with_fallbacks = chain.with_fallbacks([RunnableLambda(lambda _: "sorry")])

if __name__ == "__main__":
    result = chain_with_fallbacks.invoke("1")  # 提示词模板没有需要填充的变量，会报错
    print(result)  # sorry
```



## 2.6 Runnable 接口

所有 LCEL 组件都实现了 `Runnable` 接口，提供以下方法：

| 方法             | 说明               | 同步/异步 | 使用场景                           |
| ---------------- | ------------------ | --------- | ---------------------------------- |
| `invoke(input)`  | 单次调用           | 同步      | 简单的单次请求                     |
| `batch(inputs)`  | 批量调用           | 同步      | 处理多个输入                       |
| `stream(input)`  | 流式输出（迭代器） | 同步      | 前端实时显示，逐字输出，用户体验好 |
| `ainvoke(input)` | 单次调用           | 异步      | Web 服务（FastAPI）                |
| `abatch(inputs)` | 批量调用           | 异步      | 处理多个输入，自动并发，效率高     |
| `astream(input)` | 流式输出           | 异步      | Web 服务（FastAPI）                |

```python
# stream 流式输出，适合实时显示
for chunk in chain.stream({"input": "解释什么是递归"}):
    print(chunk, end="", flush=True)
# 输出：递归是......（逐字显示）
print()  # 换行
```



## 2.7 实例：构建一个翻译链

```python
import os
from operator import itemgetter

from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableParallel
from langchain_openai import ChatOpenAI

# 1. 定义模型
llm = ChatOpenAI(
    model="qwen-max",
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    temperature=0,
)

# 2. 提示词
translate_prompt = ChatPromptTemplate.from_messages([
    ("system", "你是一个专业翻译。将用户提供的{source_lang}文本翻译为{target_lang}"),
    ("human", "{text}")
])

review_prompt = ChatPromptTemplate.from_messages([
    ("system", "你是一个翻译质量审核员。评估以下翻译的质量，给出改进建议"),
    ("human", "原文({source_lang}): {original}\n\n译文({target_lang}): {translated}"),
])

# 3. 构建翻译链
translate_chain = translate_prompt | llm | StrOutputParser()

# 4. 构建完整管道：翻译 + 审查并行
full_chain = (
    RunnableParallel({
        "translated": translate_chain,
        "original": itemgetter("text"),
        "source_lang": itemgetter("source_lang"),
        "target_lang": itemgetter("target_lang"),
    })
    | RunnableParallel({
        "translated": itemgetter("translated"),
        "review": (
            review_prompt
            | llm
            | StrOutputParser()
        ),
    })
)

# 5. 调用
result = full_chain.invoke({
    "source_lang": "中文",
    "target_lang": "英文",
    "text": "生成式人工智能正在改变这个世界，是挑战也是机遇"
})

if __name__ == "__main__":
    print(f"翻译结果：{result['translated']}")
    print(f"质量审查：{result['review']}")
```



## 2.8小结

| 概念                  | 总结                                                   |
| --------------------- | ------------------------------------------------------ |
| `ChatModel`           | 统一的模型调用接口，`invoke` 传入消息列表              |
| `PromptTemplate`      | 用 `{variable}` 占位符构建模板，支持多种消息类型       |
| `OutputParser`        | 将 `AIMessage` 转为所需的输出格式（str、JSON、list）   |
| `LCEL`                | 用 `|` 管道符组合组件，统一 `invoke/stream/batch` 接口 |
| `RunnableParallel`    | 并行执行多个分支                                       |
| `RunnablePassthrough` | 透传数据                                               |
| `RunnableLambda`      | 插入自定义函数                                         |



# 3. RAG

## 3.1 概述

### 3.1.1 LLM 的两大局限

| 局限                      | 表现                                       | RAG 如何解决                 |
| ------------------------- | ------------------------------------------ | ---------------------------- |
| **知识截止**              | 模型的训练数据有时间截止点，不知道最新信息 | 从外部文档中检索最新知识     |
| **幻觉（Hallucination）** | 模型可能编造看似合理但实际错误的信息       | 用检索到的真实文档作为上下文 |



### 3.1.2 RAG 的核心思想

```
用户提问 → 从知识库检索相关文档 → 将文档作为上下文喂给 LLM → LLM 基于事实回答
```

对应 RAG：检索外部数据，作为参考信息输入 LLM 辅助生成答案

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/RAG-flow.png)

- **Source**：多种类型的数据源，如视频、图片、文本、代码、文档等
- **Load**：将多源异构数据统一加载为文档对象
- **Transform**：对文档进行转换和处理，比如将文本切分为小块
- **Embed**：将文本编码为向量
- **Store**：将向量化的数据存储起来
- **Retrieve**：将文本库中检索相关的文本段落



### 3.1.3 RAG vs 微调（Fine-tuning）

| 维度     | RAG                    | Fine-tuning               |
| -------- | ---------------------- | ------------------------- |
| 成本     | 低（无需训练）         | 高（需要 GPU + 数据准备） |
| 时效性   | 实时更新（改文档即可） | 需要重新训练              |
| 适用场景 | 知识密集型问答         | 风格/格式定制             |
| 可解释性 | 高（可追溯检索来源）   | 低                        |

> 💡 **经验法则**：90% 的场景用 RAG 就够了，Fine-tuning 用于需要改变模型行为风格的场景。



## 3.2 RAG 的两阶段

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/rag_pipeline_flowchart.svg)



## 3.3 Document Loaders (文档加载)

Document Loader 将各种格式的数据统一转为 LangChain 的 Document 对象



### 3.3.1 Document 对象

```python
from langchain_core.documents import Document

# Document 对象核心字段
doc = Document(
    page_content="文档内容",
    metadata={"source": "abc.txt", "page": 1}
)
```



### 3.3.2 常用 Loader

```python
# 1. 加载文本文件
from langchain_community.document_loaders import TextLoader
loader = TextLoader("./data/article.txt", encoding="utf-8")
docs = loader.load()

# 2. 加载PDF
from langchain_community.document_loaders import PyPDFLoader
loader = PyPDFLoader("./data/report.pdf")
docs = loader.load()

# 3. 加载网页
from langchain_community.document_loaders import WebBaseLoader
loader = WebBaseLoader("https://example.com/news")
docs = loader.load()

# 4. 加载CSV
from langchain_community.document_loaders import CSVLoader
loader = CSVLoader("./data/user.csv", encoding="utf-8")
docs = loader.load()
```



## 3.4 Text Splitters (文本分割)

LLM 有上下文窗口限制（如 GPT-4o 的 128K tokens），而且**文档太长时检索精度会下降**。需要将长文档切成小块（chunks），只检索最相关的块。



### 3.4.1 `RecursiveCharacterTextSplitter`

最推荐的分割器，它会按 `\n\n` → `\n` → → `""` 的优先级尝试分割，尽量保持语义完整性

```python
from langchain_text_splitters import RecursiveCharacterTextSplitter

splitter = RecursiveCharacterTextSplitter(
    chunk_size=1000,
    chunk_overlap=200,
    length_function=len,
    separators=["\n\n", "\n", "。"]
)

chunks = splitter.split_documents(docs)
print(f"分割为 {len(chunks)} 个块")
print(f"第一块长度：{len(chunks[0].page_content)}")
```



参数说明：

| 参数            | 推荐值                    | 说明                             |
| --------------- | ------------------------- | -------------------------------- |
| `chunk_size`    | **500-1500**              | 太小丢失上下文，太大降低检索精度 |
| `chunk_overlap` | **chunk_size 的 10%-20%** | 保证块之间有重叠，不丢失边界信息 |



**按Token数分割（更精确）**

```python
splitter = RecursiveCharacterTextSplitter.from_tiktoken_encoder(
    chunk_size=250,       # 每块最多 250 个 token
    chunk_overlap=0,      # 无重叠
)

chunks = splitter.split_documents(docs)
print(f"按 token 分割为 {len(chunks)} 个块")
```

> ⚠️ `from_tiktoken_encoder` 需要安装 `tiktoken`：`pip install tiktoken`



## 3.5 Embeddings (向量嵌入)

Embedding 将文本转换为一组高维浮点数向量。**语义相近的文本，向量距离越近**。

```
"猫是一种宠物"  →  [0.12, -0.34, 0.56, ..., 0.78]  (1536维)
"狗是一种宠物"  →  [0.11, -0.32, 0.55, ..., 0.77]  (相似！)
"股票市场下跌"  →  [0.89, 0.12, -0.45, ..., -0.33]  (完全不同)
```



### 3.5.1 OpenAI Embeddings

```python
from langchain_openai import OpenAIEmbeddings

embeddings = OpenAIEmbeddings(
    model="text-embedding-3-small",    # 推荐，性价比高
    # model="text-embedding-3-large",  # 更高维度，精度更好
)

# 嵌入单条查询
query_vector = embeddings.embed_query("什么是机器学习？")
print(f"向量维度：{len(query_vector)}")  # 1536

# 嵌入多条文档
doc_vectors = embeddings.embed_documents([
    "机器学习是AI的一个子领域",
    "深度学习使用神经网络",
])
print(f"嵌入了 {len(doc_vectors)} 条文档")
```



### 3.5.2 DashScopeEmbeddings

阿里云百炼向量模型

```python
embeddings = DashScopeEmbeddings(
    model="text-embedding-v4",
    dashscope_api_key=os.getenv("DASHSCOPE_API_KEY"),
    # base_url=os.getenv("DASHSCOPE_BASE_URL"),
)
```



### 3.5.3 HuggingFaceEmbeddings

开源模型，本地加载

```python
from langchain_huggingface import HuggingFaceEmbeddings

# 加载嵌入模型
embeddings = HuggingFaceEmbeddings(
    model_name=r'~/huggingface.co/bge-base-zh-v1.5'
)

if __name__ == "__main__":
    # 单文本嵌入
    query = "你好，世界"
    print(embeddings.embed_query(query))

    # 多文本嵌入
    docs = ["你好，世界", "北京欢迎你"]
    print(embeddings.embed_documents(docs))
```



## 3.6 Vector Stores (向量存储)

Vector Store 负责存储嵌入向量并支持相似度搜索。



### 3.6.1 `InMemoryVectorStore` (开发/测试)

```python
from langchain_core.vectorstores import InMemoryVectorStore
from langchain_openai import OpenAIEmbeddings

# 从文档直接创建
vectorstore = InMemoryVectorStore.from_documents(
    documents=chunks,
    embedding=OpenAIEmbeddings(),
)

# 相似度搜索
results = vectorstore.similarity_search("什么是任务分解？", k=3)
for doc in results:
    print(f"内容：{doc.page_content[:100]}...")
    print(f"来源：{doc.metadata}")
```



### 3.6.2 Milvus

```python
from langchain_community.embeddings import DashScopeEmbeddings
from langchain_community.vectorstores import Milvus

embeddings = DashScopeEmbeddings(
    model="text-embedding-v4",
    dashscope_api_key=os.getenv("DASHSCOPE_API_KEY"),
    # base_url=os.getenv("DASHSCOPE_BASE_URL"),
)

# 从文档直接创建
vectorstore = Milvus.from_documents(
    documents=chunks,
    embedding=embeddings,
    collection_name="web_data",
    connection_args={"uri": "http://192.168.3.111:19530"},
    drop_old=True,
)

# 相似度搜索
results = vectorstore.similarity_search("温哥华", k=3)
```



### 3.6.3 核心方法

| 方法                                       | 说明           | 返回                    |
| ------------------------------------------ | -------------- | ----------------------- |
| `from_documents(docs, embedding)`          | 从文档创建     | VectorStore             |
| `add_documents(docs)`                      | 添加更多文档   | list[str] (IDs)         |
| `similarity_search(query, k=4)`            | 相似度搜索     | list[Document]          |
| `similarity_search_with_score(query, k=4)` | 带分数的搜索   | list[(Document, float)] |
| `as_retriever()`                           | 转为 Retriever | Retriever               |



## 3.7 Retrievers (检索器)

Retriever 是 Vector Store 的上层抽象，为 LCEL 链提供标准接口。

**搜索类型：**

| search_type                    | 说明                                       | 适用场景             |
| ------------------------------ | ------------------------------------------ | -------------------- |
| `"similarity"`                 | 返回最相似的 k 个                          | 默认，大多数场景     |
| `"mmr"`                        | 最大边际相关性，兼顾**相关性**和**多样性** | 避免返回内容重复的块 |
| `"similarity_score_threshold"` | 只返回分数高于阈值的                       | 需要控制质量         |



### 3.7.1 相似度检索

```python
# 从 Vector Store 创建 Retriever
retriever = vectorstore.as_retriever(
    search_type="similarity",  # 搜索类型
    k=6,                       # 返回最相关的 6 个文档块
)

# 直接使用
docs = retriever.invoke("什么是 RAG？")
for doc in docs:
    print(doc.page_content[:100])
```



### 3.7.2 MMR 检索 (兼顾相关性和多样性) 

```python
retriever = vectorstore.as_retriever(
    search_type="mmr",
    search_kwargs={
        "k": 6,
        "fetch_k": 20,       # 先取 20 个候选
        "lambda_mult": 0.5,  # 0=最大多样性，1=最大相关性
    }
)
```



### 3.7.3 带阈值检索

```python
retriever = vectorstore.as_retriever(
    search_type="similarity_score_threshold",
    search_kwargs={
        "k": 6,
        "score_threshold": 0.8,  # 只返回相似度 >= 0.8 的
    }
)
```



## 3.8 构建完整 RAG 链

```python
import os
os.environ.setdefault("USER_AGENT", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36")

# 通过 monkey path 覆盖 Document 中冗余的元数据字段
def apply_path():
    from typing import Any

    from langchain_community.document_loaders import web_base

    def _build_metadata(soup: Any, url: str) -> dict:
        """Build metadata from BeautifulSoup output."""
        metadata = {"source": url}
        if title := soup.find("title"):
            metadata["title"] = title.get_text()
        return metadata

    web_base._build_metadata = _build_metadata

apply_path()

from langchain_community.document_loaders import WebBaseLoader
from langchain_community.embeddings import DashScopeEmbeddings
from langchain_community.vectorstores import Milvus
from langchain_core.documents import Document
from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableParallel, RunnablePassthrough
from langchain_openai import ChatOpenAI
from langchain_text_splitters import RecursiveCharacterTextSplitter

# ============== 1. 构建知识库 =============
# 1.1 文档
loader = WebBaseLoader(
    web_path="https://baike.baidu.com/item/%E5%8A%A0%E6%8B%BF%E5%A4%A7/145973",
)
docs = loader.load()

# 1.2 文本分割
splitter = RecursiveCharacterTextSplitter(
    chunk_size=200,
    chunk_overlap=30,
    length_function=len,
    separators=["\n\n", "\n", "。"]
)

chunks = splitter.split_documents(docs)

# 1.3 向量化存储
embeddings = DashScopeEmbeddings(
    model="text-embedding-v4",
    dashscope_api_key=os.getenv("DASHSCOPE_API_KEY"),
    # base_url=os.getenv("DASHSCOPE_BASE_URL"),
)

vectorstore = Milvus.from_documents(
    documents=chunks,
    embedding=embeddings,
    collection_name="web_data",
    connection_args={"uri": "http://192.168.3.111:19530"},
    drop_old=True,
    # metadata_field="metadata", # 确保metadata不flatten
)

# 1.4 创建检索器
retriever = vectorstore.as_retriever(k=6)


# ============== 2. 构建 RAG 链 =============

# 2.1 提示词
prompt = ChatPromptTemplate.from_messages([
    ("system", """你是一个知识问答助手。请仅根据以下检索到的上下文来回答用户的问题。
如果上下文中没有相关信息，请说"根据已有信息无法回答该问题"。
不要编造任何信息。

上下文：
{context}"""),
    ("human", "{question}"),
])

## 2.2 格式化函数，将检索到的文档拼接为字符串
def format_docs(docs: list[Document]):
    return "\n\n---\n\n".join(doc.page_content for doc in docs)

## 2.3 构建 RAG 链
llm = ChatOpenAI(
    api_key=os.getenv('DASHSCOPE_API_KEY'),
    base_url=os.getenv('DASHSCOPE_BASE_URL'),
    model="qwen-plus",
    temperature=0,
    max_tokens=1024
)

rag_chain = (
    RunnableParallel({
        "context": retriever | format_docs,  # 检索 -> 格式化
        "question": RunnablePassthrough(),   # 透传问题
    })
    | prompt
    | llm
    | StrOutputParser()
)


if __name__ == "__main__":
    answer = rag_chain.invoke("温哥华的相关信息")
    print(answer)
```



## 3.9 小结

| 组件            | 作用                  | 关键类                                       |
| --------------- | --------------------- | -------------------------------------------- |
| Document Loader | 加载各种格式数据      | `TextLoader`、`WebBaseLoader`、`PyPDFLoader` |
| Text Splitter   | 分割长文档为小块      | `RecursiveCharacterTextSplitter`             |
| Embeddings      | 文本向量化            | `OpenAIEmbeddings`                           |
| Vector Store    | 存储向量、相似度搜索  | `InMemoryVectorStore`、`FAISS`               |
| Retriever       | 检索接口（LCEL 兼容） | `vectorstore.as_retriever()`                 |
| RAG Chain       | 组合以上组件          | LCEL 管道                                    |



# 4. Agent

## 4.1 概述

### 4.1.1 Chain 的局限

LCEL 链是固定流程：

```
输入 → Prompt → LLM → Parser → 输出
```

所有步骤在编码时确定，运行时不会改变



### 4.1.2 Agent 的能力

充分利用 LLM 的推理决策能力，通过增加规划、记忆和工具调用能力，构造一个能够独立思考、逐步完成给定目标的 Agent。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/llm-agent-system.png)

Agent = LLM + Memory + Tools + Planning + Action

- **大模型 (LLM)**：作为“大脑”，提供推理、规划和知识理解能力，是 AI Agent 的决策中枢
- **记忆 (Memory)**：像人类一样，留存学到的知识及交互习惯等，让 Agent 在处理重复工作时调用以前的经验，从而避免用户进行大量重复交互
  - **短期记忆**：存储单次对话周期的上下文信息，属于临时信息存储机制。受限于模型的上下文窗口长度
  - **长期记忆**：可以跨多个任务和时间周期，可存储并调用核心知识，非即时任务。长期记忆可以通过模型参数微调 (固化知识)、知识图谱 (结构化语义网络) 或向量数据库实现
- **工具 (Tools)**：调用外部工具 (如API、数据库) 扩展能力边界
- **规划决策 (Planning)**：通过任务分解、反思与自省框架实现复杂任务处理。例如，利用思维链 (Chain of Thought) 将目标拆解为子任务，并通过反馈优化策略
- **行动 (Action)**：实际执行决策的模块，涵盖软件接口操作 (如自定订票) 和物理交互 (机器人执行搬运）



### 4.1.3 Agent 类型

| Agent 类型             | 核心特点                                                     | 适用场景                            | 来源（官方文档）                         |
| ---------------------- | ------------------------------------------------------------ | ----------------------------------- | ---------------------------------------- |
| ReAct Agent（MRKL）    | 遵循 “思考（Thought）→ 行动（Action）→ 观察（Observation）”循环，结合推理与动作 | 复杂多步骤任务、需要可解释性的场景  | JavaScript/Go/Python 官方文档            |
| OpenAI Functions Agent | 依赖 OpenAI 函数调用能力，支持结构化工具参数传递，减少解析错误 | 需精准调用工具（如 API 传参）的场景 | Go 官方文档（tmc.github.io/langchaingo） |
| Conversational Agent   | 支持多轮对话上下文，动态调用工具时维持对话连贯性             | 聊天型应用、需要上下文交互的任务    | Go 官方文档、Python 中文文档             |
| Plan-and-Execute Agent | 先通过 LLM 生成任务计划（分步骤），再按计划迭代执行工具      | 长期规划类任务（如“写一篇论文”）    | Python 中文文档、Go 官方文档             |
| Zero-shot Agent        | 无需训练，仅通过工具描述和用户输入选择工具，无历史记忆       | 简单多工具调用任务                  | Python 中文文档                          |



## 4.2 Tools (定义工具)

工具是 Agent 与外界交互的桥梁



### 4.2.1 创建工具

```python
@tool
def get_weather(location: str) -> str:
    """获取指定城市的天气信息"""
    # 实际需要调用天气 API
    weather_data = {
        "北京": "晴，18°C",
        "上海": "多云，22°C",
        "深圳": "小雨，26°C",
    }

    return weather_data.get(location, f"暂无{location}的天气数据")

@tool
def calculate(expression: str) -> str:
    """计算数学表达式，输入一个合法的数学表达式，如 '2 + 3 * 4'"""
    try:
        result = eval(expression)
        return f"计算结果：{result}"
    except Exception as e:
        return f"计算错误：{e}"

@tool
def search_knowledge_base(query: str) -> str:
    """在知识库中搜索相关信息"""
    # 实际场景中调用 RAG 检索
    knowledge = {
        "退货政策": "购买后7天内可无理由退货，需保持商品完好。",
        "配送时间": "标准配送3-5个工作日，加急配送1-2个工作日。",
        "会员等级": "银卡、金卡、钻石三个等级，消费累积升级。",
    }
    for key, value in knowledge.items():
        if key in query or any(k in query for k in key):
            return value
    return f"为找到'{query}'相关的信息"
```



### 4.2.2 工具属性

```python
print(get_weather.name)
print(get_weather.description)
print(get_weather.args_schema.model_json_schema())  # JSON Schema，给大模型用
```



### 4.2.3 带 Pydantic Schema 的工具

复杂参数时，通过 Pydantic 定义 Schema：

```python
class SearchInput(BaseModel):
    query: str = Field(description="搜索关键词")
    max_results: int = Field(default=5, description="最大返回结果数")
    language: str = Field(default="zh", description="搜索语言吗，如 zh/en")
    before: int = Field(description="前几秒")

@tool(
    name_or_callable="search_web",
    description="搜索互联网获取信息",
    args_schema=SearchInput,   # 定义参数模式
)
def search_web(query: str, max_results: int = 5, language: str = "zh") -> str:
    return f"搜索 '{query}' ({language}), 找到 {max_results} 条结果: ..."
```



## 4.3 Tool Calling

Tool Calling 分三步：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/tool-calling-flowchart.svg)



### 4.3.1 手动 Tool Calling

```python
# 大模型
llm = ChatOpenAI(
    model="qwen3-max",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    temperature=0,
)

# 关键：记录所有交互消息
messages: list[BaseMessage] = []

# 1. 绑定工具到大模型
tools = [get_weather, calculate]
llm_with_tools = llm.bind_tools(tools)


# 2. 发送消息，让模型决定是否调用工具
messages.append(HumanMessage(content="北京的天气怎么样？同时帮我算一下 '3 + 4 * 5' 等于多少"))
response = llm_with_tools.invoke(messages)
messages.append(response)  # AIMessage

print("模型返回的 tool_calls: ")
for tool_call in response.tool_calls:
    print(f"\t工具名: {tool_call['name']}")
    print(f"\t参数: {tool_call['args']}")
    print(f"\tID: {tool_call['id']}")
    print("-" * 20)


# 3. 执行工具调用
tool_messages = []
for tool_call in response.tool_calls:
    if tool_call['name'] == "get_weather":
        result = get_weather.invoke(tool_call['args'])
    elif tool_call['name'] == "calculate":
        result = calculate.invoke(tool_call['args'])
    else:
        result = "未知工具"

    tool_messages.append(ToolMessage(
        content=result,
        tool_call_id=tool_call['id'],
    ))


# 4. 将工具结果发回给模型，获取最终答案
messages.extend(tool_messages)

final_response = llm_with_tools.invoke(messages)
print("最终答案：", final_response.content)
```



## 4.4 create_agent

手动管理 Tool Calling 循环很繁琐，可使用 create_agent 一步到位，并通过 `bind_tools` 方法将工具绑定到大模型

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/llm-bind-tools.png)

- 大模型通过分析用户需求，判断是否需要调用工具
- 如果需要则在响应的 addtional_kwargs 参数中包含工具调用的详细信息
- 使用模型提供的参数执行工具



### 4.4.1 基本使用

```python
import os
from zoneinfo import ZoneInfo

from langchain.agents import create_agent
from langchain_core.tools import tool
from langchain_openai import ChatOpenAI
from langchain_tavily import TavilySearch

# 1. 定义工具
@tool
def get_time(timezone: str) -> str:
    """获取指定时区的当前时间"""
    from datetime import datetime
    now = datetime.now(ZoneInfo(timezone))
    return f"当前时间 ({timezone}): {now.strftime('%Y-%m-%d %H:%M:%S')}"

# Tavily 搜索工具
search = TavilySearch(max_results=5)

# 工具列表
tools = [search, get_time]

# 2. 创建 Agent
llm = ChatOpenAI(
    model="qwen3-max",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    temperature=0,
)

agent = create_agent(
    model=llm,
    tools=tools,
    system_prompt="你是一个助手，需要调用工具来帮助用户"
)


if __name__ == "__main__":
    result = agent.invoke({
        "messages": [{"role": "user", "content": "蒙特利尔天气怎么样？现在几点了？"}]
    })

    for msg in result["messages"]:
        print(f"[{msg.__class__.__name__}] {msg.content[:100] if msg.content else msg.tool_calls}")
```



### 4.4.2 内部架构

create_agent 内部构建了一个 LangGraph 状态图：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/create_agent-langgraph-state.svg)



### 4.4.3 携带系统提示词

```python
agent = create_agent(
    model=llm,
    tools=tools,
    system_prompt="你是一个助手，需要调用工具来帮助用户"
)
```



### 4.4.4 持久化 (多轮对话)

```python
import os

from langchain.agents import create_agent
from langchain_core.messages import HumanMessage
from langchain_openai import ChatOpenAI
from langgraph.checkpoint.memory import InMemorySaver

llm = ChatOpenAI(
    model="qwen3-max",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
    temperature=0,
)

agent = create_agent(
    model=llm,
    checkpointer=InMemorySaver(),   # 内存持久化
)

# 用 thread_id 区分不同对话
config = {"configurable": {"thread_id": "C001"}}

if __name__ == "__main__":
    # 第一轮
    result = agent.invoke(
        {"messages": [HumanMessage(content="我是Tom")]},
        config=config,
    )
    print(result["messages"][-1].content)

    # 第二轮
    result = agent.invoke(
        {"messages": [HumanMessage(content="我是谁？")]},
        config=config,
    )
    print(result["messages"][-1].content)
```



## 4.5 流式输出

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/agent_stream_mode.png)



### 4.5.1 updates (Agent 步骤进度流)

每次 agent 执行完一个节点（step）后，就推送一次该节点的状态变化。 [Langchain](https://docs.langchain.com/oss/python/langchain/streaming/overview)例如一次工具调用的完整流程会依次推出三个 chunk：LLM 节点（含 tool_call 请求）→ Tool 节点（执行结果）→ LLM 节点（最终回复）。

**数据结构**：

```python
{
  "type": "updates",
  "data": {
    "model": {"messages": [AIMessage(...)]},
    "tools": {"messages": [ToolMessage(...)]}
  }
}
```

**适合**：调试面板、进度指示器、需要追踪每个步骤结果的后台日志系统。



查看每一步的执行情况：

```python
for chunk in agent.stream(
    {"messages": [HumanMessage("深圳的天气怎么样？")]},
    stream_mode="updates"
):
    print(chunk)  # dict
    print("-" * 20)
```



chunk 是一个 `dict[str, str]`，结构如下：

```
{'model': {'messages': [AIMessage(content='', additional_kwargs={'refusal': None}, response_metadata={'token_usage': {'completion_tokens': 21, 'prompt_tokens': 269, 'total_tokens': 290, 'completion_tokens_details': None, 'prompt_tokens_details': {'audio_tokens': None, 'cached_tokens': 0}}, 'model_provider': 'openai', 'model_name': 'qwen3-max', 'system_fingerprint': None, 'id': 'chatcmpl-9cce6967-bdcd-9ee8-abf5-330022602200', 'finish_reason': 'tool_calls', 'logprobs': None}, id='lc_run--019d9a88-7b47-7150-bacf-b2b5fcaba8de-0', tool_calls=[{'name': 'get_weather', 'args': {'location': '深圳'}, 'id': 'call_d3db194fca774c3da465fc5f', 'type': 'tool_call'}], invalid_tool_calls=[], usage_metadata={'input_tokens': 269, 'output_tokens': 21, 'total_tokens': 290, 'input_token_details': {'cache_read': 0}, 'output_token_details': {}})]}}
--------------------
{'tools': {'messages': [ToolMessage(content='小雨，26°C', name='get_weather', id='32d357d9-572c-47ad-86c6-67b12e594577', tool_call_id='call_d3db194fca774c3da465fc5f')]}}
--------------------
{'model': {'messages': [AIMessage(content='深圳目前的天气是小雨，气温为26°C。建议出门携带雨具，并注意防滑。', additional_kwargs={'refusal': None}, response_metadata={'token_usage': {'completion_tokens': 24, 'prompt_tokens': 311, 'total_tokens': 335, 'completion_tokens_details': None, 'prompt_tokens_details': {'audio_tokens': None, 'cached_tokens': 192}}, 'model_provider': 'openai', 'model_name': 'qwen3-max', 'system_fingerprint': None, 'id': 'chatcmpl-6e1745cc-ba9b-997a-a0a9-c69a0225785f', 'finish_reason': 'stop', 'logprobs': None}, id='lc_run--019d9a88-80a8-7413-8aee-d901f2d75726-0', tool_calls=[], invalid_tool_calls=[], usage_metadata={'input_tokens': 311, 'output_tokens': 24, 'total_tokens': 335, 'input_token_details': {'cache_read': 192}, 'output_token_details': {}})]}}
--------------------
```



示例：

```python
# stream_mode="updates" 过程事件，按模型、工具等分不同的事件消息
def stream_chat_updates(agent, session_id: str, message: str):
    config = {"configurable": {"session_id": session_id}}

    for chunk in agent.stream(
        {"messages": [HumanMessage(content=message)],},
        config=config,
        stream_mode="updates",
    ):
        print(chunk)

        for node in chunk.values():
            if "messages" not in node:
                continue

            for msg in node["messages"]:
                # tool call
                if isinstance(msg, AIMessage) and msg.tool_calls:
                    yield (
                        "event: tool_call\n"
                        f"data: {json.dumps(msg.tool_calls)}\n\n"
                    )

                # tool result
                elif isinstance(msg, ToolMessage):
                    yield (
                        "event: tool_result\n"
                        f"data: {msg.content}\n\n"
                    )

                # normal output
                elif isinstance(msg, AIMessage) and msg.content:
                    yield (
                        "event: final_result\n"
                        f"data: {msg.content}\n\n"
                    )
```



### 4.5.2 messages (LLM Token 实时流)

流式输出所有 LLM 调用产生的 `(token, metadata)` 元组，包括增量的 tool call 构建过程

**数据结构**：

```python
# chunk 是一个 (AIMessageChunk, metadata) 元组
token, metadata = chunk
token.content          # 文本内容片段
token.tool_call_chunks # 正在构建的工具调用片段
```

**适合**：聊天 UI 中的"打字机"效果、需要最低延迟展示回复的场景、需要实时渲染 reasoning tokens 的深度思考模型。



```python
for (message, _) in agent.stream(
    {"messages": [HumanMessage("深圳的天气怎么样？")]},
    stream_mode="messages"
):
    if hasattr(message, "content") and message.content:
        print(message.content, end="", flush=True)
    print()
```



chunk 是一个 tuple  包含 `(message, metadata)` 两部分，结构如下：

```
(AIMessageChunk(content='', additional_kwargs={}, response_metadata={'model_provider': 'openai'}, id='lc_run--019d9a8f-3a4b-7463-8a5f-6c3b9593ea3f', tool_calls=[{'name': 'get_weather', 'args': {}, 'id': 'call_fe05bd1c44e9477e8a3e2e17', 'type': 'tool_call'}], invalid_tool_calls=[], tool_call_chunks=[{'name': 'get_weather', 'args': '', 'id': 'call_fe05bd1c44e9477e8a3e2e17', 'index': 0, 'type': 'tool_call_chunk'}]), {'langgraph_step': 1, 'langgraph_node': 'model', 'langgraph_triggers': ('branch:to:model',), 'langgraph_path': ('__pregel_pull', 'model'), 'langgraph_checkpoint_ns': 'model:dad2be80-d67e-e778-d3a6-c8ed285c79bc', 'checkpoint_ns': 'model:dad2be80-d67e-e778-d3a6-c8ed285c79bc', 'ls_provider': 'openai', 'ls_model_name': 'qwen3-max', 'ls_model_type': 'chat', 'ls_temperature': None})
--------------------
....
--------------------
(ToolMessage(content='小雨，26°C', name='get_weather', id='9849ec73-3423-4a22-806e-aee89d7e1a9f', tool_call_id='call_fe05bd1c44e9477e8a3e2e17'), {'langgraph_step': 2, 'langgraph_node': 'tools', 'langgraph_triggers': ('__pregel_push',), 'langgraph_path': ('__pregel_push', 0, False), 'langgraph_checkpoint_ns': 'tools:c97a8dbb-199b-d97a-6542-9fbdd1a52074'})
--------------------
(AIMessageChunk(content='', additional_kwargs={}, response_metadata={'model_provider': 'openai'}, id='lc_run--019d9a8f-3e89-7b62-bdbf-2190d9046109', tool_calls=[], invalid_tool_calls=[], tool_call_chunks=[]), {'langgraph_step': 3, 'langgraph_node': 'model', 'langgraph_triggers': ('branch:to:model',), 'langgraph_path': ('__pregel_pull', 'model'), 'langgraph_checkpoint_ns': 'model:12965b5a-14c7-aaef-4717-bccf3acd76de', 'checkpoint_ns': 'model:12965b5a-14c7-aaef-4717-bccf3acd76de', 'ls_provider': 'openai', 'ls_model_name': 'qwen3-max', 'ls_model_type': 'chat', 'ls_temperature': None})
--------------------
...
```



示例：

```python
# stream_mode="messages"
# 👉 只会流出 AI 的“生成过程”（token / chunk）
# ❌ 不会包含：HumanMessage、ToolMessage、完整 AIMessage
def stream_chat_messages(agent, session_id: str, message: str):
    config = {"configurable": {"session_id": session_id}}

    for token, metadata in agent.stream(
        {"messages": [HumanMessage(content=message)],},
        config=config,
        stream_mode="messages",
    ):
        yield token.content + "\n\n"
```



### 4.5.3 values (获取完整状态)

每一步输出完整状态，即消息累积，可理解为 updates 数据的累积

**SSE / 流式接口（推荐）:**

```python
seen_len = 0
for chunk in agent.stream(..., stream_mode="values"):
    messages = chunk["messages"]
    new_messages = messages[seen_len:] # 提取新消息
    seen_len = len(messages)
    for msg in new_messages:
        print(msg.content) # 仅处理新内容
```



每个步骤后流式传输状态的完整快照  完整的 state 对象，包含 `messages` 等所有字段

```python
## stream_mode="values" 下，chunk["messages"] 是“逐步递增的完整对话状态（state snapshot）”
def stream_chat_values(agent, session_id: str, message: str):
    config = {"configurable": {"session_id": session_id}}

    for chunk in agent.stream(
        {"messages": [HumanMessage(content=message)],},
        config=config,
        stream_mode="values",
    ):
        print(chunk)
        #
        msg = chunk["messages"][-1]
        # tool call
        if isinstance(msg, AIMessage) and msg.tool_calls:
            yield (
                "event: tool_call\n"
                f"data: {json.dumps(msg.tool_calls)}\n\n"
            )

        # tool result
        elif isinstance(msg, ToolMessage):
            yield (
                "event: tool_result\n"
                f"data: {msg.content}\n\n"
            )

        # normal output
        elif isinstance(msg, AIMessage) and msg.content:
            yield (
                "event: final_result\n"
                f"data: {msg.content}\n\n"
            )
```



示例：

```python
for chunk in agent.stream(
        {"messages": [HumanMessage("深圳的天气怎么样？")]},
        stream_mode="values"
):
    print("消息数量:", len(chunk["messages"]))  # 累计
    print("最后一条消息:", chunk["messages"][-1].content)  
```



chunk 是一个 `dict[str, list]`，结构如下，消息累积：

```
{'messages': [HumanMessage(content='深圳的天气怎么样？', additional_kwargs={}, response_metadata={}, id='b0f1f215-1a0c-4109-9124-68ccaa178bd5')]}
....
{'messages': [HumanMessage(content='深圳的天气怎么样？', additional_kwargs={}, response_metadata={}, id='b0f1f215-1a0c-4109-9124-68ccaa178bd5'), AIMessage(content='', additional_kwargs={'refusal': None}, response_metadata={'token_usage': {'completion_tokens': 21, 'prompt_tokens': 269, 'total_tokens': 290, 'completion_tokens_details': None, 'prompt_tokens_details': {'audio_tokens': None, 'cached_tokens': 0}}, 'model_provider': 'openai', 'model_name': 'qwen3-max', 'system_fingerprint': None, 'id': 'chatcmpl-9c744227-c4f1-9e60-8624-7326e88b45af', 'finish_reason': 'tool_calls', 'logprobs': None}, id='lc_run--019d9a97-b5a9-7640-9cb8-4ca4ea8798f1-0', tool_calls=[{'name': 'get_weather', 'args': {'location': '深圳'}, 'id': 'call_41b17cae9dea4ee6b51a48fb', 'type': 'tool_call'}], invalid_tool_calls=[], usage_metadata={'input_tokens': 269, 'output_tokens': 21, 'total_tokens': 290, 'input_token_details': {'cache_read': 0}, 'output_token_details': {}}), ToolMessage(content='小雨，26°C', name='get_weather', id='0acd5155-dce3-46a4-856d-25085b5a4460', tool_call_id='call_41b17cae9dea4ee6b51a48fb'), AIMessage(content='深圳目前的天气是小雨，气温为26°C。建议出门携带雨具，并注意防滑哦！', additional_kwargs={'refusal': None}, response_metadata={'token_usage': {'completion_tokens': 25, 'prompt_tokens': 311, 'total_tokens': 336, 'completion_tokens_details': None, 'prompt_tokens_details': {'audio_tokens': None, 'cached_tokens': 192}}, 'model_provider': 'openai', 'model_name': 'qwen3-max', 'system_fingerprint': None, 'id': 'chatcmpl-904dc925-b536-9bbf-9f29-67e5e006df25', 'finish_reason': 'stop', 'logprobs': None}, id='lc_run--019d9a97-bb19-7911-856f-4418e8e83175-0', tool_calls=[], invalid_tool_calls=[], usage_metadata={'input_tokens': 311, 'output_tokens': 25, 'total_tokens': 336, 'input_token_details': {'cache_read': 192}, 'output_token_details': {}})]}
```



### 3.5.4 custom (自定义进度信号)

在工具函数内部调用 `get_stream_writer()` 返回的 `writer`，可以向流中写入任意自定义数据。

**数据结构**：

```python
# 在工具函数内部
from langgraph.config import get_stream_writer
writer = get_stream_writer()
writer("已获取第 10/100 条记录")  # 任意 Python 对象

# 消费侧
{"type": "custom", "data": "已获取第 10/100 条记录"}
```

**适合**：工具内部进度上报（如批量 API 调用进度）、多步任务的心跳消息、不想改 state 结构却想向前端传信号的场景。

示例：

```python
from langgraph.config import get_stream_writer

def slow_tool(query: str) -> str:
    """模拟耗时操作的工具"""
    writer = get_stream_writer()
    
    writer(f"🔍 正在搜索：{query}")
    # 模拟搜索...
    writer("📊 找到 10 条相关结果")
    # 处理结果...
    writer("✅ 处理完成")
    
    return "这是最终结果"

# 使用 custom 模式接收工具发送的自定义消息
for custom_msg in agent.stream(
    {"messages": [{"role": "user", "content": "搜索 AI 新闻"}]},
    stream_mode="custom"
):
    print(custom_msg)  # 输出: 🔍 正在搜索... / 📊 找到... / ✅ 处理完成
```



### 3.5.5 组合使用

可以把多个模式以列表形式传入，流中会混合来自不同模式的 chunk，通过 `chunk["type"]` 字段区分来源。 [Langchain](https://docs.langchain.com/oss/python/langchain/streaming/overview)

```python
for chunk in agent.stream(input, stream_mode=["updates", "messages", "custom"]):
    if chunk["type"] == "updates":
        ...   # 步骤完成
    elif chunk["type"] == "messages":
        ...   # token 流
    elif chunk["type"] == "custom":
        ...   # 自定义信号
```



## 4.6 小结

| 概念     | Chain（链）      | Agent（代理）        |
| -------- | ---------------- | -------------------- |
| 流程     | 固定，编码时确定 | 动态，LLM 运行时决定 |
| 工具     | 无               | 可调用外部工具       |
| 适用场景 | 结构化任务       | 开放式问答、多步推理 |
| 复杂度   | 低               | 高                   |



# 5. 记忆系统

## 5.1 概念

AI Agent 记忆系统是由存储介质、索引机制、操作算法组成的技术体系，核心目标是：

- 维持单次会话的上下文连贯性 (短期记忆)
- 沉淀跨会话可复用的结构化知识 (长期记忆)
- 实现记忆的动态更新与智能调用，支撑 Agent 自主决策



按数据形态与存储特性分类：

| 记忆类型           | 定义                                       | 技术载体                           | 核心特性                               | 适用场景                          |
| ------------------ | ------------------------------------------ | ---------------------------------- | -------------------------------------- | --------------------------------- |
| 参数化记忆         | 嵌入 LLM 权重的隐式知识，预训练阶段习得    | 模型参数（GPT-4、Llama 3）         | 访问速度快，无法主动修改，提供常识支撑 | 基础问答、常识推理                |
| 上下文非结构化记忆 | 未固定格式的显式信息，涵盖多模态数据       | 上下文窗口（短期）、向量库（长期） | 支持跨模态整合，可动态增删，灵活性高   | 多轮对话、多模态交互（文本+图像） |
| 上下文结构化记忆   | 按预定义格式组织的显式知识，强调实体与关系 | 知识图谱（Neo4j）、关系库（MySQL） | 检索精度高，支持符号推理，可解释性强   | 企业协作、医疗问诊、精准信息查询  |



## 5.2 技术架构

**通用架构流程**，所有 Agent 记忆系统均遵循“数据流转-智能处理”的闭环架构，核心流程分为四步：

- **推理前加载**：根据当前用户查询，通过语义检索从长期记忆中提取相关信息 (如用户偏好、历史任务)
- **上下文注入**：将检索的长期记忆与当前会话的短期记忆融合，生成完整推理上下文
- **记忆更新**：LLM 完成响应后，自动提炼短期记忆中的有效信息 (如新增偏好、任务结论)，写入长期记忆
- **存储优化**：长期记忆模块通过压缩、索引、遗忘等操作，维持存储效率与数据有效性



**分层架构设计**，受操作系统虚拟内存启发，MemPT 提出“分层内存”架构，实现“无限上下文”能力，器架构分层如下：

- **主上下文 (Main Context)**：对应 LLM 原生上下文窗口，存储实时交互数据 (系统指令、当前对话、工具结果)，支持毫秒级访问
- **外部上下文 (External Context)**：分为归档存储 (Archival Storage) 和 调用存储 (Recall Storage) 存储非实时数据
- **内存管理器**：由 LLM 自主控制，通过函数调用实现数据在主上下文和外部上下文间的“分页加载/存储”，模拟人类内存管理逻辑



**多智能体写作架构**，MIRIX 采用“元管理者 + 专项管理者”架构，提升复杂记忆任务的处理效率：

- 元记忆管理者 (Meta Memory Manager)：负责任务分发、模块协调、检索路由，是记忆系统的“中枢”
- 专项管理者：6个功能模块各配专属管理者，负责该模块的记忆写入、检索、更新与优化
- 协作流程：优化输入触发元管理者分析，分发至相关专项管理者并行处理，最终汇总结果反馈给 Agent



## 5.3 核心组件

### 5.3.1 存储层：记忆的物理载体

**短期记忆存储**：

- **核心载体**：LLM 上下文窗口 (如 GPT-4 128K 窗口 ~ 6W 汉字)
- **存储内容**：用户输入、Agent响应、工具调用请求与结果、实时推理步骤
- **关键技术**：KV缓存优化 (动态丢弃低重要性 Token)、上下文隔离 (多 Agent 独立缓存)



**长期记忆存储**：

| 存储类型   | 技术载体                     | 核心优势                               | 适用场景                     |
| ---------- | ---------------------------- | -------------------------------------- | ---------------------------- |
| 向量存储   | Milvus、Pinecone、ChromaDB   | 支持语义相似性检索，适配非结构化数据   | 用户偏好、对话摘要、文档片段 |
| 结构化存储 | MySQL、PostgreSQL、Neo4j     | 支持精确查询与关系推理，数据可解释性强 | 用户档案、任务流程、实体关系 |
| 混合存储   | 向量库+关系库+对象存储（S3） | 兼顾语义检索与精确查询，适配多模态数据 | 企业级 Agent（客服、医疗）   |





## 5.4 关键技术

### 5.4.1 短期记忆优化：突破上下文窗口限制

短期记忆的核心痛点是 Token 超限与成本攀升，主流优化策略如下：

- **上下文缩减**：通过 LLM 生成对话摘要，保留核心信息 (如“用户想订巴黎市中心酒店，偏好印象派艺术”)，丢弃冗余细节
- **上下文卸载**：将长文本 (如工具输出、网页内容) 存入外部存储，上下文仅保留引用 ID，需用时按需加载
- **上下文隔离**：多 Agent 架构下，为不同任务子 Agent 分配独立上下文，避免信息交叉污染



### 5.4.2 长期记忆增强：跨会话复用与个性化

- **检索增强生成 (RAG)**
  - 核心流程：用户查询 -> 向量化 -> 向量库检索相关记忆 -> 与短期记忆融合 -> LLM 生成响应
  - 优化技巧：引用 Rerank 模型 (如 BERT-Reranker) 对检索结果二次筛选，提升相关性；结合知识图谱实现多跳推理 (如“用户喜欢印象派 -> 奥赛博物馆有印象派藏品 -> 推荐奥赛博物馆”)
- **多模态记忆支持**
  - 技术路径：通过多模态嵌入模型 (如 CLIP、BLIP) 将图像、音频等数据转化为统一维度向量，存入向量库
  - 应用场景：自动驾驶 Agent 存储道路图像与雷达数据，医疗 Agent 存储病历扫描件与检查影像
- **隐私合规保障**
  - 数据加密：静态数据采用 AES-256-GCM 加密，敏感信息单独加密存储
  - 本地存储：通过 SQLite、Milvus Lite 实现记忆数据本地部署，避免云端泄露
  - 合规技术：引入差分隐私 (注入噪声保护用户隐私)、联邦学习 (分布式训练不不汇集原始数据)



### 5.4.3 记忆一致性与冲突解决

- **一致性校验**：通过小模型检测新记忆与已有记忆的冲突 (如用户前后偏好矛盾)，触发人工确认或自动标记
- **时间衰减机制**：通过函数 e^(-λt) 对旧记忆降权，优先使用最新记忆；
- **优先级排序**：为记忆条目分配重要性评分（如用户显式指令>Agent 自动提炼），检索时按优先级排序。



```python
import asyncio
import os
import pandas as pd
import dotenv

from langchain_community.embeddings import DashScopeEmbeddings
from langchain_core.prompts import PromptTemplate
from langchain_milvus import Milvus
from langchain_openai import ChatOpenAI

dotenv.load_dotenv()


async def create_vector_store():
    # 初始化嵌入模型
    embeddings = DashScopeEmbeddings(
        model="text-embedding-v4",
        dashscope_api_key=os.getenv("DASHSCOPE_API_KEY"),
        # base_url=os.getenv("DASHSCOPE_BASE_URL"),
    )

    # 初始化 Milvus 向量库
    vector_store = Milvus(
        embedding_function=embeddings,
        collection_name="agent_memory",
        connection_args={"uri": "http://192.168.3.111:19530"},
        drop_old=True,
        auto_id=True,
        enable_dynamic_field=True,
    )

    return vector_store


async def add_long_term_memory(vector_store, user_id, content, memory_type="preference"):
    # 构建带元数据的记忆条目
    memory_text = f"{content}"
    metadata = {"user_id": user_id, "memory_type": memory_type, "timestamp": pd.Timestamp.now().isoformat()}

    # 写入向量库
    vector_store.add_texts(texts=[memory_text], metadatas=[metadata])
    print(f"长期记忆写入成功：{memory_text}")


async def retrieve_relevant_memory(vector_store, user_id, query, k=3):
    # 带过滤条件检索，仅检索当前用户的记忆
    results = vector_store.similarity_search_with_score(
        query=query,
        k=k,
        expr=f'user_id == "{user_id}"',  # Milvus 过滤表达式
    )

    # 格式化结果，保留相似度评分 >= 0.7 的
    relevant_memories = []
    for doc, score in results:
        if score > 0.7:
            relevant_memories.append(f"[相关记忆] {doc.page_content} (相似度：{score: .3f})")

    return "\n".join(relevant_memories)


async def update_memory(vector_store, user_id, old_content, new_content):
    # 检索旧记忆
    old_results = vector_store.similarity_search(
        query=old_content,
        k=1,
        expr=f'user_id == "{user_id}"',
    )
    if old_results:
        doc = old_results[0]
        doc.page_content = new_content
        vector_store.upsert(ids=[doc.id], documents=[doc])
        print(f"记忆更新成功：{old_content} -> {new_content}")


async def forget_memory(vector_store, user_id, memory_keyword):
    results = vector_store.similarity_search(
        query=memory_keyword,
        k=5,
        expr=f'user_id == "{user_id}"',
    )

    for doc in results:
        vector_store.delete([doc.id])
    print(f"已删除与{memory_keyword}相关的{len(results)}条记忆")


async def main():
    vector_store = await create_vector_store()

    # 写入记忆
    await add_long_term_memory(vector_store, "user123", "喜欢印象派艺术，计划2026年8月去巴黎旅行", "preference")
    await add_long_term_memory(vector_store, "user123", "埃菲尔铁塔是巴黎享誉全球的旅游景点", "preference")

    # 检索记忆
    query = "旅游景点"
    relevant_memory = await retrieve_relevant_memory(vector_store, "user123", query)
    print("检索到的相关记忆：", relevant_memory)

    # 更新记忆
    await update_memory(vector_store, "user123", "计划2026年8月去巴黎旅行", "计划2026年9月去巴黎旅行")


async def main2():
    llm = ChatOpenAI(
        api_key=os.getenv('DASHSCOPE_API_KEY'),
        base_url=os.getenv('DASHSCOPE_BASE_URL'),
        model="qwen-plus",
        temperature=0.3,  # 保证摘要稳定、不发散
        max_tokens=500
    )

    prompt_template = PromptTemplate(
        input_variables=["query", "relevant_memories", "chat_history"],
        template="""
    你是一个个性化旅行助手，需要结合用户的长期记忆提供定制化建议。
    相关长期记忆：
    {relevant_memories}
    
    本次会话历史：
    {chat_history}
    
    当前用户查询：{query}
    
    要求：基于上述信息，生成贴合用户需求的响应，不编造未提及的记忆。
    """
    )

    vector_store = await create_vector_store()
    await add_long_term_memory(vector_store, "user123", "埃菲尔铁塔是巴黎享誉全球的旅游景点", "preference")
    chat_history = []

    query = "计划的旅游景点"
    user_id = "user123"
    relevant_mem = await retrieve_relevant_memory(vector_store, user_id, query)
    print(relevant_mem)
    prompt = prompt_template.format(
        query=query,
        relevant_memories=relevant_mem or "无",
        chat_history=chat_history
    )

    response = llm.invoke(prompt)

    if "计划" in query or "喜欢" in query:
        await add_long_term_memory(vector_store, user_id, query)

    print(response.content)


if __name__ == "__main__":
    asyncio.run(main2())
```



## 5.5 `ChatMessageHistory`

### 5.5.1 底层消息存储机制

`ChatMessageHistory` 是 `LangChain` 中负责 **管理和操作聊天消息** 的底层工具类，是几乎所有对话内存的基础支持。

```python
from langchain.memory import ChatMessageHistory

history = ChatMessageHistory()
history.add_user_message("Hello")
history.add_ai_message("What can I do for you?")

print(history.messages)
```



### 5.5.2 消息存储选项

`ChatMessageHistory` 支持多种存储后端：

- **内存 (默认)**：临时存储，应用重启后丢失
- **Redis**：分布式持久化存储，适合生成环境
- **文件**：简单本地文件持久化
- **数据库**：SQL 或 NoSQL 数据库集成
- **自定义**：实现 `BaseChatMessageHistory` 接口



# 6. 补充

## 6.1 LangSmith

使用 LangChain 构建的许多应用程序都包含多个步骤，需要多次调用 LLM。随着这些应用程序变得越来越复杂，能够检查链或 Agent 内部的具体情况变得至关重要，最好的办法是使用 LangSmith

注册LangSmith，在Settings ➡️ API Keys 下创建 API-Key 并复制。之后在环境变量中添加以开始记录跟踪：

```
LANGSMITH_TRACING_v2="true"
LANGSMITH_API_KEY="..."
```

配置好环境变量之后，可在LangSmith 的 Tracing Projects 中查看跟踪记录。

LangSmith 默认将跟踪记录到 default 项目，可通过 LANGSMITH_PROJECT 环境变量设置 LangSmith 跟踪记录保存到哪个项目，如果该项目不存在则会创建。



## 6.2 提示词

```python
# 定义摘要提示词模板
summary_prompt = PromptTemplate(
    input_variables=["text"],
    template="""请对以下文本进行简洁、准确地摘要，要求：
1. 提取核心信息 (主题、关键观点、核心结论)；
2. 字数控制在100以内；
3. 语言简洁，不添加额外内容。

待摘要文本：
{text}
"""
    
# 定义摘要提示词模板
chunk_summary_prompt = PromptTemplate(
    input_variables=["text_chunk"],
    template="""请摘要以下文本片段的核心信息，要求：
1. 提取该片段的关键内容，不遗漏重要信息；
2. 字数控制在50以内；
3. 仅输出摘要内容，无其它废话。

文本片段：
{text_chunk}
"""
)

# 定义
total_summary_prompt = PromptTemplate(
    input_variables=["chunk_summaries"],
    template="""请将以下多个文本片段的摘要合并为一个完整、连贯的总摘要，要求：
1. 整合所有核心信息，逻辑清晰；
2. 字数控制在200以内；
3. 语言流畅，无重复信息。

各片段摘要：
{chunk_summaries}
"""
)
```



## 6.3 多 Agent 架构

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



