function CheckFileAge()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("fileage").count -ne 1)
    {
        ShowInfo "fileage node not found"
        return
    }    
    
    $global:ConfigXml.servermonitor.fileage.check |
    ForEach {
        CompareFileAge $_.GetAttribute("maxage") $_.GetAttribute("folder") $_.GetAttribute("recurse") $_.GetAttribute("filespec")
    }
}

function AddFAItem([string]$message,[int32]$id = $smIdUnexpectedResult,[string]$type = "Error")
{
     AddItem -info $message -Source "File Age Checker" -EventId $id -EventType $type   
}


function CompareFileAge([string]$maxage,[String]$folder,[string]$recurse,[string]$fileSpec)
{

    # default is true
    [bool]$recursive = $true;
    if ($recurse -match "false|no")
    {
        $recursive = $false
    }

    if ($fileSpec -eq "")
    {
        $fileSpec = ".+"
    }

    $intTreshold = [int64](invoke-expression ${maxage}) * -1
    $folder = ExpandEnvironmentVariables $folder

    ShowInfo "Testing Folder `'$folder`' with spec: `'$fileSpec`', maxAge: $intTreshold min"

    # only check for files
    Get-ChildItem -File -Recurse:$recursive -path $folder | Where-Object {$_.Name -match "$fileSpec"} | where { $_.LastWriteTime -lt ((get-date).AddMinutes($intTreshold)) } | 
    foreach {
        $message = "File:  '" + $_.FullName + "' is older than defined threshold of " + $intTreshold * -1 + " minutes, [modified at : " + $_.LastWriteTime + "]`n`r"
        AddFAItem $message
    }
}