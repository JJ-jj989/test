-- 查找签到相关事件名称的SQL
-- 用于确定 s3_log.client_event_log 中签到事件的具体名称

-- 1. 查找包含签到关键词的事件
SELECT 
    event,
    COUNT(*) AS 事件次数,
    COUNT(DISTINCT uid) AS 用户数,
    MIN(log_date) AS 最早日期,
    MAX(log_date) AS 最晚日期
FROM s3_log.client_event_log 
WHERE (
    LOWER(event) LIKE '%checkin%' 
    OR LOWER(event) LIKE '%check_in%'
    OR LOWER(event) LIKE '%sign_in%'
    OR LOWER(event) LIKE '%signin%'
    OR LOWER(event) LIKE '%daily%'
    OR LOWER(event) LIKE '%签到%'
    OR LOWER(event) LIKE '%welfare%'
)
  AND log_date >= '2024-01-01'  -- 近期数据
GROUP BY event
ORDER BY 事件次数 DESC;

-- 2. 如果上述查询没有结果，可以查看所有事件类型
/*
SELECT 
    event,
    COUNT(*) AS 事件次数,
    COUNT(DISTINCT uid) AS 用户数
FROM s3_log.client_event_log 
WHERE log_date >= '2024-01-01'
GROUP BY event
ORDER BY 事件次数 DESC
LIMIT 50;
*/

-- 3. 查看福利中心相关的所有事件
SELECT 
    event,
    COUNT(*) AS 事件次数,
    COUNT(DISTINCT uid) AS 用户数,
    MIN(log_date) AS 最早日期,
    MAX(log_date) AS 最晚日期
FROM s3_log.client_event_log 
WHERE (
    LOWER(event) LIKE '%welfare%'
    OR LOWER(event) LIKE '%福利%'
    OR LOWER(event) LIKE '%home_%'
)
  AND log_date >= '2024-01-01'
GROUP BY event
ORDER BY 事件次数 DESC;