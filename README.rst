psBerries
====================
psBerries is my collection of PowerShell scripts.

Of course, all the scripts have been written by me (Marco Bellaccini - marco.bellaccini(at!)gmail.com) 
and are released under `Creative Commons CC0 1.0`_ license.

evtDetective
--------------------
A PowerShell script that queries Windows computers in a certain Active Directory OU for 
some event in event logs.

You can change the target OU and the event to query by modifying the variables at the top of the script.

This script requires PowerShell 4.0 or later.

wsBackupPurgeNotify
--------------------
A PowerShell script to automate backup management, using Windows Server Backup Cmdlets.

Run it through a scheduled task: it will handle backup execution, logging, old backup purge and e-mail notifications.

You can use it to backup to network shared folders too.

It requires the WindowsServerBackup PowerShell module and PowerShell 3.0 or later.

wsusRoboMaintenance
--------------------
A PowerShell script to automate Windows Server Update Services (WSUS) maintenance.

It handles database backup/re-indexing and WSUS cleanup.

It assumes that Windows Internal Database (WID) is used for SUSDB.

Support for logging, old backups purge and e-mail notifications is included.

It is meant to be run through a scheduled task.

The service user running the task should be member of the local Administrators group.

The script requires SqlServer PowerShell module (you can install it with: *Install-Module -Name SqlServer*) and PowerShell 5.0 or later.


.. _Creative Commons CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/legalcode
