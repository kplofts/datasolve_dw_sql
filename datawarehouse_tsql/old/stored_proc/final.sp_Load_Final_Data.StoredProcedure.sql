USE [dw]
GO
/****** Object:  StoredProcedure [final].[sp_Load_Final_Data]    Script Date: 29/07/2024 8:46:44 AM ******/
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
