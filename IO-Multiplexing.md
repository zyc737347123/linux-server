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

5. __pollwait的主要工作就是把**current（当前进程）挂到设备的等待队列中**，不同的设备有不同的等待队列，对于tcp_poll来说，其等待队列是sk->sk_sleep（**注意把进程挂到等待队列中并不代表进程已经睡眠了**）。在设备收到一条消息（网络设备）或填写完文件数据（磁盘设备）后，会唤醒设备等待队列上睡眠的进程，这时current便被唤醒了

6. poll方法返回时会返回一个描述读写操作是否就绪的mask掩码，根据这个mask掩码给fd_set赋值

7. 如果遍历完所有的fd，还没有返回一个可读写的mask掩码，则会调用schedule_timeout令调用select的进程（也就是current）进入睡眠。当设备驱动发生自身资源可读写后，会唤醒其等待队列上睡眠的进程。如果超过一定的超时时间（schedule_timeout指定），还是没设备唤醒current进程，则调用select的进程会重新被唤醒获得CPU，进而重新遍历fd，判断有没有就绪的fd，**此时无论有无就绪fd，select都回返回**

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
- **将fd加入select监控的`fd_set`的同时，还要再使用一个数据结构array保存放到select监控集合中的fd，一是用于select返回后，`array`作为源数据和`fd_set`进行`FD_ISSET`判断。二是`select`返回后会把以前加入的但并无事件发生的fd清空，则每次开始`select`前都要重新从array取得fd逐一加入，扫描array的同时取得fd最大值maxfd，用于`select`的第一个参数**

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

### 2.1 实现原理（一）

要理解epoll的实现原理，有三个关键要素：**mmap，红黑树，链表**

为了解决select频繁在内核和用户空间之间拷贝数据(**fd_set**)的缺点，epoll通过**mmap**令用户进程和内核共用同一块内存，使得这块内存对用户进程和内核都可见，epoll将数据(**struct epoll_event, fd**)都存储在这块内存，减少用户态和内核态之间数据交换，内核可以直接看到epoll监听的事件和句柄，数据只复制一次（调用`EPOLL_CTL_ADD`时）

**mmap**出来的内存如何存储epoll的数据(**struct epoll_event, fd**)，必然需要一套数据结构。epoll在实现上使用**红黑树**去存储所有监听的句柄（从实现上来说，**红黑树**的每个节点是`struct epitem.rbn`），当添加、修改、删除epoll上的监听句柄时(`epoll_ctl`)，都是在红黑树上处理，红黑树插入、查找、删除性能都比较好，时间复杂度`O(logn)`

通过`epoll_ctl`函数添加进来的事件都会被放在红黑树的某个节点内，所以，重复添加是没有用的。当把事件添加进来的时候时候会完成关键的一步，那就是该监听事件与相应的设备（网卡）驱动程序建立回调关系，当监听的事件发生后，设备驱动就会调用这个回调函数，该回调函数在内核中被称为：`ep_poll_callback`**这个回调函数其实就是把这个事件添加到`rdllist`这个双向链表中**。一旦有监听事件发生，epoll就会将该事件添加到双向链表`rdllist`中。那么当我们调用`epoll_wait`时，`epoll_wait`只需要检查rdlist双向链表中是否为空，若不为则链表的元素即为发生的监听事件，效率非常可观。这里也只需要将发生的事件复制到用户态中即可，数据量比较小。

```C
struct eventpoll
{
    spin_lock_t lock;            //对本数据结构的访问
    struct mutex mtx;            //防止使用时被删除
    wait_queue_head_t wq;        //sys_epoll_wait() 使用的等待队列
    wait_queue_head_t poll_wait; //file->poll()使用的等待队列
    struct list_head rdllist;    //事件满足条件的链表
    struct rb_root rbr;          //用于管理所有fd的红黑树
    struct epitem *ovflist;      //将事件到达的fd进行链接起来发送至用户空间
}
```
```C
struct epitem
{
    struct rb_node rbn;            //用于主结构管理的红黑树
    struct list_head rdllink;       //事件就绪队列
    struct epitem *next;           //用于主结构体中的链表
    struct epoll_filefd ffd;         //每个fd生成的一个结构
    int nwait;                 
    struct list_head pwqlist;     //poll等待队列
    struct eventpoll *ep;          //该项属于哪个主结构体
    struct list_head fllink;         //链接fd对应的file链表
    struct epoll_event event;  //注册的感兴趣的事件,也就是用户空间的epoll_event
}
```

```C
typedef union epoll_data {
    void        *ptr;
    int          fd;
    __uint32_t   u32;
    __uint64_t   u64;
} epoll_data_t;
struct epoll_event {
    __uint32_t   events; /* Epoll events */
    epoll_data_t data;   /* User data variable */
};
```

### 2.2 实现原理（二）

![](https://img-blog.csdn.net/20180629080449174?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L2RvZzI1MA==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

**epoll的工作过程：**

1. `epoll_create`: 创建 epollevent 结构体并初始化相关数据结构。创建 fd 并绑定到 epoll 对象上
2. `epoll_ctl`: **从用户空间拷贝** event 到内核空间，创建`epitem`并初始化，将要监听的 fd 绑定到 epitem
3. 通过调用监听 fd 的 poll 回调函数，设置等待队列的 entry 调用函数为`ep_poll_callback`，并将 entry 插入到监听 fd 的 “睡眠队列” 上
4. `epoll_ctl`的最后将 epitem 插入到第一步创建的 epollevent 的红黑树中
5. `epoll_wait`: 如果 ep 的就绪链表为空，**根据当前进程初始化一个等待 entry 并插入到 ep fd的等待队列中**。设置当前进程为`TASK_INTERRUPTIBLE`即可被中断唤醒，然后进入” 睡眠” 状态，让出 CPU
6. 当监听的 fd 有对应事件发生，则唤醒相关文件句柄睡眠队列的 entry，并调用其回调，即`ep_poll_callback`
7. 将发生事件的 epitem 加入到 ep 的 “就绪链表” 中，唤醒阻塞在 epoll_wait 系统调用的 task 去处理。
8. `epoll_wait`被调度继续执行，判断就绪链表中有就绪的 item，会调用`ep_send_events`向用户态上报事件，即那些 epoll_wait 返回后能获取的事件
9. `ep_send_events`会调用传入的`ep_send_events_proc`函数，真正执行将就绪事件从内核空间拷贝到用户空间的操作
10. 拷贝后会判断对应事件是`ET`还是`LT`模式，如果是 LT 则无论如何都会将 epi 重新加回到 “就绪链表”，等待下次`epoll_wait`重新再调用监听 fd 的 poll 以确认是否仍然有未处理的事件
11. `ep_send_events_proc`返回后，在`ep_send_events`中会判断，如果 “就绪链表” 上仍有未处理的 epi，且有进程阻塞在 epoll 句柄的睡眠队列，则唤醒它！(**这就是 LT 惊群的根源**)

**简约版：**

1. 创建epoll句柄，初始化相关数据结构
2. 为epoll句柄添加文件句柄，注册睡眠entry的回调
3. 事件发生，唤醒相关文件句柄睡眠队列的entry，调用其回调
4. 唤醒epoll睡眠队列的task，搜集并上报数据

### 2.3 实现原理（三）

![](http://blog.chinaunix.net/attachment/201405/26/28541347_140111501437dD.jpg)

**这里主要讲ET和LT模式的实现区别：**

红线（ET模式）：fd状态改变才会触发：

- 当buffer由不可读状态变为可读的时候，即由空变为不空的时候

- 当有新数据到达时，即buffer中的待读内容变多的时候

- 当buffer由不可写变为可写的时候，即由满状态变为不满状态的时候

- 当有旧数据被发送走时，即buffer中待写的内容变少得时候

蓝线（LT模式）：fd的evnets中有相应的事件被置位

- buffer中有数据可读的时候，即buffer不空的时候fd的events的可读为就置1
- buffer中有空间可写的时候，即buffer不满的时候fd的events的可写位就置1

**红线是 事件驱动 被动触发，蓝线是 函数查询 主动触发**

### 2.4 select 和 epoll

epoll是对select改进，一些select上的问题都在epoll得到解决：

1. select实现需要调用者不断轮询所有fd集合，直到设备就绪，期间可能要睡眠和唤醒多次交替。而epoll其实也需要调用epoll_wait不断轮询就绪链表，期间也可能多次睡眠和唤醒交替，但是它是设备就绪时，调用回调函数，把就绪fd放入就绪链表中，并唤醒在epoll_wait中进入睡眠的进程。虽然都要睡眠和唤醒交替，但是select在“醒着”的时候要遍历整个fd集合，而epoll在“醒着”的时候只要判断一下就绪链表是否为空就行了，这节省了大量的CPU时间。这就是回调机制带来的性能提升

2. select每次调用都要把fd集合从用户态往内核态拷贝一次，并且要把current进程往设备等待队列中挂一次，而epoll只要一次拷贝，而且把current进程往等待队列上挂也只挂一次（在epoll_wait的开始，注意这里的等待队列并不是设备等待队列，只是一个epoll内部定义的等待队列），这也能节省不少的开销

3. **epoll最主要解决的问题是：在高并发，且任一事件只有少数socket是活跃的情况下select的性能缺陷问题。如果在并发量低，socket都比较活跃的情况下，select就不见得比epoll慢了(因为epoll实现中有大量回调的操作)**

### 2.5 select、poll、epoll区别

1. **支持一个进程所能打开的最大连接数**
![](https://static.oschina.net/uploads/img/201604/21145832_RVDK.png)

2. **监听句柄剧增后带来的IO效率问题**
![](https://static.oschina.net/uploads/img/201604/21145942_TmnB.png)

3. **监听事件元数据的传递方式**
![](https://static.oschina.net/uploads/img/201604/21150044_PgJT.png)

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
- [IO多路复用和线程池哪个效率更高，更有优势？](https://www.zhihu.com/question/306267779)
- [select、poll、epoll之间的区别总结](https://www.cnblogs.com/Anker/p/3265058.html)
- [select模型的原理、优点、缺点](https://www.cnblogs.com/-zyj/p/5719923.html)
- [Linux编程之select](https://www.cnblogs.com/skyfsm/p/7079458.html)
- [select()/poll() 的内核实现](http://janfan.cn/chinese/2015/01/05/select-poll-impl-inside-the-kernel.html)
- [select和epoll 原理概述&优缺点比较](https://blog.csdn.net/jiange_zh/article/details/50811553)
- [Linux下的I/O复用与epoll详解](https://www.cnblogs.com/lojunren/p/3856290.html)
- [Liunx epoll 详解](http://blog.lucode.net/linux/epoll-tutorial.html)
- [再谈Linux epoll惊群问题的原因和解决方案](https://blog.csdn.net/dog250/article/details/80837278)
- [彻底学会使用epoll(一)——ET模式实现分析](http://blog.chinaunix.net/uid-28541347-id-4273856.html)
- [epoll 深入学习](https://blog.leosocy.top/epoll%E6%B7%B1%E5%85%A5%E5%AD%A6%E4%B9%A0/)
- [聊聊IO多路复用之select、poll、epoll详解](https://www.jianshu.com/p/dfd940e7fca2)