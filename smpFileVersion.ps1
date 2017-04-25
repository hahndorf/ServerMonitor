function CheckFileVersion()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("fileversion").count -ne 1)
    {
        ShowInfo "fileversion node not found"
        return
    }    
    
    $global:ConfigXml.servermonitor.fileversion.check |
    ForEach {
        CompareFolders $_.GetAttribute("reference") $_.GetAttribute("target") `
        $_.GetAttribute("pattern") $_.GetAttribute("reportmissing")
    }
}

function AddFVItem([string]$message,[int32]$id = $smIdUnexpectedResult,[string]$type = "Warning")
{
     AddItem -info $message -Source "File Version Checker" -EventId $id -EventType $type   
}

function CompareFolders([string]$ref,[string]$target,[string]$pattern,$reportMissing)
{
    $ref = ExpandEnvironmentVariables $ref
    $target = ExpandEnvironmentVariables $target
    
    get-childitem "$ref" | Where-Object {$_.Name -match $pattern} | foreach{

        $refVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($_.FullName).FileVersion        
        $targetFile =  $_.FullName.Replace($ref,$target)
        if (Test-Path $targetFile)
        {
        
            # implement other ways to compare the files: by date, by size or by content
            # should be pretty easy to do
        
            $targetVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($targetFile).FileVersion
            if ($refVersion -ne $targetVersion)
            {
                $message = "Version mismatch for " + $_.Name + "`n`r"
                $message += "Reference: " + [string]::Format("{0,-12}",$refVersion)  + " (" + $ref + ")`n`r"
                $message += "   Target: " + [string]::Format("{0,-12}",$targetVersion) + " ("+ $target + ")"
                AddFVItem $message
            }            
        }
        else
        {
            if ($reportMissing -eq "1")
            {
                $message = "File missing: " + $target + $_.Name
                AddFVItem $message
            }
        }
    }
}