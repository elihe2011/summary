# 1. SQL性能优化

1. 为避免全表扫描，涉及 WHERE 和 ORDER BY 的字段建立索引

2. 避免 WHERE 中使用 NULL 判断，建表时尽量使用NOT NULL

3. 避免 WHERE 中使用 != 或 <>，这些操作可使用索引：<, <=, =, >, >=, BETWEEN, IN，LIKE (某些时候)

4. 避免 WHERE 中使用 OR，它会导致引擎放弃使用索引而进行全表扫描，可以使用 UNION 代替

5. 慎用 IN 和 NOT IN，连续的数值，推荐BETWEEN 

6. WHERE 中字段 不要使用函数、表达式

   ```sql
   SELECT * FROM record WHERE amount/30 < 1000;
   SELECT * FROM record WHERE convert(char(10), date, 112) = '20201220';
   ```

7. 用EXISTS 代替 IN

   ```sql
   select num from a where num in (select num from b)
   select num from a where num exists (select 1 from b)
   ```

8. 索引会提高SELECT的效率，但也降低了INSERT和UPDATE的效率(索引重建), 一个表的索引，最好不要超过6个

9. JOIN的表不要超过5个，考虑使用临时表。

10. 少用子查询，视图嵌套不要超过2层

11. 数量统计，用`count(1)`代替 `count(*)`

12. 记录是否存在，用 EXISTS 代替 `count(1)`

13. `>=` 效率比 `>` 高

14. GROUP BY 前，先进行数据过滤：

    ```sql
    select job, avg(sal) from emp GROUP BY job HAVING job='engineer' or job='saler';
    select job, avg(sal) from emp where job='engineer' or job='saler' GROUP BY job;
    ```

15. 尽量不使用触发器，trigger事件比较耗时

16. 避免使用DISTINCT

17. 

