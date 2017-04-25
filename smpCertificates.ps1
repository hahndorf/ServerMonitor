function AddCheckCertificatesItem([string]$message)
{
     AddItem -info $message -Source "Certificates Checker" -EventId $smIdUnexpectedResult -EventType "Warning"  
}

function Invoke-Helper([string]$helper,[string]$store)
{
    Write-Verbose -"running $helper"
  
    if ($store -eq "user")
    {
        $parameters = "-tuv"
    }
    else
    {
        $parameters = "-tv"
    }
    $parameters += " -c -accepteula -nobanner"

    $result = RunCLIProgram -fullPath $helper -parameters $parameters    

    # fix a problem with an extra field
    $result = $result -replace ",,",","
    # remove other stuff we don't want
    $result = $result -replace "Listing valid certificates not rooted to the Microsoft Certificate Trust List:",""
    $result = $result -replace "^(\W)+",""
    $result = $result -replace "^(\r\n)+",""
   
    return $result    
}

function CheckCertificates()
{
    # check for a config node
    if ($global:ConfigXml.servermonitor.SelectNodes("certificates").count -ne 1) 
    {
        ShowInfo "rootcerts node not found"
        return
    }

    # get the path to the sigcheck.exe to use
    $helper = ExpandEnvironmentVariables -data $global:ConfigXml.servermonitor.certificates.GetAttribute("helper")

    # is it there?
    if (!(Test-Path  $helper))
    {
        AddItem -info "$helper not found" -Source "Certificates Checker" -EventId $smIdHelperProgramNotFound -EventType "Error"
        return
    }

    $store = $global:ConfigXml.servermonitor.certificates.GetAttribute("store")

    if ($store -notmatch "machine|user")
    {
        AddItem -info "Attibute store can only be 'user' or 'machine'" -Source "Certificates Checker" -EventId $smIdConfigInvalid -EventType "Error"
        return        
    }

    # we build a pattern with all allowed thumbprints
    [string]$allowedCerts = ""

    if ($global:ConfigXml.servermonitor.certificates.SelectNodes("allow").count -gt 0) 
    {
        $global:ConfigXml.servermonitor.certificates.allow |
        ForEach {
            $allowedCerts += ($_.GetAttribute("thumbprint") + "|")
        }
        # cut the last pipe
        $allowedCerts = $allowedCerts -replace “\|$”
    }
    else
    {
        # if none are specified, we don't allow any, use a regex that never match a thumbprint
        $allowedCerts = "XYZ"  # all thumbprints are hex characters only
    }

    # run the helper program
    $result = Invoke-Helper -helper $helper -store $store

    # convert to CSV and filter it
    $csv_content = $result | ConvertFrom-Csv
    $csv_content | Where-Object { $_.Thumbprint -notmatch "$allowedCerts" } | Foreach-Object {
        Write-Verbose $_
        AddCheckCertificatesItem -message "Certificate `'$($_.Store)\$($_.Subject)`' is not on the trusted Microsoft root certificate list. Thumbprint= $($_.Thumbprint)"  
    }
}
