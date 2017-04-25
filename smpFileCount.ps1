function CheckFileCount()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("filecount").count -ne 1)
    {
        ShowInfo "filecount node not found"
        return
    }    
    
    $global:ConfigXml.servermonitor.filecount.check |
    ForEach {
        CountFiles $_.GetAttribute("folder") $_.GetAttribute("name") `
        $_.GetAttribute("filter") $_.GetAttribute("comparer") $_.GetAttribute("count") 
    }
}

function AddFCItem([string]$message,[int32]$id = $smIdUnexpectedResult,[string]$type = "Warning")
{
     AddItem -info $message -Source "File Count Checker" -EventId $id -EventType $type   
}


function CountFiles([string]$folder,[string]$name, [string]$filter,[string]$comparer,[int32]$expectedCount)
{
    try
    {
        $folder = ExpandEnvironmentVariables $folder
        $count = (get-childitem "$folder" -ErrorAction Stop | Where-Object {$_.Name -match $filter}).Count;
    }
    catch
    {
        $count -1
        $body = "File count check '$name ' threw an error: " + $_
        Write-Warning $body
        AddFCItem -message $body -id $smIdError -type "Error"
        return
    }

    $body = ""
   
    if ($comparer -eq "eq")
    {
        if ($count -ne $expectedCount)
        {
            $body += "$expectedCount were expected."
        }
    }

    if ($comparer -eq "gt")
    {
        if ($count -le $expectedCount)
        {
            $body = "more than $expectedCount were expected."
        }
    }

        
    if ($comparer -eq "lt")
    {
        if ($count -ge $expectedCount)
        {
            $body = "less than $expectedCount were expected."
        }
    }

    if ($body -ne "")
    {
        $body = "File count check '$name' found $count files where $body"
        AddFCItem -message $body
    }
}