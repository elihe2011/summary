# 1. 简介

Model I/O 部分是与语言模型进行交互的核心组件，包括输入提示词 (Prompt Template)、调用模型 (Model)、输出解析 (Output Parser)。简单来说，就是输入、处理、输出这三个步骤。



## 1.1  调用模型

### 1.1.1 OpenAI

OpenAI 的 GPT 系列模型是大模型技术发展的开发范式和标准，无论是 Qwen、ChatGLM 等模型，它们的使用方法和函数调用逻辑级别遵循 OpenAI 定义的规范，没有太大差异。

```python
import os

from openai import OpenAI

client = OpenAI(
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

completion = client.chat.completions.create(
    model="qwen3.5-plus",
    messages=[{"role": "user", "content": "请将“你好”翻译成法语"}],
)

print(completion.choices[0].message.content)
```



### 1.1.2 LangChain

通过聊天模型接口访问 LLM，该接口通常以消息列表作为输入并返回一条消息作为输出：

- 输入：接收文本 `PromptValue` 或消息列表 `List[BaseMessage]`，每条消息需指定角色 (如 `SystemMessage`、`HumanMessage`、`AIMessage`)
- 输出：返回带角色的消息对象 (`BaseMessage` 子类)，通常是 `AIMessage`

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/chatmodel-input-output.png)



### 1.1.3 模型初始化参数

初始化一个模型最简单的方法就是使用 `init_chat_model`，并设置必要的参数。

| 参数        | 说明                                       |
| ----------- | ------------------------------------------ |
| model       | 模型名称或标识                             |
| base_url    | 模型API端点URL                             |
| api_key     | 模型API认证密钥                            |
| temperature | 控制模型输出的随机性，数字越大，随机性越强 |
| timeout     | 取消请求前，等待模型响应的最大时间，单位秒 |
| max_tokens  | 限制响应的总 tokens 数量，控制输出长度     |
| max_retries | 请求失败时，系统尝试重新发送请求的最大次数 |



### 1.1.4 对话模型的 Message

#### 1.1.4.1 文本提示

文本提示是字符串，适用于不需要保留对话历史的直接生成任务

```python
resp = llm.invoke("你好")
```



#### 1.1.4.2 消息提示

将消息对象列表输入模型，方便管理对话历史，包含系统指令以及处理多模态数据

```python
messages = [
    SystemMessage("你是个诗人"),
    HumanMessage("写首关于春天的诗"),
]
resp = llm.invoke(messages)
```



#### 1.1.4.3 字典格式

按照 `OpenAI` 聊天补全格式创建字典列表组成消息。一条消息通常包含 role、content、metadata

```python
messages = [
    {"role": "system", "content": "你是个诗人"},
    {"role": "user", "content": "写首关于春天的诗"}
]
resp = llm.invoke(messages)
```



#### 1.1.4.4 消息类型

| 消息类型           | 描述                                                         |
| ------------------ | ------------------------------------------------------------ |
| `SystemMessage`    | 一组初始指令，用于引导模型行为。可使用它来设定语气、定义模型的角色，并建立响应的指导方针 |
| `HumanMessage`     | 表示用户输入                                                 |
| `AIMessage`        | 模型生成的响应，包含文本内容、工具调用和元数据               |
|`ToolMessage`| 表示工具调用的输出 |



### 1.1.5 调用方法

聊天模型主要提供三种调用方法：

| 同步方法 | 异步方法 | 方法说明           |
| -------- | -------- | ------------------ |
| invoke   | ainvoke  | 单个输入，普通输出 |
| batch    | abatch   | 批量输入，普通输出 |
| stream   | astream  | 单个输入，流式输出 |



#### 1.1.5.1 输出模式

在 Langchain 中，语言模型的输出分为两种主要的模式：

- **非流式输出**：用户提交请求，然后等待结果，实现简单，单体验单调
- **流式输出**：用户提问发送后，系统就开始一字一句 (逐个token) 进行回复，更新是“实时对话”，更贴近人类交互的习惯



**1、非流式输出**

LangChain 与 LLM 交互时的默认行为，是最简单、最稳定的语言模型调用方式。当用户发出请求后，系统在后台等待模型生成完整响应，然后一次性将全部结果返回

```python
import os
from langchain.chat_models import init_chat_model

llm = init_chat_model(
    model="deepseek-v3.2",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

messages = [
    {"role": "system", "content": "你是一名数学家"},
    {"role": "user", "content": "请证明一下黎曼猜想"},
]

if __name__ == '__main__':
    resp = llm.invoke(messages)
    print(resp.content)
```



**2、流式输出**

流式输出是一种更具交互感的模型输出方式，用户不再需要等待完整答案，而是能看到模型逐个 token 地实时返回内容，适合构建强调 “实时反馈” 的应用

```python
import os
from langchain.chat_models import init_chat_model

llm = init_chat_model(
    model="deepseek-v3.2",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

messages = [
    {"role": "system", "content": "你是一名数学家"},
    {"role": "user", "content": "请证明一下黎曼猜想"},
]

if __name__ == '__main__':
    for chunk in llm.stream(messages):
        # 逐个打印内容块，并刷新缓冲区以即时显示内容
        print(chunk.content, end="", flush=True)
```



#### 1.1.5.2 批量调用

将一组独立的请求批量发送给模型并行处理

```python
import os
from langchain.chat_models import init_chat_model

llm = init_chat_model(
    model="deepseek-v3.2",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

messages = [
    [
        {"role": "system", "content": "你是一位诗人"},
        {"role": "user", "content": "写一首关于春天的诗"},
    ],
    [
        {"role": "system", "content": "你是一位物理学家"},
        {"role": "user", "content": "简单解释黑洞形成的原理"},
    ],
    [
        {"role": "system", "content": "你是一位环球旅行者"},
        {"role": "user", "content": "列出全球最值得去的十个地方"},
    ],
]

if __name__ == '__main__':
    resp = llm.batch(messages)
    for r in resp:
        print(r.content)
        print("-" * 50)
```

batch 默认没有依赖底层 API 的原生批量接口，而是使用线程池并执行多个 invoke()，所以它对 IO 密集型任务 (如调用远程 LLM API) 很有效



#### 1.1.5.3 同步/异步调用

- **同步调用**：每个操作依次执行，指导当前操作完成才开始下一个操作，消耗的时间是各个操作的时间总和
- **异步调用**：允许程序在等待某些操作时继续执行其它任务，而不是阻塞等待。处理 I/O 操作 (如网络请求、文件读写等) 时特别有用，可以显著提高程序的效率和响应性

```python
import asyncio
import os
import time

from langchain.chat_models import init_chat_model

llm = init_chat_model(
    model="deepseek-v3.2",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

messages = [
    [
        {"role": "system", "content": "你是一位诗人"},
        {"role": "user", "content": "写一首关于春天的诗"},
    ],
    [
        {"role": "system", "content": "你是一位物理学家"},
        {"role": "user", "content": "简单解释黑洞形成的原理"},
    ],
    [
        {"role": "system", "content": "你是一位环球旅行者"},
        {"role": "user", "content": "列出全球最值得去的十个地方"},
    ],
]

async def async_invoke():
    tasks = [llm.ainvoke(message) for message in messages]
    return await asyncio.gather(*tasks)


if __name__ == "__main__":
    start_time = time.time()

    resp = asyncio.run(async_invoke())
    for r in resp:
        print(r.content)
        print("-" * 50)

    end_time = time.time()
    print(f"Total time: {end_time - start_time}")
```

通过 `asyncio.gather()` 并行执行时，因为多个任务几乎同时开始，它们的执行时间将重叠。理想情况下，如果多个任务的执行时间相同，那么总执行时间应该接近单个任务的执行时间。



## 1.2 Prompt Template

### 1.2.1 提示词模板

提示词模板以字典作为输入，其中每个键代表要填充的提示模板中的变量，并输出一个 `PromptValue`，它可以传递给聊天模型，也可以转换未字符串或消息列表。`PromptValue` 存在的目的时为了方便地在字符串和消息直接切换。

常用的提示词模板有 `PromptTemplate` (字符串提示词模板) 和 `ChatPromptTmeplate` (聊天提示模板)



### 1.2.2 `PromptTemplate`

 `PromptTemplate` 用于快速构建包含变量的提示词模板，并通过传入不同的参数值生成自定义的提示词。

| 参数/方法         | 说明                                                         |
| ----------------- | ------------------------------------------------------------ |
| template          | 提示词模板，包含变量占位符                                   |
| input_variables   | 输入的变量名称列表                                           |
| partial_variables | 部分变量字典，用于预先填充模板，后续调用时无需再次传入这些变量 |
| format()          | 使用输入格式化提示                                           |



























