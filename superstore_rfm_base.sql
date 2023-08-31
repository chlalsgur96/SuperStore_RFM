-- R 지표: 오늘을 2020-12-31로 가정 
-- returend 된 고객 제외후 791 
SELECT MAX(OrderTimestamp) FROM Orders;

-- RFM BASSE
SELECT CustomerID, 
		MAX(OrderTimestamp) AS R,
		COUNT(DISTINCT OrderID) AS F,
		ROUND(SUM(sales),2) AS M
FROM Orders 
WHERE OrderID NOT IN (SELECT OrderID FROM Returns)
GROUP BY CustomerID
ORDER BY CustomerID 
LIMIT 10;


-- 고객별 Recency 산출
  SELECT CustomerID, 
			DATEDIFF('2020-12-31',MAX(OrderTimestamp)) AS R,
            MAX(OrderTimestamp) AS R_sub,
			COUNT(DISTINCT OrderID) AS F,
			ROUND(SUM(sales),2) AS M
	FROM   orders 
	WHERE OrderID NOT IN (SELECT OrderID FROM Returns)
    GROUP BY CustomerID
    ORDER BY CustomerID
    LIMIT 10;
    
        
-- RFM 별 percent rank 산출
SELECT CustomerID,
	   R , R_sub , F , M,
       ROUND(PERCENT_RANK() OVER(ORDER BY R DESC),2) AS R_rk,
       ROUND(PERCENT_RANK() OVER(ORDER BY F),2) AS F_rk,
       ROUND(PERCENT_RANK() OVER(ORDER BY M),2) AS M_rk
FROM (
	 SELECT CustomerID, 
			DATEDIFF('2020-12-31',MAX(OrderTimestamp)) AS R,
            MAX(OrderTimestamp) AS R_sub,
			COUNT(DISTINCT OrderID) AS F,
			ROUND(SUM(Sales),2) AS M
	FROM   orders 
	WHERE OrderID NOT IN (SELECT OrderID FROM Returns)
	GROUP BY     CustomerID
    ORDER BY CustomerID
    LIMIT 10
    ) T1; 
    
    
SELECT
    CustomerID,
    COUNT(DISTINCT OrderID) AS F,
    ROUND(CUME_DIST() OVER(ORDER BY COUNT(DISTINCT OrderID)), 2) AS F_ratio
FROM
    Orders
WHERE OrderID NOT IN (SELECT OrderID FROM Returns)
GROUP BY CustomerID
ORDER BY CustomerID
LIMIT 10;

--  F 고객 구매 빈도를 사분위 수로 그룹화 
SELECT
	CASE WHEN F < 0.25 THEN 'F1'
		  WHEN F between 0.25 AND 0.5 THEN 'F2'
		  WHEN F between 0.5 AND 0.75 THEN  'F3'
         ELSE 'F4'
	END AS F_group,
    COUNT(*) AS cus_cnt,
    COUNT(*)*100 / SUM(COUNT(*)) OVER() AS portion
FROM (
	SELECT CustomerID,
		COUNT(DISTINCT OrderID) AS F
    FROM
		orders 
	WHERE OrderID NOT IN (SELECT OrderID FROM Returns)
    GROUP BY CustomerID
    ) AS t
    GROUP BY F_group;

WITH s1 AS (    
 SELECT CustomerID,
  COUNT(DISTINCT OrderID) AS F,
  ROUND(PERCENT_RANK() OVER(ORDER BY COUNT(DISTINCT OrderID)), 2) AS F_rk
 FROM orders
 GROUP BY CustomerID
 )
 SELECT
  CASE WHEN F_rk < 0.25 THEN 'F1'
     WHEN F_rk BETWEEN 0.25 AND 0.5 THEN 'F2'
     WHEN F_rk BETWEEN 0.5 AND 0.75 THEN  'F3'
          ELSE 'F4'
  END AS F_group,
     COUNT(*) AS cus_cnt,
     COUNT(*)*100 / SUM(COUNT(*)) OVER() AS portion
 FROM s1
 GROUP BY F_group
 ORDER BY 1;
 
 WITH S AS (
    SELECT
        CustomerID,
        ROUND(SUM(Sales), 2) AS Sales,
        PERCENT_RANK() OVER (ORDER BY ROUND(SUM(Sales), 2)) AS M_rk
    FROM
        Orders
    WHERE OrderID NOT IN (SELECT OrderID FROM Returns)
    GROUP BY
        CustomerID
)
SELECT 
    MIN(Sales) AS min,
    MAX(CASE WHEN M_rk <= 0.25 THEN Sales END) AS q1,
    MAX(CASE WHEN M_rk <= 0.5 THEN Sales END) AS q2,
    MAX(CASE WHEN M_rk <= 0.75 THEN Sales END) AS q3,
    MAX(Sales) AS max
FROM S;

-- RFM 점수 산정을 위한 view 
CREATE VIEW RFM_VW AS
SELECT CustomerID, R, R_sub, F, M, R_rk, F_rk, M_rk,
			CASE WHEN R_rk < 0.25 THEN 1
					 WHEN R_rk between 0.25 AND 0.5 THEN 2
					 WHEN R_rk between 0.5 AND 0.75 THEN 3
					 ELSE 4 END AS R_score,
			CASE WHEN F_rk < 0.25 THEN 1
					 WHEN F_rk between 0.25 AND 0.5 THEN 2
					 WHEN F_rk between 0.5 AND 0.75 THEN 3
					 ELSE 4 END AS F_score,
			CASE WHEN M_rk < 0.25 THEN 1
					 WHEN M_rk between 0.25 AND 0.5 THEN 2
					 WHEN M_rk between 0.5 AND 0.75 THEN 3
					 ELSE 4 END AS M_score
FROM
(
SELECT CustomerID,
       R, R_sub, F, M,
			 round(PERCENT_RANK() OVER(ORDER BY R desc), 2) AS R_rk,
			 round(PERCENT_RANK() OVER(ORDER BY F), 2) AS F_rk,
			 round(PERCENT_RANK() OVER(ORDER BY M), 2) AS M_rk
FROM
(
SELECT CustomerID,
       DATEDIFF('2020-12-31', MAX(OrderTimestamp)) AS R,
       MAX(OrderTimestamp) AS R_sub,
       COUNT(DISTINCT OrderID) AS F,
       ROUND(SUM(Sales), 2) AS M
FROM orders
WHERE Orderid NOT IN (SELECT Orderid FROM returns)
GROUP BY CustomerID) t1) t2;


-- RFM 지표별 매출 기여효과 
-- R_score
SELECT R_score , COUNT(*) R_CNT,
			COUNT(*)/SUM(COUNT(*)) OVER() AS R_raion,
            ROUND(SUM(m),2) AS R_revenue,
			ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
            ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY R_score
ORDER BY R_score;

SELECT SUM(contributing_effect) AS R_contributing_effect
FROM(
SELECT R_score , COUNT(*) R_CNT,
			COUNT(*)/SUM(COUNT(*)) OVER() AS R_raion,
            ROUND(SUM(M),2) AS R_revenue,
			ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
            ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY R_score
ORDER BY 1) as r1;

-- F_score
SELECT F_score, count(*) CNT, 
		count(*) / sum(count(*)) over() AS user_ratio,
		ROUND(sum(m), 2) AS revenue,
		ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
        ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
group by F_score;


SELECT SUM(contributing_effect) AS F_contributing_effect
FROM(
SELECT F_score , COUNT(*) F_CNT,
			COUNT(*)/SUM(COUNT(*)) OVER() AS F_raion,
            ROUND(SUM(M),2) AS R_revenue,
            ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
            ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY F_score
) F1;

SELECT M_score, count(*) CNT, 
		count(*) / sum(count(*)) over() AS user_ratio,
		ROUND(sum(m), 2) AS revenue,
		ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
        ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY M_score;

SELECT SUM(contributing_effect) AS M_contributing_effect
FROM(
SELECT M_score , COUNT(*) M_CNT,
			COUNT(*)/SUM(COUNT(*)) OVER() AS F_raion,
            ROUND(SUM(M),2) AS R_revenue,
            ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
            ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY M_score
) M1;


-- RFM 모형 탐색
-- 가중치 (1,1,1)
SELECT (R_score + F_score + M_score) AS total_score,
       R_score, F_score, M_score,
       COUNT(*) AS cnt,
       COUNT(*) / (SELECT COUNT(*) FROM rfm_vw) AS ratio
FROM rfm_vw
GROUP BY total_score, R_score, F_score, M_score;

-- R_vw
CREATE VIEW R_vw AS
SELECT SUM(contributing_effect) AS R_contributing_effect
FROM(
SELECT R_score , COUNT(*) R_CNT,
			COUNT(*)/SUM(COUNT(*)) OVER() AS R_raion,
            ROUND(SUM(M),2) AS R_revenue,
			ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
            ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY R_score
ORDER BY 1) as r1;


-- F_vw
CREATE VIEW F_vw AS
SELECT SUM(contributing_effect) AS F_contributing_effect
FROM(
SELECT F_score , COUNT(*) F_CNT,
			COUNT(*)/SUM(COUNT(*)) OVER() AS F_raion,
            ROUND(SUM(M),2) AS R_revenue,
            ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
            ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY F_score
) F1; 

-- M_vw
CREATE VIEW M_vw AS
SELECT SUM(contributing_effect) AS M_contributing_effect
FROM(
SELECT M_score , COUNT(*) M_CNT,
			COUNT(*)/SUM(COUNT(*)) OVER() AS F_raion,
            ROUND(SUM(M),2) AS R_revenue,
            ROUND(sum(m) / sum(sum(m)) over(), 2) AS revenue_contributing,
            ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS contributing_effect
FROM rfm_vw
GROUP BY M_score
) M1;

-- 매출 기여 효과 비중을 가중치로 산정
WITH S AS (
SELECT
	(SELECT SUM(R_contributing_effect) FROM r_vw) AS total_R_contribution,
	(SELECT SUM(F_contributing_effect) FROM f_vw) AS total_F_contribution,
	(SELECT SUM(M_contributing_effect) FROM m_vw) AS total_M_contribution)
SELECT ROUND(total_R_contribution / (total_R_contribution + total_F_contribution + total_M_contribution), 2) AS R_weight,
			 ROUND(total_F_contribution / (total_R_contribution + total_F_contribution + total_M_contribution), 2) AS F_weight,
			 ROUND(total_M_contribution / (total_R_contribution + total_F_contribution + total_M_contribution), 2) AS M_weight
FROM S;

select *,
     round(r_score*0.32 + f_score*0.35 + m_score*0.33, 2) as total_score
from rfm_vw
ORDER BY total_score 
LIMIT 10;



    
	
