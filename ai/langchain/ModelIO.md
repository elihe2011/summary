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



#### 1.2.2.1 实例化

方式一：通过构造方法实例化

```python
from langchain_core.prompts import PromptTemplate

# 使用构造方法实例化提示词模板
template = PromptTemplate(
    template="请评价{product}的优缺点，包括{aspect1}和{aspect2}。",
    input_variables=["product", "aspect1", "aspect2"],
)

# 使用模板生成提示词
prompt1 = template.format(product="智能手机", aspect1="电池续航", aspect2="拍照质量")
prompt2 = template.format(product="笔记本电脑", aspect1="处理速度", aspect2="便携性")

if __name__ == "__main__":
    print(prompt1)
    print(prompt2)
```



方式二：通过 `from_template` 方法实例化

```python
from langchain_core.prompts import PromptTemplate

# 使用 from_template 方法实例化提示词模板
template = PromptTemplate.from_template("请评价{product}的优缺点，包括{aspect1}和{aspect2}。")

# 使用模板生成提示词
prompt = template.format(product="智能手机", aspect1="电池续航", aspect2="拍照质量")

if __name__ == "__main__":
    print(prompt)
```



#### 1.2.2.2 部分提示模板

方式一：指定 `partial_variables` 参数

```python
from langchain_core.prompts import PromptTemplate

template = PromptTemplate(
    template="{foo} {bar}",
    input_variables=["foo", "bar"],
    partial_variables={"foo": "hello"},   # 预定义部分变量默认值
)

# 使用模板生成提示词
prompt = template.format(bar="world")

if __name__ == "__main__":
    print(prompt)
```



方式二：使用 partial 方法指定默认值

```python
from langchain_core.prompts import PromptTemplate

template = PromptTemplate.from_template("{foo} {bar}")

# 预定义部分变量默认值
partial_template = template.partial(foo="hello")

# 使用模板生成提示词
prompt = partial_template.format(bar="world")

if __name__ == "__main__":
    print(prompt)
```



#### 1.2.2.3 调用方法

- `format()`：返回模板字符串
- `invoke()`：返回 `PromptValue` 对象，可使用 `to_string()` 方法将其转换为字符串

```python
from langchain_core.prompts import PromptTemplate

# 使用 from_template 方法实例化提示词模板
template = PromptTemplate.from_template("{foo} {bar}")

# PromptValue 对象
prompt = template.invoke({"foo": "hello", "bar": "world"})

# str 对象
prompt_str = prompt.to_string()

if __name__ == "__main__":
    print(prompt)
    print(prompt_str)
```



### 1.2.3  `ChatPromptTemplate`

`ChatPromptTemplate` 是创建聊天消息列表的提示模板，支持 System/Human/AI 等不同角色的消息模板



#### 1.2.3.1 实例化

messages 参数格式：

- `List[tuple]`
- `List[dict]`



方式一：通过构建方法创建

```python
from langchain_core.prompts import ChatPromptTemplate

template = ChatPromptTemplate(
    [
        ("system", "你是一个AI开发工程师，你的名字是{name}"),
        ("human", "你能帮我做什么？"),
        ("ai", "我能开发很多{thing}"),
        ("human", "{user_input}"),
    ]
)

prompt = template.format_messages(name="编程助手", thing="智能体", user_input="请帮忙开发一个Gin Web框架模板")

if __name__ == "__main__":
    print(prompt)
```



方式二：通过 `from_messages` 方法创建

```python
template = ChatPromptTemplate.from_messages(
    [
        ("system", "你是一个AI开发工程师，你的名字是{name}"),
        ("human", "你能帮我做什么？"),
        ("ai", "我能开发很多{thing}"),
        ("human", "{user_input}"),
    ]
)
```



#### 1.2.3.2 调用方法

```python
from langchain_core.prompts import ChatPromptTemplate

template = ChatPromptTemplate(
    [
        ("system", "你是一个AI开发工程师，你的名字是{name}"),
        ("human", "你能帮我做什么？"),
        ("ai", "我能开发很多{thing}"),
        ("human", "{user_input}"),
    ]
)

prompt = template.invoke({
    "name": "编程助手",
    "thing": "智能体",
    "user_input": "请帮忙开发一个Gin Web框架模板",
})

if __name__ == "__main__":
    print(prompt)
```



#### 1.2.3.3 消息占位符

当希望在格式化过程中插入消息列表时，比如 Agent 暂存中间步骤，需要使用 MessagePlaceholder，负责在特定位置添加消息列表

```python
from langchain_core.prompts import ChatPromptTemplate

template = ChatPromptTemplate.from_messages(
    [
        ("system", "你是一个助手"),
        ("placeholder", "{conversation}"),
        # 等价于 MessagePlaceholder(variable_name="conversation", optional=True)
    ]
)

prompt = template.format_messages(
    conversation=[
        ("human", "你好"),
        ("ai", "想让我帮你做些什么？"),
        ("human", "能帮我做一个冰淇淋吗？"),
        ("ai", "不能"),
    ]
)

if __name__ == "__main__":
    print(prompt)
```



#### 1.2.3.4 多模态提示词

可以使用提示模板来格式化多模态输入，比如将图片链接作为输入

```python
import os

from langchain.chat_models import init_chat_model
from langchain_core.prompts import ChatPromptTemplate

llm = init_chat_model(
    model="qwen3-vl-flash-2025-10-15",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

template = ChatPromptTemplate(
    [
        {"role": "system", "content": "用中文简短描述图片内容"},
        {"role": "user", "content": [{"image_url": "{image_url}"}]},
    ]
)

prompt = template.format_messages(
    image_url="https://media.geeksforgeeks.org/wp-content/uploads/20250825123558167415/LangChain.webp",
)

if __name__ == "__main__":
    resp = llm.invoke(prompt)
    print(resp.content)
```



### 1.2.4 外部加载 Prompt

将 prompt 保存为 JSON 或 YAML 等格式的文件，通过读取指定路径的格式化文件，获取相应的 prompt.



#### 1.2.4.1 json

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



#### 1.2.4.2 yaml

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



## 1.3 Output Parsers

LLM 返回的内容通常都是文本字符串，而实际 AI 应用开发一般希望模型可以返回更直观、更格式化的内容，LangChain 提供输出解析器 (`OutputParser`) 讲模型输出解析为结构化数据



### 1.3.1 `StrOutputParser`

`StrOutputParser` 是一个简单的解析器，从结果中提取 content 字段

```python
import os

from langchain.chat_models import init_chat_model
from langchain_core.output_parsers import StrOutputParser

llm = init_chat_model(
    model="qwen3-vl-flash-2025-10-15",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

messages = [
    {"role": "system", "content": "你是一个机器人"},
    {"role": "user", "content": "你好"},
]

if __name__ == "__main__":
    resp = llm.invoke(messages)
    print(resp)

    # 等效于 resp.content
    result = StrOutputParser().invoke(resp)
    print(result)
```



### 1.3.2 `JsonOutputParser`

`JsonOutputParser` 能够结合 Pydantic 模型进行数据验证，自动验证字段类型和内容 (如字符串、数字、嵌套对象等)

```python
import os

from langchain.chat_models import init_chat_model
from langchain_core.output_parsers import JsonOutputParser
from pydantic import BaseModel, Field

llm = init_chat_model(
    model="qwen3-vl-flash-2025-10-15",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

class Prime(BaseModel):
    prime: list[int] = Field(description="素数")
    count: list[int] = Field(description="小于该素数的素数个数")

json_parser = JsonOutputParser(pydantic_object=Prime)
print(json_parser.get_format_instructions())

messages = [
    {"role": "system", "content": json_parser.get_format_instructions()},
    {"role": "user", "content": "任意生成5个1000-100000之间素数，并标出小于该素数的素数个数"},
]

if __name__ == "__main__":
    resp = llm.invoke(messages)
    print(resp)

    json_result = json_parser.invoke(resp)
    print(json_result)
```



## 1.4 Structured Outputs

### 1.4.1 TypedDict

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



### 1.4.2 Pydantic

Pydantic 模型提供了丰富的功能集，包括字段验证、描述和嵌套结构

```python
from pydantic import BaseModel, Field

class Animal(BaseModel):
    animal: str = Field(description="动物")
    emoji: str = Field(description="表情")

class AnimalList(BaseModel):
    animals: list[Animal] = Field(description="动物与表情列表")
```



### 1.4.3 JSON Schema

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































