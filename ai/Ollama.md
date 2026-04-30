# 1. 引言

Ollama 是一个开源的大型语言模型服务工具，旨在帮助用户快速在本地运行大模型。通过简单的安装指令，用户可以通过一条命令轻松启动和运行开源的大型语言模型。 它提供了一个简洁易用的命令行界面和服务器，专为构建大型语言模型应用而设计。用户可以轻松下载、运行和管理各种开源 LLM。与传统 LLM 需要复杂配置和强大硬件不同，Ollama 能够让用户在消费级的 PC 上体验 LLM 的强大功能。

Ollama 会自动监测本地计算资源，如有 GPU 的条件，会优先使用 GPU 的资源，同时模型的推理速度也更快。如果没有 GPU 条件，直接使用 CPU 资源。

Ollama 极大地简化了在 Docker 容器中部署和管理大型语言模型的过程，使用户能够迅速在本地启动和运行这些模型。



模型库查询：https://ollama.com/library

注意：运行 7B 模型至少需要 8GB 内存，运行 13B 模型至少需要 16GB 内存，运行 33B 模型至少需要 32GB 内存。



# 2. 常用命令

```bash
Usage:
  ollama [flags]
  ollama [command]

Available Commands:
  serve       Start ollama
  create      Create a model from a Modelfile
  show        Show information for a model
  run         Run a model
  stop        Stop a running model
  pull        Pull a model from a registry
  push        Push a model to a registry
  list        List models
  ps          List running models
  cp          Copy a model
  rm          Remove a model
  help        Help about any command

Flags:
  -h, --help      help for ollama
  -v, --version   Show version information

Use "ollama [command] --help" for more information about a command.
```



示例：

```bash
# 获取模型
ollama pull deepseek-r1:8b

# 模型信息
ollama show deepseek-r1:8b

# 运行模型
ollama run deepseek-r1:8b

# 运行状态
ollama ps
```





# 3. API

## 3.1 Generate a response

```bash
curl http://192.168.3.16:11434/api/generate -d '{
  "model": "deepseek-r1:8b",
  "prompt": "你是谁？",
  "steam": false
}'
```



## 3.2 Generate a chat message

```bash
curl http://192.168.3.16:11434/api/chat -d '{
  "model": "deepseek-r1:8b",
  "messages": [{ "role": "user", "content": "How about Morocco?" }]
}'
```



# 4. WEBUI

## 4.1 本地启动

```bash
# 创建环境
conda create -n ollama-web python=3.12
conda activate ollama-web

# 安装
pip install open-webui

# 启动
open-webui serve
```



## 4.2 docker 启动

```bash
docker run -d -p 3080:8080 -e OLLAMA_BASE_URL=http://192.168.3.16:11434 -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```

