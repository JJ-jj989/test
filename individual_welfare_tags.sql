-- 单独的用户福利中心标签查询
-- 可以根据需要单独执行每个标签的查询

-- ============================================
-- 标签1：历史是否有访问过福利中心
-- ============================================
/*
SELECT 
    uid,
    CASE 
        WHEN COUNT(*) > 0 THEN 1 
        ELSE 0 
    END AS is_visited_welfare_center_ever
FROM (
    SELECT DISTINCT uid
    FROM dwd.dwd_user_page_visit_log 
    WHERE page_type = 'welfare_center' 
       OR page_name LIKE '%福利中心%'
       OR module_name = 'welfare'
    
    UNION 
    
    SELECT DISTINCT user_id AS uid
    FROM dwd.dwd_welfare_center_visit_log
    WHERE status = 1
) t
RIGHT JOIN (
    SELECT DISTINCT uid 
    FROM dwd.dwd_user_info_ss 
    WHERE dt = CURRENT_DATE - INTERVAL 1 DAY
) u ON t.uid = u.uid
GROUP BY u.uid;
*/

-- ============================================
-- 标签2：近14天是否有访问福利中心
-- ============================================
/*
SELECT 
    u.uid,
    CASE 
        WHEN wv.uid IS NOT NULL THEN 1 
        ELSE 0 
    END AS is_visited_welfare_center_14d
FROM (
    SELECT DISTINCT uid 
    FROM dwd.dwd_user_info_ss 
    WHERE dt = CURRENT_DATE - INTERVAL 1 DAY
) u
LEFT JOIN (
    SELECT DISTINCT uid
    FROM (
        SELECT uid, DATE(create_time) AS visit_date
        FROM dwd.dwd_user_page_visit_log 
        WHERE (page_type = 'welfare_center' 
           OR page_name LIKE '%福利中心%'
           OR module_name = 'welfare')
          AND DATE(create_time) >= CURRENT_DATE - INTERVAL 14 DAY
        
        UNION 
        
        SELECT user_id AS uid, DATE(visit_time) AS visit_date
        FROM dwd.dwd_welfare_center_visit_log
        WHERE status = 1
          AND DATE(visit_time) >= CURRENT_DATE - INTERVAL 14 DAY
    ) recent_visits
) wv ON u.uid = wv.uid;
*/

-- ============================================
-- 标签3：累计福利中心访问次数
-- ============================================
/*
SELECT 
    u.uid,
    COALESCE(wv.visit_count, 0) AS welfare_center_visit_count_total
FROM (
    SELECT DISTINCT uid 
    FROM dwd.dwd_user_info_ss 
    WHERE dt = CURRENT_DATE - INTERVAL 1 DAY
) u
LEFT JOIN (
    SELECT 
        uid,
        COUNT(*) AS visit_count
    FROM (
        SELECT uid, create_time
        FROM dwd.dwd_user_page_visit_log 
        WHERE page_type = 'welfare_center' 
           OR page_name LIKE '%福利中心%'
           OR module_name = 'welfare'
        
        UNION ALL
        
        SELECT user_id AS uid, visit_time AS create_time
        FROM dwd.dwd_welfare_center_visit_log
        WHERE status = 1
    ) all_visits
    GROUP BY uid
) wv ON u.uid = wv.uid;
*/

-- ============================================
-- 标签4：最近一次点击签到日期
-- ============================================
/*
SELECT 
    u.uid,
    ci.last_checkin_date
FROM (
    SELECT DISTINCT uid 
    FROM dwd.dwd_user_info_ss 
    WHERE dt = CURRENT_DATE - INTERVAL 1 DAY
) u
LEFT JOIN (
    SELECT 
        uid,
        MAX(DATE(checkin_time)) AS last_checkin_date
    FROM (
        SELECT uid, checkin_time
        FROM dwd.dwd_user_daily_checkin
        WHERE checkin_status = 1
        
        UNION ALL
        
        SELECT uid, create_time AS checkin_time
        FROM dwd.dwd_user_points_log
        WHERE point_type = 'daily_checkin'
           OR business_type = 'sign_in'
    ) all_checkins
    GROUP BY uid
) ci ON u.uid = ci.uid;
*/

-- ============================================
-- 标签5：首次签到日期
-- ============================================
/*
SELECT 
    u.uid,
    ci.first_checkin_date
FROM (
    SELECT DISTINCT uid 
    FROM dwd.dwd_user_info_ss 
    WHERE dt = CURRENT_DATE - INTERVAL 1 DAY
) u
LEFT JOIN (
    SELECT 
        uid,
        MIN(DATE(checkin_time)) AS first_checkin_date
    FROM (
        SELECT uid, checkin_time
        FROM dwd.dwd_user_daily_checkin
        WHERE checkin_status = 1
        
        UNION ALL
        
        SELECT uid, create_time AS checkin_time
        FROM dwd.dwd_user_points_log
        WHERE point_type = 'daily_checkin'
           OR business_type = 'sign_in'
    ) all_checkins
    GROUP BY uid
) ci ON u.uid = ci.uid;
*/

-- ============================================
-- 组合查询：一次获取所有5个标签
-- ============================================

WITH welfare_visits AS (
    -- 福利中心访问记录
    SELECT uid, DATE(create_time) AS visit_date
    FROM dwd.dwd_user_page_visit_log 
    WHERE page_type = 'welfare_center' 
       OR page_name LIKE '%福利中心%'
       OR module_name = 'welfare'
    
    UNION ALL
    
    SELECT user_id AS uid, DATE(visit_time) AS visit_date
    FROM dwd.dwd_welfare_center_visit_log
    WHERE status = 1
),

checkin_records AS (
    -- 签到记录
    SELECT uid, DATE(checkin_time) AS checkin_date
    FROM dwd.dwd_user_daily_checkin
    WHERE checkin_status = 1
    
    UNION ALL
    
    SELECT uid, DATE(create_time) AS checkin_date
    FROM dwd.dwd_user_points_log
    WHERE point_type = 'daily_checkin'
       OR business_type = 'sign_in'
)

SELECT 
    u.uid,
    
    -- 标签1: 历史是否有访问过福利中心
    CASE WHEN wv_all.uid IS NOT NULL THEN 1 ELSE 0 END AS is_visited_welfare_center_ever,
    
    -- 标签2: 近14天是否有访问福利中心  
    CASE WHEN wv_14d.uid IS NOT NULL THEN 1 ELSE 0 END AS is_visited_welfare_center_14d,
    
    -- 标签3: 累计福利中心访问次数
    COALESCE(wv_total.visit_count, 0) AS welfare_center_visit_count_total,
    
    -- 标签4: 最近一次点击签到日期
    ci_last.last_checkin_date,
    
    -- 标签5: 首次签到日期
    ci_first.first_checkin_date

FROM (
    SELECT DISTINCT uid 
    FROM dwd.dwd_user_info_ss 
    WHERE dt = CURRENT_DATE - INTERVAL 1 DAY
) u

LEFT JOIN (SELECT DISTINCT uid FROM welfare_visits) wv_all 
    ON u.uid = wv_all.uid

LEFT JOIN (
    SELECT DISTINCT uid 
    FROM welfare_visits 
    WHERE visit_date >= CURRENT_DATE - INTERVAL 14 DAY
) wv_14d ON u.uid = wv_14d.uid

LEFT JOIN (
    SELECT uid, COUNT(*) AS visit_count
    FROM welfare_visits
    GROUP BY uid
) wv_total ON u.uid = wv_total.uid

LEFT JOIN (
    SELECT uid, MAX(checkin_date) AS last_checkin_date
    FROM checkin_records
    GROUP BY uid
) ci_last ON u.uid = ci_last.uid

LEFT JOIN (
    SELECT uid, MIN(checkin_date) AS first_checkin_date
    FROM checkin_records
    GROUP BY uid
) ci_first ON u.uid = ci_first.uid

ORDER BY u.uid;