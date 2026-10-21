param([string]$Bds = 'D:\Embarcadero RAD Studio\23.0')
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'build-helpinsight.ps1') -Check
& (Join-Path $PSScriptRoot 'build-locales.ps1') -Check
if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot 'vendor\DelphiAST\Source\DelphiAST.pas'))) {
    throw 'Initialize DelphiAST first: git submodule update --init --recursive'
}
$testRoot = Join-Path $env:LOCALAPPDATA 'XmlDocPlugin\Tests'
$sdk = Join-Path $env:LOCALAPPDATA 'XmlDocPlugin\Build\WebView2-1.0.2045.28\sdk'
if (!(Test-Path "$sdk\build\native\x86\WebView2Loader.dll")) {
    throw 'Run build-delphi12.ps1 first to obtain the WebView2 SDK.'
}
function Compile-Test([string]$Compiler, [string]$Name, [string]$Output) {
    $search = "src\Core;src\Plugin;src\HelpGen;vendor\DelphiAST\Source;vendor\DelphiAST\Source\SimpleParser;$Bds\source\DunitX"
    & cmd.exe /d /c "`"$Bds\bin\rsvars.bat`" && $Compiler -B --codepage:65001 -NSSystem;System.Win;Winapi;Vcl -Ivendor\DelphiAST\Source\SimpleParser `"-U$search`" `"-E$Output`" `"-N0$Output`" tests\$Name.dpr"
    if ($LASTEXITCODE) { throw "$Name compilation failed" }
}
Push-Location $PSScriptRoot
try {
    Push-Location src\HelpGen
    try {
        & "$Bds\bin\brcc32.exe" HelpManual.rc
        if ($LASTEXITCODE) { throw 'Help & Manual resource compilation failed' }
    } finally { Pop-Location }
    Push-Location src\Plugin
    try {
        & "$Bds\bin\brcc32.exe" XmlDocEditor.rc
        if ($LASTEXITCODE) { throw 'Editor resource compilation failed' }
        & "$Bds\bin\brcc32.exe" XmlDocSplash.rc
        if ($LASTEXITCODE) { throw 'Splash resource compilation failed' }
    } finally { Pop-Location }
    Push-Location tests
    try {
        & "$Bds\bin\brcc32.exe" BrowserSmoke.rc
        if ($LASTEXITCODE) { throw 'Smoke resource compilation failed' }
    } finally { Pop-Location }
    foreach ($arch in @('x86', 'x64')) {
        $output = Join-Path $testRoot $arch
        New-Item -ItemType Directory -Force $output | Out-Null
        Copy-Item "$sdk\build\native\$arch\WebView2Loader.dll" $output
        $compiler = if ($arch -eq 'x86') { 'dcc32' } else { 'dcc64' }
        foreach ($name in @('SettingsSmoke', 'BrowserSmoke', 'UnitEditorSmoke', 'FakeHHC', 'XmlDocTests')) {
            Compile-Test $compiler $name $output
            if ($name -eq 'FakeHHC') { continue }
            & "$output\$name.exe"
            if ($LASTEXITCODE) { throw "$arch $name failed" }
        }
        foreach ($fixture in @('HMXPFixture', 'HMXPEmpty', 'MarkupFixture')) {
            & "$PSScriptRoot\tests\Validate-HMXP.ps1" (Join-Path $output "$fixture\hmxp\Documentation.hmxp")
        }
    }
} finally { Pop-Location }
