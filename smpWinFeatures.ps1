function CheckWinFeatures()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("winfeatures").count -ne 1)
    {
        ShowInfo "winfeatures node not found"
        return
    }

#  <winfeatures>
#    <check name="countInstalled" type="count" count="10" comparer="lt" />
#  </winfeatures>  

    if (!(CheckForElevatedAdmin "WinFeatures")) {return}

    # count the features once
    $featureCount = Count-Features

    $global:ConfigXml.servermonitor.winfeatures.check |
    ForEach {

       if ($_.GetAttribute("type") -eq "count")
       {
             Compare-Features -actualCount $featureCount -name $_.GetAttribute("name") -expectedNumber $_.GetAttribute("count") -comparer $_.GetAttribute("comparer")
       }  

    }
}

function Compare-Features([int]$actualCount,[string]$name,[int]$expectedNumber,[string]$comparer)
{  
    [string]$compareText = Compare-Values -actual $actualCount -expected $expectedNumber -comparer $comparer  
           
    if ($compareText -ne "")
    {
        [string]$body = ("Windows Features check '{0}' found {1} features where {2} {3} were expected." -f $name, $actualCount,$compareText,$expectedNumber)
        AddItem -info $body -Source "Windows Features checker" -EventId $smIdUnexpectedResult -EventType "Warning"
    }
}

function Count-Features()
{
    [OutputType([int])]
    Param()

    $recordCount = 0

    # Pre-2012, use Dism.exe
    if (Get-WindowsBuildNumber -lt $smWinBuildNT62)
    {
        $tempFile = "$env:temp\ServerMonitorWinFeatureCount.tmp"
        & dism.exe /online /get-features /format:table | out-file $tempFile -Force       
        $WinFeatures = (Import-CSV -Delim '|' -Path $tempFile -Header Name,state | Where-Object {$_.State -eq "Enabled "}) | Select Name
        Remove-Item -Path $tempFile 

        $recordCount = $WinFeatures.Count
    }
    else
    {
        $recordCount = (Get-WindowsOptionalFeature -Online | Where-Object {$_.State -eq "Enabled "}).count
    }

    return [int]$recordCount
}
