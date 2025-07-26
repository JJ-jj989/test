-- 适配版：用户福利中心标签SQL（基于现有数据架构）
-- 需要根据实际表结构调整表名和字段名

WITH welfare_visits AS (
    -- 福利中心访问记录（需要根据实际表结构调整）
    SELECT 
        uid,
        create_time AS visit_time,
        DATE(create_time) AS visit_date
    FROM dwd.dwd_user_page_visit_log 
    WHERE page_type = 'welfare_center' 
       OR page_name LIKE '%福利中心%'
       OR module_name = 'welfare'
    
    UNION ALL
    
    -- 如果福利中心访问记录在其他表中
    SELECT 
        user_id AS uid,
        visit_time,
        DATE(visit_time) AS visit_date
    FROM dwd.dwd_welfare_center_visit_log
    WHERE status = 1
),

checkin_data AS (
    -- 签到记录（需要根据实际表结构调整）
    SELECT 
        uid,
        checkin_time,
        DATE(checkin_time) AS checkin_date
    FROM dwd.dwd_user_daily_checkin
    WHERE checkin_status = 1  -- 签到成功
    
    UNION ALL
    
    -- 如果签到记录在用户积分或奖励表中
    SELECT 
        uid,
        create_time AS checkin_time,
        DATE(create_time) AS checkin_date  
    FROM dwd.dwd_user_points_log
    WHERE point_type = 'daily_checkin'
       OR business_type = 'sign_in'
),

-- 基于现有模式的用户基础表
users AS (
    SELECT DISTINCT uid
    FROM dwd.dwd_user_info_ss
    WHERE dt >= CURRENT_DATE - INTERVAL 30 DAY  -- 近期活跃用户
)

SELECT 
    u.uid,
    
    -- 必需的5个标签
    
    -- 1. 历史是否有访问过福利中心 (0/1)
    CASE 
        WHEN wv_all.uid IS NOT NULL THEN 1 
        ELSE 0 
    END AS is_visited_welfare_center_ever,
    
    -- 2. 近14天是否有访问福利中心 (0/1)  
    CASE 
        WHEN wv_14d.uid IS NOT NULL THEN 1 
        ELSE 0 
    END AS is_visited_welfare_center_14d,
    
    -- 3. 累计福利中心访问次数
    COALESCE(wv_total.visit_count, 0) AS welfare_center_visit_count_total,
    
    -- 4. 最近一次点击签到日期
    ci_last.last_checkin_date AS last_checkin_date,
    
    -- 5. 首次签到日期  
    ci_first.first_checkin_date AS first_checkin_date,
    
    -- 附加标签（可选）
    COALESCE(wv_14d.recent_visit_count, 0) AS welfare_center_visit_count_14d,
    COALESCE(wv_7d.recent_visit_count_7d, 0) AS welfare_center_visit_count_7d,
    COALESCE(ci_total.total_checkin_days, 0) AS total_checkin_days,
    COALESCE(ci_14d.checkin_days_14d, 0) AS checkin_days_14d,
    
    -- 计算签到相关指标
    CASE 
        WHEN ci_first.first_checkin_date IS NOT NULL 
        THEN DATEDIFF(CURRENT_DATE, ci_first.first_checkin_date) + 1
        ELSE 0 
    END AS days_since_first_checkin,
    
    CASE 
        WHEN ci_last.last_checkin_date IS NOT NULL 
        THEN DATEDIFF(CURRENT_DATE, ci_last.last_checkin_date)
        ELSE NULL 
    END AS days_since_last_checkin

FROM users u

-- 历史福利中心访问
LEFT JOIN (
    SELECT DISTINCT uid 
    FROM welfare_visits
) wv_all ON u.uid = wv_all.uid

-- 近14天福利中心访问
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS recent_visit_count
    FROM welfare_visits 
    WHERE visit_date >= CURRENT_DATE - INTERVAL 14 DAY
    GROUP BY uid
) wv_14d ON u.uid = wv_14d.uid

-- 近7天福利中心访问
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS recent_visit_count_7d
    FROM welfare_visits 
    WHERE visit_date >= CURRENT_DATE - INTERVAL 7 DAY
    GROUP BY uid
) wv_7d ON u.uid = wv_7d.uid

-- 累计福利中心访问次数
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS visit_count
    FROM welfare_visits
    GROUP BY uid
) wv_total ON u.uid = wv_total.uid

-- 首次签到日期
LEFT JOIN (
    SELECT 
        uid,
        MIN(checkin_date) AS first_checkin_date
    FROM checkin_data
    GROUP BY uid
) ci_first ON u.uid = ci_first.uid

-- 最近一次签到日期  
LEFT JOIN (
    SELECT 
        uid,
        MAX(checkin_date) AS last_checkin_date
    FROM checkin_data
    GROUP BY uid
) ci_last ON u.uid = ci_last.uid

-- 累计签到天数
LEFT JOIN (
    SELECT 
        uid,
        COUNT(DISTINCT checkin_date) AS total_checkin_days
    FROM checkin_data
    GROUP BY uid
) ci_total ON u.uid = ci_total.uid

-- 近14天签到天数
LEFT JOIN (
    SELECT 
        uid,
        COUNT(DISTINCT checkin_date) AS checkin_days_14d
    FROM checkin_data
    WHERE checkin_date >= CURRENT_DATE - INTERVAL 14 DAY
    GROUP BY uid  
) ci_14d ON u.uid = ci_14d.uid

ORDER BY u.uid;