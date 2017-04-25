function CheckWinUpdate()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("winupdate").count -ne 1) 
    {
        ShowInfo "winupdate node not found"
        return
    }

    $WinUpdate = $global:ConfigXml.servermonitor.winupdate.GetAttribute("frequency")

    # zero means don't check at all
    # one means check once a day
    # any other number means check always

    if ($WinUpdate -eq 0) {return}

    # to implement once a day, we look at the $LastCheck variable
    # if it is today, then the script already ran at least once 
    # today, so we don't check for updates, otherwise go ahead.
    if ($WinUpdate -eq 1)
    {
        if ($LastCheck.DayOfYear -eq (Get-Date).DayOfYear) {return}
    }

    CheckForWindowsUpdate
}

function CheckForWindowsUpdate()
{

ShowInfo "Checking Windows Update"

#Get All Assigned updates in $SearchResult
$UpdateSession = New-Object -ComObject Microsoft.Update.Session
$UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
# $SearchResult = $UpdateSearcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0 and Type='Software'")
# $SearchResult = $UpdateSearcher.Search("IsHidden=0 and IsInstalled=0 and Type='Software'")
$SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")

$allCount = 0
$importantCount = 0
$importantList = ""
$othersCount = 0
$othersList = ""
$requiresreboot = $false


$SearchResult.Updates | 
     ForEach-Object { 
     
     if (($_.MsrcSeverity -eq 'Critical') -OR ($_.MsrcSeverity -eq 'Important'))
     {
        $importantCount++
        $importantList += $_.Title + "`n"
        
        if ($_.RebootRequired)
        {
          $requiresreboot = $true
        }
     }
     else
     {
       $othersCount++
       $othersList += $_.Title + "`n"
     }
     
     $allCount++
          
   }

 ShowInfo "$importantCount important and $othersCount other updates available for $env:ComputerName"

    if ($importantCount -gt 0)
    {

    $body = @"
    $importantCount important or critical updates are available:
    =========================================================
    $importantList 

    A reboot is required: $requiresreboot
    Even if it says 'false' above a reboot may still be required.

    in addition $othersCount other updates are available:
    =========================================================
    $othersList
    
    also check: http://technet.microsoft.com/en-us/security/bulletin/

"@

     AddItem -info $body -Source "Windows Update Checker" `
      -EventId $smIdAttentionRequired -EventType "Warning"
    }
}

<# 
   Enables the Windows update check when an integer greater 0.
   A 1 means, it checks for updates once early in the day.
   Any integer greater 1 means it checks on every run.

   <winupdate frequency="1" />
#>