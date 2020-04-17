# HTTP笔记

1. HTTP的body
   1. 数据类型与编码
      1. 数据类型：**MIME type**用来标记body的数据类型
      2. 编码类型：告知数据所使用的编码方式，**Encoding type**
   2. 对应的header头字段
      1. Accept：标记的是客户端可理解的**MIME type**，用`,`分隔
      2. Content-Type：告知body的数据的**MIME type**
   3. 语音类型和编码
      1. 请求头里一般只会有 Accept-Language 字段，响应头里只会有 Content-Type 字段
2. HTTP传输大文件
   1. 数据压缩
   2. 分块传输
      1. “Transfer-Encoding: chunked”和“Content-Length”这两个字段是互斥的，也就是说响应报文里这两个字段不能同时出现，一个响应报文的传输要么是长度已知，要么是长度未知（chunked）
      2. chunked主要用于流式数据，一开始不能知道准确的大小 
      3. 分块传输允许末尾有”拖尾数据“，由头字段Trailer指定，可以用来传输`Content-MD5: `（再了解一下）
      4. 大文件通常会分成小块多次传输，但如何分块、分多少协议不会管，需要通信两端自己定 
   3. 范围请求
      1. 416，意思是“你的范围请求有误，我无法处理，请再检查一下”
      2. 状态码“206 Partial Content”，和 200 的意思差不多，但表示 body 只是原数据的一部分
      3. 对于大文件通常都是range请求 
   4. 多段数据
      1. **分块是传输数据块的方式（Encoding），而multipart是数据的形状（类型Content-Type）**
      2. “multipart/byteranges”，表示报文的 body 是由多段字节序列组成的，并且还要用一个参数“boundary=xxx”给出段之间的分隔标记
3. HTTP的连接管理
   1. 连接相关的头字段：Connection ： keep-alive  、close 、upgrade（配合state code101使用，表示协议升级）
   2. 队头堵塞：“队头阻塞”与短连接和长连接无关，而是由 HTTP 基本的“请求 - 应答”模型所导致的
   3. HTTP/1.1 默认启用长连接，在一个连接上收发多个请求响应，提高了传输效率
   4. 过多的长连接会占用服务器资源，所以服务器会用一些策略有选择地关闭长连接 ：keepalive_timeout和keepalive_requests
   5. 服务器端设置最大连接数，当连接达到上限之后拒绝连接，也可以采用限流措施 
   6. 客户端设置响应超时后重试次数，当次数达到上限后关闭连接
   7. 在长连接中一个重要问题是去和正确的区分多个报文的开始和结束，需要使用`Content-Length`头明确body的长度，正确标记报文结束。如果是流式数据，必须使用chunked