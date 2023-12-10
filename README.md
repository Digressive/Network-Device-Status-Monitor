# Network Device Status Monitor (NDSM)

## PowerShell based network attached device monitor

For full instructions and documentation, [visit my blog post](https://gal.vin/posts/network-device-status)

Please consider donating to support my work:

* You can support me with a one-time payment [using PayPal](https://www.paypal.me/digressive)

Network Device Status Monitor can also be downloaded from:

* [The PowerShell Gallery](https://www.powershellgallery.com/packages/NetDev-Status)

Please report any problems via the ‘issues’ tab on GitHub.

-Mike

## Features and Requirements

* The utility can output the network device name and IP address as specified in the CSV file.
* Online/Offline status of the specified devices will be displayed.
* The utility will display the response time of online network devices.
* The utility can be configured to output the report as either a CSV file or a HTML file.
* The utility can be configured to run in ‘monitor’ mode or as a one shot report.
* The utility can be configured to email the report, or send offline alerts to Microsoft Teams
* The script has been tested running on Windows 10, Windows Server 2016 and 2019 monitoring network devices with IPv4 addresses.

## CSV File Structure

The first line of the CSV file should be the column names so the script (and you) know what each column is for.

Please see the networkdevices-example.csv file for how to structure your own file.

The utility has been tested running on Windows 10 and Windows Server 2016, monitoring PCs and Servers running Windows 10, Windows Server 2016, Windows Server 2012 R2, and Windows Server 2008 R2. The utility must be run as a user with administrator-level privileges to the systems it is monitoring.

## Generating A Password File For SMTP Authentication

The password used for SMTP server authentication must be in an encrypted text file. To generate the password file, run the following command in PowerShell, on the computer that is going to run the script and logged in with the user that will be running the script. When you run the command you will be prompted for a username and password. Enter the username and password you want to use to authenticate to your SMTP server.

Please note: This is only required if you need to authenticate to the SMTP server when send the log via e-mail.

``` powershell
$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt
```

After running the commands, you will have a text file containing the encrypted password. When configuring the -Pwd switch enter the path and file name of this file.

## Configuration

Here’s a list of all the command line switches and example configurations.

| Command Line Switch | Description | Example |
| ------------------- | ----------- | ------- |
| -List | The full path to a CSV file with a list of IP addresses and device names to monitor, separated by a comma. | [path\]networkdevices.csv |
| -Teams | The full path to a txt file containing the webhook URL for Teams. If this setting is configured other output settings will be ignored. | [path\]webhook.txt |
| -FR |  Use this switch to send a full report to Teams. This setting only has an effect when used with the -Teams switch. | N/A |
| -O | The path where the HTML or CSV report should be output to. The filename will be NetDev-Status-Report.html/csv. | [path\] |
| -Refresh | Enable monitoring mode. The number of seconds that she script should wait before running again. The minimum is 300 seconds (5 minutes) and the maximum is 28800 (8 hours). If not configured the script will run once and then exit. | [number] |
| -Light | Use a light theme for the web page generated. This setting had no effect on a CSV file report. | N/A |
| -csv | Output a CSV file instead of a HTML file for the report. | [path\]|
| -Subject | Specify a subject line. If you leave this blank the default subject will be used | "'[Server: Notification]'" |
| -SendTo | The e-mail address the log should be sent to. For multiple address, separate with a comma. | [example@contoso.com] |
| -From | The e-mail address the log should be sent from. | [example@contoso.com] |
| -Smtp | The DNS name or IP address of the SMTP server. | [smtp server address] |
| -User | The user account to authenticate to the SMTP server. | [example@contoso.com] |
| -Pwd | The txt file containing the encrypted password for SMTP authentication. | [path\]ps-script-pwd.txt |
| -UseSsl | Configures the utility to connect to the SMTP server using SSL. | N/A |

## Example Configuration

``` txt
NetDev-Status.ps1 -List C:\foo\networkdevices.csv -O C:\foo -Refresh 300 -Light
```

Using this example config, the script will execute using the list of network devices and output a html report called NetDev-Status-Report.htm to C:\foo. The status of the network devices will refresh every 5 minutes, and the web page will have a light theme instead of a dark theme.

## Change Log

### 2019-10-02 v2.0

* Added Microsoft Teams as an output location, for either offline alerts, or a 'full' report.
* MS teams is limited to 10 devices. Not sure if it's a Teams/webhook limit, or my code. Will investigate.
* Fixed bug where all devices are offline, a phantom device is added to the bottom of the offline list.
* Cleaned up code, removing/not setting variables if they are not needed in the current mode.
* Added console output for when the script is in 'monitor' mode.

### 2019-09-04 v1.2

* Added custom subject line for email.

### 2019-02-23 v1.1

* Updated the style of the web page with a cleaner look.
* Added 'online' CSS animation when the web page is in monitor mode - this is configured by using the refresh switch. It will not display when in report mode (no refresh switch).

### 2018-06-13 v1.0

* First public release.
* Based off Windows Server Status Monitor version 1.5 code.
