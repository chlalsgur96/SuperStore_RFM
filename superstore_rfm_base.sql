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
GROUP BY CustomerID;

-- 고객별 Recency 산출
  SELECT CustomerID, 
			DATEDIFF('2020-12-31',MAX(OrderTimestamp)) AS R,
            MAX(OrderTimestamp) AS R_sub,
			COUNT(DISTINCT OrderID) AS F,
			ROUND(SUM(sales),2) AS M
	FROM   orders 
	WHERE OrderID NOT IN (SELECT OrderID FROM Returns)
    GROUP BY CustomerID;
    
    
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
    ) T1; 
    
   --  F : 고객 구매 빈도 
    SELECT
    CustomerID,
    COUNT(DISTINCT OrderID) AS F,
    ROUND(CUME_DIST() OVER(ORDER BY COUNT(DISTINCT OrderID)), 2) AS F_ratio
FROM
    Orders
WHERE OrderID NOT IN (SELECT OrderID FROM Returns)
GROUP BY CustomerID;

-- M :고객 별 구매 금액 사분위수
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

-- RFM 점수 산정 
SELECT CustomerID, 
		DATEDIFF('2020-12-31',MAX(OrderTimestamp)) AS R,
		COUNT(DISTINCT OrderID) AS F,
		ROUND(SUM(sales),2) AS M
FROM Orders 
WHERE OrderID NOT IN (SELECT OrderID FROM Returns)
GROUP BY CustomerID;


/* RFM RESULT DATA */

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





-- RFM SCORE VW
CREATE VIEW RFMvw AS
WITH RFM_base AS (
    SELECT 
        CustomerID,
        MAX(OrderTimestamp) AS R_date,
        TIMESTAMPDIFF(DAY, MAX(OrderTimestamp), '2020-12-31') AS R,
        COUNT(DISTINCT OrderID) AS F,
        SUM(Sales) AS M
    FROM Orders
    WHERE OrderID NOT IN (SELECT OrderID FROM Returns)
    GROUP BY CustomerID
)
SELECT 
    CustomerID,
    R,
    F,
    M,
    CASE 
        WHEN R < 0.25 THEN '1'
        WHEN  R between 0.25 AND 0.5 THEN '2'
        WHEN R between 0.5 AND 0.75 THEN '3'
        ELSE '4'
    END AS R_score,
    CASE 
        WHEN F < 0.25 THEN '1'
        WHEN F < 0.5 THEN '2'
        WHEN F < 0.75 THEN '3'
        ELSE '4'
    END AS F_score,
    CASE 
        WHEN M < 0.25 THEN '1'
        WHEN M < 0.5 THEN '2'
        WHEN M < 0.75 THEN '3'
        ELSE '4'
    END AS M_score
FROM RFM_base;


-- RFM 지표별 매출 기여효과 
SELECT r_score, count(*) CNT, 
		count(*) / sum(count(*)) over() AS '유저 비율',
		ROUND(sum(m), 2) AS '매출',
		ROUND(sum(m) / sum(sum(m)) over(), 2) AS '매출 기여도',
        ROUND((sum(m) / sum(sum(m)) over()) / (count(*) / sum(count(*)) over()), 3) AS '기여 효과'
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
