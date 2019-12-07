<#PSScriptInfo

.VERSION 3.5

.GUID adb3e842-21c9-4547-9011-213afb1919ea

.AUTHOR Peter Hahndorf

.COMPANYNAME 

.COPYRIGHT Peter Hahndorf

.TAGS 

.LICENSEURI https://peter.hahndorf.eu/tech/servermonitor.html

.PROJECTURI https://peter.hahndorf.eu/tech/servermonitor.html

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

#>

# Server Monitor Powershell Script
# Monitors Event logs and other stuff on a Windows Server
#   Created: 26-Oct-2007 - https://peter.hahndorf.eu
# Version 3:  6-Oct-2012 
#    Latest:  7-Dec-2019
param(
    [parameter(Position=0,Mandatory=$false,ParameterSetName = "Default")]
    [string]$ConfigFile = "",
    [parameter(ParameterSetName = "Default")]
    [string]$Servers,
    [parameter(ParameterSetName = "Default")]
    [DateTime]$LastCheck,
    [parameter(ParameterSetName = "Default")]
    [string]$StateName = "servermonitor",
    [parameter(ParameterSetName = "Default")]
    [Switch]$LogToConsole,
    [parameter(Mandatory=$true,ParameterSetName = "Encrypt")]
    [string]$EncryptText = ""
 )

$script:MyName = "Server Monitor"
$script:MyVersion = "3.5.79.0"
$script:MyOS = Get-WmiObject -Class Win32_OperatingSystem -Namespace root/cimv2

# Required for decrypting a DPAPI secret
Add-Type -assembly System.Security

# ============================ Load Support Files ============================

function Get-ScriptDirectory
{
  # get the directory this script is in 
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}

# get a list of all support files and plugins
$smFiles = get-childitem (Get-ScriptDirectory) | Where-Object {$_.Name -match "^sm.+ps1$"}

# load them
foreach($file in $smFiles)
{
    . $file.FullName
}

# Write-Verbose "Check-Functions found:"
# Get-ChildItem Function: | Where-Object Name -match "^Check" | ForEach-Object { Write-Verbose "$($_.Name)"}

# ============================= Configuration ===============================

Write-Host "================== $script:MyName Vs. $script:MyVersion ================="

# Special Call to encrypt a text
if ($EncryptText -ne "")
{
    Write-Host $(DPApiEncrypt -data $EncryptText)
    Exit 0
}

# A collection to store all our issues in
# This is filled by the various providers
$smItems = new-object Collections.arraylist

Log "Script started as $env:username"

if ($Servers -eq "")
{
    $Servers = $env:COMPUTERNAME
}

if ($LastCheck -eq $null)
{
    $LastCheck = GetLastCheck
}

if ($Verbose)
{
   $VerbosePreference = "continue"
}

if ($ConfigFile -eq "")
{
    # load a file with the same base name as the script itself
 	$myPath = Split-Path -Parent $MyInvocation.MyCommand.Path;
	$myFile = Join-Path -Path $myPath -childPath $myInvocation.MyCommand.Name;
	$ConfigFile = $myFile.Replace("ps1","xml");
    $MyNameConfigFile = $ConfigFile
    if (!(Test-Path $ConfigFile))
    {
        # not found, try with computername
        $ConfigFile = Join-Path -Path $myPath -childPath $env:computername;
        $ConfigFile += ".xml"
    }
}
else
{
    $ConfigFile = ExpandEnvironmentVariables $ConfigFile
}

if (!(Test-Path $ConfigFile))
{
    $message = "Neither $MyNameConfigFile nor $ConfigFile do exist. Edit and rename example.xml, you can also use the -ConfigFile parameter"
    Write-Warning $message
    AddItem -info $message -EventId $smIdConfigFileNotFound
    exit 1
}
else
{
    ShowInfo "Using $ConfigFile"
}

try
{
    $global:ConfigXml = [xml](Get-Content $ConfigFile)
}
catch
{
    Write-Warning "Problem loading configuration file"
    Write-Warning  $ConfigFile
    write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

# ============================ Execute Providers ============================
foreach($file in $smFiles)
{
    if($file.Name -match "^smp") # all providers begin with smp
    {
        $CheckFunction = GetFunctionName $file.Name "^smp" "Check"
        # execute the function
        & ($CheckFunction)
        Log "$CheckFunction completed"
    }
}
# ============================ Execute Loggers ============================
foreach($file in $smFiles)
{
    if($file.Name -match "^sml") # all loggers begin with sml
    {
        $LogFunction = GetFunctionName $file.Name "^sml" "LogTo"
        & ($LogFunction)
    }
}

ShowSummary

<# 
   .SYNOPSIS
   Script to monitor various aspects of a Windows OS

   .DESCRIPTION
   This version works with the concept of plugins.
   There are two types of plugins:
   
   1. Providers that provide information about issues
   from various sources.
   2. Loggers that do something with that information.

   Both providers and loggers are implemented as 'support files'
   and have to be in the same directory as the main script.

   The script first executes all providers. Any errors or 
   warnings are stored in an internal data structure.

   Then every logger is executed, each logger has access to
   the data and can use it however it wants.

   All configuration is in an XML file. You may to pass
   in the filename as the first parameter to the script.

   The executing user needs to be a member of the administrators group
   for some providers to work.
   
   Requires Powershell 2 or higher
   
   Some providers require Windows Server 2008 R2 or later to work.
   (WinEvents provider doesn't work on Vista/2008 or older)
    
   .PARAMETER configfile
   An xml file with configuration settings for providers, loggers and the base script

   .PARAMETER Servers
   Comma separated list of servernames to check. If empty the local machine is used.
   Most providers ignore this setting and always check the local machine only.

   .PARAMETER LastCheck
   Specify a time in the past to limit checks to all events after that time.
   If not specified, the time this user last ran this scripts is considered LastCheck.
   Not all providers use this parameter.

   .PARAMETER StateName
   When using more than one instance of ServerManager as the same user, give it name.
   The name is used to save a file in the user's temp directory.

   .PARAMETER LogToConsole
   If present, the issues are printed out on the console.
   This overrides whatever the config files says for the console logger.

   .PARAMETER Verbose
   If present, additional information is displayed on the console.
   The loggers don't log any additional data.

   .PARAMETER EncryptText
   Provide a string which you want to encrypt with the internal encryption 
   No providers or loggers are executed in this mode.

    .EXAMPLE
    ServerMonitor3.ps1
    Uses ServerMonitor3.xml in the same directory as the configuration file.

    .EXAMPLE
    ServerMonitor3.ps1 .\myconfig.xml -LastCheck ((Get-Date).AddHours(-1))
    Specifies a configuration file and only checks event log entries in the last hour

    .EXAMPLE
    ServerMonitor3.ps1 .\myconfig.xml -LastCheck "2007-10-26 14:00"
    Specifies a configuration file and only checks event log entries since the specified date

    .EXAMPLE
    ServerMonitor3.ps1 -encryptText "Server=.;Database=sm;Integrated Security=True;"
    Encrypts the text specified and displays it.

.NOTES

    Author:  Peter Hahndorf
    Created: October 26, 2007 
    
.LINK
    https://peter.hahndorf.eu/tech/servermonitor.html
    https://github.com/hahndorf/ServerMonitor
 #>