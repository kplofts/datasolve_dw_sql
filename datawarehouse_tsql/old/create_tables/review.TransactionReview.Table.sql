USE [dw]
GO
/****** Object:  Table [review].[TransactionReview]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [review].[TransactionReview](
	[TransactionID] [uniqueidentifier] NOT NULL,
	[FirstName] [varchar](100) NOT NULL,
	[LastName] [varchar](100) NOT NULL,
	[Email] [varchar](255) NOT NULL,
	[DataSource] [varchar](100) NOT NULL,
	[Quantity] [int] NOT NULL,
	[ProductName] [varchar](255) NOT NULL,
	[ProductPrice] [decimal](10, 2) NOT NULL,
	[ReviewDate] [datetime] NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [review].[TransactionReview] ADD  DEFAULT (getdate()) FOR [ReviewDate]
GO
