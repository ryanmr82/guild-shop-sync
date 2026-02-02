# SetupTask.ps1 - Creates the GuildShopSync scheduled task with correct settings
# Called by the installer after file installation (runs under admin elevation)
param(
    [string]$ServicePath
)

# Remove existing task cleanly
Unregister-ScheduledTask -TaskName 'GuildShopSync' -Confirm:$false -ErrorAction SilentlyContinue

# Create action - run SyncService.ps1 hidden
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $ServicePath + '"')

# Trigger at logon with 30-second delay
$trigger = New-ScheduledTaskTrigger -AtLogon
$trigger.Delay = 'PT30S'

# All settings: battery ok, restart on failure, no time limit, catch up missed
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -RestartCount 999 `
    -ExecutionTimeLimit (New-TimeSpan -Seconds 0)

# Run as current user - use full Windows identity (DOMAIN\User format)
# BUG FIX: $env:USERNAME gives short name which can fail with Register-ScheduledTask
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$principal = New-ScheduledTaskPrincipal -UserId $currentUser -RunLevel Limited -LogonType Interactive

# Register the task with error handling and fallback
try {
    Register-ScheduledTask -TaskName 'GuildShopSync' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null
} catch {
    Write-Host "Method 1 failed ($($_.Exception.Message)) - trying schtasks fallback..."
    $trArg = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$ServicePath"""
    schtasks /create /tn "GuildShopSync" /tr $trArg /sc onlogon /delay 0000:30 /rl limited /f 2>&1 | Out-Null
    # Fix settings that schtasks can't set directly
    try {
        $task = Get-ScheduledTask -TaskName 'GuildShopSync' -ErrorAction Stop
        $task.Settings.AllowStartIfOnBatteries = $true
        $task.Settings.DontStopIfGoingOnBatteries = $true
        $task.Settings.StartWhenAvailable = $true
        $task.Settings.RestartInterval = 'PT1M'
        $task.Settings.RestartCount = 999
        $task.Settings.ExecutionTimeLimit = 'PT0S'
        Set-ScheduledTask -InputObject $task -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Warning: Could not set advanced task settings: $_"
    }
}

# Verify the task actually exists
$verifyTask = Get-ScheduledTask -TaskName 'GuildShopSync' -ErrorAction SilentlyContinue
if ($verifyTask) {
    Write-Host 'GuildShopSync task created successfully'
} else {
    Write-Host 'ERROR: GuildShopSync task was NOT created. Please run SetupTask.ps1 as Administrator.'
    exit 1
}
