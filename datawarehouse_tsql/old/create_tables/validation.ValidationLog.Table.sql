USE [dw]
GO
/****** Object:  Table [validation].[ValidationLog]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [validation].[ValidationLog](
	[LogID] [int] IDENTITY(1,1) NOT NULL,
	[RunDateTime] [datetime] NOT NULL,
	[totalRecordsInSource] [int] NOT NULL,
	[totalRecordsInReview] [int] NOT NULL,
	[totalRecordsInStaging] [int] NOT NULL,
	[validationResultTotalRecords] [nvarchar](50) NOT NULL,
	[validationResultDistinctTransactions] [nvarchar](50) NOT NULL,
	[numberOfProductsInSource] [int] NOT NULL,
	[numberOfProductsInReview] [int] NOT NULL,
	[numberOfProductsInStaging] [int] NOT NULL,
	[totalSumInSource] [decimal](18, 2) NOT NULL,
	[totalSumInReview] [decimal](18, 2) NOT NULL,
	[totalSumInStaging] [decimal](18, 2) NOT NULL,
	[distinctCustomersInSource] [int] NOT NULL,
	[distinctCustomersInReview] [int] NOT NULL,
	[distinctCustomersInStaging] [int] NOT NULL,
	[distinctTransactionsInSource] [int] NOT NULL,
	[distinctTransactionsInReview] [int] NOT NULL,
	[distinctTransactionsInStaging] [int] NOT NULL,
	[QueryRuntime] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[LogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
