function CheckWinEvents()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("winevents").count -ne 1)
    {
        ShowInfo "winevents node not found"
        return
    }

    # get the milliseconds since the last run
    $lcMillSec = [int32]((Get-Date) - $LastCheck).TotalMilliseconds

    $global:ConfigXml.servermonitor.winevents.check |
    ForEach {
        $theLog = $_.GetAttribute("log")
        $theSources = $_.GetAttribute("sources")
        $theIds = $_.GetAttribute("ids")
        $theTypes = $_.GetAttribute("types")

        if ($theLog -eq "*")
        {
            # loop through all event logs
            Get-WinEvent -ListLog * -ErrorAction SilentlyContinue | foreach {                
                CheckOneCrimsonLog $_.LogName $lcMillSec $theTypes $theSources $theIds
            }
        }
        elseif($theLog -match "^!")
        {
            # loop through all but exclude the part behind the ! as regex
            $theLog = $theLog -replace "^!",""
            # replace commas and semicolons by a pipe to make it a regex
            $theLog = $theLog -replace "[,;]","|"
            Get-WinEvent -ListLog * -ErrorAction SilentlyContinue `
            | Where-Object{$_.LogName -notmatch $theLog }| foreach {                          
                CheckOneCrimsonLog $_.LogName $lcMillSec $theTypes $theSources $theIds
            }
        }
        else
        {
            # just consider the value a single log
            CheckOneCrimsonLog $theLog $lcMillSec $theTypes $theSources $theIds
        }
    }    
}

function BuildSelect([string]$log,[int32]$period,[string]$types)
{
    # the Filter Current Log dialog in Windows Event Log viewer
    # has a XML tab where you can see the XML for the criteria
    # I didn't find this out until I was done here.

    if ($types -eq "")
    {
        return ""
    }

    $levels = ""
    # now filter out types we don't want
    if ($types -like "*information*")
    {
        $levels = "Level=0 or Level=4"
    }

    if ($types -like "*warning*")
    {
        if ($levels -ne "") {$levels += " or "} 
        $levels += "Level=3"
    }

    if ($types -like "*error*")
    {
        if ($levels -ne "") {$levels += " or "}
        $levels += "Level=2"
    }

    # both AuditSuccess and AuditFailure have level 0
    if ($types -like "*Audit*")
    {
        if ($levels -ne "") {$levels += " or "}
        $levels += "Level=0"

        # we could do something like this here:
        # <Select Path="Security">*[System[band(Keywords,13510798882111488)]]</Select>
    }

    $qs =  "<Select Path=`"" + $log + "`">"
    $qs +=  "  *[System[(" + $levels + ") and"
    $qs += $eventType
    $qs += " TimeCreated[timediff(@SystemTime) &lt;= '" + $period + "']"
    $qs += "]]"
    $qs += "</Select>"

    return $qs
}

function CheckOneCrimsonLog([string]$log,[int32]$period,[string]$types,[string]$sources,[string]$ids)
{
# -ErrorAction SilentlyContinue
    
    # http://msdn.microsoft.com/en-us/library/bb671200.aspx
    # for using queryString
    # http://msdn.microsoft.com/en-us/library/windows/desktop/dd996910(v=vs.85).aspx

    $queryString = "<QueryList>"
    $queryString +=     "  <Query Id=`"0`" Path=`"Application`">"

    $queryString += BuildSelect $log $period $types

    $queryString += "</Query></QueryList>"
   
    $query = New-Object -TypeName System.Xml.XmlDocument
    $query.LoadXml($queryString)

 #   $query.OuterXml
     
    try
    {
        $logRecords = Get-WinEvent -FilterXml $query -ErrorAction Stop
    }
    catch
    {
        if ($_ -notmatch '(No events were found)|(Es wurden keine Ereignisse gefunden)')
        {
            AddItem -info $_ `
            -Source "WinEvents" `
            -EventId $smIdError `
            -EventType "Error" `
            -TheTime (Get-Date) `
            -LogName "ServerMonitor" `
            -MachineName $env:ComputerName
        }
        # in any case, we have a problem and can not continue
        return
    }

    if ($logRecords -eq $null)
    {
        return
    }

    # now we apply additional filters that seemd too complicated for XPath
    if ($sources -ne "")
    {
        if ($sources -match "^!")
        {
            # remove the first bang
            $sources = $sources -replace "^!",""
            # replace commas and semicolons by a pipe to make it a regex
            $sources = $sources -replace "[,;]","|"
            $logRecords = $logRecords | Where-Object {$_.ProviderName -notmatch $sources}
        }
        else
        {
            # replace commas and semicolons by a pipe to make it a regex
            $sources = $sources -replace "[,;]","|"
            $logRecords = $logRecords | Where-Object {$_.ProviderName -match $sources}
        }
    }

    if ($ids -ne "")
    {
        if ($ids -match "^!")
        {
            # remove the first bang
            $ids = $ids -replace "^!",""
            # replace commas and semicolons by a pipe to make it a regex
            $ids = $ids -replace "[,;]","|"
            $logRecords = $logRecords | Where-Object {$_.Id -notmatch $ids}
        }
        else
        {
            # replace commas and semicolons by a pipe to make it a regex
            $ids = $ids -replace "[,;]","|"
            $logRecords = $logRecords | Where-Object {$_.Id -match $ids}
        }
    }
    
    # in the NT eventlogs there was a property EntryType that
    # had AuditSuccess or AuditFailure, they now switched to
    # Level, but you can not tell the difference between the two
    # instead the distinction seem to be in the keywords field 
    # there are three possible values for the keywords:
    #  0x8020000000000000 = Success
    #  0x8010000000000000 = Failure
    #  0x4020000000000000 = Others, 11** events
    # so to filter, use these:
    # we have to use the hex values here, they look better too:
    # this means however, that as soon as we have Audit* in the types
    # none of the other levels matter anymore    
    
    if ($types -eq "AuditFailure")
    {
      $logRecords = $logRecords | Where-Object {$_.Keywords -eq 0x8010000000000000}
    }
    if ($types -eq "AuditSuccess")
    {
      $logRecords = $logRecords | Where-Object {$_.Keywords -eq 0x8020000000000000}
    } 
    if ($types -eq "AuditAdmin")
    {
      $logRecords = $logRecords | Where-Object {$_.Keywords -eq 0x4020000000000000}
    }    
    
    if ($logRecords -eq $null)
    {
        return
    }

     foreach($LogEntry in $logRecords)
     { 
        $message = ""
        if ($LogEntry -eq $null)
        {
            return
        }

  #      $LogEntry | fl -Property *
    
        $typeName = "information" # 0 or 4
        if ($LogEntry.Level -eq 2)
        {
            $typeName = "Error"
        }

        if ($LogEntry.Level -eq 3)
        {
            $typeName = "warning"
        }

        # most events don't have a message, it's all in the xml
        if ($LogEntry.Message -ne  $null)
        {
            $message = $LogEntry.Message
        }
        else
        {
            # get the xml
            [xml]$EventXML = $LogEntry.ToXML()

            $xmlns = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList $EventXML.NameTable
            $xmlns.AddNamespace("el", "http://schemas.microsoft.com/win/2004/08/events/event")
            
            if ($EventXML.SelectNodes("/el:Event",$xmlns).count -ne 1)
            {
                $message = "No xml data found for event"
            }
            else
            {             
                $subNodes = $EventXML.SelectSingleNode("/el:Event",$xmlns).SelectNodes("*") 

                foreach($node in $subNodes)
                {                    
                    if ($node.Name -eq "EventData")
                    {
                        $dataNodes = $node.SelectNodes("*")            
                        foreach($node in $dataNodes)
                        {         
                            $message += "  " + $node.Name + ": " + $node.InnerXml + "`r`n"    
                        }
                    }
                    elseif ($node.Name -eq "UserData")
                    {
                        $dataNodes = $node.SelectNodes("*")            
                        foreach($node in $dataNodes)
                        {         
                          #  $node | fl -Property *      
                            $message += "  " + $node.Name + ": " + $node.InnerXml + "`r`n"    
                        }
                    }
                    elseif ($node.Name -eq "System")
                    {
                        # ignore system, we already have the data we need
                    }
                    elseif ($node.LocalName -eq "EventData")
                    {
                        # $node | get-member

                        if ($node.HasAttribute("Name"))
                        {
                           $message += "  Name: " + $node.GetAttribute("Name") + "`r`n"  
                        }

                        $dataNodes = $node.SelectNodes("*")            
                        foreach($node in $dataNodes)
                        {         
                          #  $node | fl -Property *      
                            $message += "  " + $node.Name + ": " + $node.InnerXml + "`r`n"    
                        }
                    }
                    else
                    {                       
                       $message = "Unsupported node: $node.Name"
                   #    $node | fl -Property *
                    }

                }
            }
        }

        if ($message -eq "")
        {
            $message = "unable to get text"
        }

        AddItem -info $message `
        -Source $LogEntry.ProviderName `
        -EventId $LogEntry.Id `
        -EventType $typeName `
        -TheTime $LogEntry.TimeCreated `
        -LogName $LogEntry.LogName `
        -MachineName $env:ComputerName 
        
        # $LogEntry.MachineName may return the full name like "host.mydomain.com" which may conflict with filters we use later
     }

     # Log "  WinEvents $log completed" 
}