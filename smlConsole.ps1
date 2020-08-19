function LogToConsole()
{      
    # parameter can override config node           
    if (!($LogToConsole)) 
    {
        $myNode = GetLoggersNode "console"
        if ($null -eq $myNode) {return}
    }

    if ($Script:smFinalItems.count -eq 0) {return}

     Write-Host "===================== Console Logger: =========================="

     foreach($item in $Script:smFinalItems)
     {
        $LineOne = $item.MachineName + " - " + $item.TheTime.ToString("dd-MMM-yy HH:mm:ss") + " - " + $item.LogName
        $LineTwo = "Id: " + [string]$item.EventId + " - Source: " + $item.Source
        $LineThree = $item.Info

        $theColor = "white";

        if ($item.EventType -eq "Warning") {$theColor = "yellow"}
        if ($item.EventType -eq "Error") {$theColor = "red"}

        Write-Host "----------------------------------------------------------------"
        Write-Host $LineOne -ForegroundColor $theColor
        Write-Host $LineTwo -ForegroundColor $theColor
        Write-Host $LineThree -ForegroundColor $theColor
     }

     $script:internalLoggedTo += "console,"
}