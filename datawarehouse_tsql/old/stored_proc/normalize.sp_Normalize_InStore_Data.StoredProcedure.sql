USE [dw]
GO
/****** Object:  StoredProcedure [normalize].[sp_Normalize_InStore_Data]    Script Date: 29/07/2024 8:46:44 AM ******/
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
