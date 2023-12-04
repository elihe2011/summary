# 1. 问题1

etcd 无法正常启动

```bash
{"level":"warn","ts":"2021-11-18T19:37:40.897+0800","caller":"embed/config.go:814","msg":"ignoring client auto TLS since certs given"}
{"level":"info","ts":"2021-11-18T19:37:40.897+0800","caller":"embed/etcd.go:307","msg":"starting an etcd server","etcd-version":"3.5.0","git-sha":"946a5a6f2","go-version":"go1.16.3","go-os":"linux","go-arch":"amd64","max-cpu-set":2,"max-cpu-available":2,"member-initialized":true,"name":"etcd-1","data-dir":"/var/lib/etcd/default.etcd","wal-dir":"","wal-dir-dedicated":"","member-dir":"/var/lib/etcd/default.etcd/member","force-new-cluster":false,"heartbeat-interval":"100ms","election-timeout":"1s","initial-election-tick-advance":true,"snapshot-count":10000,"snapshot-catchup-entries":5000,"initial-advertise-peer-urls":["https://192.168.80.240:2380","https://localhost:2380"],"listen-peer-urls":["https://192.168.80.240:2380","https://localhost:2380"],"advertise-client-urls":["https://192.168.80.240:2379","https://localhost:2379"],"listen-client-urls":["https://192.168.80.240:2379","https://localhost:2379"],"listen-metrics-urls":[],"cors":["*"],"host-whitelist":["*"],"initial-cluster":"","initial-cluster-state":"new","initial-cluster-token":"","quota-size-bytes":2147483648,"pre-vote":true,"initial-corrupt-check":false,"corrupt-check-time-interval":"0s","auto-compaction-mode":"periodic","auto-compaction-retention":"1h0m0s","auto-compaction-interval":"1h0m0s","discovery-url":"","discovery-proxy":"","downgrade-check-interval":"5s"}
panic: freepages: failed to get all reachable pages (page 428: multiple references)

goroutine 132 [running]:
go.etcd.io/bbolt.(*DB).freepages.func2(0xc000088720)
        /home/remote/sbatsche/.gvm/pkgsets/go1.16.3/global/pkg/mod/go.etcd.io/bbolt@v1.3.6/db.go:1056 +0xe9
created by go.etcd.io/bbolt.(*DB).freepages
        /home/remote/sbatsche/.gvm/pkgsets/go1.16.3/global/pkg/mod/go.etcd.io/bbolt@v1.3.6/db.go:1054 +0x1cd
```



问题根因：系统意外关闭，导致 etcd 数据库损坏



