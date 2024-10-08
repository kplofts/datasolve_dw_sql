USE [dw]
GO
/****** Object:  StoredProcedure [master].[LogDiagnostics]    Script Date: 29/07/2024 8:46:44 AM ******/
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
