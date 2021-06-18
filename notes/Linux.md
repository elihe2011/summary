# 1. Ubuntu

## 1.1 修改IP

Ubuntu 16, 18:

```bash
sudo vi /etc/network/interfaces
auto ens33
iface ens33 inet static
address 192.168.80.20
netmask 255.255.255.0
gateway 192.168.80.2
dns-nameservers 8.8.8.8

sudo ip addr flush ens33
sudo systemctl restart networking
```



Ubuntu 20:

```bash
sudo vi /etc/netplan/00-installer-config.yaml
network:
  ethernets:
    ens33:
      addresses:
      - 192.168.80.121/24
      gateway4: 192.168.80.2
      nameservers:
        addresses:
        - 8.8.8.8
        search:
        - 8.8.8.8
  version: 2

sudo netplan apply
```



## 1.2 防火墙

```bash
sudo ufw status
suod ufw enable/disable

sudo ufw allow/deny 22/tcp

sudo ufw allow from 192.168.80.1
sudo ufw delete allow from 192.168.80.1
```



## 1.3 sshd

```bash
sudo apt-get update

sudo apt-get install openssh-server

sudo ps -ef | grep ssh
```



## 1.4 Docker

```bash
# 可能缺少的公共命令
sudo apt-get install software-properties-common -y

# 证书
sudo curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -

# 仓库信息
sudo add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"

# 更新 cache
sudo apt-get update

# 可用版本查询
sudo apt-cache policy docker-ce

# 安装 docker 19.03.15~3-0~ubuntu-xenial
sudo apt-get install docker-ce=5:19.03.15~3-0~ubuntu-xenial -y

sudo docker version

# 不需要 sudo， 重新登录
sudo usermod -aG docker $USER
sudo systemctl restart docker
```



## 1.5 Python 多版本

```bash
# 增加 deadsnakes PPA 源
sudo add-apt-repository ppa:deadsnakes/ppa

# 安装 python 3.9
sudo apt-get update
sudo apt-get install python3.9

# python 默认版本切换成 3.9
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1

sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.8 2

sudo update-alternatives --config python3
There are 2 choices for the alternative python3 (providing /usr/bin/python3).

  Selection    Path                Priority   Status
------------------------------------------------------------
* 0            /usr/bin/python3.8   2         auto mode
  1            /usr/bin/python3.8   2         manual mode
  2            /usr/bin/python3.9   1         manual mode

Press <enter> to keep the current choice[*], or type selection number: 2

sudo apt install python3-pip python3.9-venv

python3 -m venv /home/ubuntu/python/venv
```



## 1.6 防火墙

```bash
sudo ufw allow ssh

sudo ufw allow 6379/tcp
```



## 1.7 阿里源

ubuntu16:

```bash
sudo -i

echo "nameserver 8.8.8.8" >> /etc/resolv.conf

mv /etc/apt/sources.list /etc/apt/sources.list.bak

cat > /etc/apt/sources.list <<EOF
# deb cdrom:[Ubuntu 16.04 LTS _Xenial Xerus_ - Release amd64 (20160420.1)]/ xenial main restricted
deb-src http://archive.ubuntu.com/ubuntu xenial main restricted #Added by software-properties
deb http://mirrors.aliyun.com/ubuntu/ xenial main restricted
deb-src http://mirrors.aliyun.com/ubuntu/ xenial main restricted multiverse universe #Added by software-properties
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted multiverse universe #Added by software-properties
deb http://mirrors.aliyun.com/ubuntu/ xenial universe
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates universe
deb http://mirrors.aliyun.com/ubuntu/ xenial multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse #Added by software-properties
deb http://archive.canonical.com/ubuntu xenial partner
deb-src http://archive.canonical.com/ubuntu xenial partner
deb http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted multiverse universe #Added by software-properties
deb http://mirrors.aliyun.com/ubuntu/ xenial-security universe
deb http://mirrors.aliyun.com/ubuntu/ xenial-security multiverse
EOF

apt-get update
```



## 1.8 时区

```bash
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# alternative
timedatectl set-timezone "Asia/Shanghai"
timedatectl status
```



## 1.9 k8s

```bash
apt-get update && apt-get install -y apt-transport-https

curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 

# ubuntu16
cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

apt-get update
apt-get install -y kubelet kubeadm kubectl
```



# 2. CentOS

## 2.1 寻找命令所在包

```bash
yum whatprovides */lspci
```



## 2.2 获取磁盘的 uuid

```bash
blkid

/dev/sr0: UUID="2020-04-22-00-51-40-00" LABEL="CentOS 7 x86_64" TYPE="iso9660" PTTYPE="dos" 
/dev/sda1: UUID="8447e521-4bb8-4fb7-853e-cd6661dd98b4" TYPE="xfs"
```



# 3. 常用命令

## 3.1 进程 & 线程

```bash
# 线程
top -H 

# 需要ncurses， 更友好
htop

# 进程的关联子进程
ps -T -p 959
    PID    SPID TTY          TIME CMD
    959     959 ?        00:00:27 redis-server
    959     960 ?        00:00:00 redis-server
    959     961 ?        00:00:00 redis-server
    959     962 ?        00:00:00 redis-server

```



## 3.2 路由

```bash
# 删除默认设置
route delete 0.0.0.0

# 外网路由，全走无线
route add 0.0.0.0 mask 0.0.0.0 192.168.33.1 –p

# 公司内网全部在10.40.*.*网段
route add 10.40.0.0 mask 255.255.0.0 10.40.254.1 -p

# 路由追踪
tracert -d google.com
```



# 3.3 tcpdump

```bash
tcpdump -i ens33 port 8080 -w http.cap


tcpdump src port 1025
tcpdump portrange 21-23

tcpdump -vvAls0 | grep 'User-Agent:'
tcpdump -vvAls0 | grep 'Set-Cookie|Host:|Cookie:'
```



## 4.3 k8s

```bash
cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

setenforce 0
yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet
```





# 4. 软件

## 4.1 Redis

```bash
wget http://download.redis.io/releases/redis-5.0.12.tar.gz 
tar zxvf redis-5.0.12.tar.gz 
cd redis-5.0.12
make
```

