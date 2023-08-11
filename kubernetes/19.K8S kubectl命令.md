# 1. 创建 Pod

```bash
# kubectl run
kubectl run nginx --image=nginx --port=80

kubectl run -it busybox --rm=true --image=busybox:1.28.4 -- /bin/sh
```



# 2. 暴露端口

```bash
# kubectl expose
kubectl expose pod nginx --type=NodePort --port=8000 --target-port=80
```
Port configurations for Kubernetes Services：

- **Port**: The port **of this service**
- **TargetPort**: The target port on the pod(s) to forward traffic to
- **NodePort**: The port on the node where external traffic will come in on



# 3. 注释

```bash
# kubectl annotate
kubectl annotate pod nginx created_at='2021-10-21 17:32:19'
kubectl annotate pod nginx created_at='2021-10-22 10:21:56' --overwrite 
```



# 4. 标签

```bash
# label
kubectl label pod nginx unhealthy=true
kubectl label pod nginx unhealthy=false --overwrite 
```



# 5. 水平自动伸缩

```bash
kubectl autoscale deployment foo --min=2 --max=10
kubectl autoscale rc foo --max=5 --cpu-percent=80
```



# 6. 创建资源

```bash
# namespace
kubectl create namespace ns1

# role
kubectl create role admin --verb=get,list,watch --resource=pods,pods/status

# rolebinding
kubectl create rolebinding admin --clusterrole=admin --user=user1 --user=user2 --group=group1

# clusterrole
kubectl create clusterrole foo --verb=get,list,watch --resource=pods,pods/status

# clusterrolebinding
kubectl create clusterrolebinding foo --clusterrole=foo --user=user1 --user=user2 --group=group1

# configmap
kubectl create configmap config1 --from-literal=key1=value1 --from-literal=key2=value2

kubectl create configmap config2 --from-file=config.txt
kubectl get configmap config2 -o yaml
apiVersion: v1
data:
  config.txt: |
    a=1
    b=2
    c=3
kind: ConfigMap
metadata:
  creationTimestamp: "2021-10-21T11:24:50Z"
  name: config2
  namespace: default
  resourceVersion: "897826"
  uid: a5be5173-5315-40dc-b65a-937d83d2bc04
  
# deployment
kubectl create deployment nginx-deploy --image=nginx --replicas=5 --port=80

# quota
kubectl create quota my-quota --hard=cpu=1,memory=1G,pods=2,services=3,replicationcontrollers=2,resourcequotas=1,secrets=5,persistentvolumeclaims=10

# service
kubectl create service clusterip svc1 --tcp=5678:8080
kubectl create service clusterip svc2 --clusterip="None"
kubectl create service externalname svc3 --external-name bar.com
kubectl create service loadbalancer svc4 --tcp=5678:8080
kubectl create service nodeport svc5 --tcp=5678:8080

# serviceaccount
kubectl create serviceaccount my-service-account

# secret 
kubectl create secret tls tls-secret --cert=path/to/tls.cert --key=path/to/tls.key
kubectl create secret generic my-secret --from-file=ssh-privatekey=~/.ssh/id_rsa --from-file=ssh-publickey=~/.ssh/id_rsa.pub
kubectl create secret docker-registry my-secret --docker-server=DOCKER_REGISTRY_SERVER --docker-username=DOCKER_USER --docker-password=DOCKER_PASSWORD --docker-email=DOCKER_EMAIL
```



# 7. 更新资源字段

```bash
# kubectl patch
kubectl patch node k8s-node01 -p '{"spec":{"unschedulable":true}}'

kubectl patch pod nginx -p '{"spec":{"containers":[{"name":"nginx","image":"nginx:1.21.3"}]}}'
```



# 8. 滚动升级

```bash
# kubectl rollout
kubectl rollout history deployment/nginx-deploy

kubectl rollout pause deployment/nginx-deploy   # 暂停更新
kubectl rollout resume deployment/nginx-deploy  # 恢复更新

kubectl rollout status deployment/nginx-deploy

kubectl rollout undo deployment/nginx-deploy
```



# 9. 调整副本数

```bash
kubectl scale --replicas=10 deployment/nginx-deploy
```



# 10. 资源设置

```bash
# 设置资源限制
kubectl set resources deployment nginx-deploy --limits=cpu=200m,memory=512Mi --requests=cpu=100m,memory=256Mi


# 设置镜像
kubectl set image deployment/nginx-deploy nginx=nginx:1.21.3
```



# 11. 命令表

| Operation       | Syntax                                                       | Description                                                  |
| --------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| `alpha`         | `kubectl alpha SUBCOMMAND [flags]`                           | List the available commands that correspond to alpha features, which are not enabled in Kubernetes clusters by default. |
| `annotate`      | `kubectl annotate (-f FILENAME | TYPE NAME | TYPE/NAME) KEY_1=VAL_1 ... KEY_N=VAL_N [--overwrite] [--all] [--resource-version=version] [flags]` | Add or update the annotations of one or more resources.      |
| `api-resources` | `kubectl api-resources [flags]`                              | List the API resources that are available.                   |
| `api-versions`  | `kubectl api-versions [flags]`                               | List the API versions that are available.                    |
| `apply`         | `kubectl apply -f FILENAME [flags]`                          | Apply a configuration change to a resource from a file or stdin. |
| `attach`        | `kubectl attach POD -c CONTAINER [-i] [-t] [flags]`          | Attach to a running container either to view the output stream or interact with the container (stdin). |
| `auth`          | `kubectl auth [flags] [options]`                             | Inspect authorization.                                       |
| `autoscale`     | `kubectl autoscale (-f FILENAME | TYPE NAME | TYPE/NAME) [--min=MINPODS] --max=MAXPODS [--cpu-percent=CPU] [flags]` | Automatically scale the set of pods that are managed by a replication controller. |
| `certificate`   | `kubectl certificate SUBCOMMAND [options]`                   | Modify certificate resources.                                |
| `cluster-info`  | `kubectl cluster-info [flags]`                               | Display endpoint information about the master and services in the cluster. |
| `completion`    | `kubectl completion SHELL [options]`                         | Output shell completion code for the specified shell (bash or zsh). |
| `config`        | `kubectl config SUBCOMMAND [flags]`                          | Modifies kubeconfig files. See the individual subcommands for details. |
| `convert`       | `kubectl convert -f FILENAME [options]`                      | Convert config files between different API versions. Both YAML and JSON formats are accepted. Note - requires `kubectl-convert` plugin to be installed. |
| `cordon`        | `kubectl cordon NODE [options]`                              | Mark node as unschedulable.                                  |
| `cp`            | `kubectl cp <file-spec-src> <file-spec-dest> [options]`      | Copy files and directories to and from containers.           |
| `create`        | `kubectl create -f FILENAME [flags]`                         | Create one or more resources from a file or stdin.           |
| `delete`        | `kubectl delete (-f FILENAME | TYPE [NAME | /NAME | -l label | --all]) [flags]` | Delete resources either from a file, stdin, or specifying label selectors, names, resource selectors, or resources. |
| `describe`      | `kubectl describe (-f FILENAME | TYPE [NAME_PREFIX | /NAME | -l label]) [flags]` | Display the detailed state of one or more resources.         |
| `diff`          | `kubectl diff -f FILENAME [flags]`                           | Diff file or stdin against live configuration.               |
| `drain`         | `kubectl drain NODE [options]`                               | Drain node in preparation for maintenance.                   |
| `edit`          | `kubectl edit (-f FILENAME | TYPE NAME | TYPE/NAME) [flags]` | Edit and update the definition of one or more resources on the server by using the default editor. |
| `exec`          | `kubectl exec POD [-c CONTAINER] [-i] [-t] [flags] [-- COMMAND [args...]]` | Execute a command against a container in a pod.              |
| `explain`       | `kubectl explain [--recursive=false] [flags]`                | Get documentation of various resources. For instance pods, nodes, services, etc. |
| `expose`        | `kubectl expose (-f FILENAME | TYPE NAME | TYPE/NAME) [--port=port] [--protocol=TCP|UDP] [--target-port=number-or-name] [--name=name] [--external-ip=external-ip-of-service] [--type=type] [flags]` | Expose a replication controller, service, or pod as a new Kubernetes service. |
| `get`           | `kubectl get (-f FILENAME | TYPE [NAME | /NAME | -l label]) [--watch] [--sort-by=FIELD] [[-o | --output]=OUTPUT_FORMAT] [flags]` | List one or more resources.                                  |
| `kustomize`     | `kubectl kustomize <dir> [flags] [options]`                  | List a set of API resources generated from instructions in a kustomization.yaml file. The argument must be the path to the directory containing the file, or a git repository URL with a path suffix specifying same with respect to the repository root. |
| `label`         | `kubectl label (-f FILENAME | TYPE NAME | TYPE/NAME) KEY_1=VAL_1 ... KEY_N=VAL_N [--overwrite] [--all] [--resource-version=version] [flags]` | Add or update the labels of one or more resources.           |
| `logs`          | `kubectl logs POD [-c CONTAINER] [--follow] [flags]`         | Print the logs for a container in a pod.                     |
| `options`       | `kubectl options`                                            | List of global command-line options, which apply to all commands. |
| `patch`         | `kubectl patch (-f FILENAME | TYPE NAME | TYPE/NAME) --patch PATCH [flags]` | Update one or more fields of a resource by using the strategic merge patch process. |
| `plugin`        | `kubectl plugin [flags] [options]`                           | Provides utilities for interacting with plugins.             |
| `port-forward`  | `kubectl port-forward POD [LOCAL_PORT:]REMOTE_PORT [...[LOCAL_PORT_N:]REMOTE_PORT_N] [flags]` | Forward one or more local ports to a pod.                    |
| `proxy`         | `kubectl proxy [--port=PORT] [--www=static-dir] [--www-prefix=prefix] [--api-prefix=prefix] [flags]` | Run a proxy to the Kubernetes API server.                    |
| `replace`       | `kubectl replace -f FILENAME`                                | Replace a resource from a file or stdin.                     |
| `rollout`       | `kubectl rollout SUBCOMMAND [options]`                       | Manage the rollout of a resource. Valid resource types include: deployments, daemonsets and statefulsets. |
| `run`           | `kubectl run NAME --image=image [--env="key=value"] [--port=port] [--dry-run=server|client|none] [--overrides=inline-json] [flags]` | Run a specified image on the cluster.                        |
| `scale`         | `kubectl scale (-f FILENAME | TYPE NAME | TYPE/NAME) --replicas=COUNT [--resource-version=version] [--current-replicas=count] [flags]` | Update the size of the specified replication controller.     |
| `set`           | `kubectl set SUBCOMMAND [options]`                           | Configure application resources.                             |
| `taint`         | `kubectl taint NODE NAME KEY_1=VAL_1:TAINT_EFFECT_1 ... KEY_N=VAL_N:TAINT_EFFECT_N [options]` | Update the taints on one or more nodes.                      |
| `top`           | `kubectl top [flags] [options]`                              | Display Resource (CPU/Memory/Storage) usage.                 |
| `uncordon`      | `kubectl uncordon NODE [options]`                            | Mark node as schedulable.                                    |
| `version`       | `kubectl version [--client] [flags]`                         | Display the Kubernetes version running on the client and server. |
| `wait`          | `kubectl wait ([-f FILENAME] | resource.group/resource.name | resource.group [(-l label | --all)]) [--for=delete|--for condition=available] [options]` | Experimental: Wait for a specific condition on one or many resources. |



参考文档：https://kubernetes.io/docs/reference/kubectl/overview/#operations
