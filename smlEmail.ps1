function LogToEmail()
{
    $myNode = GetLoggersNode "email"
    if ($myNode -eq $null) {return} 

    $emailRecipient = ExpandEnvironmentVariables $myNode.GetAttribute("recipient")
    $emailRecipientCC = ExpandEnvironmentVariables $myNode.GetAttribute("recipientcc")
    $emailHost = ExpandEnvironmentVariables $myNode.GetAttribute("host")
    $emailSender = ExpandEnvironmentVariables $myNode.GetAttribute("sender")
    $emailSubject = ExpandEnvironmentVariables $myNode.GetAttribute("subject")
    $emailUser = ExpandEnvironmentVariables $myNode.GetAttribute("user")
    $emailPassword = $myNode.GetAttribute("password")
    $emailHtml = $myNode.GetAttribute("html")

    if ($emailRecipient -eq "") {return}

    if ($emailHtml -eq "true")
    {
        $body = BuildHtmlBody
    }
    else
    {
        $body = BuildBody
    }

    if ($body -eq "") {return}

    if ($emailHost -eq "") {Write-Warning "No smtp server specified, use EmailHost parameter"}

    $subject = $emailSubject

    if ($subject -eq "")
    {
        $subject = "Powershell Server Monitor on " + $env:COMPUTERNAME
    }

    if ($emailSender -eq "")
    {
        $emailSender = "servermonitor@" + $env:COMPUTERNAME + ".hahndorf.eu"
    }
 
    $emailMessage = New-Object System.Net.Mail.MailMessage( $emailSender , $emailRecipient )
    $emailMessage.Subject = $subject 
    $emailMessage.IsBodyHtml = $emailHtml
    $emailMessage.Body = $body
 
    if ($emailRecipientCC -ne "")
    {
        $ccRecipient = New-Object System.Net.Mail.MailAddress($emailRecipientCC)
        $emailMessage.CC.Add($ccRecipient );
    }

    $SMTPClient = New-Object System.Net.Mail.SmtpClient($emailHost)

    if ($emailUser -ne "")
    {
        $pwdToUse = $emailPassword

        if ($emailPassword.length -gt 100)
        {
          $pwdToUse = DPApiDecrypt $emailPassword
        }

        $SMTPClient.Credentials = New-Object System.Net.NetworkCredential( $emailUser , $pwdToUse );
    }
 
    $SMTPClient.Send( $emailMessage )
    $script:internalLoggedTo += "email,"
}

function BuildBody()
{
    $content = ""
    [int]$countAll = 0

     foreach($item in $smItems)
     {
        $content += $item.MachineName + " - " + $item.TheTime.ToString("dd-MMM-yy HH:mm:ss") + " - " + $item.LogName + " - " + $item.EventType + "`r`n"
        $content += "Id: " + [string]$item.EventId + " - Source: " + $item.Source + "`r`n"
        $content += $item.Info + "`r`n"
        $content += "------------------------------------------------------------------------------`r`n"
        $countAll++
     }

     if ($countAll -gt 0)
     {
         return "$countAll issues found:`r`n`r`n" + $content        
     }
     else
     {
        return ""
     }    
}


function BuildHtmlBody()
{
    $content = ""
    [int]$countAll = 0 
    [int]$countErrors = 0 
    [int]$countWarnings = 0  

     foreach($item in $smItems)
     {

        if ($item.EventType -eq "error")
        {
            $content += "<div style='background-color: #FF8991;padding-top:5px;padding:3px;border-top:solid 1px black;'>"
            $countErrors++
        }
        else
        {
            $content += "<div style='background-color: #FFF0A0;padding-top:5px;padding:3px;border-top:solid 1px black;'>"
            $countWarnings++
        }

        $content += $item.MachineName + " - " + $item.TheTime.ToString("dd-MMM-yy HH:mm:ss") + " - " + $item.LogName + "`r`n"
        $content += "<br />Id: " + [string]$item.EventId + " - Source: " + $item.Source + "`r`n"
        $content += "<pre>" + $item.Info + "</pre>`r`n"
        $content += "</div>`r`n"
        $countAll++
     }

     if ($countAll -gt 0)
     {
         $header = "<html><body><div>`r`n"
         $header += "<div style='font-weight:bold;margin-bottom:1.2em;'>"
         $header += "$countErrors errors and $countWarnings warnings found:</div>`r`n"
         
         $footer = "`r`n</div></body></html>"      
         
         return ($header + $content + $footer) 
     }
     else
     {
        return ""
     }    
}