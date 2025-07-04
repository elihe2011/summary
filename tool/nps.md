# 1. 服务搭建

下载 https://github.com/ehang-io/nps 下的配置文件 `conf`，然后执行如下操作

```bash
# 新建目录，后将上述配置文件目录整个上传
mkdir -p /opt/nps

# 修改配置文件
vi /opt/nps/conf/nps.conf
bridge_port=5253         # 通道端口

web_username=admin         # web服务 
web_password=Admin@123
web_port = 5252

# 获取镜像
docker pull ffdfgdfg/nps:v0.26.10

# 启动容器
docker run -d --name=nps \
    -v /opt/nps/conf:/conf \
    --restart=always \
    --net=host ffdfgdfg/nps:v0.26.10
```



管理页面：http://xx:5252/    



# 2. 添加客户端

客户端 >> 新增客户端 >>  “允许客户端通过配置文件连接”、“压缩”、“加密” 三项均选择 “是”

添加后，获取到**唯一验证密钥**：`jqt7wo4ytzhhlbey`



# 3. 客户端安装

```bash
# 新建目录，后将上述配置文件目录整个上传
mkdir -p /opt/nps

# 获取镜像
docker pull ffdfgdfg/nps:v0.26.10

# 启动客户端
docker run -d --name=npc \
	--restart=always \
	--net=host ffdfgdfg/npc:v0.26.10 \
	-server=xx:5253 \
	-vkey=jqt7wo4ytzhhlbey 
```

成功后，客户端连线状态显示：“在线”



# 4. 新建 TCP 隧道

客户端 >> 新增客户端 >>  “允许客户端通过配置文件连接”、“压缩”、“加密” 三项均选择 “是”







