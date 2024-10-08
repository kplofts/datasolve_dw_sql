USE [dw]
GO
/****** Object:  Table [staging].[Transactions]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [staging].[Transactions](
	[SurrogateTransactionID] [int] IDENTITY(1,1) NOT NULL,
	[TransactionID] [uniqueidentifier] NULL,
	[CustomerID] [int] NULL,
	[TransactionDate] [datetime] NULL,
	[StoreID] [int] NOT NULL,
	[dateLoaded] [datetime] NULL,
	[Status] [nchar](10) NULL,
	[PaymentMethod] [nchar](10) NULL,
PRIMARY KEY CLUSTERED 
(
	[SurrogateTransactionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [staging].[Transactions] ADD  DEFAULT (getdate()) FOR [dateLoaded]
GO
ALTER TABLE [staging].[Transactions]  WITH NOCHECK ADD FOREIGN KEY([CustomerID])
REFERENCES [staging].[Customers] ([CustomerID])
GO
