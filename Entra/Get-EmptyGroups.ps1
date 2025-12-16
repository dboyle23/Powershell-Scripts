<#
.SYNOPSIS
    This script is designed to find all groups in Entra ID that contain no members.

.DESCRIPTION
    This script checks for all required modules, installs them if not present, connects to MS Graph, gets
    all the groups and reports on which ones have no members.

.NOTES
    Author: Daniel Boyle
    Date: 12/16/2025
    Version: 0.1
    Requires: PowerShell 7+ or Powershell Core on Mac/Linux
    
.LINK
    https://learn.microsoft.com/en-us/graph/
#>
# Define required modules
$modules = @('Microsoft.Graph.Groups')

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
    Connect-MgGraph -Scopes "Group.Read.All" -NoWelcome -ErrorAction Stop
    Write-Host 'Connection to MS Graph succesful' -ForegroundColor Green
}
catch {
    Write-Host 'Unable to connect to MS Graph' -ForegroundColor Red
    Write-Host $Error[0] -ForegroundColor Red
}

# Get all groups in Entra ID
Write-Host 'Getting all groups in Entra ID' -ForegroundColor White
$allGroups = Get-MgGroup -All -Property 'id,displayName,members' -ErrorAction Stop
Write-Host "Total groups found: $($allGroups.Count)" -ForegroundColor Green
foreach ($group in $allGroups) {
    if ((Get-MgGroupMember -GroupId $group.Id).count -lt 1) {
        Write-Host "Empty group found: $($group.DisplayName) (ID: $($group.Id))" -ForegroundColor Yellow
    }
}
