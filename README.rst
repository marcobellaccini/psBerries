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

easyiLO
--------------------
`CVE-2017-12542 <https://nvd.nist.gov/vuln/detail/CVE-2017-12542>`_ exploit in PowerShell:

creates a new iLO administrative user without authentication.

Works with HP iLO 4 < 2.53

Usage example:

``easyiLO.ps1 https://10.0.0.3 newadmin newpassword``

It requires PowerShell 5.1 or later.

remoteVTChecker
--------------------
A PowerShell script to check all processes of a remote server on `VirusTotal <https://www.virustotal.com/>`_.

Process hashes are computed server-side and sent to the client (the local computer).

Then, the client checks the hashes on VirusTotal.

This means that this will work even if the remote computer is missing Internet connection.

It requires PowerShell 4.0 or later both server and client side.


.. _Creative Commons CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/legalcode
