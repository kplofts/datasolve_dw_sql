USE [dw]
GO
/****** Object:  Table [staging].[Orders]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [staging].[Orders](
	[OrderID] [int] IDENTITY(1,1) NOT NULL,
	[OrderDate] [datetime] NULL,
	[ShippingAddress] [varchar](255) NULL,
	[StoreID] [int] NULL,
	[ProductID] [int] NULL,
	[Quantity] [int] NULL,
	[SurrogateTransactionID] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[OrderID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [staging].[Orders]  WITH NOCHECK ADD FOREIGN KEY([StoreID])
REFERENCES [staging].[StoreLocation] ([StoreID])
GO
ALTER TABLE [staging].[Orders]  WITH NOCHECK ADD  CONSTRAINT [FK_Orders_Products] FOREIGN KEY([ProductID])
REFERENCES [staging].[Products] ([ProductID])
GO
ALTER TABLE [staging].[Orders] CHECK CONSTRAINT [FK_Orders_Products]
GO
ALTER TABLE [staging].[Orders]  WITH NOCHECK ADD  CONSTRAINT [FK_staging_orders_SurrogateTransactionID] FOREIGN KEY([SurrogateTransactionID])
REFERENCES [staging].[Transactions] ([SurrogateTransactionID])
ON DELETE CASCADE
GO
ALTER TABLE [staging].[Orders] CHECK CONSTRAINT [FK_staging_orders_SurrogateTransactionID]
GO
