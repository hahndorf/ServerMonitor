
$internalLog = New-Object -TypeName "System.Text.StringBuilder"
$script:internalLoggedTo = ""
# a little bit extra entropy, but because it is public in this script it doesn't help too much.
$Global:smExtraEntropy = [byte[]](9,1,4,2,5)

# Issue Ids:
#============
# Server Monitor Core
[int]$smIdUserNotAdmin = 901
[int]$smIdError = 911
[int]$smIdUnexpectedResult = 912
[int]$smIdItemNotRunning = 913
[int]$smIdItemNotFound = 914
[int]$smIdConfigFileNotFound = 931
[int]$smIdConfigInvalid = 932
[int]$smIdAttentionRequired = 941
[int]$smIdHelperProgramNotFound = 951

# Windows Builds:
#=================
[int]$smWinBuildNT60 = 6000  # Windows Vista / 2008
[int]$smWinBuildNT61 = 7600  # Windows 7 / 2008 R2
[int]$smWinBuildNT62 = 9200  # Windows 8 / 2012
[int]$smWinBuildNT63 = 9600  # Windos 8.1 / 2012 R2
[int]$smWinBuildNT100 = 10240 # Windows 10 / 20xx

function CheckForElevatedAdmin([string]$providerName)
{
  $UserCurrent = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  [bool]$UserIsAdmin = $false

  # don't check for 'administrators', because in German they are 'Administratoren'
  # on 6.0+ it returns false for a non-elevated admin.
  $UserCurrent.Groups | ForEach-Object { if($_.value -eq "S-1-5-32-544") {$UserIsAdmin = $true} }

  if (!($UserIsAdmin))
  {
    AddItem -info "Current user is not an elevated admin as required by $providerName" -Source "ServerMonitor" `
            -EventId $smIdUserNotAdmin -EventType "Warning" 
    Write-Warning "not running as an elevated administrator as required by $providerName"
  }

  return $UserIsAdmin
}

function GetLoggersNode([string]$name)
{
    if ($global:ConfigXml.servermonitor.SelectNodes("loggers").count -ne 1)
    {
        Write-Warning "loggers node not found"
        return $null
    } 

    if ($global:ConfigXml.servermonitor.loggers.SelectNodes($name).count -ne 1)
    {
        return $null
    }

    $logNode = $global:ConfigXml.servermonitor.loggers.SelectSingleNode($name)

    if ($logNode.GetAttribute("enabled") -ne "true")
    {
        return $null
    }

    return $logNode
}

function GetAggregatorNode([string]$name)
{
    if ($global:ConfigXml.servermonitor.SelectNodes("aggregators").count -ne 1)
    {
        Write-Warning "aggregators node not found"
        return $null
    } 

    if ($global:ConfigXml.servermonitor.aggregators.SelectNodes($name).count -ne 1)
    {
        return $null
    }

    $aggregatorNode = $global:ConfigXml.servermonitor.aggregators.SelectSingleNode($name)

    if ($aggregatorNode.GetAttribute("enabled") -ne "true")
    {
        return $null
    }

    return $aggregatorNode
}

function Log($data)
{
   $internalLog.AppendLine((Get-Date -format "HH:mm:ss:fff") + " " + $data) | out-null
}

function AddItem()
{
param( 
    [parameter(Mandatory=$true)]
    [string]$Info, 
    [string]$MachineName = $env:COMPUTERNAME, 
    [string]$Source = "", 
    [int32]$EventId = 1, 
    [string]$LogName = "ServerMonitor", 
    [DateTime]$TheTime = (Get-Date), 
    [string]$EventType = "Warning"
)

    $smItem = New-Object PSObject
    Add-Member -InputObject $smItem -MemberType NoteProperty -Name MachineName -Value $MachineName
    Add-Member -InputObject $smItem -MemberType NoteProperty -Name Source -Value $Source
    Add-Member -InputObject $smItem -MemberType NoteProperty -Name EventId -Value $EventId
    Add-Member -InputObject $smItem -MemberType NoteProperty -Name LogName -Value $LogName
    Add-Member -InputObject $smItem -MemberType NoteProperty -Name TheTime $TheTime
    Add-Member -InputObject $smItem -MemberType NoteProperty -Name Info -Value $Info
    Add-Member -InputObject $smItem -MemberType NoteProperty -Name EventType -Value $EventType

    $smItems.Add($smItem) | out-null

}

function ShowSummary()
{
    [int]$countWarning = 0
    [int]$countErrors = 0
    [int]$countAll = 0

     foreach($item in $script:smFinalItems)
     {
        if ($item.EventType -eq "Warning") {$theColor = "yellow";$countWarning++}
        if ($item.EventType -eq "Error") {$theColor = "red";$countErrors++}
        $countAll++
     }

     $script:internalLoggedTo = $script:internalLoggedTo -replace ",$",""

     if($countWarning -eq 1)
     {
        Write-Host One warning found -ForegroundColor yellow
     }

     if($countErrors -eq 1)
     {
        Write-Host One error found -ForegroundColor red
     }

     if($countWarning -gt 1)
     {
        Write-Host $countWarning warnings found -ForegroundColor yellow
     }

     if($countErrors -gt 1)
     {
        Write-Host $countErrors errors found -ForegroundColor red
     }

     if($countAll -eq 0)
     {
        Write-Host "No problems found, all fine" -ForegroundColor green
     }
     else
     {
        Write-Host Logged to: $script:internalLoggedTo
     }   

      
}

function ExpandEnvironmentVariables([string]$data)
{
    # loop through all env variables and replace the token
    # in the string.
    Get-ChildItem env: | ForEach {
      $pattern = "%" + $_.Name + "%"
      $data = $data -replace $pattern, $_.Value
    }

    return $data

}

function GetLastCheck()
{
    $stateFile = "$env:temp\" + $StateName + ".cfg";

    if (test-path $stateFile)
    {
		$lastCheck = get-content $stateFile
		$lastCheck = [System.DateTime]::Parse($lastCheck)
    }
    else
    {
		# config file not found, go back one hour
		$lastCheck = [System.DateTime]::Now.AddHours(-1);
    }

    # write the current time as the last check
    $newCheck = [System.DateTime]::Now.ToString("yyyy-MM-ddTHH:mm:ss")
    Set-Content $stateFile -value $newCheck ;

    return $lastCheck
}

function ShowRunningFunction([string]$functionName)
{
    if ($VerbosePreference -eq "continue")
    {
        Write-Host "Running $functionName..." -ForegroundColor Cyan
    }
}

function ShowInfo([string]$info)
{
    if ($VerbosePreference -eq "continue")
    {
        Write-Host "  $info"
    }
}

function GetFunctionName([string]$fileName,[string]$FilePrefix,[string]$FuncPrefix)
{
    $FilePrefix = "^" + $FilePrefix

    $myfunction = $file.Name -replace $FilePrefix,""
    $myfunction = $myfunction -replace "\.ps1$",""
    $myfunction = $FuncPrefix + $myfunction

    ShowRunningFunction $myfunction

    return $myfunction

}

function DPApiDecrypt([string]$data)
{
  # Retrieve and decrypted password
  $encrytpedData = [System.Convert]::FromBase64String($data)
  $unencrytpedData = [System.Security.Cryptography.ProtectedData]::Unprotect( `
                         $encrytpedData, $Global:smExtraEntropy, 'LocalMachine')
  return [System.Text.Encoding]::UTF8.GetString($unencrytpedData)
}

function DPApiEncrypt([string]$data)
{
  $secret = [System.Text.Encoding]::UTF8.GetBytes($data);
  $encrytpedData = [System.Security.Cryptography.ProtectedData]::Protect( `
                          $secret, $Global:smExtraEntropy, 'LocalMachine')

  return [System.Convert]::ToBase64String($encrytpedData);
}

function Get-WindowsBuildNumber()
{
    [OutputType([int])]
    Param()

    Return [int](Get-Itemproperty "HKLM:\Software\Microsoft\Windows NT\CurrentVersion").CurrentBuild 
}

function Compare-Values()
{
    [OutputType([string])]
    Param(
        [int]$actual,
        [int]$expected,
        [string]$comparer
    )

    $compareText = ""

    if ($comparer -eq "eq" -and $actual -ne $expected)
    {
        $compareText = "exactly"
    }
    elseif ($comparer -eq "gt" -and $actual -le $expected)
    {
        $compareText = "more than"
    }        
    elseif ($comparer -eq "lt" -and $actual -ge $expected)
    {
        $compareText = "less than"
    }

    return $compareText
}

function RunCLIProgram([string]$fullPath,[string] $parameters)
{
	$startInfo = new-object System.Diagnostics.ProcessStartInfo
	$startInfo.FileName = "$fullPath"
	$startInfo.Arguments = "$parameters"
	$startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
	#Redirect the output, so we can read it below
	$startInfo.UseShellExecute = $FALSE
	$startInfo.RedirectStandardOutput = $TRUE
	$process = [system.Diagnostics.Process]::Start($startInfo)
	#read the output
	$processOutput = $process.StandardOutput.ReadToEnd()
	$process.WaitForExit()

    return $processOutput
}