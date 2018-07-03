<#PSScriptInfo

.VERSION 1.0

.GUID ea6c9f59-1659-4ab5-9d2f-8aa26a7d32b9

.AUTHOR Mike Galvin twitter.com/digressive

.COMPANYNAME

.COPYRIGHT (C) Mike Galvin. All rights reserved.

.TAGS Network Device Status Report Monitor

.LICENSEURI

.PROJECTURI https://gal.vin/2018/06/14/network-device-status

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

#>

<#
    .SYNOPSIS
    Creates a status report of Network Devices.

    .DESCRIPTION
    Creates a status report of Network Devices.

    This script will:
    
    Generate a HTML or CSV status report from a configurable list of network devices.

    Please note: to send a log file using ssl and an SMTP password you must generate an encrypted
    password file. The password file is unique to both the user and machine.
    
    The command is as follows:

    $creds = Get-Credential
    $creds.Password | ConvertFrom-SecureString | Set-Content c:\foo\ps-script-pwd.txt
    
    .PARAMETER List
    The path to a CSV file with a list of IP addresses and device names to monitor separated by a comma.
    Example:
    IP,Name
    127.0.0.1,localhost

    .PARAMETER O
    The path where the HTML or CSV report should be output to. The filename will be NetDev-Status-Report.html/csv.

    .PARAMETER Refresh
    The number of seconds that she script should wait before running again. The minimum is 300 seconds (5 minutes)
    and the maximum is 28800 (8 hours). If not configured the script will run once and then exit.

    .PARAMETER Light
    Use a light theme for the web page generated. This setting had no effect on a CSV file report.

    .PARAMETER Csv
    Output a CSV file instead of a HTML file for the report.

    .PARAMETER SendTo
    The e-mail address the log should be sent to.

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
    NetDev-Status.ps1 -List C:\foo\networkdevices.csv -O C:\foo -Refresh 300 -Light
    The script will execute using the list of network devices and output a html report called NetDev-Status-Report.htm to C:\foo.
    The status of the network devices will refresh every 5 minutes, and the web page will have a light theme instead of a dark
    theme.
#>

## Set up command line switches and what variables they map to
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [Alias("List")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    [string]$DeviceFile,
    [Parameter(Mandatory=$True)]
    [Alias("O")]
    [ValidateScript({Test-Path $_ -PathType 'Container'})]
    [string]$OutputPath,
    [Alias("Refresh")]
    [ValidateRange(300,28800)]
    [int]$RefreshTime,
    [switch]$Light,
    [switch]$Csv,
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

## Begining of the loop. At the bottom of the script the loop is broken if the refresh option is not configured.
Do
{
    ## Setting the location of the CSV file if configured.
    If ($Csv)
    {
        $OutputFile = "$OutputPath\NetDev-Status-Report.csv"
        
        ## If the CSV file already exists, clear it so information is not duplicated.
        $CsvT = Test-Path -Path $OutputFile

        If ($CsvT)
        {
            Clear-Content -Path $OutputFile
        }
    }

    ## If CSV file is not configured, output a HTML report.
    Else
    {
        $OutputFile = "$OutputPath\NetDev-Status-Report.htm"
    }

    ## Settings colours used in HTML report as variables.
    $Green = "00e600"
    $Grey = "e6e6e6"
    $Red = "ff4d4d"
    $Black = "1a1a1a"

    ## Import the CSV file data.
    $DeviceList = Import-Csv -Path $DeviceFile

    ## Creating the Result array.
    $Result = @()

    ## Sort devices in the device list alphabetically based on Name.
    $DeviceList = $DeviceList | Sort-Object -Property Name

    ## This ForEach loop puts offline devices at the top of the list.
    ForEach ($Device in $DeviceList)
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

    $DeviceListFinal = $DevicesOffline + $DevicesOnline

    ## Ping the devices in the final device list generated above.
    ForEach ($Device in $DeviceListFinal)
    {
        $PingStatus = Test-Connection -ComputerName $Device.IP -Count 1 -Quiet
        
        If ($PingStatus -eq $True)
        {
            $ResponseTime = Test-Connection -ComputerName $Device.IP -Count 1 | Select-Object -ExpandProperty ResponseTime
        }

        ## Put the results together in the array.
        $Result += New-Object PSObject -Property @{
            Status = $PingStatus
            DeviceName = $Device.Name
            DeviceIP = $Device.IP
            ResponseTime = $ResponseTime
	    }

        ## Clear the variables after obtaining and storing the results, otherwise duplicate data is entered.
        If ($DeviceListFinal)
        {
            Clear-Variable DeviceList
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
    }

    ## If the result is not empty, put the report file together.
    If ($Result -ne $null)
    {
        ## If CSV report is specified, output a CSV file.
        If ($Csv)
        {
            ForEach($Entry in $Result)
            {
                If ($Entry.Status -eq $True)
                {
                    Add-Content -Path "$OutputFile" -Value "$($Entry.DeviceIP),$($Entry.DeviceName),Online,$($Entry.ResponseTime) ms"
                }

                Else
                {
                    Add-Content -Path "$OutputFile" -Value "$($Entry.DeviceIP),$($Entry.DeviceName),Offline,N/A"
                }
            }
        }

        ## If a CSV report is not specified, output a HTML file.
        Else
        {
            ## If the light theme is specified, use a lighter css theme.
            If ($Light)
            {
                $HTML = '<style type="text/css">
                    p {font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;font-size:14px}
                    p {color:#000000;}
                    #Header{font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;width:100%;border-collapse:collapse;}
                    #Header td, #Header th {font-size:15px;text-align:left;border:1px solid #1a1a1a;padding:2px 2px 2px 7px;color:#ffffff;}
                    #Header tr.alt td {color:#ffffff;background-color:#404040;}
                    #Header tr:nth-child(even) {background-color:#404040;}
                    #Header tr:nth-child(even) {background-color:#404040;}
                    #Header tr:nth-child(odd) {background-color:#737373;}
                    body {background-color: #d9d9d9;}
                    div {background-color: #d9d9d9;-webkit-animation-name: alert;animation-duration: 4s;animation-iteration-count: infinite;animation-direction: alternate;}
                    @-webkit-keyframes alert {from {background-color:rgba(217,0,0,0);} to {background-color:rgba(217,0,0,1);}
                    @keyframes alert {from {background-color:rgba(217,0,0,0);} to {background-color:rgba(217,0,0,1);}
                    </style>
                    <head><meta http-equiv="refresh" content="300"></head>'

                $HTML += "<html><body>
                    <p><font color=#$Black>Status refreshed on: $(Get-Date -Format G)</font></p>
                    <table border=0 cellpadding=0 cellspacing=0 id=header>"
            }

            ## If the light theme is not specified, use a darker css theme.
            Else
            {
                $HTML = '<style type="text/css">
                    p {font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;font-size:14px}
                    p {color:#ffffff;}
                    #Header{font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;width:100%;border-collapse:collapse;}
                    #Header td, #Header th {font-size:15px;text-align:left;border:1px solid #1a1a1a;padding:2px 2px 2px 7px;color:#ffffff;}
                    #Header tr.alt td {color:#ffffff;background-color:#1a1a1a;}
                    #Header tr:nth-child(even) {background-color:#1a1a1a;}
                    #Header tr:nth-child(odd) {background-color:#3b3b3b;}
                    body {background-color: #1a1a1a;}
                    div {background-color: #1a1a1a;-webkit-animation-name: alert;animation-duration: 4s;animation-iteration-count: infinite;animation-direction: alternate;}
                    @-webkit-keyframes alert {from {background-color:rgba(217,0,0,0);} to {background-color:rgba(217,0,0,1);}
                    @keyframes alert {from {background-color:rgba(217,0,0,0);} to {background-color:rgba(217,0,0,1);}
                    </style>
                    <head><meta http-equiv="refresh" content="300"></head>'

                $HTML += "<html><body>
                    <p><font color=#$Grey>Status refreshed on: $(Get-Date -Format G)</font></p>
                    <table border=0 cellpadding=0 cellspacing=0 id=header>"
            }

            ## Highlight the entry if it is offline.
            ForEach($Entry in $Result)
            {
                If ($Entry.Status -eq $True)
                {
                    $HTML += "<td><font color=#$Green>&#10004</font></td>"
                }

                Else
                {
                    $HTML += "<td><font color=#$Red>&#10008</font></td>"
                }
                
                If ($Entry.Status -eq $True)
                {
                    $HTML += "<td><font color=#$Green>$($Entry.DeviceIP)</font></td>"
                }

                Else
                {
                    $HTML += "<td><div><font color=#$Red>$($Entry.DeviceIP)</font></div></td>"
                }

                If ($Entry.Status -eq $True)
                {
                    $HTML += "<td><font color=#$Green>$($Entry.DeviceName)</font></td>"
                }

                Else
                {
                    $HTML += "<td><div><font color=#$Red>$($Entry.DeviceName)</font></div></td>"
                }

                If ($Entry.ResponseTime -ne $Null)
                {
                    $HTML += "<td><font color=#$Green>$($Entry.ResponseTime) ms</font></td>
                    </tr>"
                }

                Else
                {
                    $HTML += "<td><div><font color=#$Red>Offline</font></div></td>
                    </tr>"
                }
            }

            ## Finish the HTML file.
            $HTML += "</table></body></html>"

            ## Output the HTML file.
            $HTML | Out-File $OutputFile
        }

        ## If email was configured, set the variables for the email subject and body.
        If ($SmtpServer)
        {
            $MailSubject = "Network Device Status Report"
            $MailBody = Get-Content -Path $OutputFile | Out-String

            ## If an email password was configured, create a variable with the username and password.
            If ($SmtpPwd)
            {
                $SmtpPwdEncrypt = Get-Content $SmtpPwd | ConvertTo-SecureString
                $SmtpCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($SmtpUser, $SmtpPwdEncrypt)

                ## If ssl was configured, send the email with ssl.
                If ($UseSsl)
                {
                    Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -BodyAsHtml -SmtpServer $SmtpServer -UseSsl -Credential $SmtpCreds
                }

                ## If ssl wasn't configured, send the email without ssl.
                Else
                {
                    Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -BodyAsHtml -SmtpServer $SmtpServer -Credential $SmtpCreds
                }
            }

            ## If an email username and password were not configured, send the email without authentication.
            Else
            {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -BodyAsHtml -SmtpServer $SmtpServer
            }
        }

        ## If the refresh time option is configured, wait the specifed number of seconds then loop.
        If ($RefreshTime -ne 0)
        {
            Start-Sleep -Seconds $RefreshTime
        }
    }
}

## If the refresh time option is not configured, stop the loop.
Until ($RefreshTime -eq 0)

## End