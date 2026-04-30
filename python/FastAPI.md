# 1. 响应处理

## 1.1 统一格式

```python
# core/response.py
from pydantic.generics import GenericModel
from typing import Generic, TypeVar, Optional

T = TypeVar("T")

# 定义通用响应模型（支持泛型）
class Response(GenericModel, Generic[T]):
    code: int = 0
    message: str = "success"
    data: Optional[T] = None
```



## 1.2 全局异常处理

```python
# core/exception.py
# 自定义业务异常
class BusinessException(Exception):
    def __init__(self, code: int = 4001, message: str = "业务异常"):
        self.code = code
        self.message = message

# 注册异常处理器        
def register_exceptions(app: FastAPI):
    @app.exception_handler(BusinessException)
    async def business_handler(request: Request, exc: BusinessException):
        return JSONResponse(
            status_code=200,
            content={"code": exc.code, "message": exc.message, "data": None}
        )

    @app.exception_handler(Exception)
    async def global_handler(request: Request, exc: Exception):
        return JSONResponse(
            status_code=500,
            content={"code": 5000, "message": "系统错误", "data": None}
        )
```



```python
# main.py

app = FastAPI()
        
# 注册异常处理
register_exceptions(app)

# 异常处理
@app.get("/users/{user_id}", response_model=Response[UserOut])
async def get_user(user_id: int):
    user = await User.get_or_none(id=user_id)
    if not user:
        raise BusinessException(code=4040, message="用户不存在")
    return Response(data=user)
```



# 2. 依赖注入

## 2.1 数据库连接

通过 `yield` 的方式，每个请求都会自动管理这个连接的生命周期，执行完毕后自动关闭。

```python
# database.py
from tortoise.transactions import in_transaction

async def get_db():
    async with in_transaction() as connection:
        yield connection
```



使用：

```python
# api/user.py
from fastapi import APIRouter, Depends
from database import get_db

router = APIRouter()

@router.get("/users")
async def get_users(db=Depends(get_db)):
    return await db.execute_query_dict("SELECT * FROM user")
```

🎯 优点：

- 保证事务一致性
- 避免重复创建连接
- 易于测试（可替换 `get_db`）



## 2.2 权限验证

权限校验是每个 Web 接口的“守门人”。通过 DI，可以实现灵活、统一的权限控制逻辑。

```python
# auth.py
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from models import User  # 假设你有一个 User 模型

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login")

def decode_token(token: str):
    # 实际项目中请用 JWT 解码
    if token == "admin-token":
        return {"id": 1, "is_admin": True}
    elif token == "user-token":
        return {"id": 2, "is_admin": False}
    returnNone

async def verify_token(token: str = Depends(oauth2_scheme)) -> int:
    user = decode_token(token)
    ifnot user:
        raise HTTPException(status_code=401, detail="Invalid token")
    return user["id"]

async def admin_required(user_id: int = Depends(verify_token)):
    user = await User.get(id=user_id)
    ifnot user.is_admin:
        raise HTTPException(status_code=403, detail="Admin only")
    return user
```



👨‍💻 使用方式：

```python
@app.get("/admin")
async def admin_dashboard(current_user=Depends(admin_required)):
    return {"msg": f"Welcome admin {current_user.username}"}
```

🎯 优点：

- 权限逻辑集中管理
- 可灵活复用（普通用户、管理员等）
- 更易调试和测试



## 2.3 请求上下文

如果你想记录用户 IP、来源、设备信息等，可以封装一个请求上下文依赖。

```python
# context.py
from fastapi import Request

async def get_request_context(request: Request):
    return {
        "ip": request.client.host,
        "user_agent": request.headers.get("user-agent"),
        "headers": dict(request.headers)
    }
```

👨‍💻 使用方式：

```python
@app.get("/log")
async def log(ctx = Depends(get_request_context)):
    print(f"来自 {ctx['ip']} 的请求，UA: {ctx['user_agent']}")
    return {"message": "Logged"}
```

🎯 优点：

- 自动提取请求相关数据
- 避免在每个接口中手动处理
- 支持结构化日志、追踪、限流等高级特性



## 2.4 单元测试

使用依赖注入后，**每一个外部服务（如数据库、权限、上下文）都可以在测试中 mock 掉**，不再依赖真实服务，非常适合 CI/CD 环境。

```python
from fastapi.testclient import TestClient
from main import app
from database import get_db

# Mock 数据库连接
async def override_get_db():
    class DummyDB:
        async def execute_query_dict(self, sql):
            return [{"id": 1, "username": "test_user"}]
    yield DummyDB()

app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)

def test_get_users():
    response = client.get("/users")
    assert response.status_code == 200
```

你也可以 override 权限验证、上下文获取等依赖项：

```python
from auth import verify_token

# mock 权限校验返回用户 id
app.dependency_overrides[verify_token] = lambda: 1
```

🎯 优点：

- ⚡ 测试更快，不依赖数据库
- 🧪 可控输入输出，断言更精准
- 🧹 没有副作用，测试隔离性强



# 3. 中间件

**Middleware**（中间件）是介于请求进入与响应返回之间的一段可插拔逻辑，可以用来处理：

- 日志记录
- 请求耗时
- 权限校验
- 跨域处理（CORS）
- 请求频率限制（Rate Limit）等



## 3.1 请求时间

```python
# middlewares/request_timer.py
import time
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
import logging

# 设置日志输出
logger = logging.getLogger("request_logger")
logger.setLevel(logging.INFO)

handler = logging.StreamHandler()
formatter = logging.Formatter('[%(asctime)s] %(levelname)s: %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)


class RequestTimerMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()

        response = await call_next(request)  # 执行请求处理链

        process_time = time.time() - start_time
        formatted_time = f"{process_time * 1000:.2f}ms"

        logger.info(f"{request.method} {request.url.path} - 耗时: {formatted_time}")

        # 可以添加到响应头中返回
        response.headers["X-Process-Time"] = formatted_time
        return response
```



添加中间件：

```python
# main.py
from fastapi import FastAPI
from middlewares.request_timer import RequestTimerMiddleware

app = FastAPI()

# 添加中间件
app.add_middleware(RequestTimerMiddleware)

# 示例路由
@app.get("/ping")
async def ping():
    return {"message": "pong"}
```



## 3.2 请求日志、耗时统计、IP黑名单

IP 拦截、请求记录、异常捕获、耗时统计、响应头注入

```python
import time
from fastapi import Request
from fastapi.responses import JSONResponse
import logging

logger = logging.getLogger(__name__)
BLACKLIST = set()  # 从配置文件读取

@app.middleware("http")
async def unified_middleware(request: Request, call_next):
    # 1. IP 黑名单检查
    client_ip = request.client.host
    if client_ip in BLACKLIST:
        return JSONResponse(status_code=403, content={"detail": "Forbidden"})
    
    # 2. 开始计时
    start = time.perf_counter()
    
    # 3. 记录请求
    logger.info(f"[{client_ip}] → {request.method} {request.url.path}")
    
    # 4. 执行请求
    try:
        response = await call_next(request)
    except Exception as e:
        logger.error(f"💥 异常: {e}")
        raise
    
    # 5. 计算耗时
    elapsed = time.perf_counter() - start
    
    # 6. 记录响应
    logger.info(f"[{client_ip}] ← {response.status_code} | {elapsed:.3f}s")
    
    # 7. 添加响应头
    response.headers["X-Process-Time"] = f"{elapsed:.3f}"
    
    return response
```



## 3.3 安全头（Security Headers）

```python
from fastapi.middleware.httpsredirect import HTTPSRedirectMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

app.add_middleware(HTTPSRedirectMiddleware)  # 强制 HTTPS
app.add_middleware(TrustedHostMiddleware, allowed_hosts=["example.com"])

# 自定义安全头
@app.middleware("http")
asyncdef add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    return response
```



## 3.4 CORS 精确配置

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://app.example.com", "https://admin.example.com"],  # 不写 "*"
    allow_credentials=True,  # 使用 Cookie 时必须为 True
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    expose_headers=["X-Request-ID"],
    max_age=3600,
)
```



## 3.5 请求 ID 贯穿全链路

```python
from starlette.middleware.base import BaseHTTPMiddleware
import uuid

class RequestIDMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        # 优先使用传入的 request-id，否则生成
        request_id = request.headers.get("x-request-id", uuid.uuid4().hex)
        request.state.request_id = request_id
        
        response = await call_next(request)
        response.headers["x-request-id"] = request_id
        return response

app.add_middleware(RequestIDMiddleware)
```



# 4. WebSocket

连接管理器:

```python
# chat_manager.py
from fastapi import WebSocket
from typing import Dict

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, username: str, websocket: WebSocket):
        await websocket.accept()
        self.active_connections[username] = websocket
        await self.broadcast(f"👋 用户【{username}】加入了聊天室")

    def disconnect(self, username: str):
        if username in self.active_connections:
            del self.active_connections[username]

    async def send_personal_message(self, message: str, to_user: str):
        if to_user in self.active_connections:
            await self.active_connections[to_user].send_text(message)

    async def broadcast(self, message: str):
        for ws in self.active_connections.values():
            await ws.send_text(message)
```

使用：

```python
# main.py
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Query
from chat_manager import ConnectionManager

app = FastAPI()
manager = ConnectionManager()

@app.websocket("/ws/chat/")
async def websocket_endpoint(websocket: WebSocket, username: str = Query(...)):
    await manager.connect(username, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type", "broadcast")
            content = data.get("message")
            to_user = data.get("to")

            if msg_type == "private" and to_user:
                await manager.send_personal_message(f"💌 私信【{username}】→【{to_user}】：{content}", to_user)
            else:
                await manager.broadcast(f"💬 【{username}】：{content}")
    except WebSocketDisconnect:
        manager.disconnect(username)
        await manager.broadcast(f"❌ 用户【{username}】离开了聊天室")
```



前端示例：

```html
<!DOCTYPE html>
<html>
<head><title>聊天</title></head>
<body>
  <h2>FastAPI 聊天室</h2>
  <input id="username" placeholder="用户名" />
  <button onclick="connect()">连接</button>

  <div>
    <input id="to" placeholder="发给谁（留空为群发）" />
    <input id="message" placeholder="消息内容" />
    <button onclick="send()">发送</button>
  </div>

  <ul id="messages"></ul>

  <script>
    let ws = null;
    function connect() {
      const username = document.getElementById("username").value;
      ws = new WebSocket("ws://localhost:8000/ws/chat/?username=" + username);
      ws.onmessage = event => {
        const li = document.createElement("li");
        li.innerText = event.data;
        document.getElementById("messages").appendChild(li);
      };
    }

    function send() {
      const msg = document.getElementById("message").value;
      const to = document.getElementById("to").value;
      const type = to ? "private" : "broadcast";
      ws.send(JSON.stringify({ type, message: msg, to }));
    }
  </script>
</body>
</html>
```



# 5. 启动关闭事件

在生产环境中，我们经常会遇到这样的需求：

- ✅ 项目启动时，需要连接数据库、加载机器学习模型或预热缓存
- ✅ 项目关闭时，需要优雅释放连接、清理资源，确保不会“僵尸占用”



## 5.1 生命周期

**方法一：使用 `@app.on_event()` 装饰器（经典方式）**

```python
from fastapi import FastAPI

app = FastAPI()

@app.on_event("startup")
async def startup_event():
    print("应用启动，初始化资源...")

@app.on_event("shutdown")
async def shutdown_event():
    print("应用关闭，释放资源...")
```



**方法二：使用 `lifespan()` 上下文函数（推荐方式）**

```python
from fastapi import FastAPI
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("✅ 应用启动 - startup")
    # 初始化资源
    yield
    print("🧹 应用关闭 - shutdown")
    # 清理资源

app = FastAPI(lifespan=lifespan)
```



## 5.2 应用场景

```python
# utils/database.py
class DBClient:
    def __init__(self):
        self.connected = False

    async def connect(self):
        print("🔌 正在连接数据库...")
        self.connected = True

    async def disconnect(self):
        print("❌ 正在关闭数据库连接...")
        self.connected = False

db_client = DBClient()


# utils/cache.py
cache = {}

async def preload_cache():
    print("⚡ 预热缓存中...")
    cache["hot_data"] = [1, 2, 3, 4]

async def clear_cache():
    print("🧹 清理缓存...")
    cache.clear()
    

# utils/model_loader.py
model = None

async def load_model():
    global model
    print("🤖 加载机器学习模型...")
    model = "MyModel"

async def unload_model():
    global model
    print("🧼 卸载模型...")
    model = None
    
    
# main.py
from fastapi import FastAPI
from contextlib import asynccontextmanager

from utils.database import db_client
from utils.cache import preload_cache, clear_cache
from utils.model_loader import load_model, unload_model

@asynccontextmanager
async def lifespan(app: FastAPI):
    # 应用启动
    await db_client.connect()
    await preload_cache()
    await load_model()
    yield
    # 应用关闭
    await db_client.disconnect()
    await clear_cache()
    await unload_model()

app = FastAPI(lifespan=lifespan)

@app.get("/")
async def root():
    return {"message": "Hello, FastAPI 生命周期！"}
```



# 6. 限流

基于 Redis Lua 的原子性限流：

```python
# rate_limit.py
import aioredis
from fastapi import Request, HTTPException, status
import time

# Lua 脚本在 Redis 中原子执行
LUA_SCRIPT = """
local key = KEYS[1]
local now = tonumber(ARGV[1])
local capacity = tonumber(ARGV[2])  -- 桶容量
local refill_rate = tonumber(ARGV[3])  -- 令牌补充速率（个/秒）
local cost = tonumber(ARGV[4])  -- 本次消耗的令牌数

-- 获取当前桶状态
local data = redis.call("HMGET", key, "tokens", "last_update")
local tokens = tonumber(data[1]) or capacity
local last_update = tonumber(data[2]) or now

-- 补充令牌
local delta = (now - last_update) * refill_rate
tokens = math.min(capacity, tokens + delta)

local allowed = 0
if tokens >= cost then
    tokens = tokens - cost
    allowed = 1
end

-- 保存新状态，设置过期时间
redis.call("HMSET", key, "tokens", tokens, "last_update", now)
redis.call("EXPIRE", key, 3600)

return {allowed, tokens}
"""

class RateLimiter:
    def __init__(self, redis: aioredis.Redis, capacity=100, refill_rate=50):
        """
        capacity: 桶容量（最大突发请求数）
        refill_rate: 令牌补充速率（每秒补充多少令牌）
        """
        self.redis = redis
        self.capacity = capacity
        self.refill_rate = refill_rate
        self.script = self.redis.register_script(LUA_SCRIPT)
    
    async def check(self, key: str, cost=1) -> bool:
        """检查是否允许请求"""
        # 使用 Redis 的时间戳，保证分布式一致性
        redis_time = await self.redis.time()
        now = float(redis_time[0]) + redis_time[1] / 1_000_000
        
        allowed, tokens = await self.script(
            keys=[f"rl:{key}"],
            args=[now, self.capacity, self.refill_rate, cost]
        )
        return bool(int(allowed))
    
    async def get_remaining(self, key: str) -> int:
        """获取剩余令牌数"""
        data = await self.redis.hmget(f"rl:{key}", "tokens")
        return int(data[0]) if data[0] else self.capacity

# 全局限流器实例
limiter = None

async def get_limiter():
    global limiter
    if limiter isNone:
        redis = await aioredis.from_url(
            "redis://localhost:6379", 
            decode_responses=True
        )
        limiter = RateLimiter(redis, capacity=100, refill_rate=50)
    return limiter

async def rate_limit(request: Request):
    """依赖注入：限流中间件"""
    limiter = await get_limiter()
    
    # 根据场景选择限流维度
    # 认证用户用 user_id，匿名用 IP
    user_id = request.headers.get("x-user-id")
    if user_id:
        key = f"user:{user_id}"
    else:
        key = f"ip:{request.client.host}"
    
    allowed = await limiter.check(key)
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded. Please slow down.",
            headers={"Retry-After": "30"}  # 告诉客户端 30 秒后重试
        )
```

在路由中使用：

```python
@app.get("/search", dependencies=[Depends(rate_limit)])
async def search(q: str):
    """搜索接口，限制 50 请求/秒，突发 100"""
    # 业务逻辑...
    return {"results": []}
```



**限流策略矩阵：**

| 路由类型 | 限流维度 | 推荐速率       | 说明               |
| :------- | :------- | :------------- | :----------------- |
| 匿名访问 | IP       | 10-30 req/s    | 防止爬虫           |
| 认证用户 | user_id  | 50-200 req/s   | 根据业务调整       |
| API 密钥 | api_key  | 100-1000 req/s | 合作伙伴可单独配置 |
| 登录接口 | IP       | 5 req/min      | 防止暴力破解       |
| 支付接口 | user_id  | 2 req/s        | 敏感操作低频率     |



# 7. 优雅关闭

收到终止信号后，不再接收新请求，但继续处理完已有的请求，然后才退出。

**Uvicorn + Lifespan 最佳实践**：

```python
# main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI
import asyncpg
import aioredis
import asyncio

@asynccontextmanager
async def lifespan(app: FastAPI):
    """生命周期管理：打开/关闭连接池"""
    # 启动时执行
    app.state.db_pool = await asyncpg.create_pool(
        "postgresql://user:pass@localhost/db",
        min_size=5,
        max_size=20
    )
    app.state.redis = await aioredis.from_url(
        "redis://localhost:6379",
        decode_responses=True
    )
    
    yield# 应用运行期间
    
    # 关闭时执行（优雅关闭时会等待）
    await app.state.db_pool.close()
    await app.state.redis.close()

app = FastAPI(lifespan=lifespan)

@app.get("/health/live")
async def liveness():
    """存活探针：进程是否还在"""
    return {"status": "alive"}

@app.get("/health/ready")
async def readiness():
    """就绪探针：依赖是否就绪"""
    try:
        # 检查数据库
        async with app.state.db_pool.acquire() as conn:
            await conn.execute("SELECT 1")
        # 检查 Redis
        await app.state.redis.ping()
        return {"status": "ready"}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Not ready: {e}"
        )
```

**镜像编译：**

```dockerfile
# Dockerfile
FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# 多 worker 启动，优雅关闭超时 30 秒
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", \
    "--workers", "4", "--graceful-timeout", "30"]
```



# 8. 结构化日志

```python
import logging
import json
from datetime import datetime

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "request_id": getattr(record, "request_id", "unknown"),
            "route": getattr(record, "route", "unknown"),
            "duration_ms": getattr(record, "duration_ms", 0),
        }
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_entry)

# 配置日志
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logging.basicConfig(level=logging.INFO, handlers=[handler])
logger = logging.getLogger(__name__)
```



# 9. 扩展

## 9.1 FastAPI Users：让身份验证不再痛苦

FastAPI Users 是一个即插即用的身份验证和用户管理库。它开箱即用地支持 JWT、OAuth2，甚至社交登录。

```python
from fastapi import FastAPI, Depends
from fastapi_users import FastAPIUsers, models
from fastapi_users.db import SQLAlchemyUserDatabase
from fastapi_users.authentication import JWTAuthentication
import sqlalchemy as sa
from sqlalchemy.ext.declarative import DeclarativeMeta, declarative_base
from sqlalchemy.orm import sessionmaker, Session

# 创建数据库模型
Base: DeclarativeMeta = declarative_base()

class UserTable(Base, models.BaseUserTable):
    # 可以在这里添加自定义字段
    name = sa.Column(sa.String, nullable=True)

# 创建 FastAPI 应用
app = FastAPI()

# 数据库配置（示例）
DATABASE_URL = "sqlite:///./test.db"
engine = sa.create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 创建表
Base.metadata.create_all(bind=engine)

# 用户模型定义
class User(models.BaseUser):
    name: str = None

class UserCreate(models.BaseUserCreate):
    name: str = None

class UserUpdate(models.BaseUserUpdate):
    name: str = None

class UserDB(User, models.BaseUserDB):
    pass

# 获取数据库会话
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 创建用户数据库适配器
def get_user_db(session: Session = Depends(get_db)):
    yield SQLAlchemyUserDatabase(UserDB, session, UserTable)

# JWT 配置
SECRET = "YOUR_SECRET_KEY"
jwt_authentication = JWTAuthentication(
    secret=SECRET, 
    lifetime_seconds=3600,
    tokenUrl="auth/jwt/login"
)

# 初始化 FastAPI Users
fastapi_users = FastAPIUsers(
    get_user_db,
    [jwt_authentication],
    User,
    UserCreate,
    UserUpdate,
    UserDB,
)

# 包含认证路由
app.include_router(
    fastapi_users.get_auth_router(jwt_authentication),
    prefix="/auth/jwt",
    tags=["auth"]
)

app.include_router(
    fastapi_users.get_register_router(),
    prefix="/auth",
    tags=["auth"]
)

# 受保护的路由示例
@app.get("/protected-route")
async def protected_route(user: User = Depends(fastapi_users.current_user())):
    return {"message": f"Hello {user.email}, you are authenticated!"}
```



## 9.2 FastAPI-Mail：优雅地发送邮件

```python
from fastapi import FastAPI, BackgroundTasks
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig
from pydantic import EmailStr, BaseModel
from typing import List

app = FastAPI()

# 邮件配置
conf = ConnectionConfig(
    MAIL_USERNAME = "your-email@gmail.com",
    MAIL_PASSWORD = "your-app-password",  # 注意：使用应用专用密码
    MAIL_FROM = "your-email@gmail.com",
    MAIL_PORT = 587,
    MAIL_SERVER = "smtp.gmail.com",
    MAIL_TLS = True,
    MAIL_SSL = False,
    USE_CREDENTIALS = True,
    VALIDATE_CERTS = True
)

fm = FastMail(conf)

# 邮件数据模型
class EmailSchema(BaseModel):
    email: List[EmailStr]
    subject: str = "FastAPI Mail"
    body: str

async def send_email_async(email: EmailSchema):
    message = MessageSchema(
        subject=email.subject,
        recipients=email.email,
        body=email.body,
        subtype="html"# 或 "plain"
    )
    await fm.send_message(message)

@app.post("/send-email")
async def send_email(
    background_tasks: BackgroundTasks, 
    email_data: EmailSchema
):
    """
    异步发送邮件
    """
    background_tasks.add_task(send_email_async, email_data)
    return {"message": "邮件已加入发送队列"}

# 同步发送示例
@app.post("/send-email-sync")
async def send_email_sync(email_data: EmailSchema):
    message = MessageSchema(
        subject=email_data.subject,
        recipients=email_data.email,
        body=email_data.body,
    )
    await fm.send_message(message)
    return {"message": "邮件发送成功"}

# 发送带附件的邮件
@app.post("/send-email-with-attachment")
async def send_with_attachment(email_data: EmailSchema):
    message = MessageSchema(
        subject=email_data.subject,
        recipients=email_data.email,
        body=email_data.body,
        attachments=[{
            "file": "path/to/file.pdf",
            "filename": "document.pdf"
        }]
    )
    await fm.send_message(message)
    return {"message": "带附件的邮件发送成功"}
```



## 9.3 FastAPI-SocketIO：无痛实现实时功能

```python
from fastapi import FastAPI
from fastapi_socketio import SocketManager
from typing import Optional
import asyncio

app = FastAPI()
socket_manager = SocketManager(app=app, mount_location="/ws/")

# 连接事件
@socket_manager.on("connect")
async def handle_connect(sid, environ, auth):
    print(f"客户端 {sid} 已连接")
    await socket_manager.emit("welcome", {"msg": "欢迎加入聊天室"}, to=sid)

# 消息事件
@socket_manager.on("message")
async def handle_message(sid, data):
    print(f"来自 {sid} 的消息: {data}")
    # 广播给所有客户端
    await socket_manager.emit("response", {
        "from": sid[:8],  # 显示短ID
        "msg": data["message"]
    })

# 私聊示例
@socket_manager.on("private_message")
async def handle_private_message(sid, data):
    target_sid = data.get("target_sid")
    message = data.get("message")
    
    if target_sid:
        await socket_manager.emit("private", {
            "from": sid[:8],
            "msg": message
        }, to=target_sid)
    else:
        await socket_manager.emit("error", {"msg": "目标用户未指定"}, to=sid)

# 断开连接事件
@socket_manager.on("disconnect")
async def handle_disconnect(sid):
    print(f"客户端 {sid} 已断开连接")
    # 通知其他用户
    await socket_manager.emit("user_left", {"user": sid[:8]})

# HTTP 端点与 WebSocket 结合
@app.get("/online-users")
async def get_online_users():
    """获取在线用户列表"""
    # socket_manager.server.rooms 包含连接信息
    return {"online_count": len(socket_manager.get_participants("/"))}

# 从 HTTP 端点触发 WebSocket 事件
@app.post("/broadcast")
async def broadcast_message(message: str):
    """向所有连接的客户端广播消息"""
    await socket_manager.emit("broadcast", {
        "from": "server",
        "msg": message,
        "timestamp": asyncio.get_event_loop().time()
    })
    return {"status": "广播发送成功"}
```



## 9.4 FastAPI-Limiter：专业级的限流方案

```python
from fastapi import FastAPI, Depends, Request, HTTPException
from fastapi_limiter import FastAPILimiter
from fastapi_limiter.depends import RateLimiter
import aioredis
import asyncio

app = FastAPI()

@app.on_event("startup")
async def startup():
    """
    初始化 Redis 连接和限流器
    """
    redis = await aioredis.create_redis_pool("redis://localhost")
    await FastAPILimiter.init(redis)

# 基础限流：每分钟 5 次请求
@app.get("/api/data", dependencies=[Depends(RateLimiter(times=5, seconds=60))])
async def get_data():
    return {"message": "您在速率限制内！"}

# 更复杂的限流策略
@app.get("/api/premium-data", dependencies=[Depends(RateLimiter(times=10, seconds=60))])
async def get_premium_data(request: Request):
    """
    针对付费用户的高限额
    """
    # 可以通过请求头或其他方式识别用户身份
    user_type = request.headers.get("X-User-Type", "free")
    
    if user_type == "premium":
        # 动态调整限制
        pass
    
    return {"data": "高级数据内容"}

# 基于 IP 的限流
@app.get("/api/public")
@RateLimiter(times=2, seconds=30, key_func=lambda request: request.client.host)
async def public_api():
    return {"message": "公共 API，限制较严格"}

# 异常处理
@app.exception_handler(429)
async def rate_limit_exception_handler(request: Request, exc):
    """
    处理速率限制超出异常
    """
    return JSONResponse(
        status_code=429,
        content={
            "error": "请求过多",
            "message": "请稍后再试",
            "retry_after": 60# 建议的重试时间（秒）
        }
    )

# 监控端点（用于调试）
@app.get("/rate-limit-info")
async def rate_limit_info(request: Request):
    """
    获取当前请求的限流信息
    """
    client_ip = request.client.host
    # 这里可以添加获取具体限流状态的逻辑
    return {
        "client_ip": client_ip,
        "rate_limited": False,
        "remaining": 5
    }
```



## 9.5 FastAPI-Cache：无痛加速

```python
from fastapi import FastAPI, Query
from fastapi_cache import FastAPICache, JsonCoder
from fastapi_cache.backends.redis import RedisBackend
from fastapi_cache.decorator import cache
import aioredis
from datetime import timedelta
from typing import Optional

app = FastAPI()

@app.on_event("startup")
async def startup():
    """
    初始化 Redis 缓存后端
    """
    redis = aioredis.from_url("redis://localhost")
    FastAPICache.init(RedisBackend(redis), prefix="fastapi-cache")

# 基础缓存：60秒过期
@app.get("/products")
@cache(expire=60)
async def get_products():
    """
    获取产品列表 - 结果缓存60秒
    """
    # 模拟数据库查询
    await asyncio.sleep(2)  # 模拟耗时操作
    return {"products": ["手机", "电脑", "平板", "耳机"]}

# 带参数的缓存
@app.get("/product/{product_id}")
@cache(expire=30, key_builder=lambda *args, **kwargs: f"product:{kwargs['product_id']}")
async def get_product(product_id: int):
    """
    获取单个产品信息
    """
    await asyncio.sleep(1)
    return {"id": product_id, "name": f"产品{product_id}", "price": 99.99}

# 条件缓存
@app.get("/search")
@cache(expire=60, unless=lambda response: response.status_code != 200)
async def search_products(
    q: str = Query(None, min_length=1),
    page: int = Query(1, ge=1)
):
    """
    搜索产品 - 只在响应成功时缓存
    """
    ifnot q:
        return {"error": "请输入搜索关键词"}
    
    await asyncio.sleep(1.5)
    return {
        "query": q,
        "page": page,
        "results": [f"{q}结果{i}"for i in range(10)],
        "total": 100
    }

# 手动缓存操作
from fastapi_cache import FastAPICache
from fastapi_cache.coder import JsonCoder

@app.get("/manual-cache")
async def manual_cache_demo():
    """
    手动缓存控制示例
    """
    backend = FastAPICache.get_backend()
    cache_key = "manual:data"
    
    # 尝试从缓存获取
    cached_data = await backend.get(cache_key)
    if cached_data:
        return {"source": "cache", "data": JsonCoder().decode(cached_data)}
    
    # 生成新数据
    new_data = {"id": 1, "value": "新生成的数据"}
    
    # 存入缓存
    await backend.set(cache_key, JsonCoder().encode(new_data), expire=120)
    
    return {"source": "database", "data": new_data}

# 清除缓存
@app.post("/clear-cache/{pattern}")
async def clear_cache(pattern: str = "*"):
    """
    清除匹配模式的缓存
    """
    backend = FastAPICache.get_backend()
    if isinstance(backend, RedisBackend):
        redis_client = backend.redis
        keys = await redis_client.keys(f"{FastAPICache.get_prefix()}{pattern}")
        if keys:
            await redis_client.delete(*keys)
            return {"cleared": len(keys)}
    return {"cleared": 0}
```



## 9.6 FastAPI-CrudRouter — 5行代码搞定 CRUD

```python
from fastapi import FastAPI
from fastapi_crudrouter import SQLAlchemyCRUDRouter
from pydantic import BaseModel
from typing import Optional, List
import sqlalchemy as sa
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from datetime import datetime

# 创建数据库模型
Base = declarative_base()

class ItemModel(Base):
    __tablename__ = "items"
    
    id = sa.Column(sa.Integer, primary_key=True, index=True)
    name = sa.Column(sa.String, index=True)
    description = sa.Column(sa.String, nullable=True)
    price = sa.Column(sa.Float)
    created_at = sa.Column(sa.DateTime, default=datetime.utcnow)
    updated_at = sa.Column(sa.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# Pydantic 模型
class ItemBase(BaseModel):
    name: str
    description: Optional[str] = None
    price: float

class ItemCreate(ItemBase):
    pass

class ItemUpdate(ItemBase):
    name: Optional[str] = None
    price: Optional[float] = None

class ItemResponse(ItemBase):
    id: int
    created_at: datetime
    updated_at: datetime
    
    class Config:
        orm_mode = True

# 数据库配置
DATABASE_URL = "sqlite:///./crud.db"
engine = sa.create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

app = FastAPI()

# 神奇的一行：创建完整 CRUD 路由
item_router = SQLAlchemyCRUDRouter(
    schema=ItemResponse,
    create_schema=ItemCreate,
    update_schema=ItemUpdate,
    db_model=ItemModel,
    db=get_db,
    prefix="items",
    tags=["商品管理"]
)

app.include_router(item_router)

# 扩展功能：自定义路由
@app.get("/items/search/{keyword}")
def search_items(keyword: str, db: Session = Depends(get_db)):
    """
    自定义搜索端点
    """
    results = db.query(ItemModel).filter(ItemModel.name.contains(keyword)).all()
    return results

# 复杂查询示例
@app.get("/items/expensive/{min_price}")
def get_expensive_items(min_price: float, db: Session = Depends(get_db)):
    """
    获取价格高于指定值的商品
    """
    items = db.query(ItemModel).filter(ItemModel.price >= min_price).order_by(ItemModel.price.desc()).all()
    return items

# 统计端点
@app.get("/items/stats")
def get_item_stats(db: Session = Depends(get_db)):
    """
    获取商品统计信息
    """
    total_items = db.query(ItemModel).count()
    total_value = db.query(sa.func.sum(ItemModel.price)).scalar() or0
    avg_price = db.query(sa.func.avg(ItemModel.price)).scalar() or0
    
    return {
        "total_items": total_items,
        "total_value": total_value,
        "average_price": round(avg_price, 2),
        "most_expensive": db.query(ItemModel).order_by(ItemModel.price.desc()).first()
    }
```



## 9.7 FastAPI-Plugins：一统江湖的扩展包

FastAPI-Plugins 感觉像是把所有工具打包进了一个箱子里。它为你提供了 Redis、调度器、缓存和日志记录，全部开箱即用。

```python
from fastapi import FastAPI, Depends
from fastapi_plugins import (
    RedisSettings, 
    depends_redis, 
    redis_plugin,
    RedisPlugin
)
from fastapi_plugins.cache import cache_plugin, CacheSettings
import aioredis
from contextlib import asynccontextmanager
from typing import Any

# 配置设置
class AppSettings(RedisSettings, CacheSettings):
    api_name: str = "fastapi-plugins-demo"
    redis_url: str = "redis://localhost:6379/0"
    cache_ttl: int = 300# 缓存过期时间（秒）

settings = AppSettings()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    应用生命周期管理
    """
    # 启动时
    await redis_plugin.init_app(app, config=settings)
    await redis_plugin.init()
    await cache_plugin.init_app(app, config=settings)
    await cache_plugin.init()
    
    yield
    
    # 关闭时
    await redis_plugin.terminate()
    await cache_plugin.terminate()

app = FastAPI(lifespan=lifespan)

# Redis 操作示例
@app.get("/redis-demo")
async def redis_demo(redis: aioredis.Redis = Depends(depends_redis)):
    """
    演示基本的 Redis 操作
    """
    # 设置值
    await redis.set("my_key", "Hello from FastAPI!")
    
    # 获取值
    value = await redis.get("my_key")
    
    # 设置过期时间
    await redis.setex("temp_key", 60, "临时数据")
    
    # 增加计数器
    await redis.incr("counter")
    counter = await redis.get("counter")
    
    # 存储列表
    await redis.lpush("my_list", "item1", "item2", "item3")
    list_items = await redis.lrange("my_list", 0, -1)
    
    # 存储哈希
    await redis.hset("user:1000", mapping={"name": "Alice", "age": "30"})
    user_data = await redis.hgetall("user:1000")
    
    return {
        "simple_value": value.decode() if value elseNone,
        "counter": counter.decode() if counter elseNone,
        "list_items": [item.decode() for item in list_items],
        "user_data": {k.decode(): v.decode() for k, v in user_data.items()}
    }

# 缓存示例
from fastapi_plugins.cache import depends_cache

@app.get("/cached-data")
@cache_plugin.cached(ttl=60)
async def get_cached_data():
    """
    自动缓存响应的端点
    """
    # 模拟耗时操作
    import asyncio
    await asyncio.sleep(2)
    return {"data": "这是缓存的数据", "timestamp": datetime.utcnow().isoformat()}

# 发布/订阅示例
@app.get("/publish/{channel}")
async def publish_message(
    channel: str, 
    message: str,
    redis: aioredis.Redis = Depends(depends_redis)
):
    """
    向 Redis 频道发布消息
    """
    subscribers = await redis.publish(channel, message)
    return {"channel": channel, "message": message, "subscribers": subscribers}

# 监控端点
@app.get("/redis-info")
async def redis_info(redis: aioredis.Redis = Depends(depends_redis)):
    """
    获取 Redis 服务器信息
    """
    info = await redis.info()
    
    # 获取所有键
    keys = await redis.keys("*")
    
    return {
        "redis_version": info.get("redis_version"),
        "connected_clients": info.get("connected_clients"),
        "used_memory_human": info.get("used_memory_human"),
        "total_keys": len(keys),
        "sample_keys": [key.decode() for key in keys[:10]] if keys else []
    }

# 任务调度示例（需安装额外依赖）
try:
    from fastapi_plugins.scheduler import scheduler_plugin, SchedulerSettings
    
    class ExtendedSettings(AppSettings, SchedulerSettings):
        pass
    
    settings = ExtendedSettings()
    
    @scheduler_plugin.task("interval", seconds=30)
    async def scheduled_task():
        """
        每30秒运行一次的定时任务
        """
        print(f"定时任务执行于 {datetime.utcnow()}")
        # 这里可以添加清理缓存、发送报告等逻辑
    
    @app.get("/scheduler/jobs")
    async def get_scheduled_jobs():
        """
        获取所有计划任务
        """
        scheduler = scheduler_plugin.get_scheduler()
        jobs = scheduler.get_jobs()
        return {"jobs": [str(job) for job in jobs]}
    
except ImportError:
    print("注意：未安装调度器扩展，相关功能不可用")
```

# 10. Pydantic

## 10.1 严格模式

默认会自动做类型转换。数字字符串会转成数字，`"true"`变成`True`，整数`1`变成浮点`10.0`。它的设计初衷比较“宽容”。

**严格模式下，阻止自动类型转换**

```python
from pydantic import BaseModel, ConfigDict, StrictInt, StrictStr

# 默认：自动类型转换
class PaymentLoose(BaseModel):
    amount: float
    currency: str

# 全局严格模式：拒绝类型不匹配
class PaymentStrict(BaseModel):
    model_config = ConfigDict(strict=True)

    amount: float
    currency: str

# 字段严格模式
class Order(BaseModel):
    quantity: StrictInt       # 必须是整数
    product_name: StrictStr   # 必须是字符串
    note: str | None = None   # 任然可转换

if __name__ == '__main__':
    p1 = PaymentLoose(amount="9.99", currency="USD")
    print(p1)   # amount=9.99 currency='USD'

    p2 = PaymentStrict(amount="9.99", currency="USD")
    print(p2)  # ValidationError

    o = Order(quantity="5", product_name="Banana", note="banana")
    print(o)   # ValidationError
```



## 10.2 字段约束

`Field()` 内置字段约束，替代自定义校验器 `@field_validator`

```python
from pydantic import BaseModel, Field, EmailStr

class CreateUser(BaseModel):
    user: str = Field(min_length=3, max_length=20, pattern=r'^[a-zA-Z0-9_]+$')
    email: EmailStr = Field(max_length=64)
    age: int = Field(ge=13, le=120)
    bio: str | None = Field(default=None, max_length=500)
    referral_code: str | None = Field(default=None, min_length=8, max_length=8)
```



## 10.3 为创建、更新、响应分别建模型

不要试图一个模型包揽所有操作，而是按操作类型分别建模型

```python
from datetime import datetime
from pydantic import BaseModel, Field, EmailStr, ConfigDict

# 创建用户
class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=20)
    email: EmailStr
    password: str = Field(min_length=8, max_length=20)

# 更新用户
class UpdateUser(BaseModel):
    username: str | None = Field(default=None, min_length=3, max_length=20)
    email: EmailStr | None = None
    bio: str | None = Field(default=None, max_length=500)

# API响应
class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    bio: str | None
    created_at: datetime

    # 可以从ORM对象 (如SQLAlchemy模型实例) 读取数据，而不仅仅是字典
    model_config = ConfigDict(from_attributes=True)

########################## 使用模型 ###########################
from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy.orm import Session

app = FastAPI()

@app.get("/users", response_model=UserResponse)
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    user = User(**payload.model_dump())
    user.password = hash_password(payload.password)
    db.add(user)
    db.commit()
    return user

@app.patch("/users/{user_id}", response_model=UserResponse)
def update_user(user_id: int, payload: UpdateUser, db: Session = Depends(get_db)):
    user = db.query(User).get(user_id)
    update_data = payload.model_dump(exclude_unset=True)  # 过滤掉未设置的字段
    for key, value in update_data.items():
        setattr(user, key, value)
    db.commit()
    return user
```



## 10.4 跨字段校验

字段组合校验，该使用 `@model_validator`

```python
from datetime import date

from pydantic import BaseModel, model_validator, ValidationError

# mode='after' 在所有字段校验后执行
class DateRange(BaseModel):
    start_date: date
    end_date: date

    @model_validator(mode='after')
    def validate_date_range(self):
        if self.end_date <= self.start_date:
            raise ValidationError('结束日期必须在开始时间之后')
        if (self.end_date - self.start_date).days > 365:
            raise ValidationError('日期范围不能超过365天')
        return self

class DiscountRule(BaseModel):
    discount_type: str     # "percentage" 或 "fixed"
    discount_value: float

    @model_validator(mode='after')
    def validate_discount_rule(self):
        if self.discount_type == "percentage" and not (0 < self.discount_value <= 100):
            raise ValidationError('百分比折扣必须在0到100之间')
        if self.discount_type == "fixed" and self.discount_value <= 0:
            raise ValidationError('固定折扣必须为正数')
        return self


# mode='before' 字段校验前执行，适合做数据预处理
class FlexibleUserInput(BaseModel):
    name: str
    email: str

    @model_validator(mode='before')
    @classmethod
    def normalize_input(cls, data):
        if isinstance(data, dict):
            # 对所有字符串字段去除首尾空格
            for key, value in data.items():
                if isinstance(value, str):
                    data[key] = value.strip()
            # 字段校验前，将邮箱转为小写
            if 'email' in data and isinstance(data['email'], str):
                data['email'] = data['email'].lower().strip()
        return data
```



## 10.5 自定义错误信息

Pydantic 校验错误，FastAPI 默认返回 422 错误响应

```json
{
    "detail": [
        {
            "type": "string_too_short",
            "loc": ["body", "password"],
            "msg": "String should have at least 8 characters",
            "input": "abc"
        }
    ]
}
```

不够友好，需要自定义校验错误处理的方式：

```python
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

app = FastAPI()

@app.exception_handler(RequestValidationError)
async def request_validation_error_handler(request: Request, exc: RequestValidationError):
    errors = {}
    for error in exc.errors():
        # 从 location 元组中获取字段名
        field = error['loc'][-1] if error['loc'] else 'unknown'
        # 错误信息
        errors[field] = error['msg']

    return JSONResponse(
        status_code=400,
        content={
            "success": False,
            "message": "校验失败",
            "errors": errors
        })
```

新的响应：

```json
{
    "success": false,
    "message": "校验失败",
    "errors": {
        "password": "String should have at least 8 characters",
        "email": "value is not a valid email address"
    }
}
```



## 10.6 可复用字段

如果多个模型需要校验手机号、slug或币种等，可使用自定义注解类型，一次定义，多处复用

```python
from typing import Annotated
from pydantic import AfterValidator, Field, BaseModel

def validate_phone(value: str) -> str:
    cleaned = ''.join(c for c in value if c.isdigit() or c == '+')
    if not (10 <= len(cleaned) <= 15):
        raise ValueError('手机号必须是10-15位数字')
    return cleaned

def validate_slug(value: str) -> str:
    import re
    if not re.match('^[a-z0-9]+(?:-[a-z0-9]+)*$', value):
        raise ValueError('slug必须是小写字母或数字，单词间用连字符连接')
    return value

def validate_currency_code(value: str) -> str:
    valid_currency_codes = {'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CNY'}
    currency = value.upper()
    if currency not in valid_currency_codes:
        raise ValueError(f'币种必须是以下之一：{", ".join(sorted(valid_currency_codes))}')
    return currency

#### 定义可复用类型
PhoneNumber = Annotated[str, AfterValidator(validate_phone)]
Slug = Annotated[str, Field(min_length=1, max_length=100), AfterValidator(validate_slug)]
CurrencyCode = Annotated[str, AfterValidator(validate_currency_code)]

#### 使用可复用类型
class UserProfile(BaseModel):
    phone: PhoneNumber
    website_slug: Slug

class Payment(BaseModel):
    amount: float = Field(gt=0)
    currency: CurrencyCode

class Merchant(BaseModel):
    support_phone: PhoneNumber
    default_currency: CurrencyCode
    store_slug: Slug
```



## 10.7 禁止额外字段

默认下，如果 Pydantic Model 未定义某个字段，给这个模型传了额外字段，将会被悄悄忽略。这是个安全隐患，恶意客户端可以通过传额外字段来探测 API，寄希望于某次代码变更后某个字段被意外放行

```python
from pydantic import BaseModel, EmailStr, ConfigDict

class SecureUserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str

    # 拒绝任何未明确定义的字段
    model_config = ConfigDict(extra='forbid')

if __name__ == '__main__':
    user = SecureUserCreate(username="test", email="test@example.com", password="123", is_admin=True)
    print(user)  # ValidationError
```



## 10.8 嵌套模型

每一层独立校验

```python
from pydantic import BaseModel, Field, ConfigDict, model_validator

class OrderItem(BaseModel):
    product_id: int
    quantity: int = Field(gt=0, le=100)
    unit_price: float = Field(gt=0)

class ShippingAddress(BaseModel):
    street: str = Field(min_length=5)
    city: str
    postal_code: str = Field(pattern=r'^\d{5}(-\d{4})?$')
    country: str = Field(min_length=2, max_length=2)

class CreateOrder(BaseModel):
    model_config = ConfigDict(extra='forbid')

    customer_id: int
    items: list[OrderItem] = Field(min_length=1, max_length=50)
    shipping: ShippingAddress
    notes: str | None = Field(default=None, max_length=500)

    @model_validator(mode='after')
    def validate_order(self):
        total = sum(item.quantity * item.unit_price for item in self.items)
        if total > 10000:
            raise ValueError(f"订单总金额 ${total:.2f} 超过最大限额 10000")
        return self
```



## 10.9 响应模型的计算字段

将数据库中不存在的字段，在模型序列化时动态计算，作为JSON响应

```python
from datetime import datetime, timezone

from pydantic import BaseModel, ConfigDict, computed_field


class OrderItemResponse(BaseModel):
    product_id: int
    quantity: int
    unit_price: float


class OrderResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    items: list[OrderItemResponse]
    created_at: datetime
    status: str

    @computed_field
    @property
    def total(self) -> float:
        return sum(item.quantity * item.unit_price for item in self.items)

    @computed_field
    @property
    def item_count(self) -> int:
        return sum(item.quantity for item in self.items)

    @computed_field
    @property
    def age_hours(self) -> float:
        delta = datetime.now(timezone.utc) - self.created_at
        return round(delta.total_seconds() / 3600, 1)
```



## 10.10 带判别器的联合类型，处理多态数据

示例：一个通知设置接口，不同渠道的payload结构不同

```python
from typing import Literal, Annotated, Union

from fastapi import FastAPI
from pydantic import BaseModel, Field


class EmailNotification(BaseModel):
    channel: Literal["email"]
    email_address: str
    subject_prefix: str | None = None

class SlackNotification(BaseModel):
    channel: Literal["slack"]
    webhook_url: str
    mention_users: list[str] = []

class SMSNotification(BaseModel):
    channel: Literal["sms"]
    phone_number: str
    max_length: int = Field(default=160, le=500)

NotificationConfig = Annotated[
    Union[EmailNotification, SlackNotification, SMSNotification],
    Field(discriminator='channel'),
]

class UpdateNotificationSettings(BaseModel):
    user_id: int
    notifications: list[NotificationConfig]

app = FastAPI()

@app.put("/settings/notifications")
def update_notification_settings(settings: UpdateNotificationSettings):
    for notification in settings.notifications:
        match notification.channel:
            case "email":
                setup_email(notification.email_address, notification.subject_prefix)
            case "slack":
                setup_slack(notification.webhook_url, notification.mention_users)
            case "sms":
                setup_sms(notification.phone_number, notification.max_length)
    return {"updated": len(settings.notifications)}
```



## 10.11 总结

**严格模式**：`ConfigDict(strict=True)` 阻止自动类型转换，尤其适合金额、数量等敏感字段。

**模型分离**：Create、Update、Response 各建模型，配合`exclude_unset=True`实现优雅的局部更新。

**跨字段校验**：用`@model_validator`处理字段组合逻辑，`mode='before'`做预处理，`mode='after'`做关系校验。
