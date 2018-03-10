#Requires -Version 3.0
#Requires -Modules WindowsServerBackup

<#
    wsBackupPurgeNotify.ps1
    A PowerShell script to automate backup management,
    using Windows Server Backup Cmdlets.
    It handles backup execution, logging, old backups purge and e-mail notifications.
    You can use it to backup to network shared folders too.

    It is meant to be run through a scheduled task.

    It requires the WindowsServerBackup PowerShell module and
    PowerShell 3.0 or later.

    author: Marco Bellaccini - marco.bellaccini[at!]gmail.com
    license: Creative Commons CC0
    https://creativecommons.org/publicdomain/zero/1.0/
#>

##### SCRIPT VARIABLES YOU MUST EDIT #####

# location where the computer should store backups (local folder or network shared folder)
# BEWARE: ALL THE SUBFOLDERS OLDER THAN $backpers DAYS (see below) WILL BE DELETED BY
# THE AUTOMATIC BACKUP PURGE PERFORMED BY THE SCRIPT
$bktgtroot = "\\backupnas\server01backup\windowsServerBackup"

# log file
$backupdellog = "C:\MyScripts\Backup\backuplog.log"

# drives to backup
$volpathtb = "C:"

# backup retention period (days)
$backpers = 70

# notification email recipients
$emaildest = "John Doe <john.doe@foodom1.com>", "Liz Foo <liz.foo@foodom1.com>"

# sender address
$emailsrc = "noreply <noreply@foodom1.com>"

# email subject - when backup/purge succeeded
$emailsubok = "[ws-Backup] Backup Succeeded"

# email body - when backup/purge succeeded
$emailbodyok = "Backup Succeeded."

# email subject - when backup/purge failed
$emailsubfail = "[ws-Backup] Backup FAILED"

# email body - when backup/purge failed
$emailbodyfail = "Backup FAILED."

# smtp server
$emailsmtp = "smtp.foodom1.com"

##### ------------------------------ #####

# backup start time
$acttime = Get-Date

# get previous backup details
$oldbackjob = Get-WBJob -Previous 1 

# log date/time
$acttime | Out-File $backupdellog -Append -NoClobber

## Backup Execution

# log Backup start
"BACKUP STARTED" | Out-File $backupdellog -Append -NoClobber

# create a subfolder for the backup
# (use the current date/time as the name)
$actdate = Get-Date -Format FileDateTime
$bkpath = $bktgtroot + "\$actdate"
New-Item -ItemType directory -Path $bkpath -ErrorAction SilentlyContinue

# create backup policy
$wbpolicy = New-WBPolicy

# backup target
$bktgt = New-WBBackupTarget -NetworkPath $bkpath
Add-WBBackupTarget -Policy $wbpolicy -Target $bktgt

# bare-metal recovery
Add-WBBareMetalRecovery -Policy $wbpolicy

# systemstate
Add-WBSystemState -Policy $wbpolicy

# drives to backup
$cvol = Get-WBVolume -VolumePath $volpathtb
Add-WBVolume -Policy $wbpolicy -Volume $cvol

# start backup (logging output)
Start-WBBackup -Policy $wbpolicy -Force | Out-File $backupdellog -Append -NoClobber

## Check if backup succeeded

# wait for backup status to be updated (that's awful, but necessary)
while ((Get-WbJob).JobType -ne [Microsoft.Windows.ServerBackup.Commands.WBJobType]::None) {
    Start-Sleep -s 5
}

# get backup details
$backjob = Get-WBJob -Previous 1
# if backup was not performed (i.e.: backup start time did not change)
# or if backup failed (non-zero return code),
if (($backjob.StartTime -eq $oldbackjob.StartTime) -or ($backjob.HResult -ne "0")) {
    # log the error
    "BACKUP FAILED, ABORTING OLD BACKUP PURGE" | Out-File $backupdellog -Append -NoClobber
    # send email notification
    Send-MailMessage -To $emaildest -From $emailsrc -Subject $emailsubfail `
    -Body $emailbodyfail -SmtpServer $emailsmtp
    # quit
    exit
}

## Old backup purge

# log "purge start"
"STARTING OLD BACKUP PURGE" | Out-File $backupdellog -Append -NoClobber

# set retention limit
$limit = (Get-Date).AddDays(-$backpers)

# list folders older than retention limit
$dtodel = Get-ChildItem -Path $bktgtroot -Force | Where-Object { $_.PSIsContainer -and $_.CreationTime -lt $limit } 

# log folders marked for deletion
if ($dtodel) {
    "The following folders will be deleted:" | Out-File $backupdellog -Append -NoClobber
    $dtodel | Out-File $backupdellog -Append -NoClobber
} else {
    "There are no folders to delete." | Out-File $backupdellog -Append -NoClobber
}

# remove old backup folders
$dtodel | Remove-Item -Recurse -Force

# send email notification
Send-MailMessage -To $emaildest -From $emailsrc -Subject $emailsubok -Body $emailbodyok `
-SmtpServer $emailsmtp
