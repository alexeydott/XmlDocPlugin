param(
    [string]$Rad12 = 'D:\Embarcadero RAD Studio\23.0',
    [string]$Rad13 = 'D:\Embarcadero RAD Studio\37.0',
    [string]$ISCC = 'D:\tools\InnoSetup\6\ISCC.exe',
    [string]$Version = '',
    [switch]$IncrementVersion,
    [string]$OutputDir = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$Version = & (Join-Path $PSScriptRoot 'build-version.ps1') -Version $Version -IncrementVersion:$IncrementVersion
# Only the final EXE goes into OutputDir. All staging, DCPs and hashes stay outside Git.
$workDir = Join-Path $env:LOCALAPPDATA 'XmlDocPlugin\Installer'
$stage = Join-Path $workDir 'payload'
$retiredPayload = [IO.Path]::GetFullPath((Join-Path $stage 'rad12-x64'))
if (!$retiredPayload.StartsWith([IO.Path]::GetFullPath($workDir) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid retired payload path' }
if (Test-Path -LiteralPath $retiredPayload) { Remove-Item -LiteralPath $retiredPayload -Recurse -Force }
New-Item -ItemType Directory -Force $OutputDir | Out-Null
if (!(Test-Path -LiteralPath (Join-Path $Rad13 'bin\dcc64.exe'))) { throw 'RAD Studio 13 Win64 compiler not found' }
foreach ($root in @($Rad12, $Rad13)) {
    foreach ($file in @('bin\bds.exe', 'bin\rsvars.bat', 'bin\dcc32.exe')) {
        if (!(Test-Path -LiteralPath (Join-Path $root $file))) { throw "Required build tool missing: $root\$file" }
    }
}
if (!(Test-Path -LiteralPath $ISCC)) { throw "Inno Setup compiler not found: $ISCC" }
Push-Location $PSScriptRoot
try {
    # Build the bundled editor, resources and Win32 package first.
    & .\build-delphi12.ps1 -Bds $Rad12 -OutputDir (Join-Path $stage 'rad12-x86') -DcpOutputDir (Join-Path $workDir 'intermediate\rad12-x86')
    if (!$?) { throw 'RAD Studio 12 build failed' }
    $sdk = Join-Path $env:LOCALAPPDATA 'XmlDocPlugin\Build\WebView2-1.0.2045.28\sdk'
    foreach ($target in @(
        @{Name='rad13-x86'; Bds=$Rad13; Package='13'; Platform='Win32'; Arch='x86'},
        @{Name='rad13-x64'; Bds=$Rad13; Package='13'; Platform='Win64'; Arch='x64'})) {
        $dir = Join-Path $stage $target.Name
        $dcpDir = Join-Path $workDir "intermediate\$($target.Name)"
        New-Item -ItemType Directory -Force $dir, $dcpDir | Out-Null
        & cmd.exe /d /c "`"$($target.Bds)\bin\rsvars.bat`" && msbuild src\Packages\$($target.Package)\XmlDocPlugin.dproj /t:Rebuild /p:Config=Release /p:Platform=$($target.Platform) `"/p:DCC_BplOutput=$dir`" `"/p:DCC_DcpOutput=$dcpDir`" /v:minimal"
        if ($LASTEXITCODE) { throw "Package build failed: $($target.Name)" }
        Copy-Item "$sdk\build\native\$($target.Arch)\WebView2Loader.dll" $dir
        Copy-Item "$sdk\LICENSE.txt" (Join-Path $dir 'WebView2-LICENSE.txt')
        Copy-Item "$sdk\NOTICE.txt" (Join-Path $dir 'WebView2-NOTICE.txt')
    }
    & .\build-cli.ps1 -Bds $Rad13 -Platform Win64 -OutputDir (Join-Path $workDir 'cli-build')
    if (!$?) { throw 'Win64 command-line generator build failed' }
    $cliDir = Join-Path $stage 'bin'
    New-Item -ItemType Directory -Force $cliDir | Out-Null
    Copy-Item (Join-Path $workDir 'cli-build\Win64\XmlDocGen.exe') $cliDir -Force
    $cliBytes = [IO.File]::ReadAllBytes((Join-Path $cliDir 'XmlDocGen.exe'))
    $cliPE = [BitConverter]::ToInt32($cliBytes, 60)
    if ([BitConverter]::ToUInt16($cliBytes, $cliPE + 4) -ne 0x8664) { throw 'Command-line generator must be an x64 executable' }
    foreach ($binary in @('rad12-x86\XmlDocPlugin290.bpl','rad13-x86\XmlDocPlugin370.bpl','rad13-x64\XmlDocPlugin370.bpl','bin\XmlDocGen.exe')) {
        $binaryInfo = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $stage $binary))
        $fv = '{0}.{1}.{2}.{3}' -f $binaryInfo.FileMajorPart,$binaryInfo.FileMinorPart,$binaryInfo.FileBuildPart,$binaryInfo.FilePrivatePart
        $pv = '{0}.{1}.{2}.{3}' -f $binaryInfo.ProductMajorPart,$binaryInfo.ProductMinorPart,$binaryInfo.ProductBuildPart,$binaryInfo.ProductPrivatePart
        if ($fv -ne $Version -or $pv -ne $Version) { throw "Binary version mismatch: $binary ($fv / $pv), expected $Version" }
    }
    $cache = Join-Path $env:LOCALAPPDATA 'XmlDocPlugin\InstallerCache'
    New-Item -ItemType Directory -Force $cache | Out-Null
    $bootstrap = Join-Path $cache 'MicrosoftEdgeWebview2Setup.exe'
    if (!(Test-Path -LiteralPath $bootstrap)) {
        Invoke-WebRequest 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $bootstrap
    }
    $signature = Get-AuthenticodeSignature -LiteralPath $bootstrap
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(?:,|$)') {
        throw 'The WebView2 bootstrapper must have a valid Microsoft signature.'
    }
    Copy-Item $bootstrap $stage
    $hashes = Get-ChildItem $stage -Recurse -File | Where-Object Name -ne 'manifest.json' | Get-FileHash -Algorithm SHA256 | ForEach-Object {
        [pscustomobject]@{Path=$_.Path.Substring($stage.Length+1); SHA256=$_.Hash}
    }
    $hashes | ConvertTo-Json | Set-Content (Join-Path $stage 'manifest.json') -Encoding UTF8
    & $ISCC "/DStageDir=$stage" "/DOutputDir=$OutputDir" "/DAppVersion=$Version" installer\XmlDocPlugin.iss
    if ($LASTEXITCODE) { throw 'Inno Setup compilation failed' }
    $installer = Join-Path $OutputDir 'XmlDocPlugin-Setup.exe'
    $info = [Diagnostics.FileVersionInfo]::GetVersionInfo($installer)
    $fileVersion = '{0}.{1}.{2}.{3}' -f $info.FileMajorPart, $info.FileMinorPart, $info.FileBuildPart, $info.FilePrivatePart
    if ($fileVersion -ne $Version) { throw "Installer file version mismatch: $fileVersion instead of $Version" }
    $productVersion = '{0}.{1}.{2}.{3}' -f $info.ProductMajorPart,$info.ProductMinorPart,$info.ProductBuildPart,$info.ProductPrivatePart
    if ($productVersion -ne $Version) { throw "Installer product version mismatch: $productVersion instead of $Version" }
    (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash | Set-Content (Join-Path $workDir 'XmlDocPlugin-Setup.exe.sha256') -Encoding ASCII

    Write-Host "Installer: $installer (FileVersion $fileVersion)"
} finally { Pop-Location }
