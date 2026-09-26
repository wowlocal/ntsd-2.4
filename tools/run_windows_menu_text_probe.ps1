<# Controlled DirectDraw/GDI text observation. Never starts the original EXE.
   Use in an ordinary PowerShell session permitted to run this reviewed script.
   No execution-policy, network, administrator or security-setting changes.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [Parameter(Mandatory = $true)][string]$EnvironmentDescription
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$kit = $PSScriptRoot
$manifestPath = Join-Path $kit 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne 'ntsd-windows-menu-text-build-v1') { throw 'Unsupported kit' }
foreach ($property in $manifest.files.PSObject.Properties) {
    if ($property.Name -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Invalid kit path' }
    $file = Join-Path $kit $property.Name
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $property.Value.sha256 -or
        (Get-Item -LiteralPath $file).Length -ne $property.Value.bytes) { throw "Kit mismatch: $($property.Name)" }
}
if (-not $EnvironmentDescription.Trim()) { throw 'Actual environment description required' }
$out = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $out) { throw 'Refusing to overwrite capture directory' }
[void](New-Item -ItemType Directory -Path $out)
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $out 'manifest.json')
$record = [ordered]@{
    schema = 'ntsd-windows-menu-text-run-v1'
    environmentDescription = $EnvironmentDescription
    startedUTC = [DateTime]::UtcNow.ToString('o')
    completedUTC = $null
    powershellVersion = $PSVersionTable.PSVersion.ToString()
    runnerPointerBits = [IntPtr]::Size * 8
    runnerProcessArchitecture = $env:PROCESSOR_ARCHITECTURE
    runnerNativeArchitectureVariable = $env:PROCESSOR_ARCHITEW6432
    manifestSHA256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    firstMenuSHA256 = $manifest.firstMenuSHA256
    windowsRegistry = [ordered]@{}
    moduleFiles = @()
    captures = @()
    failure = $null
    complete = $false
    gameExecuted = $false
    nativeCompared = $false
    fileHashScope = 'Runner-visible module files, not loaded-image hashes; WOW64 redirection remains explicit.'
}
$recordPath = Join-Path $out 'run.json'
function Save-Record { $record | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $recordPath -Encoding UTF8 }
function Decode-UTF16Hex([string]$Hex) {
    if ($Hex.Length % 4 -ne 0) { throw 'Invalid UTF-16 hex' }
    $data = New-Object byte[] ($Hex.Length / 2)
    for ($i=0; $i -lt $data.Length; $i++) { $data[$i]=[Convert]::ToByte($Hex.Substring(2*$i,2),16) }
    return [Text.Encoding]::Unicode.GetString($data)
}
Save-Record
try {
    $version = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    foreach ($name in @('ProductName','EditionID','DisplayVersion','CurrentBuildNumber','UBR','BuildLabEx')) {
        $property = $version.PSObject.Properties[$name]
        if ($null -ne $property) { $record.windowsRegistry[$name]=$property.Value }
    }
    $architectures = @('x86')
    foreach ($arch in $architectures) {
        $directory = Join-Path $out $arch
        [void](New-Item -ItemType Directory -Path $directory)
        $exe = Join-Path $kit "probe-windows-menu-text-$arch.exe"
        $process = Start-Process -FilePath $exe -WorkingDirectory $directory -PassThru
        # Bound observation, preserve a stalled child; timeout is not termination.
        $capture = [ordered]@{
            architecture=$arch; processId=$process.Id
            processStartUTC=$process.StartTime.ToUniversalTime().ToString('o')
            executable=$exe; launchWorkingDirectory=$directory
            timedOut=$false; terminal=$false; exitCode=$null; rawExists=$false
        }
        $record.captures += $capture; Save-Record
        if (-not $process.WaitForExit(60000)) {
            $capture.timedOut = $true
            Save-Record
            throw "Collector $arch exceeded the observation interval; exact child and partial output retained, no termination or retry"
        }
        $capture.terminal=$true
        $capture.exitCode=$process.ExitCode
        $path=Join-Path $directory 'menu-text.json'; $capture.rawExists=Test-Path -LiteralPath $path
        if ($capture.rawExists) {
            $capture.bytes=(Get-Item -LiteralPath $path).Length
            $capture.sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        Save-Record
        if ($capture.timedOut -or $process.ExitCode -ne 0) { throw "Collector $arch failed; partial output retained" }
        $raw=Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        foreach ($module in $raw.environment.modules) {
            if ($module.loaded -and $module.pathCharacters -lt 1024) {
                $modulePath=Decode-UTF16Hex $module.pathUTF16LE
                $item=[ordered]@{architecture=$arch; path=$modulePath; exists=(Test-Path -LiteralPath $modulePath -PathType Leaf)}
                if ($item.exists) {
                    $info=Get-Item -LiteralPath $modulePath
                    $item.bytes=$info.Length; $item.fileVersion=$info.VersionInfo.FileVersion
                    $item.sha256=(Get-FileHash -LiteralPath $modulePath -Algorithm SHA256).Hash.ToLowerInvariant()
                }
                $record.moduleFiles += $item
            }
        }
    }
    $record.complete=$true
} catch {
    $record.failure=$_.Exception.ToString()
    throw
} finally {
    $record.completedUTC=[DateTime]::UtcNow.ToString('o'); Save-Record
}
Write-Output "Capture retained in $out; controlled observations are not full-menu or Native acceptance."
