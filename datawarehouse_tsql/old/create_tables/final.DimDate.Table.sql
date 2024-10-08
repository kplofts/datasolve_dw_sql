USE [dw]
GO
/****** Object:  Table [final].[DimDate]    Script Date: 29/07/2024 8:46:44 AM ******/
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
