# SSH - 反向隧道 & 内网穿透

## 0.0 概述

本文用于记录，如何利用个人公网`VPS`搭建`SSH隧道`

## 0.1 事前准备

| 机器代号 |  机器位置   | 地址(域名orIP) | 用户名 | sshd端口 | 是否需要运行sshd |
| :------: | :---------: | :------------: | :----: | :------: | :--------------: |
|    A     |  位于公网   |  192.168.11.2  |  vps   |    22    |       yes        |
|    B     | 位于NAT之后 |   非必须信息   | userb  |    22    |       yes        |
|    C     | 位于NAT之后 |   非必须信息   | userc  |    22    |        no        |



## 1.0 SSH反向隧道

### 使用背景

在你的受限的家庭网络之外你需要另一台主机（所谓的“中继主机”），你能从当前所在地通过 SSH 登录到它。你可以用有公网 `IP` 地址的`VPS`配置成一个中继主机。然后要做的就是从你的家庭服务器中建立一个到公网中继主机的**永久 SSH 隧道**。有了这个隧道，你就可以从中继主机中连接“回”家庭服务器（这就是为什么称之为 “反向” 隧道）。不管你在哪里、你的家庭网络中的 NAT 或 防火墙限制多么严格，只要你可以访问中继主机，你就可以连接到家庭服务器

![](https://img.linux.net.cn/data/attachment/album/201508/07/235248bx5kxx52gg8yyty4.jpg)

### 远程端口转发 

假设在家庭服务器执行如下命令

命令格式：`ssh -R [bind address:]port:host:hostport vps@xxx.xxx.xxx.xxx`

`-R`参数，就是建立远程端口转发；

`bind address`是可选参数，如果中继主机上的`sshd`的配置项`GatewayPorts`是`no`，则这个转发规则只对中继主机的本机地址（127.0.0.1）进行监听，如果想要中继主机监听所有自己的`IP`，则需要设`GatewayPorts yes`，同时设置`bing address`为空或`*`即可

`port`参数，中继主机监听端口，外部主机直径访问的中继主机的这个端口

`host`：目标主机的`ip`，如果家庭主机和中继主机在同一局域网，可以使用具体家庭服务器`ip`，如果家庭服务器在运营商的局域网里，一般选择`loaclhost`做为参数值

`hostport`：根据家庭服务器想要对外提供的服务选择，例如想要提供`ssh server`，就使用`ssh`服务的22端口作为参数值

`vps@xxx.xxx.xxx.xxx`：中继主机的用户和地址

远程端口转发实际就是利用已经建立的`ssh`连接，实现一条转发规则，所以在设置转发规则的时候，转发规则应该是能够通过这个已有的`ssh`连接实现的规则。

**本地端口转发**和**远程端口转发**的最大区别，谁是**转发规则的执行者**。本地端口转发是在本地进行端口监听，数据的入口在本地；远程端口转发是在远程进行端口监听，数据的入口在远程；**本地转发和远程转发可以是对称的**，但为什么还需要远程转发，是因为现代网络环境下，机器的`ssh`有时只能单向发起。这也就是为什么会有反向隧道的原因。

### 实际使用

反向隧道的建立依赖于SSH的远程端口转发功能，单纯建立家庭服务器和中继主机的SSH连接是不够的，还需要中继主机将访问机器的数据转发通过已经建立的SSH连接转发到家庭服务器才行。远程端口转发即是在建立本地主机和远程主机SSH连接的同时，设置一个转发规则。指定远程主机利用这个SSH连接将指定的远程端口的数据转发到指定的目标主机的目标端口



## 2.0 基础方案

现在有机器A（中继主机），有机器B（家庭服务器，本文默认家庭服务器已经安装`openssh-server`）。

#### 中继主机ssh服务配置

首先配置机器A的`sshd`服务，`sshd`服务受`systemd`机制管理的，`sshd`服务的配置文件是`/etc/ssh/sshd_config`

需要配置三个参数，`ClientAliveInterval 60`，`ClientAliveCountMax 10`，`GatewayPorts yes`

`ClientAliveInterval`参数是配置`ssh`服务端多少秒发送一次心跳信息，维持`ssh`连接

`ClientAliveCountMax`参数是配置多次次心跳消息无响应后，断开连接

上面两个参数实际是在设置`ssh`服务端的连接超时，现在是 60s * 10 = 600s

`GatewayPorts`参数是用来打开`ssh`服务的端口监听地址限制的，如果不设置或设置为`no`，则`ssh`服务只监听`127.0.0.1`地址上的数据，设置`yes`后会监听本机所有的`ip`

#### 家庭服务器发起远程端口转发

在配置好中继主机的`ssh`服务后，在机器B发起远程端口转发，命令如下：

`ssh -qnfNTR 6700:localhost:22 vps@192.168.11.1`

这里解释一下命令的各个参数

`-q`： 静默模式。大多数警告信息将不输出

`-n`：将`/dev/null`作为标准输入`stdin`，可以防止从标准输入中读取内容。 当`ssh`在后台运行时必须使用该项。但当`ssh`被询问输入密码时失效

`-f`：请求ssh在工作在后台模式。该选项隐含了"-n"选项，所以标准输入将变为`/dev/null`

`-N`：明确表示不执行远程命令。仅作端口转发时比较有用

`-T`：禁止为`ssh`分配伪终端

`-R`：远程端口转发，上文有具体说明

在执行完命令以后，机器B就与机器A之间就建立了一个反向隧道，机器C（任意主机）就可以通过以下命令访问到机器B：

`ssh -p 6700 userb@192.168.11.2`

这里有几点要说明一下，首先使用了`-p`参数指定发起`ssh`连接的端口为6700，这是因为我们配置的远程端口转发就是转发机器A的6700端口的数据到机器B的22端口。然后，`ssh`连接的目标主机是`userb@192.168.11.2`是因为TCP层只关心`ip`和端口，用户名是`ssh`关心的信息，转发只是单纯转发TCP流数据，所以`userb`不是机器A的用户也能够正常访问，最后数据有交互的是机器A和机器C，机器B只是在`TCP`层做转发工作

PS：这里的中继主机的`IP`实际是内网地址，是为了保护我的`VPS`请不要在意



## 2.1 方案改进一

基础方案虽然实现了任意主机访问家庭服务器的目标，但是基础方案还是存在几个不可忽视的缺点。

1. 家庭服务器和中继主机的连接的稳定性没有保障
2. 家庭服务器和中继主机的连接需要人工建立

#### 连接稳定性

首先解决`ssh`稳定性的问题，虽然前面已经设置了中继主机的`sshd`服务，但如果将`ssh`服务端设置成超时非常大也是不合理的，这样资源很容易被空闲连接占用，所以还是需要客户端维持连接。

解决`ssh`连接稳定性的一个方案就是`autossh`，`autossh`会在超时之后自动重新建立SSH 隧道，这样就解决了隧道的稳定性问题

使用两种命令都可以让`autossh`后台运行

`autossh -qNTR 6700:localhost:22 linkz@117.78.3.62 &`

这种就是在终端后台运行，由于`atuossh`不处理`SIGUHP`信号，所以退出终端不会导致`autossh`进程结束

`autossh -f -qNTR 6700:localhost:22 linkz@117.78.3.62`

`autossh`也提供了类型`&`的参数，`-f`参数会令`autossh`后台运行，而且不会传递给`ssh`，而且`-f`参数开启时，无法输入`ssh`登陆密码

#### 无密码登陆

最基础的实现,，在机器B上执行下面的命令（因为机器B在登陆过程中属于客户端）：

`ssh-keygen -t 'rsa'`

`ssh-copy-id vps@ip`

因为下面我们要将`autossh`建立隧道的工作服务化，所以需要先配置无密码登陆

#### 隧道的自动建立

最后要实现反向隧道的自动建立，我们用`systemd`机制将`autossh`部署成家庭服务器上的一个服务。

可以在`/etc/systemd/system`目录下，创建一个`autossh.service`文件，内容如下:

```sh
[Unit]
Description=Auto SSH Tunnel
After=network-online.target
[Service]
User=youruser
Type=simple
ExecStart=/bin/autossh -NTR 6700:localhost:22 usera@a.site -i /home/youruser/.ssh/id_rsa
ExecReload=/bin/kill -9 $MAINPID
KillMode=process
Restart=always
[Install]
WantedBy=multi-user.target
WantedBy=graphical.target
```

上面的`youruser`请设置你自己用户名，`vps`的网址也是设置成你自己的，`-i`参数是指定使用哪个秘钥文件进行登陆用户身份认证

#### 隧道服务(autossh.service)的部署

以下命令都是在机器B（家庭服务器）上执行

在B 上让`network-online.target` 生效：

`systemctl enable NetworkManager-wait-online`

然后设置隧道服务开机自启动

`sudo systemctl enable autossh`

PS：配置文件中的 `autossh `命令需要替换为其绝对地址，以及不支持 `-f `参数



## 2.2 成熟方案

即使使用了`autossh`和`systemd`，其实还有很多网络情况是我们没有考虑的，如果是正儿八经长期用的话，推荐使用专业程序来提供更加稳定高效的方向代理

[Frp]( https://github.com/fatedier/frp)：frp 是一个可用于内网穿透的高性能的反向代理应用，支持 tcp, udp 协议，为 http 和 https 应用协议提供了额外的能力，且尝试性支持了点对点穿透。

[Sakura Frp](https://link.zhihu.com/?target=https%3A//www.natfrp.org/)：基于 `Frp `二次开发的，免费提供内网穿透服务。普通用户的映射最高速率可达到 8Mbps，且不限流量



## 参考文献

- [SSH原理与运用（二）：远程操作与端口转发](http://www.ruanyifeng.com/blog/2011/12/ssh_port_forwarding.html)
- [ssh端口转发](https://www.zsythink.net/archives/2450)
- [SSH隧道技术----端口转发](https://www.jianshu.com/p/1ddab825956c)
- [man ssh翻译(ssh命令中文手册)](https://www.cnblogs.com/f-ck-need-u/p/7120669.html)
- [使用SSH反向隧道进行内网穿透](http://arondight.me/2016/02/17/%E4%BD%BF%E7%94%A8SSH%E5%8F%8D%E5%90%91%E9%9A%A7%E9%81%93%E8%BF%9B%E8%A1%8C%E5%86%85%E7%BD%91%E7%A9%BF%E9%80%8F/)
- [内网穿透：在公网访问你家的 NAS](https://zhuanlan.zhihu.com/p/57477087)
- [使用 autossh 建立反向 SSH 隧道管理个人计算机](https://www.centos.bz/2017/12/%E4%BD%BF%E7%94%A8-autossh-%E5%BB%BA%E7%AB%8B%E5%8F%8D%E5%90%91-ssh-%E9%9A%A7%E9%81%93%E7%AE%A1%E7%90%86%E4%B8%AA%E4%BA%BA%E8%AE%A1%E7%AE%97%E6%9C%BA/)
- [systemctl 针对 service 类型的配置文件](https://wizardforcel.gitbooks.io/vbird-linux-basic-4e/content/150.html)

