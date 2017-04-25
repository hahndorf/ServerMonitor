[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$target = $pwd
)
# Script to download and extract the latest version of ServerMonitor

Begin
{
    Function Test-Command {
       param($Command)
 
       $found = $false
       $match = [Regex]::Match($Command, "(?<Verb>[a-z]{3,11})-(?<Noun>[a-z]{3,})", "IgnoreCase")
       if($match.Success) {
           if(Get-Command -Verb $match.Groups["Verb"] -Noun $match.Groups["Noun"]) {
               $found = $true
           }
       }
 
       $found
    }

     function UnzipUsingDotNet
     {
         if ($WhatIfPreference.IsPresent)
         {
             Write-Output "what if: Unzipping using .Net to $tempFolder"  
         }
         else
         {           
             Write-Output "Unzipping using .Net to $tempFolder"         
             Expand-Archive -Path $tempFile -DestinationPath $tempFolder
         }
     }

     Function Move-TheFiles()
     {
         if ($WhatIfPreference.IsPresent)
         {
            Write-Output "what if: moving files from $tempFolder to $target"  
         }
         else
         {
            Get-ChildItem $tempFolder\ServerMonitor-master | Move-Item -Destination $target -Force
            Remove-Item $tempFolder -Force -Recurse        
         }
     }

     function UnzipUsingShell
     {

         if ($WhatIfPreference.IsPresent)
         {
            Write-Output "what if: Unzipping using shell to $tempFolder"  
         }
         else
         {
             # full GUI, use the shell
              Write-Output "what if: Unzipping $tempFile using shell to $tempFolder"
             New-Item -Path $tempFolder -ItemType Directory | Out-Null
             $zipPackage = (new-object -com shell.application).NameSpace($tempFile)
             $destinationFolder = (new-object -com shell.application).NameSpace($tempFolder)
             $destinationFolder.CopyHere($zipPackage.Items(),0x14)  
         }
     }
}

Process
{

    [string]$url = "https://github.com/hahndorf/ServerMonitor/archive/master.zip"
    [string]$timestamp = Get-Date -format "yyyyMMdd-HHmmss"
    [string]$tempFile = $env:temp + "\sm" + $timestamp + ".zip"
    [string]$tempFolder = $env:temp + "\sm" 
    $tempFolder += $timestamp 
   
    if ($WhatIfPreference.IsPresent)
    {
        Write-Output "What if: downloading $url"
    }
    else
    {
        Write-Output "Downloading $url to $tempFile"
        (New-Object System.Net.WebClient).DownloadFile($url,$tempFile)
    }

    If (Test-Command "Expand-Archive")
    {
        UnzipUsingDotNet
    }
    else
    {
        UnzipUsingShell
    }

    Move-TheFiles
    if ($WhatIfPreference.IsPresent)
    {
        Write-Output "What if: Deleting $tempFile"
    }
    else
    {
        Remove-Item $tempFile
    }
}