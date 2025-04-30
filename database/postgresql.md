# 1. 删除数据库

```sql
-- 1. 禁止新的连接到数据库
UPDATE pg_database SET datallowconn = 'false' WHERE datname = 'konga';

-- 2. 中断当前所有连接会话
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'konga';

-- 3. 删除数据库
DROP DATABASE konga;
```
