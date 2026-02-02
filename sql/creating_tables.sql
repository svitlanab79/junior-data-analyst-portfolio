-- Create database
CREATE DATABASE Ecommerce_Analysis;
GO

USE Ecommerce_Analysis;
GO


IF OBJECT_ID('dbo.EcommerceData', 'U') IS NOT NULL
    DROP TABLE dbo.EcommerceData;
GO

IF OBJECT_ID('dbo.EcommerceStaging', 'U') IS NOT NULL
    DROP TABLE dbo.EcommerceStaging;
GO



CREATE TABLE EcommerceStaging (
    OrderID NVARCHAR(50),
    CustomerName NVARCHAR(100),
    Email NVARCHAR(100),
    Country NVARCHAR(50),
    OrderDate NVARCHAR(50),
    Revenue NVARCHAR(50),
    ProductName NVARCHAR(100),
    Category NVARCHAR(50)
);
GO


CREATE TABLE EcommerceData (
    OrderID INT PRIMARY KEY,
    CustomerName NVARCHAR(100),
    Email NVARCHAR(100),
    Country NVARCHAR(50),
    OrderDate DATE,
    Revenue DECIMAL(10,2),
    ProductName NVARCHAR(100),
    Category NVARCHAR(50)
);
GO



BULK INSERT EcommerceStaging
FROM 'C:\Users\svitl\Documents\Portfolio\junior-data-analyst-portfolio\datasets\e_comm.csv'  -- <<--- update this path
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);
GO






