# 1. 管理虚拟机

```bash
# 虚拟机列表
virsh list
virsh list --all  # 包含已停止

# 虚拟机信息
virsh dominfo vm1

# 内存和CPU使用情况
yum install virt-top -y
virt-top

# 分区信息
virt-df vm1

# 停止
virsh shutdown vm1

# 启动
virsh start vm1

# 开机自启
virsh autostart vm1
virsh autostart --disable vm1

# 控制台登录, 退出：Ctrl+[
virsh console vm1
```



# 2. 添加磁盘

```bash
# USB 或磁盘
virsh attach-disk vm1 /dev/sdc vbc --driver qemu --mode shareable
virsh detach-disk vm1 vdc

# LVM
lvcreate -n lv_vm1_data -L 50G vg_vm1
virsh attach-disk vm1 /dev/vg_vm1/lv_vm1_data vdc --driver qemu --mode shareable
```



# 3. 参数配置

```bash
$ virsh shutdown vm1

$ virsh edit vm1
...
<memory unit='KiB'>4194304</memory>
  <currentMemory unit='KiB'>4194304</currentMemory>
  <vcpu placement='static'>2</vcpu>
  <os>
    <type arch='aarch64' machine='virt-3.1'>hvm</type>
    <loader readonly='yes' type='pflash'>/usr/share/AAVMF/AAVMF_CODE.fd</loader>
    <nvram>/var/lib/libvirt/qemu/nvram/ubuntu18.04-liulei-3.176_VARS.fd</nvram>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <gic version='3'/>
  </features>
  <cpu mode='host-passthrough' check='none'>
    <topology sockets='1' cores='2' threads='1'/>
  </cpu>
...

$ virsh start vm1
```



# 4. 删除虚拟机

```bash
virsh shutdown vm1

virsh destroy vm1

virsh undefine vm1
virsh undefine --nvram vm1

rm -f /dev/vg_vm1/lv_vm1_data
```



# 5. 克隆虚拟机

```bash
virt-clone --auto-clone -o vm1 -n vm-new 
```



# 6. 其他操作

```bash
# 挂起和恢复     
virsh suspend vm1
virsh resume vm1

# 网卡信息        
virsh domiflist vm1 

# 磁盘信息      
virsh domblklist vm1

# 配置信息（全部）   
virsh dumpxml vm1 
```

