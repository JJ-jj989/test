-- 用户福利中心相关标签SQL查询
-- 包含：历史访问、近14天访问、累计访问次数、签到日期等标签

WITH welfare_center_visits AS (
    -- 福利中心访问记录
    -- 假设使用用户行为日志表记录福利中心访问
    SELECT 
        uid,
        visit_time,
        DATE(visit_time) AS visit_date
    FROM dwd.dwd_user_behavior_log 
    WHERE page_name = '福利中心' 
       OR page_code = 'welfare_center'
       OR action_type = 'welfare_center_visit'
),

checkin_records AS (
    -- 签到记录
    -- 假设使用签到记录表或从行为日志中筛选签到动作
    SELECT 
        uid,
        checkin_time,
        DATE(checkin_time) AS checkin_date
    FROM dwd.dwd_user_checkin_log
    WHERE status = 1  -- 成功签到
    
    UNION ALL
    
    -- 如果签到记录在行为日志中
    SELECT 
        uid,
        action_time AS checkin_time,
        DATE(action_time) AS checkin_date
    FROM dwd.dwd_user_behavior_log
    WHERE action_type = 'daily_checkin' 
       OR action_type = 'sign_in'
       AND result = 'success'
),

user_base AS (
    -- 用户基础信息
    SELECT DISTINCT uid
    FROM dwd.dwd_user_info_ss
    WHERE dt = CURRENT_DATE - INTERVAL 1 DAY  -- 最新快照
)

SELECT 
    u.uid AS 用户ID,
    
    -- 标签1: 历史是否有访问过福利中心
    CASE 
        WHEN wv_history.uid IS NOT NULL THEN 1 
        ELSE 0 
    END AS 历史是否访问福利中心,
    
    -- 标签2: 近14天是否有访问福利中心  
    CASE 
        WHEN wv_recent.uid IS NOT NULL THEN 1 
        ELSE 0 
    END AS 近14天是否访问福利中心,
    
    -- 标签3: 累计福利中心访问次数
    COALESCE(wv_count.total_visits, 0) AS 累计福利中心访问次数,
    
    -- 标签4: 最近一次点击签到日期
    ci_latest.latest_checkin_date AS 最近一次签到日期,
    
    -- 标签5: 首次签到日期
    ci_first.first_checkin_date AS 首次签到日期,
    
    -- 额外标签: 近14天福利中心访问次数
    COALESCE(wv_recent.recent_visits, 0) AS 近14天福利中心访问次数,
    
    -- 额外标签: 累计签到天数
    COALESCE(ci_count.total_checkin_days, 0) AS 累计签到天数,
    
    -- 额外标签: 近14天签到天数
    COALESCE(ci_recent.recent_checkin_days, 0) AS 近14天签到天数

FROM user_base u

-- 关联历史福利中心访问记录
LEFT JOIN (
    SELECT DISTINCT uid
    FROM welfare_center_visits
) wv_history ON u.uid = wv_history.uid

-- 关联近14天福利中心访问记录
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS recent_visits
    FROM welfare_center_visits
    WHERE visit_date >= CURRENT_DATE - INTERVAL 14 DAY
    GROUP BY uid
) wv_recent ON u.uid = wv_recent.uid

-- 关联累计福利中心访问次数
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS total_visits
    FROM welfare_center_visits
    GROUP BY uid
) wv_count ON u.uid = wv_count.uid

-- 关联最近一次签到日期
LEFT JOIN (
    SELECT 
        uid,
        MAX(checkin_date) AS latest_checkin_date
    FROM checkin_records
    GROUP BY uid
) ci_latest ON u.uid = ci_latest.uid

-- 关联首次签到日期
LEFT JOIN (
    SELECT 
        uid,
        MIN(checkin_date) AS first_checkin_date
    FROM checkin_records
    GROUP BY uid
) ci_first ON u.uid = ci_first.uid

-- 关联累计签到天数
LEFT JOIN (
    SELECT 
        uid,
        COUNT(DISTINCT checkin_date) AS total_checkin_days
    FROM checkin_records
    GROUP BY uid
) ci_count ON u.uid = ci_count.uid

-- 关联近14天签到天数
LEFT JOIN (
    SELECT 
        uid,
        COUNT(DISTINCT checkin_date) AS recent_checkin_days
    FROM checkin_records
    WHERE checkin_date >= CURRENT_DATE - INTERVAL 14 DAY
    GROUP BY uid
) ci_recent ON u.uid = ci_recent.uid

ORDER BY u.uid;