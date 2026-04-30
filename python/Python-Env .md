# 1. conda

## 1.1 安装

https://www.anaconda.com/docs/getting-started/miniconda/main

配置环境变量：

```bash
ANACONDA_HOME=D:\miniconda3

%ANACONDA_HOME%
%ANACONDA_HOME%\Scripts
%ANACONDA_HOME%\Library\bin
```



激活：

```bash
# 版本查看
conda --version

# 自动添加启动配置到%USER_DIR%\Documents\WindowsPowerShell\*.ps1
conda init powershell

# 激活
conda activate base

# 查看 Python 版本
python --version

# 已安装的 Python 环境
conda env list

# 删除缓存
conda install jupyter -y

# 详细信息
conda info
```



pip 配置：

```bash
# 查询配置目录
pip -v config list

# 新增配置
mkdir -p ~/.pip/
cat > ~/.pip/pip.ini <<EOF
[global]
timeout = 6000
index-url=http://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host=mirrors.aliyun.com
EOF
```





## 1.2 创建独立 Python 环境

不要直接使用 base 环境

```bash
# 指定环境版本
conda create -n py-notebook python=3.14

# 激活
conda activate py-notebook

# 删除环境
conda deactivate py-notebook
conda env remove -n py-notebook
```



## 1.3 安装 Jupyter Notebook

经典版安装问题较多，使用更现代的 JupyterLab

```bash
# 安装
conda install jupyterlab -y

# 启动
jupyter lab

# 指定参数
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root
```



让 Notebook 使用当前 Conda 环境否则你会看到“装了包却 import 不到”的经典坑。

```
conda install ipykernel -y
python -m ipykernel install --user --name py-notebook --display-name "Python (py-notebook)"
```

Notebook 里选择：

```
Kernel → Change Kernel → Python (py-notebook)
```



配置文件：

```bash
# 生成默认配置
jupyter lab --generate-config

# 设置密码
jupyter server password

# 编辑配置
vi ~/.jupyter/jupyter_lab_config.py
c.ServerApp.ip = '0.0.0.0'  # 允许所有IP地址访问
c.ServerApp.open_browser = False  # 不自动打开浏览器
c.ServerApp.port = 8888  # 设置端口号
c.ServerApp.allow_remote_access = True  # 允许远程连接
c.ServerApp.password = u'sha1:...your hashed password here...'  # 设置一个强密码
```



## 1.4 工作目录

```
workspace/
├── notebooks/
│   ├── demo.ipynb
├── data/
├── scripts/
└── requirements.txt
```

启动：

```bash
cd workspace
jupyter lab
```



## 1.5 使用代理

```bash
%env ALL_PROXY=http://127.0.0.1:7890
%env HTTP_PROXY=http://127.0.0.1:7890
%env HTTPS_PROXY=http://127.0.0.1:7890
```



# 2. uv

## 2.1 安装

```bash
scoop install uv

# 关闭硬链接
[Environment]::SetEnvironmentVariable("UV_LINK_MODE","copy","User")
```

国内源：`~/.config/uv/uv.toml`

```toml
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple/"
default = true
```



## 2.2 Python

```bash
# 版本列表
uv python list

# 安装新版本
uv python install 3.13.12

# 加入到系统PATH中
uv python update-shell
```



## 2.3 虚拟环境

```bash
# 自动创建.venv目录
uv venv --python 3.13.12

# 初始化
uv init

# 激活
.venv\Scripts\activate

# 安装依赖包
uv add langchain   # 推荐，自动写入 pyproject.toml
uv pip install langchain # 临时测试
```



## 2.4 依赖管理

推荐：

```bash
# 导出依赖
uv export --format requirements.txt --no-hashes --no-annotate > requirements.txt

# 导入依赖
uv add -r requirements.txt
```



不推荐：(包未区分平台限制)

```bash
# 导出依赖
uv pip freeze > requirements.txt

# 导入依赖
uv pip install -r r requirements.txt
```




