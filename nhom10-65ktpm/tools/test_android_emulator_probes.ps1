# Run with Windows PowerShell 5.1 or PowerShell 7. No SDK, AVD or device needed.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'start_android_emulator.ps1'
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $launcher, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -ne 0) { throw "Launcher syntax errors: $parseErrors" }
$definition = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Invoke-AdbProbe'
}, $true)
if ($null -eq $definition) { throw 'Missing Invoke-AdbProbe in launcher' }
# Load only the checked-in helper, never the launcher body (which boots an AVD).
. ([scriptblock]::Create($definition.Extent.Text))

# cmd.exe acts as the native executable: real stderr and native exit codes,
# without invoking ADB, installing anything or starting an emulator.
$adb = $env:ComSpec
$cases = @(
    @{ Name = 'device absent'; Command = 'echo missing-device 1>&2 & exit /b 1'; Code = 1; Output = '' },
    @{ Name = 'device connected'; Command = 'echo device & exit /b 0'; Code = 0; Output = 'device' },
    @{ Name = 'boot not ready'; Command = 'exit /b 0'; Code = 0; Output = '' },
    @{ Name = 'boot complete'; Command = 'echo 1 & exit /b 0'; Code = 0; Output = '1' },
    @{ Name = 'failed probe with stdout'; Command = 'echo 1 & echo failed 1>&2 & exit /b 7'; Code = 7; Output = '1' }
)
foreach ($case in $cases) {
    $result = Invoke-AdbProbe -AdbArguments @('/d', '/c', $case.Command)
    if ($result.ExitCode -ne $case.Code -or $result.Output -ne $case.Output) {
        throw "Probe mismatch: $($case.Name); exit=$($result.ExitCode), output=$($result.Output)"
    }
    if ($ErrorActionPreference -ne 'Stop') { throw 'Probe changed caller error preference' }
    Write-Output "PASS: $($case.Name)"
}

# Parameter/file guards must still terminate before any ADB/emulator invocation.
foreach ($port in @(5555, 5552, 5684)) {
    $rejected = $false
    try { & $launcher -Port $port } catch {
        if ($_.FullyQualifiedErrorId -notlike 'ParameterArgumentValidationError*') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw "Invalid port accepted: $port" }
    Write-Output "PASS: reject port $port"
}
$rejected = $false
try { & $launcher -SdkRoot (Join-Path $PSScriptRoot ([guid]::NewGuid().ToString())) } catch {
    if ($_.Exception.Message -notlike 'Missing:*') { throw }
    $rejected = $true
}
if (-not $rejected) { throw 'Missing SDK accepted' }
Write-Output 'PASS: reject missing SDK'
Write-Output "All 9 checks passed on PowerShell $($PSVersionTable.PSVersion). Launcher parser also passed."
