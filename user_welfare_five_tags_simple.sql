-- 用户福利中心5个核心标签 (简化版)
-- 基于 s3_log.client_event_log 事件日志

WITH welfare_visits AS (
    -- 福利中心访问记录
    SELECT 
        uid,
        DATE(log_date) AS visit_date
    FROM s3_log.client_event_log 
    WHERE event IN ('home_welfare_new_newuser', 'home_welfare_new_advance')
      AND uid IS NOT NULL
),

checkin_records AS (
    -- 签到记录 (需要根据实际签到事件名称调整)
    SELECT 
        uid,
        DATE(log_date) AS checkin_date
    FROM s3_log.client_event_log 
    WHERE event IN (
        'daily_checkin',        -- 请根据实际的签到事件名称调整
        'checkin_success',      
        'welfare_checkin',
        'home_checkin',
        'sign_in_daily'
    )
      AND uid IS NOT NULL
)

SELECT 
    u.uid,
    
    -- 标签1: 历史是否有访问过福利中心 (0/1)
    CASE 
        WHEN wv_ever.uid IS NOT NULL THEN 1 
        ELSE 0 
    END AS 历史是否有访问过福利中心,
    
    -- 标签2: 近14天是否有访问福利中心 (0/1)
    CASE 
        WHEN wv_14d.uid IS NOT NULL THEN 1 
        ELSE 0 
    END AS 近14天是否有访问福利中心,
    
    -- 标签3: 累计福利中心访问次数
    COALESCE(wv_total.访问次数, 0) AS 累计福利中心访问次数,
    
    -- 标签4: 最近一次点击签到日期
    ci_last.最近一次签到日期 AS 最近一次点击签到日期,
    
    -- 标签5: 首次签到日期
    ci_first.首次签到日期 AS 首次签到日期

FROM (
    -- 用户基础表
    SELECT DISTINCT uid
    FROM dwd.dwd_user_info
    WHERE uid IS NOT NULL
) u

-- 关联历史福利中心访问
LEFT JOIN (
    SELECT DISTINCT uid 
    FROM welfare_visits
) wv_ever ON u.uid = wv_ever.uid

-- 关联近14天福利中心访问
LEFT JOIN (
    SELECT DISTINCT uid 
    FROM welfare_visits 
    WHERE visit_date >= CURRENT_DATE - INTERVAL 14 DAY
) wv_14d ON u.uid = wv_14d.uid

-- 关联累计福利中心访问次数
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS 访问次数
    FROM welfare_visits
    GROUP BY uid
) wv_total ON u.uid = wv_total.uid

-- 关联首次签到日期
LEFT JOIN (
    SELECT 
        uid,
        MIN(checkin_date) AS 首次签到日期
    FROM checkin_records
    GROUP BY uid
) ci_first ON u.uid = ci_first.uid

-- 关联最近一次签到日期
LEFT JOIN (
    SELECT 
        uid,
        MAX(checkin_date) AS 最近一次签到日期
    FROM checkin_records
    GROUP BY uid
) ci_last ON u.uid = ci_last.uid

ORDER BY u.uid;