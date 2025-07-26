-- 简化版：快速获取活动VIP交易额核心指标

SELECT 
    activity_id AS 活动ID,
    activity_name AS 活动名称,
    
    -- 核心VIP交易指标
    COUNT(DISTINCT CASE WHEN vip_level > 0 AND enroll_flag = 1 THEN uid END) AS 活动VIP报名人数,
    COUNT(DISTINCT CASE WHEN vip_level > 0 AND enroll_flag = 1 AND trade_flag = 1 THEN uid END) AS 活动VIP交易人数,
    SUM(CASE WHEN vip_level > 0 AND enroll_flag = 1 AND trade_flag = 1 THEN amount_u ELSE 0 END) AS 活动VIP交易总额,
    
    -- 按VIP等级分类的交易额
    SUM(CASE WHEN vip_level = 1 AND enroll_flag = 1 THEN amount_u ELSE 0 END) AS VIP1级交易额,
    SUM(CASE WHEN vip_level = 2 AND enroll_flag = 1 THEN amount_u ELSE 0 END) AS VIP2级交易额,
    SUM(CASE WHEN vip_level = 3 AND enroll_flag = 1 THEN amount_u ELSE 0 END) AS VIP3级交易额,
    SUM(CASE WHEN vip_level >= 4 AND enroll_flag = 1 THEN amount_u ELSE 0 END) AS VIP4级及以上交易额,
    
    -- 活跃度指标
    ROUND(
        COUNT(DISTINCT CASE WHEN vip_level > 0 AND enroll_flag = 1 AND trade_flag = 1 THEN uid END) * 100.0 / 
        NULLIF(COUNT(DISTINCT CASE WHEN vip_level > 0 AND enroll_flag = 1 THEN uid END), 0), 2
    ) AS VIP交易活跃率

FROM (
    SELECT DISTINCT
        e.uid,
        e.vip_level,
        COALESCE(a.amount_u, 0) AS amount_u,
        CASE WHEN b.uid IS NOT NULL THEN 1 ELSE 0 END AS enroll_flag,
        CASE WHEN a.uid IS NOT NULL THEN 1 ELSE 0 END AS trade_flag,
        b.activity_id,
        b.activity_name
        
    FROM (
        SELECT uid, dt, vip_level 
        FROM dwd.dwd_user_info_ss 
        WHERE dt BETWEEN '${begin_date}' AND '${end_date}'
    ) e
    
    LEFT JOIN (
        SELECT uid, stats_date, SUM(amount_u) AS amount_u
        FROM dws.dws_trade_type_day
        WHERE stats_date BETWEEN '${begin_date}' AND '${end_date}'
          AND amount_u > 0
        GROUP BY uid, stats_date
    ) a ON e.uid = a.uid AND e.dt = a.stats_date
    
    LEFT JOIN (
        SELECT DISTINCT 
               au.uid,
               ai.activity_id,
               ai.activity_name
        FROM dwd.dwd_activity_apply_user_info au
        INNER JOIN dwd.dwd_activity_info ai ON au.activity_id = ai.activity_id
        WHERE au.status = 1
          AND DATE(au.create_time) BETWEEN '${begin_date}' AND '${end_date}'
          ${if(len(activity_id_limit) > 0, "AND au.activity_id IN (" + activity_id_limit + ")", "")}
    ) b ON e.uid = b.uid
    
    WHERE b.uid IS NOT NULL  -- 只统计参与活动的用户
) main_data

GROUP BY activity_id, activity_name
ORDER BY 活动VIP交易总额 DESC;