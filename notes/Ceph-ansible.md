



```sh
wget https://github.com/ceph/ceph-ansible/archive/refs/tags/v6.0.28.tar.gz

tar zxvf v6.0.28.tar.gz
cd ceph-ansible-6.0.28/


pip install netaddr
pip install ansible>=2.10,<2.11,!=2.9.10
pip install ansible-base<2.11,>=2.10.5

ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.3.103 
ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.3.104  
ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.3.105 
ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.3.106 
```





Ceph系统有几大组件，OSD\Monitor\MDS\Managers

Ceph OSD:

Ceph的OSD（Object Storage Device）守护进程。主要功能包括：存储数据、副本数据处理、数据恢复、数据回补、平衡数据分布，并将数据相关的一些监控信息提供给Ceph Moniter,以便Ceph Moniter来检查其他OSD的心跳状态。一个Ceph OSD存储集群，要求至少两个Ceph OSD,才能有效的保存两份数据。注意，这里的两个Ceph OSD是指运行在两台物理服务器上，并不是在一台物理服务器上运行两个Ceph OSD的守护进程。通常，冗余和高可用性至少需要3个Ceph OSD。

Monitor:

Ceph的Monitor守护进程，主要功能是维护集群状态的表组，这个表组中包含了多张表，其中有Moniter map、OSD map、PG(Placement Group) map、CRUSH map。 这些映射是Ceph守护进程之间相互协调的关键簇状态。 监视器还负责管理守护进程和客户端之间的身份验证。 通常需要至少三个监视器来实现冗余和高可用性。

MDS：

Ceph的MDS（Metadata Server）守护进程，主要保存的是Ceph文件系统的元数据。注意，对于Ceph的块设备和Ceph对象存储都不需要Ceph MDS守护进程。Ceph MDS为基于POSIX文件系统的用户提供了一些基础命令的执行，比如ls、find等，这样可以很大程度降低Ceph存储集群的压力。

Managers：

Ceph的Managers（Ceph Manager），守护进程（ceph-mgr）负责跟踪运行时间指标和Ceph群集的当前状态，包括存储利用率，当前性能指标和系统负载。 Ceph Manager守护程序还托管基于python的插件来管理和公开Ceph集群信息，包括基于Web的仪表板和REST API。 通常，至少有两名Manager需要高可用性。





OSDs: Ceph的OSD守护进程（OSD）存储数据，处理数据复制，恢复，回填，重新调整，并通过检查其它Ceph OSD守护程序作为一个心跳 向Ceph的监视器报告一些检测信息。Ceph的存储集群需要至少2个OSD守护进程来保持一个 active + clean状态.（Ceph默认制作2个备份，但你可以调整它）

Monitors:Ceph的监控保持集群状态映射，包括OSD(守护进程)映射,分组(PG)映射，和CRUSH映射。 Ceph 保持一个在Ceph监视器, Ceph OSD 守护进程和 PG的每个状态改变的历史（称之为“epoch”）.

MDS: MDS是Ceph的元数据服务器，代表存储元数据的Ceph文件系统（即Ceph的块设备和Ceph的对象存储不使用MDS）。Ceph的元数据服务器使用POSIX文件系统，用户可以执行基本命令如 ls, find,等，并且不需要在Ceph的存储集群上造成巨大的负载.

Ceph把客户端的数据以对象的形式存储到了存储池里。利用CRUSH算法，Ceph可以计算出安置组所包含的对象，并能进一步计算出Ceph OSD集合所存储的安置组。CRUSH算法能够使Ceph存储集群拥有动态改变大小、再平衡和数据恢复的能力。





```bash
cat > hosts <<EOF
[mons]
192.168.3.103
192.168.3.104
192.168.3.105
192.168.3.106

[osds]
192.168.3.103
192.168.3.104
192.168.3.105
192.168.3.106

[rgws]
192.168.3.103
192.168.3.104
192.168.3.105
192.168.3.106

[clients]
192.168.3.103
192.168.3.104
192.168.3.105
192.168.3.106

[mgrs]
192.168.3.103
192.168.3.105
EOF

cat > group_vars/all.yml <<EOF
---
cluster: ceph
configure_firewall: False
ceph_origin: repository
ceph_repository: community
ceph_mirror: http://mirrors.aliyun.com/ceph
ceph_stable_key: http://mirrors.aliyun.com/ceph/keys/release.asc
ceph_stable_release: pacific
ceph_stable_repo: "{{ ceph_mirror }}/debian-{{ ceph_stable_release }}"
public_network: "192.168.3.0/24"
cluster_network: "192.168.3.0/24"
monitor_interface: enp1s0
osd_auto_discovery: true
osd_objectstore: bluestore
radosgw_interface: enp1s0
pg_autoscale_mode: True
copy_admin_key: true
devices:
  - '/dev/vdb'
osd_scenario: collocated
dashboard_enabled: True
dashboard_admin_user: admin
dashboard_admin_password: Admin@123
grafana_admin_password: Admin@123
ceph_conf_overrides:
    global:
        mon_allow_pool_delete: true
        mon_osd_allow_primary_affinity: 1
        mon_clock_drift_allowed: 0.5
        osd_pool_default_size: 3
        osd_pool_default_min_size: 1
        mon_pg_warn_min_per_osd: 0
        mon_pg_warn_max_per_osd: 0
        mon_pg_warn_max_object_skew: 0
    client:
        rbd_default_features: 1
    mon:
        mon_allow_pool_delete: true 
EOF


cp site.yml.sample site.yml
vi site.yml
- hosts:
  - mons
  - osds
    #- mdss
  - rgws
    #- nfss
    #- rbdmirrors
  - clients
  - mgrs
    #- iscsigws
    #- monitoring
    #- rgwloadbalancers
...



ansible-playbook -i hosts site.yml 

ansible-galaxy collection install ansible.utils


缩小osd

$ ansible-playbook -vv -i hosts infrastructure-playbooks/shrink-osds.yml -e osd_to_kill=1,2,3
1


ansible-playbook -vv infrastructure-playbooks/purge-container-cluster.yml

```















\1.  FileStore是SSD-based ceph system的最优存储后端。

\2.  在时延敏感场景，尤其是HDD-based ceph system，BlueStore更为合适。







对于 RBD，如果您选择跟踪长期内核，我们目前推荐基于 4.x 的“长期维护”内核系列或更高版本：

- 4.19.z
- 4.14.z
- 5.x



将内核升级到 4.19

```bash
$ uname -r
4.15.0-153-generic

wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19.286/amd64/linux-headers-4.19.286-0419286-generic_4.19.286-0419286.202306140936_amd64.deb
wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19.286/amd64/linux-headers-4.19.286-0419286_4.19.286-0419286.202306140936_all.deb
wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19.286/amd64/linux-image-unsigned-4.19.286-0419286-generic_4.19.286-0419286.202306140936_amd64.deb
wget https://kernel.ubuntu.com/~kernel-ppa/mainline/v4.19.286/amd64/linux-modules-4.19.286-0419286-generic_4.19.286-0419286.202306140936_amd64.deb

dpkg -i *.deb
```





卸载操作：

```bash
systemctl stop ceph-mon.target
systemctl stop ceph-mgr.target
systemctl stop ceph-crash.service

dpkg -l | grep ceph- | grep -v python | awk '{print $2}' | xargs apt remove -y


ps aux | grep ceph | grep -v grep | awk '{print $2}'| xargs kill -9
ps -ef | grep ceph

umount /var/lib/ceph/osd
rm -rf /var/lib/ceph
rm -rf /var/run/ceph
rm -rf /etc/ceph




```





三、ceph 更换controller3 服务器，ceph需要处理的地方
　　1、删除ceph-mon

```
ceph mon remove mon3
```


　　2、移除osd
```bash
ceph osd rm osd.6
ceph osd rm osd.7
ceph osd rm osd.8
ceph osd crush rm osd.6
ceph osd crush rm osd.7
ceph osd crush rm osd.8
ceph auth del osd.6
ceph auth del osd.7
ceph auth del osd.8
```

