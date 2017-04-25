function CheckHyperV()
{
    $is2012orNewer = $false
    
    # Windows Server 2012 has better build in tools
    # but make sure you have Hyper-V cmdlets enabled
    # Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell 
    if ([int]$script:MyOS.BuildNumber -ge $smWinBuildNT62)
    {
        $is2012orNewer = $true
    }

    if ($global:ConfigXml.servermonitor.SelectNodes("hyperv").count -ne 1) 
    {
        ShowInfo "hyperv node not found"
        return
    }

    try
    {
        if ($is2012orNewer)
        {
            # we don't have to do anything, now external module needed
        }
        else
        {
            # we may have the Hyper-V module installed in two different locations
            # or in one that is in the PSModulePath, try all three

            $mymoduleFile = $env:ProgramFiles + "\PowerShell\modules\HyperV\HyperV.psd1"
            [bool]$myModuleLoaded = $false

            if (Test-Path $mymoduleFile)
            {
                import-module $mymoduleFile -force -ErrorAction Stop
                $myModuleLoaded = $true
            }

            if (!($myModuleLoaded))
            {
                $mymoduleFile = $env:ProgramFiles + "\modules\HyperV\HyperV.psd1"
                if (Test-Path $mymoduleFile)
                {
                    import-module $mymoduleFile -force -ErrorAction Stop
                    $myModuleLoaded = $true
                }   
            }
        
            if (!($myModuleLoaded))
            {
                import-module HyperV -force -ErrorAction Stop
            }
        }
    }
    catch    
    {
        Write-Warning "Hyper-V PowerShell module could not be loaded!"
        AddItem -info "Hyper-V PowerShell module could not be loaded." `
                -Source "Hyper-V Checker" `
                -EventId $smIdError `
                -EventType "Error" 
        return
    }

    $global:ConfigXml.servermonitor.hyperv.check |
    ForEach {
        if ($is2012orNewer)
        {
            CheckHyperVMachine -vMachine $_.GetAttribute("name")
        }
        else
        {
            CheckHyperVBoxes $_.GetAttribute("name") 
        }
    }           
}

function CheckHyperVBoxes($vMachine)
{                               
    foreach ($box in $vMachine) 
    { 
        ShowInfo "Checking VM: $box"
        $result = Test-VMHeartbeat -vm $box
        if ($result.Status -ne "OK")
        {
            $message = "$box is not running in Hyper-V"
             
            AddItem -info $message `
                    -Source "Hyper-V Checker" `
                    -EventId $smIdItemNotRunning `
                    -EventType "Error"             
        }
    }        
}

function CheckHyperVMachine([string]$vMachine)
{       
    $countMachines = (Get-Vm | Where-Object name -eq "$vMachine").count
                       
    if ($countMachines -eq 0)
    {           
           AddItem -info "$vMachine does not exist in Hyper-V" `
                   -Source "Hyper-V Checker" `
                   -EventId $smIdItemNotFound `
                   -EventType "Error"           
    }
    else
    {
        # the name of the service is language dependent, but the last part of the id is always the same.
        $VMis = Get-VMIntegrationService -VMName $vMachine | Where Id -Like "*84EAAE65-2F2E-45F5-9BB5-0E857DC8EB47"

        if ($VMis.PrimaryStatusDescription -ne "OK") 
        {
           AddItem -info "$vMachine is not running in Hyper-V" `
                   -Source "Hyper-V Checker" `
                   -EventId $smIdItemNotRunning `
                   -EventType "Error"              
        }
    }          
}
