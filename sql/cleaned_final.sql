USE Ecommerce_Analysis;
GO


DROP TABLE IF EXISTS StagingOrders;
DROP TABLE IF EXISTS OrdersWithRevenue;
GO


CREATE TABLE StagingOrders (
    InvoiceNo NVARCHAR(MAX),
    StockCode NVARCHAR(MAX),
    Description NVARCHAR(MAX),
    Quantity NVARCHAR(MAX),
    InvoiceDate NVARCHAR(MAX),
    UnitPrice NVARCHAR(MAX),
    CustomerID NVARCHAR(MAX),
    Country NVARCHAR(MAX)
);
GO


-- 2. DATA INGESTION 
-----------------------------------------------------------
BULK INSERT StagingOrders
FROM 'C:\Users\svitl\Documents\Portfolio\junior-data-analyst-portfolio\datasets\e_comm.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a', -- Handles \n and \r\n effectively
    CODEPAGE = '65001',     -- UTF-8 Support
    TABLOCK
);
GO


-- FINAL TABLE STRUCTURE
-----------------------------------------------------------
CREATE TABLE OrdersWithRevenue (
    InvoiceNo NVARCHAR(50),
    StockCode NVARCHAR(50),
    Description NVARCHAR(MAX),
    Quantity INT,
    InvoiceDate DATETIME,
    UnitPrice DECIMAL(18,2),
    CustomerID INT,
    Country NVARCHAR(100),
    -- Computed column for automated math
    Revenue AS (CAST(Quantity AS DECIMAL(18,2)) * UnitPrice) PERSISTED
);
GO


-- TRANSFORMATION & DATA RECOVERY
-- "shifted" rows and cleans invisible characters
-----------------------------------------------------------
INSERT INTO OrdersWithRevenue (
    InvoiceNo, StockCode, Description, Quantity, 
    InvoiceDate, UnitPrice, CustomerID, Country
)
SELECT 
    TRIM(InvoiceNo),
    TRIM(StockCode),
    TRIM(Description),
    TRY_CAST(Quantity AS INT),
    TRY_CAST(InvoiceDate AS DATETIME),
    -- If Country has commas, the Price is actually the first part of that string
    CASE 
        WHEN Country LIKE '%,%' THEN TRY_CAST(LEFT(Country, CHARINDEX(',', Country) - 1) AS DECIMAL(18,2))
        ELSE TRY_CAST(UnitPrice AS DECIMAL(18,2)) 
    END,
    -- Extract CustomerID from middle of shifted Country string
    CASE 
        WHEN Country LIKE '%,%' THEN TRY_CAST(PARSENAME(REPLACE(Country, ',', '.'), 2) AS INT)
        ELSE TRY_CAST(NULLIF(TRIM(CustomerID), '') AS INT)
    END,
    -- Remove hidden  (CHAR 13) and non-breaking spaces (CHAR 160)
    TRIM(REPLACE(REPLACE(REPLACE(
        CASE 
            WHEN Country LIKE '%,%' THEN PARSENAME(REPLACE(Country, ',', '.'), 1)
            ELSE Country 
        END, 
    CHAR(13), ''), CHAR(10), ''), CHAR(160), ' '))
FROM StagingOrders
WHERE InvoiceNo IS NOT NULL;
GO



--  ANALYTICAL REPORTS
-----------------------------------------------------------

-- A. Global Revenue Performance
SELECT 
    Country, 
    FORMAT(SUM(Revenue), 'C', 'en-US') AS TotalRevenue,
    COUNT(DISTINCT InvoiceNo) AS OrderCount,
    COUNT(DISTINCT CustomerID) AS UniqueCustomers
FROM OrdersWithRevenue
GROUP BY Country
ORDER BY SUM(Revenue) DESC;

-- B. Top 5 Best Selling Products (Excluding Returns)
SELECT TOP 5 
    Description, 
    SUM(Quantity) AS UnitsSold, 
    FORMAT(SUM(Revenue), 'C', 'en-US') AS TotalRevenue
FROM OrdersWithRevenue
WHERE Quantity > 0
GROUP BY Description
ORDER BY SUM(Revenue) DESC;

-- C. Return Rate Analysis by Country
SELECT 
    Country,
    FORMAT(SUM(CASE WHEN Quantity < 0 THEN Revenue ELSE 0 END), 'C', 'en-US') AS TotalRefunded,
    CAST((SUM(CASE WHEN Quantity < 0 THEN Revenue ELSE 0 END) / 
          NULLIF(SUM(CASE WHEN Quantity > 0 THEN Revenue ELSE 0 END), 0)) * -100 AS DECIMAL(10,2)) AS ReturnRatePct
FROM OrdersWithRevenue
GROUP BY Country
HAVING SUM(CASE WHEN Quantity < 0 THEN Revenue ELSE 0 END) < 0
ORDER BY ReturnRatePct DESC;
GO