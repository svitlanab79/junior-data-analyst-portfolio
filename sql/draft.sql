USE Ecommerce_Analysis;
GO

-- Disable foreign key constraints temporarily
EXEC sp_msforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT ALL";

-- Drop all tables
EXEC sp_msforeachtable "DROP TABLE ?";




-- Step 1: Create staging table to hold CSV data
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

-- Step 2: Bulk insert CSV into staging table
BULK INSERT StagingOrders
FROM 'C:\Users\svitl\Documents\Portfolio\junior-data-analyst-portfolio\datasets\e_comm.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a', -- This handles both \n and \r\n more gracefully
    CODEPAGE = '65001',
    TABLOCK
);
GO

-- Step 3: Create final table including Revenue
CREATE TABLE OrdersWithRevenue (
    InvoiceNo VARCHAR(50),
    StockCode VARCHAR(50),
    Description VARCHAR(MAX),
    Quantity VARCHAR(50),
    InvoiceDate DATETIME,
    UnitPrice DECIMAL(10,2),
    CustomerID INT,
    Country VARCHAR(50),
    Revenue AS (Quantity * UnitPrice) PERSISTED
);
GO

INSERT INTO OrdersWithRevenue (
    InvoiceNo, 
    StockCode, 
    Description, 
    Quantity, 
    InvoiceDate, 
    UnitPrice, 
    CustomerID, 
    Country
)
SELECT 
    InvoiceNo, 
    StockCode, 
    Description, 
    TRY_CAST(Quantity AS INT),
    -- Style 101 or 103 handles many MM/DD/YYYY formats. 
    -- TRY_CAST usually handles 'YYYY-MM-DD HH:MM', but for 'M/D/YYYY', 
    -- CASTing to DATETIME first is safer.
    CAST(TRY_CAST(InvoiceDate AS DATETIME) AS DATE), 
    TRY_CAST(UnitPrice AS DECIMAL(10,2)), 
    -- This handles the ,, (Empty string) by turning it into a NULL INT
    TRY_CAST(NULLIF(CustomerID, '') AS INT), 
    Country
FROM StagingOrders
WHERE InvoiceNo IS NOT NULL;
GO



TRUNCATE TABLE StagingOrders;
GO

INSERT INTO StagingOrders
SELECT * FROM OPENROWSET(
   BULK 'C:\Users\svitl\Documents\Portfolio\junior-data-analyst-portfolio\datasets\e_comm.csv',
   FORMAT = 'CSV',
   FIRSTROW = 2,
   FIELDQUOTE = '"'  -- This is the magic fix for commas/newlines in quotes
) AS t1;


DROP TABLE IF EXISTS StagingOrders;
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

BULK INSERT StagingOrders
FROM 'C:\Users\svitl\Documents\Portfolio\junior-data-analyst-portfolio\datasets\e_comm.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a', -- Hex for Line Feed (\n)
    CODEPAGE = '65001',     -- UTF-8
    TABLOCK
);
GO

SELECT TOP 10 * FROM StagingOrders;

INSERT INTO OrdersWithRevenue (
    InvoiceNo, 
    StockCode, 
    Description, 
    Quantity, 
    InvoiceDate, 
    UnitPrice, 
    CustomerID, 
    Country
)
SELECT 
    TRIM(InvoiceNo), 
    TRIM(StockCode), 
    TRIM(Description), 
    TRY_CAST(Quantity AS INT), 
    -- Handling the MM/DD/YYYY HH:MM format
    TRY_CAST(InvoiceDate AS DATETIME), 
    TRY_CAST(UnitPrice AS DECIMAL(10,2)), 
    TRY_CAST(NULLIF(TRIM(CustomerID), '') AS INT), 
    TRIM(Country)
FROM StagingOrders
WHERE InvoiceNo IS NOT NULL;

SELECT 
    Country, 
    SUM(Quantity * UnitPrice) AS NetRevenue
FROM OrdersWithRevenue
GROUP BY Country
ORDER BY NetRevenue DESC;

SELECT 
    Country,
    SUM(CASE WHEN Quantity > 0 THEN Revenue ELSE 0 END) AS GrossSales,
    SUM(CASE WHEN Quantity < 0 THEN Revenue ELSE 0 END) AS TotalReturns,
    (SUM(CASE WHEN Quantity < 0 THEN Revenue ELSE 0 END) / 
     NULLIF(SUM(CASE WHEN Quantity > 0 THEN Revenue ELSE 0 END), 0)) * 100 AS ReturnRatePercentage
FROM OrdersWithRevenue
GROUP BY Country
ORDER BY GrossSales DESC;


UPDATE OrdersWithRevenue
SET 
    -- PARSENAME is a trick to split strings by dots, but here we'll use a CASE or string logic
    -- Since your data is 'Price,ID,Country', we split by comma:
    Country = REVERSE(LEFT(REVERSE(Country), CHARINDEX(',', REVERSE(Country)) - 1)),
    UnitPrice = TRY_CAST(LEFT(Country, CHARINDEX(',', Country) - 1) AS DECIMAL(10,2))
WHERE Country LIKE '%,%';

SELECT COUNT(*) as BrokenRows 
FROM StagingOrders 
WHERE Country LIKE '%,%';


INSERT INTO OrdersWithRevenue (InvoiceNo, StockCode, Description, Quantity, InvoiceDate, UnitPrice, CustomerID, Country)
SELECT 
    InvoiceNo, 
    StockCode, 
    Description, 
    TRY_CAST(Quantity AS INT), 
    TRY_CAST(InvoiceDate AS DATETIME),
    -- CASE 1: The row is broken (Country contains commas)
    CASE 
        WHEN Country LIKE '%,%' THEN TRY_CAST(LEFT(Country, CHARINDEX(',', Country) - 1) AS DECIMAL(10,2))
        ELSE TRY_CAST(UnitPrice AS DECIMAL(10,2)) 
    END AS UnitPrice,
    CASE 
        WHEN Country LIKE '%,%' THEN TRY_CAST(PARSENAME(REPLACE(Country, ',', '.'), 2) AS INT)
        ELSE TRY_CAST(NULLIF(CustomerID, '') AS INT)
    END AS CustomerID,
    CASE 
        WHEN Country LIKE '%,%' THEN PARSENAME(REPLACE(Country, ',', '.'), 1)
        ELSE TRIM(Country)
    END AS Country
FROM StagingOrders
WHERE InvoiceNo IS NOT NULL;

SELECT Country, SUM(Revenue) AS TotalRevenue
FROM OrdersWithRevenue
WHERE Country = 'France'
GROUP BY Country;

SELECT TOP 10 
    '[' + Country + ']' AS CountryWithBrackets, -- Shows hidden spaces
    Revenue,
    UnitPrice,
    CustomerID
FROM OrdersWithRevenue
WHERE Country LIKE '%France%';

SELECT 
    Country AS Original,
    -- This looks scary but it just grabs everything after the LAST comma
    TRIM(REVERSE(LEFT(REVERSE(Country), CHARINDEX(',', REVERSE(Country) + ',') - 1))) AS CleanedCountry
FROM StagingOrders
WHERE Country LIKE '%,%';

UPDATE OrdersWithRevenue
SET Country = TRIM(REVERSE(LEFT(REVERSE(Country), CHARINDEX(',', REVERSE(Country) + ',') - 1)))
WHERE Country LIKE '% ' OR Country LIKE '%,%';
GO

UPDATE OrdersWithRevenue
SET Country = REPLACE(REPLACE(REPLACE(Country, CHAR(13), ''), CHAR(10), ''), CHAR(9), '');
GO

SELECT TRIM(Country) AS Country, SUM(Revenue) AS TotalRevenue
FROM OrdersWithRevenue
WHERE TRIM(Country) = 'France'
GROUP BY TRIM(Country);

UPDATE OrdersWithRevenue
SET Country = TRIM(REVERSE(LEFT(REVERSE(Country), CHARINDEX(',', REVERSE(Country) + ',') - 1)));
GO

SELECT Country, SUM(Revenue) AS TotalRevenue
FROM OrdersWithRevenue
WHERE Country = 'France'
GROUP BY Country;

SELECT TOP 1 
    Country,
    LEN(Country) AS TotalLength,
    ASCII(SUBSTRING(Country, LEN(Country), 1)) AS LastCharASCII,
    UNICODE(SUBSTRING(Country, LEN(Country), 1)) AS LastCharUnicode
FROM OrdersWithRevenue
WHERE Country LIKE '%France%';

UPDATE OrdersWithRevenue
SET Country = TRIM(REPLACE(Country, CHAR(160), ' '))
WHERE Country LIKE '%France%';
GO

SELECT 'France' AS CleanCountry, SUM(Revenue) AS TotalRevenue
FROM OrdersWithRevenue
WHERE Country LIKE '%France%'
GROUP BY (CASE WHEN Country LIKE '%France%' THEN 'France' END);

-- 1. Remove Carriage Returns (13) and Line Feeds (10)
UPDATE OrdersWithRevenue
SET Country = REPLACE(REPLACE(Country, CHAR(13), ''), CHAR(10), '');

-- 2. Now perform a standard TRIM to catch any remaining regular spaces
UPDATE OrdersWithRevenue
SET Country = TRIM(Country);
GO

SELECT Country, SUM(Revenue) AS TotalRevenue
FROM OrdersWithRevenue
WHERE Country = 'United Kingdom'
GROUP BY Country;

SELECT COUNT(*) AS MessyRowsCount
FROM OrdersWithRevenue
WHERE Country LIKE '%' + CHAR(13) + '%' -- Carriage Return
   OR Country LIKE '%' + CHAR(10) + '%' -- Line Feed
   OR Country LIKE '%' + CHAR(9) + '%';  -- Tab

SELECT 
    SUM(Quantity * UnitPrice) AS CalculatedRevenue,
    SUM(Revenue) AS StoredRevenue
FROM OrdersWithRevenue;

SELECT 
    TRIM(Country) AS Country, 
    FORMAT(SUM(Revenue), 'C', 'en-US') AS TotalRevenue,
    COUNT(DISTINCT CustomerID) AS UniqueCustomers,
    COUNT(InvoiceNo) AS TransactionCount
FROM OrdersWithRevenue
GROUP BY TRIM(Country)
ORDER BY SUM(Revenue) DESC;



-- 1. Convert Quantity to Integer
ALTER TABLE OrdersWithRevenue 
ALTER COLUMN Quantity INT;

-- 2. Convert UnitPrice to Decimal
ALTER TABLE OrdersWithRevenue 
ALTER COLUMN UnitPrice DECIMAL(18,2);
GO

UPDATE OrdersWithRevenue
SET 
    Quantity = TRY_CAST(Quantity AS INT),
    UnitPrice = TRY_CAST(UnitPrice AS DECIMAL(18,2))
WHERE TRY_CAST(Quantity AS INT) IS NULL OR TRY_CAST(UnitPrice AS DECIMAL(18,2)) IS NULL;

SELECT 
    Country, 
    SUM(CAST(Revenue AS DECIMAL(18,2))) AS TotalRevenue
FROM OrdersWithRevenue
GROUP BY Country
ORDER BY SUM(Revenue) DESC;

UPDATE OrdersWithRevenue
SET Country = 'Ireland'
WHERE Country = 'EIRE';



-- 1. Remove the dependent column temporarily
ALTER TABLE OrdersWithRevenue DROP COLUMN Revenue;

-- 2. Clean and Convert the base columns to numbers
-- We use TRY_CAST to turn any remaining "garbage" text into NULLs
UPDATE OrdersWithRevenue
SET 
    Quantity = TRY_CAST(Quantity AS INT),
    UnitPrice = TRY_CAST(UnitPrice AS DECIMAL(18,2));

-- 3. Now change the actual column types
ALTER TABLE OrdersWithRevenue ALTER COLUMN Quantity INT;
ALTER TABLE OrdersWithRevenue ALTER COLUMN UnitPrice DECIMAL(18,2);

-- 4. Re-add the Revenue column (Properly typed)
ALTER TABLE OrdersWithRevenue 
ADD Revenue AS (CAST(Quantity AS DECIMAL(18,2)) * CAST(UnitPrice AS DECIMAL(18,2))) PERSISTED;
GO

SELECT TOP 5 
    Description, 
    SUM(Quantity) AS TotalUnitsSold, 
    FORMAT(SUM(Revenue), 'C', 'en-US') AS TotalRevenue
FROM OrdersWithRevenue
WHERE Quantity > 0 -- Exclude returns for this specific view
GROUP BY Description
ORDER BY SUM(Revenue) DESC;
GO