# 惊群问题

惊群效应（thundering herd）是指多进程（多线程）在同时**阻塞**等待同一个事件的时候（**休眠状态**），如果等待的这个事件发生，那么他就会唤醒等待的所有进程（或者线程），但是最终却只能有一个进程（线程）获得这个事件的“控制权”，对该事件进行处理，而其他进程（线程）获取“控制权”失败，只能重新进入休眠状态，这种现象和性能浪费就叫做惊群效应。

**惊群效应造成的性能浪费：**

- Linux 内核对用户进程（线程）频繁地做无效的调度、上下文切换等使系统性能大打折扣。上下文切换（context switch）过高会导致 CPU 像个搬运工，频繁地在寄存器和运行队列之间奔波，更多的时间花在了进程（线程）切换，而不是在真正工作的进程（线程）上面。直接的消耗包括 CPU 寄存器要保存和加载（例如程序计数器）、系统调度器的代码需要执行。间接的消耗在于多核 cache 之间的共享数据
- 为了确保只有一个进程（线程）得到资源，需要对资源操作进行加锁保护，加大了系统的开销。目前一些常见的服务器软件有的是通过锁机制解决的，比如 `Nginx`（它的锁机制是默认开启的，可以关闭）；还有些认为惊群对系统性能影响不大，没有去处理，比如 `Lighttpd`

**下面会描述一下几个惊群问题出现的场景，以及对应的解决方案**

## 1. accept调用中的惊群

**在Linux2.6内核版本之前**，当多个线程中的`accept`函数同时监听同一个`listen_fd`的时候，如果此`listen_fd`变成可读，则系统会唤醒所有使用`accept`函数等待`listen_fd`的所有线程（或进程），但是最终只有一个线程可以`accept`调用返回成功，其他线程的`accept`函数调用返回`EAGAIN`错误，线程回到**堵塞状态**，这就是`accept`函数产生的惊群问题。

**在Linux 2.6版本中**，内核维护了一个等待队列，队列中的元素就是进程，非`exclusive`属性的元素会加在等待队列的前面，而`exclusive`属性的元素会加在等待队列的末尾，**当子进程调用阻塞`accept`时，该进程会被打上`WQ_FLAG_EXCLUSIVE`标志位**，从而成为`exclusive`属性的元素被加到等待队列中。当有`TCP`连接请求到达时，该等待队列会被遍历，非`exclusive`属性的进程会被不断地唤醒，等到出现第一个`exclusive`属性的进程，该进程会被唤醒，同时遍历结束。

只唤醒一个`exclusive`属性的进程，这也是`exclusive`的含义所在：互斥。

因为**阻塞**在accept上的进程都是互斥的（都是打上`WQ_FLAG_EXCLUSIVE`标志位），所以`TCP`连接请求到达时只会有一个进程被唤醒，从而解决了惊群效应。

**上面的方案解决的是多线程（多进程）堵塞调用`accept`时候的惊群问题**

## 2. epoll中的惊群问题

### 2.1 Nginx的锁方案

上面说到在Linux 2.6版本以后，`accept`调用本身所引起的惊群问题已经得到了解决，但是在`Nginx`中，`accept`是交给`epoll`机制来处理的（即`epoll`监听`listen_fd`），`epoll`的`accept`带来的惊群问题并没有得到解决（**`epoll_wait`本身并没有区别读事件是否来自于一个`listen_fd`的能力，所以所有监听这个事件的进程会被这个`epoll_wait`唤醒**），所以`Nginx`的`accept`惊群问题仍然需要定制一个自己的解决方案。（其实本来在使用`epoll`的时候，`listen_fd`就会设置成`non-blocking`，否则堵塞在`accept`上，就没有使用多路复用的意义了，所以上面的方案不适用于`epoll`）

`accept`锁就是`nginx`的解决方案，本质上这是一个跨进程的互斥锁，以这个互斥锁来保证只有一个进程具备监听`accept`事件的能力。

`accept`锁是一个跨进程锁，其在`Nginx`中是一个全局变量，声明如下

```c
ngx_shmtx_t           ngx_accept_mutex;
```

这是一个在`event`模块初始化时就分配好的锁，**放在一块进程间共享的内存中，以保证所有进程都能访问这一个实例**，其加锁解锁是借由`linux`的原子变量来做`CAS`，如果加锁失败则立即返回，是一种非阻塞的锁。加解锁代码如下：

```c
static ngx_inline ngx_uint_t                                                   
ngx_shmtx_trylock(ngx_shmtx_t *mtx)                                            
{                                                                              
    return (*mtx->lock == 0 && ngx_atomic_cmp_set(mtx->lock, 0, ngx_pid));     
}                                                                              
                                                                               
#define ngx_shmtx_lock(mtx)   ngx_spinlock((mtx)->lock, ngx_pid, 1024)         
                                                                               
#define ngx_shmtx_unlock(mtx) (void) ngx_atomic_cmp_set((mtx)->lock, ngx_pid, 0)

```

可以看出，调用`ngx_shmtx_trylock`失败后会立刻返回而不会阻塞。

`Nginx`使用`accept`锁保证同一时间只有一个进程监听`listen_fd`，以此解决使用`epoll`可能导致的惊群问题，具体实现伪代码如下：

```c
尝试获取accept锁
if 获取成功：
	在epoll中注册accept事件
else:
	在epoll中注销accept事件
处理所有事件
释放accept锁
```

对于`accept`锁的处理和`epoll`中注册和注销`accept`事件的的处理都是在`ngx_trylock_accept_mutex`中进行的。而这一系列过程则是在·nginx·主循环中反复调用的`void ngx_process_events_and_timers(ngx_cycle_t *cycle)`中进行。

也就是说，每轮事件的处理都会首先竞争`accept`锁，竞争成功则在`epoll`中注册`accept`事件，失败则注销`accept`事件，然后处理完事件之后，释放`accept`锁。由此保证同一时刻只有一个进程监听一个`listen_fd`，从而避免了惊群问题。

`accept`锁处理惊群问题的方案看起来似乎很美，但如果完全使用上述逻辑，就会有一个问题：如果服务器非常忙，有非常多事件要处理，那么“处理所有事件这一步”就会消耗非常长的时间，也就是说，某一个进程长时间占用`accept`锁，而又无暇处理新连接；其他进程又没有占用`accept`锁，同样无法处理新连接——至此，新连接就处于无人处理的状态，这对服务的实时性无疑是很要命的。

**为了解决这个问题，`Nginx`采用了将事件处理延后的方式**。即在`ngx_process_events`的处理中，仅仅将事件放入两个队列中：

```c
ngx_thread_volatile ngx_event_t  *ngx_posted_accept_events;                             
ngx_thread_volatile ngx_event_t  *ngx_posted_events; 
```

返回后先处理`ngx_posted_accept_events`，然后立刻释放`accept`锁，然后再慢慢处理其他事件。

那么具体是怎么实现的呢？其实就是在`static ngx_int_t ngx_epoll_process_events(ngx_cycle_t *cycle, ngx_msec_t timer, ngx_uint_t flags)`的`flags`参数中传入一个`NGX_POST_EVENTS`的标志位，处理事件时检查这个标志位即可。

这里只是避免了事件的消费对于accept锁的长期占用，那么万一epoll_wait本身占用的时间很长呢？这种事情也不是不可能发生。这方面的处理也很简单，epoll_wait本身是有超时时间的，限制住它的值就可以了，这个参数保存在`ngx_accept_mutex_delay`这个全局变量中。

[详细过程代码](https://juejin.im/post/5c0286b75188255275507013#heading-3)

如果进程没有拿到`accept`锁就会直接处理事件，不会放入队列

**`Nginx`在1.11.3版本之前通过配置`accept_mutex`默认为`on`支持`accept`锁解决方案。**

### 2.2 SO_REUSEPORT（socket 选项）

在Linux 3.9版本引入了`socket`套接字选项`SO_REUSEPORT`，Linux 3.9版本之前，一个进程通过`bind`一个三元组`（protocol, src_addr, src_port）`组合之后，其他进程不能再`bind`同样的三元组，Linux 3.9版本之后，凡是传入选项`SO_REUSEPORT`且为同一个用户下（安全考虑）的`socket`套接字都可以`bind`和监听同样的三元组。内核对这些监听相同三元组的`socket`套接字实行负载均衡，将`TCP`连接请求均匀地分配给这些`socket`套接字。

这里的负载均衡基本原理为：当有TCP连接请求到来时，用数据包的`（src_addr, src_port）`作为一个`hash`函数的输入，将`hash`后的结果对`SO_REUSEPORT`套接字的数量取模，得到一个索引，该索引指示的数组位置对应的套接字便是要处理连接请求的套接字。

**Nginx在1.9.1版本时支持了`reuseport`特征**，在Nginx配置中的`listen`指令的端口号之后增加`reuseport`参数后，`Nginx`的各个`worker`进程就有自己各自的监听套接字，这些监听套接字监听相同的源地址和端口号组合。

由于`reuseport`特征负载均衡在内核中的实现原理是按照套接字数量的`hash`，所以当`worker`的数量发生变化，性能会有下降，需要重新建立对应哈希关系

### 2.3 EPOLLEXCLUSIVE（epoll_ctl 选项）

在Linux 4.5版本引入`LLEXCLUSIVE`志位`inux 4.5, glibc 2.24）`子进程通过调用`poll_ctl`监听套接字与监听事件加入epfd时，会同时将`POLLEXCLUSIVE`志位显式传入，这使得子进程带上了`xclusive`性，也就是互斥属性，**跟Linux 2.6版本解决accept惊群效应的解决方案类似，不同的地方在于，当有监听事件发生时，唤醒的可能不止一个进程（见如下对EPOLLEXCLUSIVE标志位的官方文档说明中的“one or more”）**，这一定程度上缓解了惊群效应。

**Nginx在1.11.3版本时采用了该解决方案，所以从该版本开始，配置`accept_mutex`默认为`off`**

### 2.4 小结

`EPOLLEXCLUSIVE` 和 `SO_REUSEPORT `都是在内核层面将连接分到多个`worker`，解决了`epoll下`的惊群，`SO_REUSEPORT` 会更均衡一些，`EPOLLEXCLUSIVE`在压力不大的时候会导致连接总是在少数几个`worker`上。但是 `SO_REUSEPORT`在最坏的情况下会导致一个`worker`即使`Hang`了，`OS`也依然会派连接过去，这是非常致命的，所以4.5内核引入了 `EPOLLEXCLUSIVE`（总是给闲置等待队列的第一个`worker`派连接）

## 3. 线程池中的惊群问题

在实际应用程序开发中，为了避免线程的频繁创建销毁，我们一般建立线程池去并发处理，而线程池最经典的模型就是生产者-消费者模型，包含一个任务队列，当队列不为空的时候，线程池中的线程从任务队列中取出任务进行处理。一般使用**条件变量**进行处理，当我们往任务队列中放入任务时，需要唤醒等待的线程来处理任务，如果我们使用`C++`标准库中的函数`notify_all()`来唤醒线程，则会将所有的线程都唤醒，然后最终只有一个线程可以获得任务的处理权，其他线程在此陷入睡眠，因此产生惊群问题。

对于线程池中的惊群问题，我们需要分情况看待，有时候业务需求就是需要唤醒所有线程，那么这时候使用`notify_all()`唤醒所有线程就不能称为”惊群问题“，因为`CPU`并没有无谓消耗。而对于只需要唤醒一个线程的情况，我们需要使用`notify_one()`函数代替`notify_all()`只唤醒一个线程，从而避免惊群问题。

## 4. 总结
惊群问题本质是事件处理问题，解决惊群问题就是解决：如果一个事件实际只需要一个处理者，但是有多个处理者空闲时，如何高效率指派处理者的问题

从上面的几个解决方案，可以总结一下几个做法：

1. 认为惊群对系统性能影响不大，不做处理
2. 通过队列或负载均衡的方式，选出一个处理者
3. 通过竞争全局锁，选出一个处理者

## 参考文献

- [什么是惊群，如何有效避免惊群?](https://www.zhihu.com/question/22756773/answer/545048210)
- [再谈Linux epoll惊群问题的原因和解决方案](https://blog.csdn.net/dog250/article/details/80837278)
- [Nginx accept锁的机制和实现](https://juejin.im/post/5c0286b75188255275507013)
- [Liunx与Nginx中的惊群效应](https://zhuanlan.zhihu.com/p/88181936)
- [关于网络编程中惊群效应那点事儿](https://zhuanlan.zhihu.com/p/60966989)
- [SO_REUSEPORT、EPOLLEXCLUSIVE都用来解决epoll的惊群，侧重点跟区别是什么?](https://www.zhihu.com/question/290390092)
- [C++性能榨汁机之惊群问题](https://zhuanlan.zhihu.com/p/37861062)
