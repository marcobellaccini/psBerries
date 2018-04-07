#Requires -Version 5.0
#Requires -Modules UpdateServices
#Requires -Modules SqlServer

<#
    wsusRoboMaintenance.ps1
    A PowerShell script to automate Windows Server Update Services (WSUS) maintenance.
    It handles database backup/re-indexing and WSUS cleanup.
    It assumes that Windows Internal Database (WID) is used for SUSDB.
    Support for logging, old backups purge and e-mail notifications is included.
    It is meant to be run through a scheduled task.
    The service user running the task should be member of the local Administrators group.
    The script requires SqlServer PowerShell module (you can install it 
    with: Install-Module -Name SqlServer) and PowerShell 5.0 or later.

    author: Marco Bellaccini - marco.bellaccini[at!]gmail.com
    license: Creative Commons CC0
    https://creativecommons.org/publicdomain/zero/1.0/
#>

##### SCRIPT VARIABLES YOU MUST EDIT #####

# target location for database backups (local folder or network shared folder)
# BEWARE: ALL THE SUBFOLDERS OLDER THAN $backpers DAYS (see below) WILL BE DELETED BY
# THE AUTOMATIC BACKUP PURGE PERFORMED BY THE SCRIPT
$bktgtroot = "\\backupnas\server01backup\susdbBackup"

# log file
$maintlog = "C:\Scripts\wsusbackup\wsusBackuplog.log"

# backup retention period (days)
$backpers = 70

# WSUS db backup temporary folder
# THIS FOLDER MUST BE WRITABLE BY WINDOWS INTERNAL DATABASE SERVICE USER
# (which is, by default, "NT SERVICE\MSSQL$MICROSOFT##WID")
$dbtmpf = "C:\dbbacktmp"

# WID WSUS Server Instance
# (if unsure, keep the default)
$widsi = "\\.\pipe\MICROSOFT##WID\tsql\query"

# WSUS DB Maintenance T-SQL script path
# You can get the WSUSDBMaintenance T-SQL script at:
# https://gallery.technet.microsoft.com/scriptcenter/6f8cde49-5c52-4abd-9820-f1d270ddea61
$reindexscr = "C:\Scripts\wsusbackup\WSUSDBMaintenance.sql"

# WSUS http port
$wsusport = "8530"

# notification email recipients
$emaildest = "John Doe <john.doe@foodom1.com>", "Liz Foo <liz.foo@foodom1.com>"

# sender address
$emailsrc = "noreply <noreply@foodom1.com>"

# email subject - when maintenance succeeded
$emailsubok = "[wsus-Maintenance] Maintenance Succeeded"

# email body - when maintenance succeeded
$emailbodyok = "Maintenance Succeeded."

# email subject - when maintenance failed
$emailsubfail = "[wsus-Maintenance] Maintenance FAILED"

# email body - when maintenance failed
$emailbodyfail = "Maintenance FAILED."

# smtp server
$emailsmtp = "smtp.foodom1.com"


##### ------------------------------ #####


# exit-failure function
function Ex-Failure {
    # log the error
    "MAINTENANCE FAILED, ABORTING PENDING OPERATIONS" | Out-File $maintlog -Append -NoClobber
    # send email notification
    Send-MailMessage -To $emaildest -From $emailsrc -Subject $emailsubfail `
    -Body $emailbodyfail -SmtpServer $emailsmtp
    # quit with non-zero return code
    exit 12301
}

# get start time
$acttime = Get-Date

# log date/time
$acttime | Out-File $maintlog -Append -NoClobber

# log Maintenance start
"MAINTENANCE STARTED" | Out-File $maintlog -Append -NoClobber

# create a subfolder for the backup
# (use the current date/time as the name)
$actdate = Get-Date -Format FileDateTime
$bkpath = $bktgtroot + "\$actdate"
New-Item -ItemType directory -Path $bkpath -ErrorAction SilentlyContinue

####### BACKUP WSUS #######

$susdbtmp = $dbtmpf + "\SUSDB.bak"

# delete old backup temporary file (if exists)
if (Test-Path $susdbtmp) {
    Remove-Item $susdbtmp
}

# perform SUSDB backup
Backup-SqlDatabase -ServerInstance $widsi -Database "SUSDB" -BackupFile $susdbtmp

# exit on failure
if (-not (Test-Path $susdbtmp)) {
    Ex-Failure
}

# create compressed backup in destination path
$susdbtgt = $bkpath + "\SUSDB.bak.zip"
$susdbtgtres = Compress-Archive -LiteralPath $susdbtmp -DestinationPath $susdbtgt

# exit on failure
if (-not (Test-Path $susdbtgt)) {
    Ex-Failure
}

# delete backup temporary file
Remove-Item $susdbtmp

# log backup result
"SUSDB Backup was successful" | Out-File $maintlog -Append -NoClobber
"Backup file:" | Out-File $maintlog -Append -NoClobber
Get-ChildItem -Path $susdbtgt | Out-File $maintlog -Append -NoClobber

####### WSUS RE-INDEXING #######

# invoke sqlcmd to re-index SUSDB
Invoke-Sqlcmd -InputFile $reindexscr -ServerInstance $widsi

# log re-index result
"SUSDB was re-indexed" | Out-File $maintlog -Append -NoClobber

####### WSUS CLEANUP #######

# get WSUS object
$wsuso = Get-WsusServer -name $env:computername -PortNumber $wsusport

# perform full WSUS cleanup
$wscres = Invoke-WsusServerCleanup -CleanupObsoleteComputers -CleanupObsoleteUpdates -CleanupUnneededContentFiles `
-CompressUpdates -DeclineExpiredUpdates -DeclineSupersededUpdates -UpdateServer $wsuso

# exit on failure
if (-not $wscres) {
    Ex-Failure
}

# log cleanup results
"WSUS cleanup was successful" | Out-File $maintlog -Append -NoClobber
$wscres | Out-File $maintlog -Append -NoClobber

####### FINALIZATION AND OLD BACKUP PURGE #######

## Old backup purge

# log "purge start"
"STARTING OLD BACKUP PURGE" | Out-File $maintlog -Append -NoClobber

# set retention limit
$limit = (Get-Date).AddDays(-$backpers)

# list folders older than retention limit
$dtodel = Get-ChildItem -Path $bktgtroot -Force | Where-Object { $_.PSIsContainer -and $_.CreationTime -lt $limit } 

# log folders marked for deletion
if ($dtodel) {
    "The following folders will be deleted:" | Out-File $maintlog -Append -NoClobber
    $dtodel | Out-File $maintlog -Append -NoClobber
} else {
    "There are no folders to delete." | Out-File $maintlog -Append -NoClobber
}

# remove old backup folders
$dtodel | Remove-Item -Recurse -Force

# log Maintenance success
"MAINTENANCE WAS SUCCESSFUL" | Out-File $maintlog -Append -NoClobber

# complete success: send email notification
Send-MailMessage -To $emaildest -From $emailsrc -Subject $emailsubok -Body $emailbodyok `
-SmtpServer $emailsmtp
