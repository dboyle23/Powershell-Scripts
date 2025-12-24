<#
.SYNOPSIS
    This script is designed to find all users in Entra ID that have not logged in recently.

.DESCRIPTION
    This script checks for all required modules, installs them if not present, connects to MS Graph, gets
    all users and their sign-in activity, and reports on inactive users. Normal users are considered inactive
    if they have not logged in within 90 days, and guest users within 30 days.

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
$today = (Get-Date).Date
$normalUserThreshold = 90
$guestUserThreshold = 30
$inactiveUsers = @()

# Define required modules
$modules = @('Microsoft.Graph.Users', 'Microsoft.Graph.Reports')

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
    Connect-MgGraph -Scopes "User.Read.All", "AuditLog.Read.All" -NoWelcome -ErrorAction Stop
    Write-Host 'Connection to MS Graph succesful' -ForegroundColor Green
}
catch {
    Write-Host 'Unable to connect to MS Graph' -ForegroundColor Red
    Write-Host $Error[0] -ForegroundColor Red
    exit 1
}

# Get all users with sign-in activity
Write-Host 'Getting all users from Entra ID' -ForegroundColor White
try {
    $users = Get-MgUser -All -Property 'id,displayName,userPrincipalName,userType,signInActivity' -ErrorAction Stop
    Write-Host "$($users.Count) users found" -ForegroundColor Green
}
catch {
    Write-Host 'Failed to retrieve users' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Loop through users to check for inactivity
$i = 0
if ($users.Count -gt 0) {
    foreach ($user in $users) {
        $i++
        $percent = [int](($i / $users.Count) * 100)
        Write-Progress -Activity 'Checking user sign-in activity' -Status "Processing $i of $($users.Count)" -PercentComplete $percent
        
        # Determine user type threshold
        if ($user.UserType -eq 'Guest') {
            $threshold = $guestUserThreshold
        }
        else {
            $threshold = $normalUserThreshold
        }
        
        # Check last sign-in activity
        $lastSignIn = $null
        $daysSinceSignIn = $null
        
        if ($user.SignInActivity) {
            # Try to get the most recent sign-in date
            if ($user.SignInActivity.LastSignInDateTime) {
                $lastSignIn = [DateTime]$user.SignInActivity.LastSignInDateTime
            }
            elseif ($user.SignInActivity.LastNonInteractiveSignInDateTime) {
                $lastSignIn = [DateTime]$user.SignInActivity.LastNonInteractiveSignInDateTime
            }
        }
        
        # Calculate days since last sign-in
        if ($lastSignIn) {
            $daysSinceSignIn = ($today - $lastSignIn.Date).Days
        }
        else {
            # User has never signed in
            $daysSinceSignIn = $null
        }
        
        # Determine if user is inactive
        $isInactive = $false
        if ($daysSinceSignIn -eq $null) {
            # Never signed in
            $isInactive = $true
        }
        elseif ($daysSinceSignIn -gt $threshold) {
            $isInactive = $true
        }
        
        # Add to inactive users list
        if ($isInactive) {
            $inactiveUsers += [PSCustomObject]@{
                DisplayName       = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                UserType          = $user.UserType
                LastSignIn        = if ($lastSignIn) { $lastSignIn.ToString('yyyy-MM-dd') } else { 'Never' }
                DaysSinceSignIn   = if ($daysSinceSignIn) { $daysSinceSignIn } else { 'N/A' }
                Threshold         = $threshold
            }
        }
    }
    Write-Progress -Activity 'Checking user sign-in activity' -Completed
}

# Display results
if ($inactiveUsers.Count -eq 0) {
    Write-Host "`nNo inactive users found" -ForegroundColor Green
}
else {
    Write-Host "`nFound $($inactiveUsers.Count) inactive user(s):" -ForegroundColor Yellow
    Write-Host ""
    
    # Sort by user type and days since sign-in
    $sortedUsers = $inactiveUsers | Sort-Object UserType, @{Expression = {if ($_.DaysSinceSignIn -eq 'N/A') { 999999 } else { [int]$_.DaysSinceSignIn }}; Descending = $true}
    
    foreach ($user in $sortedUsers) {
        # Color code based on severity
        if ($user.DaysSinceSignIn -eq 'N/A') {
            $color = 'Red'
            Write-Host "[$($user.UserType)] $($user.DisplayName) ($($user.UserPrincipalName)) - Never signed in" -ForegroundColor $color
        }
        else {
            $days = [int]$user.DaysSinceSignIn
            if ($user.UserType -eq 'Guest') {
                if ($days -gt 90) {
                    $color = 'Red'
                }
                elseif ($days -gt 60) {
                    $color = 'Yellow'
                }
                else {
                    $color = 'White'
                }
            }
            else {
                if ($days -gt 180) {
                    $color = 'Red'
                }
                elseif ($days -gt 120) {
                    $color = 'Yellow'
                }
                else {
                    $color = 'White'
                }
            }
            Write-Host "[$($user.UserType)] $($user.DisplayName) ($($user.UserPrincipalName)) - Last sign-in: $($user.LastSignIn) ($($user.DaysSinceSignIn) days ago)" -ForegroundColor $color
        }
    }
    
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "  Total inactive users: $($inactiveUsers.Count)" -ForegroundColor Cyan
    Write-Host "  Normal users (>$normalUserThreshold days): $(($inactiveUsers | Where-Object { $_.UserType -ne 'Guest' }).Count)" -ForegroundColor Cyan
    Write-Host "  Guest users (>$guestUserThreshold days): $(($inactiveUsers | Where-Object { $_.UserType -eq 'Guest' }).Count)" -ForegroundColor Cyan
}
