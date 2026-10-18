param(
    [string]$Bds = 'D:\Embarcadero RAD Studio\23.0',
    [ValidateSet('Win32', 'Win64')][string]$Platform = 'Win32',
    [string]$OutputDir = "$env:LOCALAPPDATA\XmlDocPlugin\CLI"
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'vendor\DelphiAST\Source\DelphiAST.pas'))) {
    throw 'Initialize DelphiAST first: git submodule update --init --recursive'
}
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$units = Join-Path $OutputDir $Platform
New-Item -ItemType Directory -Force $units | Out-Null
Push-Location $PSScriptRoot
try {
    Push-Location src\HelpGen
    try {
        & "$Bds\bin\brcc32.exe" HelpManual.rc
        if ($LASTEXITCODE) { throw 'Help & Manual resource compilation failed' }
    } finally { Pop-Location }
    $versionResources = Join-Path $units 'version'
    & (Join-Path $PSScriptRoot 'build-version.ps1') -Bds $Bds -ResourceDir $versionResources | Out-Null
    $compiler = if ($Platform -eq 'Win32') { 'dcc32' } else { 'dcc64' }
    & cmd.exe /d /c "`"$Bds\bin\rsvars.bat`" && $compiler -B --codepage:65001 `"-R$versionResources`" -NSSystem;System.Win;Winapi;Vcl;Xml;Data -Ivendor\DelphiAST\Source\SimpleParser -U`"src\Core;src\HelpGen;vendor\DelphiAST\Source;vendor\DelphiAST\Source\SimpleParser`" `"-E$units`" `"-N0$units`" src\CLI\XmlDocGen.dpr"
    if ($LASTEXITCODE) { throw 'CLI compilation failed' }
} finally { Pop-Location }
Write-Host "Built $units\XmlDocGen.exe"
