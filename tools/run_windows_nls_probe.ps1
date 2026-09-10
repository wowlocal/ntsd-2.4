<# Run the bounded NTSD NLS collector on an explicitly identified Windows OS.
   No game launch, networking, administrator privileges, policy changes or hooks.
   Preserve raw results even if a process fails. See WINDOWS_REFERENCE_PLAN.md.
   Example in an ordinary PowerShell session permitted to run this reviewed file:
   .\run_windows_nls_probe.ps1 -OutputDirectory C:\NTSD-Research\nls-001 `
       -EnvironmentDescription 'Windows build ..., VM ..., Windows x86 translation' -Architecture x86
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [Parameter(Mandatory = $true)][string]$EnvironmentDescription,
    [ValidateSet('x86', 'arm64', 'both')][string]$Architecture = 'x86'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$kit = $PSScriptRoot
$manifestPath = Join-Path $kit 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne 'ntsd-windows-nls-build-v1') { throw 'Unsupported kit manifest' }
foreach ($property in $manifest.files.PSObject.Properties) {
    if ($property.Name -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Invalid manifest filename' }
    $file = Join-Path $kit $property.Name
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $property.Value.sha256 -or (Get-Item -LiteralPath $file).Length -ne $property.Value.bytes) {
        throw "Kit hash/length mismatch: $($property.Name)"
    }
}
$out = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $out) { throw 'Refusing to overwrite an existing capture directory' }
[void](New-Item -ItemType Directory -Path $out)
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $out 'manifest.json')
$record = [ordered]@{
    schema = 'ntsd-windows-nls-run-v1'
    environmentDescription = $EnvironmentDescription
    startedUTC = [DateTime]::UtcNow.ToString('o')
    completedUTC = $null
    powershellVersion = $PSVersionTable.PSVersion.ToString()
    runnerPointerBits = [IntPtr]::Size * 8
    runnerProcessArchitecture = $env:PROCESSOR_ARCHITECTURE
    runnerNativeArchitectureVariable = $env:PROCESSOR_ARCHITEW6432
    manifestSHA256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    fileHashScope = 'Files visible to the PowerShell runner, not loaded-image hashes; retain WOW64 filesystem-view limits.'
    windowsRegistry = [ordered]@{}
    captures = @()
    files = @()
    failure = $null
    complete = $false
    nativeCompared = $false
}
$recordPath = Join-Path $out 'run.json'
function Save-Record {
    $record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $recordPath -Encoding UTF8
}
function Record-File([string]$Path, [string]$Role) {
    $item = [ordered]@{ path = $Path; role = $Role; exists = $false }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $info = Get-Item -LiteralPath $Path
        $item.exists = $true
        $item.bytes = $info.Length
        $item.sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        $item.fileVersion = $info.VersionInfo.FileVersion
    }
    $record.files += $item
}
function Decode-UTF16Hex([string]$Hex) {
    if ($Hex.Length % 4 -ne 0) { throw 'Invalid UTF-16 byte sequence' }
    $data = New-Object byte[] ($Hex.Length / 2)
    for ($i = 0; $i -lt $data.Length; $i++) { $data[$i] = [Convert]::ToByte($Hex.Substring(2 * $i, 2), 16) }
    return [Text.Encoding]::Unicode.GetString($data)
}
Save-Record
try {
    $version = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    foreach ($name in @('ProductName', 'EditionID', 'DisplayVersion', 'CurrentBuildNumber', 'UBR', 'BuildLabEx')) {
        $value = $version.PSObject.Properties[$name]
        if ($null -ne $value) { $record.windowsRegistry[$name] = $value.Value }
    }
    $architectures = @($Architecture)
    if ($Architecture -eq 'both') { $architectures = @('x86', 'arm64') }
    foreach ($arch in $architectures) {
        $directory = Join-Path $out $arch
        [void](New-Item -ItemType Directory -Path $directory)
        $exe = Join-Path $kit "probe-windows-nls-$arch.exe"
        $process = Start-Process -FilePath $exe -WorkingDirectory $directory -PassThru -Wait
        $capturePath = Join-Path $directory 'nls.json'
        $capture = [ordered]@{ architecture = $arch; exitCode = $process.ExitCode; rawExists = (Test-Path -LiteralPath $capturePath) }
        if ($capture.rawExists) {
            $capture.bytes = (Get-Item -LiteralPath $capturePath).Length
            $capture.sha256 = (Get-FileHash -LiteralPath $capturePath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        $record.captures += $capture
        Save-Record
        if ($process.ExitCode -ne 0) { throw "Collector $arch exited $($process.ExitCode); raw output retained" }
        $raw = Get-Content -LiteralPath $capturePath -Raw | ConvertFrom-Json
        foreach ($module in $raw.environment.modules) {
            if ($module.loaded -and $module.pathCharacters -lt 1024) {
                Record-File (Decode-UTF16Hex $module.pathUTF16LE) "$arch module path reported by GetModuleFileNameW"
            }
        }
    }
    foreach ($relative in @('System32\locale.nls', 'System32\c_1252.nls', 'System32\l_intl.nls',
                            'System32\Sorts\sortdefault.nls', 'SysWOW64\kernel32.dll',
                            'SysWOW64\kernelbase.dll', 'SysWOW64\ntdll.dll')) {
        Record-File (Join-Path $env:SystemRoot $relative) 'Explicit OS/NLS file in runner filesystem view'
    }
    $record.complete = $true
} catch {
    $record.failure = $_.Exception.ToString()
    throw
} finally {
    $record.completedUTC = [DateTime]::UtcNow.ToString('o')
    Save-Record
}
Write-Output "Capture retained in $out. Validate raw files before any Windows compatibility claim."
