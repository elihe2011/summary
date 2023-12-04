# 1. 远程桌面

```bash
sudo apt-get install xrdp xorgxrdp  -y

systemctl status xrdp

# 一定要运行下面的命令，否则可能会出现卡顿或者黑频的现象
sudo init 3
```

需要注意：

- 退出时，需要把uos注销到登录界面
- 然后Windows退出时点注销退出，不要直接关闭窗口，否则uos会黑屏



# 2. 关闭激活提示

**Your system is not activated. Please activate as soon as possible for normal use.**

```bash
systemctl |grep license
systemctl stop license.service
systemctl disable license.service

cd /usr/lib/deepin-daemon
chmod -x uos-license-agent
sudo killall uos-license-agent
sudo killall uos-activator
```






xauth add $(xauth -f ~root/.Xauthority list|tail -



