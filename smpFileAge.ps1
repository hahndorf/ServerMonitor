function CheckFileAge()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("fileage").count -ne 1)
    {
        ShowInfo "fileage node not found"
        return
    }    
    
    $global:ConfigXml.servermonitor.fileage.check |
    ForEach {
        CompareFileAge $_.GetAttribute("maxage") $_.GetAttribute("folder")
    }
}

function AddFAItem([string]$message,[int32]$id = $smIdUnexpectedResult,[string]$type = "Error")
{
     AddItem -info $message -Source "File Age Checker" -EventId $id -EventType $type   
}


function CompareFileAge([string]$maxage,[String]$folder)
{

    $intTreshold = [int64](invoke-expression ${maxage}) * -1

    Get-ChildItem  -recurse -path $folder | where { $_.CreationTime -lt ((get-date).AddMinutes($intTreshold)) } | 
    foreach {
        $message = "Checking " + $_.DirectoryName + ": file is older than defined threshold of " + $intTreshold * -1 + " minutes: " + $_.Name + " [created at : " + $_.CreationTime + "]`n`r"
        AddFAItem $message
    }

}