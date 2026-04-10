# 1. ai-agent 运行

环境：

- python 3.13
- docker 18.0



## 1.1 服务启动失败 

报错如下：

```
OpenBLAS blas_thread_init: pthread_create failed for thread 1 of 8: Operation not permitted OpenBLAS blas_thread_init: ensure that your address space and process count limits are big enough (ulimit -a)
```

解决方案：修改为单线程

```bash
export OPENBLAS_NUM_THREADS=1
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
```



## 1.2 创建线程失败

### 1.2.1 错误分析

报错如下：

```bash
langchain_core/chat_history.py → aget_messages()
  → run_in_executor(None, lambda: self.messages)   ← 问题在这里
    → ThreadPoolExecutor.submit()
      → t.start() → RuntimeError: can't start new thread
```

容器中诊断：

```bash
# 1. 确认线程创建本身是否正常
$ docker exec -it ai-agent bash
root@20852456e5b8:/app# python3 -c "
import concurrent.futures
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:
    f = ex.submit(lambda: 'ok')
    print(f.result())
"
Traceback (most recent call last):
  File "<string>", line 4, in <module>
    f = ex.submit(lambda: 'ok')
  File "/usr/local/lib/python3.13/concurrent/futures/thread.py", line 180, in submit
    self._adjust_thread_count()
    ~~~~~~~~~~~~~~~~~~~~~~~~~^^
  File "/usr/local/lib/python3.13/concurrent/futures/thread.py", line 203, in _adjust_thread_count
    t.start()
    ~~~~~~~^^
  File "/usr/local/lib/python3.13/threading.py", line 976, in start
    _start_joinable_thread(self._bootstrap, handle=self._handle,
    ~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                           daemon=self.daemon)
                           ^^^^^^^^^^^^^^^^^^^
RuntimeError: can't start new thread

# 2. 查 seccomp 状态
root@20852456e5b8:/app# cat /proc/self/status | grep -i seccomp
Seccomp:        2

# 3. 查容器的 clone 权限
root@20852456e5b8:/app# cat /proc/self/status | grep -i cap
CapInh: 00000000a80425fb
CapPrm: 00000000a80425fb
CapEff: 00000000a80425fb
CapBnd: 00000000a80425fb
CapAmb: 0000000000000000
```



**Seccomp 常见模式（取值）**：

- 1️⃣ **SECCOMP_MODE_DISABLED**

  - 值：`0`

  - 含义：不启用 Seccomp（默认）

  - 行为：进程可以调用所有系统调用

- 2️⃣ **SECCOMP_MODE_STRICT**

  - 值：`1`

  - 含义：严格模式（老模式）

  - 允许的 syscall 只有：
    - `read`
    - `write`
    - `_exit`
    - `sigreturn`

​	👉 其他 syscall 直接 **被杀死（SIGKILL）**

​	⚠️ 几乎不可用（太严格）

- 3️⃣ **SECCOMP_MODE_FILTER（最常用）**

  - 值：`2`

  - 含义：基于 BPF（Berkeley Packet Filter）的过滤模式

  - 可以自定义规则（allow / deny / trap / log）

​	👉 Docker / Kubernetes 使用的就是这个



------

**`clone3` 是 `clone` 的增强版（Linux 5.3+），用于创建线程/进程**：

- 支持结构体参数（比 clone 更灵活）
- 支持更多 flags（如 pidfd）



### 1.2.2 根因分析

无法创建线程的根因：**Docker 默认 seccomp profile 拦截了 `clone3`**

```
Python 3.13 新线程创建路径：
  threading.start()
    → _start_joinable_thread()   ← Python 3.13 新增的 C 实现
      → clone3()                 ← 新的系统调用 (Linux 5.3+)
        → EPERM / SIGSYS         ← 被 Docker seccomp profile 拦截！
```

Docker 默认的 seccomp profile 是 **2016 年**写的白名单，`clone3` 是 **2019 年**才加入内核的新系统调用，**不在白名单里**。



```
Python 3.13  → 强制使用 _start_joinable_thread (基于 clone3)
Docker 旧版  → seccomp profile 没有 clone3 白名单
─────────────────────────────────────────────────
结果：所有线程创建都被 seccomp 静默拦截 → RuntimeError
```



Python 3.12 及以前用的是 `clone` 或 `pthread_create` 的老路径，所以没问题。

------



### 1.2.3 修复方案

`seccomp=unconfined` 会关闭**所有**系统调用过滤，生产环境不安全。

✅ **方案 1：升级 Docker（推荐）**

```bash
# Docker 20.10.10+ 已修复 seccomp profile，加入了 clone3
docker --version

# 升级 Docker
curl -fsSL https://get.docker.com | sh
```



✅ **方案 2：自定义 seccomp profile 只开放 clone3**

```bash
# 导出默认 profile
curl -o seccomp-default.json \
  https://raw.githubusercontent.com/moby/moby/master/profiles/seccomp/default.json

# 在 "syscalls" 数组里加入 clone3
{
  "names": ["clone3"],
  "action": "SCMP_ACT_ALLOW",
  "args": [],
  "comment": "allow clone3 for Python 3.13 threading",
  "includes": {},
  "excludes": {}
}

# 使用自定义 profile 启动
docker run --security-opt seccomp=./seccomp-default.json your-image

# docker-compose.yml
services:
  app:
    image: your-image
    security_opt:
      - seccomp=./seccomp-default.json
```



✅ **方案 3：换回 Python 3.11/3.12（规避问题）**

```dockerfile
# Python 3.11/3.12 不强制使用 clone3
FROM python:3.12-slim

# 不需要任何 seccomp 修改
```



✅ **方案 4：编译时禁用 _start_joinable_thread（不推荐）**

```dockerfile
# 通过环境变量回退到旧线程实现（实验性）
ENV PYTHON_THREAD_FORCE_OLD=1
```



**方案对比：**

| 方案                   | 安全性 | 改动成本 | 推荐度           |
| ---------------------- | ------ | -------- | ---------------- |
| `seccomp=unconfined`   | ❌ 最低 | 最小     | 仅限开发环境     |
| 升级 Docker            | ✅ 最高 | 中       | ⭐⭐⭐ 生产首选     |
| 自定义 seccomp profile | ✅ 高   | 中       | ⭐⭐⭐ 无法升级时用 |
| 换 Python 3.12         | ✅ 高   | 大       | ⭐⭐ 新项目不推荐  |

**生产环境推荐：升级 Docker 到 20.10.10+ 或使用自定义 seccomp profile 加入 `clone3` 白名单。**



## 1.3 合并分析

### 1.3.1 同一个问题的两个症状

```
Docker 旧版 seccomp profile 缺少新系统调用
          │
          ├─── clone3 被拦截
          │         │
          │         ├── OpenBLAS: pthread_create failed    ← 第一个报错
          │         └── RuntimeError: can't start new thread  ← 第二个报错
          │
          └── 本质是同一件事：线程无法创建
```



### 1.3.2 时间线还原

```
你的排查过程：

1. OpenBLAS blas_thread_init: pthread_create failed   ← 以为是 ulimit
2. RuntimeError: can't start new thread               ← 以为是内存/mmap
3. ulimit ✅  max_map_count ✅  内存 ✅  全部正常      ← 排除系统资源
4. seccomp=unconfined 后恢复正常                      ← 确认根因
                                                      
根因：Docker 旧版 seccomp 白名单缺 clone3
```



### 1.3.3 两个报错的触发路径

```
OpenBLAS 错误：
  import numpy / scipy
    → OpenBLAS 初始化
      → pthread_create()
        → 内部调用 clone3()
          → seccomp EPERM
            → "pthread_create failed for thread 1 of 8"

Python 线程错误：
  threading.Thread().start()
    → _start_joinable_thread()   ← Python 3.13 新增
      → clone3()
        → seccomp EPERM
          → "RuntimeError: can't start new thread"
```



### 1.3.4 结论

| 症状                                 | 表面原因               | 真实根因                   |
| ------------------------------------ | ---------------------- | -------------------------- |
| OpenBLAS pthread_create failed       | 以为是 ulimit/资源不足 | Docker seccomp 拦截 clone3 |
| RuntimeError: can't start new thread | 以为是线程数耗尽       | Docker seccomp 拦截 clone3 |
| `seccomp=unconfined` 修复            | —                      | 确认根因 ✅                 |

**升级 Docker ≥ 20.10.10 或使用自定义 seccomp profile 加入 `clone3`，两个报错会同时消失。**
