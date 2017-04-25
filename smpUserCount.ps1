function CheckUserCount()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("usercount").count -ne 1)
    {
        ShowInfo "usercount node not found"
        return
    }    
    
    $global:ConfigXml.servermonitor.usercount.check |
    ForEach {
        CountUsers $_.GetAttribute("group") $_.GetAttribute("name") `
                   $_.GetAttribute("comparer") $_.GetAttribute("count") 
    }
}

function AddUCItem([string]$message,[int32]$id = $smIdUnexpectedResult,[string]$type = "Warning")
{
     AddItem -info $message -Source "User Count Checker" -EventId $id -EventType $type   
}


function CountUsers([string]$group,[string]$name, [string]$comparer,[int32]$expectedCount)
{
    try
    {
        if ($group -eq "*")
        {
            $count = (get-wmiobject -class "win32_account" -namespace "root\cimv2" `
            | where-object{$_.sidtype -eq 1} | where {$_.Disabled -eq $false} | measure).count
        }
        else
        {
            $groupCount = (get-wmiobject -class "win32_account" -namespace "root\cimv2" `
            | where-object{$_.sidtype -eq 4} | where-object{$_.Name -eq $group -or $_.sid -eq $group} | measure).count


            if ($groupCount -eq 0)
            {
                AddUCItem -message "Group '$group' not found"
                return
            }

            if ($groupCount -gt 1)
            {
                AddUCItem -message "More than one group matches '$group'"
                return
            }

            $groupName = (get-wmiobject -class "win32_account" -namespace "root\cimv2" `
            | where-object{$_.sidtype -eq 4} | where-object{$_.Name -eq $group -or $_.sid -eq $group}).name

            [int]$buildno = Get-WindowsBuildNumber

            if ($buildno -le [int]$smWinBuildNT100)
            {
                Write-Host "using old"

                $NtGroup = [ADSI]("WinNT://./$groupName,group")
                # get the members and loop through them comparing with the current user
                ($NtGroup.psbase.invoke("Members") `
                | %{$_.GetType().InvokeMember("Name", 'GetProperty', $null, $_, $null)}) `
                | foreach {
                    $userName = $_
                    $count += (get-wmiobject -class "win32_account" -namespace "root\cimv2" `
                    | where-object{$_.sidtype -eq 1} | where {$_.Disabled -eq $false} `
                    | where {$_.name -eq $userName} | measure).count
                }
            }
            else
            {   
                # Code for Windows 10 and newer        
                # There is a problem with $_.GetType().InvokeMember("Name" in Windows 10
                # we use the output from net localgroup:
                $myindex = 1
                $users = net localgroup "$groupName"
                $users | foreach {

                    # skip the first 6 and the last line in the output, they are boilerplate
                    if ($myindex -gt 6 -and $myindex -lt ($users.length - 1))
                    {
                        $userName = $_

                            $count += (get-wmiobject -class "win32_account" -namespace "root\cimv2" `
                            | where-object{$_.sidtype -eq 1} | where {$_.Disabled -eq $false} `
                            | where {$_.name -eq $userName} | measure).count
                    }

                    $myindex++
                }                
            }
            
         }
    }
    catch
    {
        $count -1
        $body = "User count check '$name ' threw an error: " + $_
        Write-Warning $body
        AddUCItem -message $body -id $smIdError -type "Error"
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
        $body = "User count check '$name' found $count users where $body"
        AddUCItem -message $body
    }
}