CREATE TABLE [staging].[Location](
	[SITEID] [nvarchar](100) NULL,
	[TURBINENO] [nvarchar](500) NOT NULL,
	[ISACTIVE] [char](1) NULL,
	[CREATEDBY] [nvarchar](100) NULL,
	[CREATEDDATE] [datetime] NULL,
	[LASTMODIFIEDBY] [nvarchar](100) NULL,
	[LASTMODIFIEDDATE] [datetime] NULL
) ON [PRIMARY]