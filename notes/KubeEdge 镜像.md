# 1. 镜像制作

```bash
git clone https://github.com/kubeedge/kubeedge.git

cd kubeedge
git checkout release-1.14

make image WHAT=cloudcore
make image WHAT=iptablesmanager
```





# 2. KS 安装代码

```bash
cat > test.yml <<EOF
edgeruntime:
  enabled: true
  kubeedge:
    enabled: true
    cloudCore:
      cloudHub:
        advertiseAddress:
          - 192.168.3.103
      service:
        cloudhubNodePort: "30000"
        cloudhubQuicNodePort: "30001"
        cloudhubHttpsNodePort: "30002"
        cloudstreamNodePort: "30003"
        tunnelNodePort: "30004"
      # resources: {}
      # hostNetWork: false
    iptables-manager:
      enabled: true
      mode: "external"
      # resources: {}
    # edgeService:
    #   resources: {}
EOF


ansible-playbook -e @test.yml playbooks/edgeruntime.yaml
```





```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  annotations:
    deprecated.daemonset.template.generation: "1"
    meta.helm.sh/release-name: cloudcore
    meta.helm.sh/release-namespace: kubeedge
  creationTimestamp: "2023-07-09T09:32:22Z"
  generation: 1
  labels:
    app.kubernetes.io/managed-by: Helm
    k8s-app: iptables-manager
    kubeedge: iptables-manager
  name: cloud-iptables-manager
  namespace: kubeedge
  resourceVersion: "4863"
  uid: e437dca3-8a90-4c5a-94ae-ecda6075aeed
spec:
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: iptables-manager
      kubeedge: iptables-manager
  template:
    metadata:
      creationTimestamp: null
      labels:
        k8s-app: iptables-manager
        kubeedge: iptables-manager
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: node-role.kubernetes.io/edge
                operator: DoesNotExist
      containers:
      - command:
        - iptables-manager
        env:
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.namespace
        image: kubeedge/iptables-manager:v1.9.2
        imagePullPolicy: IfNotPresent
        name: iptables-manager
        resources:
          limits:
            cpu: 200m
            memory: 50Mi
          requests:
            cpu: 100m
            memory: 25Mi
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
            - NET_RAW
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      hostNetwork: true
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      serviceAccount: iptables-manager-sa
      serviceAccountName: iptables-manager-sa
      terminationGracePeriodSeconds: 30
  updateStrategy:
    rollingUpdate:
      maxSurge: 0
      maxUnavailable: 1
    type: RollingUpdate
status:
  currentNumberScheduled: 2
  desiredNumberScheduled: 2
  numberAvailable: 2
  numberMisscheduled: 0
  numberReady: 2
  observedGeneration: 1
  updatedNumberScheduled: 2

```

