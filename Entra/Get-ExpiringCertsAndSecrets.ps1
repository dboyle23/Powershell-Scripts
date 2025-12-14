<#
.SYNOPSIS
    This script is designed to let you know which certificates and secrets for your enterprise apps
    and app registrations will expire soon

.DESCRIPTION
    This script checks for all required modules, installs them if not present, connects to MS Graph, gets
    all the certificates and secrets for enterprise apps and app registrations and then sorts them in
    order of expiration (soonest at the top)

.NOTES
    Author: Daniel Boyle
    Date: 12/11/2025
    Version: 0.1
    Requires: PowerShell 7+ or Powershell Core on Mac/Linux
    
.LINK
    https://learn.microsoft.com/en-us/graph/
#>


### Start Code ###

# Initiate some variables
$enterpriseAppsWithCertificates = @()
$today = (Get-Date).Date

# Define required modules
$modules = @('Microsoft.Graph.Applications')#, 'Microsoft.Graph.ServicePrincipal')

# Ensure required modules are loaded into the session
Write-Host 'Checking required PowerShell modules are available and loaded' -ForegroundColor White
foreach ($module in $modules) {
    $available = Get-Module -ListAvailable -Name $module
    if (-not $available) {
        Write-Host "Module $module is not installed on this system. Please install it (Install-Module -Name $module) and re-run." -ForegroundColor Yellow
        exit 1
    }

    if (-not (Get-Module -Name $module)) {
        try {
            Import-Module $module -ErrorAction Stop
            Write-Host "Module $module imported into the session" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to import module $module" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "Module $module already loaded" -ForegroundColor White
    }
}


# Connect to Microsoft Graph
Write-Host 'Attempting to connect to MS Graph interactively' -ForegroundColor White
try {
    Connect-MgGraph -Scopes "Application.Read.All" -NoWelcome -ErrorAction Stop
    Write-Host 'Connection to MS Graph succesful' -ForegroundColor Green
}
catch {
    Write-Host 'Unable to connect to MS Graph' -ForegroundColor Red
    Write-Host $Error[0] -ForegroundColor Red
}

# Get enterprise apps
Write-Host 'Getting all enterprise applications' -ForegroundColor White
$enterpriseApps = Get-MgServicePrincipal -All -Property DisplayName, keyCredentials, preferredTokenSigningKeyThumbprint
Write-Host "$($enterpriseApps.count) enterprise apps found"

# Loop through enterprise apps to determine if app contains a certificate that will expire at some date
# If true, get appname and days left until expiration and place in PSCustomObject $enterpriseAppsWithCertificates
$i = 0
if ($enterpriseApps.Count -gt 0) {
    foreach ($enterpriseApp in $enterpriseApps) {
        $i++
        $percent = [int](($i / $enterpriseApps.Count) * 100)
        Write-Progress -Activity 'Checking enterprise applications' -Status "Processing $i of $enterpriseApps.Count" -PercentComplete $percent
        $certs = $enterpriseApp.KeyCredentials
        if ($certs) {
            foreach ($cert in $certs) {
                try {
                    $expirationdate = [DateTime]$cert.EndDateTime.ToLocalTime()
                }
                catch {
                    continue
                }

                $daysRemaining = ($expirationdate - $today).Days
                $enterpriseAppsWithCertificates += [PSCustomObject]@{
                    AppName        = $enterpriseApp.DisplayName
                    DaysRemaining  = $daysRemaining
                    ExpirationDate = $expirationdate
                    KeyId          = $cert.KeyId
                }
            }
        }
    }
    Write-Progress -Activity 'Checking enterprise applications' -Completed
}

# If no apps found
if ($enterpriseAppsWithCertificates.count -lt 1) {
    Write-Host 'No enterprise apps with certificates found' -ForegroundColor Yellow
}

# Sort apps by expiration date and show top 10
else {
    Write-Host 'The following applications are the next to expire:' -ForegroundColor Yellow

    # For apps with multiple certificates, pick the certificate with the earliest ExpirationDate
    $collapsed = $enterpriseAppsWithCertificates |
    Group-Object -Property AppName |
    ForEach-Object {
        $_.Group | Sort-Object ExpirationDate | Select-Object -First 1
    }

    $top = $collapsed | Sort-Object ExpirationDate | Select-Object -First 10

    foreach ($e in $top) {
        $daysRemaining = ($e.ExpirationDate - $today).Days
        if ($daysRemaining -le 30) {
            $color = 'Red'
        }
        elseif ($daysRemaining -le 90) {
            $color = 'Yellow'
        }
        else {
            $color = 'Green'
        }
        if ($daysRemaining -lt 0) {
            $daysRemaining = [Math]::Abs($daysRemaining)
            Write-Host "$($e.AppName) expired $($daysRemaining) days ago" -ForegroundColor $color
        }
        Write-Host "$($e.AppName) will expire in $($daysRemaining) days" -ForegroundColor $color
    }
}


# Check app registration secrets
Write-Host "`nChecking app registration secrets" -ForegroundColor White
$appRegistrationsWithSecrets = @()

# Get all app registrations
Write-Host 'Getting all app registrations' -ForegroundColor White
$apps = Get-MgApplication -All -Property DisplayName, passwordCredentials
Write-Host "$($apps.count) app registrations found"

# Add progress for app registration secrets
$j = 0
if ($apps.Count -gt 0) {
    foreach ($app in $apps) {
        $j++
        $percent = [int](($j / $apps.Count) * 100)
        Write-Progress -Activity 'Checking application registrations (secrets)' -Status "Processing $j of $apps.Count" -PercentComplete $percent
        $secrets = $app.PasswordCredentials
        if ($secrets) {
            foreach ($secret in $secrets) {
                try {
                    $expiration = [DateTime]$secret.EndDateTime.ToLocalTime()
                }
                catch {
                    continue
                }

                $daysRemaining = ($expiration - $today).Days
                $appRegistrationsWithSecrets += [PSCustomObject]@{
                    AppName           = $app.DisplayName
                    DaysRemaining     = $daysRemaining
                    ExpirationDate    = $expiration
                    KeyId             = $secret.KeyId
                    SecretDisplayName = $secret.DisplayName
                }
            }
        }
    }
    Write-Progress -Activity 'Checking application registrations (secrets)' -Completed
}

# No app registration secrets found
if ($appRegistrationsWithSecrets.count -lt 1) {
    Write-Host 'No application registration secrets found' -ForegroundColor Yellow
}

# Sort app registration secrets by expiration date and show top 10
else {
    Write-Host 'The following app registrations are the next to expire:' -ForegroundColor Yellow

    $collapsedSecrets = $appRegistrationsWithSecrets |
    Group-Object -Property AppName |
    ForEach-Object {
        $_.Group | Sort-Object ExpirationDate | Select-Object -First 1
    }

    $topSecrets = $collapsedSecrets | Sort-Object ExpirationDate | Select-Object -First 10

    foreach ($r in $topSecrets) {
        $daysRemaining = ($r.ExpirationDate - $today).Days
        if ($daysRemaining -le 30) {
            $color = 'Red'
        }
        elseif ($daysRemaining -le 90) {
            $color = 'Yellow'
        }
        else {
            $color = 'Green'
        }
        if ($daysRemaining -lt 0) {
            $daysRemaining = [Math]::Abs($daysRemaining)
            Write-Host "$($r.AppName) secret '$($r.SecretDisplayName)' expired $($daysRemaining) days ago" -ForegroundColor $color
            continue
        }
        Write-Host "$($r.AppName) expires in $($daysRemaining) days" -ForegroundColor $color
    }
}


