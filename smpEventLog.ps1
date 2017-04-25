function CheckEventLog()
{

    # this is a provider for the old Windows Event Log API
    # this works under XP/Windows Server 2003

    if ($global:ConfigXml.servermonitor.SelectNodes("eventlog").count -ne 1)
    {
        ShowInfo "eventlog node not found"
        return
    }

    $mynode = $global:ConfigXml.servermonitor.eventlog

    $EventLogNameExpression = $mynode.GetAttribute("EventLogNameExpression")
    $EventSourceExpression = $mynode.GetAttribute("EventSourceExpression")
    $EventTypesToIncludeExpression = $mynode.GetAttribute("EventTypesToIncludeExpression")
    $EventIdsToExcludeExpression = $mynode.GetAttribute("EventIdsToExcludeExpression")

    # disable by setting the EventLogNameExpression to empty
    if ($EventLogNameExpression -eq "") {return}

    $machines = [regex]::split($Servers,'[, ;]')

    foreach ($machine in $machines) { CheckEventLogForOneMachine $machine}

}

function CheckEventLogForOneMachine([String]$hostname)
{			
	#write-host $Global:EntryTypes $Global:Sources $Global:excludeIDs
											
	# select logs matching the required ones e.g System|Application etc.
	$logs = [System.Diagnostics.EventLog]::GetEventLogs($hostname) `
	| where-object {($_.Log -match $EventLogNameExpression)}
		
	foreach($log in $logs)
	{	
		$logName = $log.LogDisplayName;
		ShowInfo "Checking eventlog for $hostname $logName"
		$message = "";
        
        # if event source starts with a bang, we treat it as exclude
        # otherwise it is include, which is the old behaviour
        if ($EventSourceExpression -match "^!")
        {
            $sourceExclude = $EventSourceExpression -replace "^!",""
        
            $LogEntries = $log.entries | where {($_.TimeWritten -ge $lastCheck) `
    		-AND ($_.EntryType -match $EventTypesToIncludeExpression)`
    		-AND ($_.EventID.ToString() -notmatch $EventIdsToExcludeExpression) `
    		-AND ($_.Source -notmatch $sourceExclude)}
        }
        else
        {
            $LogEntries = $log.entries | where {($_.TimeWritten -ge $lastCheck) `
    		-AND ($_.EntryType -match $EventTypesToIncludeExpression)`
    		-AND ($_.EventID.ToString() -notmatch $EventIdsToExcludeExpression) `
    		-AND ($_.Source -match $EventSourceExpression)}
        }
        	
        if ($LogEntries -ne $null) 
        {       	
            foreach($LogEntry in $LogEntries)
        	{      
        	    # The text for many events is stored in WIN32 DLLs and has
        	    # data tokens. In Event Viewer the text is loaded and
        	    # the tokens are replaced with the ReplacementStrings
        	    # This is not possible or hard to do in Powershell
        	    # So we just show the replacement string instead of a full message
        	    if ($LogEntry.Message -match "(^Die Beschreibung für Ereignis-ID)|(^The description for Event ID)")
                {
                    $message = "MISSING TEXT FOR " + $LogEntry.ReplacementStrings
                }
                else
                {                      
                    $message = $LogEntry.Message
                }

                AddItem -info $message `
                        -Source $LogEntry.Source `
                        -EventId $LogEntry.EventID `
                        -EventType $LogEntry.EntryType `
                        -TheTime $LogEntry.TimeGenerated `
                        -LogName $logName `
                        -MachineName $hostname
          }
        }

	}	
}