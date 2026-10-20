param([ValidateSet('both','preview','direct')][string]$RealAIMode='both',[string]$AIReplayResponse='',[ValidateRange(0,300000)][int]$AITimeoutMs=0,[switch]$RealAI,[switch]$AIOnly,[ValidateSet('','save','reload')][string]$MarkerAudit='', [string]$LargeProject='', [string]$LargeSource='', [string]$EvidenceDir = "$env:LOCALAPPDATA\XmlDocPlugin\E2E\$([guid]::NewGuid())",[switch]$SkipBuild,[switch]$Installed,[switch]$GroupOnly,[switch]$ThemesOnly,[switch]$DiagnosticsOnly,[ValidateRange(0,5000)][int]$BenchmarkModules=0,
 [string]$InstallRoot="$env:LOCALAPPDATA\Programs\XmlDocPlugin",
 [string]$InstalledDcpRoot="$env:LOCALAPPDATA\XmlDocPlugin\Installer\intermediate",
 [ValidateSet('rad12-x86','rad13-x86','rad13-x64')][string[]]$Targets=@('rad12-x86','rad13-x86','rad13-x64'),[string]$Rad12='D:\Embarcadero RAD Studio\23.0',[string]$Rad13='D:\Embarcadero RAD Studio\37.0')
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$EvidenceDir=[IO.Path]::GetFullPath($EvidenceDir)
if(Test-Path -LiteralPath $EvidenceDir){throw "Use a fresh evidence directory to exclude stale exports: $EvidenceDir"}
New-Item -ItemType Directory $EvidenceDir | Out-Null
$build=Join-Path $env:LOCALAPPDATA 'XmlDocPlugin\Improvements1'
if($Installed){$build=[IO.Path]::GetFullPath($InstallRoot)}
function Test-Export([string]$Output){
 & python tests/Validate-DocExport.py $Output --project XmlDocE2E
 if($LASTEXITCODE){throw "Export links or resources failed: $Output"}
 & tests/Validate-HMXP.ps1 "$Output\hmxp\XmlDocE2E.hmxp"
 & python tests/e2e/Validate-WorkbenchExport.py $Output
 if($LASTEXITCODE){throw "Export grouping or numeric filenames failed: $Output"}
}
$savedEnvironment=@{}
foreach($name in 'XMLDOC_E2E_REAL_MODE','XMLDOC_E2E_AI_TIMEOUT','XMLDOC_E2E_REAL_AI','XMLDOC_AI_CONFIG','XMLDOC_E2E_AI_ONLY','XMLDOC_E2E_MARKER_PHASE','XMLDOC_DRAFT_DIR','XMLDOC_E2E_FIXTURE','XMLDOC_E2E_JS','XMLDOC_E2E_LOG','XMLDOC_E2E_VERSION','XMLDOC_E2E_GROUP_ONLY','XMLDOC_E2E_THEMES_ONLY','XMLDOC_E2E_DIAGNOSTICS_ONLY','XMLDOC_E2E_BENCHMARK_MODULES','XMLDOC_E2E_LARGE_PROJECT','XMLDOC_E2E_LARGE_SOURCE'){$savedEnvironment[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
$savedBounds=@{}
$boundsKey=[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\XmlDocPlugin\DocExplorer')
try {foreach($name in 'Left','Top','Width','Height'){
 if($boundsKey -and $boundsKey.GetValueNames() -contains $name){$savedBounds[$name]=$boundsKey.GetValue($name)}
}} finally {if($boundsKey){$boundsKey.Dispose()}}
Push-Location $repo
try {
 $env:XMLDOC_E2E_REAL_AI=if($RealAI){'1'}else{''}
 $env:XMLDOC_E2E_AI_TIMEOUT=$AITimeoutMs.ToString();$env:XMLDOC_E2E_REAL_MODE=$RealAIMode
 if($RealAI){$AIOnly=$true}
 $env:XMLDOC_E2E_AI_ONLY=if($AIOnly){'1'}else{''}
 $env:XMLDOC_E2E_MARKER_PHASE=$MarkerAudit
 $env:XMLDOC_E2E_LARGE_PROJECT=$LargeProject;$env:XMLDOC_E2E_LARGE_SOURCE=$LargeSource
 $env:XMLDOC_E2E_GROUP_ONLY=if($GroupOnly){'1'}else{''}
 $env:XMLDOC_E2E_THEMES_ONLY=if($ThemesOnly){'1'}else{''}
 $env:XMLDOC_E2E_DIAGNOSTICS_ONLY=if($DiagnosticsOnly){'1'}else{''}
 $env:XMLDOC_E2E_BENCHMARK_MODULES=$BenchmarkModules.ToString()
 $env:XMLDOC_E2E_VERSION=(Get-Content (Join-Path $repo 'installer\Version.txt') -Raw).Trim()
 if($Installed){
  $manifest=Get-Content (Join-Path $build 'manifest.json') -Raw | ConvertFrom-Json
  foreach($entry in $manifest){
   # The bootstrapper is embedded in Setup and deliberately not installed.
   if($entry.Path -eq 'MicrosoftEdgeWebview2Setup.exe'){continue}
   if(($entry.Path -notlike 'bin\*') -and !(@($Targets | Where-Object {$entry.Path.StartsWith($_+'\')}).Count)){continue}
   if((Get-FileHash (Join-Path $build $entry.Path)).Hash -ne $entry.SHA256){throw "Installed payload mismatch: $($entry.Path)"}
  }
  $cli=Join-Path $build 'bin\XmlDocGen.exe'
  $bytes=[IO.File]::ReadAllBytes($cli);$pe=[BitConverter]::ToInt32($bytes,60)
  if([BitConverter]::ToUInt16($bytes,$pe+4) -ne 0x8664){throw 'Installed CLI must be x64'}
  if(!$MarkerAudit -and !$AIOnly){
  & $cli -p "$PSScriptRoot\DocumentationWorkbench\XmlDocE2E.dproj" -o "$EvidenceDir\cli" -f html,chm,md,json,hmxp,mkdocs,docusaurus,vitepress -t XmlDocE2E --site-name XmlDocE2E --numeric-file-names --coverage *> "$EvidenceDir\cli.log"
  if($LASTEXITCODE){throw "Installed CLI generation failed: $EvidenceDir\cli.log"}
  Test-Export "$EvidenceDir\cli"
  }
 }
 foreach($t in @(
  @{Name='rad12-x86';Version='23.0';Platform='Win32';Compiler='dcc32';Bin='bin';Suffix='290';Node='Known Packages'},
  @{Name='rad13-x86';Version='37.0';Platform='Win32';Compiler='dcc32';Bin='bin';Suffix='370';Node='Known Packages'},
  @{Name='rad13-x64';Version='37.0';Platform='Win64';Compiler='dcc64';Bin='bin64';Suffix='370';Node='Known Packages x64'})) {
  if($Targets -notcontains $t.Name){continue}
  $rad=if($t.Version -eq '23.0'){$Rad12}else{$Rad13}
  $out=Join-Path $EvidenceDir $t.Name;New-Item -ItemType Directory -Force $out | Out-Null; if($RealAI -and $AIReplayResponse){Copy-Item -LiteralPath $AIReplayResponse -Destination (Join-Path $out 'html-baseline.response.json')}
  $bplDir=Join-Path $build $t.Name;$dcp=Join-Path $build "dcp\$($t.Name)"
  if($Installed){
   $dcp=Join-Path $InstalledDcpRoot $t.Name
   if(!(Test-Path "$dcp\XmlDocPlugin.dcp")){throw "Matching package DCP required to compile the probe: $dcp"}
   $registered=Get-Item "HKCU:\Software\Embarcadero\BDS\$($t.Version)\$($t.Node)"
   if(!$registered.GetValue("$bplDir\XmlDocPlugin$($t.Suffix).bpl")){throw "Installed package is not registered: $($t.Name)"}
  }
  if(!$SkipBuild -and !$Installed){
   if($t.Version -eq '23.0') { & .\build-delphi12.ps1 -Bds $rad -OutputDir $bplDir -DcpOutputDir $dcp *> "$out\plugin-build.log" }
   else {
    New-Item -ItemType Directory -Force $bplDir,$dcp | Out-Null
    & cmd.exe /d /c "`"$rad\bin\rsvars.bat`" && msbuild src\Packages\13\XmlDocPlugin.dproj /t:Rebuild /p:Config=Release /p:Platform=$($t.Platform) `"/p:DCC_BplOutput=$bplDir`" `"/p:DCC_DcpOutput=$dcp`" /v:minimal" *> "$out\plugin-build.log"
    if($LASTEXITCODE){throw 'Plugin build failed'}
    $arch=if($t.Platform -eq 'Win32'){'x86'}else{'x64'}
    Copy-Item "$env:LOCALAPPDATA\XmlDocPlugin\Build\WebView2-1.0.2045.28\sdk\build\native\$arch\WebView2Loader.dll" $bplDir -Force
   }
  }
  $fixture=Join-Path $out 'fixture';Copy-Item (Join-Path $PSScriptRoot 'DocumentationWorkbench') $fixture -Recurse
  $fixtureBin=Join-Path $out 'fixture-bin';New-Item -ItemType Directory -Force $fixtureBin | Out-Null
  & cmd.exe /d /c "`"$rad\bin\rsvars.bat`" && msbuild `"$fixture\XmlDocE2E.dproj`" /t:Rebuild /p:Platform=$($t.Platform) /p:Config=Debug `"/p:XMLDOC_E2E_OUT=$fixtureBin`" /v:minimal" *> "$out\fixture-build.log"
  if($LASTEXITCODE){throw "Fixture build failed: $out\fixture-build.log"}
  & "$fixtureBin\XmlDocE2E.exe" *> "$out\fixture-run.log";if($LASTEXITCODE){throw 'Fixture runtime failed'}
  & cmd.exe /d /c "`"$rad\bin\rsvars.bat`" && $($t.Compiler) -B --codepage:65001 -NSSystem;System.Win;Winapi;Vcl `"-U$dcp`" `"-LE$out`" `"-LN$out`" `"-N0$out`" `"$PSScriptRoot\WorkbenchProbe.dpk`"" *> "$out\probe-build.log"
  if($LASTEXITCODE){throw "Probe build failed: $out\probe-build.log"}
  $profile='XmlDocE2E'+[guid]::NewGuid().ToString('N');$profileRoot="HKCU:\Software\Embarcadero\$profile"
  reg copy "HKCU\Software\Embarcadero\BDS\$($t.Version)" "HKCU\Software\Embarcadero\$profile\$($t.Version)" /s /f | Out-Null
  foreach($node in 'Known Packages','Known Packages x64','Experts'){
   $key="$profileRoot\$($t.Version)\$node"
   if(Test-Path $key){(Get-Item $key).Property | Where-Object {$_ -notlike '$(BDSBIN)\*' -and $_ -notlike '$(BDS)\*'} | ForEach-Object {Remove-ItemProperty $key -Name $_}}
  }
  # Exclude the online Welcome Page components from isolated test profiles. Its
  # background request can finish after the stock feed package has unloaded.
  foreach($node in 'Known IDE Packages','Known IDE Packages x64'){
   $feedKey="$profileRoot\$($t.Version)\$node"
   if(Test-Path $feedKey){(Get-Item $feedKey).Property | Where-Object {$_ -like '*WelcomePage*'} | ForEach-Object {Remove-ItemProperty $feedKey -Name $_}}
  }
  $key="$profileRoot\$($t.Version)\$($t.Node)";New-Item $key -Force | Out-Null
  New-ItemProperty $key -Name "$bplDir\XmlDocPlugin$($t.Suffix).bpl" -Value 'XmlDocPlugin E2E' -Force | Out-Null
  New-ItemProperty $key -Name "$out\WorkbenchProbe.bpl" -Value 'Documentation workbench E2E probe' -Force | Out-Null
  if($AIOnly){$env:XMLDOC_AI_CONFIG=Join-Path $out 'ai.json'}
  $env:XMLDOC_DRAFT_DIR=Join-Path $out 'drafts';$env:XMLDOC_E2E_FIXTURE=$fixture;$env:XMLDOC_E2E_JS=Join-Path $PSScriptRoot $(if($MarkerAudit){'MarkerAuditProbe.js'}else{'WorkbenchProbe.js'});$env:XMLDOC_E2E_LOG="$out\runtime.log"
  $p=Start-Process "$rad\$($t.Bin)\bds.exe" -ArgumentList "-r$profile",'-ns' -PassThru -WindowStyle Hidden
  # Allow cold IDE startup and repeated generation/quality-gate checks.
  for($waitAttempt=0;($waitAttempt -lt $(if($RealAI){18}else{6})) -and !$p.HasExited;$waitAttempt++){$null=$p.WaitForExit(50000);if($RealAI -and !$p.HasExited){Write-Host "$($t.Name) real AI ${RealAIMode}: waiting $((1+$waitAttempt)*50)s"}}
  if(!$p.HasExited){throw "E2E timeout: $($t.Name), test-owned IDE PID $($p.Id)"}
  Get-Content "$out\runtime.log"
  if($p.ExitCode -ne 0 -or !(Select-String -LiteralPath "$out\runtime.log" -Pattern '^PASS$' -Quiet)){throw "E2E failed: $($t.Name), process exit $($p.ExitCode)"}
  "PASS IDE exit 0: $($t.Name)"
  if(($BenchmarkModules -eq 0) -and !$DiagnosticsOnly -and !$MarkerAudit -and !$AIOnly){Test-Export "$out\documentation"}
  if($Installed -and !$DiagnosticsOnly -and !$MarkerAudit -and !$AIOnly -and (Get-Content "$out\documentation\topic-map.json" -Raw) -ne (Get-Content "$EvidenceDir\cli\topic-map.json" -Raw)){throw "IDE and CLI numeric topic mappings differ: $($t.Name)"}
  # Keep isolated profile and copied sources for reproducible failure analysis.
 }
 if($RealAI){$providerFailures=@(Get-ChildItem -LiteralPath $EvidenceDir -Recurse -Filter 'provider-failure.observation.json');if($providerFailures.Count){throw "Real provider verification failed for $($providerFailures.Count) target(s); IDE workflow results are retained in $EvidenceDir"}}
} finally {
 Pop-Location
 foreach($name in $savedEnvironment.Keys){[Environment]::SetEnvironmentVariable($name,$savedEnvironment[$name],'Process')}
 $boundsKey=[Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\XmlDocPlugin\DocExplorer')
 try {foreach($name in 'Left','Top','Width','Height'){
  if($savedBounds.ContainsKey($name)){$boundsKey.SetValue($name,$savedBounds[$name],[Microsoft.Win32.RegistryValueKind]::DWord)}else{$boundsKey.DeleteValue($name,$false)}
 }} finally {$boundsKey.Dispose()}
}
Write-Host "E2E evidence: $EvidenceDir"
