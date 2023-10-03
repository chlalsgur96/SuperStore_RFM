-- insight (상품/매출)
-- 수익이 안 나는 카테고리 제품
SELECT ProductCategory, ProductSubCategory, 
		count(distinct order_id) '주문 수', count(order_id) '주문 품목 수', round(avg(Quantity),1) '평균 구매 수량',
        -- round(avg(sales), 2) AVG_SALES,
        round(AVG(Sales/Quantity),0) as AVG_UNIT_SALES, -- 개당 평균 매출
        -- round(avg(profit), 2) AVG_PROFIT,
        round(AVG(Profit/Quantity),0) as AVG_UNIT_PROFIT, -- 개당 평균 수익
        round(avg(Sales / Quantity * (1-Discount)), 2) AS AVG_PRODUCT_PRICE, -- 평균 물건 단가
		rank() over(order by AVG(Sales/Quantity) desc) RNK_SALES, rank() over(order by AVG(Profit/Quantity) desc) RNK_PROFIT
FROM orders 
where order_id not in (select order_id from returns)
group by ProductCategory, ProductSubCategory;

-- 월 평균 매출 및 평균 수익
SELECT
	date_format(order_timestamp,'%y-%m')month,
	AVG(Sales) as AVG_sales,
	AVG(Profit) as AVG_profit
FROM orders
where order_id not in (select order_id from returns)
group by month
order by 2 desc;

-- 지역별 관리자 배치 불균형 발생
SELECT Area,
	count(distinct Sales_Rep) as cnt
from managers
group by Area;

SELECT AddressRegion,
COUNT(DISTINCT order_id) AS order_cnt
from orders
where order_id not in (select order_id from returns)
GROUP BY AddressRegion;

-- insight(고객)
-- 연중 이용 고객 불균형
SELECT date_format(order_timestamp, '%m') month,
		count(if(year(order_timestamp) = '2017', order_id, null)) '2017',
        count(if(year(order_timestamp) = '2018', order_id, null)) '2018',
        count(if(year(order_timestamp) = '2019', order_id, null)) '2019',
        count(if(year(order_timestamp) = '2020', order_id, null)) '2020'
from orders
where order_id not in (select order_id from returns)
group by month
order by 1;

-- 신규 고객 유입 감소 (월별 코호트)
WITH t1 AS
(
SELECT customer_id,
	   MIN(order_timestamp) AS first_purchase
FROM orders
GROUP BY customer_id
)
SELECT date_format(first_purchase, '%Y-%m') AS first_purchase_month,
       date_format(order_timestamp, '%Y-%m') AS re_purchase_month,
       count(DISTINCT orders.customer_id) AS num_retention_customers
FROM orders
INNER JOIN t1 ON orders.customer_id = t1.customer_id
WHERE order_id NOT IN (SELECT order_id FROM returns)
GROUP BY first_purchase_month, re_purchase_month
ORDER BY first_purchase_month;

-- Action Plan
-- 상품 / 매출 → 수익성 개선

-- 등급별 할인율에 따른 구매 민감도
SELECT class,
round(avg(Quantity / Discount), 2) AS avg_quantity_per_discount
FROM rfm_grade t1
INNER JOIN orders t2 ON t1.customer_id = t2.customer_id
WHERE order_id NOT IN (SELECT order_id FROM returns)
GROUP BY class
ORDER BY
CASE class
WHEN 'White' THEN 1
WHEN 'Bronze' THEN 2
WHEN 'Silver' THEN 3
WHEN 'Gold' THEN 4
WHEN 'VIP' THEN 5 END;

-- 등급별 카테고리별 구매민감도
SELECT ProductCategory, ProductSubCategory,
round(avg(if(class='VIP', Quantity/Discount, NULL)), 2) AS VIP,
round(avg(if(class='Gold', Quantity/Discount, NULL)), 2) AS Gold,
round(avg(if(class='Silver', Quantity/Discount, NULL)), 2) AS Sliver,
round(avg(if(class='Bronze', Quantity/Discount, NULL)), 2) AS Bronze,
round(avg(if(class='White', Quantity/Discount, NULL)), 2) AS White
FROM rfm_grade
INNER JOIN orders ON orders.customer_id = rfm_grade.customer_id
WHERE order_id NOT IN (SELECT order_id FROM returns)
GROUP BY ProductCategory, ProductSubCategory
ORDER BY VIP DESC, Gold DESC, Sliver DESC, Bronze DESC, White DESC;

/* 고객 유형별 등급 구매 민감도 차이 */
SELECT class,
round(avg(if(CustomerSegment='개인고객',Quantity/Discount,NULL)), 2) AS '개인고객',
round(avg(if(CustomerSegment='기업고객',Quantity/Discount,NULL)), 2) AS '기업고객',
round(avg(if(CustomerSegment='홈오피스',Quantity/Discount,NULL)), 2) AS '홈오피스'
FROM rfm_grade
INNER JOIN orders ON orders.customer_id = rfm_grade.customer_id
WHERE order_id NOT IN (SELECT order_id FROM returns)
GROUP BY class
ORDER BY
CASE class
WHEN 'White' THEN 1
WHEN 'Bronze' THEN 2
WHEN 'Silver' THEN 3
WHEN 'Gold' THEN 4
WHEN 'VIP' THEN 5 END;

-- 할인율 구간에 따른 평균 매출과 수익 → 평균 개당 수익이 0보다 작은 카테고리 존재
SELECT  ProductCategory, ProductSubCategory, 
		case when Discount < 0.1 then 'grp_1' -- 할인율 10%
        when Discount < 0.25 then 'grp_2' -- 할인율 10% ~ 25%
        when Discount < 0.4 then 'grp_3' -- 할인율 20% ~ 40%
        when discount < 0.55 then 'grp_4' -- 할인율 40% ~ 60%
        when discount < 0.7 then 'grp_5' -- 할인율 60% ~ 80%
        else 'grp_6' end as discount_grp, -- 할인율 80% 이상
        count(ProductID) cnt, round(count(ProductId) / sum(count(ProductId)) over(), 2) ratio,
								 -- 같은 제품이어도 할인율이 다르게 적용되어 orderid를 세는 것과 결과는 같음
        round(avg(Sales/Quantity)) avg_unit_sales, 
        round(avg(Profit/Quantity)) avg_unit_profit,
        round(avg(Sales / Quantity * ((1-Discount))), 2) AS avg_product_price,
        round(avg(Discount), 2) avg_discount
FROM orders 
WHERE order_id not in (SELECT order_id FROM returns)
group by ProductCategory, ProductSubCategory, discount_grp
having ProductSubCategory in ('문구류', '책상', '책장')
order by avg_unit_profit desc;

-- 전체 카테고리
SELECT  ProductCategory, ProductSubCategory, 
		case when Discount < 0.1 then 'grp_1' -- 할인율 10%
        when Discount < 0.25 then 'grp_2' -- 할인율 10% ~ 25%
        when Discount < 0.4 then 'grp_3' -- 할인율 20% ~ 40%
        when discount < 0.55 then 'grp_4' -- 할인율 40% ~ 60%
        when discount < 0.7 then 'grp_5' -- 할인율 60% ~ 80%
        else 'grp_6' end as discount_grp, -- 할인율 80% 이상
        count(ProductID) cnt, round(count(ProductId) / sum(count(ProductId)) over(), 2) ratio,
        round(avg(Sales/Quantity)) avg_unit_sales, 
        round(avg(Profit/Quantity)) avg_unit_profit,
        round(avg(Sales / Quantity * ((1-Discount))), 2) AS avg_product_price,
        round(avg(Discount), 2) avg_discount
FROM orders 
WHERE order_id not in (SELECT order_id FROM returns)
group by ProductCategory, ProductSubCategory, discount_grp
order by avg_unit_profit desc;

-- 대량 주문이 많이 발생하는 카테고리 조회
SELECT ProductCategory,
       ProductSubCategory,
       round(avg(Quantity), 2) AS avg_quantity,
       min(Quantity) MIN,
       max(Quantity) MAX,
       round(variance(Quantity), 2) VAR
FROM orders
WHERE order_id NOT IN (SELECT order_id FROM returns)
GROUP BY ProductCategory, ProductSubCategory
ORDER BY avg_quantity DESC;

-- 할인율에 따른 주문량 , 매출 , 수익 평균
SELECT Discount,
       count(DISTINCT order_id) AS order_cnt,
       round(count(DISTINCT order_id) / sum(count(DISTINCT order_id)) OVER(), 2) AS order_ratio,
       sum(Quantity) AS order_quantity,
       round(sum(Quantity) / sum(sum(Quantity)) OVER(), 2) AS quantity_ratio,
       truncate(avg(Sales), 0) AS avg_sales,
	   truncate(avg(Profit), 0) AS avg_profit
FROM rfm_grade t1
INNER JOIN orders t2 ON t1.customer_id = t2.customer_id
WHERE order_id NOT IN (SELECT order_id FROM returns)
GROUP BY Discount
ORDER BY Discount DESC;

-- 지역 관리자 배치 불균형 해소 방안 
SELECT  Area,
	COUNT(DISTINCT s1.Region) AS num_branch,
    COUNT(DISTINCT s2.order_id) as order_cnt,
    ROUND(COUNT(DISTINCT s2.order_id) / COUNT(DISTINCT Region)) AS order_region,
    COUNT(DISTINCT s2.customer_id) AS customer_cnt,
    ROUND(COUNT(DISTINCT s2.customer_id) / COUNT(DISTINCT Region)) AS customer_region
FROM managers s1
LEFT JOIN orders s2 ON s1.Area = s2.AddressRegion
WHERE s2.order_id NOT IN(SELECT order_id FROM returns)
GROUP BY Area
ORDER BY order_region DESC, customer_region DESC;

-- 고객
-- 기존 고객 → RFM 상위 등급 유지를 위한 전략 (경험 개선)
SELECT delivery_mode,
	COUNT(IF(class='VIP',order_id,NULL)) AS VIP,
    COUNT(IF(class='Gold',order_id,NULL)) AS Gold,
    COUNT(IF(class='Silver',order_id,NULL)) AS Silver,
    COUNT(IF(class='Bronze',order_id,NULL)) AS Bronze,
    COUNT(IF(class= 'White',order_id,NULL)) AS White,
    ROUND(COUNT(IF(class='VIP', order_id, NULL)) / SUM(COUNT(IF(class='VIP', order_id, NULL))) OVER(), 2) VIP_RATIO,
    ROUND(COUNT(IF(class='Gold', order_id, NULL)) / SUM(COUNT(IF(class='Gold', order_id, NULL))) OVER(), 2) Gold_RATIO,
    ROUND(COUNT(IF(class='Silver', order_id, NULL)) / SUM(COUNT(IF(class='Silver', order_id, NULL))) OVER(), 2) Silver_RATIO,
    ROUND(COUNT(IF(class='Bronze', order_id, NULL)) / SUM(COUNT(IF(class='Bronze', order_id, NULL))) OVER(), 2) Bronze_RATIO,
    ROUND(COUNT(IF(class='White', order_id, NULL)) / SUM(COUNT(IF(class='White', order_id, NULL))) OVER(), 2) White_RATIO
FROM rfm_grade s1
INNER JOIN orders s2 ON s1.customer_id = s2.customer_id
WHERE order_id NOT IN(SELECT order_id FROM returns)
GROUP BY delivery_mode;

-- 하위 등급 업셀링 방안
-- 기존 하위 등급 고객을 차상위 고객 등급으로 전환하기 위해 재구매 주기를 고려한 업셀링
SELECT
    class,
    AVG(diff) AS avg_purchase_diff
FROM (
    SELECT
        o.customer_id,
        r.class,
        DATEDIFF(
            LEAD(order_timestamp) OVER(PARTITION BY o.customer_id ORDER BY order_timestamp),
            order_timestamp
        ) AS diff
    FROM orders o
    INNER JOIN rfm_grade r ON o.customer_id = r.customer_id
    WHERE o.order_id NOT IN (SELECT order_id FROM returns)
) t1
GROUP BY class;

-- 신규 고객
-- 신규 고객 유입을 위한 전략
-- 첫 구매 고객의 구입 요일과 시간 파악
WITH s1 AS
(
SELECT customer_id,
	MIN(order_timestamp) as first_purchase,
    HOUR(MIN(order_timestamp)) AS first_purchase_hour
FROM orders
WHERE order_id NOT IN (SELECT order_id FROM returns)
GROUP BY customer_id
)
SELECT first_purchase_hour,
		COUNT(DISTINCT if(dayname(first_purchase) = 'Monday', customer_id, null)) Monday,
		COUNT(DISTINCT if(dayname(first_purchase) = 'Tuesday', customer_id, null)) Tuesday,
		COUNT(DISTINCT if(dayname(first_purchase) = 'Wednesday', customer_id, null)) Wednesday,
		COUNT(DISTINCT if(dayname(first_purchase) = 'Thursday', customer_id, null)) Thursday,
		COUNT(DISTINCT if(dayname(first_purchase) = 'Friday', customer_id, null)) Friday,
		COUNT(DISTINCT if(dayname(first_purchase) = 'Saturday', customer_id, null)) Saturday,
		COUNT(DISTINCT if(dayname(first_purchase) = 'Sunday', customer_id, null)) Sunday
FROM s1
GROUP BY first_purchase_hour
ORDER BY first_purchase_hour;

-- 첫 구매 고객의 구매 카테고리 
WITH s1 AS
(
SELECT customer_id,
	   ProductCategory, ProductSubCategory,
       AVG(Sales) AS avg_sales,
       AVG(Quantity) AS avg_quantity,
       MIN(order_timestamp) AS first_purchase
FROM orders
WHERE order_id NOT IN (SELECT order_id FROM returns)
GROUP BY customer_id,
	   ProductCategory, ProductSubCategory
)
SELECT ProductCategory,ProductSubCategory,
	COUNT(*) AS order_cnt,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER(),2) AS  orders_ratio,
    ROUND(AVG(avg_quantity),2) AS avg_quantity,
    ROUND(AVG(avg_sales)) AS avg_sales,
    ROUND(AVG(avg_sales/avg_quantity),0) AS avg_unit_sales
FROM s1
GROUP BY ProductCategory, ProductSubCategory
ORDER BY orders_ratio DESC, avg_sales DESC;

-- 첫 구매 고객과 기존 고객의 카테고리별 구매 비교
WITH s1 AS 
(
SELECT order_id,order_timestamp,customer_id,CustomerSegment,ProductID,ProductCategory,ProductSubCategory,
	ROUND(Sales / Quantity) unit_sales,
		ROUND(Profit / Quantity) unit_profit,
        Discount, 
dense_rank() over(partition by customer_id order by order_id) AS order_freq -- 누적 구매 빈도
FROM orders
WHERE order_id NOT IN (SELECT order_id FROM returns)
)
SELECT ProductCategory , ProductSubCategory,
	round(count(if(order_freq = 1, order_id, null)) / sum(count(if(order_freq = 1, order_id, null))) over(), 2) first_order_cnt_ratio, 
		round(avg(if(order_freq = 1, unit_sales, null))) first_avg_unit_sales,
        round(avg(if(order_freq = 1, unit_profit, null))) first_avg_unit_profit,
        round(avg(if(order_freq = 1, discount, null)), 2) first_avg_discount,
		round(count(if(order_freq != 1, order_id, null)) / sum(count(if(order_freq != 1, order_id, null))) over(), 2) nth_order_cnt_ratio,
		round(avg(if(order_freq != 1, unit_sales, null))) nth_avg_unit_sales,
        round(avg(if(order_freq != 1, unit_profit, null))) nth_avg_unit_profit,
        round(avg(if(order_freq != 1, discount, null)), 2) nth_avg_discount
FROM s1
GROUP BY ProductCategory , ProductSubCategory
ORDER BY ProductCategory , ProductSubCategory DESC;

