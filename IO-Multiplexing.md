# IO多路复用

## 0.0 概述

**I/O multiplexing 这里面的 multiplexing 指的其实是在单个线程通过记录跟踪每一个Socket(I/O流)的状态来同时管理多个I/O流**. 发明它的原因，是尽量多的提高服务器的吞吐能力，

与多进程和多线程技术相比，I/O多路复用技术的最大优势是系统开销小，**这里的“复用”指的是复用同一个线程**，同一个进（线）程可以处理多个IO数据流，这样系统就不必创建进程/线程去处理多个IO流，也不必维护这些进程/线程，**需要的线程数减少，也就减少了内存开销和上下文切换的CPU开销**。

总的来说，从实际使用（非极限benchmark）上来说，线程池并不显著地比io多路复用慢，**多路复用的主要优势在于使用更少的内存等资源来支持更高的并发数**

## 1.0 select

### 1.1 实现原理

![](https://images0.cnblogs.com/blog/305504/201308/17201205-8ac47f1f1fcd4773bd4edd947c0bb1f4.png)

1. 使用copy_from_user从用户空间拷贝fd_set到内核空间

2. 注册回调函数__pollwait

3. 遍历所有fd，调用其对应的poll方法（对于socket，这个poll方法是sock_poll，sock_poll根据情况会调用到tcp_poll,udp_poll或者datagram_poll）

4. 以tcp_poll为例，其核心实现就是__pollwait，也就是上面注册的回调函数

5. __pollwait的主要工作就是把current（当前进程）挂到设备的等待队列中，不同的设备有不同的等待队列，对于tcp_poll来说，其等待队列是sk->sk_sleep（注意把进程挂到等待队列中并不代表进程已经睡眠了）。在设备收到一条消息（网络设备）或填写完文件数据（磁盘设备）后，会唤醒设备等待队列上睡眠的进程，这时current便被唤醒了

6. poll方法返回时会返回一个描述读写操作是否就绪的mask掩码，根据这个mask掩码给fd_set赋值

7. 如果遍历完所有的fd，还没有返回一个可读写的mask掩码，则会调用schedule_timeout令调用select的进程（也就是current）进入睡眠。当设备驱动发生自身资源可读写后，会唤醒其等待队列上睡眠的进程。如果超过一定的超时时间（schedule_timeout指定），还是没人唤醒，则调用select的进程会重新被唤醒获得CPU，进而重新遍历fd，判断有没有就绪的fd

8. 把fd_set从内核空间拷贝到用户空间

**简约版：**

1. 先把全部fd扫一遍

2. 如果发现**有满足条件(可写，可读，异常)的fd || 事件(发生超时，有signal打断)**，跳到5

3. 如果没有，当前进程休眠指定超时时间

4. 超时时间到达 || 有发生状态改变的fd，唤醒了进程，跳到1

5. 结束循环，select函数调用返回

### 1.2 实例理解select模型

理解select模型的关键在于理解fd_set，为说明方便，取fd_set长度为1字节，fd_set中的每一bit可以对应一个文件描述符fd。则1字节长的fd_set最大可以对应8个fd

1. 定义变量`fd_set set;` ` FD_ZERO(&set);` 则`set`用位表示是`0000,0000`
2. 若fd＝5,执行`FD_SET(fd,&set);`后`set`变为`0001,0000`(第5位置为1)
3. 若再加入fd＝2，fd=1,则`set`变为`0001,0011`
4. 执行`select(6,&set,0,0,0)`阻塞等待
5. 若fd=1,fd=2上都发生可读事件，则`select`返回，此时`set`变为`0000,0011`。**注意：没有事件发生的fd=5被清空**

总结可得

- **可监控的文件描述符个数取决与sizeof(fd_set)的值。我这边服务器上sizeof(fd_set)＝512，每bit表示一个文件描述符，则我服务器上支持的最大文件描述符是512\*8=4096。据说可调，另有说虽然可调，但调整上限受于编译内核时的变量值**
- **将fd加入select监控的`fd_set`的同时，还要再使用一个数据结构array保存放到select监控集中的fd，一是用于elect返回后，`array`作为源数据和`fd_set`进行`FD_ISSET`判断。二是`select`返回后会把以前加入的但并无事件发生的fd清空，则每次开始`select`前都要重新从array取得fd逐一加入，扫描array的同时取得fd最大值maxfd，用于`select`的第一个参数**

### 1.3 poll实现原理

poll的实现和select非常相似，只是描述fd集合的方式不同，poll使用pollfd结构而不是select的fd_set结构，其他的都差不多

### 1.4 缺点

- **每次调用select，都需要把fd集合从用户态拷贝到内核态，这个开销在fd很多时会很大**
- **同时每次调用select都需要在内核遍历传递进来的所有fd，这个开销在fd很多时也很大**
- **无论是用户空间还是内核空间随着每次`select`调用都需要维护一个用来存放大量fd的数据结构，这样会使得用户空间和内核空间在传递该结构时复制开销大**
- **select会修改传入的fd_set参数**
- **select返回后需要调用者遍历fd_set，使用`FD_ISSET`找出可读写的fd，线性效率，fd_set越大速度越慢**
- **单个进程可监视的fd数量被限制，即能监听端口的大小有限。一般来说这个数目和系统内存关系很大，具体数目可以cat/proc/sys/fs/file-max察看。32位机默认是1024个。64位机默认是2048**
- **对socket进行扫描时是线性扫描，即采用轮询的方法，效率较低：当套接字比较多的时候，每次select()都要通过遍历`FD_SET SIZE`个Socket来完成调度,不管哪个Socket是活跃的,都遍历一遍。这会浪费很多CPU时间。如果能给套接字注册某个回调函数，当他们活跃时，自动完成相关操作，那就避免了轮询，这正是epoll与kqueue做的。**
- **`select`每次调用都要把fd集合从用户态往内核态拷贝一次，并且要把current(当前进程)往设备等待队列中挂一次**

## 2.0 epoll



TODO



## 3.0 IO多路复用历史

**select, poll, epoll 都是I/O多路复用的具体的实现，之所以有这三个鬼存在，其实是他们出现是有先后顺序的。** 

### 3.1 select(1983)

I/O多路复用这个概念被提出来以后， select是第一个实现 (1983 左右在BSD里面实现的)。select 被实现以后，很快就暴露出了很多问题。 
- select 会修改传入的参数数组，这个对于一个需要调用很多次的函数，是非常不友好的。
-  select 如果任何一个socket(I/O stream)出现了数据，select 仅仅会返回，但是并不会告诉你是那个socket上有数据，于是你只能自己一个一个的找，10几个socket可能还好，要是几万的socket每次都找一遍，这个无谓的开销就颇有海天盛筵的豪气了。
-  select 只能监视1024个链接， 这个跟草榴没啥关系哦，linux 定义在头文件中的，参见FD_SETSIZE。
-  select 不是线程安全的，如果你把一个socket加入到select, 然后突然另外一个线程发现，尼玛，这个socket不用，要收回。对不起，这个select 不支持的，如果你丧心病狂的竟然关掉这个socket, select的标准行为是。。呃。。不可预测的， 这个可是写在文档中的哦.

“If a file descriptor being monitored by select() is closed in another thread, the result is unspecified”

### 3.2 poll(1997)

于是14年以后(1997年）一帮人又实现了poll, poll 修复了select的很多问题，比如 

- poll 去掉了1024个链接的限制，于是要多少链接呢， 主人你开心就好。
- poll 从设计上来说，不再修改传入数组，不过这个要看你的平台了，所以行走江湖，还是小心为妙。

其实拖14年那么久也不是效率问题， 而是那个时代的硬件实在太弱，一台服务器处理1千多个链接简直就是神一样的存在了，select很长段时间已经满足需求。

但是poll仍然不是线程安全的， 这就意味着，不管服务器有多强悍，你也只能在一个线程里面处理一组I/O流。你当然可以那多进程来配合了，不过这样你就有了多进程的各种问题。

### 3.3 epoll(2002)

于是5年以后, 在2002, 大神 Davide Libenzi 实现了epoll。epoll 可以说是I/O 多路复用最新的一个实现，epoll 修复了poll 和select绝大部分问题, 比如： 

- epoll 现在是线程安全的。 
- epoll 现在不仅告诉你socket组里面数据，还会告诉你具体哪个socket有数据，你不用自己去找了。

## 参考文献

- [IO 多路复用是什么意思？](https://www.zhihu.com/question/32163005)
- [IO多路复用之select总结](https://www.cnblogs.com/Anker/archive/2013/08/14/3258674.html)
- [IO多路复用和线程池哪个效率更高，更有优势？](https://www.zhihu.com/question/306267779)
- [select、poll、epoll之间的区别总结](https://www.cnblogs.com/Anker/p/3265058.html)
- [select模型的原理、优点、缺点](https://www.cnblogs.com/-zyj/p/5719923.html)
- [Linux编程之select](https://www.cnblogs.com/skyfsm/p/7079458.html)
- [select()/poll() 的内核实现](http://janfan.cn/chinese/2015/01/05/select-poll-impl-inside-the-kernel.html)
- [select和epoll 原理概述&优缺点比较](https://blog.csdn.net/jiange_zh/article/details/50811553)