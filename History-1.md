# 前后端分离

## 1.0 从本质上看前后端分离

### 1.1 序

康威定律：

> Organizations which design systems are constrained to produce designs which are copies of the communication structures of these organizations. - Melvin Conway(1967)
>
> 任何设计系统的组织，必然会产生以下设计结果：即其结构就是该组织沟通结构的写照
>
> 即系统设计本质上反映了企业的组织机构

**所谓架构设计，实际上是如何合理的对现实的人力架构进行系统映射，以便最大限度的压榨整个公司（组织）的运行效率（万恶的资本家）**

### 1.2 分离前

先看看一个 Web 系统，在前后端不分离时架构设计是什么样的:

![](https://pic3.zhimg.com/80/v2-1a16914020e75833279d33c873d74eb1_hd.jpg)

用户在浏览器上发送请求，服务器端接收到请求，根据 Header 中的 token 进行用户鉴权，从数据库取出数据，处理后将结果数据填入 HTML 模板，返回给浏览器，浏览器将 HTML 展现给用户

**这样的架构有什么问题？**

问题出现在图右边那位全寨（栈）开发人员！

他既要会数据库开发（SQL）、又要会服务器端开发（Java、C#），又要会前端开发（HTML、CSS、JS）。现实告诉我们，百样通往往不如一样精，什么都会的人往往哪一样都干不好。**是否可以按照前端后端进行人员职责区分呢？如果进行职责区分，分成前端开发和后端开发，但由于程序全在一个服务里，不同职责开发人员彼此间的交流、代码管理就会成为一个大问题，也就是交流成本膨胀的问题了**。

**那么，有什么办法可以让前端和后端开发只做自己擅长的事情，并尽量减少交流成本呢？**

### 1.3 分离后

为了解决上面的问题，前后端分离应运而生。**记住，分离的是人员职责，人员职责分离，所以架构也发生变化了**

![](https://pic4.zhimg.com/80/v2-889ced410c2319dbed2fe21c2da6e344_hd.jpg)

现在 Web 服务器不再处理任何业务，它接收到请求后，经过转换（路由和数据初步处理），发送给各个相关后端服务器，将各个后端服务器返回的，处理过的业务数据填入 HTML 模板，最后发送给浏览器。Web 服务器和后端服务器间，可以选用任何你觉得合适的通信手段，可以是 REST，可以是 RPC，选用什么样的通信手段，这是另一个议题了。

这样，前端人员和后端人员约定好接口后，前端人员彻底不用再关心业务处理是怎么回事，他只需要把界面做好就可以了，后端人员也不用再关心前端界面是什么样的，他只需要做好业务逻辑处理即可。服务的切离，代码管理，服务部署也都独立出来分别管理，系统的灵活性也获得了极大的提升。

### 1.4 总结

**总结，任何系统架构设计，实际上是对组织结构在系统上进行映射，前后端分离，就是在对前端开发人员和后端开发人员的工作进行解耦，尽量减少他她们之间的交流成本，帮助他她们更能专注于自己擅长的工作**。

## 2.0 从技术实现看前后端分离

### 2.1 完全不分离

早期主要使用MVC框架，JSP + Servlet 的结构图如下：

![](https://ss.csdn.net/p?https://mmbiz.qpic.cn/mmbiz_jpg/UtWdDgynLdaZrcL8lQlic6n0OHVBahakCeDctOD5ysRfstQKJKvvkqGjA83HQojfODSxWENHghzppc3l9tBjyAw/640?wx_fmt=jpeg)

![](https://pic4.zhimg.com/80/v2-d81b101ed82efc1bbfb918f03ff3f452_hd.jpg)

大致就是所有的请求都被发送给作为`Controller`的`Servlet`，它接受请求，并根据请求信息将它们分发给适当的`View`(`JSP`)来响应。同时，`Servlet`还根据`JSP`的需求生成`JavaBeans`(`Model`)的实例并输出给`JSP`环境。`JSP`可以通过直接调用方法或使用`UseBean`的自定义标签得到`JavaBeans`(`Model`)中的数据。需要说明的是，这个`View`还可以采用 Velocity、Freemaker 等模板引擎。使用了这些模板引擎，可以使得开发过程中的人员分工更加明确，还能提高开发效率。

### 2.2 半分离

前后端半分离，前端负责开发页面，通过接口（`Ajax`）获取数据，采用`Dom`操作对页面进行数据绑定，最终是由前端把页面渲染出来。这也就是`Ajax`与`SPA`应用（单页应用）结合的方式，其结构图如下：

![](https://ss.csdn.net/p?https://mmbiz.qpic.cn/mmbiz_jpg/UtWdDgynLdaZrcL8lQlic6n0OHVBahakCFnq4hJXa86V5mGQoIB3pASSSlWzoSJqIRWqV7wwo98ZWalSEe1wWsg/640?wx_fmt=jpeg)

后端提供的接口是统一的，没有区分native和web端，所以web端的工作流程如下：
1. 发起页面请求，加载基本资源，如CSS，JS等
2. 发起一个Ajax请求再到服务端请求数据，同时展示loading
3. 得到json格式的数据后再根据逻辑选择模板，渲染出DOM字符串
4. 将DOM字符串插入页面中web view渲染出DOM结构

这些步骤都是在终端设备中串行执行的，也就是说Web应用的速度和终端设备硬件性能有很强的相关性，终端设备的硬件性能会很大程度影响用户体验

为什么说是半分离的？因为不是所有页面都是单页面应用，在多页面应用的情况下，前端没有掌握`Controller`层，前端还是需要跟后端讨论，我们这个页面是要同步输出呢，还是异步json渲染呢？而且，即使在这一时期，通常也是一个工程师搞定前后端所有工作。因此，在这一阶段，只能算半分离

在这种架构下，还是存在明显的弊端的。最明显的有如下几点：

- JS存在大量冗余，在业务复杂的情况下，页面的渲染部分的代码，非常复杂
- 在Json返回的数据量比较大的情况下，渲染的十分缓慢，会出现页面卡顿的情况
- SEO（ Search Engine Optimization，即搜索引擎优化）非常不方便，由于搜索引擎的爬虫无法爬下JS异步渲染的数据，导致这样的页面，SEO会存在一定的问题
- 资源消耗严重，在业务复杂的情况下，一个页面可能要发起多次HTTP请求才能将页面渲染完毕。可能有人不服，觉得PC端建立多次HTTP请求也没啥。那你考虑过移动端么，知道移动端建立一次HTTP请求需要消耗多少资源？

### 2.3 分离

在前后端彻底分离这一时期，前端的范围被扩展，`Controller`层也被认为属于前端的一部分：

- 前端：负责`View`和`Controller`层
- 后端：只负责`Model`层，业务/数据处理等

可是服务端人员对前端HTML结构不熟悉，前端也不懂后台代码呀，`Controller`层如何实现呢？这就是node.js的妙用了，node.js适合运用在高并发、I/O密集、少量业务逻辑的场景。最重要的一点是，前端不用再学一门其他的语言了，对前端来说，上手度大大提高

用NodeJs来作为桥梁架接服务器端API输出的JSON。后端出于性能和别的原因，提供的接口所返回的数据格式也许不太适合前端直接使用，前端所需的排序功能、筛选功能，以及到了`View`层的页面展现，也许都需要对后端接口所返回的数据进行二次处理。这些处理虽可以放在前端来进行，但数据量一大便会浪费浏览器性能。因而现今，增加Node中间层便是一种良好的解决方案

![](https://img-blog.csdn.net/20180811200234841?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L2Z1emhvbmdtaW4wNQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

浏览器(webview)不再直接请求后端的API，而是：
1. 浏览器请求服务器端的NodeJS
2. NodeJS再发起HTTP去请求后端的model
3. `Model`层输出JSON给NodeJS
4. NodeJS收到JSON后再渲染出HTML页面
5. NodeJS直接将HTML页面flush到浏览器

这样，浏览器得到的就是普通的HTML页面，而不用再发Ajax去请求服务器了。

![](https://img-blog.csdn.net/20180811205658171?watermark/2/text/aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L2Z1emhvbmdtaW4wNQ==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

## Q&A

1. 前后端分离是说浏览器和后端服务分离吗？

   不是，前后端分离里的前端不是浏览器，指的是生成 HTML 的那个服务，它可以是一个仅仅生成 HTML 的 Web 服务器，也可以是在浏览器中通过 JS 动态生成 HTML 的 单页应用。实践中，有实力的团队往往在实现前后端分离里时，前端选用 node 服务器，后端选用 C#、Java 等（排名不分先后）

2. 前后端分离是种技术吗？

   不是，前后端分离是种架构模式，或者说是最佳实践。所谓模式就是大家这么用了觉得不错，你可以直接抄来用的固定套路。


## 参考文献

- [Conway's law 康威定律](https://www.cnblogs.com/ghj1976/p/5703462.html)
- [到底什么是前后端分离?](https://www.zhihu.com/question/304180174)
- [前后端分离架构概述](https://blog.csdn.net/fuzhongmin05/article/details/81591072)
- [如何理解Web应用程序的MVC模型?](https://www.zhihu.com/question/27897315)
- [SPA和MPA](https://www.jianshu.com/p/a02eb15d2d70)
- [Swagger - 前后端分离后的契约](https://www.cnblogs.com/whitewolf/p/4686154.html)
- [基于Swagger的前后端协同开发解决方案-SMock](https://juejin.im/entry/5bf3927d6fb9a049f361b5c2)

