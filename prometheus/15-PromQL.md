# 1. 向量

## 1.1 瞬时向量

当前最新的值，实时数据，通常用于报警、实时监控

请求示例：`http://172.16.7.181:30090/api/v1/query?query=ssCpuIdle&time=1752029987.793`

响应数据：`resultType=vector`

```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {
          "__name__": "ssCpuIdle",
          "device_type": "fisec_cipher",
          "instance": "172.16.8.184",
          "job": "snmp",
          "safe_zone": "I",
          "sysName": "localhost.localdomain"
        },
        "value": [
          1752029987.793,
          "93"
        ]
      },
      ...
    ]
  }
}
```



## 1.2 区间向量

一段时间内的所有样本值，多用于数据分析、预测

区间范围定义：[N[s|m|h|d|w|y]]

示例：30分钟内，CPU空闲率  `ssCpuIdle[30m]`

请求示例：`http://172.16.7.181:30090/api/v1/query?query=ssCpuIdle%5B30m%5D&time=1752030030.58`

响应数据：`resultType=matrix`

```json
{
    "status": "success",
    "data": {
        "resultType": "matrix",
        "result": [
            {
                "metric": {
                    "__name__": "ssCpuIdle",
                    "device_type": "fisec_cipher",
                    "instance": "172.16.8.184",
                    "job": "snmp",
                    "safe_zone": "I",
                    "sysName": "localhost.localdomain"
                },
                "values": [
                    [
                        1752028322.04,
                        "92"
                    ],
                    [
                        1752028622.04,
                        "92"
                    ],
                    [
                        1752028922.04,
                        "94"
                    ],
                    [
                        1752029222.04,
                        "95"
                    ],
                    [
                        1752029522.04,
                        "94"
                    ],
                    [
                        1752029822.04,
                        "93"
                    ]
                ]
            },
            ...
        ]
    }
}
```



另一个接口：`http://172.16.7.181:30090/api/v1/query_range?query=ssCpuIdle&start=1752029086.888&end=1752030886.888&step=7`

参数说明：

- start：开始时间
- end：结束时间
- step：数据查询步进(密度)，这里是7s，所以返回的values数组非常大

```json
{
    "status": "success",
    "data": {
        "resultType": "matrix",
        "result": [
            {
                "metric": {
                    "__name__": "ssCpuIdle",
                    "device_type": "fisec_cipher",
                    "instance": "172.16.8.184",
                    "job": "snmp",
                    "safe_zone": "I",
                    "sysName": "localhost.localdomain"
                },
                "values": [
                    [
                        1752029086.888,
                        "94"
                    ],
                    [
                        1752029093.888,
                        "94"
                    ],
                    [
                        1752029100.888,
                        "94"
                    ],
                    ...
                ]
            },
            ...
        ]
    }
}
```



# 2. 基本操作

## 2.1 查询时间序列

```text
# 查询指标的所有时间序列
http_requests_total
http_requests_total{}

# 携带过滤条件
http_requests_total{code="401"}

# 排除条件
http_requests_total{instance!="localhost:9090"}

# 正则条件
http_requests_total{environment=~"staging|testing|development", method!="GET"}
```

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/promql-basic.png)



## 2.2 范围查询

```text
http_requests_total{code="200"}[5m]
http_requests_total{code="200"} offset 1h  
http_requests_total{code="200"}[5m] offset 1h  
```

通过区间向量表达式查询到的结果称为**区间向量**，PromQL支持的时间单位：s, m, h, d, w, y



## 2.3 时间位移操作

通过 offset 获取前5分钟、前一天的数据

```text
http_requests_total{}      # 瞬时向量表达式，当前最新的数据
http_requests_total{}[5m]  # 区间向量表达式，当前时间为基准，5分钟内的数据

http_requests_total{}[5m] offset 5m
http_requests_total{}[1d] offset 1d
```



## 2.4 标量和字符串

除了使用瞬时向量表达式和区间向量表达式外，PromQL还支持标量(Scalar)和字符串(String)

- 标量：一个浮点数，没有时序。`count(http_requests_total)` 返回的依旧是瞬时向量，可以通过内置函数 scalar() 将单个瞬时向量转换为标量
- 字符串：直接返回字符串

```bash
# 将瞬时向量转换为标量，如果指标样本数量大于1或等于0，则返回NaN
scalar(v instant-vetcor)

# 将标量转换为一个无标签的瞬时向量
vector(s scalar)
```

示例：

```bash
scalar(ssCpuIdle{instance="172.16.8.184"})  =>  scalar 95
scalar(ssCpuIdle{})  =>  scalar NaN

# 指标存在
ssCpuIdle{instance="172.16.8.184"} or vector(80) => 
  ssCpuIdle{instance="172.16.8.184", job="snmp"} 95
  {}                                             80

# 指标不存在
ssCpuIdle{instance="172.16.8.185"} or vector(80) =>
  {}                                             80
```



# 3. 操作符

## 3.1 数学运算

支持的数学运算符：`+`, `-`, `*`, `/`, `%`, `^`

```text
node_disk_written_bytes_total{device="dm-1"} / (1024 * 1024)

node_disk_written_bytes_total{device="dm-1"} + node_disk_read_bytes_total{device="dm-1"}
```



## 3.2 布尔运算

支持的布尔运算符：`==`、`!=`、`>`、`<`、`>=`、`<=`

使用 bool 修饰符改变布尔运算符行为：true(1)，false(0)

```text
# 大于1000时，返回1
http_requests_total > bool 1000

# 两个标量之间的布尔运算，必须使用 bool 修饰符
2 == bool 2     # 返回1
```



## 3.3 集合运算符

瞬时向量表达式能够获取一个包含多个时间序列的集合，称之为瞬时向量。可以在两个瞬时向量之间进行相应的集合操作，支持如下操作符：

- v1 and v2：两个向量的交集
- v1 or v2：两个向量的并集
- v1 unless v2：v1中没有与v2匹配的元素集合

```bash
# 过滤使用量大于4096的分区
hrStorageUsed{instance="172.16.7.181"} and hrStorageUsed>4096

# 范围(4096, 32000)
hrStorageUsed<32000 and hrStorageUsed>4096

# 范围(0,4096)和(3200,+Inf)
hrStorageUsed>31000 or hrStorageUsed<4096

# 标签不相同时，输出第一个
ssCpuIdle{instance="172.16.8.158",device_type="server"} unless ssCpuSystem{instance="172.16.8.158",device_type="workstation"} => ssCpuIdle{instance="172.16.8.158",device_type="server"}

# 标签相同时，不输出
ssCpuIdle{instance="172.16.8.158",device_type="server"} unless ssCpuSystem{instance="172.16.8.158",device_type="server"} => no data
```



## 3.4 操作符优先级

优先级由高到低，依次为：

- `^`
- `*, /, %`
- `+, -`
- `==, !=, <, <=, >, >=`
- `and, unless`
- `or`



## 3.5 匹配模式

向量与向量之间的运算操作，会基于默认的匹配规则：**两个向量的标签必须完全一致，如果不一致，则直接丢弃。**

**一对一匹配(one-to-one)**：从操作符的两边表达式获取瞬时变量依次比较并找到唯一配（标签完全一致）的样本值

```text
vector1 <operator> vector2
```

在标签不一致时，可以使用以下两个操作符来修改标签的匹配行为：

```text
<vector expr> <bin-op> ignoring(<label list>) <vector expr>
<vector expr> <bin-op> on(<label list>) <vector expr>
```

- on：限定使用某些标签
- ignoring：忽略某些标签



样本值：

```bash
method_code:http_errors:rate5m{method="get", code="500"}  24
method_code:http_errors:rate5m{method="get", code="404"}  30
method_code:http_errors:rate5m{method="put", code="501"}  3
method_code:http_errors:rate5m{method="post", code="500"} 6
method_code:http_errors:rate5m{method="post", code="404"} 21

method:http_requests:rate5m{method="get"}  600
method:http_requests:rate5m{method="del"}  34
method:http_requests:rate5m{method="post"} 120
```



计算值：

```bash
method_code:http_errors:rate5m{code="500"} / ignoring(code) method:http_requests:rate5m

{method="get"}  0.04            //  24 / 600
{method="post"} 0.05            //   6 / 120
```



**多对一和一对多**：针对除了标签不一致，操作符左右向量数不一致的情况，需要使用 group 修饰符

```text
<vector expr> <bin-op> ignoring(<label list>) group_left(<label list>) <vector expr>
<vector expr> <bin-op> ignoring(<label list>) group_right(<label list>) <vector expr>
<vector expr> <bin-op> on(<label list>) group_left(<label list>) <vector expr>
<vector expr> <bin-op> on(<label list>) group_right(<label list>) <vector expr>
```

- group_left
- group_right

使用表达式：

```bash
method_code:http_errors:rate5m / ignoring(code) group_left method:http_requests:rate5m
```

该表达式中，左向量`method_code:http_errors:rate5m`包含两个标签method和code。而右向量`method:http_requests:rate5m`中只包含一个标签method，因此匹配时需要使用ignoring限定匹配的标签为code。 在限定匹配标签后，右向量中的元素可能匹配到多个左向量中的元素 因此该表达式的匹配模式为多对一，需要使用group修饰符group_left指定左向量具有更好的基数。

运算结果：

```bash
{method="get", code="500"}  0.04            //  24 / 600
{method="get", code="404"}  0.05            //  30 / 600
{method="post", code="500"} 0.05            //   6 / 120
{method="post", code="404"} 0.175           //  21 / 120
```



# 4. 聚合操作

样本特征标签不唯一的情况下，通过 PromQL 查询数据，会返回多条满足这些特征维度的时间序列，而聚合操作可用来对这些时间序列进行处理，形成一条新的时间序列

聚合操作语法：

```text
<aggr-op>([parameter,] <vector expression>) [without|by (<label list>)]
```

其中：只有`count_values`, `quantile`, `topk`, `bottomk` 支持参数

without： 用于从计算结果中移除列举的标签，保留其他标签

by：与 without 相反，结果向量中只保留列出的标签，其余标签移除

```
sum(http_requests_total) without (instance)

sum(http_requests_total) by (code,handler,job, method)
```



## 4.1 单值

```bash
sum(v instant-vector)
min(v instant-vector)
max(v instant-vector)
avg(v instant-vector)

count(v instant-vector)

# 统计某个标签或某个值出现的频次
count_values(label_name string, v instant-vector)
```

示例：

```bash
# 请求总数
sum(prometheus_http_requests_total) =>
{} 36049

# 排除标签handler统计
sum(prometheus_http_requests_total) without (handler) =>
{code="200", instance="prometheus", job="prometheus"} 37972
{code="302", instance="prometheus", job="prometheus"} 1
{code="400", instance="prometheus", job="prometheus"} 13

# 通过标签code、instance统计
sum(prometheus_http_requests_total) by (code, instance) =>
{code="200", instance="prometheus"} 38041
{code="302", instance="prometheus"} 1
{code="400", instance="prometheus"} 13

# 最大值
max(prometheus_http_requests_total) =>
{} 16160

# 最小值
min(prometheus_http_requests_total) =>
{} 0

# 请求量总个数
count(prometheus_http_requests_total) =>
{} 	54

# 统计每个状态码的数量
count_values("code", prometheus_http_requests_total)

# 统计每种错误类型出现次数
count_values("error", errors_total)

# 按 mode 计算主机 CPU 的平均使用率
avg(node_cpu_seconds_total) by (mode)

# 查询各主机的 CPU 使用率
sum(sum(irate(node_cpu_seconds_total{mode!='idle'}[5m])) / sum(irate(node_cpu_seconds_total[5m]))) by (instance)
```



## 4.2 排序

```bash
# 返回向量最大的几个采样值
topk(N scalar, v instant-vector)

# 返回向量最小的几个采样值
bottomk(N scalar, v instant-vector)

# 升序排序
sort(v instant-vector)

# 降序排序
sort_desc(v instant-vector)
```

示例：

```bash
# CPU空闲率最大的3个
topk(3, ssCpuIdle)

# 按CPU空闲率升序排序
sort(ssCpuIdle)
```



## 4.3 分位数

φ-quantile (0 ≤ φ ≤ 1)

```bash
quantitle(φ scalar, v instant-vector)
```

示例：

```bash
# 计算当前样本数据分布情况 quantile(φ, express)其中0 ≤ φ ≤ 1
quantile(0.5, http_requests_total)  # 找到当前样本数据中的中位数
```



## 4.4 标准差

```bash
# 方差
stdvar(v instant-vector)

# 标准差，体现出一组数据的离散程度
# 标准差是方差的平方根
# 两个集合{0,5,9,14} 和 {5,6,7,8} 的平均值都是7，但第二个具有较小的标准差
# 平均值：(0+5+9+14)/4=7
# 方差：((0-7)^2+(5-7)^2+(9-7)^2+(14-7)^2)=(49+4+4+49)/4=106/4=26.5
# 标准差：sqrt(26.5)=5.1478150704935
stddev(v instant-vector)
```

示例：

```bash
```



# 5. 数学函数

```bash
# 绝对值
abs(v instant-vector)

# 四舍五入向上取整
ceil(v instant-vector)

# 四舍五入向下取整
floor(v instant-vector)

# 保留几位小数，to_nearest默认值1，表示样本返回的是最接近1的倍数的值
round(v instant-vector, to_nearest=1 scalar)

# 指数，当指标值足够大时会返回+Inf，特殊情况：exp(+Inf)=+Inf，exp(NaN)=NaN
exp(v instant-vector)

# 平方根
sqrt(v instant-vector)
```

示例：

```bash
ceil(vector(6.5))    # 7
floor(vector(6.5))   # 6

round(vector(6.5))   # 7
round(vector(6.4))   # 6

round(vector(6.1), 4)  # 8, 最接近4的倍数的是8

round(vector(6.1234), 0.1)  # 6.1

exp(vector(2))   # 7.38905609893065

sqrt(vector(3))  # 1.7320508075688772     
```



# 6. 时间函数

```bash
# 返回样本的时间戳
timestamp(v instant-vector)

month(v=vector(time()) instant-vector)

year(v=vector(time()) instant-vector)

hour(v=vector(time()) instant-vector)

minute(v=vector(time()) instant-vector)

# UTC 时间所在月的第几天 (1~31)
day_of_month(v=vector(time()) instant-vector)

# UTC 时间所在周的第几天 (0~6)
day_of_week(v=vector(time()), instant-vector)

# UTC 时间所在的月共有几天 (28~31)
day_in_month(v=vector(time()) instant-vector)
```

示例：

```bash
day_of_month(timestamp(ssCpuIdle{instance="172.16.7.181"}))
{device_type="server", group="tke", instance="172.16.7.181", job="snmp-exporter", safe_zone="III", sysName="k8s-master"}
8

day_of_week(timestamp(ssCpuIdle{instance="172.16.7.181"}))

days_in_month(timestamp(sysUpTime{instance="172.16.7.181"}))
```



# 7. 增长率

**适用于 Counter 类型**

```bash
# 所有样本增长率的平均值 (适合缓慢变化的计数器)
rate(v range-vector)

# 最后两个样本增长率的平均值 (适合快速变化的计数器，具有更好的灵敏度)
irate(v range-vector)

# 区间向量最后一个和第一个的样本的差值
increase(v range-vector)
```

示例：

```bash
# increase 获取区间向量中第一个后最后一个样本并返回其增长量
increase(node_cpu_seconds_total[2m]) / 120    # 两分钟的增长量，除以120s得到最近两分钟的平均增长率

# rate 直接计算区间向量在时间窗口内的平均增长率
rate(node_cpu_seconds_total[2m])    # 效果同上

# irate 同样计算区间内的增长率，但其反映出瞬时增长率，可用于避免时间窗口范围内的”长尾问题“，具有更好的灵敏度
irate(node_cpu_seconds_total[2m])
```



## 7.1 rate

**rate**：`Counter` 指标的平均变化速率。可用于求某个时间区间内的请求速率，即QPS

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-PromQL-rate.png)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-PromQL-rate-instance.png)

## 7.2 irate

**irate**：更高的灵敏度，通过时间区间中最后两个样本数据来计算区间向量的增长速率，解决 rate() 函数无法处理的突变

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-PromQL-irate.png)

![img](https://cdn.jsdelivr.net/gh/elihe2011/bedgraph@master/prometheus/prometheus-PromQL-irate-instance.png)

# 8. 差值

适用于 Gauge 类型：

```bash
# 区间内第一个和最后一个元素之间的差值
delta(v range-vector)

# 区间内最新 2 个样本值的差值
idelta(v range-vector)
```



# 9. 预测

预测 Gauge 指标变化趋势

```bash
predict_linear(v range-vector, t scalar)
```

预测时间序列 v 在 t 秒后的值。它基于简单线性回归的方式，对时间窗口内的样本数据进行统计，从而可以对时间序列的变化趋势做出预测。该函数的返回结果不带有度量指标，只有标签列表。

```bash
# 根据过去4小时的指标值，预测2小时后的值
predict_linear(ssCpuIdle{device_type="fisec_cipher"}[4h], 2*3600)
```



# 10. 子查询

```bash
# 区间向量内每个指标的平均值
avg_over_time(v range-vector)

# 区间向量内每个指标的最小值
min_over_time(v range-vector)

# 区间向量内每个指标的最大值
max_over_time(v range-vector)

# 区间向量内每个指标的求和
sum_over_time(v range-vector)

# 区间向量内每个指标的个数
count_over_time(v range-vector)

# 区间向量内每个指标的分位数, φ-quantile (0 ≤ φ ≤ 1)
quantile_over_time(φ scalar, v range-vetcor)
```



示例：

```bash
# 2小时内，CPU平均空闲率
avg_over_time(ssCpuIdle{instance="172.16.8.184"}[2h])

# 1天内，CPU空闲率达到95%的百分比为85%
quantile_over_time(0.95, ssCpuIdle{instance="172.16.7.181"}[1d])
```



# 11. 统计 Histogram 指标的分位数

区别于 Summary 直接在客户端计算了数据分布的分位数情况，Histogram 的分位数计算需要通过 `histogram_quantile(φ float, b instant-vector)`函数进行计算。其中φ（0<φ<1）表示需要计算的分位数.

指标http_request_duration_seconds_bucket：

```text
# HELP http_request_duration_seconds request duration histogram
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.5"} 0
http_request_duration_seconds_bucket{le="1"} 1
http_request_duration_seconds_bucket{le="2"} 2
http_request_duration_seconds_bucket{le="3"} 3
http_request_duration_seconds_bucket{le="5"} 3
http_request_duration_seconds_bucket{le="+Inf"} 3
http_request_duration_seconds_sum 6
http_request_duration_seconds_count 3
```

计算中位分位数：

```text
histogram_quantile(0.5, http_request_duration_seconds_bucket)
```



# 12. 标签

```bash
# 合并标签
label_join(v instant-vector, dst_label string, separator string, src_label_1 string, src_label_2 string, ...)

# 正则方式添加额外新标签
label_replace(v instant-vetcor, dst_label string, replacement string, src_label string, regex string)
```

示例：

```bash
ssCpuIdle{device_type="fisec_cipher", instance="172.16.8.184", job="snmp", safe_zone="I", sysName="localhost.localdomain"} 95

label_join(ssCpuIdle{device_type="fisec_cipher"}, "newLabel", "->", "safe_zone", "instance")
ssCpuIdle{device_type="fisec_cipher", instance="172.16.8.184", job="snmp", newLabel="I->172.16.8.184", safe_zone="I", sysName="localhost.localdomain"} 95

----------------------------------------
doris_fe_qps{_type="doris", cluster_name="doris-igom", group="fe", instance="172.16.8.158:8030", job="doris"}
0.4375

label_replace(doris_fe_qps, "host", "$1", "instance", "(.*):.*")

doris_fe_qps{_type="doris", cluster_name="doris-igom", group="fe", host="172.16.8.158", instance="172.16.8.158:8030", job="doris"}
```



# 13. 其他

## 13.1 不存在

```bash
# 不存在时，返回1
absent(v instant-vector)
```

示例：

```bash
# 样本存在，不返回
absent(prometheus_http_requests_total) => no data

# 样本不存在，返回1
absent(nonexistent) => 1
absent(nonexistent{job="doris"}) => {job="doris"} 1
```



## 13.2 限制值

```bash
# 限制最大返回值
clamp_max(v instant-vetcor, max scalar)

# 限制最小返回值
clamp_min(v instant-vetcor, min scalar)

# 最大最小值限制
clamp(v instant-vector, min scalar, max scalar)
```

示例：

```bash
prometheus_http_requests_total{code="200", handler="/-/healthy", instance="prometheus", job="prometheus"}
9494

clamp_max(prometheus_http_requests_total{handler="/-/healthy"}, 5000) =>
{code="200", handler="/-/healthy", instance="prometheus", job="prometheus"} 5000

clamp_min(prometheus_http_requests_total{handler="/-/healthy"}, 10000) => 
{code="200", handler="/-/healthy", instance="prometheus", job="prometheus"} 10000
```



## 13.3 指标变化

```bash
# 区间向量内数值变更的次数。非常适合用来分析 状态变更频率、重启次数、配置切换次数
changes(v range-vector)

# 一般只用在Counter类型的时间序列上。它返回一个计数器重置的次数。两个连续样本之间的值减少被认为是一次计数器重置
resets(v range-vector)
```

示例：

```bash
# 区间向量内，每个样本数值变化的次数
changes(sum(prometheus_http_requests_total{instance="prometheus"}) by (code) [1h:5m]) =>
{code="200"} 11
{code="302"} 0
{code="400"} 0

# 过去12天，计数器被重置的次数
resets(ssCpuRawIdle{instance="172.16.8.158"}[12d])
```

















































