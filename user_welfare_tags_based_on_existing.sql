-- 基于现有代码结构生成用户福利中心5个标签
-- 数据源：s3_log.client_event_log (福利中心访问事件)

WITH welfare_center_visits AS (
    -- 福利中心访问记录 (基于现有的事件日志)
    SELECT 
        uid,
        DATE(log_date) AS visit_date,
        log_date AS visit_datetime
    FROM s3_log.client_event_log 
    WHERE event IN ('home_welfare_new_newuser', 'home_welfare_new_advance')
      AND uid IS NOT NULL
),

checkin_events AS (
    -- 签到事件记录 (假设签到事件也在同一日志表中)
    SELECT 
        uid,
        DATE(log_date) AS checkin_date,
        log_date AS checkin_datetime
    FROM s3_log.client_event_log 
    WHERE event IN (
        'daily_checkin',           -- 日常签到
        'checkin_success',         -- 签到成功
        'sign_in',                 -- 签到
        'welfare_checkin',         -- 福利签到
        'home_checkin'             -- 首页签到
    )
      AND uid IS NOT NULL
),

user_base AS (
    -- 用户基础表 (基于现有的用户信息表)
    SELECT DISTINCT uid
    FROM dwd.dwd_user_info
    WHERE uid IS NOT NULL
)

SELECT 
    u.uid,
    
    -- 标签1: 历史是否有访问过福利中心 (0/1)
    CASE 
        WHEN wv_history.uid IS NOT NULL THEN 1 
        ELSE 0 
    END AS is_visited_welfare_center_ever,
    
    -- 标签2: 近14天是否有访问福利中心 (0/1)
    CASE 
        WHEN wv_14days.uid IS NOT NULL THEN 1 
        ELSE 0 
    END AS is_visited_welfare_center_14d,
    
    -- 标签3: 累计福利中心访问次数
    COALESCE(wv_total.total_visit_count, 0) AS welfare_center_visit_count_total,
    
    -- 标签4: 最近一次点击签到日期
    ci_latest.last_checkin_date,
    
    -- 标签5: 首次签到日期
    ci_first.first_checkin_date,
    
    -- 附加信息
    COALESCE(wv_14days.visit_count_14d, 0) AS welfare_center_visit_count_14d,
    COALESCE(wv_7days.visit_count_7d, 0) AS welfare_center_visit_count_7d,
    COALESCE(wv_30days.visit_count_30d, 0) AS welfare_center_visit_count_30d,
    
    -- 签到相关附加信息
    COALESCE(ci_total.total_checkin_days, 0) AS total_checkin_days,
    COALESCE(ci_14days.checkin_days_14d, 0) AS checkin_days_14d,
    
    -- 计算距离首次/最近签到的天数
    CASE 
        WHEN ci_first.first_checkin_date IS NOT NULL 
        THEN DATEDIFF(CURRENT_DATE, ci_first.first_checkin_date)
        ELSE NULL 
    END AS days_since_first_checkin,
    
    CASE 
        WHEN ci_latest.last_checkin_date IS NOT NULL 
        THEN DATEDIFF(CURRENT_DATE, ci_latest.last_checkin_date)
        ELSE NULL 
    END AS days_since_last_checkin

FROM user_base u

-- 关联历史福利中心访问 (是否访问过)
LEFT JOIN (
    SELECT DISTINCT uid 
    FROM welfare_center_visits
) wv_history ON u.uid = wv_history.uid

-- 关联近14天福利中心访问
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS visit_count_14d
    FROM welfare_center_visits 
    WHERE visit_date >= CURRENT_DATE - INTERVAL 14 DAY
    GROUP BY uid
) wv_14days ON u.uid = wv_14days.uid

-- 关联近7天福利中心访问
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS visit_count_7d
    FROM welfare_center_visits 
    WHERE visit_date >= CURRENT_DATE - INTERVAL 7 DAY
    GROUP BY uid
) wv_7days ON u.uid = wv_7days.uid

-- 关联近30天福利中心访问
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS visit_count_30d
    FROM welfare_center_visits 
    WHERE visit_date >= CURRENT_DATE - INTERVAL 30 DAY
    GROUP BY uid
) wv_30days ON u.uid = wv_30days.uid

-- 关联累计福利中心访问次数
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS total_visit_count
    FROM welfare_center_visits
    GROUP BY uid
) wv_total ON u.uid = wv_total.uid

-- 关联首次签到日期
LEFT JOIN (
    SELECT 
        uid,
        MIN(checkin_date) AS first_checkin_date
    FROM checkin_events
    GROUP BY uid
) ci_first ON u.uid = ci_first.uid

-- 关联最近一次签到日期
LEFT JOIN (
    SELECT 
        uid,
        MAX(checkin_date) AS last_checkin_date
    FROM checkin_events
    GROUP BY uid
) ci_latest ON u.uid = ci_latest.uid

-- 关联累计签到天数
LEFT JOIN (
    SELECT 
        uid,
        COUNT(DISTINCT checkin_date) AS total_checkin_days
    FROM checkin_events
    GROUP BY uid
) ci_total ON u.uid = ci_total.uid

-- 关联近14天签到天数
LEFT JOIN (
    SELECT 
        uid,
        COUNT(DISTINCT checkin_date) AS checkin_days_14d
    FROM checkin_events
    WHERE checkin_date >= CURRENT_DATE - INTERVAL 14 DAY
    GROUP BY uid
) ci_14days ON u.uid = ci_14days.uid

ORDER BY u.uid;