USE [dw]
GO
/****** Object:  StoredProcedure [raw_source].[sp_Load_in_store_data]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [raw_source].[sp_Load_in_store_data]
AS
BEGIN
    -- Create a temporary staging table that matches the structure of the CSV file
    CREATE TABLE #in_store_data_staging (
        FirstName VARCHAR(100),
        LastName VARCHAR(100),
        Email VARCHAR(255),
        Phone VARCHAR(20),
        Address VARCHAR(255),
        City VARCHAR(100),
        State VARCHAR(100),
        ZipCode VARCHAR(20),
        Country VARCHAR(100),
        OrderDate VARCHAR(50),
        Time VARCHAR(50),
        ShippingAddress VARCHAR(255),
        OrderStatus VARCHAR(50),
        ProductName VARCHAR(255),
        ProductPrice VARCHAR(50),
        Category VARCHAR(100),
        Quantity VARCHAR(50),
        TransactionID VARCHAR(50),
        StoreLocation VARCHAR(100)
    );

    -- Bulk insert data from CSV file into the temporary staging table
    BULK INSERT #in_store_data_staging
    FROM 'C:\Users\kingk\Desktop\datwarehouse_blog\sourceData\in_store_dummy_data.csv'
    WITH (
        FIELDTERMINATOR = ',',  -- Delimiter for fields
        ROWTERMINATOR = '\n',  -- Delimiter for rows
        FIRSTROW = 2,  -- Skip the header row
        TABLOCK
    );

    -- Insert data from staging table to the target table with appropriate conversions
    INSERT INTO raw_source.in_store_data (
        FirstName,
        LastName,
        Email,
        Phone,
        Address,
        City,
        State,
        ZipCode,
        Country,
        OrderDate,
        Time,
        ShippingAddress,
        OrderStatus,
        ProductName,
        ProductPrice,
        Category,
        Quantity,
        TransactionID,
        StoreLocation
    )
    SELECT
        FirstName,
        LastName,
        Email,
        Phone,
        Address,
        City,
        State,
        ZipCode,
        Country,
        -- Use TRY_CAST to safely convert OrderDate and Time columns, defaulting to NULL if conversion fails
        '2023-12-26',
        TRY_CAST(Time AS TIME),
        ShippingAddress,
        OrderStatus,
        ProductName,
        -- Use TRY_CAST to safely convert ProductPrice and Quantity, defaulting to NULL if conversion fails
        TRY_CAST(ProductPrice AS DECIMAL(10, 2)),
        Category,
        TRY_CAST(Quantity AS INT),
        TRY_CAST(TransactionID AS UNIQUEIDENTIFIER),
        StoreLocation
    FROM #in_store_data_staging;

    -- Drop the temporary staging table
    DROP TABLE #in_store_data_staging;
END;
GO
