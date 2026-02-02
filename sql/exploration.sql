USE Ecommerce_Analysis;

-- Check first 10 rows
SELECT TOP 10 * FROM EcommerceData;

-- Total rows
SELECT COUNT(*) AS TotalOrders FROM EcommerceData;

-- Revenue summary
SELECT SUM(Revenue) AS TotalRevenue, AVG(Revenue) AS AvgRevenue
FROM EcommerceData;

-- Check date range
SELECT MIN(OrderDate) AS FirstOrder, MAX(OrderDate) AS LastOrder
FROM EcommerceData;


WITH Deduplicated AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY OrderID ORDER BY OrderDate) AS rn
    FROM EcommerceStaging
    WHERE ISDATE(OrderDate) = 1
      AND TRY_CAST(OrderID AS INT) IS NOT NULL
)

INSERT INTO EcommerceData (OrderID, CustomerName, Email, Country, OrderDate, Revenue, ProductName, Category)
SELECT
    TRY_CAST(OrderID AS INT),
    CustomerName,
    Email,
    Country,
    CAST(OrderDate AS DATE),
    TRY_CAST(Revenue AS DECIMAL(10,2)),
    ProductName,
    Category
FROM Deduplicated
WHERE rn = 1;
GO

-- STEP 7: Basic Analysis 


--  Total orders and total revenue
SELECT COUNT(*) AS TotalOrders,
       SUM(Revenue) AS TotalRevenue
FROM EcommerceData;
GO

-- Top 10 customers by revenue
SELECT CustomerName,
       Email,
       Country,
       COUNT(OrderID) AS OrdersCount,
       SUM(Revenue) AS TotalRevenue
FROM EcommerceData
GROUP BY CustomerName, Email, Country
ORDER BY TotalRevenue DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;
GO

--  Monthly revenue trend
SELECT FORMAT(OrderDate, 'yyyy-MM') AS YearMonth,
       SUM(Revenue) AS MonthlyRevenue
FROM EcommerceData
GROUP BY FORMAT(OrderDate, 'yyyy-MM')
ORDER BY YearMonth;
GO

--  Repeat customers: number of orders per customer
SELECT CustomerName,
       COUNT(OrderID) AS OrdersCount
FROM EcommerceData
GROUP BY CustomerName
HAVING COUNT(OrderID) > 1
ORDER BY OrdersCount DESC;
GO


-- Some rows had missing ProductName. For analysis, excluded or labeled them as ‘Unknown’
SELECT ISNULL(ProductName, 'Unknown') AS ProductName,
       SUM(Revenue) AS ProductRevenue,
       SUM(Revenue)/SUM(SUM(Revenue)) OVER() * 100 AS RevenuePercent
FROM EcommerceData
GROUP BY ISNULL(ProductName, 'Unknown')
ORDER BY ProductRevenue DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;