#Requires -Version 4.0
#Requires -Modules ActiveDirectory
<#
    evtDetective.ps1

    A PowerShell script that queries Windows computers in a certain
    Active Directory OU for some event in event logs.

    It requires PowerShell 4.0 or later.

    author: Marco Bellaccini - marco.bellaccini[at!]gmail.com

    license: Creative Commons CC0
    https://creativecommons.org/publicdomain/zero/1.0/

#>

##### SCRIPT VARIABLES YOU MUST EDIT #####

# eventid to look for
$evtid = 1102

# log to search
$logname = 'security'

# credential to use
$usern = 'domain01\username'

# OU with target computers
$ou = "OU=Office1,OU=Italy,OU=Europe,DC=domain01,DC=com"

# number of computers to sequentially query in each batch
# 1        => quicker - full parallelism (but lots of powershell processes may be spawned)
# 2,3,4... => slower (but saves memory)
$srvperbatch = 3

##### ------------------------------ #####


# empty computer list
$srvl = @()

# get credential, prompting for password
$cr = Get-Credential -Credential $usern

# get computers in the OU
$computers = Get-ADComputer -Filter '*' -SearchBase $ou -Credential $cr

# put computers in the array
foreach($comp in $computers)
{
    # if DNSHostName is available, use it
    if ($comp.DNSHostName) {
        $srvl += $comp.DNSHostName
    }
    # else use CN
    else {
        $srvl += ($comp.DistinguishedName -split ',*..=')[1] # this extracts CN
    }
}

# computer count
$comcount = $srvl.Count

# get start time
$stime = Get-Date

Write-Output "Starting queries at $stime"
Write-Output "Querying $comcount computers..."

# parallel execution setup
$i = 0
$j = $srvperbatch - 1

while ($i -lt $comcount) {
    $srvbatch = $srvl[$i..$j]

    Start-Job -ScriptBlock {
        param([string]$logname,
              [int]$evtid,
              [PSCredential]$cr,
              [string[]]$srvl
        )
        foreach ($srv in $srvl)
        {

            try
            {
                $evt = Get-WinEvent @{logname=$logname;id=$evtid} -MaxEvents 1 -computername $srv -Credential $cr -ErrorAction SilentlyContinue
                # if event was found
                if ($evt) {
                    $evtTime = $evt.TimeCreated
                    Write-Output "Event $evtid was found in $srv $logname log - logged on $evtTime"
                }
                # else...
                else {
                    Write-Output "No event $evtid in $srv $logname log"
                }
            }
        
            # if unable to connect to computer
            catch [System.Diagnostics.Eventing.Reader.EventLogException]
            {
                Write-Output "Unable to connect to $srv"
            }
            # if unauthorized
            catch [System.UnauthorizedAccessException]
            {
                Write-Output "Cannot get $srv log: unauthorized"
            }

        }
    } -ArgumentList($logname,$evtid,$cr,$srvbatch) | Out-Null # suppress output

    $i = $j + 1
    $j += $srvperbatch

    if ($i -gt $comcount) {$i = $comcount}
    if ($j -gt $comcount) {$j = $comcount}
}


# wait for all jobs to finish
Get-Job | Wait-Job | Out-Null # suppress output

# get end time
$etime = Get-Date

Write-Output "Done."
Write-Output "Queries ended at $etime"


# receive jobs
Get-Job | Receive-Job

# remove jobs
Get-Job | Remove-Job | Out-Null # suppress output
