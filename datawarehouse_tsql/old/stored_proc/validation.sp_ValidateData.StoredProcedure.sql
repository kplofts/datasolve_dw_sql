USE [dw]
GO
/****** Object:  StoredProcedure [validation].[sp_ValidateData]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [validation].[sp_ValidateData]
    @RunDateTime DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Execute the sp_duplicateCheck stored procedure
        EXEC [validation].[sp_duplicateCheck];

        -- Temporary staging tables for bulk insert
        CREATE TABLE #eCommerce_data_staging (
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
            ProductPrice DECIMAL(10, 2),
            Category VARCHAR(100),
            Quantity INT,
            TransactionID UNIQUEIDENTIFIER
        );

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
            ProductPrice DECIMAL(10, 2),
            Category VARCHAR(100),
            Quantity INT,
            TransactionID UNIQUEIDENTIFIER,
            StoreLocation VARCHAR(100)
        );

        -- Bulk insert data from CSV file into the temporary staging table
        BULK INSERT #eCommerce_data_staging
        FROM 'C:\Users\kingk\Desktop\datwarehouse_blog\sourceData\eCommerceDummyData.csv'
        WITH (
            FIELDTERMINATOR = ',',  -- Delimiter for fields
            ROWTERMINATOR = '\n',  -- Delimiter for rows
            FIRSTROW = 2,  -- Skip the header row
            TABLOCK
        );

        BULK INSERT #in_store_data_staging
        FROM 'C:\Users\kingk\Desktop\datwarehouse_blog\sourceData\in_store_dummy_data.csv'
        WITH (
            FIELDTERMINATOR = ',',  -- Delimiter for fields
            ROWTERMINATOR = '\n',  -- Delimiter for rows
            FIRSTROW = 2,  -- Skip the header row
            TABLOCK
        );

        -- Validate total records and sums
        DECLARE @totalRecordsInSource INT;
        DECLARE @totalRecordsInReview INT;
        DECLARE @totalRecordsInStaging INT;

        DECLARE @numberOfProductsInSource INT;
        DECLARE @numberOfProductsInReview INT;
        DECLARE @numberOfProductsInStaging INT;

        DECLARE @totalSumInSource DECIMAL(18, 2);
        DECLARE @totalSumInReview DECIMAL(18, 2);
        DECLARE @totalSumInStaging DECIMAL(18, 2);

        DECLARE @distinctCustomersInSource INT;
        DECLARE @distinctCustomersInReview INT;
        DECLARE @distinctCustomersInStaging INT;

        DECLARE @distinctTransactionsInSource INT;
        DECLARE @distinctTransactionsInReview INT;
        DECLARE @distinctTransactionsInStaging INT;

        DECLARE @EndTime DATETIME;
        DECLARE @QueryRuntime INT;

        DECLARE @validationResultTotalRecords NVARCHAR(50);
        DECLARE @validationResultDistinctTransactions NVARCHAR(50);

        -- Source data metrics
        SELECT @totalRecordsInSource = 
            (SELECT COUNT(*) FROM #eCommerce_data_staging)
            + (SELECT COUNT(*) FROM #in_store_data_staging);

        SELECT @numberOfProductsInSource = COUNT(DISTINCT ProductName)
        FROM (
            SELECT ProductName FROM #eCommerce_data_staging
            UNION
            SELECT ProductName FROM #in_store_data_staging
        ) AS SourceProducts;

        SELECT @totalSumInSource = 
            (SELECT SUM(Quantity * ProductPrice) FROM #eCommerce_data_staging)
            + (SELECT SUM(Quantity * ProductPrice) FROM #in_store_data_staging);

        SELECT @distinctCustomersInSource = COUNT(DISTINCT Email)
        FROM (
            SELECT Email FROM #eCommerce_data_staging
            UNION
            SELECT Email FROM #in_store_data_staging
        ) AS SourceCustomers;

        SELECT @distinctTransactionsInSource = COUNT(DISTINCT TransactionID)
        FROM (
            SELECT TransactionID FROM #eCommerce_data_staging
            UNION
            SELECT TransactionID FROM #in_store_data_staging
        ) AS SourceTransactions;

        -- Review data metrics
        SELECT @totalRecordsInReview = COUNT(*) FROM review.TransactionReview;

        SELECT @numberOfProductsInReview = COUNT(DISTINCT ProductName) FROM review.TransactionReview;

        SELECT @totalSumInReview = COALESCE(SUM(Quantity * ProductPrice), 0) FROM review.TransactionReview;

        SELECT @distinctCustomersInReview = COUNT(DISTINCT Email) FROM review.TransactionReview;

        SELECT @distinctTransactionsInReview = COUNT(DISTINCT TransactionID) FROM review.TransactionReview;

        -- Staging data metrics
        SELECT @totalRecordsInStaging = COUNT(*) FROM staging.Orders;

        SELECT @numberOfProductsInStaging = COUNT(DISTINCT ProductName) FROM staging.Products;

        SELECT @totalSumInStaging = SUM(p.Price * o.Quantity)
        FROM [dw].[staging].[Orders] o
        INNER JOIN dw.staging.Products p ON p.ProductID = o.ProductID;

        SELECT @distinctCustomersInStaging = COUNT(DISTINCT Email) FROM staging.Customers;

        SELECT @distinctTransactionsInStaging = COUNT(DISTINCT TransactionID) FROM staging.Transactions;

        -- Validation check for total records
        IF @totalRecordsInSource - @totalRecordsInReview = @totalRecordsInStaging
        BEGIN
            SET @validationResultTotalRecords = 'Valid';
        END
        ELSE
        BEGIN
            SET @validationResultTotalRecords = 'Invalid';
        END

        -- Validation check for distinct transactions
        IF @distinctTransactionsInSource - @distinctTransactionsInReview = @distinctTransactionsInStaging
        BEGIN
            SET @validationResultDistinctTransactions = 'Valid';
        END
        ELSE
        BEGIN
            SET @validationResultDistinctTransactions = 'Invalid';
        END

        ---- Output validation results
        --PRINT 'Validation Results:';
        --PRINT '----------------------------------------';
        --PRINT 'Total Records in Source Data: ' + CAST(@totalRecordsInSource AS NVARCHAR(10));
        --PRINT 'Total Records in Review Table: ' + CAST(@totalRecordsInReview AS NVARCHAR(10));
        --PRINT 'Total Records in Staging Table: ' + CAST(@totalRecordsInStaging AS NVARCHAR(10));
        --PRINT 'Validation Result (Total Records): ' + @validationResultTotalRecords;
        --PRINT '----------------------------------------';
        --PRINT 'Number of Products in Source Data: ' + CAST(@numberOfProductsInSource AS NVARCHAR(10));
        --PRINT 'Number of Products in Review Table: ' + CAST(@numberOfProductsInReview AS NVARCHAR(10));
        --PRINT 'Number of Products in Staging Table: ' + CAST(@numberOfProductsInStaging AS NVARCHAR(10));
        --PRINT '----------------------------------------';
        --PRINT 'Total Sum in Source Data: ' + CAST(@totalSumInSource AS NVARCHAR(18));
        --PRINT 'Total Sum in Review Table: ' + CAST(@totalSumInReview AS NVARCHAR(18));
        --PRINT 'Total Sum in Staging Table: ' + CAST(@totalSumInStaging AS NVARCHAR(18));
        --PRINT '----------------------------------------';
        --PRINT 'Distinct Customers in Source Data: ' + CAST(@distinctCustomersInSource AS NVARCHAR(10));
        --PRINT 'Distinct Customers in Review Table: ' + CAST(@distinctCustomersInReview AS NVARCHAR(10));
        --PRINT 'Distinct Customers in Staging Table: ' + CAST(@distinctCustomersInStaging AS NVARCHAR(10));
        --PRINT '----------------------------------------';
        --PRINT 'Distinct Transactions in Source Data: ' + CAST(@distinctTransactionsInSource AS NVARCHAR(10));
        --PRINT 'Distinct Transactions in Review Table: ' + CAST(@distinctTransactionsInReview AS NVARCHAR(10));
        --PRINT 'Distinct Transactions in Staging Table: ' + CAST(@distinctTransactionsInStaging AS NVARCHAR(10));
        --PRINT 'Validation Result (Distinct Transactions): ' + @validationResultDistinctTransactions;

        -- Cleanup temporary tables
        DROP TABLE #eCommerce_data_staging;
        DROP TABLE #in_store_data_staging;

        -- Get end time and calculate runtime
        SET @EndTime = GETDATE();
        SET @QueryRuntime = DATEDIFF(SECOND, @RunDateTime, @EndTime);

        -- Insert into ValidationLog table
        INSERT INTO validation.ValidationLog (
            RunDateTime,
            totalRecordsInSource,
            totalRecordsInReview,
            totalRecordsInStaging,
            validationResultTotalRecords,
            validationResultDistinctTransactions,
            numberOfProductsInSource,
            numberOfProductsInReview,
            numberOfProductsInStaging,
            totalSumInSource,
            totalSumInReview,
            totalSumInStaging,
            distinctCustomersInSource,
            distinctCustomersInReview,
            distinctCustomersInStaging,
            distinctTransactionsInSource,
            distinctTransactionsInReview,
            distinctTransactionsInStaging,
            QueryRuntime
        ) VALUES (
            @RunDateTime,
            @totalRecordsInSource,
            @totalRecordsInReview,
            @totalRecordsInStaging,
            @validationResultTotalRecords,
            @validationResultDistinctTransactions,
            @numberOfProductsInSource,
            @numberOfProductsInReview,
            @numberOfProductsInStaging,
            @totalSumInSource,
            @totalSumInReview,
            @totalSumInStaging,
            @distinctCustomersInSource,
            @distinctCustomersInReview,
            @distinctCustomersInStaging,
            @distinctTransactionsInSource,
            @distinctTransactionsInReview,
            @distinctTransactionsInStaging,
            @QueryRuntime
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

        DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;
        SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
GO
