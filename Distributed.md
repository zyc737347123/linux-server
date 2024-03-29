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

解决方案：逻辑时钟，向量时钟，[混合逻辑时钟](http://yang.observer/2020/12/16/hlc/)

Ref：

- https://writings.sh/post/logical-clocks
- https://yang.observer/2020/07/26/time-lamport-logical-time/
- https://blog.xiaohansong.com/lamport-logic-clock.html


## 6. Leader election

问题场景：狭义拜占庭问题（假设将军中没有叛军，信使的信息可靠但有可能被暗杀的情况下，将军们如何达成一致性决定？）

解决方案：Raft，Bully，ZooKeeper Atomic Broadcast

Ref:

- https://zhuanlan.zhihu.com/p/85680181
- https://www.cnblogs.com/moonyaoo/p/12952580.html
- https://catkang.github.io/2017/06/30/raft-subproblem.html

## 7. Quantum Byzantine agreement（量子拜占庭协议）

问题场景：[检测的拜占庭协议](http://www.infocomm-journal.com/cjnis/article/2016/2096-109x/2096-109x-2-11-00030.shtml)

解决方案：每个将军都有不被其他将军所知的数字列表，并且自己拥有的数字列表与其他将军手中的列表之间有合适的关联关系。因此，解决拜占庭问题可以简化为解决生成和安全分发这些列表的问题。利用量子协议就能检测分发的安全性

## 8. Race condition

Handling race conditions in distributed systems is tricky. It all depends on how you want your system to behave.

Is it alright to have eventual consistency or strong consistency is a must?
Do you want your system to be more available or consistent if a resource is unavailable?

Some of the ways to handle race conditions are:

1. Distributed locks: But remember, pessimistic locking down a resource will have a significant impact on the latency of your system.
2. Sharding: For an instance you have a counter variable which multiple threads are updating every second. Instead of pessimistic locking down that variable.
Shard it. There will be multiple copies of that variable across various nodes. Individual threads will update the variable & eventually all the updates across nodes will be summed up.
3. Implementing a high performance queue: Queue all the requests for a resource. Let the requests access the resource in a first in first out fashion.

## 9. Self-stabilization

描述：Self-stabilization is a concept of fault-tolerance in distributed systems. Given any initial state, a self-stabilizing distributed system will end up in a correct state in a finite number of execution steps.

A system is self-stabilizing if and only if:

1. Starting from any state, it is guaranteed that the system will eventually reach a correct state (convergence).
2. Given that the system is in a correct state, it is guaranteed to stay in a correct state, provided that no fault happens (closure).

A system is said to be randomized self-stabilizing if and only if it is self-stabilizing and the expected number of rounds needed to reach a correct state is bounded by some constant k.


## 10. Distributed serializability

描述：Distributed serializability is the serializability of a schedule of a transactional distributed system (e.g., a distributed database system)；Distributed serializability is a major goal of [distributed concurrency control](https://en.wikipedia.org/wiki/Distributed_concurrency_control) for correctness

问题背景：全局事务，多个本地事务一起成功或一起失败

解决方案：原子协议，Distributed transactions imply a need for an [atomic commit](https://en.wikipedia.org/wiki/Atomic_commit) protocol to reach consensus among its local sub-transactions on whether to commit or abort.

