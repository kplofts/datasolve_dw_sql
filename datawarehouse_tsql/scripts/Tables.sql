USE [dw]
GO
/****** Object:  Table [final].[DimCustomer]    Script Date: 6/09/2024 4:55:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [final].[DimCustomer](
	[CustomerKey] [int] IDENTITY(1,1) NOT NULL,
	[FirstName] [varchar](100) NULL,
	[LastName] [varchar](100) NULL,
	[Email] [varchar](255) NULL,
	[Phone] [varchar](20) NULL,
	[Address] [varchar](255) NULL,
	[City] [varchar](100) NULL,
	[State] [varchar](100) NULL,
	[ZipCode] [varchar](20) NULL,
	[Country] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[CustomerKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [final].[DimDate]    Script Date: 6/09/2024 4:55:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [final].[DimDate](
	[DateKey] [int] NOT NULL,
	[Date] [date] NULL,
	[Year] [int] NULL,
	[Quarter] [int] NULL,
	[Month] [int] NULL,
	[Day] [int] NULL,
	[DayOfWeek] [int] NULL,
	[MonthName] [varchar](20) NULL,
	[DayName] [varchar](20) NULL,
	[IsWeekend] [bit] NULL,
	[CalendarYearMonth] [varchar](7) NULL,
PRIMARY KEY CLUSTERED 
(
	[DateKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [final].[DimOrder]    Script Date: 6/09/2024 4:55:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [final].[DimOrder](
	[OrderKey] [int] IDENTITY(1,1) NOT NULL,
	[OrderID] [int] NOT NULL,
	[ProductID] [int] NOT NULL,
	[Quantity] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[OrderKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [final].[DimProduct]    Script Date: 6/09/2024 4:55:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [final].[DimProduct](
	[ProductKey] [int] IDENTITY(1,1) NOT NULL,
	[ProductName] [varchar](255) NULL,
	[Category] [varchar](100) NULL,
	[Price] [decimal](10, 2) NULL,
	[ActualPrice] [decimal](10, 2) NULL,
PRIMARY KEY CLUSTERED 
(
	[ProductKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [final].[DimStoreLocation]    Script Date: 6/09/2024 4:55:41 PM ******/
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
/****** Object:  Table [final].[FactSales]    Script Date: 6/09/2024 4:55:41 PM ******/
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
/****** Object:  Table [raw_source].[eCommerce_data]    Script Date: 6/09/2024 4:55:41 PM ******/
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
/****** Object:  Table [raw_source].[in_store_data]    Script Date: 6/09/2024 4:55:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [raw_source].[in_store_data](
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
	[TransactionID] [uniqueidentifier] NULL,
	[StoreLocation] [varchar](100) NULL
) ON [PRIMARY]
GO
/****** Object:  Table [review].[TransactionReview]    Script Date: 6/09/2024 4:55:41 PM ******/
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
/****** Object:  Table [staging].[Customers]    Script Date: 6/09/2024 4:55:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [staging].[Customers](
	[CustomerID] [int] IDENTITY(1,1) NOT NULL,
	[FirstName] [varchar](100) NULL,
	[LastName] [varchar](100) NULL,
	[Email] [varchar](255) NULL,
	[Phone] [varchar](20) NULL,
	[Address] [varchar](255) NULL,
	[City] [varchar](100) NULL,
	[State] [varchar](100) NULL,
	[ZipCode] [varchar](20) NULL,
	[Country] [varchar](100) NULL,
	[dateLoaded] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[CustomerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [staging].[DuplicateLog]    Script Date: 6/09/2024 4:55:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create  TABLE [staging].[DuplicateLog](
	[LogID] [int] IDENTITY(1,1) NOT NULL,
	[TableName] [varchar](100) NULL,
	[DuplicateRecord] [nvarchar](max) NULL,
	[LogDate] [datetime] NULL,
	[Description] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[LogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [staging].[ETL_Log]    Script Date: 6/09/2024 4:55:41 PM ******/
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
/****** Object:  Table [staging].[Orders]    Script Date: 6/09/2024 4:55:41 PM ******/
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
/****** Object:  Table [staging].[Products]    Script Date: 6/09/2024 4:55:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [staging].[Products](
	[ProductID] [int] IDENTITY(1,1) NOT NULL,
	[ProductName] [varchar](255) NULL,
	[Category] [varchar](100) NULL,
	[Price] [decimal](10, 2) NULL,
	[dateLoaded] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[ProductID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [staging].[StoreLocation]    Script Date: 6/09/2024 4:55:41 PM ******/
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
/****** Object:  Table [staging].[Transactions]    Script Date: 6/09/2024 4:55:41 PM ******/
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
/****** Object:  Table [validation].[ValidationLog]    Script Date: 6/09/2024 4:55:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create TABLE [validation].[ValidationLog](
	[LogID] [int] IDENTITY(1,1),
	[RunDateTime] [datetime] NULL,
	[totalRecordsInSource] [int] NULL,
	[totalRecordsInReview] [int] NULL,
	[totalRecordsInStaging] [int] NULL,
	[validationResultTotalRecords] [nvarchar](50) NULL,
	[validationResultDistinctTransactions] [nvarchar](50) NULL,
	[numberOfProductsInSource] [int] NULL,
	[numberOfProductsInReview] [int] NULL,
	[numberOfProductsInStaging] [int] NULL,
	[totalSumInSource] [decimal](18, 2) NULL,
	[totalSumInReview] [decimal](18, 2) NULL,
	[totalSumInStaging] [decimal](18, 2) NULL,
	[distinctCustomersInSource] [int] NULL,
	[distinctCustomersInReview] [int] NULL,
	[distinctCustomersInStaging] [int] NULL,
	[distinctTransactionsInSource] [int] NULL,
	[distinctTransactionsInReview] [int] NULL,
	[distinctTransactionsInStaging] [int] NULL,
	[QueryRuntime] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[LogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [review].[TransactionReview] ADD  DEFAULT (getdate()) FOR [ReviewDate]
GO
ALTER TABLE [staging].[Customers] ADD  DEFAULT (getdate()) FOR [dateLoaded]
GO
ALTER TABLE [staging].[DuplicateLog] ADD  DEFAULT (getdate()) FOR [LogDate]
GO
ALTER TABLE [staging].[Products] ADD  DEFAULT (getdate()) FOR [dateLoaded]
GO
ALTER TABLE [staging].[StoreLocation] ADD  DEFAULT (getdate()) FOR [dateLoaded]
GO
ALTER TABLE [staging].[Transactions] ADD  DEFAULT (getdate()) FOR [dateLoaded]
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
ALTER TABLE [staging].[Transactions]  WITH NOCHECK ADD FOREIGN KEY([CustomerID])
REFERENCES [staging].[Customers] ([CustomerID])
GO
