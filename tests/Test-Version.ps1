param()
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
$temp=Join-Path $env:LOCALAPPDATA ('XmlDocPlugin\VersionTests\'+[guid]::NewGuid())
New-Item -ItemType Directory (Join-Path $temp 'installer') -Force | Out-Null
Copy-Item (Join-Path $repo 'build-version.ps1') $temp
$versionFile=Join-Path $temp 'installer\Version.txt'
[IO.File]::WriteAllText($versionFile,'1.2.3.4')
$script=Join-Path $temp 'build-version.ps1'
if((& $script) -ne '1.2.3.4'){throw 'Default shared version mismatch'}
if((& $script -IncrementVersion) -ne '1.2.3.5'){throw 'Increment mismatch'}
if(([IO.File]::ReadAllText($versionFile)).Trim() -ne '1.2.3.5'){throw 'Increment was not persisted'}
if((& $script -Version '2.3.4') -ne '2.3.4.0'){throw 'Three-part normalization mismatch'}
foreach($invalid in @('1.2','1.2.3.4.5','1.2.-1.4','1.2.3.65536','version')){
 $rejected=$false;try{& $script -Version $invalid | Out-Null}catch{$rejected=$true}
 if(!$rejected){throw "Invalid version accepted: $invalid"}
}
Write-Output 'PASS shared version reading, persisted increments, normalization and invalid input rejection'
