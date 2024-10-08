USE [dw]
GO
/****** Object:  StoredProcedure [clean].[sp_DeleteAllData]    Script Date: 29/07/2024 8:46:44 AM ******/
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
        -- Disable constraints on all tables
        EXEC sp_MSforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all";

        -- Delete data from final schema tables
        DELETE FROM final.FactSales;
        DELETE FROM final.DimCustomer;
        DELETE FROM final.DimProduct;
        DELETE FROM final.DimStoreLocation;


        -- Delete data from raw_source schema tables
        DELETE FROM raw_source.eCommerce_data;
        DELETE FROM raw_source.in_store_data;

        -- Delete data from staging schema tables
        DELETE FROM staging.Transactions;
        DELETE FROM staging.Orders;
        DELETE FROM staging.Products;
        DELETE FROM staging.Customers;
        DELETE FROM staging.StoreLocation;
        DELETE FROM staging.DuplicateLog;
        DELETE FROM staging.ETL_Log;

		DELETE FROM staging.ETL_Log;
		DELETE FROM staging.DuplicateLog;

		TRUNCATE TABLE [staging].[ETL_Log]
		TRUNCATE TABLE [staging].[DuplicateLog]
		TRUNCATE TABLE [validation].[ValidationLog]
		TRUNCATE TABLE [review].[TransactionReview]

		TRUNCATE TABLE [raw_source].[eCommerce_data]
		TRUNCATE TABLE [raw_source].[in_store_data]

        -- Enable constraints on all tables
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
