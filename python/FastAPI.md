# 1. Pydantic

## 1.1 严格模式

默认会自动做类型转换。数字字符串会转成数字，`"true"`变成`True`，整数`1`变成浮点`1.0`。它的设计初衷比较“宽容”。

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



## 1.2 字段约束

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



## 1.3 为创建、更新、响应分别建模型

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



## 1.4 跨字段校验

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



## 1.5 自定义错误信息

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



## 1.6 可复用字段

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



## 1.7 禁止额外字段

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



## 1.8 嵌套模型

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



## 1.9 响应模型的计算字段

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



## 1.10 带判别器的联合类型，处理多态数据

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



## 1.11 总结

**严格模式**：`ConfigDict(strict=True)` 阻止自动类型转换，尤其适合金额、数量等敏感字段。

**模型分离**：Create、Update、Response 各建模型，配合`exclude_unset=True`实现优雅的局部更新。

**跨字段校验**：用`@model_validator`处理字段组合逻辑，`mode='before'`做预处理，`mode='after'`做关系校验。
