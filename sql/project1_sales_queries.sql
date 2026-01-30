WITH monthly_sales AS (
  SELECT strftime('%Y-%m', OrderDate) AS Month, SUM(Revenue) AS TotalRevenue
  FROM Orders
  GROUP BY 1
)
SELECT Month, TotalRevenue,
       LAG(TotalRevenue) OVER(ORDER BY Month) AS PrevMonthRevenue
FROM monthly_sales;