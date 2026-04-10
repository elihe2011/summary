# 1. 引言

## 1.1 简介

LangChain 是一个用于构建智能应用的框架，它让大语言模型 (如 ChatGPT、Llama、Claude 等) 能够更好地记忆、思考、规划，并与各种外部工具 (数据库、API、搜索引擎等) 进行交互。

核心能力：

- **记忆能力**：记住上一次的聊天记录
- **数据能力**：访问数据库查询信息
- **行动能力**：自动执行任务，比如帮你查询天气、发邮件等
- **思考能力**：进行复杂的推理，比如分步规划解决问题



## 1.2 应用场景

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



## 1.3 架构

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/langchain-overall-arch.png)

- **Langchain**：帮助快速构建 Agent，支持选择任何模型提供商
- **LangGraph**：允许通过低级编排、记忆和人工参与支持来控制自定义 Agent 的每一步。可以管理具有持久执行能力的场时间允许任务
- **LangSmith**：一个帮助 AI 团队使用实时生成数据进行持久测试和改进的平台，提供观测、评估与部署功能
- **Deep Agents**：用于构建能够规划、使用子  Agent 并利用文件系统处理复杂任务的 Agent，受 Claude Code、Deep Research 和 Manus 等引用启发



常用依赖包：

| 包                       | 描述                                            |
| ------------------------ | ----------------------------------------------- |
| langchain                | 包含构建使用 LLM 的应用所需的所有实现的主入口点 |
| langchain-core           | LangChain 生态系统中的核心接口和抽象            |
| langchain-text-splitters | 用于文档处理的文本分割工具                      |
| langchain-mcp-adapters   | 在 LangChain 和 LangGraph 应用中提供 MCP 工具   |
| langchain-tests          | 用于验证 LangChain 集成包实现的标准化测试套件   |
| langchain-classic        | 遗留的 langchain 实现和组件                     |



# 2. 开发架构

## 2.1 RAG

大模型存在的问题：

- **知识冻结**：随着 LLM 规模扩大，训练成本和周期相应增加，模型无法实时学习到最新的信息或动态变化，导致 LLM 难以应付诸如 “请推荐最近热门的十条新闻” 等时间敏感的问题
- **幻觉**：LLM 从未在训练过程中学习过的信息时，大模型无法给出准确的答复，转而开始臆想和编造答案

RAG 能够为 LLM 提供一些提示和参考，让 LLM 能够更准确回答问题。



## 2.2 Agent

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



## 2.3 应用场景

### 2.3.1 纯 Prompt

Prompt 是操作大模型的唯一接口，一问一答

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/agent-app-scenario-prompt.png)



### 2.3.2 Agent + Function Calling

- **Agent**：AI 主动提要求
- **Function Calling**：对接外部系统是，AI 要求执行某个函数

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/agent-app-scenario-func-calling.png)



### 2.3.3 RAG (Retrieval-Augmented Generation)

- **RAG**：需要补充领域知识时使用
- **Embeddings**：把文字转换为更易于相似度计算的编码
- **向量数据库**：存储 Embedding 编码的向量
- **向量搜索**：根据输入向量，找到最相似的向量

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/agent-app-scenario-rag.png)



### 2.3.4 Fine-tuning （微调）

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/agent-app-scenario-fine-tuning.png)



### 2.3.5 场景选择

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/agent-app-scenario-choices.png)



## 2.4 核心组件

LangChain 的核心组件主要涉及四个部分：Model I/O、Chains、RAG、Agents



### 2.4.1 Model I/O

标准化大模型的输入和输出，包含提示模板、模型调用和格式化输出

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/model-io.png)

- **Format**：通过模板管理大模型的输入，将原始数据格式化成模型可以处理的形式，插入到一个模板中，然后送入模型进行处理
- **Predict**：调用 LLM，进行预测或生成回答
- **Parse**：规范化模型输出，比如将模型输出格式化为 JSON



### 2.4.2 Chains

"链" 用于将多个组件组合成一个完整的流程，方便链式调用



### 2.4.3 Retrieval

对应 RAG：检索外部数据，作为参考信息输入 LLM 辅助生成答案

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/RAG-flow.png)

- **Source**：多种类型的数据源，如视频、图片、文本、代码、文档等
- **Load**：将多源异构数据统一加载为文档对象
- **Transform**：对文档进行转换和处理，比如将文本切分为小块
- **Embed**：将文本编码为向量
- **Store**：将向量化的数据存储起来
- **Retrieve**：将文本库中检索相关的文本段落



### 2.4.4 Agents

**Agent 自主规划执行步骤，并使用工具来完成任务**

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/agent-diagram.png)









# 2. 环境搭建

## 2.1 Python 虚拟环境

```bash
# 创建
conda create -n langchain-env python=3.13

# 激活
conda activate langchain-env

# 升级pip
pip install --upgrade pip
```



## 2.2 依赖库

```bash
# 核心库
pip install langchain
pip show langchain
```



其它可选库：

| 集成场景               | 安装命令                          | 适用场景                     |
| ---------------------- | --------------------------------- | ---------------------------- |
| OpenAI系列模型         | `pip install langchain-openai`    | 调用GPT-3.5/4、Embedding模型 |
| 本地开源模型（Ollama） | `pip install langchain-ollama`    | 对接Llama3/Qwen2等本地模型   |
| 深度求索 (Deepseek)    | `pip install langchain-deepseek`  | 国内模型适配                 |
| 向量存储（Chroma）     | `pip install langchain-chroma`    | RAG场景必备                  |
| 文档加载（PDF/Word）   | `pip install langchain-community` | 加载各类文档                 |





LangChain 官方文档明确支持以下核心 Agent 类型，适配不同场景：

| Agent 类型             | 核心特点                                                     | 适用场景                            | 来源（官方文档）                         |
| ---------------------- | ------------------------------------------------------------ | ----------------------------------- | ---------------------------------------- |
| ReAct Agent（MRKL）    | 遵循“思考（Thought）→ 行动（Action）→ 观察（Observation）”循环，结合推理与动作 | 复杂多步骤任务、需要可解释性的场景  | JavaScript/Go/Python 官方文档            |
| OpenAI Functions Agent | 依赖 OpenAI 函数调用能力，支持结构化工具参数传递，减少解析错误 | 需精准调用工具（如 API 传参）的场景 | Go 官方文档（tmc.github.io/langchaingo） |
| Conversational Agent   | 支持多轮对话上下文，动态调用工具时维持对话连贯性             | 聊天型应用、需要上下文交互的任务    | Go 官方文档、Python 中文文档             |
| Plan-and-Execute Agent | 先通过 LLM 生成任务计划（分步骤），再按计划迭代执行工具      | 长期规划类任务（如“写一篇论文”）    | Python 中文文档、Go 官方文档             |
| Zero-shot Agent        | 无需训练，仅通过工具描述和用户输入选择工具，无历史记忆       | 简单多工具调用任务                  | Python 中文文档                          |



# 3. Agent

LangChain Agent 无论多复杂，核心离不开以下三个部分：

| 组件              | 作用                                                         | 类比                       |
| ----------------- | ------------------------------------------------------------ | -------------------------- |
| LLM（大语言模型） | Agent 的“大脑”，负责决策“是否调用工具”“调用哪个工具”         | 人类的思考中枢             |
| Tool（工具）      | Agent 可执行的具体功能（如计算、查询），需定义名称、描述、执行逻辑 | 人类的手/计算器/手机       |
| Agent 模板        | 定义 LLM 的决策逻辑（“思考→行动→观察→总结”）                 | 人类的决策流程（先想再做） |
|                   |                                                              |                            |



实现两个数字加减法运算 Agent:

```python
import os

import dotenv
from langchain_openai import ChatOpenAI
from langchain.agents import create_agent
from langchain.tools import tool

dotenv.load_dotenv()


# 核心工具：加法计算
@tool
def add_numbers(numbers: list[float]) -> float:
    """计算两个数字的加法。输入必须是包含两个数字的列表。"""
    if len(numbers) != 2:
        raise ValueError("必须提供两个数字")
    return numbers[0] + numbers[1]


@tool
def subtract_numbers(numbers: list[float]) -> float:
    """计算两个数字的 减法，输入必须是包含两个数字的列表"""
    if len(numbers) != 2:
        raise ValueError("必须提供两个数字")
    return numbers[0] - numbers[1]


# 配置 LLM (Agent 的大脑)
llm = ChatOpenAI(
    api_key=os.getenv('DASHSCOPE_API_KEY'),
    base_url=os.getenv('DASHSCOPE_BASE_URL'),
    # model="qwen-plus",
    model="deepseek-r1",
    # model="glm-5",
    temperature=0    # 保证决策稳定，避免随机输出
)

# 提示词模板 (决策逻辑)
prompt = """
你是一个极简的智能代理，仅能调用 add_numbers 工具完成加法计算任务。

规则：
1. 只能调用 add_numbers
2. 输入必须是两个数字组成的列表，例如：[1, 2]
3. 如果问题不是两个数字的加法，回复：
    “仅支持两个数字的加法计算，请调整问题”    
"""

system_prompt = """
你是一个计算代理。

规则：
- 只要用户问题中出现两个数字并表示加法，就调用 add_numbers
- 只要用户问题中出现两个数字并表示减法，就调用 subtract_numbers
- 禁止直接给出答案
"""


# 创建 Agent， 绑定 LLM、工具、决策提示词
agent = create_agent(
    model=llm,
    tools=[add_numbers, subtract_numbers],
    system_prompt=system_prompt
)


if __name__ == "__main__":
    print("====== 测试用例1：加法计算")
    messages =  {"messages": [{"role": "user", "content": "2 加 7 等于多少？"}]}
    result = agent.invoke(messages)
    print(result)
    print(result["messages"][-1].content)

    print("====== 测试用例2：非加法计算")
    messages2 = {"messages": [{"role": "user", "content": "今天的气温是多少度？"}]}
    result = agent.invoke(messages2)
    print(result)
    print(result["messages"][-1].content)

    print("====== 测试用例3：减法计算")
    messages3 = {"messages": [{"role": "user", "content": "8 减 3 等于多少？"}]}
    result = agent.invoke(messages3)
    print(result)
    print(result["messages"][-1].content)
```



Agent 执行流程：

```json
{'messages': 
    [
        HumanMessage(
            content='1 加 7 等于多少？', 
            additional_kwargs={}, 
            response_metadata={}, 
            id='afd2571b-c8c6-4380-aefc-e1ff03c7f975'
        ), 
        AIMessage(
            content='', 
            additional_kwargs={'refusal': None}, 
            response_metadata={
                'token_usage': {
                    'completion_tokens': 23, 
                    'prompt_tokens': 212, 
                    'total_tokens': 235, 
                    'completion_tokens_details': None, 
                    'prompt_tokens_details': {
                        'audio_tokens': None, 
                        'cached_tokens': 0
                    }
                }, 
                'model_provider': 'openai', 
                'model_name': 'qwen-plus', 
                'system_fingerprint': None, 
                'id': 'chatcmpl-31ae60b0-94f4-9469-9a8b-555f9d1be7f0', 
                'finish_reason': 'tool_calls', 
                'logprobs': None
            }, 
            id='lc_run--019cac9a-dfc7-7310-9b2f-06852d0446fd-0', 
            tool_calls=[
                {
                    'name': 'add_numbers', 
                    'args': {
                        'numbers': [1, 7]
                    }, 
                    'id': 'call_7f7849c52f0942f1a11e18', 
                    'type': 'tool_call'
                }
            ], 
            invalid_tool_calls=[], 
            usage_metadata={
                'input_tokens': 212, 
                'output_tokens': 23, 
                'total_tokens': 235, 
                'input_token_details': {'cache_read': 0}, 
                'output_token_details': {}
            }
        ), 
        ToolMessage(
            content='8.0', 
            name='add_numbers', 
            id='19632704-d2cb-4677-9f43-08366b631ae8', 
            tool_call_id='call_7f7849c52f0942f1a11e18'
        ), 
        AIMessage(
            content='1 加 7 等于 8。', 
            additional_kwargs={'refusal': None}, 
            response_metadata={
                'token_usage': {
                    'completion_tokens': 11, 
                    'prompt_tokens': 252, 
                    'total_tokens': 263, 
                    'completion_tokens_details': None, 
                    'prompt_tokens_details': {'audio_tokens': None, 'cached_tokens': 0}
                }, 
                'model_provider': 'openai', 
                'model_name': 'qwen-plus', 
                'system_fingerprint': None, 
                'id': 'chatcmpl-e23afe22-7c8a-9a2a-acb1-26c2ee071b0d', 
                'finish_reason': 'stop', 
                'logprobs': None
            }, 
            id='lc_run--019cac9a-e3ba-7d30-a5ad-6c0a57a878c8-0', 
            tool_calls=[], 
            invalid_tool_calls=[], 
            usage_metadata={
                'input_tokens': 252, 
                'output_tokens': 11, 
                'total_tokens': 263, 
                'input_token_details': {'cache_read': 0}, 
                'output_token_details': {}
            }
        )
    ]
}
```



# 4. LLMChain

LLMChain 的核心是 ”提示词模板 (PromptTemplate) + 大模型 (LLM)“ 的流水线，实现文本摘要的逻辑：

- **定义摘要提示词模板**：明确告诉模型”要做什么“ (如"简洁摘要、提取核心信息")；
- **初始化大模型**：选择模型并初始化；
- **构建 LLMChain**：将模板和模型串联，形成”输入文本 -> 生成摘要“的闭环；
- **长文本适配**：若超出模型上下文窗口，先分段 -> 逐段摘要 -> 合并总摘要。



**LangChain 0.x 架构 (经典链式设计)**：

```
+----------------+       +----------------+       +-----------------+
|  PromptTemplate|  ---> |    LLMChain    |  ---> | Output / Parser |
+----------------+       +----------------+       +-----------------+
        |                        |
        |                        v
        |                  可选：tools / agent
        |                        |
        v                        v
 User Input  ----------------->  Agent (ReAct)
```

特点：

- **PromptTemplate** 负责格式化用户输入
- **LLMChain** 负责把 prompt 送给 LLM
- **Agent / ReAct** 可以手动拼 Action / Scratchpad
- `.run()` 是核心方法
- 逻辑链条固定，扩展性有限



**LangChain 1.x LCEL 架构 (Runnable + LCEL)**:

```
 User Input
      |
      v
+----------------+
| PromptTemplate | (langchain_core.prompts)
+----------------+
      |
      v
+----------------+
|      LLM       | (ChatOpenAI / OpenAI)
+----------------+
      |
      v
+----------------+
| OutputParser   | (可选)
+----------------+
      |
      v
+----------------+
|    Agent       | (create_agent)
+----------------+
      |
      v
Tools / Tool Calls (function-calling)
```

特点：

- **PromptTemplate** → `langchain_core.prompts.PromptTemplate`
- **LLM** → `ChatOpenAI` / `OpenAI` / 其他兼容 LLM
- **Agent** → `create_agent`，接收 LLM + Tools + System Prompt
- **工具调用** → 通过 function-calling 自动触发
- **组合方式** → 使用 `|` 或 `invoke()`，不再用 `.run()`
- **链条可组合** → `prompt | llm | output_parser | agent`



**Agent 在 LCEL 中的位置**：

```
                   +----------------+
User Input ------> |   SystemPrompt | 
                   +----------------+
                           |
                           v
                   +----------------+
                   |      LLM       |
                   +----------------+
                           |
                  +--------+--------+
                  |                 |
                  v                 v
           Tool Calling         Direct Text Output
           (JSON)                  (optional)
           AddNumbers, etc.
```

说明：

- Agent 本质是 **LLM + Tools + System Prompt 的组合**
- LLM 决定是否调用工具（通过 function-calling）
- Agent 不是单独链条，而是 LCEL 流程的一部分
- 工具调用与 LLM 的输出是结构化的 JSON
- 传统的 ReAct Text（`Action / Action Input / scratchpad`）属于 0.x 风格



**核心差异总结：**

| 特性          | 0.x              | 1.x LCEL                         |
| ------------- | ---------------- | -------------------------------- |
| Prompt        | PromptTemplate   | PromptTemplate (langchain_core)  |
| 链            | LLMChain         | Runnable /                       |
| Agent / ReAct | 手动拼文本       | create_agent + Tools + LLM       |
| 工具调用      | Action/Text 模拟 | function-calling JSON            |
| 输出方式      | run() / text     | invoke() / tool_calls / messages |
| 扩展性        | 链条固定         | 高，可组合各种 Runnable          |



为什么 LLMChain 被移除？

LangChain 1.x 架构改成：

```
Prompt → Model → Parser
```

全部统一成 Runnable 接口。

核心思想：

```
prompt | model | output_parser
```

而不是：

```
LLMChain(...)
```



## 4.1 短文本

```python
import os

import dotenv
from langchain_openai import ChatOpenAI
from langchain_core.prompts import PromptTemplate


dotenv.load_dotenv()


# 初始化大模型
llm = ChatOpenAI(
    api_key=os.getenv('DASHSCOPE_API_KEY'),
    base_url=os.getenv('DASHSCOPE_BASE_URL'),
    model="qwen-plus",
    temperature=0.3,    # 保证摘要稳定、不发散
    max_tokens=500
)


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
)


if __name__ == '__main__':
    # 待摘要短文本
    # raw_text = """
    # LangChain是一个用于构建大语言模型应用的开源框架，核心功能包括提示词工程、链（Chains）、代理（Agents）、记忆（Memory）和检索增强生成（RAG）。
    # 它支持对接OpenAI、文心一言、Llama3等主流大模型，还提供了丰富的工具集成（如数据库、API调用），帮助开发者快速搭建智能问答、文本摘要、知识库等应用。
    # """

    raw_text = """
LangChain是2022年推出的开源大模型应用开发框架，旨在简化基于LLM的复杂应用构建。其核心设计理念是“模块化”，将大模型应用的核心环节拆分为可复用的组件。
    首先是模型层（Models），LangChain支持对接几乎所有主流大模型，包括闭源的OpenAI GPT系列、Anthropic Claude，开源的Llama3、Qwen2，以及国内的文心一言、讯飞星火等。开发者只需通过统一的接口，即可切换不同模型，无需修改核心代码。
    其次是提示词工程（Prompts），LangChain提供了丰富的PromptTemplate模板，支持动态变量替换、提示词优化，还内置了FewShotPromptTemplate等高级模板，帮助开发者快速构建高质量提示词。
    链（Chains）是LangChain的核心组件之一，LLMChain是最基础的链，用于串联提示词和模型；SequentialChain可将多个链按顺序执行；RouterChain能根据输入自动选择合适的链，满足复杂任务需求。
    代理（Agents）则是LangChain的进阶功能，它让模型具备“自主决策”能力——能分析用户需求，选择合适的工具（如数据库查询、API调用、代码执行），并迭代执行直到完成任务，典型应用包括智能编程助手、自动化数据分析工具等。
    记忆（Memory）模块用于维护对话上下文，支持短期记忆（上下文窗口）和长期记忆（向量库存储），让大模型应用具备“记忆能力”，能理解跨轮对话中的指代和上下文关联。
    此外，LangChain还提供了检索增强生成（RAG）相关组件，包括文档加载器、文本分割器、向量存储、检索器等，帮助开发者快速搭建知识库问答系统，解决大模型“幻觉”问题。
    LangChain的生态还在不断扩展，目前已支持Python和JavaScript两种主流语言，并有丰富的第三方插件和集成工具，成为大模型应用开发的主流框架之一。    
    """

    # 执行链
    chain = summary_prompt | llm

    # 生成摘要
    result = chain.invoke({"text": raw_text})
    print(result)
```



## 4.2 长文本

```python
import os

import dotenv
from langchain_openai import ChatOpenAI
from langchain_core.prompts import PromptTemplate


dotenv.load_dotenv()


# 初始化大模型
llm = ChatOpenAI(
    api_key=os.getenv('DASHSCOPE_API_KEY'),
    base_url=os.getenv('DASHSCOPE_BASE_URL'),
    model="qwen-plus",
    temperature=0.3,    # 保证摘要稳定、不发散
    max_tokens=500
)


def split_long_text(text: str, chunk_size: int = 1000) -> list:
    chunks = []
    start = 0
    text_len = len(text)

    while start < text_len:
        end = start + chunk_size

        # 避免截断句子，按句号简单处理
        if end < text_len:
            end = text.rfind("。", start, end) + 1
            # 未找到句号，直接截断
            if end < text_len:
                end = start + chunk_size

        chunks.append(text[start:end])
        start = end

    return chunks


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


# 创建分段摘要链、总摘要链
chunk_chain = chunk_summary_prompt | llm
total_chain = total_summary_prompt | llm


def long_text_summary(long_text: str) -> str:
    text_chunks = split_long_text(long_text, chunk_size=1000)
    print(f"长文本分段完成，共{len(text_chunks)}段")

    # 分段摘要
    chunk_summaries = []
    for i, chunk in enumerate(text_chunks):
        print(f"\n正在摘要第{i+1}段 ...")
        chunk_summary = chunk_chain.invoke({"text_chunk": chunk})
        chunk_summaries.append(chunk_summary)
        print(f"第{i+1}段摘要：{chunk_summary}")

    # 合并摘要
    chunk_summaries_str = "\n".join([f"{i+1}. {s}" for i, s in enumerate(chunk_summaries)])
    total_summary = total_chain.invoke({"chunk_summaries": chunk_summaries_str})
    return total_summary.content


if __name__ == "__main__":
    long_text_raw = """
    
"""

    final_summary = long_text_summary(long_text_raw)
    print(final_summary)
```



# 5. 记忆系统

## 5.1 基础概念

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



主流框架记忆模块对比：

| 框架       | 短期记忆组件             | 长期记忆组件                | 核心设计特点                     |
| ---------- | ------------------------ | --------------------------- | -------------------------------- |
| LangChain  | ConversationBufferMemory | 外挂式 Long-Term Memory     | 需手动集成外部存储，灵活性高     |
| AgentScope | Memory模块               | LongTermMemory组件          | API 层面分离，功能边界清晰       |
| MemGPT     | 主上下文（Main Context） | 外部上下文（归档/调用存储） | 模拟OS内存管理，支持“无限上下文” |
| Google ADK | Session                  | Long-Term Knowledge         | 长期记忆为独立可搜索知识库       |



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



### 5.3.2 索引层：高效检索的核心支撑

索引层的核心目标是解决“大规模记忆快速定位”问题，主流技术如下：

- **FLAT 索引**：暴力搜索算法，计算查询向量与所有存储向量的距离，召回率 100% 但时间复杂度 O(N)，仅适用于小规模数据 (<10W条)
- **HNSW 索引**：分层导航小世界图算法，通过多层稀疏/密集图结构实现近似最近邻搜索，检索延迟毫秒级，支持10亿级数据
  - 关键参数：M(最大出度，控制图导航性)、efConstruction(构建时搜索范围)、efSearch(查询时搜索范围)
  - 调用原则：M=16-32、efConstruction=200-400、efSearch=50-100，平衡召回率与延迟
- **混合索引**：结合向量索引与结构化索引 (如用户ID、时间戳过滤)，提升检索精度与效率



### 5.3.3 操作层：记忆的全生命周期管理

记忆系统通过 6 种核心操作实现全生命周期管理，分为“记忆管理”和“记忆利用”两大类：

- **记忆操作管理**
  - **巩固 (Consolidation)**：将短期记忆转化为长期记忆，如通过 LLM 生成对话摘要存入向量库，或提取实体关系构建知识图谱
  - **索引 (Indexing)**：为长期记忆构建辅助索引，如为向量数据库构建 HNSW 索引，为结构化数据建立 SQL 索引
  - **更新 (Updating)**：动态修正记忆内容，如用户偏好变更时，标记旧记忆失效并写入新记忆，或通过增量学习更新知识图谱
  - **遗忘 (Forgetting)**：清理无效/敏感记忆，策略包括时间衰减 (长期未访问数据归档)、重要性评分 (淘汰低价值记忆)、用户主动删除 (支持“被遗忘权”)
- **记忆利用操作**
  - **检索 (Retrieval)**：基于语义相似性或精确条件提取相关记忆，核心流程为“查询向量化 -> 索引匹配 -> Top-K筛选 -> 结果整合”
  - **压缩 (Compression)**：减少记忆数据量，包括预输入压缩 (长文本摘要)、后检索压缩 (检索结果精炼)、向量量化 (降低向量维度)



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





# 6. agent 和 chain

本质区别：

👉 **Chain = 固定流程（你写死）**
👉 **Agent = 动态决策（模型决定）**



## 核心对比

| 维度         | Chain  | Agent         |
| ------------ | ------ | ------------- |
| 流程         | 固定   | 动态          |
| 控制权       | 开发者 | LLM           |
| 是否能选工具 | ❌ 不会 | ✅ 会          |
| 是否有“思考” | ❌ 没有 | ✅ 有（ReAct） |
| 可预测性     | ✅ 高   | ❌ 相对低      |
| 灵活性       | ❌ 低   | ✅ 高          |



## 三、Chain 是什么？

👉 本质：**Runnable Pipeline（流水线）**

你明确规定每一步：

```
input → prompt → llm → parser → output
```

### 示例（LCEL）

```
from langchain_core.runnables import RunnableLambda

chain = (
    RunnableLambda(lambda x: x + " world")
)

chain.invoke("hello")
```

👉 特点：

- 每一步你都写死
- 不会“自己决定”
- 不会调用工具（除非你硬编码）

------

## 四、Agent 是什么？

👉 本质：**带决策能力的 Chain（LLM + Tools + Reasoning）**

典型流程（ReAct）：

```
用户问题
  ↓
LLM 思考（Thought）
  ↓
是否需要工具？
  ↓
调用 Tool
  ↓
拿到结果（Observation）
  ↓
继续思考
  ↓
最终回答
```

------

### 示例（Agent）

```
from langchain.agents import create_agent

agent = create_agent(
    model=llm,
    tools=[get_time]
)

agent.invoke({
    "messages": [{"role": "user", "content": "现在几点"}]
})
```

👉 这里关键点：

- LLM 自己决定：
  - 要不要调用 `get_time`
  - 调用几次
  - 何时结束





## 六、什么时候用 Chain？

👉 满足这些就用 Chain：

- 流程固定（ETL / pipeline）
- 不需要工具选择
- 要求稳定、可控
- Structured Output（JSON）

典型：

- 日志解析（你之前在做）
- Prometheus 指标处理
- 数据清洗
- 固定 Prompt 生成

------

## 七、什么时候用 Agent？

👉 满足这些就用 Agent：

- 问题不确定
- 需要调用工具
- 需要推理（multi-step）
- 用户输入开放

典型：

- ChatGPT 类应用
- Copilot
- 数据查询助手（SQL / API）
- 自动化运维助手（很适合你）
