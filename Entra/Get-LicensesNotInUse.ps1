<#
.SYNOPSIS
    Identifies unused licenses in the tenant

.DESCRIPTION
    Connects to Microsoft Graph and compares total licenses purchased in the tenant
    against licenses assigned to users, showing which licenses are not in use

.NOTES
    Author: Daniel Boyle
    Date: 12/28/2025
    Version: 0.1
    Requires: PowerShell 7+ or Powershell Core on Mac/Linux
    
.LINK
    https://learn.microsoft.com/en-us/graph/
#>


### Start Code ###

# Define required modules
$modules = @('Microsoft.Graph.Identity.DirectoryManagement')

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
    Connect-MgGraph -Scopes "Organization.Read.All" -NoWelcome -ErrorAction Stop
    Write-Host 'Connection to MS Graph successful' -ForegroundColor Green
}
catch {
    Write-Host 'Unable to connect to MS Graph' -ForegroundColor Red
    Write-Host $Error[0] -ForegroundColor Red
    exit 1
}

# Get all subscribed SKUs (licenses) in the tenant
Write-Host 'Getting all subscribed SKUs in the tenant' -ForegroundColor White
$subscribedSkus = Get-MgSubscribedSku
Write-Host "$($subscribedSkus.Count) license SKUs found in tenant" -ForegroundColor White

# Build results using ConsumedUnits property (no need to enumerate users)
$results = @()
foreach ($sku in $subscribedSkus) {
    $available = $sku.PrepaidUnits.Enabled
    $assigned = $sku.ConsumedUnits
    $unused = $available - $assigned
    
    $results += [PSCustomObject]@{
        SkuPartNumber    = $sku.SkuPartNumber
        SkuId            = $sku.SkuId
        TotalLicenses    = $available
        AssignedLicenses = $assigned
        UnusedLicenses   = $unused
        PercentUsed      = if ($available -gt 0) { [math]::Round(($assigned / $available) * 100, 2) } else { 0 }
    }
}

# Display results
Write-Host "`nLicense Usage Summary:" -ForegroundColor Cyan
Write-Host "=====================`n" -ForegroundColor Cyan

$unusedOnly = $results | Where-Object { $_.UnusedLicenses -gt 0 } | Sort-Object -Property UnusedLicenses -Descending

if ($unusedOnly.Count -eq 0) {
    Write-Host "All licenses are fully utilized!" -ForegroundColor Green
}
else {
    Write-Host "Found $($unusedOnly.Count) license types with unused licenses:`n" -ForegroundColor Yellow
    
    foreach ($result in $unusedOnly) {
        Write-Host "License: $($result.SkuPartNumber)" -ForegroundColor White
        Write-Host "  Total: $($result.TotalLicenses) | Assigned: $($result.AssignedLicenses) | Unused: $($result.UnusedLicenses) | Usage: $($result.PercentUsed)%" -ForegroundColor Gray
        
        if ($result.PercentUsed -lt 50) {
            Write-Host "  WARNING: Less than 50% utilization" -ForegroundColor Red
        }
        elseif ($result.PercentUsed -lt 80) {
            Write-Host "  NOTICE: Less than 80% utilization" -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

# Show fully utilized licenses
$fullyUsed = $results | Where-Object { $_.UnusedLicenses -eq 0 }
if ($fullyUsed.Count -gt 0) {
    Write-Host "`nFully utilized licenses:" -ForegroundColor Green
    foreach ($result in $fullyUsed) {
        Write-Host "  $($result.SkuPartNumber) - $($result.AssignedLicenses)/$($result.TotalLicenses) (100%)" -ForegroundColor Green
    }
}

Write-Host "`nDone!" -ForegroundColor Cyan
