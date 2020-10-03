# MySQL慢查询

1. 思路：https://tech.meituan.com/2014/06/30/mysql-index.html
   1. 一般的慢查询可以在应用层就感知到，可以对关键查询做应用层监控
   2. 大部分的读优化都是基于局部预读性原理
2. Explain详解：https://www.cnblogs.com/tufujie/p/9413852.html
3. 慢查询具体配置：https://www.cnblogs.com/kerrycode/p/5593204.HTML
   1. 一般是不会开启慢日志记录功能，会对读写性能有影响，一般是要做数据库性能调优才开启的