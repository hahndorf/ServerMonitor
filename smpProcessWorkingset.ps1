function CheckProcessWorkingSet()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("processworkingset").count -ne 1)
    {
        ShowInfo "processworkingset node not found"
        return
    }    
    
    $global:ConfigXml.servermonitor.processworkingset.check |
    ForEach-Object {
        CheckProcesses $_.GetAttribute("threshold") $_.GetAttribute("name")
    }
}

function AddPWSItem([string]$message,[int32]$id = $smIdUnexpectedResult,[string]$type = "Warning")
{
     AddItem -info $message -Source "Process Working Set Checker" -EventId $id -EventType $type   
}

function CheckProcesses([string]$threshold,[string]$name)
{
    # in PowerShell 3 something like 5GB works in where, but in Vs.2 we have to convert it.
    $intTreshold = [int64](invoke-expression ${threshold})

    get-process | Where-Object {$_.ProcessName -match $name -and $_.WorkingSet -gt $intTreshold} `
    | ForEach-Object {
        $size = ($_.WorkingSet /1MB)
        $filter = "ProcessId = " + $_.Id
        
        # this only works when ran as admin
        $cmd = Get-WmiObject Win32_Process -Filter $filter | select-Object CommandLine
        
        $body = "Process '" + $_.ProcessName + "' (" + $_.Id + ") has a working set size of " + $size.ToString("F1") + "MB - only $threshold are allowed. " + $cmd 
        AddPWSItem -message $body
    }
}