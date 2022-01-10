# 分布式

## 1. Edit conflic

描述：The conflict occurs when an editor gets a copy of a shared document file, changes the copy, and attempts to save the changes to the original file, which has been altered by another editor after the copy was obtained.

---------------------

问题场景：分布式版本控制系统(git,Mercurial)，分支冲突

解决方案：git 是分布式的文件版本控制系统，在分布式环境中时间是不可靠的，git是靠`三路合并算法`进行合并的

问题场景：用户余额修改，并发修改

解决方案：锁 or CAS

Ref:

- https://juejin.cn/post/7004643157279244325
- https://zhuanlan.zhihu.com/p/149287658

## 2. Embarrassingly parallel（完全并行）

描述：In [parallel computing](https://en.wikipedia.org/wiki/Parallel_computing), an **embarrassingly parallel** workload or problem (also called **embarrassingly parallelizable**, **perfectly parallel**, **delightfully parallel** or **pleasingly parallel**) is one where little or no effort is needed to separate the problem into a number of parallel tasks.[[1\]](https://en.wikipedia.org/wiki/Embarrassingly_parallel#cite_note-1) This is often the case where there is little or no dependency or need for communication between those parallel tasks, or for results between them.

A common example of an embarrassingly parallel problem is 3D video rendering handled by a [graphics processing unit](https://en.wikipedia.org/wiki/Graphics_processing_unit), where each frame (forward method) or pixel ([ray tracing](https://en.wikipedia.org/wiki/Ray_tracing_(graphics)) method) can be handled with no interdependency.[[3\]](https://en.wikipedia.org/wiki/Embarrassingly_parallel#cite_note-ChalmersReinhard2011-3) Some forms of [password cracking](https://en.wikipedia.org/wiki/Password_cracking) are another embarrassingly parallel task that is easily distributed on [central processing units](https://en.wikipedia.org/wiki/Central_processing_unit), [CPU cores](https://en.wikipedia.org/wiki/CPU_core), or clusters.

## 3. Failure semantics（错误语义）
A list of types of errors that can occur:

- An omission error is when one or more responses fails. 

- A crash error is when nothing happens. A crash is a special case of omission when all responses fail.
- A Timing error is when one or more responses arrive outside the time interval specified. Timing errors can be early or late. An omission error is a timing error when a response has infinite timing error.
- An arbitrary error is any error, (i.e. a wrong value or a timing error).
- When a client uses a server it can cope with different type errors from the server.
  - If it can manage a crash at the server it is said to assume the server to have crash failure semantics.
  - If it can manage a service omission it is said to assume the server to have omission failure semantics.
- Failure semantics are the type of errors that are expected to appear.
Should another type of error appear it will lead to a service failure because it cannot be managed.


## 4. Fallacies of distributed computing（分布式计算语境中的谬论）

描述：The fallacies of distributed computing are a set of assertions made by L Peter Deutsch and others at Sun Microsystems describing false assumptions that programmers new to distributed applications invariably make.

谬论：
1. The network is reliable;
2. Latency is zero;
3. Bandwidth is infinite;
4. The network is secure;
5. Topology doesn't change;
6. There is one administrator;
7. Transport cost is zero;
8. The network is homogeneous; ps：[Heterogeneous network](https://en.wikipedia.org/wiki/Heterogeneous_network)

## 5. Happened-before （事件顺序，因果一致性）
描述：In computer science, the happened-before relation is a relation between the result of two events, such that if one event should happen before another event, the result must reflect that, even if those events are in reality executed out of order (usually to optimize program flow). This involves ordering events based on the potential causal relationship of pairs of events in a concurrent system, especially asynchronous distributed systems. It was formulated by Leslie Lamport.[1]

---------------------

问题场景：

![02](/Users/yongchang.zhang/Downloads/02.jpg)
