USE [dw]
GO
/****** Object:  Table [staging].[ETL_Log]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [staging].[ETL_Log](
	[LogID] [int] IDENTITY(1,1) NOT NULL,
	[RunDateTime] [datetime] NULL,
	[StoredProcedureName] [nvarchar](255) NULL,
	[QueryRuntime] [int] NULL,
	[CustomersInserted] [int] NULL,
	[ProductsInserted] [int] NULL,
	[OrdersInserted] [int] NULL,
	[OrderProductsInserted] [int] NULL,
	[TransactionsInserted] [int] NULL,
	[StoreLocationsInserted] [int] NULL,
	[TotalRecordsInserted] [int] NULL,
	[DiskSpaceLeft] [nvarchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[LogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
