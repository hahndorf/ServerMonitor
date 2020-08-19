function AggregateDefault()
{

    # Default Aggregator, groups by Logname,EventId,Source,EventType
    # if these are the same for certain items, they are grouped together

    $myItems = New-Object Collections.arraylist

    $myNode = GetAggregatorNode "default"
    if ($null -eq $myNode) {return}

    [int]$thresholdcount = $myNode.GetAttribute("thresholdcount")
    [string]$prefix = $myNode.GetAttribute("infoprefix")

    ShowInfo -Info "Thresholdcount: $thresholdcount"

    $Script:smFinalItems | Group-Object -Property Logname,EventId,Source,EventType | ForEach-Object {

        $Nameparts = $_.Name -split ","
        $first = $_.Group[0]

        if ($_.Count -ge $thresholdcount)
        {            
            $Item = New-Object PSObject
            Add-Member -InputObject $item -MemberType NoteProperty -Name MachineName -Value $first.MachineName
            Add-Member -InputObject $item -MemberType NoteProperty -Name Source -Value $Nameparts[2].Trim()
            Add-Member -InputObject $item -MemberType NoteProperty -Name EventId -Value $Nameparts[1].Trim()
            Add-Member -InputObject $item -MemberType NoteProperty -Name LogName -Value $Nameparts[0].Trim()
            Add-Member -InputObject $item -MemberType NoteProperty -Name TheTime $first.TheTime
            Add-Member -InputObject $item -MemberType NoteProperty -Name Info -Value "$($_.Count) $prefix $($first.Info)"
            Add-Member -InputObject $item -MemberType NoteProperty -Name EventType -Value $Nameparts[3].Trim()
            
            $myItems.Add($item) | out-null
        }
        else {
            $_.Group | ForEach-Object {
                
                $Item = New-Object PSObject
                Add-Member -InputObject $item -MemberType NoteProperty -Name MachineName -Value $_.MachineName
                Add-Member -InputObject $item -MemberType NoteProperty -Name Source -Value $_.Source
                Add-Member -InputObject $item -MemberType NoteProperty -Name EventId -Value $_.EventId
                Add-Member -InputObject $item -MemberType NoteProperty -Name LogName -Value $_.LogName
                Add-Member -InputObject $item -MemberType NoteProperty -Name TheTime $_.TheTime
                Add-Member -InputObject $item -MemberType NoteProperty -Name Info -Value $_.Info
                Add-Member -InputObject $item -MemberType NoteProperty -Name EventType -Value $_.EventType
                
                $myItems.Add($item) | out-null

            }
        }
    }

    $Script:smFinalItems =  $myItems

}

# Example XML:

# <aggregators>
#    <default enabled="true" thresholdcount="6" infoprefix="similar alerts to this:" />
# </aggregators>