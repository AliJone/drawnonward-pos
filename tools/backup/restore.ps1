<#
.SYNOPSIS
    Restores a drawnonward POS backup made by backup.ps1.

.DESCRIPTION
    Replaces the current database and the uploaded images with the contents of a
    drawnonward-backup-<date>-<time>.zip. With -IncludeEnv the .env file (settings and
    encryption keys) is restored as well; use that when moving to a new PC.

    The POS must already be installed and running (Docker: docker compose up -d).

.EXAMPLE
    .\restore.ps1 -Backup ..\..\backups\drawnonward-backup-20261003-210000.zip

.EXAMPLE
    .\restore.ps1 -Backup D:\drawnonward-backup-20261003-210000.zip -IncludeEnv -Force
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Backup,

    [ValidateSet('Docker', 'Xampp')]
    [string] $Mode = 'Docker',

    # Folder that holds docker-compose.yml and .env (default: two levels above this script)
    [string] $ProjectRoot = '',

    # Also restore .env (encryption keys and database settings)
    [switch] $IncludeEnv,

    # Do not ask for confirmation
    [switch] $Force,

    # docker compose project name, only needed when it is not the project folder name
    [string] $ComposeProject = '',

    # XAMPP only: path to mysql.exe
    [string] $MysqlPath = 'C:\xampp\mysql\bin\mysql.exe'
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

if ($ProjectRoot -eq '') {
    $ProjectRoot = [IO.Path]::GetFullPath([IO.Path]::Combine($PSScriptRoot, '..', '..'))
}

function Write-Log {
    param([string] $Message, [string] $Level = 'INFO')
    Write-Host ('{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message)
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

function Import-Database {
    param([string] $DumpPath)
    if ($Mode -eq 'Docker') {
        $compose = Get-ComposeArgs
        Invoke-Native 'docker' ($compose + @('cp', $DumpPath, 'mysql:/tmp/drawnonward-restore.sql')) 'Copying the dump into the container' | Out-Null
        $import = 'MYSQL_PWD=$MYSQL_PASSWORD mysql -u$MYSQL_USER $MYSQL_DATABASE < /tmp/drawnonward-restore.sql'
        Invoke-Native 'docker' ($compose + @('exec', '-T', 'mysql', 'sh', '-c', $import)) 'Database import' | Out-Null
        Invoke-Native 'docker' ($compose + @('exec', '-T', 'mysql', 'rm', '-f', '/tmp/drawnonward-restore.sql')) 'Removing the temporary dump' | Out-Null
    } else {
        if (-not (Test-Path $MysqlPath)) { throw "mysql.exe not found at $MysqlPath (use -MysqlPath)" }
        $db = Read-DotEnvDatabase (Join-Path $ProjectRoot '.env')
        $source = 'source ' + ($DumpPath -replace '\\', '/')
        $importArgs = @('-h', $db.hostname, '-u', $db.username, $db.database, '-e', $source)
        if ($db.password -ne '') { $importArgs = @("-p$($db.password)") + $importArgs }
        Invoke-Native $MysqlPath $importArgs 'Database import' | Out-Null
    }
}

function Import-Uploads {
    param([string] $UploadsPath)
    if ($Mode -eq 'Docker') {
        $compose = Get-ComposeArgs
        # A trailing "/." copies the folder contents, not the folder itself
        $contents = $UploadsPath + [IO.Path]::DirectorySeparatorChar + '.'
        Invoke-Native 'docker' ($compose + @('cp', $contents, 'drawnonward:/app/public/uploads/')) 'Copying uploads into the container' | Out-Null
        Invoke-Native 'docker' ($compose + @('exec', '-T', 'drawnonward', 'chown', '-R', 'www-data:www-data', '/app/public/uploads')) 'Fixing upload permissions' | Out-Null
    } else {
        Copy-Item -Path (Join-Path $UploadsPath '*') -Destination (Join-Path $ProjectRoot 'public\uploads') -Recurse -Force
    }
}

# ---------------------------------------------------------------------------------------------
if (-not (Test-Path $Backup)) { throw "Backup file not found: $Backup" }
$Backup = (Resolve-Path $Backup).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) ('drawnonward-restore-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$exitCode = 0

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($Backup, $temp)

    $dump = Join-Path $temp 'database.sql'
    $uploads = Join-Path $temp 'uploads'
    $envFile = Join-Path $temp '.env'
    if (-not (Test-Path $dump)) { throw 'The archive has no database.sql; is this a drawnonward backup?' }
    if (Test-Path (Join-Path $temp 'manifest.txt')) {
        Write-Log ('Backup manifest: ' + ((Get-Content (Join-Path $temp 'manifest.txt')) -join '; '))
    }

    if (-not $Force) {
        Write-Host ''
        Write-Host 'This REPLACES the current database and uploaded images with the backup.' -ForegroundColor Yellow
        if ($IncludeEnv) { Write-Host 'The current .env (settings and encryption keys) will be replaced too.' -ForegroundColor Yellow }
        $answer = Read-Host 'Type YES to continue'
        if ($answer -ne 'YES') { throw 'Restore cancelled by the user' }
    }

    if ($IncludeEnv) {
        if (-not (Test-Path $envFile)) { throw 'The archive has no .env file' }
        Copy-Item -Path $envFile -Destination (Join-Path $ProjectRoot '.env') -Force
        Write-Log '.env restored'
        if ($Mode -eq 'Docker') {
            Invoke-Native 'docker' ((Get-ComposeArgs) + @('restart', 'drawnonward')) 'Restarting the application' | Out-Null
        }
    }

    Write-Log 'Importing the database (this replaces all current data)'
    Import-Database -DumpPath $dump
    Write-Log 'Database restored'

    if (Test-Path $uploads) {
        Import-Uploads -UploadsPath $uploads
        Write-Log 'Uploads restored'
    }

    Write-Log 'Restore finished. Log in to the POS and check a recent sale and the company logo.'
} catch {
    Write-Log "Restore FAILED: $($_.Exception.Message)" 'ERROR'
    $exitCode = 1
} finally {
    if (Test-Path $temp) { Remove-Item -Path $temp -Recurse -Force }
}
exit $exitCode
