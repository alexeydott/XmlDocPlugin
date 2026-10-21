param([ValidateSet('11','12','13')][string]$Version='12',
 [ValidateSet('Light','Dark')][string]$Theme='Dark',
 [ValidateSet('Classic','Current')][string]$Backend='Current',
 [Parameter(Mandatory)][string]$BuildRoot,[Parameter(Mandatory)][string]$EvidenceDir,
 [string]$LongFixture="$PSScriptRoot\..\fixtures\HelpInsight\LongHintParagraphs.dpr",
 [string]$ParameterFixture="$PSScriptRoot\..\fixtures\HelpInsight\HelpInsightCssProbe.dpr")
$ErrorActionPreference='Stop'
if(Get-Process bds -ErrorAction SilentlyContinue){throw 'Close RAD Studio before testing shared native Help Insight templates.'}
$rad=if($Version -eq '11'){'D:\Embarcadero RAD Studio\22.0'}elseif($Version -eq '12'){'D:\Embarcadero RAD Studio\23.0'}else{'D:\Embarcadero RAD Studio\37.0'}
$bdsVersion=if($Version -eq '11'){'22.0'}elseif($Version -eq '12'){'23.0'}else{'37.0'}
$suffix=if($Version -eq '11'){'280'}elseif($Version -eq '12'){'290'}else{'370'}
$target="rad$Version-x86";$bpl=Join-Path $BuildRoot $target;$dcp=Join-Path $BuildRoot "dcp\$target"
if(Test-Path $EvidenceDir){throw 'Use a new evidence directory'}
New-Item -ItemType Directory $EvidenceDir|Out-Null
$EvidenceDir=[IO.Path]::GetFullPath($EvidenceDir)
Copy-Item -LiteralPath $LongFixture -Destination "$EvidenceDir\LongHintParagraphs.dpr"
$long=[IO.File]::ReadAllText("$EvidenceDir\LongHintParagraphs.dpr",[Text.Encoding]::UTF8)
$long=$long.Replace('</remarks>','<para>Additional paragraph with <b>bold</b> text and a <see cref="TMapDocumentation"/> reference.<br/>Second line.</para><list type="bullet"><item><description>First item</description></item><item><description>Second item</description></item></list><list type="table"><listheader><term>Option</term><description>Meaning</description></listheader><item><term>Clipping</term><description>Restricts output to the viewport.</description></item></list><note type="caller">Provide a valid rendering context.</note></remarks>')
[IO.File]::WriteAllText("$EvidenceDir\LongHintParagraphs.dpr",$long,[Text.UTF8Encoding]::new($true))
Copy-Item -LiteralPath $ParameterFixture -Destination "$EvidenceDir\HelpInsightCssProbe.dpr"
Copy-Item "$rad\ObjRepos\HelpInsight.css" "$EvidenceDir\original.css"
Copy-Item "$rad\ObjRepos\en\HelpInsight.xsl" "$EvidenceDir\original.xsl"
Copy-Item "$rad\ObjRepos\HelpInsight.xsl" "$EvidenceDir\original-root.xsl"
& cmd.exe /d /c "`"$rad\bin\rsvars.bat`" && dcc32 -B --codepage:65001 -NSSystem;System.Win;Winapi;Vcl `"-U$dcp`" `"-LE$EvidenceDir`" `"-LN$EvidenceDir`" `"-N0$EvidenceDir`" `"$PSScriptRoot\HelpInsightProbe.dpk`"" *> "$EvidenceDir\build.log"
if($LASTEXITCODE){throw 'Help Insight probe failed to compile'}
$profile='XmlDocHint'+[guid]::NewGuid().ToString('N');$key="HKCU:\Software\Embarcadero\$profile\$bdsVersion"
reg copy "HKCU\Software\Embarcadero\BDS\$bdsVersion" "HKCU\Software\Embarcadero\$profile\$bdsVersion" /s /f | Out-Null
foreach($node in 'Known Packages','Known Packages x64','Experts','Known IDE Packages','Known IDE Packages x64'){
 $path="$key\$node";if(Test-Path $path){(Get-Item $path).Property|Where-Object {($_ -notlike '$(BDSBIN)\*' -and $_ -notlike '$(BDS)\*') -or $_ -like '*WelcomePage*'}|ForEach-Object {Remove-ItemProperty $path -Name $_}}
}
New-Item "$key\Known Packages" -Force|Out-Null
New-ItemProperty "$key\Known Packages" -Name "$bpl\XmlDocPlugin$suffix.bpl" -Value 'XmlDocPlugin Help Insight test' -Force|Out-Null
New-ItemProperty "$key\Known Packages" -Name "$EvidenceDir\HelpInsightProbe.bpl" -Value 'Help Insight visual probe' -Force|Out-Null
New-ItemProperty "$key\Theme" -Name Theme -Value $Theme -Force|Out-Null
New-ItemProperty "$key\Theme" -Name ToggleTheme -PropertyType DWord -Value 0 -Force|Out-Null
New-ItemProperty "$key\Theme" -Name Enabled -PropertyType DWord -Value 1 -Force|Out-Null
if($Backend -eq 'Classic'){
 $sourceOptions="$key\Editor\Source Options\Borland.EditOptions.Pascal"
 if(!(Test-Path $sourceOptions)){New-Item $sourceOptions -Force|Out-Null}
 New-ItemProperty $sourceOptions -Name 'Insight Manager' -Value 'Borland.CodeInsight.Pascal' -Force|Out-Null
}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
& cmd.exe /d /c "`"$rad\bin\rsvars.bat`" && dcc32 -B --codepage:65001 -NSSystem;System.Win;Winapi;Vcl `"-U$repo\src\Plugin;$repo\src\Core`" `"-E$EvidenceDir`" `"-N0$EvidenceDir`" `"$repo\tests\HelpInsightRender.dpr`"" *> "$EvidenceDir\renderer-build.log"
if($LASTEXITCODE){throw 'Renderer helper compilation failed'}
& "$EvidenceDir\HelpInsightRender.exe" apply $Theme "$rad\ObjRepos\HelpInsight.css" "$rad\ObjRepos\en\HelpInsight.xsl"
if($LASTEXITCODE){throw 'Template staging failed'}
$saved=$env:XMLDOC_HINT_ROOT
try{
 $env:XMLDOC_HINT_ROOT=$EvidenceDir
 $p=Start-Process "$rad\bin\bds.exe" -ArgumentList "-r$profile",'-ns' -WindowStyle Normal -PassThru
 @{pid=$p.Id;profile=$profile;root=$EvidenceDir;theme=$Theme;version=$Version;backend=$Backend}|ConvertTo-Json|Set-Content "$EvidenceDir\process.json"
 Write-Host "Visual test IDE PID $($p.Id); commands: $EvidenceDir\command.json"
}finally{$env:XMLDOC_HINT_ROOT=$saved}

