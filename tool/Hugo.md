# 1. 快速入门

## 1.1 准备操作

```powershell
# Windows
$Env:CGO_ENABLED=1
go install -tags extended github.com/gohugoio/hugo@latest

# Linux/macOS
CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest

# 版本
hugo version

# 帮助
hugo help
hugo server --help
```



## 1.2 基本用法

### 1.2.1 创建网站

```bash
hugo new site quickstart
cd quickstart

git init
git submodule add https://github.com/theNewDynamic/gohugo-theme-ananke.git themes/ananke
echo "theme = 'ananke'" >> hugo.toml


git submodule add https://github.com/razonyang/hugo-theme-bootstrap themes/hugo-theme-bootstrap
sed -i "s/theme:.*/theme: hugo-theme-bootstrap/g" config/_default/config.yaml


hugo server
```



### 1.2.2 添加内容

```bash
hugo new content/posts/my-first-post.md

# 编辑my-first-post.md
cat > my-first-post.md <<EOF
+++
date = '2025-03-19T10:18:52+08:00'
draft = true
title = 'My First Post'
+++

## 简介 
这是 **粗体** 文本，
这是 *斜体* 文本。 访问 [Hugo](https://gohugo.io) 网站！
EOF

# 启动服务
hugo server --buildDrafts
hugo server -D
```



### 1.2.3 配置站点

```bash
# 站点配置
vi hugo.toml
baseURL = 'https://myblog.cn/'
languageCode = 'zh-cn'
title = '我的站点'
theme = 'ananke'
```



### 1.2.4 构建站点

```bash
hugo
```

`hugo` 命令会构建站点，并将文件发布到 public 目录中。要将站点发布到其它目录，需要使用 `--destination` 标志或在站点配置中设置 `publishDir`.

Hugo 在构建站点前不会清空 `public` 目录。现有文件会被覆盖，但不会被删除。



### 1.2.5 草稿、未来和过期内容

内容的前置元数据如果设置了以下情况，不会发布内容：

- `draft`：true
- `date`：在未来
- `publishDate`：在未来
- `expiryDate`：在过去

覆盖默认行为：

```bash
hugo --buildDrafts    # 或 -D
hugo --buildExpired   # 或 -E
hugo --buildFuture    # 或 -F
```



### 1.2.6 开发和测试站点

```bash
# 启动测试服务
hugo server
```



### 1.2.7 部署站点

```bash
# 构建站点
hugo
```

构建站点，并将文件发布到 public 目录：

```
public/
├── categories/
│   ├── index.html
│   └── index.xml  <-- 此类别的RSS订阅
├── post/
│   ├── my-first-post/
│   │   └── index.html
│   ├── index.html
│   └── index.xml  <-- 此部分的RSS订阅
├── tags/
│   ├── index.html
│   └── index.xml  <-- 此部分的RSS订阅
├── index.html
├── index.xml      <-- 站点的RSS订阅
└── sitemap.xml
```



## 1.3 目录结构

### 1.3.1 站点骨架

创建新站点：

```bash
hugo new site my-site
```

目录结构：

```bash
my-site/
├── archetypes
│   └── default.md
├── assets
├── content
├── data
├── hugo.toml    <-- 站点配置
├── i18n
├── layouts
├── static
└── themes
```

支持将站点配置组织到子目录中：

```bash
my-site/
├── archetypes
│   └── default.md
├── assets
├── config     <-- 站点配置
│   └── _default
│       └── hugo.toml
├── content
├── data
├── i18n
├── layouts
├── static
└── themes
```



使用 `hugo` 命令构建站点后，会创建 `public` 和 `resources` 目录：

```bash 
my-site/
├── archetypes
│   └── default.md
├── assets
├── config
│   └── _default
│       └── hugo.toml
├── content
├── data
├── i18n
├── layouts
├── public            <-- 构建站点时创建
│   ├── categories
│   │   └── index.xml
│   ├── index.xml
│   ├── sitemap.xml
│   └── tags
│       └── index.xml
├── static
└── themes
```



### 1.3.2 联合文件系统

Hugo 允许将两个以上目录挂载到同一个位置，如下目录结构：

```bash
home/
└── user/
    ├── my-site/            
    │   ├── content/
    │   │   ├── books/
    │   │   │   ├── _index.md
    │   │   │   ├── book-1.md
    │   │   │   └── book-2.md
    │   │   └── _index.md
    │   ├── themes/
    │   │   └── my-theme/
    │   └── hugo.toml
    └── shared-content/     
        └── films/
            ├── _index.md
            ├── film-1.md
            └── film-2.md
```

可以使用挂载 (mounts) 在构建站点时包含共享内容，在站点配置 `hugo.toml` 中添加：

```toml
[module]
[[module.mounts]]
    source = 'content'
    target = 'content'
[[module.mounts]]
    source = '/home/user/shared-content'
    target = 'content'
```

挂载后，联合文件系统结构如下：

```bash
home/
└── user/
    └── my-site/
        ├── content/
        │   ├── books/
        │   │   ├── _index.md
        │   │   ├── book-1.md
        │   │   └── book-2.md
        │   ├── films/
        │   │   ├── _index.md
        │   │   ├── film-1.md
        │   │   └── film-2.md
        │   └── _index.md
        ├── themes/
        │   └── my-theme/
        └── hugo.toml
```



### 1.3.3 主题骨架

创建新主题：

```bash
hugo new theme my-theme
```

目录结构：

```bash
themes/my-theme/
├── LICENSE
├── README.md
├── archetypes
│   └── default.md
├── assets
│   ├── css
│   │   └── main.css
│   └── js
│       └── main.js
├── content
│   ├── _index.md
│   └── posts
│       ├── _index.md
│       ├── post-1.md
│       ├── post-2.md
│       └── post-3
│           ├── bryce-canyon.jpg
│           └── index.md
├── data
├── hugo.toml
├── i18n
├── layouts
│   ├── _default
│   │   ├── baseof.html
│   │   ├── home.html
│   │   ├── list.html
│   │   └── single.html
│   └── partials
│       ├── footer.html
│       ├── head
│       │   ├── css.html
│       │   └── js.html
│       ├── head.html
│       ├── header.html
│       ├── menu.html
│       └── terms.html
├── static
│   └── favicon.ico
└── theme.toml
```



































