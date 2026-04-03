# 1. Runnable 和 LCEL

## 1.1 Runnable

Runnable 是 LangChain 中可以调用、批处理、流式传输、转换和组合的工作单元。

Runnable 接口时使用 LangChain 组件的基础，它在许多组件中实现。如语言模型、输出解析器、检索器、编译的 LangGraph 图等

Runnable 接口强制要求所有 LCEL 组件实现一组标准方法：

| 方法             | 功能                     |
| ---------------- | ------------------------ |
| invoke / ainvoke | 将单个输入转换为输出     |
| batch / abatch   | 批量将多个输入转换为输出 |
| stream / astream | 从单个输入生成流式输出   |

假设没有统一调用方式，每个组件调用方式不同，组合时需要手动适配：

- 提示词渲染 `.format()`
- 模型调用 `.generate()`
- 解析器解析 `.parse()`
- 工具调用 `.run()`

代码会变成：

```python
prompt_text = prompt.format(topic="春天")
model_out = model.generate(prompt_text)
result = parser.parse(model_out)
```

Runnable 统一调用方式：

```python
# 分布调用
prompt_text = prompt.invoke({"topic": "春天"})
model_out = model.invoke(prompt_text)
result = parser.invoke(model_out)

# LCEL管道式
chain = prompt | model | parser
result = chain.invoke({"topic": "春天"})
```



## 1.2 LCEL

LCEL (LangChain Expression Language) 是一种从现有的 Runnable 构建新的 Runnable 的声明式方法，用于声明、组合和执行各种组件 (模型、提示、工具、函数等)

使用 LCEL 创建的 Runnable 为“链”，“链”本身就是 Runnable。

LCEL 的两个主要组合原语：

- `RunnableSequence`  可运行序列
- `RunnableParallel` 可运行并行



# 2. `RunnableSequence` 

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



# 3. `RunnableParallel`

`RunnableParallel`支持同时运行多个可运行对象，并为每个对象提供相同的输入

- 同步执行：使用 `ThreadPoolExecutor` 来同时执行可运行对象
- 异步执行：使用 `asyncio.gather` 来同时执行可运行对象

在 LCEL 表达式中，字典会自动转换为 `RunnableParallel`

```python
import os

from langchain.chat_models import init_chat_model
from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import PromptTemplate
from langchain_core.runnables import RunnableParallel

llm = init_chat_model(
    model="qwen3-vl-flash-2025-10-15",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

joke_chain = (
    PromptTemplate.from_template("讲一个关于{topic}的笑话") | llm | StrOutputParser()
)

poem_chain = (
    PromptTemplate.from_template("写一首关于{topic}的诗歌") | llm | StrOutputParser()
)

map_chain = RunnableParallel(joke=joke_chain, poem=poem_chain)

if __name__ == "__main__":
    resp = map_chain.invoke({"topic": "cat"})
    print(resp)
```



# 4. `RunnableLambda`

`RunnableLambda` 将 Python 可调用函数转换为 Runnable，使得函数可以在同步或异步上下文中使用

```python
from langchain_core.runnables import RunnableLambda

chain = {
    "text1": lambda x: x + " world",
    "text2": lambda x: x + ", how are you",
} | RunnableLambda(lambda x: len(x["text1"]) + len(x["text2"]))

if __name__ == '__main__':
    result = chain.invoke("hello")
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



# 5. `RunnablePassthrough`

`RunnablePassthrough` 接收输入并将其原样输出。它是 LCEL 体系中的“无操作节点”，用于在流水线中透传输入或保留上下文，也可以用于输出中添加键

示例：保留中间结果

```python
from langchain_core.runnables import RunnableParallel, RunnablePassthrough

chain = RunnableParallel(
    original=RunnablePassthrough(), # 保留中间结果
    word_count=lambda x: len(x),
)

if __name__ == "__main__":
    result = chain.invoke("hello world")
    print(result)  # {'original': 'hello world', 'word_count': 11}
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



# 6. `RunnableBranch`

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



# 7. `RunnableWithFallbacks`

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



