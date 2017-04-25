function CheckDiskSpace()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("diskspace").count -ne 1) 
    {
        ShowInfo "diskspace node not found"
        return
    }

    $machines = [regex]::split($Servers,'[, ;]')

    foreach ($machine in $machines) 
    { 
        $global:ConfigXml.servermonitor.diskspace.check |
        ForEach {
            CheckDiskSpaceForOneMachine $machine $_.GetAttribute("drive") $_.GetAttribute("min")
        } 
    }
}

# Check the disk space for a single server
function CheckDiskSpaceForOneMachine([String]$hostname,[string]$drive,[int32]$minDiskSpace)
{
    ShowInfo "Checking disk-space for $hostname..."

    if ($hostname.Trim() -eq "")
    {
        Write-Warning "CheckDiskSpaceForOneMachine: No correct hostname"
        return
    }

    # make it critical if it is less than half or the required value
    $criticalDiskSpace = [int]($minDiskSpace / 2)
    $ourType = ""
    $ourId = 0

    $obj = (Get-WmiObject -class Win32_LogicalDisk -filter "DriveType=3" -computername $hostname)
			
    if ($drive -ne "*")
    {
        $drive = $drive + ":"
        $obj = $obj | Where-Object {$_.DeviceID -eq $drive}
    }

	foreach ($disk in $obj) 
	{
		if ($disk.Size -gt 0)
		{
			$freespace = ($disk.freespace /1GB)
			$totalspace = ($disk.Size /1GB)
			$freepercent = (($freespace / $totalspace)*100)
			if ($freepercent -lt $minDiskSpace) 
            {   
                $message = "Drive " + $disk.deviceid + " has " `
                + ($disk.freespace/1GB).ToString("F0") + "GB free of " `
                + ($disk.Size /1GB).ToString("F0") + "GB total. That's only " `
                + $freepercent.ToString("F0") + "% - more than " + $minDiskSpace.ToString("F0") + "% are required."

                $ourId =  $smIdUnexpectedResult

            	if ($freepercent -lt $criticalDiskSpace) 
                {              
                    $ourType = "error" 
                    
			    }
                else
                {  
                    $ourType = "warning"                                    
                }
                AddItem -info $message -Source "Diskspace Checker" -EventId $ourId  `
                    -EventType $ourType -MachineName $hostname
			}
		}
	}
}

<# 

   Disk space checking
   If a disk has less free space in percent than a warning is created.
   If the disk space is less than half of the specified value,
   and error is created instead.

  Example for the config file:

  <diskspace>
     <check drive="*" min="50" />
  </diskspace>

  or 

  <diskspace>
     <check drive="C" min="50" />
     <check drive="D" min="20" />
  </diskspace>

 #>