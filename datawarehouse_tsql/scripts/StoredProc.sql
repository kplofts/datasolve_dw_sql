USE [dw]
GO
/****** Object:  StoredProcedure [clean].[sp_DeleteAllData]    Script Date: 6/09/2024 4:54:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [clean].[sp_DeleteAllData]
AS
BEGIN
    SET NOCOUNT ON;

    -- Begin transaction
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Disable constraints on necessary tables
        EXEC sp_MSforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all";

        -- Truncate data from tables without foreign key dependencies
        TRUNCATE TABLE final.FactSales;
        TRUNCATE TABLE final.DimCustomer;
        TRUNCATE TABLE final.DimProduct;
        TRUNCATE TABLE final.DimStoreLocation;

        TRUNCATE TABLE raw_source.eCommerce_data;
        TRUNCATE TABLE raw_source.in_store_data;

        -- Delete data from tables with foreign key dependencies
        DELETE FROM staging.Transactions;
        DELETE FROM staging.Orders;
        DELETE FROM staging.Products; -- Products table cannot be truncated
        DELETE FROM staging.Customers;
        DELETE FROM staging.StoreLocation;

        -- Truncate log tables (assuming no foreign keys)
        TRUNCATE TABLE staging.ETL_Log;
        TRUNCATE TABLE staging.DuplicateLog;

        TRUNCATE TABLE validation.ValidationLog;
        TRUNCATE TABLE review.TransactionReview;

        -- Enable constraints on necessary tables
        EXEC sp_MSforeachtable "ALTER TABLE ? CHECK CONSTRAINT all";

        -- Commit transaction
        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        -- Rollback transaction if any error occurs
        ROLLBACK TRANSACTION;
        -- Raise the error to the caller
        THROW;
    END CATCH
END;
GO
/****** Object:  StoredProcedure [final].[sp_Load_Final_Data]    Script Date: 6/09/2024 4:54:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [final].[sp_Load_Final_Data]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insert into final.DimCustomer
        INSERT INTO final.DimCustomer (FirstName, LastName, Email, Phone, [Address], City, [State], ZipCode, Country)
        SELECT DISTINCT
            c.FirstName,
            c.LastName,
            c.Email,
            c.Phone,
            c.[Address],
            c.City,
            c.[State],
            c.ZipCode,
            c.Country
        FROM staging.Customers c
        LEFT JOIN final.DimCustomer fc ON c.Email = fc.Email
        WHERE fc.Email IS NULL;

        -- Insert into final.DimProduct
        INSERT INTO final.DimProduct (ProductName, Category, Price, ActualPrice)
        SELECT DISTINCT
            p.ProductName,
            p.Category,
            p.Price,
            p.Price * 0.8 AS ActualPrice
        FROM staging.Products p
        LEFT JOIN final.DimProduct fp ON p.ProductName = fp.ProductName
        WHERE fp.ProductName IS NULL;

        -- Insert into final.DimStoreLocation
        INSERT INTO final.DimStoreLocation (StoreLocation)
        SELECT DISTINCT
            sl.StoreLocation
        FROM staging.StoreLocation sl
        LEFT JOIN final.DimStoreLocation fsl ON sl.StoreLocation = fsl.StoreLocation
        WHERE fsl.StoreLocation IS NULL;

        -- Insert into final.DimOrder with correct ProductID
        INSERT INTO final.DimOrder (OrderID, ProductID, Quantity)
        SELECT DISTINCT
            o.OrderID,
            dp.ProductKey, -- Use ProductKey from DimProduct
            o.Quantity
        FROM staging.Orders o
        INNER JOIN staging.Products p ON o.ProductID = p.ProductID
        INNER JOIN final.DimProduct dp ON p.ProductName = dp.ProductName AND p.Price = dp.Price
        LEFT JOIN final.DimOrder fo ON o.OrderID = fo.OrderID AND dp.ProductKey = fo.ProductID
       -- WHERE fo.OrderID IS NULL;

        -- Insert into FactSales using captured keys from the final dimension tables
        INSERT INTO final.FactSales (OrderKey, CustomerKey, ProductKey, DateKey, StoreLocationKey, Quantity, UnitPrice, TransactionDate, TransactionID)
        SELECT 
            do.OrderKey,
            dc.CustomerKey,
            dp.ProductKey,
            dd.DateKey,
            dsl.StoreLocationKey,
            do.Quantity,
            dp.Price,
            t.TransactionDate,
            t.TransactionID
        FROM final.DimOrder do
        INNER JOIN staging.Orders o ON do.OrderID = o.OrderID --AND do.ProductID = o.ProductID
        INNER JOIN staging.Transactions t ON o.SurrogateTransactionID = t.SurrogateTransactionID
        INNER JOIN final.DimProduct dp ON do.ProductID = dp.ProductKey
        INNER JOIN staging.Customers c ON t.CustomerID = c.CustomerID
        INNER JOIN final.DimCustomer dc ON c.Email = dc.Email AND dc.FirstName = c.FirstName AND dc.LastName = c.LastName
        INNER JOIN staging.StoreLocation sl ON o.StoreID = sl.StoreID
        INNER JOIN final.DimStoreLocation dsl ON sl.StoreLocation = dsl.StoreLocation
        INNER JOIN final.DimDate dd ON CAST(o.OrderDate AS DATE) = dd.Date;

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
    
    SET NOCOUNT OFF;
END
GO
/****** Object:  StoredProcedure [master].[LogDiagnostics]    Script Date: 6/09/2024 4:54:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [master].[LogDiagnostics]
    @ProcedureName NVARCHAR(255),
    @RowsAffected INT,
    @StartTime DATETIME,
    @EndTime DATETIME,
    @DiagnosticInfo NVARCHAR(MAX) OUTPUT
AS
BEGIN
    DECLARE @QueryRuntime INT = DATEDIFF(SECOND, @StartTime, @EndTime);
    SET @DiagnosticInfo = @DiagnosticInfo + 'Procedure: ' + @ProcedureName + CHAR(13) + CHAR(10)
                        + 'Rows Affected: ' + CAST(@RowsAffected AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'Runtime (seconds): ' + CAST(@QueryRuntime AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + '----------------------------------------' + CHAR(13) + CHAR(10);
END
GO
/****** Object:  StoredProcedure [master].[sp_RunETLProcesses]    Script Date: 6/09/2024 4:54:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [master].[sp_RunETLProcesses]
AS
BEGIN
    SET NOCOUNT ON;

    -- Declare variables for logging
    DECLARE @StartTime DATETIME;
    DECLARE @EndTime DATETIME;
    DECLARE @TotalRuntime INT;
    DECLARE @EndTimeValidation DATETIME;
    DECLARE @StoredProcedureName NVARCHAR(255);
    DECLARE @DiagnosticInfo NVARCHAR(MAX);
    DECLARE @EmailBody NVARCHAR(MAX) = '';
    DECLARE @ETLLog NVARCHAR(MAX) = '';
    DECLARE @DuplicateLogSummary NVARCHAR(MAX) = '';
    DECLARE @ValidationLog NVARCHAR(MAX) = '';
    DECLARE @TransactionReviewLog NVARCHAR(MAX) = '';
    DECLARE @ValidationCheckSum DECIMAL(18, 2);
    
    -- Initialize start time
    SET @StartTime = GETDATE();

    -- Create a temporary table for capturing email body details
    CREATE TABLE #EmailBodyDetails (
        Detail NVARCHAR(MAX)
    );

    -- Artificial loading steps
    PRINT 'Extracting data from source systems...';
    WAITFOR DELAY '00:00:02';  -- 2 seconds delay

    PRINT 'Applying a random mathematical principal...';
    WAITFOR DELAY '00:00:02';  -- 2 seconds delay

    -- Execute stored procedures and capture diagnostics
    DECLARE @ProcedureList TABLE (SchemaName NVARCHAR(255), ProcedureName NVARCHAR(255), [Order] INT);

    INSERT INTO @ProcedureList (SchemaName, ProcedureName, [Order]) VALUES
    ('clean', 'sp_DeleteAllData', 1),
    ('raw_source', 'sp_Load_eCommerce_Data', 2),
    ('raw_source', 'sp_Load_in_store_data', 3),
    ('normalize', 'sp_Normalize_eCommerce_Data', 4),
    ('normalize', 'sp_Normalize_InStore_Data', 5),
    ('validation', 'sp_ValidateData', 6),
    ('final', 'sp_Load_Final_Data', 7);

    DECLARE @SchemaName NVARCHAR(255);
    DECLARE @ProcName NVARCHAR(255);
    DECLARE @Order INT;
    DECLARE @SQL NVARCHAR(MAX);

    DECLARE ProcedureCursor CURSOR FOR
    SELECT SchemaName, ProcedureName, [Order]
    FROM @ProcedureList
    ORDER BY [Order];

    OPEN ProcedureCursor;
    FETCH NEXT FROM ProcedureCursor INTO @SchemaName, @ProcName, @Order;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @StoredProcedureName = @SchemaName + '.' + @ProcName;

        -- Execute the stored procedure
        IF @SchemaName = 'validation' AND @ProcName = 'sp_ValidateData'
        BEGIN
            SET @SQL = 'EXEC ' + @StoredProcedureName + ' @RunDateTime = @StartTime';
            EXEC sp_executesql @SQL, N'@StartTime DATETIME', @StartTime;
        END
        ELSE
        BEGIN
            SET @SQL = 'EXEC ' + @StoredProcedureName;
            EXEC sp_executesql @SQL;
        END

        SET @EndTime = GETDATE();

        -- Log diagnostics
        EXEC master.LogDiagnostics @StoredProcedureName, @@ROWCOUNT, @StartTime, @EndTime, @DiagnosticInfo OUTPUT;

        -- Insert diagnostic info into temp table
        INSERT INTO #EmailBodyDetails (Detail)
        VALUES ('StoredProcedureName: ' + @StoredProcedureName + CHAR(13) + CHAR(10) +
                'StartTime: ' + CAST(@StartTime AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
                'EndTime: ' + CAST(@EndTime AS NVARCHAR(20)) + CHAR(13) + CHAR(10) +
                'Runtime (seconds): ' + CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS NVARCHAR(10)) + CHAR(13) + CHAR(10) +
                '----------------------------------------' + CHAR(13) + CHAR(10));

        FETCH NEXT FROM ProcedureCursor INTO @SchemaName, @ProcName, @Order;
    END;

    CLOSE ProcedureCursor;
    DEALLOCATE ProcedureCursor;

    -- Calculate total runtime
    SET @EndTime = GETDATE();
    SET @TotalRuntime = DATEDIFF(SECOND, @StartTime, @EndTime);

    -- Fetch ETL log data
    SELECT @ETLLog = @ETLLog + 'RunDateTime: ' + CAST(RunDateTime AS NVARCHAR(20)) + CHAR(13) + CHAR(10)
                    + 'StoredProcedureName: ' + StoredProcedureName + CHAR(13) + CHAR(10)
                    + 'QueryRuntime: ' + CAST(QueryRuntime AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                    + 'TotalRecordsInserted: ' + CAST(TotalRecordsInserted AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                    + 'DiskSpaceLeft: ' + DiskSpaceLeft + CHAR(13) + CHAR(10)
                    + '----------------------------------------' + CHAR(13) + CHAR(10)
    FROM staging.ETL_Log;

    -- Insert ETL log into temp table
    INSERT INTO #EmailBodyDetails (Detail)
    SELECT @ETLLog;

    -- Fetch Duplicate log summary
    SELECT @DuplicateLogSummary = @DuplicateLogSummary + 'TableName: ' + TableName + CHAR(13) + CHAR(10)
                                + 'RowCount: ' + CAST(COUNT(*) AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                                + '----------------------------------------' + CHAR(13) + CHAR(10)
    FROM staging.DuplicateLog
    GROUP BY TableName;

    -- Insert duplicate log summary into temp table
    INSERT INTO #EmailBodyDetails (Detail)
    SELECT @DuplicateLogSummary;

    -- Fetch Validation log data
    SELECT @ValidationLog = @ValidationLog + 'RunDateTime: ' + CAST(RunDateTime AS NVARCHAR(20)) + CHAR(13) + CHAR(10)
                        + 'TotalRecordsInSource: ' + CAST(totalRecordsInSource AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'TotalRecordsInReview: ' + CAST(totalRecordsInReview AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'TotalRecordsInStaging: ' + CAST(totalRecordsInStaging AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'ValidationResultTotalRecords: ' + validationResultTotalRecords + CHAR(13) + CHAR(10)
                        + 'ValidationResultDistinctTransactions: ' + validationResultDistinctTransactions + CHAR(13) + CHAR(10)
                        + 'NumberOfProductsInSource: ' + CAST(numberOfProductsInSource AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'NumberOfProductsInReview: ' + CAST(numberOfProductsInReview AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'NumberOfProductsInStaging: ' + CAST(numberOfProductsInStaging AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'TotalSumInSource: ' + CAST(totalSumInSource AS NVARCHAR(18)) + CHAR(13) + CHAR(10)
                        + 'TotalSumInReview: ' + CAST(totalSumInReview AS NVARCHAR(18)) + CHAR(13) + CHAR(10)
                        + 'TotalSumInStaging: ' + CAST(totalSumInStaging AS NVARCHAR(18)) + CHAR(13) + CHAR(10)
                        + 'DistinctCustomersInSource: ' + CAST(distinctCustomersInSource AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'DistinctCustomersInReview: ' + CAST(distinctCustomersInReview AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'DistinctCustomersInStaging: ' + CAST(distinctCustomersInStaging AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'DistinctTransactionsInSource: ' + CAST(distinctTransactionsInSource AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'DistinctTransactionsInReview: ' + CAST(distinctTransactionsInReview AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'DistinctTransactionsInStaging: ' + CAST(distinctTransactionsInStaging AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + 'QueryRuntime: ' + CAST(QueryRuntime AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                        + '----------------------------------------' + CHAR(13) + CHAR(10)
    FROM validation.ValidationLog;

    -- Insert Validation log into temp table
    INSERT INTO #EmailBodyDetails (Detail)
    SELECT 'DATA VALIDATION CHECKS' + CHAR(13) + CHAR(10) + @ValidationLog;

    -- Fetch TransactionReview data
    SELECT @TransactionReviewLog = @TransactionReviewLog + 'TransactionID: ' + CAST(TransactionID AS NVARCHAR(36)) + CHAR(13) + CHAR(10)
                                + 'FirstName: ' + FirstName + CHAR(13) + CHAR(10)
                                + 'LastName: ' + LastName + CHAR(13) + CHAR(10)
                                + 'Email: ' + Email + CHAR(13) + CHAR(10)
                                + 'DataSource: ' + DataSource + CHAR(13) + CHAR(10)
                                + 'Quantity: ' + CAST(Quantity AS NVARCHAR(10)) + CHAR(13) + CHAR(10)
                                + 'ProductName: ' + ProductName + CHAR(13) + CHAR(10)
                                + 'ProductPrice: ' + CAST(ProductPrice AS NVARCHAR(18)) + CHAR(13) + CHAR(10)
                                + 'ReviewDate: ' + CAST(ReviewDate AS NVARCHAR(20)) + CHAR(13) + CHAR(10)
                                + '----------------------------------------' + CHAR(13) + CHAR(10)
    FROM review.TransactionReview;

    -- Insert TransactionReview log into temp table
    INSERT INTO #EmailBodyDetails (Detail)
    SELECT 'TRANSACTIONS IN REVIEW' + CHAR(13) + CHAR(10) + @TransactionReviewLog;

    -- Additional data validation check
    SELECT @ValidationCheckSum = SUM(Quantity * UnitPrice)
    FROM final.FactSales;

    -- Insert data validation check result into temp table
    INSERT INTO #EmailBodyDetails (Detail)
    SELECT 'Additional Data Validation Check' + CHAR(13) + CHAR(10) +
           'Sum(Quantity * UnitPrice) from final.FactSales: ' + CAST(@ValidationCheckSum AS NVARCHAR(18)) + CHAR(13) + CHAR(10) +
           '----------------------------------------' + CHAR(13) + CHAR(10);

    -- Fetch the email body details
    SELECT @EmailBody = COALESCE(@EmailBody + Detail + CHAR(13) + CHAR(10), Detail + CHAR(13) + CHAR(10))
    FROM #EmailBodyDetails;

    -- Send the email
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = 'DataSolveProfile',  -- Replace with your actual mail profile name
        @recipients = 'kristian@datasolve.tech',
        @subject = 'ETL Pipeline Successfully ran',
        @body = @EmailBody,
        @body_format = 'TEXT';

    -- Cleanup temporary table
    DROP TABLE #EmailBodyDetails;
END;
GO
/****** Object:  StoredProcedure [normalize].[sp_Normalize_eCommerce_Data]    Script Date: 6/09/2024 4:54:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [normalize].[sp_Normalize_eCommerce_Data]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insert into StoreLocation (if not already exists)
        IF NOT EXISTS (SELECT 1 FROM staging.StoreLocation WHERE StoreLocation = 'online')
        BEGIN
            INSERT INTO staging.StoreLocation (StoreLocation)
            VALUES ('online');
        END
        
        DECLARE @StoreID INT;
        SELECT @StoreID = StoreID FROM staging.StoreLocation WHERE StoreLocation = 'online';

        -- Identify transactions with multiple email addresses and insert into a temp table
		IF OBJECT_ID('tempdb..#DuplicateTransactions') IS NOT NULL DROP TABLE #DuplicateTransactions;

		CREATE TABLE #DuplicateTransactions (TransactionID UNIQUEIDENTIFIER);

		INSERT INTO #DuplicateTransactions (TransactionID)
		SELECT DISTINCT TransactionID
		FROM raw_source.eCommerce_data
		GROUP BY TransactionID
		HAVING COUNT(DISTINCT Email) > 1;


        -- Move duplicate transactions to review table
        INSERT INTO review.TransactionReview (TransactionID, FirstName, LastName, Email, DataSource, Quantity, ProductName, ProductPrice, ReviewDate)
        SELECT 
            e.TransactionID,
            e.FirstName,
            e.LastName,
            e.Email,
            'eCommerce',
            e.Quantity,
            e.ProductName,
            e.ProductPrice,
            GETDATE()
        FROM raw_source.eCommerce_data e
        INNER JOIN #DuplicateTransactions dt ON e.TransactionID = dt.TransactionID;

        -- Insert into Customers excluding those with duplicate transactions
        INSERT INTO staging.Customers (FirstName, LastName, Email, Phone, [Address], City, [State], ZipCode, Country)
        SELECT DISTINCT
            FirstName, LastName, Email, Phone, [Address], City, [State], ZipCode, Country
        FROM raw_source.eCommerce_data e
        WHERE NOT EXISTS (
            SELECT 1 
            FROM #DuplicateTransactions dt
            WHERE e.TransactionID = dt.TransactionID
        )
        AND NOT EXISTS (
            SELECT 1 
            FROM staging.Customers c 
            WHERE c.Email = e.Email
            AND c.FirstName = e.FirstName
            AND c.LastName = e.LastName
        );

        -- Insert into Products excluding those with duplicate transactions
        INSERT INTO staging.Products (ProductName, Category, Price)
        SELECT DISTINCT
            e.ProductName, e.Category, e.ProductPrice
        FROM raw_source.eCommerce_data e
        WHERE NOT EXISTS (
            SELECT 1 
            FROM #DuplicateTransactions dt
            WHERE e.TransactionID = dt.TransactionID
        )
        AND NOT EXISTS (
            SELECT 1 
            FROM staging.Products p 
            WHERE p.ProductName = e.ProductName
        );

        -- Using CTE to ensure unique TransactionID for valid transactions
        ;WITH UniqueTransactions AS (
            SELECT 
                TransactionID,
                MAX(FirstName) AS FirstName,
                MAX(LastName) AS LastName,
                MAX(Email) AS Email,
                MAX(OrderDate) AS OrderDate,
                MAX([Time]) AS [Time],
                MAX(OrderStatus) AS OrderStatus
            FROM raw_source.eCommerce_data e
            WHERE NOT EXISTS (
                SELECT 1 
                FROM #DuplicateTransactions dt
                WHERE e.TransactionID = dt.TransactionID
            )
            GROUP BY TransactionID
        )
        -- Insert into Transactions excluding those with duplicate transactions
        INSERT INTO staging.Transactions (TransactionID, CustomerID, TransactionDate, StoreID, Status, PaymentMethod)
        SELECT 
            ut.TransactionID, 
            c.CustomerID, 
            CAST(ut.OrderDate AS DATETIME) + CAST(ut.[Time] AS DATETIME),
            @StoreID,
            ut.OrderStatus,
            'Online' -- Assuming the payment method is online, you can adjust as needed
        FROM 
            UniqueTransactions ut
        INNER JOIN 
            staging.Customers c ON ut.Email = c.Email AND ut.FirstName = c.FirstName AND ut.LastName = c.LastName
        WHERE NOT EXISTS (
            SELECT 1 FROM staging.Transactions t
            WHERE t.TransactionID = ut.TransactionID
        );

        -- Insert into Orders excluding those with duplicate transactions
        INSERT INTO staging.Orders (OrderDate, ShippingAddress, StoreID, ProductID, Quantity, SurrogateTransactionID)
        SELECT 
            CAST(e.OrderDate AS DATETIME) + CAST(e.[Time] AS DATETIME),
            e.ShippingAddress,
            @StoreID,
            p.ProductID,
            e.Quantity,
            t.SurrogateTransactionID
        FROM 
            raw_source.eCommerce_data e
        INNER JOIN 
            staging.Products p ON e.ProductName = p.ProductName
        INNER JOIN 
            staging.Transactions t ON e.TransactionID = t.TransactionID
        WHERE NOT EXISTS (
            SELECT 1 
            FROM #DuplicateTransactions dt
            WHERE e.TransactionID = dt.TransactionID
        );

        -- Cleanup temp table
        DROP TABLE #DuplicateTransactions;

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
    
    SET NOCOUNT OFF;
END
GO
/****** Object:  StoredProcedure [normalize].[sp_Normalize_InStore_Data]    Script Date: 6/09/2024 4:54:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [normalize].[sp_Normalize_InStore_Data]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Insert into StoreLocation (if not already exists)
        INSERT INTO staging.StoreLocation (StoreLocation)
        SELECT DISTINCT StoreLocation
        FROM raw_source.in_store_data
        WHERE NOT EXISTS (
            SELECT 1 FROM staging.StoreLocation sl
            WHERE sl.StoreLocation = raw_source.in_store_data.StoreLocation
        );

        DECLARE @StoreID INT;

        -- Insert into Customers
        INSERT INTO staging.Customers (FirstName, LastName, Email, Phone, [Address], City, [State], ZipCode, Country)
        SELECT DISTINCT
            FirstName, LastName, Email, Phone, [Address], City, [State], ZipCode, Country
        FROM raw_source.in_store_data
        WHERE NOT EXISTS (
            SELECT 1 FROM staging.Customers c 
            WHERE c.Email = raw_source.in_store_data.Email
            AND c.FirstName = raw_source.in_store_data.FirstName
            AND c.LastName = raw_source.in_store_data.LastName
        );

        -- Insert into Products
        INSERT INTO staging.Products (ProductName, Category, Price)
        SELECT DISTINCT
            ProductName, Category, ProductPrice
        FROM raw_source.in_store_data
        WHERE NOT EXISTS (
            SELECT 1 FROM staging.Products p 
            WHERE p.ProductName = raw_source.in_store_data.ProductName
        );

        -- Using CTE to ensure unique TransactionID
        ;WITH UniqueTransactions AS (
            SELECT 
                TransactionID,
                MAX(FirstName) AS FirstName,
                MAX(LastName) AS LastName,
                MAX(Email) AS Email,
                MAX(OrderDate) AS OrderDate,
                MAX([Time]) AS [Time],
                MAX(OrderStatus) AS OrderStatus,
                MAX(StoreLocation) AS StoreLocation
            FROM raw_source.in_store_data
            GROUP BY TransactionID
        )
        -- Insert into Transactions
        INSERT INTO staging.Transactions (TransactionID, CustomerID, TransactionDate, StoreID, Status, PaymentMethod)
        SELECT 
            ut.TransactionID, 
            c.CustomerID, 
            CAST(ut.OrderDate AS DATETIME) + CAST(ut.[Time] AS DATETIME),
            sl.StoreID,
            ut.OrderStatus,
            'InStore' -- Assuming the payment method is in-store, you can adjust as needed
        FROM 
            UniqueTransactions ut
        INNER JOIN 
            staging.Customers c ON ut.Email = c.Email AND ut.FirstName = c.FirstName AND ut.LastName = c.LastName
        INNER JOIN 
            staging.StoreLocation sl ON ut.StoreLocation = sl.StoreLocation
        WHERE NOT EXISTS (
            SELECT 1 FROM staging.Transactions t
            WHERE t.TransactionID = ut.TransactionID
        );

        -- Insert into Orders
        INSERT INTO staging.Orders (OrderDate, ShippingAddress, StoreID, ProductID, Quantity, SurrogateTransactionID)
        SELECT 
            CAST(e.OrderDate AS DATETIME) + CAST(e.[Time] AS DATETIME),
            e.ShippingAddress,
            sl.StoreID,
            p.ProductID,
            e.Quantity,
            t.SurrogateTransactionID
        FROM 
            raw_source.in_store_data e
        INNER JOIN 
            staging.Products p ON e.ProductName = p.ProductName
        INNER JOIN 
            staging.Transactions t ON e.TransactionID = t.TransactionID
        INNER JOIN
            staging.StoreLocation sl ON e.StoreLocation = sl.StoreLocation;

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
    
    SET NOCOUNT OFF;
END
GO
/****** Object:  StoredProcedure [raw_source].[sp_Load_eCommerce_Data]    Script Date: 6/09/2024 4:54:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [raw_source].[sp_Load_eCommerce_Data]
AS
BEGIN
    -- Create a temporary staging table that matches the structure of the CSV file
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
        ProductPrice VARCHAR(50),
        Category VARCHAR(100),
        Quantity VARCHAR(50),
        TransactionID VARCHAR(50)
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

    -- Insert data from staging table to the target table with appropriate conversions
    INSERT INTO   raw_source.eCommerce_data (
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
        TransactionID
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
        TRY_CAST(TransactionID AS UNIQUEIDENTIFIER)
    FROM #eCommerce_data_staging;

    -- Drop the temporary staging table
    DROP TABLE #eCommerce_data_staging;
END;
GO
/****** Object:  StoredProcedure [raw_source].[sp_Load_in_store_data]    Script Date: 6/09/2024 4:54:59 PM ******/
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
/****** Object:  StoredProcedure [validation].[sp_duplicateCheck]    Script Date: 6/09/2024 4:54:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [validation].[sp_duplicateCheck]

AS
BEGIN
    SET NOCOUNT ON;


        -- Step 1: Identify transactions with same TransactionID and Email but different FirstName and LastName
        INSERT INTO review.TransactionReview (TransactionID, FirstName, LastName, Email, DataSource, Quantity, ProductName, ProductPrice)
        SELECT 
            t.TransactionID,
            c.FirstName,
            c.LastName,
            c.Email,
            'eCommerce', -- Assuming eCommerce for now, adjust if needed
            o.Quantity,
            p.ProductName,
            p.Price
        FROM 
            staging.Transactions t
        JOIN 
            staging.Customers c ON c.CustomerID = t.CustomerID
        JOIN 
            staging.Orders o ON o.SurrogateTransactionID = t.SurrogateTransactionID
        JOIN 
            staging.Products p ON p.ProductID = o.ProductID
        WHERE 
            t.TransactionID IN (
                SELECT TransactionID
                FROM staging.Transactions t1
                JOIN staging.Customers c1 ON c1.CustomerID = t1.CustomerID
                GROUP BY t1.TransactionID, c1.Email
                HAVING COUNT(DISTINCT c1.FirstName) > 1 OR COUNT(DISTINCT c1.LastName) > 1
            );

        -- Step 2: Identify transactions with same TransactionID but different Email
        INSERT INTO review.TransactionReview (TransactionID, FirstName, LastName, Email, DataSource, Quantity, ProductName, ProductPrice)
        SELECT 
            t.TransactionID,
            c.FirstName,
            c.LastName,
            c.Email,
            'eCommerce', -- Assuming eCommerce for now, adjust if needed
            o.Quantity,
            p.ProductName,
            p.Price
        FROM 
            staging.Transactions t
        JOIN 
            staging.Customers c ON c.CustomerID = t.CustomerID
        JOIN 
            staging.Orders o ON o.SurrogateTransactionID = t.SurrogateTransactionID
        JOIN 
            staging.Products p ON p.ProductID = o.ProductID
        WHERE 
            t.TransactionID IN (
                SELECT TransactionID
                FROM staging.Transactions t1
                JOIN staging.Customers c1 ON c1.CustomerID = t1.CustomerID
                GROUP BY t1.TransactionID
                HAVING COUNT(DISTINCT c1.Email) > 1
            );

        -- Step 3: Remove transactions with issues from staging.Transactions
        DELETE FROM staging.Transactions
        WHERE 
            TransactionID IN (
                SELECT TransactionID
                FROM review.TransactionReview
            );

   

    SET NOCOUNT OFF;
END
GO
/****** Object:  StoredProcedure [validation].[sp_ValidateData]    Script Date: 6/09/2024 4:54:59 PM ******/
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
