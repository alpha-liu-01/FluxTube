# Copy the ARM64 VC++ CRT next to fluxtube.exe and drop any non-ARM64 DLL.
# vcruntime140_1.dll is x64-only and has no ARM64 counterpart.
param(
    [Parameter(Mandatory = $true)]
    [string]$Release
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Release)) {
    throw "missing $Release"
}

$Redist = Get-ChildItem -Path @(
    "${env:ProgramFiles}\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\arm64\Microsoft.VC*.CRT",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\arm64\Microsoft.VC*.CRT"
) -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\onecore\\' } |
    Sort-Object FullName -Descending |
    Select-Object -First 1
if (-not $Redist) {
    throw "ARM64 VC++ CRT redist not found"
}
Write-Host "CRT $($Redist.FullName)"

function Get-PeMachine([string]$File) {
    $Bytes = [IO.File]::ReadAllBytes($File)
    if ($Bytes.Length -lt 64 -or $Bytes[0] -ne 0x4D -or $Bytes[1] -ne 0x5A) { return $null }
    $E = [BitConverter]::ToUInt32($Bytes, 0x3C)
    if (($E + 6) -gt $Bytes.Length) { return $null }
    if ([Text.Encoding]::ASCII.GetString($Bytes, [int]$E, 4) -ne "PE`0`0") { return $null }
    return [BitConverter]::ToUInt16($Bytes, [int]$E + 4)
}

foreach ($Dll in Get-ChildItem -Path $Redist.FullName -Filter '*.dll') {
    $Machine = Get-PeMachine $Dll.FullName
    if ($Machine -ne 0xAA64) {
        Write-Host ("SKIP {0} machine 0x{1:X4}" -f $Dll.Name, $Machine)
        continue
    }
    Copy-Item -Force $Dll.FullName $Release
    Write-Host "COPY $($Dll.Name)"
}

foreach ($File in Get-ChildItem -Path $Release -Filter '*.dll') {
    $Machine = Get-PeMachine $File.FullName
    if ($Machine -ne 0xAA64) {
        Write-Host ("REMOVE {0} machine 0x{1:X4}" -f $File.Name, $Machine)
        Remove-Item -Force $File.FullName
    }
}

foreach ($Name in @('vcruntime140.dll', 'msvcp140.dll')) {
    if (-not (Test-Path (Join-Path $Release $Name))) {
        throw "missing $Name after CRT copy"
    }
}
