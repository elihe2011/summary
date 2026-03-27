# 1. 核心概念

Memory 是 `LangChain` 框架中负责 **维护 Chain 状态并整合过去上下文** 的核心组件。默认情况下，所有链式模型和代理模型都是**无状态的** (独立处理每个查询，不保留历史信息)，而在对话系统等场景中，记住先前的交互至关重要，Memory 正是为此设计的。



Memory 支持的两个核心操作：

- **读取 (Load)**：在 Chain 执行前，从记忆中获取历史信息，增强用户输入
- **写入 (Save)**：在 Chain 执行后，将当前输入/输出保存到记忆中，供后续使用



Memory 分类：

- **短期内存 (Short-term memory)**：线程范围内存，追踪当前会话，在会话结束后通常会被清除
- **长期内存 (Long-term memory)**：跨会话存储，可在任意线程中随时访问，通常需要配置持久化存储



# 2. 聊天消息历史

## 2.1 核心类

```
BaseChatMessageHistory
├── InMemoryChatMessageHistory
│   ├── ConversationBufferMemory
│   ├── ConversationBufferWindowMemory
│   ├── ConversationSummaryMemory
│   ├── ConversationSummaryBufferMemory
│   ├── ConversationEntityMemory
│   └── ConversationKGMemory
└── VectorStoreRetrieverMemory
```



## 2.2 `BaseChatMessageHistory` 接口

| 方法/属性                                              | 参数                | 说明     |
| ------------------------------------------------------ | ------------------- | -------- |
| `aget_messages(self)`                                  | `list[BaseMessage]` |          |
| `add_user_message(self, message: HumanMessage )`       | `None`              |          |
| `add_ai_message(self, messages: AIMessage | str)`      | `None`              |          |
| `add_message(self, message: BaseMessage)`              | `None`              |          |
| `add_messages(self, messages: Sequence[BaseMessage])`  | `None`              |          |
| `aadd_messages(self, messages: Sequence[BaseMessage])` | `None`              |          |
| `clear(self)`                                          | `None`              | 抽象方法 |
| `aclear(self)`                                         | `None`              |          |
| `messages`                                             | `list[BaseMessage]` | 属性     |





## 2.3 类型详解

### 2.3.1 `ConversationBufferMemory`

**基础对话缓冲内存**：简单存储完整对话历史，返回字符串格式的历史内容

```python
from langchain.memory import ConversationBufferMemory

memory = ConversationBufferMemory(memory_key="chat_history")
memory.chat_memory.add_user_message("Hi!")
memory.chat_memory.add_ai_message("Hello!")

print(memory.load_memory_variables({}))  # 输出: {'chat_history': 'Human: Hi!\nAI: Hello!'}
```



### 2.3.2 `ConversationBufferWindowMemory`

**对话窗口缓冲内存**：只保留最近 k 轮对话，适合 **高频短对话** 场景，避免内存溢出

```python
memory = ConversationBufferWindowMemory(k=2, memory_key="history")
```



### 2.3.3 `ConversationSummaryMemory`

**对话摘要内存**：使用 LLM 自动生成对话摘要，**减少 token**占用，适合长对话场景

```python
from langchain.llms import OpenAI
from langchain.memory import ConversationSummaryMemory

llm = OpenAI(temperature=0)
memory = ConversationSummaryMemory(llm=llm, memory_key="history")
```



### 2.3.4 `ConversationSummaryBufferMemory`

**对话摘要 + 缓冲 混合内存**：近期消息保留原文，久远内容使用摘要，平衡信息完整性与内存效率



### 2.3.5 `ConversationEntityMemory`

**实体内存**：专注于**识别和存储对话中的实体** (如人名、组织、地点) 及其属性，适合个性化助手场景，让 AI 真正 “认识” 用户



### 2.3.6 `ConversationKGMemory`

**知识图谱内存**：构建 **对话知识图谱**，将对话中的实体关系结构化 (如 “张三是产品经理”、“李华在杭州工作“)，适合需要 **关系推理** 的复杂问答系统



### 2.3.7 `VectorStoreRetrieverMemory`

**向量存储内存**：将对话历史存储为 **向量嵌入** 到向量数据库，通过 **语义相似度检索** 相关历史，适合 **大规模知识库** 集成和 **长期记忆** 场景



# 3. `ChatMessageHistory`

## 3.1 底层消息存储机制

`ChatMessageHistory` 是 `LangChain` 中负责 **管理和操作聊天消息** 的底层工具类，是几乎所有对话内存的基础支持。

```python
from langchain.memory import ChatMessageHistory

history = ChatMessageHistory()
history.add_user_message("Hello")
history.add_ai_message("What can I do for you?")

print(history.messages)
```



## 3.2 消息存储选项

`ChatMessageHistory` 支持多种存储后端：

- **内存 (默认)**：临时存储，应用重启后丢失
- **Redis**：分布式持久化存储，适合生成环境
- **文件**：简单本地文件持久化
- **数据库**：SQL 或 NoSQL 数据库集成
- **自定义**：实现 `BaseChatMessageHistory` 接口



