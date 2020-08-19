function LogToFile()
{
    $myNode = GetLoggersNode "file"
    if ($null -eq $myNode) {return}  

    $LogFileBase = ExpandEnvironmentVariables $myNode.GetAttribute("base")
    if ($logFolder -eq "") {return}
    
    $logFolder = [System.IO.Path]::GetDirectoryName($LogFileBase)

    if (!(Test-Path $logFolder))
    {
        Write-Warning "File-Logger directory '$logFolder' not found"
        return
    }

    $timestamp = Get-Date -format "yyyy-MM-dd"
    $fileName = $LogFileBase + $timestamp + ".log"

    $content = "==============================================================================`r`n"
    $content += $internalLog.ToString()
    $content += "==============================================================================`r`n"
    $content | Out-File -FilePath $fileName -Append

     foreach($item in $Script:smFinalItems)
     {
        $content = $item.MachineName + " - " + $item.TheTime.ToString("dd-MMM-yy HH:mm:ss") + " - " `
                 + $item.LogName + " - " + $item.EventType + "`r`n"
        $content += "Id: " + [string]$item.EventId + " - Source: " + $item.Source + "`r`n"
        $content += $item.Info + "`r`n"
        $content += "------------------------------------------------------------------------------`r`n"

        $content | Out-File -FilePath $fileName -Append
     }

    $script:internalLoggedTo += "file,"
    
    ShowInfo "Logged to: $fileName"
}