# 1. 系统性能

psutil是一个跨平台进程和系统监控的Python库，gopsutil是其Go语言版本的实现。适合做一些诸如采集系统信息和监控的服务

```bash
go get github.com/shirou/gopsutil/cpu
```



```go
func getCpuInfo() {
	cpuInfos, _ := cpu.Info()

	for _, ci := range cpuInfos {
		fmt.Println(ci)
	}

	// CPU 使用率
	for {
		percent, _ := cpu.Percent(time.Second, false)
		fmt.Printf("cpu percent: %v\n", percent)
	}
}

func getMemInfo() {
	memInfo, _ := mem.VirtualMemory()
	fmt.Printf("mem info: %v\n", memInfo)
}

func getHostInfo() {
	hostInfo, _ := host.Info()
	fmt.Printf("host info: %v\n", hostInfo)
}

func getDiskInfo() {
	parts, _ := disk.Partitions(true)

	for _, part := range parts {
		fmt.Printf("part: %v\n", part.String())
		diskInfo, _ := disk.Usage(part.Mountpoint)
		fmt.Printf("disk info: used=%v, free=%v\n", diskInfo.Used, diskInfo.Free)
	}

	ioStat, _ := disk.IOCounters()
	for k, v := range ioStat {
		fmt.Printf("%v: %v\n", k, v)
	}
}

func getNetInfo() {
	infos, _ := net.IOCounters(true)
	for i, v := range infos {
		fmt.Printf("%v: %v, send: %v, recv: %v\n", i, v, v.BytesSent, v.BytesRecv)
	}
}
```



# 2. 获取IP地址

```go
func getLocalIP() {
	addrs, _ := net.InterfaceAddrs()

	for _, addr := range addrs {
		ipAddr, ok := addr.(*net.IPNet)
		if !ok {
			continue
		}

		if ipAddr.IP.IsLoopback() {
			continue
		}

		if !ipAddr.IP.IsGlobalUnicast() {
			continue
		}

		fmt.Println(ipAddr.IP.String())
	}
}

func getOutboundIP() {
	conn, err := net.Dial("udp", "114.114.114.114:80")
	if err != nil {
		panic(err)
	}
	defer conn.Close()

	localAddr := conn.LocalAddr().(*net.UDPAddr)
	fmt.Println(localAddr.IP.String())
}
```



