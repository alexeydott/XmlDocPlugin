param([string]$Bds='D:\Embarcadero RAD Studio\23.0',[string]$EvidenceDir="$env:LOCALAPPDATA\XmlDocPlugin\ToonTests\$([guid]::NewGuid())")
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceDir|Out-Null
Push-Location (Join-Path $PSScriptRoot '..')
try {
 & node tests/Validate-AIToon.mjs generate "$EvidenceDir\input.json"
 if($LASTEXITCODE){throw 'TOON fixture creation failed; run npm ci --prefix web'}
 foreach($compiler in 'dcc32','dcc64'){
  $out=Join-Path $EvidenceDir $compiler;New-Item -ItemType Directory -Force $out|Out-Null
  & cmd.exe /d /c "`"$Bds\bin\rsvars.bat`" && $compiler -B --codepage:65001 -NSSystem `"-Usrc\Core`" `"-E$out`" `"-N0$out`" tests\AIToonProbe.dpr" *> "$out\build.log"
  if($LASTEXITCODE){throw "TOON compilation failed: $out\build.log"}
  & "$out\AIToonProbe.exe" "$EvidenceDir\input.json" "$out\encoded.json"
  if($LASTEXITCODE){throw 'Native TOON encoding failed'}
  & node tests/Validate-AIToon.mjs verify "$out\encoded.json"
  if($LASTEXITCODE){throw 'Native TOON reference round-trip failed'}
 }
}finally{Pop-Location}
