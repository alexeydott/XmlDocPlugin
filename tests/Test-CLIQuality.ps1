param([Parameter(Mandatory)][string]$CLI,
 [string]$EvidenceDir="$env:LOCALAPPDATA\XmlDocPlugin\CLIQuality\$([guid]::NewGuid().ToString('N'))")
$ErrorActionPreference='Stop'
$CLI=[IO.Path]::GetFullPath($CLI)
if(Test-Path -LiteralPath $EvidenceDir){throw 'Use a fresh evidence directory'}
$source=Join-Path $EvidenceDir 'source'
New-Item -ItemType Directory $source | Out-Null
$unit=Join-Path $source 'Widgets.pas'
function Invoke-Quality([string]$Name,[string[]]$Options,[int]$Expected){
 $output=Join-Path $EvidenceDir $Name
 & $CLI -d $source -o $output -f json @Options *> "$EvidenceDir\$Name.log"
 if($LASTEXITCODE -ne $Expected){throw "$Name returned $LASTEXITCODE, expected $Expected; see $EvidenceDir\$Name.log"}
}
foreach($prefix in 'FIXME: ','Описание: ','待补充：','[draft].* '){
 $name='prefix-'+[Array]::IndexOf(@('FIXME: ','Описание: ','待补充：','[draft].* '),$prefix)
 [IO.File]::WriteAllText($unit,"/// <summary>Widget declarations.</summary>`r`nunit Widgets;`r`ninterface`r`ntype`r`n/// <summary>${prefix}TWidget class description</summary>`r`nTWidget=class end;`r`nimplementation`r`nend.",[Text.UTF8Encoding]::new($true))
 Invoke-Quality "$name-presence" @('--placeholder-prefix',$prefix,'--coverage-min','100') 0
 Invoke-Quality "$name-ready" @('--placeholder-prefix',$prefix,'--ready-min','100') 1
 Invoke-Quality "$name-check" @('--placeholder-prefix',$prefix,'--check') 3
 $diagnostics=Get-Content "$EvidenceDir\$name-check\diagnostics.json" -Raw
 if($diagnostics -notmatch 'XD008'){throw "Missing unfinished-placeholder diagnostic: $name"}
}
foreach($marker in 'ДОРАБОТАТЬ:','待完善：','작성 필요:','要修正：','CUSTOM:'){
 [IO.File]::WriteAllText($unit,"/// <summary>Widget declarations.</summary>`r`nunit Widgets; interface type`r`n/// <summary>${marker} unfinished</summary>`r`nTWidget=class end; implementation end.",[Text.UTF8Encoding]::new($true))
 $name='marker-'+[Array]::IndexOf(@('ДОРАБОТАТЬ:','待完善：','작성 필요:','要修正：','CUSTOM:'),$marker)
 $options=@('--placeholder-prefix','OTHER:','--check');if($marker -eq 'CUSTOM:'){$options+=@('--placeholder-marker','ANOTHER:','--placeholder-marker',$marker)}
 Invoke-Quality $name $options 3
 if((Get-Content "$EvidenceDir\$name\diagnostics.json" -Raw) -notmatch 'XD008'){throw "Missing multilingual diagnostic: $marker"}
}
[IO.File]::WriteAllText($unit,"/// <summary>Widget declarations.</summary>`r`nunit Widgets; interface type`r`n/// <summary>Represents a widget.</summary>`r`nTWidget=class end; implementation end.",[Text.UTF8Encoding]::new($true))
Invoke-Quality 'complete' @('--coverage-min','100','--ready-min','100') 0
Invoke-Quality 'invalid-ready' @('--ready-min','101') 2
Invoke-Quality 'invalid-presence' @('--coverage-min','invalid') 2
Invoke-Quality 'missing-marker' @('--placeholder-marker') 2
Invoke-Quality 'missing-ready' @('--ready-min') 2
Invoke-Quality 'missing-presence' @('--coverage-min') 2
Write-Output "PASS CLI presence/readiness gates, custom placeholder diagnostics and argument validation: $EvidenceDir"
