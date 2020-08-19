function CheckFolderSize()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("foldersize").count -ne 1)
    {
        ShowInfo "foldersize node not found"
        return
    }    
    
    $global:ConfigXml.servermonitor.foldersize.check |
    ForEach-Object {
        CheckDirectory $_.GetAttribute("max") $_.GetAttribute("path")
    }
}

function AddFZItem([string]$message,[int32]$id = $smIdUnexpectedResult,[string]$type = "Warning")
{
     AddItem -info $message -Source "Folder Size Checker" -EventId $id -EventType $type   
}

function CheckDirectory([String]$maxsize,[String]$folder)
{
    $intTreshold = [int64](invoke-expression ${maxsize})
    $folder = ExpandEnvironmentVariables $folder

    ShowInfo -info "Checking $folder for size $maxsize"

	$totalSize = get-childitem -recurse -force $folder `
	| measure-object -Property length -sum `
	| select-object sum

	if ($totalSize.Sum -gt $intTreshold)
	{
        $info = "'" + $folder + "' is too big, its total size is " + ($totalSize.Sum/1MB).ToString("N0") + " MB"
        $info += ", allowed are " + ($intTreshold/1MB).ToString("N0") + " MB`n"
        AddFZItem $info
	}
}