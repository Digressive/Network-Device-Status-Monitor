<#PSScriptInfo

.VERSION 2.0

.GUID ea6c9f59-1659-4ab5-9d2f-8aa26a7d32b9

.AUTHOR Mike Galvin Contact: digressive@outlook.com

.COMPANYNAME Mike Galvin

.COPYRIGHT (C) Mike Galvin. All rights reserved.

.TAGS Network Device Status Report Monitor Teams CSV HTML Email

.LICENSEURI https://github.com/Digressive/Network-Device-Status-Monitor?tab=MIT-1-ov-file

.PROJECTURI https://gal.vin/posts/network-device-status

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

#>

<#
    .SYNOPSIS
    Creates a status report of network devices.

    .DESCRIPTION
    This script will generate a status report of a configurable list of network devices.

    The report can be in HTML or CSV file formats, emailed or sent to Microsoft Teams via webhook.

    It can be run in 'monitor' mode and continuiously generate a report, or as a single one shot.

    Please note to send the report using ssl and an SMTP password you must generate an encrypted
    password file. The password file is unique to both the user and machine.
    
    The command is as follows:

    $creds = Get-Credential
    $creds.Password | ConvertFrom-SecureString | Set-Content C:\scripts\ps-script-pwd.txt
    
    .PARAMETER List
    The path to a CSV file with a list of IP addresses and device names to monitor separated by a comma.
    Please see the networkdevices-example.csv file for how to structure your own file.

    .PARAMETER Teams
    The path to a txt file containing the webhook URL to use for Teams output. If this switch is used, -O and -CSV are ignored.

    .PARAMETER FR
    Use the FR switch to provide a full report to teams, without this switch only offline devices will be reported to Teams.
    This switch has no effect without using the teams switch.

    .PARAMETER O
    The path where the HTML or CSV report should be output to. The filename will be NetDev-Status-Report.html/csv.

    .PARAMETER Refresh
    Run the script in 'monitor' mode.
    The number of seconds that she script should wait before running again. The minimum is 300 seconds (5 minutes)
    and the maximum is 28800 (8 hours). If not configured the script will run once and then end.

    .PARAMETER Light
    Use a light theme for the HTML report generated. This setting will have no effect on a CSV file report.

    .PARAMETER Csv
    Output a CSV file instead of a HTML file for the report.

    .PARAMETER Subject
    The subject line that the email should have. Encapulate with single or double quotes.
    
    .PARAMETER SendTo
    The email address the log should be sent to.

    .PARAMETER From
    The from address the log should be sent from.

    .PARAMETER Smtp
    The DNS or IP address of the SMTP server.

    .PARAMETER User
    The user account to connect to the SMTP server.

    .PARAMETER Pwd
    The txt file containing the encrypted password for the user account.

    .PARAMETER UseSsl
    Connect to the SMTP server using SSL.

    .EXAMPLE
    NetDev-Status.ps1 -List C:\foo\networkdevices.csv -O C:\foo -Refresh 300
    Using the above command the script will execute using the list of network devices and output a html report called NetDev-Status-Report.htm to C:\foo.
    The status of the network devices will refresh every 5 minutes and the web page will have the default dark theme.
#>

# Set up command line switches/parameters and what variables they map to.
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [Alias("List")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    [string]$DeviceFile,
    [Alias("O")]
    [string]$OutputPath,
    [Alias("Refresh")]
    [ValidateRange(300,28800)]
    [int]$RefreshTime,
    [Alias("Teams")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    [string]$TeamsO,
    [switch]$FR,
    [switch]$Light,
    [switch]$csv,
    [alias("Subject")]
    [string]$MailSubject,
    [Alias("SendTo")]
    [string]$MailTo,
    [Alias("From")]
    [string]$MailFrom,
    [Alias("Smtp")]
    [string]$SmtpServer,
    [Alias("User")]
    [string]$SmtpUser,
    [Alias("Pwd")]
    [string]$SmtpPwd,
    [switch]$UseSsl)

# Report in the console that monitor mode is enabled.
If ($RefreshTime -ne 0)
{
    Write-Host "Monitor mode: Enabled"
}

Else
{
    Write-Host "Monitor mode: Disabled"
}

# Begining of the loop. At the bottom of the script the loop is broken if the refresh option is not configured.
Do
{
    ## Clear variables if they are set, otherwise data becomes corrupted.
    If ($Device)
    {
        Clear-Variable Device
    }

    If ($DeviceList)
    {
        Clear-Variable DeviceList
    }
    
    If ($DeviceListSorted)
    {
        Clear-Variable DeviceList
    }

    If ($DeviceListFinal)
    {
        Clear-Variable DeviceListFinal
    }

    If ($DevicesOffline)
    {
        Clear-Variable DevicesOffline
    }

    If ($DevicesOnline)
    {
        Clear-Variable DevicesOnline
    }

    If ($PingStatus)
    {
        Clear-Variable PingStatus
    }

    If ($ResponseTime)
    {
        Clear-Variable ResponseTime
    }

    # If the teams switch is used, get the webhook uri from the txt file.
    If ($TeamsO)
    {
        If ($OutputPath)
        {
            Clear-Variable -Name "OutputPath"
        }

        $uri = Get-Content $TeamsO
    }

    Else
    {
        If ($OutputPath)
        {
            # Setting the location of the CSV file if configured.
            If ($csv)
            {
                $OutputFile = "$OutputPath\NetDev-Status-Report.csv"
            }

            # If CSV file is not configured, output a HTML report.
            Else
            {
                $OutputFile = "$OutputPath\NetDev-Status-Report.htm"
            }
        }
    }

    If ($OutputPath -ne $null -And $csv -eq $False)
    {
        # Using variables for HTML and CSS so we don't need to use escape characters below.
        $Green = "00e600"
        $Grey = "e6e6e6"
        $Red = "ff4d4d"
        $Black = "1a1a1a"
        $CssError = "error"
        $CssFormat = "format"
        $CssSpinner = "spinner"
        $CssRect1 = "rect1"
        $CssRect2 = "rect2"
        $CssRect3 = "rect3"
        $CssRect4 = "rect4"
        $CssRect5 = "rect5"
    }

    # Import the CSV file data.
    $DeviceList = Import-Csv -Path $DeviceFile

    # Creating Result array.
    $ResultArr = @()

    # If teams is configured and Full Report is not, then do the following...
    If ($TeamsO -And $FR -eq $False)
    {
        # Sort devices in the device list alphabetically based on Name.
        $DeviceListSorted = $DeviceList | Sort-Object -Property Name

        # For each device ping it and if it doesn't respond, enter it's information into the array.
        ForEach ($Device in $DeviceListSorted)
        {
            $PingStatus = Test-Connection -ComputerName $Device.IP -Count 1 -Quiet

            If ($PingStatus -eq $False)
            {
                $DevicesOffline += @($Device)

                # Put the results in the array, formatted as json for Teams.
                $ResultArr += New-Object PSObject -Property @{
                    facts = @(
                        @{
                            name = 'Device:'
                            value = $Device.Name + " " + "|" + " " + $Device.IP
                        },
                        @{
                            name = 'Status:'
                            value = 'Offline'
                        }
                    )
                }
            }
        }
    }

    # If Teams isn't configured, then run the following...
    Else
    {
        # Sort devices in the device list alphabetically based on Name.
        $DeviceListSorted = $DeviceList | Sort-Object -Property Name

        # This loop sorts the devices by their offline/online status.
        ForEach ($Device in $DeviceListSorted)
        {
            $PingStatus = Test-Connection -ComputerName $Device.IP -Count 1 -Quiet

            If ($PingStatus -eq $False)
            {
                $DevicesOffline += @($Device)
            }

            Else
            {
                $DevicesOnline += @($Device)
            }
        }

        # If there are online devices then put the final list together.
        If ($DevicesOnline.Count -ne 0)
        {
            $DeviceListFinal = $DevicesOffline + $DevicesOnline
        }

        # If there are no online devices create the final list. This prevents the 'phantom device' bug when all devices are offline.
        Else
        {
            $DeviceListFinal = $DevicesOffline
        }

        # Ping the devices in the final device list generated above.
        ForEach ($Device in $DeviceListFinal)
        {
            $PingStatus = Test-Connection -ComputerName $Device.IP -Count 1 -Quiet

            # If the device responds, get the response time.
            If ($PingStatus -eq $True)
            {
                $ResponseTime = Test-Connection -ComputerName $Device.IP -Count 1 | Select-Object -ExpandProperty ResponseTime
            }

            # If Teams and Full Report are configured, put the results together in the array formatted for Teams.
            If ($TeamsO -And $FR -eq $True)
            {
                If ($PingStatus -eq $True)
                {
                    $PStatus = "Online"
                }

                Else
                {
                    $PStatus = "Offline"
                }

                # Put the results together in the array.
                $ResultArr += New-Object PSObject -Property @{
                    facts = @(
                        @{
                            name = 'Device:'
                            value = $Device.Name + " " + "|" + " " + $Device.IP
                        },
                        @{
                            name = 'Status:'
                            value = $PStatus
                        }
                    )
                }
            }

            # If Teams and Full Report are not configured, prepare the array for file output.
            If ($Null -ne $TeamsO -And $FR -eq $False)
            {
            # Put the results together in the array.
            $ResultArr += New-Object PSObject -Property @{
                Status = $PingStatus
                DeviceName = $Device.Name
                DeviceIP = $Device.IP
                ResponseTime = $ResponseTime}
            }
        }
    }

    # If the result is not empty, put the report file together.
    If ($Null -ne $ResultArr)
    {
        # If Teams and Full Report are configured then format and send the results to Teams.
        If ($TeamsO -And $FR -eq $True)
        {
            $Body = ConvertTo-Json -Depth 8 @{
                text  = "Full report:"
                sections = $ResultArr
                title = "Network Device Status Monitor"
            }

            Invoke-RestMethod -Uri $Uri -Method Post -body $Body -ContentType 'application/json'
        }

        Else
        {
            # If Teams is configured and Full Report is not, and there are offline devices, then send the results to Teams.
            If ($TeamsO -And $FR -eq $False -And $DevicesOffline.Count -ne 0)
            {
                $Body = ConvertTo-Json -Depth 8 @{
                    text  = "The following device(s) not responding:"
                    sections = $ResultArr
                    title = "Network Device Status Monitor"
                }

                Invoke-RestMethod -Uri $Uri -Method Post -body $Body -ContentType 'application/json'
            }

            #If the Output path is configured then do the follwing...
            If ($OutputPath)
            {
                # If CSV report is specified, output a CSV file.
                If ($csv)
                {
                    # Test if the CSV file already exists, if it does, clear it so information is not duplicated.
                    $csvT = Test-Path -Path $OutputFile

                    If ($csvT)
                    {
                        Clear-Content -Path $OutputFile
                    }

                    # For each entry in the array output the results.
                    ForEach($Entry in $ResultArr)
                    {
                        If ($Entry.Status -eq $True)
                        {
                            Add-Content -Path "$OutputFile" -Value "$($Entry.DeviceIP),$($Entry.DeviceName),Online,$($Entry.ResponseTime)ms"
                        }

                        Else
                        {
                            Add-Content -Path "$OutputFile" -Value "$($Entry.DeviceIP),$($Entry.DeviceName),Offline,Offline"
                        }
                    }
                }

                # If a CSV report is not specified, output a HTML file.
                Else
                {
                    # If the light theme is specified, create the lighter css theme.
                    If ($Light)
                    {
                        $HTML = '<style type="text/css">
                            p {font-family:Gotham, "Helvetica Neue", Helvetica, Arial, sans-serif;font-size:14px}
                            p {color:#000000;}
                            #Header{font-family:Gotham, "Helvetica Neue", Helvetica, Arial, sans-serif;width:100%;border-collapse:collapse;}
                            #Header td, #Header th {font-size:14px;text-align:left;}
                            #Header tr.alt td {color:#ffffff;background-color:#404040;}
                            #Header tr:nth-child(even) {background-color:#404040;}
                            #Header tr:nth-child(odd) {background-color:#737373;}
                            body {background-color: #d9d9d9;}
                            .spinner {width: 40px;height: 20px;font-size: 14px;padding: 5px;}
                            .spinner > div {background-color: #00e600;height: 100%;width: 3px;display: inline-block;animation: sk-stretchdelay 3.2s infinite ease-in-out;}
                            .spinner .rect2 {animation-delay: -3.1s;}
                            .spinner .rect3 {animation-delay: -3.0s;}
                            .spinner .rect4 {animation-delay: -2.9s;}
                            .spinner .rect5 {animation-delay: -2.8s;}
                            @keyframes sk-stretchdelay {0%, 40%, 100% {transform: scaleY(0.4);} 20% {transform: scaleY(1.0);}}
                            .format {position: relative;overflow: hidden;padding: 5px;}
                            .error {-webkit-animation-name: alert;animation-duration: 4s;animation-iteration-count: infinite;animation-direction: alternate;padding: 5px;}
                            @keyframes alert {from {background-color:rgba(117,0,0,0);} to {background-color:rgba(117,0,0,1);}}
                            </style>
                            <head><meta http-equiv="refresh" content="310"></head>'

                        $HTML += "<html><body>
                            <p><font color=#$Black>Last update: $(Get-Date -Format G)</font></p>
                            <table border=0 cellpadding=0 cellspacing=0 id=header>"
                    }

                    # If the light theme is not specified, create the darker css theme.
                    Else
                    {
                        $HTML = '<style type="text/css">
                            p {font-family:Gotham, "Helvetica Neue", Helvetica, Arial, sans-serif;font-size:14px}
                            p {color:#ffffff;}
                            #Header{font-family:Gotham, "Helvetica Neue", Helvetica, Arial, sans-serif;width:100%;border-collapse:collapse;}
                            #Header td, #Header th {font-size:14px;text-align:left;}
                            #Header tr:nth-child(even) {background-color:#1B1B1B;}
                            #Header tr:nth-child(odd) {background-color:#0F0F0F;}
                            body {background-color: #0F0F0F;}
                            .spinner {width: 40px;height: 20px;font-size: 14px;padding: 5px;}
                            .spinner > div {background-color: #00e600;height: 100%;width: 3px;display: inline-block;animation: sk-stretchdelay 3.2s infinite ease-in-out;}
                            .spinner .rect2 {animation-delay: -3.1s;}
                            .spinner .rect3 {animation-delay: -3.0s;}
                            .spinner .rect4 {animation-delay: -2.9s;}
                            .spinner .rect5 {animation-delay: -2.8s;}
                            @keyframes sk-stretchdelay {0%, 40%, 100% {transform: scaleY(0.4);} 20% {transform: scaleY(1.0);}}
                            .format {position: relative;overflow: hidden;padding: 5px;}
                            .error {animation-name: alert;animation-duration: 4s;animation-iteration-count: infinite;animation-direction: alternate;padding: 5px;}
                            @keyframes alert {from {background-color:rgba(117,0,0,0);} to {background-color:rgba(117,0,0,1);}}
                            </style>
                            <head><meta http-equiv="refresh" content="310"></head>'

                        $HTML += "<html><body>
                            <p><font color=#$Grey>Last update: $(Get-Date -Format G)</font></p>
                            <table border=0 cellpadding=0 cellspacing=0 id=header>"
                    }

                    # Go through each entry and if it is offline, highlight it.
                    ForEach($Entry in $ResultArr)
                    {
                        # If monitor mode is not configured, don't output the activity animation.
                        If ($RefreshTime -ne 0)
                        {
                            If ($Entry.Status -eq $True)
                            {
                                $HTML += "<td><div class=$CssSpinner><div class=$CssRect1></div> <div class=$CssRect2></div> <div class=$CssRect3></div> <div class=$CssRect4></div> <div class=$CssRect5></div></div></td>"
                            }

                            Else
                            {
                                $HTML += "<td><div class=$CssError><font color=#$Red>OFFL</font></div></td>"
                            }
                        }
                            
                        If ($Entry.Status -eq $True)
                        {
                            $HTML += "<td><div class=$CssFormat><font color=#$Green>$($Entry.DeviceIP)</font></div></td>"
                        }

                        Else
                        {
                            $HTML += "<td><div class=$CssError><font color=#$Red>$($Entry.DeviceIP)</font></div></td>"
                        }

                        If ($Entry.Status -eq $True)
                        {
                            $HTML += "<td><div class=$CssFormat><font color=#$Green>$($Entry.DeviceName)</font></div></td>"
                        }

                        Else
                        {
                            $HTML += "<td><div class=$CssError><font color=#$Red>$($Entry.DeviceName)</font></div></td>"
                        }

                        If ($Null -ne $Entry.ResponseTime)
                        {
                            $HTML += "<td><div class=$CssFormat><font color=#$Green>$($Entry.ResponseTime)ms</font></div></td>
                            </tr>"
                        }

                        Else
                        {
                            $HTML += "<td><div class=$CssError><font color=#$Red>OFFL</font></div></td>
                            </tr>"
                        }
                    }

                    # Close the tags in the HTML file.
                    $HTML += "</table></body></html>"

                    # If the HTML file already exists, clear it just in case information gets duplicated.
                    $htmlT = Test-Path -Path $OutputFile

                    If ($htmlT)
                    {
                        Clear-Content -Path $OutputFile
                    }

                    # Output the HTML file to the location configured.
                    $HTML | Out-File $OutputFile
                }
            }
        }

        # If email was configured, set the variables for the email subject and body.
        If ($SmtpServer)
        {
            # If no subject is set, use the string below
            If ($Null -eq $MailSubject)
            {
                $MailSubject = "Network Device Status Monitor"
            }
                
            # Set the mail body to be the contents of the output file.
            $MailBody = Get-Content -Path $OutputFile | Out-String

            # If an email password was configured, create a variable with the username and password.
            If ($SmtpPwd)
            {
                $SmtpPwdEncrypt = Get-Content $SmtpPwd | ConvertTo-SecureString
                $SmtpCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($SmtpUser, $SmtpPwdEncrypt)

                # If ssl was configured, send the email with ssl.
                If ($UseSsl)
                {
                    Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -BodyAsHtml -SmtpServer $SmtpServer -UseSsl -Credential $SmtpCreds
                }

                # If ssl wasn't configured, send the email without ssl.
                Else
                {
                    Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -BodyAsHtml -SmtpServer $SmtpServer -Credential $SmtpCreds
                }
            }

            # If an email username and password were not configured, send the email without authentication.
            Else
            {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -BodyAsHtml -SmtpServer $SmtpServer
            }
        }

        # If the refresh time option is configured, wait the specifed number of seconds then loop.
        If ($RefreshTime -ne 0)
        {
            Start-Sleep -Seconds $RefreshTime
        }
    }
}

# If the refresh time option is not configured, stop the loop.
Until ($RefreshTime -eq 0)

# End