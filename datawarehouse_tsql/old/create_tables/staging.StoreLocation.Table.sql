USE [dw]
GO
/****** Object:  Table [staging].[StoreLocation]    Script Date: 29/07/2024 8:46:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [staging].[StoreLocation](
	[StoreID] [int] IDENTITY(1,1) NOT NULL,
	[StoreLocation] [varchar](100) NULL,
	[dateLoaded] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[StoreID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [staging].[StoreLocation] ADD  DEFAULT (getdate()) FOR [dateLoaded]
GO
