# Starts an existing local SingLearn AVD. Does not install SDKs or change global settings.
[CmdletBinding()]
param(
    [string]$SdkRoot = 'D:\Android\Sdk',
    [string]$AvdHome = 'D:\Android\SingLearn\avd',
    [string]$AvdName = 'SingLearn_API35',
    [ValidateRange(5554, 5682)]
    [ValidateScript({ $_ % 2 -eq 0 })]
    [int]$Port = 5554,
    [switch]$Headless
)

$ErrorActionPreference = 'Stop'
$adb = Join-Path $SdkRoot 'platform-tools\adb.exe'
$emulator = Join-Path $SdkRoot 'emulator\emulator.exe'
$device = "emulator-$Port"
foreach ($path in @($adb, $emulator, (Join-Path $AvdHome "$AvdName.ini"))) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing: $path" }
}

# Only readiness probes may fail while ADB cannot see the device yet.
# Windows PowerShell 5.1 turns redirected native stderr into NativeCommandError
# under Stop. Keep Continue local to this function; the caller stays on Stop.
function Invoke-AdbProbe {
    param([string[]]$AdbArguments)
    $ErrorActionPreference = 'Continue'
    $output = & $adb @AdbArguments 2>$null
    $exitCode = $LASTEXITCODE
    [pscustomobject]@{ ExitCode = $exitCode; Output = ($output -join "`n").Trim() }
}

$existing = Invoke-AdbProbe -AdbArguments @('-s', $device, 'get-state')
if ($existing.ExitCode -eq 0 -and $existing.Output -eq 'device') {
    $runningName = & $adb -s $device emu avd name
    if ($runningName -notcontains $AvdName) {
        throw "$device already belongs to a different AVD; choose another -Port."
    }
    $boot = & $adb -s $device shell getprop sys.boot_completed
    if ($boot -eq '1') {
        & $adb -s $device shell input keyevent KEYCODE_WAKEUP
        Write-Output "$AvdName is already running: $device"
        return
    }
    throw "$AvdName is still booting; wait for Android's home screen before running again."
}

$dataRoot = Split-Path -Parent $AvdHome
$logs = Join-Path $dataRoot 'logs'
$temp = Join-Path $dataRoot 'temp'
foreach ($dir in @($logs, $temp)) {
    Microsoft.PowerShell.Management\New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
# Only the emulator child inherits these values. Restore the caller afterwards.
$names = @('ANDROID_AVD_HOME', 'TEMP', 'TMP')
$previous = @{}
foreach ($name in $names) {
    $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
    $env:ANDROID_AVD_HOME = $AvdHome
    $env:TEMP = $temp
    $env:TMP = $temp
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $arguments = @('-avd', $AvdName, '-port', "$Port", '-memory', '2048',
        '-cores', '2', '-gpu', 'auto', '-no-boot-anim', '-no-snapshot-save',
        '-camera-back', 'none', '-camera-front', 'none')
    if ($Headless) { $arguments += '-no-window' }
    $process = Start-Process -FilePath $emulator -ArgumentList $arguments -PassThru `
        -RedirectStandardOutput (Join-Path $logs "emulator-$stamp.stdout.log") `
        -RedirectStandardError (Join-Path $logs "emulator-$stamp.stderr.log")
} finally {
    foreach ($name in $names) {
        [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process')
    }
}

$deadline = (Get-Date).AddMinutes(6)
do {
    $boot = Invoke-AdbProbe -AdbArguments @('-s', $device, 'shell', 'getprop', 'sys.boot_completed')
    if ($boot.ExitCode -eq 0 -and $boot.Output -eq '1') {
        & $adb -s $device shell input keyevent KEYCODE_WAKEUP
        Write-Output "Ready: $AvdName ($device), AVD data: $AvdHome"
        Write-Output "From nhom10-65ktpm/src: flutter run --no-pub -d $device"
        Write-Output "Stop: & '$adb' -s $device emu kill"
        return
    }
    if ($process.HasExited -and $process.ExitCode -ne 0) {
        throw "Emulator exited with code $($process.ExitCode). Check $logs."
    }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)
throw "Emulator did not finish booting in 6 minutes. Check $logs; no data was wiped."
