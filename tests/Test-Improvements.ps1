param(
 [string]$EvidenceDir="$env:LOCALAPPDATA\XmlDocPlugin\WorkbenchTests\$([guid]::NewGuid())",
 [string]$Rad12='D:\Embarcadero RAD Studio\23.0',
 [string]$Rad13='D:\Embarcadero RAD Studio\37.0',
 [switch]$SkipIDE
)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
New-Item -ItemType Directory -Force $EvidenceDir | Out-Null
Push-Location $repo
try {
 & npm test --prefix web *> "$EvidenceDir\web-tests.log"
 if($LASTEXITCODE){throw 'Browser unit and fuzz tests failed'}
 & .\test-delphi12.ps1 -Bds $Rad12 *> "$EvidenceDir\rad12-tests.log"
 & .\test-delphi12.ps1 -Bds $Rad13 *> "$EvidenceDir\rad13-tests.log"
 & .\build-cli.ps1 -Bds $Rad13 -Platform Win64 -OutputDir "$EvidenceDir\cli" *> "$EvidenceDir\cli-build.log"
 $cli="$EvidenceDir\cli\Win64\XmlDocGen.exe"
 $fixture=Join-Path $PSScriptRoot 'e2e\DocumentationWorkbench\XmlDocE2E.dproj'
 $output="$EvidenceDir\documentation"
 & $cli -p $fixture -o $output -f html,chm,md,json,hmxp,mkdocs,docusaurus,vitepress -t XmlDocE2E --site-name XmlDocE2E --numeric-file-names --coverage --check --write-baseline "$EvidenceDir\baseline.json" *> "$EvidenceDir\generate.log"
 if($LASTEXITCODE){throw 'Generation failed'}
 & python tests/Validate-DocExport.py $output --project XmlDocE2E
 if($LASTEXITCODE){throw 'Generated local links or project resources are invalid'}
 & tests/Validate-HMXP.ps1 "$output\hmxp\XmlDocE2E.hmxp"
 & $cli -p $fixture -o $output -f json --check --baseline "$EvidenceDir\baseline.json" *> "$EvidenceDir\baseline.log"
 if($LASTEXITCODE){throw 'Unchanged baseline was rejected'}
 $changed=Join-Path $EvidenceDir 'changed-project'
 Copy-Item (Split-Path $fixture) $changed -Recurse
 $unit=Join-Path $changed 'Units\Workbench.Sample.pas'
 $text=[IO.File]::ReadAllText($unit).Replace('Options:Integer','Options:NativeInt')
 [IO.File]::WriteAllText($unit,$text,[Text.UTF8Encoding]::new($true))
 & $cli -p "$changed\XmlDocE2E.dproj" -o "$EvidenceDir\changed-documentation" -f json --check --baseline "$EvidenceDir\baseline.json" *> "$EvidenceDir\changed-baseline.log"
 if($LASTEXITCODE -ne 3){throw 'Changed public API was not rejected'}
 $diagnostics=Get-Content "$EvidenceDir\changed-documentation\diagnostics.json" -Raw | ConvertFrom-Json
 if(!($diagnostics.issues | Where-Object code -eq XD011)){throw 'Public API change diagnostic is missing'}
 if(!$SkipIDE){& tests/e2e/Test-E2E.ps1 -Rad12 $Rad12 -Rad13 $Rad13 -EvidenceDir "$EvidenceDir\ide"}
 Write-Host "PASS. Evidence: $EvidenceDir"
} finally {Pop-Location}
