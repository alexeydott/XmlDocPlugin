param(
 [Parameter(Mandatory)][string]$Source,
 [Parameter(Mandatory)][string]$Project,
 [string]$Bds='D:\Embarcadero RAD Studio\23.0',
 [string]$EvidenceDir="$env:LOCALAPPDATA\XmlDocPlugin-work\parser-latency-$([guid]::NewGuid().ToString('N'))"
)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$Source=(Resolve-Path -LiteralPath $Source).Path
$Project=(Resolve-Path -LiteralPath $Project).Path
New-Item -ItemType Directory -Force $EvidenceDir | Out-Null
$before=(Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
Push-Location $repo
try {
 & cmd.exe /d /c "`"$Bds\bin\rsvars.bat`" && dcc64 -B --codepage:65001 -NSSystem;System.Win;Winapi;Vcl -Ivendor\DelphiAST\Source\SimpleParser `"-Usrc\Core;vendor\DelphiAST\Source;vendor\DelphiAST\Source\SimpleParser`" `"-E$EvidenceDir`" `"-N0$EvidenceDir`" tests\perf\ParserLatency.dpr" *> "$EvidenceDir\build.log"
 if($LASTEXITCODE){throw "Latency probe compilation failed: $EvidenceDir\build.log"}
 & "$EvidenceDir\ParserLatency.exe" $Source $Project | Tee-Object "$EvidenceDir\result.log"
 if($LASTEXITCODE){throw 'Latency probe failed'}
 if((Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash -ne $before){throw 'Input source changed'}
} finally {Pop-Location}
