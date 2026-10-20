param([string]$Bds='D:\Embarcadero RAD Studio\23.0',[ValidateSet('dcc32','dcc64')][string]$Compiler='dcc32')
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot;$dir=Join-Path $env:LOCALAPPDATA ('XmlDocPlugin\AITransportTests\'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory $dir | Out-Null
$server=Start-Process python -ArgumentList @("`"$PSScriptRoot\AITransportServer.py`"","`"$dir\port.txt`"") -WindowStyle Hidden -PassThru
try{
 for($i=0;!(Test-Path "$dir\port.txt") -and $i -lt 100;$i++){Start-Sleep -Milliseconds 50}
 $port=(Get-Content "$dir\port.txt" -Raw).Trim()
 & cmd.exe /d /c "`"$Bds\bin\rsvars.bat`" && $Compiler -B --codepage:65001 -NSSystem;System.Win;Winapi;Vcl `"-U$repo\src\Core`" `"-E$dir`" `"-N0$dir`" `"$PSScriptRoot\AITransportProbe.dpr`"" *> "$dir\build.log"
 if($LASTEXITCODE){Get-Content "$dir\build.log" -Tail 10;throw 'Probe compilation failed'}
 & "$dir\AITransportProbe.exe" $port | Tee-Object "$dir\run.log";if($LASTEXITCODE){throw 'HTTP transport verification failed'}
}finally{if(!$server.HasExited){Stop-Process -Id $server.Id}}
Write-Output "Transport evidence: $dir"
