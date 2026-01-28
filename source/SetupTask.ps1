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

# Run as current user, limited privileges
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited -LogonType Interactive

# Register the task
Register-ScheduledTask -TaskName 'GuildShopSync' -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host 'GuildShopSync task created successfully'
