# SSH - 反向隧道 & 内网穿透

## 0.0 概述

本文用于记录，如何利用个人公网`VPS`搭建`ssh隧道`

## 0.1 事前准备

| 机器代号 |  机器位置   | 地址(域名orIP) | 用户名 | sshd端口 | 是否需要运行sshd |
| :------: | :---------: | :------------: | :----: | :------: | :--------------: |
|    A     |  位于公网   |  192.168.11.2  |  vps   |    22    |       yes        |
|    B     | 位于NAT之后 |   非必须信息   | userb  |    22    |       yes        |
|    C     | 位于NAT之后 |   非必须信息   | userc  |    22    |        no        |
