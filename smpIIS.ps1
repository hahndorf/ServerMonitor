function CheckIIS()
{
    if ($global:ConfigXml.servermonitor.SelectNodes("iis").count -ne 1)
    {
        ShowInfo "iis node not found"
        return
    }

#  <iis>
#    <check type="apppool" uri="DefaultAppPool"></check>  
#    <check type="site" uri="Default Web Site"></check>    
#    <check type="http" uri="http://localhost"  pattern="microsoft.com"></check>
#    <check type="sitecount" count="1"  comparer="eq"></check>
#  </iis>

    if (!(CheckForElevatedAdmin "IIS")) {return}

    Import-Module WebAdministration -Verbose:$false

    $global:ConfigXml.servermonitor.iis.check |
    ForEach {

       $theUrl = ExpandEnvironmentVariables $_.GetAttribute("uri")
       $pattern = ExpandEnvironmentVariables $_.GetAttribute("pattern")

       if ($_.GetAttribute("type") -eq "apppool")
       {
            CheckAppPool $theUrl
       }
   
       if ($_.GetAttribute("type") -eq "site")
       {
            CheckSite $theUrl
       }

       if ($_.GetAttribute("type") -eq "sitecount")
       {
           Count-Sites -expectedNumber $_.GetAttribute("count") -comparer $_.GetAttribute("comparer")
       }

       if ($_.GetAttribute("type") -eq "http")
       {
            CheckHttp -url $theUrl -pattern $pattern
       }

       if ($_.GetAttribute("type") -eq "https")
       {
    
       }
    }
}

function AddIIsItem([string]$message,[int32]$id,[string]$type = "Error")
{
     AddItem -info $message -Source "IIS Checker" -EventId $id -EventType $type   
}

function CheckAppPool([string]$name)
{
    ShowInfo "Testing AppPool `'$name`'"

    if (((Get-ChildItem IIS:\apppools | Where {$_.Name -eq "$name"}).State) -ne "Started")
    {
        $message = "IIS App Pool: $name is not running"
        AddIIsItem  $message $smIdItemNotRunning
    } 
}

function CheckSite([string]$name)
{
    ShowInfo "Testing site `'$name`'"

    if (((Get-ChildItem IIS:\sites | Where {$_.Name -eq "$name"}).State) -ne "Started")
    {
        $message = "IIS site: $name is not running"
        AddIIsItem  $message $smIdItemNotRunning
    } 
}

function CheckHttp([string]$url,[string]$pattern)
{
   ShowInfo "Testing $url"
   
    # this works around SSL problems
 #   [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
   
    $webClient = new-object System.Net.WebClient
    $webClient.Headers.Add("user-agent", "Mozilla/4.0 (compatible;ServerMonitor-" `
    + $script:MyVersion + "; Windows NT " + $script:MyOS.Version + "; http://peter.hahndorf.eu/tech/servermonitor.html)")

    $output = ""    
    $pattern = "*" + $pattern + "*"

    try
    {
       $output = $webClient.DownloadString($url)

       if ($output -notlike $pattern) 
       {
            $message = "Pattern `'$pattern`' not found at $Url"
            AddIIsItem  $message $smIdUnexpectedResult "warning"
       }   
    }
    catch [System.Net.WebException] 
    {              
        $message = "Checking `'$Url`' failed: $($_.Exception.Message)"
        AddIIsItem -message $message -id $smIdError       
    } 
    catch
    {
        $message = "Error loading $Url, $($_.Exception.Message)"
        AddIIsItem -message $message -id $smIdError 
    }
}

function Count-Sites([int]$expectedNumber,[string]$comparer)
{  
    ShowInfo "Counting sites"

    $actualCount = (Get-ChildItem IIS:\Sites).count

    [string]$compareText = Compare-Values -actual $actualCount -expected $expectedNumber -comparer $comparer   
    
    if ($compareText -ne "")
    {
        [string]$body = ("IIS Site count: found {1} site where {2} {3} were expected." -f $name, $actualCount,$compareText,$expectedNumber)
        AddIIsItem -message $body -id $smIdUnexpectedResult 
    }
}