# Network Device Status Monitor
PowerShell based network attached device monitor

Network Device Status Monitor can also be downloaded from:

* [The Microsoft TechNet Gallery](https://gallery.technet.microsoft.com/Network-Device-Status-d4bd859a)
* [The PowerShell Gallery](https://www.powershellgallery.com/packages/NetDev-Status)
* For full instructions and documentation, [visit my blog post](https://gal.vin/2018/06/14/network-device-status)

-Mike

Tweet me if you have questions: [@Digressive](https://twitter.com/digressive)

## Features and Requirements

* The utility will display the network device name and IP address as specified in the CSV file.
* The utility will display Online/Offline status of the specified devices.
* The utility will display the response time of the network device.
* The utility can display the results as either a CSV file or a HTML file.
* The utility can be configured to monitor continuously, or run once.
* The utility can be configured to e-mail the results.
* The script has been tested running on Windows 10 and Windows Server 2016, monitoring network devices with IP v4 addresses.

### CSV File Structure

The structure of the CSV file is as follows:

```
IP,Name
10.30.1.1,Router
10.30.1.5,NAS
10.30.1.10,Switch 1
```

The utility has been tested running on Windows 10 and Windows Server 2016, monitoring PCs and Servers running Windows 10, Windows Server 2016, Windows Server 2012 R2, and Windows Server 2008 R2. The utility must be run as a user with administrator-level privileges to the systems it is monitoring.

### Generating A Password File

The password used for SMTP server authentication must be in an encrypted text file. To generate the password file, run the following command in PowerShell, on the computer that is going to run the script and logged in with the user that will be running the script. When you run the command you will be prompted for a username and password. Enter the username and password you want to use to authenticate to your SMTP server.

Please note: This is only required if you need to authenticate to the SMTP server when send the log via e-mail.

```
$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt
```

After running the commands, you will have a text file containing the encrypted password. When configuring the -Pwd switch enter the path and file name of this file.

### Configuration

Here’s a list of all the command line switches and example configurations.
```
-List
```
The path to a CSV file with a list of IP addresses and device names to monitor separated by a comma.
```
-O
```
The path where the HTML or CSV report should be output to. The filename will be NetDev-Status-Report.html/csv.
```
-Refresh
```
The number of seconds that she script should wait before running again. The minimum is 300 seconds (5 minutes)
and the maximum is 28800 (8 hours). If not configured the script will run once and then exit.
```
-Light
```
Use a light theme for the web page generated. This setting had no effect on a CSV file report.
```
-Csv
```
Output a CSV file instead of a HTML file for the report.
```
-SendTo
```
The e-mail address the log should be sent to.
```
-From
```
The from address the log should be sent from.
```
-Smtp
```
The DNS or IP address of the SMTP server.
```
-User
```
The user account to connect to the SMTP server.
```
-Pwd
```
The txt file containing the encrypted password for the user account.
```
-UseSsl
```
Connect to the SMTP server using SSL.

```
NetDev-Status.ps1 -List C:\foo\networkdevices.csv -O C:\foo -Refresh 300 -Light
```
The script will execute using the list of network devices and output a html report called NetDev-Status-Report.htm to C:\foo. The status of the network devices will refresh every 5 minutes, and the web page will have a light theme instead of a dark theme.
