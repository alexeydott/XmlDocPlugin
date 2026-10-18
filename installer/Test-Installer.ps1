param(
    [string]$PayloadDir = "$env:LOCALAPPDATA\XmlDocPlugin\Installer\payload",
    [string]$ISCC = 'D:\tools\InnoSetup\6\ISCC.exe'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot
$id = [guid]::NewGuid().ToString()
$dir = Join-Path $env:LOCALAPPDATA "XmlDocPlugin\InstallerTests\$id"
$key = "Software\XmlDocPluginInstallerTests\$id"
New-Item -ItemType Directory $dir -Force | Out-Null
$testPayload = Join-Path $dir 'payload'
New-Item -ItemType Directory $testPayload -Force | Out-Null
Copy-Item "$PayloadDir\*" $testPayload -Recurse -Force
# Only the isolated test installer uses this deterministic runtime fixture.
# The production build always bundles the signed Microsoft bootstrapper.
$runtimeFixture = Join-Path $dir 'RuntimeFixture.cs'
@'
class RuntimeFixture {
  static void Main() {
    System.IO.File.WriteAllText(System.Environment.GetEnvironmentVariable("XMLDOC_TEST_RUNTIME_MARKER"), "executed");
    if (System.Environment.GetEnvironmentVariable("XMLDOC_TEST_RUNTIME_MODE") == "install") {
      using (var key = Microsoft.Win32.Registry.CurrentUser.CreateSubKey(System.Environment.GetEnvironmentVariable("XMLDOC_TEST_RUNTIME_KEY")))
        key.SetValue("pv", "1.0.0.0");
    }
  }
}
'@ | Set-Content $runtimeFixture -Encoding ASCII
& "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe" /nologo /target:winexe "/out:$testPayload\MicrosoftEdgeWebview2Setup.exe" $runtimeFixture
if ($LASTEXITCODE) { throw 'Runtime fixture compilation failed' }
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'XmlDocPlugin.iss'))
$source = $source.Replace('C91E1B1C-1B43-4B75-AC3E-D7DC79CCB435', $id)
$source = $source.Replace('Software\Embarcadero\BDS\', "$key\BDS\")
$source = $source.Replace('Software\Microsoft\EdgeUpdate\Clients\', "$key\WebView\")
$source = $source.Replace('Software\XmlDocPlugin\Installer\', "$key\Backup\")
# Limit process detection to the test-owned fixture; leave running user IDEs alone.
$source = $source.Replace("WHERE Name = ''bds.exe'''", "WHERE Name = ''bds.exe'' AND ProcessId = ' + GetEnv('XMLDOC_TEST_BDS_PID')")
$source = $source.Replace('..\LICENSE', (Join-Path $repo 'LICENSE'))
$source = $source.Replace('OutputBaseFilename=XmlDocPlugin-Setup', 'OutputBaseFilename=InstallerTest-Setup')
$iss = Join-Path $dir 'Test.iss'
[IO.File]::WriteAllText($iss, $source)
$version = & (Join-Path $repo 'build-version.ps1')
& $ISCC "/DStageDir=$testPayload" "/DOutputDir=$dir" "/DAppVersion=$version" $iss *> (Join-Path $dir 'compile.log')
if ($LASTEXITCODE) { throw "Test installer compilation failed: $dir\compile.log" }
$exe = Join-Path $dir 'InstallerTest-Setup.exe'
$app = Join-Path $dir 'installed'
$script:results = @()
function Run-Setup([string]$Name, [bool]$Success, [string[]]$ExtraArguments = @()) {
    $log = Join-Path $dir "$Name.log"
    $p = Start-Process $exe -ArgumentList (@('/VERYSILENT','/SUPPRESSMSGBOXES','/SP-','/NORESTART',"/DIR=`"$app`"","/LOG=`"$log`"") + $ExtraArguments) -PassThru -WindowStyle Hidden
    if (!$p.WaitForExit(60000)) { throw "Timed out: $Name (PID $($p.Id))" }
    if (($p.ExitCode -eq 0) -ne $Success) { throw "Unexpected exit $($p.ExitCode) for $Name. See $log" }
    if (!$Success -and (Test-Path $app)) { throw "Rejected installation wrote application files: $Name" }
    $script:results += "PASS: $Name (exit $($p.ExitCode))"
}
function Test-InstalledCLI {
    $cli = Join-Path $app 'bin\XmlDocGen.exe'
    $bytes = [IO.File]::ReadAllBytes($cli)
    $pe = [BitConverter]::ToInt32($bytes, 60)
    if ([BitConverter]::ToUInt16($bytes, $pe + 4) -ne 0x8664) { throw 'Installed CLI is not x64' }
    if ((Get-FileHash $cli).Hash -ne (Get-FileHash (Join-Path $PayloadDir 'bin\XmlDocGen.exe')).Hash) { throw 'Installed CLI hash mismatch' }
    $inputDir = Join-Path $dir 'cli-source'
    New-Item -ItemType Directory -Force $inputDir | Out-Null
    [IO.File]::WriteAllText((Join-Path $inputDir 'Sample.pas'), 'unit Sample; interface type TSample = class public procedure Run; end; implementation procedure TSample.Run; begin end; end.')
    $output = Join-Path $dir 'cli-output'
    & $cli --directory $inputDir --output $output --format html,json --title 'Installed CLI' --numeric-file-names *> (Join-Path $dir 'cli.log')
    if ($LASTEXITCODE) { throw 'Installed CLI generation failed' }
    if (!(Test-Path "$output\api.json") -or !(Test-Path "$output\units\t000001.html") -or !(Test-Path "$output\topic-map.json")) { throw 'Installed CLI output missing' }
}
try {
    $env:XMLDOC_TEST_RUNTIME_KEY = "$key\WebView\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
    $env:XMLDOC_TEST_RUNTIME_MARKER = Join-Path $dir 'runtime-executed.txt'
    $env:XMLDOC_TEST_BDS_PID = '0'
    $env:XMLDOC_TEST_RUNTIME_MODE = 'fail'
    Run-Setup 'no-ide' $false
    foreach ($version in @('23.0','37.0')) {
        $root = Join-Path $dir $version
        New-Item -ItemType Directory "$root\bin", "$root\bin64" -Force | Out-Null
        New-Item -Path "HKCU:\$key\BDS\$version" -Force | Out-Null
        New-ItemProperty "HKCU:\$key\BDS\$version" -Name RootDir -Value $root -Force | Out-Null
    }
    Run-Setup 'missing-bds' $false
    foreach ($version in @('23.0','37.0')) {
        foreach ($bin in @('bin','bin64')) { [IO.File]::WriteAllText((Join-Path $dir "$version\$bin\bds.exe"), 'existence fixture') }
    }
    Run-Setup 'missing-webview-no-consent' $false
    if (Test-Path $env:XMLDOC_TEST_RUNTIME_MARKER) { throw 'Runtime installer ran without consent' }
    Run-Setup 'webview-install-failure' $false @('/INSTALLWEBVIEW2=1')
    $cs = Join-Path $dir 'bds.cs'
    [IO.File]::WriteAllText($cs, 'class Program { static void Main() { System.Threading.Thread.Sleep(60000); } }')
    & "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe" /nologo /target:winexe "/out:$dir\bds.exe" $cs
    if ($LASTEXITCODE) { throw 'Process fixture compilation failed' }
    $fixture = Start-Process "$dir\bds.exe" -PassThru -WindowStyle Hidden
    $env:XMLDOC_TEST_BDS_PID = [string]$fixture.Id
    try { Run-Setup 'running-ide' $false }
    finally { if (!$fixture.HasExited) { Stop-Process -Id $fixture.Id }; $env:XMLDOC_TEST_BDS_PID = '0' }
    $old = Join-Path $dir 'previous\XmlDocPlugin290.bpl'
    New-Item -ItemType Directory (Split-Path $old) -Force | Out-Null
    [IO.File]::WriteAllText($old, 'previous package registration')
    $known = "HKCU:\$key\BDS\23.0\Known Packages"
    New-Item $known -Force | Out-Null
    New-ItemProperty $known -Name $old -Value 'Previous plugin' -Force | Out-Null
    $env:XMLDOC_TEST_RUNTIME_MODE = 'install'
    Run-Setup 'install' $true @('/INSTALLWEBVIEW2=1')
    if (!(Test-Path $env:XMLDOC_TEST_RUNTIME_MARKER)) { throw 'Approved runtime installer did not execute' }
    foreach ($t in @(
        @{Dir='rad12-x86';Version='23.0';Node='Known Packages';File='XmlDocPlugin290.bpl';Machine=0x14c},
        @{Dir='rad13-x86';Version='37.0';Node='Known Packages';File='XmlDocPlugin370.bpl';Machine=0x14c},
        @{Dir='rad13-x64';Version='37.0';Node='Known Packages x64';File='XmlDocPlugin370.bpl';Machine=0x8664})) {
        $file = Join-Path $app "$($t.Dir)\$($t.File)"
        $reg = "HKCU:\$key\BDS\$($t.Version)\$($t.Node)"
        if ((Get-ItemPropertyValue $reg -Name $file) -notlike 'XmlDoc Plugin*') { throw "Registration missing: $file" }
        if ((Get-FileHash $file).Hash -ne (Get-FileHash (Join-Path $PayloadDir "$($t.Dir)\$($t.File)")).Hash) { throw "Payload mismatch: $file" }
        foreach ($binary in @($file, (Join-Path $app "$($t.Dir)\WebView2Loader.dll"))) {
            $bytes = [IO.File]::ReadAllBytes($binary)
            $pe = [BitConverter]::ToInt32($bytes, 60)
            if ([BitConverter]::ToUInt16($bytes, $pe+4) -ne $t.Machine) { throw "Wrong binary architecture: $binary" }
        }
    }
    if (Test-Path "$app\rad12-x64") { throw 'Retired RAD Studio 12 x64 payload was installed' }
    if (Test-Path "HKCU:\$key\BDS\23.0\Known Packages x64") { throw 'Retired RAD Studio 12 x64 registration was created' }
    foreach ($entry in (Get-Content (Join-Path $app 'manifest.json') -Raw | ConvertFrom-Json)) {
        if ($entry.Path -eq 'MicrosoftEdgeWebview2Setup.exe') { continue }
        $installed = Join-Path $app $entry.Path
        if ((Get-FileHash $installed).Hash -ne $entry.SHA256) { throw "Installed manifest mismatch: $installed" }
    }
    if ((Get-Item $known).Property -contains $old) { throw 'Old registration was not replaced' }
    Test-InstalledCLI
    Run-Setup 'upgrade' $true
    Test-InstalledCLI
    $un = Start-Process "$app\unins000.exe" -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -PassThru -WindowStyle Hidden
    if (!$un.WaitForExit(60000) -or $un.ExitCode -ne 0) { throw 'Uninstall failed' }
    if ((Get-ItemPropertyValue $known -Name $old) -ne 'Previous plugin') { throw 'Previous registration was not restored' }
    if (Test-Path "$app\rad12-x86\XmlDocPlugin290.bpl") { throw 'Uninstall left the package behind' }
    if (Test-Path "$app\bin\XmlDocGen.exe") { throw 'Uninstall left the command-line generator behind' }
    $script:results += 'PASS: x64 CLI installation, generation, upgrade and removal'
    $script:results += 'PASS: all three registrations, PE architectures and installed hashes'
    $script:results += 'PASS: uninstall restores the previous package registration'
    $script:results | Tee-Object -FilePath (Join-Path $dir 'results.txt')
    Write-Output "Test evidence: $dir"
} finally {
    Remove-Item Env:\XMLDOC_TEST_BDS_PID,Env:\XMLDOC_TEST_RUNTIME_KEY,Env:\XMLDOC_TEST_RUNTIME_MARKER,Env:\XMLDOC_TEST_RUNTIME_MODE -ErrorAction SilentlyContinue
    # This unique test key is never the user's real IDE registration.
    if (Test-Path "HKCU:\$key") { Remove-Item -LiteralPath "HKCU:\$key" -Recurse -Force }
}
