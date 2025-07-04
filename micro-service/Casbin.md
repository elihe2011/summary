# 1. 简介

## 1.1 基础概念

`casbin` 是一个强大、高效的访问控制库。支持常用的多种访问控制模式，如 `ACL/RBAC/ABAC` 等。可实现灵活的访问权限控制。

`casbin` 支持多种编程语言，例如 Golang、Java、Nodejs、Python、.NET、Rust



功能点：

- 支持自定义请求格式，默认的请求格式为 `{subject, object, action}`
- 具有访问控制模型 model 和策略 policy 两个核心概念
- 支持 RBAC 中的多层角色继承，不止主体可以有角色，资源也可以具体角色
- 支持超级用户，如 `root` 或 `admin`，超级用户可以不授权策略约束访问任意资源
- 支持多种内置的操作符，如 `keyMatch`，方便对路径式的资源进行管理，如 `/foo/bar` 可映射到 `/foo/*`



不支持：

- 身份认证 authentication (如用户名、密码等)，casbin 只负责访问控制。
- 管理用户列表或角色列表。casbin 的设计思想并不是作为一个存储密码的容器，而是存在RBAC 方案中用户和角色之间的映射关系。



## 1.2 授权模式

### 1.2.1 ACL

Access Control List，访问控制列表。定义了谁可以对某个数据继续何种操作，关键数据模型有：用户，权限

ACL 规则简单，但也带来一些问题：资源的权限需要在用户间切换的成本极大；随着用户或资源的数量增长，都会加剧规则维护成本

**典型应用**：

- 文件系统：文件(夹)定义某个账号(user)或某个群组(group)多文件(夹)的读写执行权限(RWX)
- 网络访问：防火墙，服务器限制不允许指定机器访问其指定段，或允许特定服务器访问其指定端口



### 1.2.2 RBAC

Role Based Access Control，基于角色的访问控制。核心数据模型有：用户，角色，权限。用户关联角色，角色绑定权限，从而表达用户具有权限。



### 1.2.3 ABAC

Attribute Based Access Control，基于属性的访问控制。权限和资源当时的状态(属性)有关，属性的值可以用于正向判断(符合某种条件则通过)，也可以用于反向判断(符合某种条件则拒绝)

**典型应用**：

- 论坛的评论权限，当帖子是锁定状态时，则不再允许继续评论
- Github 私有仓库不允许其他人访问
- 发帖者 可以编辑、删除评论 (如果是RBAC，会为发帖者定义一个角色，但是每个帖子都要新增一条用户/发帖角色记录)
- 微信聊天消息超过 2 分钟不能撤回
- 12306 只有实名认证后的账号才能购票
- 已过期的付费账号将不再允许使用付费功能



## 1.3 工作原理

权限实际上就是控制“**谁**”能够对“**什么资源**”进行“**什么操作**”，casbin 将访问控制模型抽象成一个基于 **PERM** (Policy, Effect, Request, Matcher) 元模型配置文件。

- Policy：策略、规则定义
- Request：访问请求对象的抽象，它与 `e.Enforce()` 方法的参数一一对应
- Matcher：匹配器，判断 Request 是否满足 Policy
- Effect：对 Matcher 所得结果进行汇总，决定 Request 是允许还是拒绝

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/golang/auth-casbin-model.png)

### 1.3.1 模型文件

访问模型文件(`model.conf`)，语法详见：https://casbin.org/zh/docs/syntax-for-models

- 至少四个部分：`[request_definition]`，`[policy_definition]`, `[policy_effect]`, `[matcher]`
- RBAC 模式下，增加 `[role_definition]`

```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
```

- **request_definition**：请求定义，即 `e.Enforce()` 方法参数的定义，`sub, obj, act` 三元组：访问实体(Subject)，访问资源(Object)和访问方法(Action)
- **policy_definition**：策略定义，每条规则通常以形如 `p` 的 `policy type ` 开头，例如 `p,tom,data1,read` 就是一条表示 tom 具有 data1 数据 read 权限的规则
- **role_definition**：RBAC 角色继承关系定义，g 是一个 RBAC 系统，`_, _` 表示角色继承关系的前项和后项，即前项继承后项角色的权限
- **policy_effect**：策略生效范围定义，对request的决策结果进行统一的决策。例如 `e = some(where (p.eft == allow))` 表示如果存在任意一个决策结果为 `allow` 的匹配规则，则最终决策结果为 allow。`p.eft` 表示策略规则的决策结果，可以 allow 或 deny，当不指定规则的决策结果时，取默认值 allow
- **matchers**：策略匹配者定义。匹配者是一组表达式，它定义了如何根据请求来匹配策略规则

 

### 1.3.2 策略文件

访问控制关于角色、资源、行为的具体映射关系

```csv
p, tom, data1, read
p, sarah, data2, write
```



# 2. 使用

## 2.1 ACL

###  2.1.1 模型文件

```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act

[policy_effect]
e = some(where (p.eft == allow))
```



### 2.1.2 策略文件

```csv
p, tom, data, read
p, tom, data, write
p, sarah, data, read
```

有一条 `p(策略)`，定义了 `tom(sub), data(obj), read(act)`，语义化就是 `tom` 可以对 `data1` 执行 `read` 方法



### 2.1.3 验证程序

```go
func verify(e *casbin.Enforcer, sub, obj, act string) {
	ok, _ := e.Enforce(sub, obj, act)
	if ok {
		log.Printf("[%s] CAN [%s %s]", sub, act, obj)
	} else {
		log.Printf("[%s] CANNOT [%s %s]", sub, act, obj)
	}
}

func main() {
	e, err := casbin.NewEnforcer("./model.conf", "./policy.csv")
	if err != nil {
		log.Fatalln(err)
	}

	verify(e, "tom", "data", "read")
	verify(e, "tom", "data", "write")
	verify(e, "sarah", "data", "read")
	verify(e, "sarah", "data", "write")
}
```



## 2.2 RBAC

### 2.2.1 单 RBAC

#### 2.2.1.1 模型文件

```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _

[matchers]
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act

[policy_effect]
e = some(where (p.eft == allow))
```

 `g = _,_` 定义了用户角色映射关系，前者是后者的成员，拥有后者的权限。在匹配器中，不需要判断`r.sub`与`p.sub`完全相等，只需要使用`g(r.sub, p.sub)`来判断请求主体`r.sub`是否属于`p.sub`这个角色即可



#### 2.2.1.2 策略文件

```csv
p, admin, data, read
p, admin, data, write
p, developer, data, read
g, tom, admin
g, sarah, developer
```



#### 2.2.1.3 验证程序

```go
func main() {
	e, err := casbin.NewEnforcer("./model.conf", "./policy.csv")
	if err != nil {
		log.Fatalln(err)
	}	

    verify(e, "tom", "data", "read")
	verify(e, "tom", "data", "write")
	verify(e, "sarah", "data", "read")
	verify(e, "sarah", "data", "write")
}
```



### 2.2.2 多个 RBAC

#### 2.2.2.1 模型文件

```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _
g2 = _, _

[matchers]
m = g(r.sub, p.sub) && g2(r.obj, p.obj) && r.act == p.act

[policy_effect]
e = some(where (p.eft == allow))
```

定义了两个`RBAC`系统`g`和`g2`，我们在匹配器中使用`g(r.sub, p.sub)`判断请求主体属于特定组，`g2(r.obj, p.obj)`判断请求资源属于特定组，且操作一致即可放行。



#### 2.2.2.2 策略文件

```
p, admin, prod, read
p, admin, prod, write
p, admin, dev, read
p, admin, dev, write
p, developer, dev, read
p, developer, dev, write
p, developer, prod, read
g, tom, admin
g, sarah, developer
g2, prod.data, prod
g2, dev.data, dev
```



#### 2.2.2.3 验证程序 

```go
func main() {
	e, err := casbin.NewEnforcer("./model.conf", "./policy.csv")
	if err != nil {
		log.Fatalln(err)
	}

	verify(e, "tom", "prod.data", "read")
	verify(e, "tom", "prod.data", "write")
	verify(e, "tom", "dev.data", "read")
	verify(e, "tom", "dev.data", "write")
	verify(e, "sarah", "prod.data", "read")
	verify(e, "sarah", "prod.data", "write")
	verify(e, "sarah", "dev.data", "read")
	verify(e, "sarah", "dev.data", "write")
}
```



### 2.2.3 多层角色

#### 2.2.3.1 模型文件

```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _

[matchers]
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act

[policy_effect]
e = some(where (p.eft == allow))
```



#### 2.2.3.2 策略文件

```
p, senior, data, write
p, developer, data, read
g, tom, senior
g, senior, developer
g, sarah, developer
```



#### 2.2.3.3 验证程序 

```go
func main() {
	e, err := casbin.NewEnforcer("./model.conf", "./policy.csv")
	if err != nil {
		log.Fatalln(err)
	}

	verify(e, "tom", "data", "read")     // ok
	verify(e, "tom", "data", "write")    // ok
	verify(e, "sarah", "data", "read")   // ok
	verify(e, "sarah", "data", "write")  // not
}
```



### 2.2.4 域 (domain)

在`casbin`中，角色可以是全局的，也可以是特定`domain`（领域）或`tenant`（租户），可以简单理解为**组**

#### 2.2.4.1 模型文件

```ini
[request_definition]
r = sub, dom, obj, act

[policy_definition]
p = sub, dom, obj, act

[role_definition]
g = _,_,_

[matchers]
m = g(r.sub, p.sub, r.dom) && r.dom == p.dom && r.obj == p.obj && r.act == p.act

[policy_effect]
e = some(where (p.eft == allow))
```



#### 2.2.4.2 策略文件

```csv
p, admin, tenant1, data1, read
p, admin, tenant2, data2, read
g, tom, admin, tenant1
g, tom, developer, tenant2
```



#### 2.2.4.3 验证程序 

```go
func verify(e *casbin.Enforcer, sub, dom, obj, act string) {
	ok, _ := e.Enforce(sub, dom, obj, act)
	if ok {
		log.Printf("[%s] CAN [%s %s] in [%s]", sub, act, obj, dom)
	} else {
		log.Printf("[%s] CANNOT [%s %s] in [%s]", sub, act, obj, dom)
	}
}

func main() {
	e, err := casbin.NewEnforcer("./model.conf", "./policy.csv")
	if err != nil {
		log.Fatalln(err)
	}

	verify(e, "tom", "tenant1", "data1", "read") // ok
	verify(e, "tom", "tenant2", "data2", "read") // not
}
```



## 2.3 ABAC

`RBAC`模型对于实现比较规则的、相对静态的权限管理非常有用。但是对于特殊的、动态的需求，`RBAC`就显得有点力不从心了。例如，在不同的时间段对数据`data`实现不同的权限控制。正常工作时间`9:00-18:00`所有人都可以读写`data`，其他时间只有数据所有者能读写。这种需求可以很方便地使用`ABAC`（attribute base access list）模型完成



### 2.3.1 模型文件

```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[matchers]
m = r.sub.Hour >= 9 && r.sub.Hour < 18 || r.sub.Name == r.obj.Owner

[policy_effect]
e = some(where (p.eft == allow))
```



### 2.3.2 策略文件

无需策略文件



### 2.3.3 验证程序 

```go
type Object struct {
	Name  string
	Owner string
}

type Subject struct {
	Name string
	Hour int
}

func verify(e *casbin.Enforcer, sub Subject, obj Object, act string) {
	ok, _ := e.Enforce(sub, obj, act)
	if ok {
		log.Printf("[%s] CAN [%s %s] at [%d:00]", sub.Name, act, obj.Name, sub.Hour)
	} else {
		log.Printf("[%s] CANNOT [%s %s] at [%d:00]", sub.Name, act, obj.Name, sub.Hour)
	}
}

func main() {
	e, err := casbin.NewEnforcer("./model.conf")
	if err != nil {
		log.Fatalln(err)
	}

	obj := Object{"data", "tom"}

	s1 := Subject{"tom", 10}
	s2 := Subject{"sarah", 10}
	s3 := Subject{"tom", 20}
	s4 := Subject{"sarah", 20}

	verify(e, s1, obj, "read") // ok
	verify(e, s2, obj, "read") // ok
	verify(e, s3, obj, "read") // ok
	verify(e, s4, obj, "read") // not
}
```



# 3. 策略存储

## 3.1 数据库

采用数据库存储，也可换成 redis, etcd 等

```sql
CREATE TABLE `sys_casbin_rule` (
  `p_type` varchar(100) DEFAULT NULL COMMENT '规则类型',
  `v0` varchar(100) DEFAULT NULL COMMENT '角色ID',
  `v1` varchar(100) DEFAULT NULL COMMENT 'URI',
  `v2` varchar(100) DEFAULT NULL COMMENT 'Method',
  `v3` varchar(100) DEFAULT NULL,
  `v4` varchar(100) DEFAULT NULL,
  `v5` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='权限规则表';

-- 默认开启
INSERT INTO `sys_casbin_rule`(`p_type`, `v0`, `v1`, `v2`) VALUES ('p', '0', '/api/v1/captcha', 'GET');
```



## 3.2 程序

### 3.2.1 初始化

采用 gorm 做为策略适配器(策略存储)，采用 redis 做为策略监视器

```go
func setupCasbin() (*casbin.Enforcer, error) {
	adapter, err := gormadapter.NewAdapter("mysql", "root:123456@tcp(192.168.3.102:3306)/iamdb",
		"iamdb", "sys_casbin_rule", true)
	if err != nil {
		return nil, err
	}

	m, err := model.NewModelFromFile("./model.conf")
	if err != nil {
		return nil, err
	}

	enforcer, err := casbin.NewEnforcer(m, adapter)
	if err != nil {
		return nil, err
	}

	err = enforcer.LoadPolicy()
	if err != nil {
		return nil, err
	}

	return enforcer, nil
}

func setupRedisWatcher(f func(s string)) (persist.Watcher, error) {
	w, err := rediswatcher.NewWatcher("192.168.3.102:6379", rediswatcher.WatcherOptions{
		Options: redis.Options{
			Network:  "tcp",
			Password: "",
		},
		Channel:    "/casbin",
		IgnoreSelf: false,
	})
	if err != nil {
		return nil, err
	}

	err = w.SetUpdateCallback(f)
	if err != nil {
		return nil, err
	}

	return w, nil
}

func NewCasbinWithWatcher() (*casbin.Enforcer, error) {
	enforcer, err := setupCasbin()
	if err != nil {
		return nil, err
	}

	watcher, err := setupRedisWatcher(func(s string) {
		rediswatcher.DefaultUpdateCallback(enforcer)(s)
	})

	err = enforcer.SetWatcher(watcher)
	if err != nil {
		return nil, err
	}

	err = enforcer.SavePolicy()
	if err != nil {
		return nil, err
	}

	return enforcer, nil
}
```



### 3.2.2 验证

```go
func verify(e *casbin.Enforcer, sub, obj, act string) {
	ok, _ := e.Enforce(sub, obj, act)
	if ok {
		log.Printf("[Role: %s] CAN [Method: %s, Url: %s]", sub, act, obj)
	} else {
		log.Printf("[Role: %s] CANNOT [Method: %s, Url: %s]", sub, act, obj)
	}
}

func main() {
	e, err := NewCasbinWithWatcher()
	if err != nil {
		log.Fatal(err)
	}

	// 验证默认权限：角色Id为0
	verify(e, "0", "/api/v1/captcha", "GET")
	verify(e, "0", "/api/v1/captcha", "POST")

	// 新增规则
	ok, err := e.AddPolicy("0", "/api/v1/login", "POST")
	if err != nil {
		log.Fatalf("policy does not add: %v", err)
	} else if ok {
		log.Printf("policy is added")
	} else {
		log.Printf("policy has been added")
	}
	verify(e, "0", "/api/v1/login", "POST")
	verify(e, "1", "/api/v1/login", "POST")

	// 删除规则
	ok, err = e.RemovePolicy("0", "/api/v1/login", "POST")
	if err != nil {
		log.Fatalf("policy does not remove: %v", err)
	} else if ok {
		log.Printf("policy is removed")
	} else {
		log.Printf("policy has been removed")
	}
	verify(e, "0", "/api/v1/login", "POST")
	verify(e, "1", "/api/v1/login", "POST")
}
```



### 3.2.4 删除权限

```go
if ok := enforcer.RemovePolicy(roleName, url, method); !ok {
  	log.Fatal("删除权限失败")
} else {
  	log.Fatal("删除权限成功")
}
```



## 3.3 模糊匹配

参见：https://casbin.org/zh/docs/function

模型文件：

```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[matchers]
m = r.sub == p.sub && keyMatch2(r.obj, p.obj) && regexMatch(r.act, p.act)

[policy_effect]
e = some(where (p.eft == allow))
```

验证程序：

```go
func main() {
	e, err := NewCasbinWithWatcher()
	if err != nil {
		log.Fatal(err)
	}

	// 新增规则
	_, _ = e.AddPolicy("0", "/api/v1/users/:id", "GET")
	_, _ = e.AddPolicy("0", "/api/v1/menus/:id/ops/:res", "PUT")

	// 验证规则
	verify(e, "0", "/api/v1/users/5", "GET")
	verify(e, "0", "/api/v1/menus/3/ops/add", "PUT")

	// 删除规则
	_, _ = e.RemovePolicy("0", "/api/v1/users/:id", "GET")
	_, _ = e.RemovePolicy("0", "/api/v1/menus/:id/ops/:res", "PUT")

	// 验证规则
	verify(e, "0", "/api/v1/users/5", "GET")
	verify(e, "0", "/api/v1/menus/3/ops/add", "PUT")
}

```



# 4. 中间件

```go
func(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
        obj := r.URL.Path
		act := r.Method

		var reqs [][]any
		for _, v := range payload.RoleKeys {
			reqs = append(reqs, []any{v, obj, act})
		}

		// 查询
		result, err := m.cbn.BatchEnforce(reqs)
		if err != nil {
			logx.Errorw("casbin enforce failed", logx.Field("error", err.Error()))
			return except.ErrInsufficientPermission()
		}

		for _, v := range result {
			if v {
				logx.Infow("HTTP/HTTPS Request", logx.Field("path", obj), logx.Field("method", act))
				return nil
			}
		}

		logx.Errorw("not permitted to access the API", logx.Field("rolekeys", payload.RoleKeys),
			logx.Field("path", obj), logx.Field("method", act))
		return except.ErrInsufficientPermission()
}
```

