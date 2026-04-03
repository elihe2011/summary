# 1. RAG

## 1.1 LLM 问题

大模型局限：

- **知识滞后**：LLM 因其具有海量参数，需要花费相当的物力和时间成本进行预训练和微调，同时商用 LLM 还需要进行各种安全测试与风险评估等，因此 LLM 会存在知识滞后的问题
- **知识缺失**：在专有领域，LLM 无法学习到所有的专业知识细节，因此在面向专业领域知识的提问时，无法给出可靠准确的回答
- **幻觉**：LLM 在生成回答时，可能会“胡言乱语”，错误陈述、编造事实、错误的复杂推理或复杂语境下理解能力不足



“幻觉” 产生的原因：

- LLM 训练时过度泛化，将普通的模式应用在特定场合导致不准确输出
- LLM 本身没有真正学习到训练数据中深层次的含义，导致在一些需要深入理解或复杂推理的任务中出错
- LLM 缺失某些领域的相关知识，在面临这些领域的相关问题时，编造不存在的信息
- 大模型生成的内容不可控，尤其是在金融和医疗领域，一次金融评估错误，一次医疗诊断失误，都是致命的。但这些错误对非专业人士来说难以辨认。目前还没有能够百分百解决这种情况的方案



## 1.2 RAG 是什么

RAG (Retrieval-Augmented Generation，检索增强生成)，其基本思想：将传统的生成式大模型和实时信息检索技术相结合，为大模型补充来自外部的相关数据和上下文，来帮助大模型生成更加准确可靠的内容。这使得大模型在生成内容时可以依赖实时与个性化的数据和知识，而非仅仅依赖训练知识。就相当于在大模型回答时给它一本参考书

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/RAG-prompt-LLM.png)



## 1.3 RAG 优缺点

- 优点
  - 相比提示词工程，RAG 有更丰富的上下文和数据样本，可以不需要用户提供过多的背景描述，就能生成比较符合用户预期的答案
  - 相比于模型微调，RAG 可以提升问答内容的时效性和可靠性
  - 在一定程度上保护了业务数据的隐私性
- 缺点
  - 由于每次问答都涉及外部系统数据检索，因此 RAG 的相应时延相对较高
  - 引用的外部知识数据会消耗大量的模型 Token 资源



## 1.4 RAG 流程

典型的 RAG 有两个主要流程：

- **索引**：从数据源提取数据，构建索引
- **检索生成**：接受用户查询并从索引中检索相关数据，然后将其传递给模型



索引阶段：

- 从各种数据源加载数据
- 将文档切分为小块
- 对文本块进行嵌入
- 存储嵌入向量

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/RAG-indexing-phase.png)



索引检索阶段：

- 根据用户输入，使用检索器从存储中检索相关文本块
- 大模型使用包含问题和检索结果的提示生成回答



# 2. 文档加载

LangChain 所有文档加载器都实现了 BaseLoader 接口，接口提供了通用的 load (一次性加载所有文档) 与 lazy_load (以延迟方式加载文档) 方法，用于从数据源加载数据并处理为 Document 对象。

Document 抽象，用于表示文本单元及其元数据，它包含三个属性：

- page_content  文本内容字符串
- metadata  包含元数据的字典，如文档的来源等
- id  可选，文档标识符



## 2.1 加载 TXT

```python
from langchain_community.document_loaders import TextLoader

docs = TextLoader(
    file_path="assets/sample.txt",
    encoding="utf-8",
).load()

if __name__ == "__main__":
    for doc in docs:
        print(doc)
        # page_content='...' metadata={'source': 'assets/sample.txt'}
```



## 2.2 加载 CSV

```python
from langchain_community.document_loaders import CSVLoader

# 加载所有列
docs = CSVLoader(
    file_path="assets/sample.csv",
).load()

print(docs)
# [Document(metadata={'source': 'assets/sample.csv', 'row': 0}, page_content='c_system: ...\nc_type: ...)]

# 加载指定列
docs = CSVLoader(
    file_path="assets/sample.csv",
    metadata_columns=["c_system", "c_type"],  # 将指定列加载到metadata中
    content_columns=["c_content"],  # page_content中的数据
).load()

print(docs)
# [Document(metadata={'source': 'assets/sample.csv', 'row': 0, 'c_system': '...', 'c_type': '...'}, page_content='c_content: ...')...]
```



## 2.3 加载 JSON

`JSONLoader` 使用指定 jq 模式来解析 JSON 文件，从而将特定字段提取到 Document 中。如果要从 JSON Lines 文件加载文档，需要传递 `json_lines=True`

常见 jq schema 参考：https://jqlang.org/manual/#basic-filters

```
JSON         -> [{"text": ...}, {"text": ...}, {"text": ...}]
jq_schema    -> ".[].text"

JSON         -> {"key": [{"text": ...}, {"text": ...}, {"text": ...}]}
jq_schema    -> ".key[].text"

JSON         -> ["...", "...", "..."]
jq_schema    -> ".[]"
```

示例1：提取所有字段

```python
from langchain_community.document_loaders import JSONLoader

docs = JSONLoader(
    file_path="assets/sample.json",
    jq_schema=".",       # 提取所有字段
    text_content=False,  # 提取内容是否为字符串格式
).load()

if __name__ == '__main__':
    print(docs)
# [Document(metadata={'source': 'assets/sample.json', 'seq_num': 1}, page_content='{"code": 1, "message": "success", "data": {"items": [{"id": 1, "title": "title 1", "content": "content 1"}, {"id": 2, "title": "title 2", "content": "content 2"}]}}')]
```



示例2：提取指定字段中的内容

```python
from langchain_community.document_loaders import JSONLoader

docs = JSONLoader(
    file_path="assets/sample.json",
    jq_schema=".data.items[].content",  # 提取data.item中的数据
    text_content=False,  # 提取内容是否为字符串格式
).load()

if __name__ == '__main__':
    print(docs)
# [Document(metadata={'source': 'assets/sample.json', 'seq_num': 1}, page_content='content 1'), Document(metadata={'source': 'assets/sample.json', 'seq_num': 2}, page_content='content 2')]
```



## 2.4 加载 HTML

```python
import bs4
from langchain_community.document_loaders import WebBaseLoader

docs = WebBaseLoader(
    web_path="https://news.cctv.com/2026/03/30/ARTI9dWKDYk7zIMcWamgYpmh260330.shtml",
    # 提取指定标签的元素
    bs_kwargs={"parse_only": bs4.SoupStrainer(class_="info")},
).load()

if __name__ == "__main__":
    print(docs)
# [Document(metadata={'source': 'https://news.cctv.com/2026/03/30/ARTI9dWKDYk7zIMcWamgYpmh260330.shtml'}, page_content='来源：央视网  |  2026年03月30日 19:02:56')]
```



## 2.5 加载 Markdown

可以通过 Unstructured 文档加载器来加载多种类型文件，需要安装依赖 unstructured 和 markdown

```python
import os

from langchain_community.document_loaders import UnstructuredMarkdownLoader

# 需要代理，会自动下载 https://github.com/explosion/spacy-models/releases/download/en_core_web_hftrf-3.8.1/en_core_web_hftrf-3.8.1-py3-none-any.whl
os.environ.setdefault("HTTP_PROXY", "http://127.0.0.1:7890")
os.environ.setdefault("HTTPS_PROXY", "http://127.0.0.1:7890")

docs = UnstructuredMarkdownLoader(
    file_path="assets/sample.md",
    mode="elements",  # single-返回单个Document对象，elements-按标题等元素切分文档
).load()

if __name__ == "__main__":
    print(docs)
```



# 2.6 加载 Doc / Docx

需要安装依赖 unstructured 和 python-docx (不是docx，该包存在 exceptions 依赖问题)

```python
import os

from langchain_community.document_loaders import UnstructuredWordDocumentLoader

# 需要代理，会自动下载 en_core_web_sm
os.environ.setdefault("HTTP_PROXY", "http://127.0.0.1:7890")
os.environ.setdefault("HTTPS_PROXY", "http://127.0.0.1:7890")

docs = UnstructuredWordDocumentLoader(
    file_path="assets/sample.docx",
    mode="single",
).load()

if __name__ == "__main__":
    print(docs)
```



## 2.7 加载 PDF

PDF 存在多种格式，包括扫描版 (图片)、电子文本版、混合版。并且布局格式也多种多样，包括单列布局、双列布局甚至竖排文本布局。并且包含段落、标题、页眉页脚、表格、数学公式、化学式、特殊符号、图片等各种元素。因此，PDF解析存在很多挑战，对于复杂 PDF，需要进行文本提取、布局检测、表格解析、公式识别等处理。



### 2.7.1 `PyPDFLoader`

```python
from langchain_community.document_loaders import PyPDFLoader

docs = PyPDFLoader(
    file_path="assets/sample.pdf",
    extraction_mode="plain", # plain-文本，layout-布局
).load()

if __name__ == "__main__":
    print(docs)
```



### 2.7.2 `UnstructuredPDFLoader`

`UnstructuredPDFLoader` 是对 unstructured 库的封装，支持布局与OCR提取文字。使用它之前，需要安装：

- `Poppler`：开源 PDF 文档处理库，用于渲染、解析和操作 PDF 文件
- `Tesseract OCR`：用于提取图片中的文字

```powershell
scoop install poppler

scoop install tesseract tesseract-languages

uv add pdfminer-six  # 不要安装 pdfminer
uv add pi-heif
uv add unstructured-inference
```

示例：解析 pdf 文档

```python
from langchain_community.document_loaders import UnstructuredPDFLoader

docs = UnstructuredPDFLoader(
    file_path='assets/invoice.pdf',
    # 加载模式:
    #   single: 返回单个Document对象
    #   elements: 按标题等元素切分文档
    mode="elements",
    # 加载策略:
    #   fast: pdfminer 提取并处理文本
    #   ocr_only: 转换为图片并进行 OCR
    #   hi_res: 识别文档布局，将OCR 输出与 pdfminer 输出融合
    strategy="hi_res",
    # 推断表格结构:仅 hi_res 下起效，如果为 True 则会在表格元素的元数据中添加 text_as_html
    infer_table_structure=True,
    # OCR 使用的语言: eng 英文，chi_sim 中文简体。
    languages=["eng", "chi_sim"],
).load()

if __name__ == "__main__":
    print(docs)
```



# 3. 文档切分

## 3.1 为什么切分

获取 Document 对象后，需要将其切分成 Chunk，之所以要进行切分出于以下考虑：

- Document 中可能包含非常多无用的信息，这些无效信息会干扰大模型的生成
- 大模型存在最大输入的 Token 限制，如果一个 Document 非常大，在输入大模型时会被截断，导致信息缺失

将 Document 进行分块处理 (Chunking) 成一个个小块 (Chunk)，无论是在存储还是检索过程中，都将以这些块为基本单位，这样能有效地避免内容噪声干扰和超出最大 Token 的问题



## 3.2 切分策略

- 按固定字符数或Token数切分，但可能会在不适当的位置切断句子
- 递归使用多个分隔符切分，同时尽量保证字符数或Token数不超出限制，能保证不切断完整的句子
- 按文本的语义切分，旨在保持相关信息的集中和完整，适用于需要高度语义保持的场景。
  - 问题：处理速度慢，且可能出现不同块之间长度极不均衡
  - 切分：将相邻的几个句子拼成一个句组。对所有句组进行嵌入，并比较嵌入向量的距离，找到语义变化大的位置，根据阈值确定切分点（比如计算相邻句子嵌入向量的余弦距离，取距离分布的第N百分位值作为阈值，高于此值则切分）。
  - 按照切分点切出若干语义段，并合并某些长度很短的语义段



## 3.3 `RecursiveCharacterTextSplitter`

递归字符文本切分器 是最常用的切分器，它由一个字符列表作为参数，默认列表为 `[\"\n\n", "\n", " ", ""]`，并且会尝试按顺序使用这些字符进行切分，直到块足够小。由此尽可能地将所有段落 (然后是句子，最后是词) 保持在一起，因为这些段落通常看起来是语义上最相关的文本片段

为了保证段落之间语义完整，可以设置每个块之间有一部分重叠：

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/document-chunking-overlap.png)

```python
from langchain_community.document_loaders import UnstructuredWordDocumentLoader
from langchain_text_splitters import RecursiveCharacterTextSplitter

docs = UnstructuredWordDocumentLoader(
    file_path="assets/sample2.docx",
    mode="single",
).load()

chunks = RecursiveCharacterTextSplitter(
    separators=["\n\n", "\n", "。", "！", "？", "……", "，", ""],
    chunk_size=400,
    chunk_overlap=50,
    length_function=len,
    add_start_index=True,
).split_documents(docs)

if __name__ == "__main__":
    print(chunks)
```



# 4. 文档嵌入

使用嵌入模型生成文档的嵌入向量，后续检索时用于与查询的嵌入向量进行相似度计算

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/document-embedding.png)

**BERT**：2018 Google 推出的文本嵌入为简单的向量表示，但它为针对有效生成句子嵌入进行优化

**Sentence-BERT**：调整了 BERT 架构以及预训练任务以生成包含语义的句子嵌入向量，这些嵌入向量可以通过余弦相似度等相似性指标轻松进行比较，大大降低查找相似句子等任务的计算开销

准备工作：

```bash
# 安装支撑包
uv add sentence-transformers langchain_huggingface

# 下载嵌入模型
export https_proxy=http://127.0.0.1:7890
git clone https://huggingface.co/BAAI/bge-base-zh-v1.5
```

示例：中文向量化

```python
from langchain_huggingface import HuggingFaceEmbeddings

# 加载嵌入模型
embed_model = HuggingFaceEmbeddings(
    model_name=r'E:\HHZ\huggingface.co\bge-base-zh-v1.5'
)

if __name__ == "__main__":
    # 单文本嵌入
    query = "你好，世界"
    print(embed_model.embed_query(query))

    # 多文本嵌入
    docs = ["你好，世界", "北京欢迎你"]
    print(embed_model.embed_documents(docs))
```



# 5. 向量存储

## 5.1 向量数据库

| 数据库        | 简介                                                         |
| ------------- | ------------------------------------------------------------ |
| FAISS         | 一个用于高效相似性搜索和密集向量聚类的库                     |
| Chroma        | 开源轻量级向量数据库，有极简的API                            |
| Milvus        | 开源转为向量搜索设计的云原生数据库。性能强悍、功能丰富。覆盖轻量级原型开发到十亿级向量的大规模生产系统 |
| PgVector      | 开源关系型数据库PostgreSQL扩展，为其增加了向量数据类型和相似性搜索功能 |
| Redis         | 开源内存数据结构存储，现已原生支撑向量相似性搜索功能         |
| ElasticSearch | 开源分布式搜索和分析引擎，提供基于文档数据库，结构化、非结构化和向量数据通过高效的列式存储统一管理 |



## 5.2 Milvus

### 5.2.1 数据库

Milvus 通过 “DATABASE --> Collections --> Entities” 的结构管理数据。Collections 和 Entities 类似关系数据库的表和行

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/milvus-collections.png)

Collection 通过 Schema 来定义有哪些字段及字段的类型、索引等。一个 Collection Schema 有一个主键、最多四个向量字段和若干标量字段。

- **主键**：唯一标识，只接受 Int64 或 VarChar。插入实体时，默认情况下应包含主键值，但如果在创建 Collections 时企业 AutoId，它将在插入数据时自动生成主键值，插入实体时不应该包含主键值
- **向量字段**：用于存储文本、图像、音频等非结构化数据类型的嵌入，可以是密集向量、稀疏向量或二进制向量。通常，**密集向量用于语义搜索，而稀疏向量则更适合全文或词性匹配**。
- **标量字段**：用于存在一些元数据，并可以在搜索时通过元数据过滤，以提高搜索结果的正确性
- **索引**：建立在数据之上的附加结果，可以加快搜索速度。不同字段数据类型适用于不同的搜索类型
  - `FLOAT_VECTOR`：HNSW (分层导航小世界) 索引
  - `VARCHAR`：`INVERTED` (反转) 索引

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/milvus-field-type.png)



### 5.2.2 版本选择

Milvus 版本选择：

- Lite：本地轻量化运行，通过 `pip install pymilvus[milvus-lite]` 安装，但它仅支撑 FLAT 类型，且无法直接在 windows 上使用
- Standalone：单点部署，支持通过 Docker 部署
- Distributed：分布式部署，支持在 Kubernetes 集群上部署

通过 Dockers 部署 Milvus Standalone  

```yaml
version: '3.5'

services:
  etcd:
    container_name: milvus-etcd
    image: quay.io/coreos/etcd:v3.5.25
    environment:
      - ETCD_AUTO_COMPACTION_MODE=revision
      - ETCD_AUTO_COMPACTION_RETENTION=1000
      - ETCD_QUOTA_BACKEND_BYTES=4294967296
      - ETCD_SNAPSHOT_COUNT=50000
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/etcd:/etcd
    command: etcd -advertise-client-urls=http://etcd:2379 -listen-client-urls http://0.0.0.0:2379 --data-dir /etcd
    healthcheck:
      test: ["CMD", "etcdctl", "endpoint", "health"]
      interval: 30s
      timeout: 20s
      retries: 3

  minio:
    container_name: milvus-minio
    image: minio/minio:RELEASE.2024-05-28T17-19-04Z
    environment:
      MINIO_ACCESS_KEY: minioadmin
      MINIO_SECRET_KEY: minioadmin
    ports:
      - "9001:9001"
      - "9000:9000"
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/minio:/minio_data
    command: minio server /minio_data --console-address ":9001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  standalone:
    container_name: milvus-standalone
    image: milvusdb/milvus:v2.6.11
    command: ["milvus", "run", "standalone"]
    security_opt:
    - seccomp:unconfined
    environment:
      MINIO_REGION: us-east-1
      ETCD_ENDPOINTS: etcd:2379
      MINIO_ADDRESS: minio:9000
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/milvus:/var/lib/milvus
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9091/healthz"]
      interval: 30s
      start_period: 90s
      timeout: 20s
      retries: 3
    ports:
      - "19530:19530"
      - "19091:9091"
    depends_on:
      - "etcd"
      - "minio"

networks:
  default:
    name: milvus
```

管理页面：`http://127.0.0.1:19091/webui/`



## 5.3 创建 Collection

```python
from pprint import pprint

from pymilvus import MilvusClient, DataType

# 实例化客户端
client = MilvusClient(
    uri="http://192.168.3.111:19530"
)

# 创建 schema
def build_schema():
    return (
        MilvusClient.create_schema(
            # 自动分配主键
            auto_id=True,
            # 启用后，字段会以键值对的形式存储在动态字段 $meta
            enable_dynamic_field=False,
        )
        # 添加 id 字段，类型为整数，设为主键
        .add_field(field_name="id", datatype=DataType.INT64, is_primary=True)
        # 添加 vector 字段，类型为浮点数向量，维度为 768
        .add_field(field_name="vector", datatype=DataType.FLOAT_VECTOR, dim=768)
        # 添加 text 字段，类型为字符串，最大长度 2048
        .add_field(field_name="text", datatype=DataType.VARCHAR, max_length=2048)
        # 添加 metadata 字段，类型为 JSON
        .add_field(field_name="metadata", datatype=DataType.JSON)
    )

# 创建 index
def build_index():
    index_params = MilvusClient.prepare_index_params()
    index_params.add_index(
        field_name="vector",    # 索引字段名称
        index_type="AUTOINDEX", # 索引类型
        metric_type="L2",       # 向量相似度度量方式
    )
    return index_params

# 创建 collection
if client.has_collection(collection_name="demo_collection"):
    # 删除 collection，但删除数据后，存储不会立即释放，只会将实体标记为“逻辑删除”
    # Milvus 会在后台字段压缩数据，将较小的数据段合并为较大的数据段，并删除“逻辑删除”的数据和已超过有效时间的数据
    # 一个名为 Garbage Collection (GC) 的独立程序会定期删除这些“已删除”的数据段，释放存储空间
    client.drop_collection(collection_name="demo_collection")

client.create_collection(
    collection_name="demo_collection",
    schema=build_schema(),
    index_params=build_index(),
)

if __name__ == "__main__":
    print(client.list_collections())

    pprint(client.describe_collection(collection_name="demo_collection"))
```



## 5.4 操作实体

### 5.4.1 插入实体

```python
from langchain_community.document_loaders import UnstructuredWordDocumentLoader
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from pymilvus import MilvusClient

# 客户端
client = MilvusClient(uri="http://192.168.3.111:19530")

# 加载文档
docs = UnstructuredWordDocumentLoader(
    file_path="../doc_load/assets/sample2.docx",
    mode="single",
).load()

# 切分文档
chunks = RecursiveCharacterTextSplitter(
    separators=["\n\n", "\n", "。", "！", "？", "……", "，"],
    chunk_size=400,
    chunk_overlap=50,
).split_documents(docs)

# 加载嵌入模型
embed_model = HuggingFaceEmbeddings(
    model_name=r'E:\HHZ\huggingface.co\bge-base-zh-v1.5'
)

# 计算嵌入向量
embeddings = embed_model.embed_documents([chunk.page_content for chunk in chunks])

# 转换数据格式
data = [
    {
        "vector": embedding,
        "text": chunk.page_content,
        "metadata": chunk.metadata,
    }
    for chunk, embedding in zip(chunks, embeddings)
]

if __name__ == "__main__":
    # 插入实体
    res = client.insert(collection_name="demo_collection", data=data)
    print(res)
```



### 5.4.2 查询实体

```python
from pymilvus import MilvusClient

# 客户端
client = MilvusClient(uri="http://192.168.3.111:19530")

# 通过主键查询实体
res = client.get(
    collection_name="demo_collection",
    ids=[464651142493638386, 464651142493638397],
    output_fields=["text", "metadata"]
)
print(res)

# 通过过滤条件 https://milvus.io/docs/zh/boolean.md
res = client.query(
    collection_name="demo_collection",
    filter='metadata["source"] == "../doc_load/assets/sample2.docx"',
    output_fields=["text", "metadata"],
    limit=5,
)

if __name__ == '__main__':
    print(res)
```



### 5.4.3 删除实体

```python
from pymilvus import MilvusClient

# 客户端
client = MilvusClient(uri="http://192.168.3.111:19530")

# 通过主键删除
res = client.delete(
    collection_name="demo_collection",
    ids=[464651142493638397, 464651142493638398],
)
print(res)

# 通过过滤条件 https://milvus.io/docs/zh/boolean.md
res = client.delete(
    collection_name="demo_collection",
    filter='text LIKE "自动化%"',
)

if __name__ == "__main__":
    print(res)
```



# 6. 检索与生成

## 6.1 检索

### 6.1.1 数据检索

检索阶段：用户输入查询 => 计算嵌入向量 => 在向量存储中检索相似向量 => 返回相似向量对应的内容

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/vector-retrieval.png)

```python
from langchain_huggingface import HuggingFaceEmbeddings
from pymilvus import MilvusClient

# 客户端
client = MilvusClient(uri="http://192.168.3.111:19530")

# 加载嵌入模型
embed_model = HuggingFaceEmbeddings(
    model_name=r'E:\HHZ\huggingface.co\bge-base-zh-v1.5',
)

# 检索上下文
query = "自动化数字值班员"
query_embedding = embed_model.embed_query(query)
context = client.search(
    collection_name="demo_collection",
    data=[query_embedding],    # 搜索的向量
    anns_field="vector",        # 进行向量搜索的字段
    # 度量方式：L2-欧式距离 IP-内积 COSINE-余弦相似度
    search_params={"metric_type": "L2"},
    output_fields=["text", "metadata"],
    limit=2,
)

if __name__ == "__main__":
    print(context)
```



### 6.1.2 向量相似性搜索算法

常见向量相似性搜索算法：

- **KNN**：必须将向量空间中的所有向量与搜索请求中携带的查询向量进行比较，然后找出最相似的向量，费时费力。
- **ANN**：要求提供一个索引文件，记录向量 Embeddings 的排序顺序。当收到搜索请求时，使用搜索文件作为参考，找到可能包含与查询向量最相似的向量嵌入的子组，根据指定的度量类型来测量查询向量与子组中的向量之间的相似度，根据与查询向量的相似度对组成员进行排序，并返回前 K 个成员。不过 ANN 搜索依赖于预建索引，搜索吞吐量、内存使用量和搜索正确性可能会因选择的索引类型而不同
- **HNSW**：分层导航小世界，一种基于图的索引算法，可以提高搜索高维浮点数向量的性能。它具有出色的搜索精度和低延迟，但需要较高的内存开销来维护器分层图结果。其工作原理如下：
  - **入口点**：搜索从顶层的一个固定入口点开始，该入口点是图中的一个预定节点
  - **贪婪搜索**：算法贪婪地移动到当前层的近邻，直到无法再接近查询向量为止。上层起到导航作用，作为粗过滤器，为下层的精细搜索找到潜在的入口点
  - **层层下降**：一旦当前层达到局部最小值，算法就会预先建立的连接跳转到下层，并重复贪婪搜索
  - **最后细化**：这个过程一直持续到最底层，再最底层进行最后的细化不足，找出最近的邻居

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/langchain/vector-HNSW.png)



## 6.2 生成

```python
import os

from langchain.chat_models import init_chat_model
from langchain_core.output_parsers import StrOutputParser
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnablePassthrough, RunnableLambda
from langchain_huggingface import HuggingFaceEmbeddings
from pymilvus import MilvusClient

# 客户端
client = MilvusClient(uri="http://192.168.3.111:19530")

# 加载嵌入模型
embed_model = HuggingFaceEmbeddings(
    model_name=r'E:\HHZ\huggingface.co\bge-base-zh-v1.5',
)

# 检索
def retrieval(query):
    query_embedding = embed_model.embed_query(query)
    return client.search(
        collection_name="demo_collection",
        data=[query_embedding],
        anns_field="vector",
        search_params={"metric_type": "L2"},
        output_fields=["text", "metadata"],
        limit=3,
    )

# 大模型
llm = init_chat_model(
    model="qwen3-vl-flash-2025-10-15",
    model_provider="openai",
    base_url=os.getenv("DASHSCOPE_BASE_URL"),
    api_key=os.getenv("DASHSCOPE_API_KEY"),
)

# 提示
prompt = ChatPromptTemplate.from_messages(
    [
        (
            "system",
            "# 任务\n\n根据上下文参考，回答用户的问题。\n\n# 上下文参考\n\n{context}",
        ),
        ("human", "{query}")
    ]
)

# chain
rag_chain = (
    {
        "query": RunnablePassthrough(),
        "context": lambda x: retrieval(x),
    }
    | RunnableLambda(lambda x: print(x) or x) # 打印中间结果
    | prompt
    | llm
    | StrOutputParser()
)

if __name__ == "__main__":
    chunks = rag_chain.stream(input="自动化数字值班员")
    for chunk in chunks:
        print(chunk, end="", flush=True)
```

























