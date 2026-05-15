# 2. 中间件

`DeepAgents` 内部的中间件实现 



## 2.1 Summarization

### 2.1.1 概述

在基于大模型和工具构建的 Agent 中，每次调用模型都需要将之前的对话历史一并传入，以便模型理解当前上下文。然而，模型的上下文窗口是有限的 (常见的 8K、32K token 限制)。当任务变得复杂，或工具返回的信息量很大时，消息列表很容易就会“爆表”，超出模型的处理能力。

Summarization 中间件的作用，正是**在接近 Token 限制或其它预设条件时，自动对较旧的对话记录进行摘要。它会在保留近期关键消息的同时，将早期内容压缩成一段精炼的总结。这样一来，Agent 既能维持对任务背景的连贯理解，又不会因 Token 溢出而导致执行中断。



适用场景：

- **长文本处理**

  当模型需要阅读并分析长文档、多页网页时，工具返回的内容可能一次就占满上下文。Summarization 可以在每次调用工具前对已积累的内容做摘要，防止溢出。

- **多轮对话**

  多客服、咨询等场景中，对话轮次可能多达几十轮。Summarization 可以将早期的寒暄或确认信息压缩，让模型聚焦当前核心问题。

- **高冗余工具调用**

  某些工具 (如搜索引擎、爬虫) 返回的信息往往包含大量无关内容 (广告、导航栏等)。Summarization 可以提炼关键信息，减少噪声。



### 2.1.2 实现原理

Summarization 中间件继承自 `AgentMiddleware`，通过 Overwrite `before_model` 与 `after_model` 方法，在信息进入模型前执行压缩处理。

Summarization 属于 before model 钩子 类型中间件，它会在每次模型调用前触发执行，其核心工作流程如下：

- **检查消息列表**：获取当前 Agent 的完整消息列表 (包括历史消息、用户最新输入、工具响应等)
- **判断触发条件**：根据用户配置的 trigger 参数 (例如消息数量超过阈值、Token总数超限、达到模型上下文窗口的一定比例等)，判断当前是否需要进行摘要
- **执行摘要**：如果条件满足，中间件会先根据 keep 参数保留最新的一定数据的消息 (例如保留最近的3条)，然后将剩余的历史消息一并发送给摘要模型，生成一段概括性的总结
- **重组消息列表**：用新生成的摘要消息 (通常包装成一条 `HumanMessage`) 与之前保留的最近消息组合，形象一个新的、更精简的消息列表，再传递给模型进行后续的处理



### 2.1.3 配置说明

```python
agent = create_agent(
    model=llm,
    tools=[internet_search, calculate],
    middleware=[
        SummarizationMiddleware(
            model=llm,
            trigger=("messages", 5),  # 当历史消息数量大于等于5条时触发摘要
            keep=("messages", 3),  # 摘要完成后，只保留最近的 3 条原始消息，其余压缩成一条摘要
            backend=FilesystemBackend(
                root_dir="./.deepagents_fs",
                virtual_mode=True,
            ),
        ),
    ],
    checkpointer=InMemorySaver(),
)
```



**配置参数**：

- **trigger 触发条件**

  `trigger: ContextSize | list[ContextSize] | None = None,`

    ```python
    # ContextFraction
    context_size: ContextSize = ("fraction", 0.5)
  
    # ContextTokens
    context_size: ContextSize = ("tokens", 3000)
  
    # ContextMessages
    context_size: ContextSize = ("messages", 50)
    ```



- **keep 保留最新消息数量**

  `keep: ContextSize = ("messages", _DEFAULT_MESSAGES_TO_KEEP),`

  ```python
  # ContextFraction
  context_size: ContextSize = ("fraction", 0.5)
  
  # ContextTokens
  context_size: ContextSize = ("tokens", 3000)
  
  # ContextMessages
  context_size: ContextSize = ("messages", 50)
  ```



- **model  摘要模型**

  `model: str | BaseChatModel,` 指定生成摘要的模型



- **summary_prompt  摘要提示词**

  `summary_prompt: str = DEFAULT_SUMMARY_PROMPT,` 不指定直接使用默认提示词

  ```python
  from langchain.prompts import PromptTemplate
  
  custom_prompt = PromptTemplate.from_template(
      "请将以下对话浓缩成一段简洁的总结，重点关注事实和行动项：\n\n{messages}"
  )
  
  summarization_mw = SummarizationMiddleware(
      model=summary_llm,
      trigger=trigger,
      keep=keep,
      summary_prompt=custom_prompt
  )
  ```



## 2.2 Tool Selector

### 2.2.1 概述

当任务环境复杂时，Agent 可能拥有成百上千个工具。但执行具体任务时，实际用到的工具往往只是其中很小一部分。大量无关的工具不仅不会再每一步发挥作用，反而会持续占据宝贵的模型上下文窗口。这不仅造成 Token 浪费，更可能引入噪声，干扰大模型判断，降低决策的准确率。



适用场景：

- **多工具管理**：Agent 拥有庞大的工具集，但每次查询仅涉及其中少数几个
- **成本控制**：通过过滤无关工具，显著减少 Token 消耗，优化 API 调用成本
- **精度提升**：减少上下文冗余信息，提升模型子在关键任务上的专注度和决策准确率



### 2.2.2 实现原理

Tool Selector 可通过 Overwrite `wrap_model_call` 钩子函数的中间件。其核心机制：**在每次调用主模型之前，Tool Selector 中间件会基于当前的对话消息列表及用户问题，对全部工具列表进行一次智能预筛选，只保留与当前任务最相关的一小部分工具**。随后将这个精简后的工具子集传给主模型，让主模型能够排除干扰，更专注、更准确地做下一步决策。



### 2.2.3 配置说明

```python
agent = create_agent(
    model=model,
    tools=[tool_1, tool_2, tool_3, tool_4, calculate],
    middleware=[
        LLMToolSelectorMiddleware(
            model=model,
            max_tools=2,
            always_include=['tool_1'],
        ),
    ],
)
```

- `model` 工具筛选模型
- `max_tools`：保留的最大工具数量
- `always_include`：必选工具



## 2.3 Todo List

### 2.3.1 解决问题

当 Agent 需要执行一个多步骤、跨工具的复杂任务时，如果没有任务规划能力，Agent 很容易在步骤中迷失，或忘记已完成的部分。因此，一个有能力的 Agent 首要工作是生成一份清晰的任务规划清单。



适用场景：

- **复杂多步骤任务**：需要调用多个工具协同完成，且步骤之间存在明确的前后依赖关系
- **需要进度可见性的长期运行任务**：通过查看 `todos` 状态，开发者或用户能实时了解任务执行的进展，知道当前进行到哪一步，哪些步骤已经完成



### 2.3.2 实现原理

Todo List 中间件正是为这种规划能力设计的，它的实现方式与传统的钩子函数不同，而是以**额外工具**的形式，向 Agent 注入一个名为 `write_todo` 的工具。

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/deepagents-todo-list.png)



### 2.3.3 配置说明

```python
agent = create_agent(
    model=model,
    tools=[],
    middleware=[TodoListMiddleware()],
)
```

对一个高度复杂、需要多步分析和计算的综合性问题，当用户下达任务后，Todo List 机制会自动生效。在 Agent 的最终响应中，除了常规的 `messages` (包含历史对话和最终答案)，还有一个 `todos`，该字段包含了 Agent 对原始任务进行拆解后的详细子任务列表。每个子任务条目都包含 content (任务描述) 和 status (状态)



## 2.4 File System

### 2.4.1 解决问题

在构建具备长期运行能力的 Agent 时，记忆时维持 Agent 状态一致性的核心要素。



### 2.4.2 实现原理

File System 中间件正是为了解决 Agent 的记忆问题而设计的。它允许 Agent 将关键信息以文件形式写入本地或内存中的“文件系统”，并在后续步骤中随时读取、修改或追加内容。



### 2.4.3 配置说明

```python
agent = create_agent(
    model=llm,
    middleware=[
        FilesystemMiddleware(
            backend=None,
            system_prompt="Write to the filesystem when...",
            custom_tool_descriptions={
                "ls": "Use the ls tool when..",
                "read file": "Use the read file tool when..",
            },
        ),
    ],
)
```

主要参数：

- **`backend`**：可选，记忆的存储模式
- **`system_prompt`**：可选，重新默认系统提示词，引导 Agent 在何时使用文件系统
- **`custom_tool_descriptions`**：可选，自定义各个工具的描述文本，以适应特定场景的需求



配置 `FileSystemMiddleware` 后，Agent 将自动获取四个文件操作工具：

- **`ls`**：列出当前文件系统的文件列表
- **`read_file`**：读取指定文件的全部内容或特定行
- **`write_file`**：创建新文件并写入内容
- **`edit_file`**：修改已有文件，支持追加、替换等操作



**backend 参数：**

- **`FileSystemBackend` 访问本地磁盘**

  ```python
  agent = create_agent(
      model=llm,
      middleware=[
          FilesystemMiddleware(
              backend=FilesystemBackend(
                  root_dir="./dp_fs",
                  virtual_mode=True,
              )
          ),
      ],
  )
  
  if __name__ == "__main__":
      result = agent.invoke({
          "messages": [HumanMessage("调用工具写一个文件，文件名为‘测试.txt’，内容为‘测试内容’")],
      })
      print(result)
  ```



- **`StateBackend` 线程级短期记忆**

  `StateBackend` 将文件系统“嵌入”到 Agent 的运行状态 State 中，文件内容仅存于当前线程的声明周期内。它就像一个草稿纸，适合在单次任务中临时记录中间信息，任务结束后内容自动释放，不留痕迹。

  ```python
  agent = create_agent(
      model=llm,
      middleware=[
          FilesystemMiddleware(
              backend=StateBackend(),
          ),
      ],
  )
  
  if __name__ == "__main__":
      result = agent.invoke({
          "messages": [
              HumanMessage("调用工具写一个文件，文件名‘测试.txt’，内容‘临时文件’"),
              HumanMessage("调用工具读取一个名为‘测试.txt’的文件，告诉我里面的内容")
          ],
      })
      print(result["messages"][-1].content)
  ```



- **`StoreBackend` 跨线程长期记忆**

  利用运行时聚合的 `store` 对象进行文件存储。`store` 对象独立于线程，其生命周期由开发者控制，因此可以实现跨线程、跨会话的**长期记忆共享**。适合需要持久化用户偏好、全局配置或跨多次对话积累知识库的场景。

  ```python
  agent = create_agent(
      model=llm,
      middleware=[
          FilesystemMiddleware(
              backend=StoreBackend(store=InMemoryStore()),  # 生产推荐PostgresStore
          ),
      ],
  )
  ```



- **`CompositeBackend` 复合后端 (混合存储)**

  `CompositeBackend` 允许将 `StateBackend` 和 `StoreBackend` 组合使用，实现“临时文件进状态，重要文件进仓库”的混合模式。

  参数配置：

  - **`default`**：默认后端，不匹配任何前缀的文件操作，会路由到此操作，通常设置为 `StateBackend`，存放会话内临时文件
  - **`routes`**：路由规则，字典形式，键为路径前缀 (如 "/memories/")，值为对应的后端实例

  **路径前缀剥离**：`CompositeBackend` 在将文件传递给具体后端存储之前，会自动剥离匹配到的路由前缀。例如，Agent 写入 `/memories/preferences.txt` 时，实际存储在 `StoreBackend` 中的文件路径为 `/preferences.txt`

  ```python
  agent = create_agent(
      model=llm,
      middleware=[
          FilesystemMiddleware(
              backend=CompositeBackend(
                  default=StateBackend(),
                  routes={
                      "/memories/": StoreBackend(store=InMemoryStore()),  # 生产推荐PostgresStore
                  },
              )
          ),
      ],
  )
  
  if __name__ == "__main__":
      config1 = {"configurable": {"thread_id": "conversation-123"}}
      result = agent.invoke({
          "messages": [
              HumanMessage("我最爱的水果是西瓜, 请把我的偏好保存在/memories/preferences.txt"),
          ],
      }, config=config1)
      print(result["messages"][-1].content)
  
      config2 = {"configurable": {"thread_id": "conversation-123"}}
      result = agent.invoke({
          "messages": [
              HumanMessage("请从/memories/获取我最哎的水果是什么"),
          ],
      }, config=config2)
      print(result["messages"][-1].content)
  ```

