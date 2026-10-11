<#
.SYNOPSIS
    Backs up drawnonward POS (database, uploaded images, .env) to a local folder and, optionally, to the cloud.

.DESCRIPTION
    Creates backups\drawnonward-backup-<date>-<time>.zip containing:
      database.sql   full dump of the POS database
      uploads\       company logo and item pictures
      .env           application settings including the encryption keys
      manifest.txt   when, where and from which version the backup was taken

    Works with the Docker install (default) and the XAMPP install (-Mode Xampp).

    Cloud copies:
      -Remote      an rclone destination such as gdrive:drawnonward-backups (Google Drive, OneDrive,
                   Dropbox, S3, Backblaze B2 ... anything rclone supports; https://rclone.org).
                   Use an rclone "crypt" remote so the archives are encrypted before they leave the PC.
      -SyncFolder  a folder that a desktop client already syncs to the cloud, for example
                   "$env:USERPROFILE\OneDrive\drawnonward-backups".
    Both can be given at the same time.

    Exit code 0 on success, 1 on any failure, so Windows Task Scheduler shows the result.
    Everything is also appended to backups\backup.log.

.EXAMPLE
    .\backup.ps1 -Remote gdrive-crypt:drawnonward-backups

.EXAMPLE
    .\backup.ps1 -SyncFolder "$env:USERPROFILE\OneDrive\drawnonward-backups" -KeepDays 7

.EXAMPLE
    .\backup.ps1 -Mode Xampp -Remote onedrive:drawnonward-backups
#>
[CmdletBinding()]
param(
    [ValidateSet('Docker', 'Xampp')]
    [string] $Mode = 'Docker',

    # Folder that holds docker-compose.yml and .env (default: two levels above this script)
    [string] $ProjectRoot = '',

    # Where the zip archives are written (default: <ProjectRoot>\backups)
    [string] $BackupFolder = '',

    # rclone destination, e.g. gdrive:drawnonward-backups. Empty = no rclone upload.
    [string] $Remote = '',

    # Folder synced to the cloud by OneDrive / Google Drive / Dropbox. Empty = not used.
    [string] $SyncFolder = '',

    # Local archives older than this many days are deleted after a successful backup
    [int] $KeepDays = 14,

    # Archives older than this many days are deleted from -Remote and -SyncFolder (0 = keep forever)
    [int] $CloudKeepDays = 180,

    # docker compose project name, only needed when it is not the project folder name
    [string] $ComposeProject = '',

    # XAMPP only: path to mysqldump.exe
    [string] $MysqldumpPath = 'C:\xampp\mysql\bin\mysqldump.exe'
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

if ($ProjectRoot -eq '') {
    $ProjectRoot = [IO.Path]::GetFullPath([IO.Path]::Combine($PSScriptRoot, '..', '..'))
}
if ($BackupFolder -eq '') {
    $BackupFolder = Join-Path $ProjectRoot 'backups'
}
$script:LogFile = Join-Path $BackupFolder 'backup.log'

function Write-Log {
    param([string] $Message, [string] $Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    if (Test-Path (Split-Path $script:LogFile)) {
        Add-Content -Path $script:LogFile -Value $line
    }
}

# Runs a native command, returns its output as text and throws when it exits non-zero.
function Invoke-Native {
    param([string] $Exe, [string[]] $Arguments, [string] $What)
    $previous = $ErrorActionPreference
    # Windows PowerShell 5 turns stderr lines (docker progress messages) into errors; only the exit code matters here
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Exe @Arguments 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($code -ne 0) {
        throw ('{0} failed (exit {1}): {2}' -f $What, $code, (($output -join "`n")).Trim())
    }
    return $output
}

function Get-ComposeArgs {
    $composeArgs = @('compose', '-f', (Join-Path $ProjectRoot 'docker-compose.yml'), '--project-directory', $ProjectRoot)
    if ($ComposeProject -ne '') { $composeArgs += @('-p', $ComposeProject) }
    return $composeArgs
}

# Reads database.default.* from .env (XAMPP install).
function Read-DotEnvDatabase {
    param([string] $EnvPath)
    $settings = @{ hostname = 'localhost'; database = 'drawnonward'; username = 'admin'; password = '' }
    foreach ($line in Get-Content $EnvPath) {
        if ($line -match '^\s*database\.default\.(hostname|database|username|password)\s*=\s*[''"]?([^''"\r\n]*)') {
            $settings[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return $settings
}

function Export-Database {
    param([string] $Staging)
    $target = Join-Path $Staging 'database.sql'

    if ($Mode -eq 'Docker') {
        $compose = Get-ComposeArgs
        # Credentials come from the MariaDB container's own environment, so none are stored here.
        # MYSQL_PWD is read by mysqldump; the assignment form keeps any password characters intact.
        $dump = 'MYSQL_PWD=$MYSQL_PASSWORD mysqldump -u$MYSQL_USER --single-transaction --routines --triggers $MYSQL_DATABASE > /tmp/drawnonward-backup.sql'
        Invoke-Native 'docker' ($compose + @('exec', '-T', 'mysql', 'sh', '-c', $dump)) 'Database dump' | Out-Null
        Invoke-Native 'docker' ($compose + @('cp', 'mysql:/tmp/drawnonward-backup.sql', $target)) 'Copying the dump out of the container' | Out-Null
        Invoke-Native 'docker' ($compose + @('exec', '-T', 'mysql', 'rm', '-f', '/tmp/drawnonward-backup.sql')) 'Removing the temporary dump' | Out-Null
    } else {
        if (-not (Test-Path $MysqldumpPath)) { throw "mysqldump not found at $MysqldumpPath (use -MysqldumpPath)" }
        $db = Read-DotEnvDatabase (Join-Path $ProjectRoot '.env')
        $dumpArgs = @('-h', $db.hostname, '-u', $db.username, '--single-transaction', '--routines', '--triggers',
                      "--result-file=$target", $db.database)
        if ($db.password -ne '') { $dumpArgs = @("-p$($db.password)") + $dumpArgs }
        Invoke-Native $MysqldumpPath $dumpArgs 'Database dump' | Out-Null
    }

    if (-not (Test-Path $target) -or (Get-Item $target).Length -lt 1024) { throw 'Database dump is missing or empty' }
    if (-not (Select-String -Path $target -Pattern 'CREATE TABLE' -Quiet)) { throw 'Database dump contains no tables' }
    return $target
}

function Export-Uploads {
    param([string] $Staging)
    $target = Join-Path $Staging 'uploads'
    if ($Mode -eq 'Docker') {
        Invoke-Native 'docker' ((Get-ComposeArgs) + @('cp', 'drawnonward:/app/public/uploads', $target)) 'Copying uploads out of the container' | Out-Null
    } else {
        Copy-Item -Path (Join-Path $ProjectRoot 'public\uploads') -Destination $target -Recurse
    }
    if (-not (Test-Path $target)) { throw 'Uploads folder was not copied' }
}

function Export-Env {
    param([string] $Staging)
    $envPath = Join-Path $ProjectRoot '.env'
    if (-not (Test-Path $envPath)) { throw ".env not found at $envPath" }
    Copy-Item -Path $envPath -Destination (Join-Path $Staging '.env')
}

function Write-Manifest {
    param([string] $Staging)
    $version = 'unknown'
    $appConfig = Join-Path $ProjectRoot 'app/Config/App.php'
    if (Test-Path $appConfig) {
        $match = Select-String -Path $appConfig -Pattern "application_version\s*=\s*'([^']+)'" | Select-Object -First 1
        if ($match) { $version = $match.Matches[0].Groups[1].Value }
    }
    @(
        "created=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "computer=$([Environment]::MachineName)",
        "mode=$Mode",
        "app_version=$version",
        'contents=database.sql, uploads/, .env'
    ) | Set-Content -Path (Join-Path $Staging 'manifest.txt')
}

function New-BackupArchive {
    param([string] $Staging, [string] $ZipPath)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($Staging, $ZipPath, [IO.Compression.CompressionLevel]::Optimal, $false)

    # Re-open the archive to prove it is readable and complete
    $zip = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $names = @($zip.Entries | ForEach-Object { $_.FullName })
    } finally {
        $zip.Dispose()
    }
    foreach ($required in @('database.sql', '.env', 'manifest.txt')) {
        if ($names -notcontains $required) { throw "Archive is missing $required" }
    }
}

function Remove-OldArchives {
    param([string] $Folder, [int] $Days)
    if ($Days -le 0 -or -not (Test-Path $Folder)) { return }
    $cutoff = (Get-Date).AddDays(-$Days)
    Get-ChildItem -Path $Folder -Filter 'drawnonward-backup-*.zip' -File |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            Write-Log "Deleting old archive $($_.Name)"
            Remove-Item -Path $_.FullName -Force
        }
}

function Send-ToRclone {
    param([string] $ZipPath)
    $rclone = Get-Command rclone -ErrorAction SilentlyContinue
    if (-not $rclone) { throw 'rclone is not installed or not on the PATH. Install it from https://rclone.org/downloads/ and run "rclone config".' }
    $name = Split-Path $ZipPath -Leaf

    Invoke-Native $rclone.Source @('copy', $ZipPath, $Remote, '--stats=0', '--quiet') "Upload to $Remote" | Out-Null

    $listed = Invoke-Native $rclone.Source @('lsf', $Remote, '--include', $name) "Verifying $name on $Remote"
    if (($listed | Out-String) -notmatch [regex]::Escape($name)) { throw "$name is not visible on $Remote after upload" }
    Write-Log "Uploaded $name to $Remote"

    if ($CloudKeepDays -gt 0) {
        Invoke-Native $rclone.Source @('delete', $Remote, '--min-age', "$($CloudKeepDays)d", '--include', 'drawnonward-backup-*.zip', '--quiet') "Cloud retention on $Remote" | Out-Null
    }
}

function Send-ToSyncFolder {
    param([string] $ZipPath)
    if (-not (Test-Path $SyncFolder)) { New-Item -ItemType Directory -Path $SyncFolder | Out-Null }
    Copy-Item -Path $ZipPath -Destination $SyncFolder -Force
    $copied = Join-Path $SyncFolder (Split-Path $ZipPath -Leaf)
    if ((Get-Item $copied).Length -ne (Get-Item $ZipPath).Length) { throw "Copy to $SyncFolder is incomplete" }
    Write-Log "Copied to sync folder $SyncFolder"
    Remove-OldArchives -Folder $SyncFolder -Days $CloudKeepDays
}

# ---------------------------------------------------------------------------------------------
function Invoke-Backup {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $staging = Join-Path $BackupFolder ".staging-$stamp"
    $zipPath = Join-Path $BackupFolder "drawnonward-backup-$stamp.zip"
    $exitCode = 0

    try {
        if (-not (Test-Path $BackupFolder)) { New-Item -ItemType Directory -Path $BackupFolder | Out-Null }
        Write-Log "Backup started ($Mode mode, project $ProjectRoot)"
        New-Item -ItemType Directory -Path $staging | Out-Null

        $dump = Export-Database -Staging $staging
        Write-Log ('Database dumped ({0:N0} KB)' -f ((Get-Item $dump).Length / 1KB))
        Export-Uploads -Staging $staging
        Export-Env -Staging $staging
        Write-Manifest -Staging $staging

        New-BackupArchive -Staging $staging -ZipPath $zipPath
        Write-Log ('Archive written: {0} ({1:N0} KB)' -f $zipPath, ((Get-Item $zipPath).Length / 1KB))

        if ($Remote -ne '') { Send-ToRclone -ZipPath $zipPath }
        if ($SyncFolder -ne '') { Send-ToSyncFolder -ZipPath $zipPath }
        if ($Remote -eq '' -and $SyncFolder -eq '') {
            Write-Log 'No -Remote or -SyncFolder given: the backup exists only on this PC' 'WARN'
        }

        Remove-OldArchives -Folder $BackupFolder -Days $KeepDays
        Write-Log 'Backup finished successfully'
    } catch {
        Write-Log "Backup FAILED: $($_.Exception.Message)" 'ERROR'
        $exitCode = 1
    } finally {
        if (Test-Path $staging) { Remove-Item -Path $staging -Recurse -Force }
    }
    return $exitCode
}

# Dot-sourcing the file only loads the functions (used by the tests)
if ($MyInvocation.InvocationName -ne '.') {
    exit (Invoke-Backup)
}
