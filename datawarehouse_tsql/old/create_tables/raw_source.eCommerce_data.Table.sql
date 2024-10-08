USE [dw]
GO
/****** Object:  Table [raw_source].[eCommerce_data]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [raw_source].[eCommerce_data](
	[FirstName] [varchar](100) NULL,
	[LastName] [varchar](100) NULL,
	[Email] [varchar](255) NULL,
	[Phone] [varchar](20) NULL,
	[Address] [varchar](255) NULL,
	[City] [varchar](100) NULL,
	[State] [varchar](100) NULL,
	[ZipCode] [varchar](20) NULL,
	[Country] [varchar](100) NULL,
	[OrderDate] [date] NULL,
	[Time] [time](7) NULL,
	[ShippingAddress] [varchar](255) NULL,
	[OrderStatus] [varchar](50) NULL,
	[ProductName] [varchar](255) NULL,
	[ProductPrice] [decimal](10, 2) NULL,
	[Category] [varchar](100) NULL,
	[Quantity] [int] NULL,
	[TransactionID] [uniqueidentifier] NULL
) ON [PRIMARY]
GO
