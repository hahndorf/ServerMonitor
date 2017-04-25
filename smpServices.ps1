function CheckServices()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("services").count -ne 1) 
    {
        ShowInfo "services node not found"
        return
    }

    $machines = [regex]::split($Servers,'[,;]')

    foreach ($machine in $machines) 
    { 
        $global:ConfigXml.servermonitor.services.check |
        ForEach {
            CheckServicesForOneMachine $machine $_.GetAttribute("name") 
        }           
    }
}

function CheckServicesForOneMachine([string]$hostname,[string]$name)
{
    if ($name -eq "") {return}
                          
    ShowInfo "Checking Service: $name on $hostname"

    try
    {  
        $result = GET-Service $name -ComputerName $hostname -ErrorAction Stop
        if ($result.Status -ne "Running")
        {
            $message = "$name is not running"
            AddItem -info $message -Source "Services Checker" -EventId $smIdItemNotRunning `
                    -EventTyp "Error"               
        }
    }
    catch
    {
            $message = "$name service does not exist"
            AddItem -info $message -Source "Services Checker" -EventId $smIdItemNotRunning `
                    -EventType "Error" -MachineName $hostname
    }        
}