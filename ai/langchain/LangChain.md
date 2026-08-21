

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





# 6. 运行时数据注入



## 6.6 企业级 Agent 架构

```python
import os
from dataclasses import dataclass
from datetime import datetime

from langchain.agents import AgentState, create_agent
from langchain.agents.middleware import before_model
from langchain_core.tools import tool
from langgraph.prebuilt import ToolRuntime
from langgraph.runtime import Runtime
from langgraph.store.memory import InMemoryStore


# ============ 1. 上下文定义 ============
@dataclass
class CustomerServiceContext:
    agent_id: str               # 客服工号
    user_tier: str              # vip | premium | standard
    session_id: str             # 会话ID，用于链路追踪
    crm_api_token: str          # CRM系统密钥
    knowledge_base_version: str

# ============ 2. 中间件：动态权限提示 ============
@before_model
def inject_privacy_warning(state: AgentState, runtime: Runtime[CustomerServiceContext]) -> dict:
    """在模型调用前注入数据隐私提醒"""
    if runtime.context.user_tier == "vip":
        return {
            "messages": [{
                "role": "system",
                "content": "⚠️ 当前用户为VIP，注意保护隐私数据，不得透露其他客户信息"
            }]
        }
    return {}

# ============ 3. 工具实现 ============
@tool
def lookup_customer_history(customer_phone: str, runtime: ToolRuntime[CustomerServiceContext]) -> str:
    """查询客户历史，自动根据等级决定详细程度"""
    ctx = runtime.context

    # 实时反馈
    runtime.stream_writer(f"🔍 正在查询客户 {customer_phone[-4:]}...")

    # 使用安全 token 调用 CRM
    history = crm_client.query(
        token=ctx.crm_api_token,
        phone=customer_phone,
    )

    # VIP 客户看到完整历史，普通用户仅看摘要
    if ctx.user_tier == "vip":
        return format_detailed_history(history)
    else:
        return format_summary(history)

@tool
def escalate_to_human(reason: str, runtime: ToolRuntime[CustomerServiceContext]) -> str:
    """升级至人工客服"""
    ctx = runtime.context

    # 写入长期记忆：标记该用户需要人工跟进
    if runtime.store:
        runtime.store.put(
            ("escalation",),
            ctx.session_id,
            {
                "agent_id": ctx.agent_id,
                "reason": reason,
                "timestamp": datetime.now().isoformat(),
                "resolved": False,
            }
        )

    # 通知监控系统
    runtime.stream_writer({
        "type": "alert",
        "level": "high",
        "message": f"工单升级: {reason}"
    })

    return "已为你转接人工客服，请稍等..."

# ============ 4. 组装 Agent ============
agent = create_agent(
    model="deepseek-v3.1",
    tools=[lookup_customer_history, escalate_to_human],
    context_schema=CustomerServiceContext,
    middleware=[inject_privacy_warning],
    store=InMemoryStore(),
)

# ============ 5. 运行 ============
response = agent.invoke(
    {"messages": [{"role": "user", "content": "我要投诉昨天的订单"}]},
    context=CustomerServiceContext(
        agent_id="CS-1001",
        user_tier="vip",
        session_id="TK-20260430-099001",
        crm_api_token=os.getenv("CRM_API_TOKEN"),
        knowledge_base_version="v1.5"
    )
)
```











# Z. 附录

## Z.1 LangSmith

使用 LangChain 构建的许多应用程序都包含多个步骤，需要多次调用 LLM。随着这些应用程序变得越来越复杂，能够检查链或 Agent 内部的具体情况变得至关重要，最好的办法是使用 LangSmith

注册LangSmith，在Settings ➡️ API Keys 下创建 API-Key 并复制。之后在环境变量中添加以开始记录跟踪：

```
LANGSMITH_TRACING_v2="true"
LANGSMITH_API_KEY="..."
```

配置好环境变量之后，可在LangSmith 的 Tracing Projects 中查看跟踪记录。

LangSmith 默认将跟踪记录到 default 项目，可通过 LANGSMITH_PROJECT 环境变量设置 LangSmith 跟踪记录保存到哪个项目，如果该项目不存在则会创建。



## Z.2 提示词

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



## Z.3 多 Agent 架构

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



