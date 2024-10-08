USE [dw]
GO
/****** Object:  Table [final].[FactSales]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [final].[FactSales](
	[FactSalesKey] [int] IDENTITY(1,1) NOT NULL,
	[CustomerKey] [int] NULL,
	[ProductKey] [int] NULL,
	[DateKey] [int] NULL,
	[StoreLocationKey] [int] NULL,
	[Quantity] [int] NULL,
	[UnitPrice] [decimal](10, 2) NULL,
	[TotalCost]  AS ([Quantity]*[UnitPrice]) PERSISTED,
	[TransactionDate] [datetime] NULL,
	[TransactionID] [uniqueidentifier] NULL,
	[OrderKey] [int] NULL
) ON [PRIMARY]
GO
