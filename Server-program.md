# 服务器编程模型


- 单线程 Reactor：nonblocking IO + IO multiplexing

  - libevent
  - lighttpd
  - Tomcat
- 多线程 Reactor：non-blocking IO + one loop per thread

  - 依赖线程安全队列，去分发task
  - **每个 connection/acceptor 都会注册到某个 Reactor 上，程序里有多个 Reactor，每个线程至多有一个 Reactor**
- 多进程 Reactor：nonblocking IO + IO multiplexing

  - Nginx（异步非堵塞），**nginx的异步是指epoll的异步机制，即内部探测socket事件发生是通过消息通知方式**
- 多进程通信：tcp socket，共享内存+信号量（实现一个进程队列）
- 多线程通信：线程安全的队列，无锁队列CAS
- IO多路复用是减少IO等待时的CPU空闲，不能提升计算密集型的性能
- 对于计算密集型，可以用线程池+队列

