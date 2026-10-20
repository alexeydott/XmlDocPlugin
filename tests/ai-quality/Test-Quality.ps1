param(
 [string]$EvidenceDir="$env:LOCALAPPDATA\XmlDocPlugin\AIQuality\$([guid]::NewGuid().ToString('N'))",
 [string]$ProfileName='', [switch]$RunLive,
 [ValidateSet('built-in','fact-review')][string[]]$Variants=@('built-in','fact-review'),
 [string[]]$Bds=@('D:\Embarcadero RAD Studio\22.0','D:\Embarcadero RAD Studio\23.0','D:\Embarcadero RAD Studio\37.0')
)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$EvidenceDir=[IO.Path]::GetFullPath($EvidenceDir)
if($EvidenceDir.StartsWith($repo+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or $EvidenceDir -eq $repo){throw 'Keep quality responses and requests outside Git'}
if(Test-Path -LiteralPath $EvidenceDir){throw 'Use a fresh evidence directory'}
if($RunLive -and !$ProfileName){throw 'Explicit ProfileName is required for live requests'}
New-Item -ItemType Directory $EvidenceDir | Out-Null
Push-Location $repo
try {
 & python tests/ai-quality/TestQuality.py
 if($LASTEXITCODE){throw 'Quality evaluator tests failed'}
 foreach($rad in $Bds){foreach($arch in '32','64'){
  $out=Join-Path $EvidenceDir ((Split-Path $rad -Leaf)+'-'+$arch);New-Item -ItemType Directory $out | Out-Null
  & cmd /d /c "`"$rad\bin\rsvars.bat`" && dcc$arch -B --codepage:65001 -NSSystem `"-E$out`" `"-N0$out`" tests\ai-quality\QualitySmoke.dpr" *> "$out\build.log"
  if($LASTEXITCODE){throw "Corpus compilation failed: $out"}
  & "$out\QualitySmoke.exe"
  if($LASTEXITCODE){throw "Corpus runtime failed: $out"}
 }}
 if($RunLive){
  $rad=$Bds[-1];$out=Join-Path $EvidenceDir 'runner';New-Item -ItemType Directory $out | Out-Null
  $paths="src\Core;vendor\DelphiAST\Source;vendor\DelphiAST\Source\SimpleParser"
  & cmd /d /c "`"$rad\bin\rsvars.bat`" && dcc64 -B --codepage:65001 -NSSystem;System.Win;Winapi -Ivendor\DelphiAST\Source\SimpleParser `"-U$paths`" `"-E$out`" `"-N0$out`" tests\ai-quality\RunQuality.dpr" *> "$out\build.log"
  if($LASTEXITCODE){throw 'Quality runner compilation failed'}
  $responses=@();$failed=$false
  foreach($variant in $Variants){
   & "$out\RunQuality.exe" $ProfileName tests\ai-quality\corpus.json "$EvidenceDir\$variant" $variant *> "$EvidenceDir\$variant.log"
   if($LASTEXITCODE){$failed=$true}
   $responses+=Join-Path "$EvidenceDir\$variant" 'responses.json'
  }
  & python tests/ai-quality/Compare.py @responses --out "$EvidenceDir\comparison.json"
  if($LASTEXITCODE){throw 'Quality comparison failed'}
  if($failed){throw 'A live quality request failed; see retained responses and logs'}
 }
 Write-Host "PASS quality corpus and evaluator; evidence: $EvidenceDir"
} finally {Pop-Location}
