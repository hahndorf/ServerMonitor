function AggregateDefault()
{

    # Default Aggregator, groups by Logname,EventId,Source,EventType
    # if these are the same for certain items, they are grouped together

    $myItems = New-Object Collections.arraylist

    $myNode = GetAggregatorNode "default"
    if ($null -eq $myNode) {return}

    [int]$threshold = $myNode.GetAttribute("threshold")
    [string]$prefix = $myNode.GetAttribute("infoprefix")

    ShowInfo -Info "Thresholdcount: $threshold"

    # loop through all items still here,
    # group all items with the same Logname,EventId,Source,EventType together

    $Script:smFinalItems | Group-Object -Property Logname,EventId,Source,EventType | ForEach-Object {

        # this is the first item from the group, we use it for the properties
        $first = $_.Group[0]

        if ($_.Count -ge $threshold)
        {
            # create a new item
            $Item = New-Object PSObject
            Add-Member -InputObject $item -MemberType NoteProperty -Name MachineName -Value $first.MachineName
            Add-Member -InputObject $item -MemberType NoteProperty -Name Source -Value $first.Source
            Add-Member -InputObject $item -MemberType NoteProperty -Name EventId -Value $first.EventId
            Add-Member -InputObject $item -MemberType NoteProperty -Name LogName -Value $first.LogName
            Add-Member -InputObject $item -MemberType NoteProperty -Name TheTime $first.TheTime
            Add-Member -InputObject $item -MemberType NoteProperty -Name EventType -Value $First.EventType
            # this is the special property, we add the number of occurrances to it:
            Add-Member -InputObject $item -MemberType NoteProperty -Name Info -Value "$($_.Count) $prefix $($first.Info)"
            
            $myItems.Add($item) | out-null
        }
        else {

            # if we are below the threshold, we add an item for each original item.
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