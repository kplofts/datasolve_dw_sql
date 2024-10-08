USE [dw]
GO
/****** Object:  StoredProcedure [validation].[sp_duplicateCheck]    Script Date: 29/07/2024 8:46:44 AM ******/
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
