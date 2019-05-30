#Requires -Version 4.0
<#
    remoteVTChecker.ps1
    A PowerShell script to check all processes of a remote server on VirusTotal.
    Process hashes are computed server-side and sent to the client (the local computer).
    Then, the client checks the hashes on VirusTotal.
    This means that this will work even if the remote computer is missing Internet
    connection.

    It requires PowerShell 4.0 or later both server and client side.
    author: Marco Bellaccini - marco.bellaccini[at!]gmail.com
    license: Creative Commons CC0
    https://creativecommons.org/publicdomain/zero/1.0/
#>

##### SCRIPT VARIABLES YOU MUST EDIT #####
# target host
$tgtcomputer = "REMOTE_HOSTNAME"
# username - SHOULD BE AN ADMINISTRATOR OF THE REMOTE MACHINE
$username = "USERNAME"
# VirusTotal API Key
$VTApiKey = "YOUR_API_KEY"
##### ------------------------------ #####

# script block to execute on the remote server
$sb_gethashes = { 
                    $hashes = @{} # empty hash table
                    foreach ($proc in Get-Process) {
                        if ($proc.path) {
                            $hashes.Set_Item((Get-FileHash $proc.path -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash, $proc.path)
                        }
                    }
                    $hashes
                }

# this is adapted from: https://gallery.technet.microsoft.com/Get-VirusTotalReport-90065fad
function Query-VirusTotal {

    param([string]$hash)
    
    $body = @{ resource = $hash; apikey = $VTApiKey }

    # if report is empty, wait and retry
    do {
        $VTReport = Invoke-RestMethod -Method 'POST' -Uri 'https://www.virustotal.com/vtapi/v2/file/report' -Body $body
        if (!$VTReport) {
            Start-Sleep -s 4 | Out-Null
        }
    } until ($VTReport)
    
    # if unknown hash, return -1
    if (!$VTReport.scans) {
        return -1
    }

    $VTReport.positives
}


$cr = Get-Credential -UserName $username -Message "Please enter credentials:"
$hres = Invoke-Command -ComputerName $tgtcomputer -Credential $cr -ScriptBlock $sb_gethashes

Write-Host "SHA256 HASH`t`t`t`t`t`t`t`t`t`t`t`t`t`t`tPOSITIVES`tFILE PATH"

foreach ($hent in $hres.GetEnumerator()) {
    $VTpositives = (Query-VirusTotal($hent.Name))
    # if positives
    if ($VTpositives -gt 0) {
        Write-Host "$($hent.Name)`t$($VTpositives)`t`t`t$($hent.Value)"  -ForegroundColor Red
    }
    # if known and no positives
    elseif ($VTpositives -eq 0) {
        Write-Host "$($hent.Name)`t$($VTpositives)`t`t`t$($hent.Value)"
    }
    # if unknown hash
    else {
        Write-Host "$($hent.Name)`tUNKNOWN`t`t$($hent.Value)" -ForegroundColor Yellow
    }
}
