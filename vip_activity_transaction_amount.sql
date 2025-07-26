-- 生成活动的VIP交易额SQL查询
-- 基于现有的数据结构和业务逻辑

WITH trade_type_name_mapping AS (
    -- 交易类型映射表
    SELECT id,
           CASE WHEN id IN (3,4) THEN '标准合约自主'
                WHEN id = 8 THEN '标准合约跟单'
                WHEN id = 5 THEN '永续合约自主'
                WHEN id = 11 THEN '永续合约网格自主'
                WHEN id = 9 THEN '永续合约仓位跟单'
                WHEN id = 10 THEN '币安合约跟单'
                WHEN id = 1 THEN '现货自主直接'
                WHEN id = 2 THEN '现货(标准)网格自主'
                WHEN id = 16 THEN '现货无限网格自主'
                WHEN id = 7 THEN '现货网格跟单'
                WHEN id = 17 THEN 'MT5交易自主'
                WHEN id = 18 THEN '永续合约固定保证金跟单'
                WHEN id = 20 THEN '现货单笔跟单'
                WHEN id = 21 THEN '现货单笔带单'
                WHEN id = 22 THEN '永续币本位自主'
                ELSE name END AS name
    FROM dim.dim_trade_final_type
),

activity_users AS (
    -- 获取活动报名用户信息
    SELECT DISTINCT 
           a.uid,
           a.activity_id,
           b.activity_name,
           b.activity_type_name,
           b.creator,
           b.begin_time,
           b.end_time,
           DATE(a.create_time) AS apply_date,
           CASE get_json_string(PARSE_JSON(c.extra),'$.level')
               WHEN 1 THEN 'S' 
               WHEN 2 THEN 'A'
               WHEN 3 THEN 'B+'
               WHEN 4 THEN 'B'
               WHEN 5 THEN 'C'
           END AS activity_level
    FROM dwd.dwd_activity_apply_user_info a
    INNER JOIN dwd.dwd_activity_info b ON a.activity_id = b.activity_id
    INNER JOIN `db_activity`.`tb_activity` c ON b.activity_id = c.id
    WHERE a.status = 1
      AND DATE(a.create_time) BETWEEN '${begin_date}' AND '${end_date}'
      -- 可选筛选条件
      ${if(len(activity_id_limit) > 0, "AND a.activity_id IN (" + activity_id_limit + ")", "")}
      ${if(len(activity_type_name_limit) > 0, "AND b.activity_type_name IN ('" + activity_type_name_limit + "')", "")}
      ${if(len(creator_limit) > 0, "AND b.creator IN ('" + creator_limit + "')", "")}
),

vip_users AS (
    -- 获取VIP用户信息
    SELECT uid,
           dt,
           vip_level
    FROM dwd.dwd_user_info_ss 
    WHERE dt BETWEEN '${begin_date}' AND '${end_date}'
      AND vip_level > 0
),

trade_data AS (
    -- 获取交易数据
    SELECT t.uid,
           t.stats_date,
           SUM(t.amount_u) AS amount_u
    FROM dws.dws_trade_type_day t
    LEFT JOIN trade_type_name_mapping ttm ON t.final_trade_type = ttm.id
    WHERE t.stats_date BETWEEN '${begin_date}' AND '${end_date}'
      AND t.amount_u > 0
      -- 可选交易类型筛选
      ${if(len(final_trade_type_limit) > 0, "AND ttm.name IN ('" + final_trade_type_limit + "')", "")}
      ${if(len(final_trade_type) > 0, "AND t.final_trade_type IN ('" + final_trade_type + "')", "")}
    GROUP BY t.uid, t.stats_date
),

vip_activity_transactions AS (
    -- 组合VIP用户、活动参与和交易数据
    SELECT 
        v.uid,
        v.dt AS transaction_date,
        v.vip_level,
        a.activity_id,
        a.activity_name,
        a.activity_type_name,
        a.activity_level,
        a.creator,
        a.begin_time,
        a.end_time,
        COALESCE(t.amount_u, 0) AS amount_u,
        CASE 
            WHEN '${date_typ}' = '日' THEN CAST(v.dt AS VARCHAR)
            WHEN '${date_typ}' = '周' THEN CAST(d.yearweek_day AS VARCHAR)
            WHEN '${date_typ}' = '月' THEN CAST(d.yearmonth AS VARCHAR)
            WHEN '${date_typ}' = '季' THEN CAST(d.yearqtr AS VARCHAR)
        END AS date_period
    FROM vip_users v
    LEFT JOIN dim.dim_date d ON v.dt = d.dt
    INNER JOIN activity_users a ON v.uid = a.uid
    LEFT JOIN trade_data t ON v.uid = t.uid AND v.dt = t.stats_date
    WHERE v.dt BETWEEN DATE(a.begin_time) AND DATE(a.end_time)
)

-- 主查询：按不同维度统计VIP交易额
SELECT 
    date_period AS 日期,
    activity_id AS 活动ID,
    activity_name AS 活动名称,
    activity_type_name AS 活动类型,
    activity_level AS 活动等级,
    creator AS 创建人,
    begin_time AS 开始时间,
    end_time AS 结束时间,
    
    -- VIP相关统计
    COUNT(DISTINCT uid) AS VIP参与人数,
    COUNT(DISTINCT CASE WHEN amount_u > 0 THEN uid END) AS VIP交易人数,
    SUM(amount_u) AS VIP交易总额,
    AVG(CASE WHEN amount_u > 0 THEN amount_u END) AS VIP平均交易额,
    MAX(amount_u) AS VIP最大单日交易额,
    
    -- 按VIP等级分组统计
    COUNT(DISTINCT CASE WHEN vip_level = 1 THEN uid END) AS VIP1级人数,
    COUNT(DISTINCT CASE WHEN vip_level = 2 THEN uid END) AS VIP2级人数,
    COUNT(DISTINCT CASE WHEN vip_level = 3 THEN uid END) AS VIP3级人数,
    COUNT(DISTINCT CASE WHEN vip_level >= 4 THEN uid END) AS VIP4级及以上人数,
    
    SUM(CASE WHEN vip_level = 1 THEN amount_u ELSE 0 END) AS VIP1级交易额,
    SUM(CASE WHEN vip_level = 2 THEN amount_u ELSE 0 END) AS VIP2级交易额,
    SUM(CASE WHEN vip_level = 3 THEN amount_u ELSE 0 END) AS VIP3级交易额,
    SUM(CASE WHEN vip_level >= 4 THEN amount_u ELSE 0 END) AS VIP4级及以上交易额,
    
    -- 交易活跃度指标
    ROUND(
        COUNT(DISTINCT CASE WHEN amount_u > 0 THEN uid END) * 100.0 / 
        NULLIF(COUNT(DISTINCT uid), 0), 2
    ) AS VIP交易活跃率,
    
    -- 贡献度分析
    ROUND(SUM(amount_u) * 100.0 / SUM(SUM(amount_u)) OVER(), 2) AS 交易额占比

FROM vip_activity_transactions
GROUP BY 
    date_period,
    activity_id,
    activity_name,
    activity_type_name,
    activity_level,
    creator,
    begin_time,
    end_time
ORDER BY 
    date_period,
    activity_id,
    VIP交易总额 DESC;