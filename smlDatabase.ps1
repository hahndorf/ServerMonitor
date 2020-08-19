# For this logger to work you need a database server with a database (new or existing) 
# and two objects, a table and a stored procedure
# The code below is only tested with SQL-Server

# Create these two objects:

 <#
 
 CREATE TABLE [dbo].[serveralert](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[MachineName] [varchar](50) NOT NULL CONSTRAINT [DF_serveralert_MachineName]  DEFAULT (''),
	[TimeGenerated] [datetime] NOT NULL CONSTRAINT [DF_serveralert_TimeGenerated]  DEFAULT (getdate()),
	[LogName] [varchar](30) NOT NULL CONSTRAINT [DF_serveralert_Log]  DEFAULT (''),
	[EntryType] [varchar](50) NOT NULL CONSTRAINT [DF_serveralert_EntryType]  DEFAULT (''),
	[Source] [varchar](50) NOT NULL CONSTRAINT [DF_serveralert_Source]  DEFAULT (''),
	[EventId] [int] NOT NULL CONSTRAINT [DF_serveralert_EventId]  DEFAULT ((0)),
	[Message] [nvarchar](max) NOT NULL CONSTRAINT [DF_serveralert_Message]  DEFAULT (''),
 CONSTRAINT [PK_serveralert] PRIMARY KEY NONCLUSTERED 
 (
	[Id] ASC
 )
) 

GO

CREATE PROCEDURE [dbo].[ServerAlertInsert](
    @MachineName varchar(50),
    @LogName varchar(30),
    @TimeGenerated datetime,
    @EntryType varchar(50),
    @Source varchar(50),
    @EventId int,
    @Message varchar(max),
    @period INT = 10
)
AS

BEGIN

	DECLARE @EventCount INT
	SET @EventCount = 0

	-- for better performance, create a time one hour in the 
	-- past of the event time, we use this to enable
	-- a index seek
	DECLARE @TimeCut DATETIME
	SET @TimeCut = DATEADD(hh,-1,CAST(@TimeGenerated AS DATETIME))

	SELECT @EventCount = COUNT(*)
	FROM dbo.serveralert
	WHERE (TimeGenerated > @TimeCut)
	AND (MachineName = @MachineName)
	AND (LogName = @LogName)
	AND (EntryType = @EntryType)
	AND ([Source] = @Source)
	AND (EventId = @EventId)
	AND ([Message] = @Message)
	-- Difference between the existing time and new time should be
	-- less then x, so we don't do duplicates
	AND ABS(DATEDIFF(second,TimeGenerated,@TimeGenerated)) < @period

	IF @EventCount = 0
	BEGIN

		INSERT INTO dbo.serveralert
		(
		   [MachineName], 
		   [TimeGenerated], 
		   [LogName], 
		   [EntryType], 
		   [Source], 
		   [EventId], 
		   [Message]
		)
		VALUES
		(
			@MachineName,
			@TimeGenerated,
			@LogName,
			@EntryType,
			@Source,
			@EventId,
			@Message
		)

	END

END

GO

#>

# Also make sure that who-ever runs the script has execute permissions on the stored procedure.

# GRANT EXECUTE ON [dbo].[ServerAlertInsert] TO myUserName

# In the configuration file enable the database logger with an appropriate connection string
#  <loggers>
#    <database enabled="true" connectionstring="Server=.;Database=ServerMonitor;Integrated Security=True;" />
#  </loggers>

# our database connection object
$mySqlConnection = $null
 # used to buffer the last SQL statement to be written to the database
$myLastSql = ""
# if an event log entry already exists within this period, we don't log it again. In Seconds.
$myDuplicatePeriod = 10

function LogToDatabase()
{
    $myNode = GetLoggersNode "database"
    if ($null -eq $myNode) {return}
    $LogConnectionString = ExpandEnvironmentVariables $myNode.GetAttribute("connectionstring")

    if ($LogConnectionString -eq "") {return}
    LogToDatabaseTable $LogConnectionString
}

function ExecuteNonQuery([string]$sql)
{
    $sqlCommandUpdate = New-Object System.Data.SqlClient.SqlCommand $sql, $mySqlConnection 
	$result = $sqlCommandUpdate.ExecuteNonQuery()
}   

# adds an alert to the database
function AddAlertToDb($item)
{
   # build the SQL string. Open to SQL injection, if someone managed
   # to get his text into the eventlog. We only escape single quotes.
   # the user should only have execute permission on dbo.ServerAlertInsert
          
    $sql = "EXEC dbo.ServerAlertInsert '" + $item.MachineName + "','" + $item.LogName + "','" `
     + $item.TheTime.ToString("yyyy-MM-ddTHH:mm:ss") + "','" + $item.EventType `
     + "','" + $item.Source + "'," + $item.EventID + ",'"  `
     + $item.Info.Replace("'","''") + "'," + $myDuplicatePeriod
                 
    # only if we not used the same SQL before
    if ($sql -ne $myLastSql)
    {
        # buffer the sql for the next time
        $myLastSql = $sql
        # execute the SQL
        ExecuteNonQuery $sql
        # Write-Host $sql
    }            
}

function LogToDatabaseTable([string]$conString)
{
    # if the connection string has a semicolon we assume
    # it is not encrypted and use it as is, otherwise we decrypt it.
    if ($conString.IndexOf(";") -eq -1)
    {
         $conString = DPApiDecrypt $conString
    }
        
    $mySqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $mySqlConnection.ConnectionString = $conString
    $mySqlConnection.Open() 

    foreach($item in $Script:smFinalItems)
    {
        AddAlertToDb $item
    }

    $mySqlConnection.close()
    $script:internalLoggedTo += "database,"
}