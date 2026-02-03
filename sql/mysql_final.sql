
-- =========================================================
USE Ecommerce_Analysis;

DROP TABLE IF EXISTS StagingOrders;
DROP TABLE IF EXISTS OrdersWithRevenue;
DROP VIEW IF EXISTS vw_PowerBI_Ecommerce;



-- STAGING TABLE 
-- =========================================================
CREATE TABLE StagingOrders (
    InvoiceNo TEXT,
    StockCode TEXT,
    Description TEXT,
    Quantity TEXT,
    InvoiceDate TEXT,
    UnitPrice TEXT,
    CustomerID TEXT,
    Country TEXT
);



-- CSV DATA INGESTION 
-- =========================================================
LOAD DATA LOCAL INFILE 'C:/Users/svitl/Documents/Portfolio/junior-data-analyst-portfolio/datasets/e_comm.csv'
INTO TABLE StagingOrders
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;



-- FINAL TABLE WITH GENERATED REVENUE COLUMN
-- =========================================================
CREATE TABLE OrdersWithRevenue (
    InvoiceNo VARCHAR(50),
    StockCode VARCHAR(50),
    Description TEXT,
    Quantity INT,
    InvoiceDate DATETIME,
    UnitPrice DECIMAL(18,2),
    CustomerID INT,
    Country VARCHAR(100),

    Revenue DECIMAL(18,2)
        GENERATED ALWAYS AS (Quantity * UnitPrice) STORED
);



-- TRANSFORMATION, CLEANING & "SHIFTED ROW" RECOVERY
-- =========================================================
INSERT INTO OrdersWithRevenue (
    InvoiceNo, StockCode, Description, Quantity,
    InvoiceDate, UnitPrice, CustomerID, Country
)
SELECT
    TRIM(InvoiceNo),
    TRIM(StockCode),
    TRIM(Description),

    -- Quantity
    CAST(NULLIF(Quantity, '') AS SIGNED),

    -- Invoice Date conversion 
    STR_TO_DATE(InvoiceDate, '%m/%d/%Y %H:%i'),


    CASE
        WHEN Country LIKE '%,%' 
            THEN CAST(SUBSTRING_INDEX(Country, ',', 1) AS DECIMAL(18,2))
        ELSE CAST(NULLIF(UnitPrice, '') AS DECIMAL(18,2))
    END,

    -- Extract CustomerID from shifted Country string
    CASE
        WHEN Country LIKE '%,%' 
            THEN CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(Country, ',', 2), ',', -1) AS SIGNED)
        ELSE CAST(NULLIF(CustomerID, '') AS SIGNED)
    END,

    -- Clean hidden characters from Country
    TRIM(
        REPLACE(
            REPLACE(
                REPLACE(
                    CASE
                        WHEN Country LIKE '%,%' 
                            THEN SUBSTRING_INDEX(Country, ',', -1)
                        ELSE Country
                    END,
                '\r',''),
            '\n',''),
        UNHEX('A0'),' ')
    )

FROM StagingOrders
WHERE InvoiceNo IS NOT NULL;



-- GLOBAL REVENUE PERFORMANCE
-- =========================================================
SELECT 
    Country,
    ROUND(SUM(Revenue), 2) AS TotalRevenue,
    COUNT(DISTINCT InvoiceNo) AS OrderCount,
    COUNT(DISTINCT CustomerID) AS UniqueCustomers
FROM OrdersWithRevenue
GROUP BY Country
ORDER BY SUM(Revenue) DESC;



-- TOP 5 BEST SELLING PRODUCTS (excluding returns)
-- =========================================================
SELECT 
    Description,
    SUM(Quantity) AS UnitsSold,
    ROUND(SUM(Revenue), 2) AS TotalRevenue
FROM OrdersWithRevenue
WHERE Quantity > 0
GROUP BY Description
ORDER BY SUM(Revenue) DESC
LIMIT 5;



--  RETURN RATE ANALYSIS BY COUNTRY
-- =========================================================
SELECT 
    Country,
    ROUND(SUM(CASE WHEN Quantity < 0 THEN Revenue ELSE 0 END), 2) AS TotalRefunded,

    ROUND(
        (
            SUM(CASE WHEN Quantity < 0 THEN Revenue ELSE 0 END) /
            NULLIF(SUM(CASE WHEN Quantity > 0 THEN Revenue ELSE 0 END), 0)
        ) * -100, 2
    ) AS ReturnRatePct

FROM OrdersWithRevenue
GROUP BY Country
HAVING SUM(CASE WHEN Quantity < 0 THEN Revenue ELSE 0 END) < 0
ORDER BY ReturnRatePct DESC;



-- POWER BI VIEW
-- =========================================================
CREATE OR REPLACE VIEW vw_PowerBI_Ecommerce AS
SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,

    YEAR(InvoiceDate) AS InvoiceYear,
    MONTH(InvoiceDate) AS InvoiceMonth,

    UnitPrice,
    CustomerID,
    Country,
    Revenue,

    CASE
        WHEN Quantity < 0 THEN 'Return'
        ELSE 'Sales'
    END AS TransactionType

FROM OrdersWithRevenue
WHERE Country <> 'Unspecified';
