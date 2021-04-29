# 1. 概述

Rancher 是容器管理平台。它通过支持集群身份验证和基于角色的访问控制（RBAC），使系统管理员能够从一个位置控制全部集群的访问。



相关概念：

- Rancher Server: 管理和配置 kubernetes 集群。通过 Rancher Server 的 UI和下游 Kubernetes 集群进行交互
- RKE (Rancher Kubernetes Engine): 提供 CLI 工具用于创建和管理 Kubernetes 集群。在 Rancher UI 中创建集群时，它将调用 RKE 来配置 Rancher 启动的 Kubernetes 集群
- k3s: 轻量级 Kubernetes，它比 RKE 更新，更易用且更轻量化。
- RKE2： 专注于安全性和合规性
- RancherD：安装 Rancher 的新工具，它首先启动一个 RKE2 Kubernetes 集群，然后在集群上安装 Rancher 服务器 Helm 图

