USE [dw]
GO
/****** Object:  StoredProcedure [master].[sp_RunETLProcesses]    Script Date: 29/07/2024 8:46:44 AM ******/
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
        @recipients = 'YOUR_EMAIL',
        @subject = 'ETL Pipeline Successfully ran',
        @body = @EmailBody,
        @body_format = 'TEXT';

    -- Cleanup temporary table
    DROP TABLE #EmailBodyDetails;
END;
GO
