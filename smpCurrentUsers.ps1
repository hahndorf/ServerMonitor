function CheckCurrentUsers()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("currentusers").count -ne 1)
    {
        ShowInfo "currentusers node not found"
        return
    }    
    
    $global:ConfigXml.servermonitor.currentusers.check |
    ForEach-Object {
        CountCurrentUsers $_.GetAttribute("name") $_.GetAttribute("maxallowedminutes")
    }
}

function AddCurrentUsersItem([string]$message,[int32]$id = $smIdUnexpectedResult,[string]$type = "Warning")
{
     AddItem -info $message -Source "Current users Checker" -EventId $id -EventType $type   
}

function CountCurrentUsers([string]$name,[int32]$maxallowedminutes)
{

    [DateTime]$TimeNow=(GET-DATE)

    try
    {
        $users = ((quser) -replace '^>', '') -replace '\s{2,}', ',' | ConvertFrom-Csv

        $users | ForEach-Object {
            
            # sometimes Logon Time is null and IDLE TIME is set instead.
            $theTime = ""
            if ($_."IDLE TIME" -ne $null -and $_."IDLE TIME" -ne ".")
            {
               $theTime = $_."IDLE TIME"
            }
            
            if ($_."Logon Time" -ne $null -and $_."Logon Time" -ne ".")
            {
               $theTime = $_."Logon Time"
            }  

            $logonTime = [DateTime]::Parse($theTime)
            $loggedOn = New-TimeSpan -Start $logonTime -End $TimeNow
            $loggedMinutes =  [math]::Round($loggedOn.TotalMinutes)
            
            if ($loggedMinutes -gt $maxallowedminutes)
            {
                $body = "User `'$($_.USERNAME)`' logged on at `'$($logonTime.ToString())`', $loggedMinutes minutes ago, only $maxallowedminutes minutes are allowed"  
                AddCurrentUsersItem -message $body
            }               
        }
    }
    catch
    {
        $count -1
        $body = "Current Users check '$name' threw an error: " + $_
        Write-Warning $body
        AddCurrentUsersItem -message $body -id $smIdError -type "Error"
        return
    }
}

# Example XML:

# <?xml version="1.0"?>
# <servermonitor version="3.0">

#   <loggers>
#     <console enabled="true" />
#   </loggers>
  
#   <currentusers>
#      <check name="any" maxallowedminutes="30" />
#   </currentusers>
  
# </servermonitor>