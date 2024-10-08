USE [dw]
GO
/****** Object:  StoredProcedure [normalize].[sp_Normalize_eCommerce_Data]    Script Date: 29/07/2024 8:46:44 AM ******/
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

        CREATE TABLE #DuplicateTransactions (
            TransactionID UNIQUEIDENTIFIER
        );

        INSERT INTO #DuplicateTransactions (TransactionID)
        SELECT TransactionID
        FROM (
            SELECT 
                TransactionID,
                Email,
                COUNT(*) OVER (PARTITION BY TransactionID, Email) AS EmailCountPerEmail
            FROM raw_source.eCommerce_data
        ) AS EmailCounts
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
