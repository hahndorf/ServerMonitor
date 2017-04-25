$DBValueSqlConnection = $null

function CheckSqlCount()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("sqlcount").count -ne 1)
    {
        ShowInfo "sqlcount node not found"
        return
    }
    CheckDatabase
}

function CheckScalarCount($name,$expectedNumber,$comparer,$sql)
{
    try
    {
        $body = ""
        $sql = $sql.trim()
        ShowInfo "Executing: $sql"
        $sqlCommandUpdate = New-Object System.Data.SqlClient.SqlCommand $sql, $DBValueSqlConnection 
        $recordCount = $sqlCommandUpdate.ExecuteScalar()

        if ($comparer -eq "eq")
        {
            if ($recordCount -ne $expectedNumber)
            {
                $body = "Database check '$name' found $recordCount records where $expectedNumber were expected."
            }
        }

        if ($comparer -eq "gt")
        {
            if ($recordCount -le $expectedNumber)
            {
                $body = "Database check '$name' found $recordCount records where more than $expectedNumber were expected."
            }
        }

        
        if ($comparer -eq "lt")
        {
            if ($recordCount -ge $expectedNumber)
            {
                $body = "Database check '$name' found $recordCount records where less than $expectedNumber were expected."
            }
        }

        if ($body -ne "")
        {
           AddItem -info $body -Source "Database checker" -EventId $smIdUnexpectedResult -EventType "Warning"
        }
    }
    catch
    {
        $body = "Database check '$name ' threw an error: " + $_
        AddItem -info $body -Source "Database checker" -EventId $smIdError -EventType "Error"
    }
}

function CheckDatabase()
{ 
    try
    {
        $constring = $global:ConfigXml.servermonitor.sqlcount.GetAttribute("connectionstring")
    }
    catch
    {
        $message = "Connection string not defined as attribute of the 'sqlcount' node in '$ConfigFile'"
        Write-Warning $message
        AddItem -info $message -Source "SqlCount Checker" `
                -EventId $smIdConfigInvalid  -EventType "Warning"        

        return
    }

    if ($constring -eq "")
    {
        $message = "Connection string not defined as attribute of the 'sqlcount' node in '$ConfigFile'"
        Write-Warning $message
        AddItem -info $message -Source "SqlCount Checker" `
                -EventId $smIdConfigInvalid  -EventType "Warning"        

        return
    }

    if ($conString.IndexOf(";") -eq -1)
    {
         $conString = DPApiDecrypt $conString
    }

    $DBValueSqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $DBValueSqlConnection.ConnectionString = $conString
    $DBValueSqlConnection.Open() 

    $global:ConfigXml.servermonitor.sqlcount.check |
    ForEach {
        CheckScalarCount $_.GetAttribute("name") $_.GetAttribute("count") `
        $_.GetAttribute("comparer") $_.SelectSingleNode(".").InnerText
    }

    $DBValueSqlConnection.close()
}