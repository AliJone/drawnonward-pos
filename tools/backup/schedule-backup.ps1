<#
.SYNOPSIS
    Registers (or removes) a daily Windows scheduled task that runs backup.ps1.

.DESCRIPTION
    The task runs as the current user while they are logged on, which is required for the Docker
    install because Docker Desktop runs inside the user's session. If the PC is off at the scheduled
    time, the backup runs as soon as the user logs on again.

    Run this once from PowerShell in the tools\backup folder. Re-running it replaces the task.

.EXAMPLE
    .\schedule-backup.ps1 -Time 21:00 -Remote gdrive-crypt:drawnonward-backups

.EXAMPLE
    .\schedule-backup.ps1 -Time 21:30 -SyncFolder "$env:USERPROFILE\OneDrive\drawnonward-backups" -Mode Xampp

.EXAMPLE
    .\schedule-backup.ps1 -Unregister
#>
[CmdletBinding()]
param(
    # Time of day, 24-hour clock
    [string] $Time = '21:00',

    [string] $Remote = '',
    [string] $SyncFolder = '',
    [int] $KeepDays = 14,
    [int] $CloudKeepDays = 180,
    [ValidateSet('Docker', 'Xampp')]
    [string] $Mode = 'Docker',
    [string] $ComposeProject = '',

    [string] $TaskName = 'drawnonward POS backup',

    # Remove the task instead of creating it
    [switch] $Unregister
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command Register-ScheduledTask -ErrorAction SilentlyContinue)) {
    throw 'Scheduled task cmdlets are not available; this script is for Windows.'
}

if ($Unregister) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed scheduled task '$TaskName'."
    exit 0
}

$backupScript = Join-Path $PSScriptRoot 'backup.ps1'
if (-not (Test-Path $backupScript)) { throw "backup.ps1 not found next to this script ($backupScript)" }

$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $backupScript), '-Mode', $Mode,
               '-KeepDays', $KeepDays, '-CloudKeepDays', $CloudKeepDays)
if ($Remote -ne '')         { $arguments += @('-Remote', ('"{0}"' -f $Remote)) }
if ($SyncFolder -ne '')     { $arguments += @('-SyncFolder', ('"{0}"' -f $SyncFolder)) }
if ($ComposeProject -ne '') { $arguments += @('-ComposeProject', ('"{0}"' -f $ComposeProject)) }

$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ($arguments -join ' ') -WorkingDirectory $PSScriptRoot
$trigger   = New-ScheduledTaskTrigger -Daily -At $Time
$settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME) -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Scheduled task '$TaskName' will run backup.ps1 every day at $Time as $env:USERNAME."
Write-Host "Test it now with:  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "Check the result in Task Scheduler (Last Run Result 0x0 = success) or in ..\..\backups\backup.log"
