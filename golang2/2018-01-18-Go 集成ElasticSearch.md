---
layout: post
title:  Go 集成ElasticSearch
date:   2018-01-18 12:20:00
comments: true
photos: 
tags: 
  - elasticsearch
categories: Golang
---

# 1. 简介

- 全文搜索引擎
- 快速存储、搜索和分析海量数据
- 存储json格式文档

## 1.1 ElasticSearch数据库
- `<server>:9200/index/type/id`
- `index -> database`
- `type -> table`
- `<server>:9200/index/type/_search?q=` 全文搜索

## 1.2 安装elastic client:

```bash
go get gopkg.in/olivere/elastic.v5
```

# 2. 安装ElasticSearch服务器

# 2.1 使用Docker方式安装

```bash
docker login daocloud.io

docker pull daocloud.io/library/elasticsearch:7.3.2

docker run -d -p 9200:9200 daocloud.io/library/elasticsearch
```

