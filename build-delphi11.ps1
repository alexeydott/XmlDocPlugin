param(
    [string]$Bds = 'D:\Embarcadero RAD Studio\22.0',
    [ValidateSet('Debug', 'Release')][string]$Config = 'Release',
    [string]$OutputDir = "$env:PUBLIC\Documents\Embarcadero\Studio\22.0\Bpl",
    [string]$DcpOutputDir = ''
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'build-delphi12.ps1') -PackageVersion 11 -Bds $Bds -Config $Config -OutputDir $OutputDir -DcpOutputDir $DcpOutputDir
