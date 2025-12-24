<#
.SYNOPSIS
    This script is designed to identify inactive enterprise applications in Microsoft Entra ID

.DESCRIPTION
    This script connects to Microsoft Graph, retrieves all enterprise applications, and checks
    their sign-in activity over the last 30 days. Apps with no sign-ins in the last 30 days
    are considered inactive and displayed in the console output.

.NOTES
    Author: Daniel Boyle
    Date: 12/24/2025
    Version: 0.1
    Requires: PowerShell 7+ or Powershell Core on Mac/Linux
    
.LINK
    https://learn.microsoft.com/en-us/graph/
#>


### Start Code ###

# Initiate some variables
$inactiveApps = @()
$activeApps = @()
$cutoffDate = (Get-Date).AddDays(-30)

# Define required modules
$modules = @('Microsoft.Graph.Applications', 'Microsoft.Graph.Reports')

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
    Connect-MgGraph -Scopes "Application.Read.All", "AuditLog.Read.All" -NoWelcome -ErrorAction Stop
    Write-Host 'Connection to MS Graph successful' -ForegroundColor Green
}
catch {
    Write-Host 'Unable to connect to MS Graph' -ForegroundColor Red
    Write-Host $Error[0] -ForegroundColor Red
    exit 1
}

# Get enterprise apps
Write-Host 'Getting all enterprise applications' -ForegroundColor White
$enterpriseApps = Get-MgServicePrincipal -All -Property DisplayName, Id, AppId, ServicePrincipalType
Write-Host "$($enterpriseApps.count) enterprise apps found" -ForegroundColor Green

# Loop through enterprise apps to check sign-in activity
$i = 0
if ($enterpriseApps.Count -gt 0) {
    foreach ($enterpriseApp in $enterpriseApps) {
        $i++
        $percent = [int](($i / $enterpriseApps.Count) * 100)
        Write-Progress -Activity 'Checking enterprise application sign-in activity' -Status "Processing $i of $($enterpriseApps.Count)" -PercentComplete $percent
        
        try {
            # Get sign-in logs for this app
            $signIns = Get-MgAuditLogSignIn -Filter "appId eq '$($enterpriseApp.AppId)' and createdDateTime ge $($cutoffDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))" -Top 1 -ErrorAction SilentlyContinue
            
            if ($signIns -and $signIns.Count -gt 0) {
                # App has sign-ins in the last 30 days
                $activeApps += [PSCustomObject]@{
                    AppName          = $enterpriseApp.DisplayName
                    AppId            = $enterpriseApp.AppId
                    ServicePrincipalId = $enterpriseApp.Id
                    LastSignIn       = $signIns[0].CreatedDateTime
                }
            }
            else {
                # No sign-ins in the last 30 days - app is inactive
                $inactiveApps += [PSCustomObject]@{
                    AppName          = $enterpriseApp.DisplayName
                    AppId            = $enterpriseApp.AppId
                    ServicePrincipalId = $enterpriseApp.Id
                }
            }
        }
        catch {
            # Log the error but continue processing
            Write-Verbose "Unable to retrieve sign-in data for $($enterpriseApp.DisplayName): $($_.Exception.Message)"
            # Consider app inactive if we can't retrieve sign-in data
            $inactiveApps += [PSCustomObject]@{
                AppName          = $enterpriseApp.DisplayName
                AppId            = $enterpriseApp.AppId
                ServicePrincipalId = $enterpriseApp.Id
            }
        }
    }
    Write-Progress -Activity 'Checking enterprise application sign-in activity' -Completed
}

# Display results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Enterprise Application Activity Report" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Report Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "Activity Period: Last 30 days" -ForegroundColor White
Write-Host ""

# Display inactive apps
if ($inactiveApps.count -gt 0) {
    Write-Host "INACTIVE APPLICATIONS (No sign-ins in last 30 days):" -ForegroundColor Red
    Write-Host "Total Inactive Apps: $($inactiveApps.count)" -ForegroundColor Red
    Write-Host ""
    foreach ($app in $inactiveApps | Sort-Object AppName) {
        Write-Host "  - $($app.AppName)" -ForegroundColor Yellow
        Write-Host "    App ID: $($app.AppId)" -ForegroundColor Gray
    }
}
else {
    Write-Host "No inactive applications found" -ForegroundColor Green
}

Write-Host ""

# Display summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Apps Checked: $($enterpriseApps.count)" -ForegroundColor White
Write-Host "Active Apps: $($activeApps.count)" -ForegroundColor Green
Write-Host "Inactive Apps: $($inactiveApps.count)" -ForegroundColor Red
Write-Host ""

