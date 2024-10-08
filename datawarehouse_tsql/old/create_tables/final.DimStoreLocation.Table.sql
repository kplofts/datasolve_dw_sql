USE [dw]
GO
/****** Object:  Table [final].[DimStoreLocation]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [final].[DimStoreLocation](
	[StoreLocationKey] [int] IDENTITY(1,1) NOT NULL,
	[StoreLocation] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[StoreLocationKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
