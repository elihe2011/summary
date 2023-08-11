# 1. 入门

## 1.1 安装

控制节点上操作：

```bash
apt install python3 python3-pip python3-dev -y

pip3 install ansible

pip3 install ansible-lint==6.8.5   # 开发时语法检查需要
```



## 1.2 概念

- Host Inventory：主机清单文件，即它管理的服务器分组列表。默认配置文件 `/etc/ansible/hosts`
- Playbook：被执行的 yaml 文件。ansible 管理主机有两种方式：
  - Ad-Hoc Commands  命令行
  - Playbook，支持更复杂的参数
- Role: Playbook 中的 Package，可以重用的一组功能完成的文件
- Ansible Tower：图形化界面配置和管理 ansible 脚本



## 1.3 执行过程

- 加载自己的配置文件 默认/etc/ansible/ansible.cfg

- 加载自己对应的模块文件，如command

- 通过ansible将模块或命令生成对应的临时py文件，并将该文件传输至远程服务器的对应执行用户

- $HOME/.ansible/tmp/ansible-tmp-数字/XXX.PY文件

- 给文件+x执行

- 执行并返回结果

- 删除临时py文件，sleep 0退出



## 1.4 命令工

- ansible主程序，临时命令执行工具

- ansible-doc 查看配置文档，模块功能查看工具

- ansible-galaxy 下载/上传优秀代码或Roles模块的官网平台

- ansible-playbook 定制自动化任务，编排剧本工具

- ansible-pull 远程执行命令的工具

- ansible-vault 文件加密工具

- ansible-console 基于Console界面与用户交互的执行工具



# 2. 主机配置

## 2.1 密码登录

配置项：

- `ansible_ssh_host` 远程主机名

- `ansible_ssh_port` 远程主机端口

- `ansible_ssh_user` 用户名

- `ansible_ssh_pass` 密码，不安全，建议使用 –ask-pass 或 SSH 密钥

- `ansible_sudo_pass` sudo 密码，不安全，建议使用  –ask-sudo-pass

```bash
root@ubuntu-20-04:/etc/ansible# cat /etc/ansible/hosts
192.168.3.196 ansible_ssh_user=root ansible_ssh_pass=root
192.168.3.197 ansible_ssh_user=root ansible_ssh_pass=root

root@ubuntu-20-04:/etc/ansible# ansible 192.168.3.196 -m ping
192.168.3.196 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```



## 2.2 免密码登录

```bash
# 生成密钥
ssh-keygen -t rsa

# 拷贝公钥到远程主机的authorized_keys文件上
ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.3.198

# 自身也免密码
ssh-copy-id localhost

# 首次登录
ssh -o stricthostkeychecking=no

root@ubuntu-20-04:/etc/ansible# cat /etc/ansible/hosts
192.168.3.196 ansible_ssh_user=root ansible_ssh_pass=root
192.168.3.197 ansible_ssh_user=root ansible_ssh_pass=root
192.168.3.198

root@ubuntu-20-04:/etc/ansible# ansible 192.168.3.198 -m ping
192.168.3.198 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```



## 2.3 分组

```yaml
[servers]
k8s-master1 ansible_host=192.168.3.197
k8s-node01 ansible_host=192.168.3.198 
k8s-node02 ansible_host=192.168.3.199

[all:vars]   # 组变量
ansible_python_interpreter=/usr/bin/python3
```



主机详细：

```bash
$ ansible-inventory --list -y
all:
  children:
    servers:
      hosts:
        k8s-master1:
          ansible_host: 192.168.3.197
          ansible_python_interpreter: /usr/bin/python3
        k8s-node01:
          ansible_host: 192.168.3.198
          ansible_python_interpreter: /usr/bin/python3
        k8s-node02:
          ansible_host: 192.168.3.199
          ansible_python_interpreter: /usr/bin/python3
    ungrouped: {}
```



## 2.4 连通性测试

```bash
# -m MODULE_NAME, --module-name MODULE_NAME (default=command)
$ ansible all -m ping
k8s-node02 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
k8s-node01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
k8s-master1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}

# -a MODULE_ARGS, --args MODULE_ARGS
$ ansible all -m command -a "hostnamectl"
$ ansible all -a "df -h"  # -m command 是默认值，可省略

# -m & -a
$ ansible all -m apt -a "name=vim state=latest"

# 指定组
$ ansible servers -a "uptime"

# 多个 host
$ ansible k8s-node01:k8s-node02 -m ping
k8s-node01 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
k8s-node02 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```



## 2.5 总结

hosts 文件格式

```bash
# IP + A/C
192.168.3.196 ansible_ssh_user="root" ansible_ssh_pass="root"

# nickname + IP + A/C
master-01 ansible_ssh_host=192.168.3.196 ansible_ssh_user="root" ansible_ssh_pass="root"

# nickname + IP + Account + 节点私钥
master-01 ansible_ssh_host=192.168.3.196 ansible_ssh_user="vagrant" ansible_private_key_file=./vagrant/machines/default/virtual/private_key

# IP，需要先配置免密码
192.168.0.10
```





# 3. 模块

**常见 module**：

- 调试类：

  - ping：连通性判断
  - debug：打印消息，类似echo

- 文件类：

  - copy：从本地拷贝文件到远程节点
  - template：从本地拷贝文件到远程节点，并进行变量替换
  - file：设置文件属性

- 系统管理：

  - user：账号
  - group：组
  - service：服务

- Ubuntu/Debian
  - apt
  - ufw

- Redhat/CentOS
  - yum
  - firewalld
- 执行命令：

  - shell：执行shell命令，支持 $HOME，"<"，">"，";"，"|" 及 "&" 
  - command：同上，但不支持以上符号
  - raw：执行原始命令



## 3.1 调试类

### 3.1.1 ping

检查机器是否连通

```bash
ansible web -m ping
```



### 3.1.2 debug

打印调试信息

```yaml
---
- hosts: k8s-node01

  tasks:
  # 打印消息
  - name: debug print msg
    debug:
      msg: "System {{ inventory_hostname }} has gateway {{ ansible_default_ipv4.gateway }}"

  # 打印变量
  - name: debug print var
    debug:
      var: hostvars[inventory_hostname]['ansible_default_ipv4']['gateway']

  # 绑定变量
  - name: execute shell & register the result  to variable
    shell: /usr/bin/uptime
    register: result

  - name: debug print registered variable
    debug:
      var: result
```



## 3.2 文件类

### 3.2.1 copy

文件复制，参数：

- src：本地文件路径，可以是目录或文件。如果是目录，将递归复制；路径以"/"结尾，则只复制目录下的内容；路径结尾没有"/"，则连同目录一并复制
- content：可替代 src，直接将其写入目标文件
- dest：目标文件路径，如果源文件是目录，它也必须是目录
- directory_mode：目标目录权限，默认为系统默认权限
- force：目标文件存在，是否强行覆盖，默认为yes
- others：file模块的选项

```yaml
---
- hosts: k8s-node01

  tasks:
  - name: copy test
    copy:
      src: /etc/sudoers
      dest: /etc
      owner: root
      group: root
      mode: 0440
      backup: true   # 目标主机已存在，则先备份
      validate: 'visudo -cf %s'      # 语法验证
```



### 3.2.2 template

基于模板方式生成文件并复制到远程主机

- backup：如果目标文件已存在，先备份，默认false
- src：jinja2 目标文件路径
- dest：目标文件路径
- force：是否强制覆盖，默认yes
- owner：文件属主
- group：文件属组
- mode：文件权限

```yaml
- template:
    src: etc/ssh/sshd_config.j2
    dest: /etc/ssh/sshd_config.j2
    owner: root
    group: root
    mode: '0600'
    validate: /usr/sbin/sshd -t %s
    backup: yes
```



### 3.2.3 file

文件或目录权限设置：

- force：是否强制创建软连接(源文件不存在、目标软链接已创建)，默认no
- group
- owner
- mode
- path：文件或目录路径
- recurse：递归设置文件的属性
- src：创建链接的源文件路径，state=link时有效
- dest：创建链接的目标文件路径，state=link时有效
- state:
  - directory：目录不存在，则创建
  - file：即使文件不存在，也不会被创建
  - link: 软链接
  - hard：硬链接
  - touch：文件不存在，则创建
  - absent：删除目录、文件或取消链接

```yaml
---
- hosts: k8s-node01

  tasks:  
  # 更改文件权限
  - name: change file mode
    file:
      path: /root/abc.txt
      owner: ubuntu
      group: ubuntu
      mode: 0600
    
  # 软连接
  - name: create symbolic link
    file:
      src: /root/abc.txt
      dest: /root/abc
      owner: root
      group: root
      state: link
      
  # 创建目录
  - name: create directory
    file:
      path: /root/ansible-dir
      state: directory
      mode: "u=rwx,g=r,o=r"
      
  # 创建文件
  - name: create file
    file:
      path: /root/xyz.txt
      state: touch
      mode: 0400
```



### 3.2.4 unarchive

解压文件：

- copy：解压文件前，是否先将文件拷贝到远程主机，默认yes。如果为no，需确保远程主机上已存在该文件
- creates：指定一个文件名，当该文件存在时，则解压指令不执行
- src：源文件路径，copy为yes时必须
- dest：文件解压的绝对路径
- group：解压后文件或目录的属组
- owner：解压后文件或目录的属主
- mode：解压后文件或目录的权限
- list_files：解压后列出压缩包中文件，默认为no

```yaml
- name: uncompress file
  unarchive:
    src: foo.tgz
    desc: /tmp/foo
    
- name: 解压远程机上已存在的文件
  unarchive:
    src: /tmp/foo.zip
    dest: /usr/local/bin
    remote_src: yes
    
- name: 先下载后解压
  unarchive:
    src: http://192.168.1.100/example.tar.xz
    dest: /tmp/example
    remote_src: yes
```



### 3.2.5 synchronize

使用 rsync 同步文件，将主机节点的目录推送到指定节点上

- src：源文件/目录的路径
- dest：远程主机的目标文件/目录的路径
- dest_port：远程主机同步端口，默认22
- mode：默认push，即向远程主机推送文件，pull时则从远程主机拉取文件
- delete：是否删除对端不存在的文件，默认no
- rsync_opts：rsync 参数选项

```yaml
# 将控制机器上的src同步到远程主机上
- synchronize:
    src: some/relative/path
    dest: /some/absolute/path

# 同步传递额外的rsync选项
- synchronize:
    src: /tmp/helloworld
    dest: /var/www/helloworld
    rsync_opts:
      - "--no-motd"
      - "--exclude=.git"

```



### 3.2.6 get_url

下载文件，类似 wget：

- url：下载地址
- url_username 和 url_password：需要用户名密码验证时

- sha256sum：下载完毕 sha256 检查
- timeout：下载超时时间，默认10s
- dest：文件存放路径
- headers：自定义 HTTP 头

```yaml
- name: Download foo.conf
  get_url:
    url: http://example.com/path/file.conf
    dest: /etc/foo.conf
    mode: 0440

- name: Download file with custom HTTP headers
  get_url:
    url: http://example.com/path/file.conf
    dest: /etc/foo.conf
    headers: 'key:value,key:value'

- name: Download file with check (sha256)
  get_url:
    url: http://example.com/path/file.conf
    dest: /etc/foo.conf
    checksum: sha256:b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c
```



### 3.2.7 fetch

从远程机获取文件，并存储在本地

- src：远程机文件路径
- dest：本地存储文件的目录

```yaml
# 将文件存储到/tmp/fetched/host.example.com/tmp/somefile中
- fetch:
    src: /tmp/somefile
    dest: /tmp/fetched

# 直接指定路径
- fetch:
    src: /tmp/somefile
    dest: /tmp/prefix-{{ inventory_hostname }}
    flat: yes

# 指定目标路径
- fetch:
    src: /tmp/uniquefile
    dest: /tmp/special/
    flat: yes
```



## 3.3 系统管理

### 3.3.1 group

组管理：

- gid
- name
- state
  - present 创建
  - absent 删除
- system，是否创建系统组，默认no



### 3.3.2 user

用户管理：

- name
- uid
- password：需要先加密 `echo -n '123456' | openssl passwd -1 -salt $(< /dev/urandom tr -dc '[:alnum:]' | head -c 32) -stdin`
- shell
- group
- groups：指定附属组

- home
- createhome: 是否创建HOME目录，默认yes
- system：是否为系统用户
- remove：当 state=absent，remove=yes时，删除用户并删除HOME目录，即`userdel -r`
- state
  - present
  - absent
- generate_ssh_key：是否生成用户的SSH密钥
- ssh_key_bits：密钥位数
- ssh_key_passphrase：密钥的密码
- ssh_key_file：密钥文件名称
- ssh_key_type：密钥的类型



```yaml
---
- hosts: k8s-node01

  tasks:
  # 新增组
  - name: create group
    group:
      name: eli
      gid: 2000
  
  # 新增账号
  - name: create account
    user:
      name: eli
      comment: 'Eli He'
      shell: /bin/bash
      home: /home/eli
      uid: 2000
      group: eli
      groups: adm,sudo
      append: yes
  
  # 删除账号
  - name: remove account
    user:
      name: foo
      state: absent
      remove: yes
      
  # 创建用户时创建SSH密钥
  - name: create account with ssh key
    user:
      name: rania
      generate_ssh_key: yes
      ssh_key_bits: 2048
      ssh_key_file: .ssh/id_rsa
```



### 3.3.3 service

服务管理：

- name
- state
  - started
  - stopped
  - restarted
  - reloaded
- sleep：执行 restarted 时，在 stop 和 start 之间沉睡几秒
- runlevel：运行级别
- enabled：开机启动，默认no
- arguments：命令的额外参数

```yaml
# 启动、关闭、重启、配置重载
- service:
    name: httpd
    state: started|stopped|restarted|reloaded
    
# 开机启动
- service:
    name: httpd
    enabled: yes|no
    
# 指定参数，例如：启动网络服务下的特定网卡
- service:
    name: network
    state: restarted
    args: eth0
```



## 3.4 Ubuntu

### 3.4.1 apt

软件包管理：

- name：软件包名称，支持通过类似 `name=git=1.6`指定版本
- state
  - present：安装
  - latest：安装最新版本，已安装则升级
  - absent：卸载

- deb：安装”.deb“后缀的软件包
- install_recommends：默认在true，下载并安装；当为false时，只下载
- update_cache：当为 yes 时，执行 `apt update`

```yaml
# 在安装foo软件包前更新然后安装foo
- apt: 
    name=foo 
    update_cache=yes

# 移除foo软件包
- apt: 
    name=foo 
    state=absent

# 安装foo软件包
- apt: 
    name=foo=1.00 
    state=present

# 安装nginx最新的名字为squeeze-backport发布包，并且安装前执行更新
- apt: 
    name=nginx 
    state=latest 
    default_release=squeeze-backports 
    update_cache=yes
    
# 只下载openjdk-6-jdk最新的软件包，不安装
- apt: 
    name=openjdk-6-jdk 
    state=latest 
    install_recommends=no

# 安装所有软件包到最新版本
- apt: 
    upgrade=dist

# 安装远程节点上的/tmp/mypackage.deb软件包
- apt: 
    deb=/tmp/mypackage.deb
```



### 3.4.2 ufw



## 3.5 CentOS

### 3.5.1 yum

软件包管理：

- name：软件包名称，可携带版本，也可传递一个url或本地rpm包路径
- state：
  - present：安装
  - latest：安装最新版本，已安装则升级
  - absent：卸载

- config_file：yum的配置文件
- disable_gpg_check：关闭 gbp 检查
- disablerepo：禁用某个源
- enablerepo：启用某个源

```yaml
# 安装最新版本的包，如果已经安装，则更新到最新版本
  - name: install the latest version of Apache
    yum:
      name: httpd
      state: latest

# 安装指定版本的包
  - name: install one specific version of Apache
    yum:
      name: httpd-2.2.29-1.4.amzn1
      state: present

# 删除包
  - name: remove the Apache package
    yum:
      name: httpd
      state: absent

# 从指定的repo testing中安装包
  - name: install the latest version of Apache from the testing repo
    yum:
      name: httpd
      enablerepo: testing
      state: present

# 从yum源上安装一组包
- name: install the 'Development tools' package group
  yum:
    name: "@Development tools"
    state: present

- name: install the 'Gnome desktop' environment group
  yum:
    name: "@^gnome-desktop-environment"
    state: present

# 从本地文件中安装包
- name: install nginx rpm from a local file
  yum:
    name: /usr/local/src/nginx-release-centos-6-0.el6.ngx.noarch.rpm
    state: present

# 从URL中安装包
- name: install the nginx rpm from a remote repo
  yum:
    name: http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm
    state: present
```



### 3.5.2 firewalld

```yaml
# 为服务添加firewalld规则
- firewalld:
    service: https
    permanent: true
    state: enabled

- firewalld:
    zone: dmz
    service: http
    permanent: true
    state: enabled

# 为端口号添加firewalld规则
- firewalld:
    port: 8081/tcp
    permanent: true
    state: disabled

- firewalld:
    port: 161-162/udp
    permanent: true
    state: enabled

# 其它复杂的firewalld规则
- firewalld:
    rich_rule: 'rule service name="ftp" audit limit value="1/m" accept'
    permanent: true
    state: enabled

- firewalld:
    source: 192.0.2.0/24
    zone: internal
    state: enabled

- firewalld:
    zone: trusted
    interface: eth2
    permanent: true
    state: enabled

- firewalld:
    masquerade: yes
    state: enabled
    permanent: true
    zone: dmz
```



## 3.6 执行命令

Ansible 可以执行命令的模块有三个：

- command
- shell
- raw

应尽量避免使用这三个模块来执行命令，因为其他模块大部分都是幂等性的，可以自动进行更改跟踪。command、shell、raw不具备幂等性。

**command、shell模块：要求受管主机上安装Python**。command可以在受管主机上执行shell命令，但是不支持环境变量和操作符（例如 '|', '<', '>', '&'），shell模块调用的/bin/sh指令执行。

**raw模块：不需要受管主机上安装Python**，直接使用远程shell运行命令，通常用于无法安装Python的系统（例如网络设备等）。



### 3.6.1 shell

执行命令，支持特殊字符：

- chdir：执行命令前，切换目录
- executable：更改执行命令的shell

```yaml
- name: Execute the command in remote shell; stdout goes to the specified file on the remote.
  shell: somescript.sh >> somelog.txt

- name: Run a command that uses non-posix shell-isms (in this example /bin/sh doesn't handle redirection and wildcards together but bash does)
  shell: cat < /tmp/*txt
  args:
    executable: /bin/bash
```



### 3.6.2 command

执行命令，不支持特殊字符：

- chdir：执行命令前，切换目录

```yaml
- name: return motd to registered var
  command: cat /etc/motd
  register: mymotd

- name: Run the command if the specified file does not exist.
  command: /usr/bin/make_database.sh arg1 arg2 creates=/path/to/database

# 您还可以使用“args”表单提供选项。
- name: This command will change the working directory to somedir/ and will only run when /path/to/database doesn't exist.
  command: /usr/bin/make_database.sh arg1 arg2
  args:
    chdir: somedir/
    creates: /path/to/database
```



### 3.6.3 raw

执行原生命令

```yaml
- name: Bootstrap a legacy python 2.4 host
  raw: yum -y install python-simplejson

- name: Bootstrap a host without python2 installed
  raw: dnf install -y python2 python2-dnf libselinux-python

- name: Run a command that uses non-posix shell-isms (in this example /bin/sh doesn't handle redirection and wildcards together but bash does)
  raw: cat < /tmp/*txt
  args:
    executable: /bin/bash

- name: safely use templated variables. Always use quote filter to avoid injection issues.
  raw: "{{package_mgr|quote}} {{pkg_flags|quote}} install {{python_simplejson|quote}}"
```



## 3.7 pip

Python 依赖库：

- name: 包名称或远程 url 地址
- requiremens：依赖包文件 requirements.txt 路径
- chdir：执行 pip 命令前切换目录
- version：指定版本
- extra_args：额外参数
- executable：显示指定可执行文件路径，用于区分不同的Python版本
- virtualenv：Python虚拟环境路径
- virtualenv_command：创建虚拟环境的命令或路径。例如 pyenv，virtualenv，virtualenv2 等
- virtualenv_python：创建虚拟环境的Python可执行文件，例如 Python3.6, Python2.7。未指定则使用 ansible 使用的Python版本
- state
  - present
  - absent
  - latest
  - forcereinstall

```yaml
# 安装bottle python包。
- pip:
    name: bottle

# 在0.11版安装bottle python包。
- pip:
    name: bottle
    version: 0.11

# 使用远程协议（bzr +，hg +，git +，svn +）安装MyApp。 您不必在extra_args中提供'-e'选项。
- pip:
    name: svn+http://myrepo/svn/MyApp#egg=MyApp

# 使用远程协议（bzr +，hg +，git +）安装MyApp。
- pip:
    name: git+http://myrepo/app/MyApp
    
# 从本地压缩包安装MyApp
- pip:
    name: file:///path/to/MyApp.tar.gz
    
# 将bottle安装到指定的virtualenv中，继承全局安装的模块
- pip:
    name: bottle
    virtualenv: /my_app/venv
    virtualenv_site_packages: yes
    
# 使用Python 2.7将bottle安装到指定的virtualenv中
- pip:
    name: bottle
    virtualenv: /my_app/venv
    virtualenv_command: virtualenv-2.7

# 在用户主目录中安装bottle。
- pip:
    name: bottle
    extra_args: --user

# 安装指定的python requirements
- pip:
    requirements: /my_app/requirements.txt

# 在指定的virtualenv中安装指定的python requirements。
- pip:
    requirements: /my_app/requirements.txt
    virtualenv: /my_app/venv

# 安装指定的python requirements和自定义pip源URL
- pip:
    requirements: /my_app/requirements.txt
    extra_args: -i https://example.com/pypi/simple

# 专门为Python 3.3安装bottle，使用'pip-3.3'可执行文件。
- pip:
    name: bottle
    executable: pip-3.3

# 安装 bottle，如果已安装，强制重新安装
- pip:
    name: bottle
    state: forcereinstall
```



# 4. ansible 命令

命令工具：`ansible <host-pattern> [options]`

```bash
# 环境检查
ansible all -m ping

# 执行命令
ansible all -m command -a "/bin/echo hello"
ansible all -a "/bin/echo hello" 

# 文件拷贝
ansible all -m copy -a "src=/etc/hosts dest=/tmp/hosts"

# 安装软件
ansible all -m apt -a "name=lrzsz state=present"

# 新增用户
ansible all -m user -a "name=foo password=<crypted password here>"

# 下载git包
ansible k8s-node01 -m git -a "repo=https://github.com/gin-gonic/gin.git dest=/tmp/abc version=HEAD"

# 启动服务
ansible all -m service -a "name=atd state=started"

# 并行执行
ansible k8s-node0* -a "/sbin/reboot" -f 2

# 主机信息
ansible all -m setup
```



# 5. ansible 脚本

## 5.1 hosts & user

执行的机器和用户

| key               | 含义                                                         |
| ----------------- | ------------------------------------------------------------ |
| **hosts**         | 为主机的IP，或者主机组名，或者关键字all                      |
| **user**          | 在远程以哪个用户身份执行                                     |
| **become**        | 切换成其它用户身份执行，值为yes或者no                        |
| **become_method** | 与became一起用，指可以为‘sudo’、’su’、’pbrun’、’pfexec’、’doas’ |
| **become_user**   | 与become_user一起用，可以是root或者其它用户名                |

脚本里用became的时候，执行的playbook的时候可以加参数–ask-become-pass，则会在执行后提示输入sudo密码：

`ansible-playbook deploy.yml --ask-become-pass`



```yaml
- hosts: k8s-node01
  become: true
  vars_files:
    - vars/default.yml
```



## 5.2 tasks

定义顺序执行的动作action，每个action调用一个 ansible module，语法:

```yaml
tasks:
  - name: make sure apache is running
    service: name=httpd state=running
    
# 过长的参数，改用yaml
 tasks:
  - name: Copy ansible inventory file to client
    copy:
      src: /etc/ansible/hosts
      dest: /etc/ansible/hosts
      owner: root
      group: root
      mode: 0644
```

任务状态：

- ok    
- changed
- unreachable
- failed
- skipped
- rescued
- ignored



## 5.3 handlers

善后工作。事件处理，默认不执行。只在task的执行状态为changed的时候，才会执行该task调用的handler只有在action中触发了才执行，多次触发只执行一次

```yaml
  handlers:
    - name: Reload Apache
      service:
        name: apache2
        state: reloaded

    - name: Restart Apache
      service:
        name: apache2
        state: restarted
```



## 5.4 vars

### 5.4.1 自定义变量

**定义变量**:

```yaml
- hosts: web
  vars:
    http_port: 80
  remote_user: root
  tasks:
  - name: insert firewalld rule for httpd
    firewalld: port=\{\{ http_port \}\}/tcp permanent=true state=enabled immediate=yes
```



**文件变量（变量较多时）**:

```yaml
- hosts: web
  remote_user: root
  vars_files:
      - vars/server_vars.yml  # 内容为 "http_port: 80"
  tasks:
  - name: insert firewalld rule for httpd
    firewalld: port=\{\{ http_port \}\}/tcp permanent=true state=enabled immediate=yes
```



**复杂变量**：

```yaml
# 定义变量
foo:
  field1: one
  field2: two
  
# 使用变量
foo['field1']
foo.field1
```



### 5.4.2 系统变量 (facts)

获取远程主机系统信息：`ansible all -m setup -u root`

```text
k8s-node01 | SUCCESS => {
    "ansible_facts": {
        "ansible_all_ipv4_addresses": [
            "192.168.3.198"
        ],
        "ansible_all_ipv6_addresses": [
            "fe80::5054:ff:feb2:fc46"
        ],
        "ansible_apparmor": {
            "status": "enabled"
        },
        "ansible_architecture": "x86_64",
        "ansible_bios_date": "04/01/2014",
        "ansible_bios_vendor": "SeaBIOS",
        "ansible_bios_version": "1.11.1-4.module_el8.2.0+320+13f867d7",
        "ansible_board_asset_tag": "NA",
        "ansible_board_name": "NA",
        "ansible_board_serial": "NA",
        "ansible_board_vendor": "NA",
        "ansible_board_version": "NA",
        "ansible_chassis_asset_tag": "NA",
        "ansible_chassis_serial": "NA",
        "ansible_chassis_vendor": "Red Hat",
        "ansible_chassis_version": "RHEL-7.6.0 PC (Q35 + ICH9, 2009)",
        "ansible_cmdline": {
            "BOOT_IMAGE": "/vmlinuz-4.15.0-196-generic",
            "maybe-ubiquity": true,
            "ro": true,
            "root": "/dev/mapper/ubuntu--vg-ubuntu--lv"
        },
        ......
        "ansible_default_ipv4": {
            "address": "192.168.3.198",
            "alias": "enp1s0",
            "broadcast": "192.168.3.255",
            "gateway": "192.168.3.1",
            "interface": "enp1s0",
            "macaddress": "52:54:00:b2:fc:46",
            "mtu": 1500,
            "netmask": "255.255.255.0",
            "network": "192.168.3.0",
            "type": "ether"
        },
        ......
        "ansible_enp1s0": {
            "active": true,
            "device": "enp1s0",
            ......
            "ipv4": {
                "address": "192.168.3.198",
                "broadcast": "192.168.3.255",
                "netmask": "255.255.255.0",
                "network": "192.168.3.0"
            },
            "ipv6": [
                {
                    "address": "fe80::5054:ff:feb2:fc46",
                    "prefix": "64",
                    "scope": "link"
                }
            ],
            "macaddress": "52:54:00:b2:fc:46",
            "module": "e1000e",
            "mtu": 1500,
            "pciid": "0000:01:00.0",
            "phc_index": 0,
            "promisc": false,
            "speed": 1000,
            "timestamping": [
                "tx_hardware",
                "tx_software",
                "rx_hardware",
                "rx_software",
                "software",
                "raw_hardware"
            ],
            "type": "ether"
        },
```



**使用系统变量**：

```yaml
- hosts: all
  user: root
  tasks:
  - name: echo system
    shell: echo \{\{ ansible_os_family \}\}
  - name install ntp on Debian linux
    apt: name=git state=installed
    when: ansible_os_family == "Debian"
  - name install ntp on redhat linux
    yum: name=git state=present
    when: ansible_os_family == "RedHat"
```



**访问复杂系统变量**：

```yaml
\{\{ ansible_enp1s0["ipv4"]["address"] \}\}

\{\{ ansible_enp1s0.ipv4.address \}\}
```



**禁用远程主机系统信息收集**：

```yaml
- hosts: whatever
  gather_facts: no
```



### 5.4.3 目标中使用变量

变量配置：`vars/default.yml`

```yaml
---
http_host: "192.168.3.198"
http_conf: "apache.conf"
http_port: "80"
disable_default: true
```



配置模板：`templates/apache.conf.j2`

```jinja2
<VirtualHost *:{{ http_port }}>
    ServerAdmin admin@localhost
    ServerName {{ http_host }}
    ServerAlias {{ http_host }}
    DocumentRoot /var/www/html
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
```



网页模板：`templates/index.html.j2`

```jinja2
<html>
    <head>
        <title>Welcome to {{ http_host }} !</title>
    </head>
    <body>
        <h1>Success! The {{ http_host }} virtual host is working!</h1>
    </body>
</html>
```



部署playbook：`deploy-apache.yml`

```yaml
---
- hosts: k8s-node01
  become: true
  vars_files:
    - vars/default.yml

  tasks:
    - name: Install prerequisites
      apt: name={{ item }} update_cache=yes state=latest force_apt_get=yes
      loop: [ 'aptitude' ]

    - name: Install Apache
      apt: name=apache2 update_cache=yes state=latest

    - name: Create document root
      file:
        path: "/var/www/html"
        state: directory
        mode: '0755'

    - name: Copy index test page
      template:
        src: "templates/index.html.j2"
        dest: "/var/www/html/index.html"

    - name: Set up Apache virtualhost
      template:
        src: "templates/apache.conf.j2"
        dest: "/etc/apache2/sites-available/{{ http_conf }}"

    - name: Enable new site
      shell: /usr/sbin/a2ensite {{ http_conf }}
      notify: Reload Apache

    - name: Disable default Apache site
      shell: /usr/sbin/a2dissite 000-default.conf
      when: disable_default
      notify: Reload Apache

    - name: "UFW - Allow HTTP on port {{ http_port }}"
      ufw:
        rule: allow
        port: "{{ http_port }}"
        proto: tcp

  handlers:
    - name: Reload Apache
      service:
        name: apache2
        state: reloaded

    - name: Restart Apache
      service:
        name: apache2
        state: restarted
```



### 5.4.4 变量注册

将 task 执行结构作为变量

```yaml
- hosts: web

  tasks:
     - shell: ls
       register: result
       ignore_errors: True

     - shell: echo "\{\{ result.stdout \}\}"
       when: result.rc == 5

     - debug: msg="\{\{ result.stdout \}\}"
```



### 5.4.5 命令行传递变量

```bash
# 传递变量
ansible-playbook deploy-nginx.yml --extra-vars "hosts=web user=root"

# json格式参数
ansible-playbook deploy-nginx.yml --extra-vars "{'hosts':'vm-rhel7-1', 'user':'root'}"

# 参数文件
ansible-playbook deploy-nginx.yml --extra-vars "@vars.json"
```



## 5.5 逻辑控制

### 5.5.1 when

**满足条件则执行**:

```yaml
tasks:
  - name: "shutdown Debian flavored systems"
    command: /sbin/shutdown -t now
    when: ansible_os_family == "Debian"
```



**根据action结果，来决定接下来的执行的action**:

```yaml
tasks:
  - command: /bin/false
    register: result
    ignore_errors: True
  - command: /bin/something
    when: result|failed
  - command: /bin/something_else
    when: result|success
  - command: /bin/still/something_else
    when: result|skipped
```



**系统变量类型转换**：`|int`

```yaml
- hosts: web
  tasks:
    - debug: msg="only on Red Hat 7, derivatives, and later"
      when: ansible_os_family == "RedHat" and ansible_lsb.major_release|int >= 6
```



**变量是否定义**：

```yaml
tasks:
 - shell: echo "I've got '\{\{ foo \}\}' and am not afraid to use it!"
   when: foo is defined

 - fail: msg="Bailing out. this play requires 'bar'"
   when: bar is not defined
```



**数值表达式**：

```yaml
tasks:
  - command: echo \{\{ item \}\}
    with_items: [ 0, 2, 4, 6, 8, 10 ]
    when: item > 5
```



**与include一起使用**：

```yaml
- include: tasks/sometasks.yml
  when: "'reticulating splines' in output"
```



**与role一起使用**：

```yaml
- hosts: webservers
  roles:
     - { role: debian_stock_config, when: ansible_os_family == 'Debian' }
```



### 5.5.2 循环

#### 5.5.2.1 标准循环 (with_items)

**重复任务**：

```yaml
tasks:
  - name: add sereral users
    user: name={{ item }} state=present groups=sudo
    with_items:
      - user1
      - user2
```



**引用变量**：

```yaml
vars:
  userlist: ["user1", "user2"]
tasks:
  - name: remove serveral user
    user: name={{ item }} state=absent remove=yes
    with_items: "{{ userlist }}"   # 必须加双引号
```



**哈希列表**：

```yaml
tasks:
  - name: create users
    user: name={{ item.name }} state=present groups={{ item['groups'] }}
    with_items:
      - { name: 'user1', groups: 'sudo' }
      - { name: 'user2', groups: 'sudo' }
```



#### 5.5.2.2 嵌套循环 (with_nested)

```yaml
tasks:
  - name: give users access to multiple databases
    mysql_user: name={{ item[0] }} priv={{ item.1 }}.*:ALL append_privs=yes password=foo
    with_nested:
      - ['alice', 'bob']
      = ['clientdb', 'employeedb', 'providerdb']
```



#### 5.5.2.3 哈希表循环 (with_dict)

未验证成功

```yaml
- hosts: k8s-node01
  vars:
    users:
      alice:
        name: Alice Smith
        phone: 123-456-7890
      bob:
        name: Bob Trump
        phone: 987-654-3210
  tasks:
    name: print phone records
    debug:
      msg: "User {{ item.key }} is {{ item.value.name }} ({{ item.value.phone }})"
    with_dict: "{{ users }}"

```



#### 5.5.2.4 文件列表循环 (with_fileglob)

```yaml
  tasks:
    - name: first ensure our target directory exists
      file: dest=/etc/fooapp state=directory

    - name: copy each file over that matches the given pattern
      copy: src={{ item }} dest=/etc/fooapp/ owner=root mode=600
      with_fileglob:
        - /playbooks/files/fooapp/*
```



### 5.5.3 块语句 (block)

**多个 action 组成块**：

```yaml
   tasks:
     - block:
         - yum: name=\{\{ item \}\} state=installed
           with_items:
             - httpd
             - memcached

         - template: src=templates/src.j2 dest=/etc/foo.conf

         - service: name=bar state=started enabled=True

       when: ansible_distribution == 'CentOS'
       become: true
       become_user: root
```



**块异常处理**：

```yaml
tasks:
  - block:
      - debug: msg='i execute normally'
      - command: /bin/false
      - debug: msg='i never execute, cause ERROR!'
    rescue:
      - debug: msg='I caught an error'
      - command: /bin/false
      - debug: msg='I also never execute :-('
    always:
      - debug: msg="this always executes"
```



## 5.6 重用 playbook

### 5.6.1 include

**支持重用单个 playbook 文件**

被重用的文件 `tasks/firewall_httpd_default.yml`:

```yaml
---
  - name: insert firewalld rule for httpd
    firewalld: port=\{\{ port \}\}/tcp permanent=true state=enabled immediate=yes
```

使用：

```yaml
tasks:
- include: tasks/firewall.yml port=80
- include: tasks/firewall.yml port=443
- include: tasks/firewall.yml
  vars:
    port: 8080
```



### 5.6.2 role

playbook 中的 “Package”机制

role的目录结构:

```yaml
site.yml
roles/
├── myrole
    ├── tasks
    │   └── main.yml
    ├── handlers
    │   └── main.yml
    ├── defaults
    │   └── main.yml
    ├── vars
    │   └── main.yml
    ├── files
    ├── templates
    ├── README.md
    ├── meta
    │   └── main.yml
    └── tests
        ├── inventory
        └── test.yml
```



目录和文件功能:

- 如果` roles/x/tasks/main.yml` 存在，其中的 tasks 将被添加到 play 中，这个文件也可以视作role的入口文件。
- 如果 `roles/x/handlers/main.yml` 存在，其中的 handlers 将被添加到 play 中
- 如果 `roles/x/vars/main.yml` 存在，其中的 variables 将被添加到 play 中
- 如果 `roles/x/meta/main.yml` 存在，其中的 “角色依赖” 将被添加到 roles 列表中
- `roles/x/tasks/main.yml`中的tasks，可以引用 `roles/x/{files,templates,tasks}`中的文件，不需要指明文件的路径。



site.yml中调用role:

```yaml
---
- hosts: webservers
  roles:
     - myrole
```



### 5.6.1 带参数的 role

定义一个带参数的 role，目录结构

```text
 main.yml
 roles
   myrole
     tasks
       main.yml
```

在roles/myrole/tasks/main.yml中，使用`{{ }}`定义的变量就可以了

```
 ---
 - name: use param
   debug: msg="{{ param }}"
```

使用带参数的 role:

```yaml
---
- hosts: webservers
  roles:
    - role: myrole
      param: 'Call some_role for the 1st time'
    - role: myrole
      param: 'Call some_role for the 2nd time'
```



支持默认参数：

```text
 main.yml
 roles
   myrole
     tasks
       main.yml
     defaults
       main.yml     # 定义默认参数
```

在roles/myrole/defaults/main.yml中，配置参数：

```yaml
param: "I am the default value"
```



### 5.6.2 与 when 合用

```yaml
---
- hosts: webservers
  roles:
    - role: my_role
      when: "ansible_os_family == 'RedHat'"
```



### 5.6.3 roles 和 tasks 的调用顺序

**pre_tasks > role > tasks > post_tasks**

```yaml
---

- hosts: lb
  user: root

  pre_tasks:
    - name: pre
      shell: echo 'hello'

  roles:
    - { role: some_role }

  tasks:
    - name: task
      shell: echo 'still busy'

  post_tasks:
    - name: post
      shell: echo 'goodbye'
```



## 5.7 tags 执行部分任务

### 5.7.1 基本用法

```yaml
tasks:

  - yum: name=\{\{ item \}\} state=installed
    with_items:
       - httpd
    tags:
       - packages

  - name: copy httpd.conf
    template: src=templates/httpd.conf.j2 dest=/etc/httpd/conf/httpd.conf
    tags:
       - configuration

  - name: copy index.html
    template: src=templates/index.html.j2 dest=/var/www/html/index.html
    tags:
       - configuration
```

执行解析：

```bash
# 执行全部
$ ansible-playbook deploy.yml

# 执行部分步骤
$ ansible-playbook deploy.yml --tags=packages

# 不执行部分步骤
$ ansible-playbook deploy.yml --skip-tags=configuration
```



### 5.7.2 特殊 tags

- always 不管是否指定了执行的tags，该步骤总数被执行

  ```bash
  tasks:
  
      - debug: msg="Always print this debug message"
        tags:
          - always
  
      - yum: name=\{\{ item \}\} state=installed
        with_items:
           - httpd
        tags:
           - packages
  
      - template: src=templates/httpd.conf.j2 dest=/etc/httpd/conf/httpd.conf
        tags:
           - configuration
  ```

  

- “tagged”，“untagged”和“all”

  ```bash
  ansible-playbook tags_tagged_untagged_all.yml --tags tagged
  ansible-playbook tags_tagged_untagged_all.yml --tags untagged
  ansible-playbook tags_tagged_untagged_all.yml --tags all
  ```

  

### 5.7.3 include 和 role 中使用tags

include语句指定执行的tags的语法：

```yaml
- include: foo.yml
  tags: [web,foo]
```

调用role中的tags的语法为：

```yaml
roles:
  - { role: webserver, port: 5000, tags: [ 'web', 'foo' ] }
```











问题：

```bash
root@ubuntu-20-04:/etc/ansible# ansible 192.168.3.196 -m ping
192.168.3.196 | FAILED! => {
    "msg": "to use the 'ssh' connection type with passwords or pkcs11_provider, you must install the sshpass program"
}

root@ubuntu-20-04:/etc/ansible# apt install sshpass
Reading package lists... Done

root@ubuntu-20-04:/etc/ansible# ansible 192.168.3.196 -m ping
192.168.3.196 | FAILED! => {
    "msg": "Using a SSH password instead of a key is not possible because Host Key checking is enabled and sshpass does not support this.  Please add this host's fingerprint to your known_hosts file to manage this host."
}

# 等效于 export ANSIBLE_HOST_KEY_CHECKING=False
root@ubuntu-20-04:/etc/ansible# vi ansible.cfg   
[defaults]
host_key_checking = false

root@ubuntu-20-04:/etc/ansible# ansible 192.168.3.196 -m ping
192.168.3.196 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}

```











