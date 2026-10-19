param(
    [string]$Bds = 'D:\Embarcadero RAD Studio\23.0',
    [string]$WorkDir = "$env:LOCALAPPDATA\XmlDocPlugin\ApiDocs"
)
$ErrorActionPreference = 'Stop'
$WorkDir = [IO.Path]::GetFullPath($WorkDir)
$repo = [IO.Path]::GetFullPath($PSScriptRoot)
if (($WorkDir -eq $repo) -or $WorkDir.StartsWith($repo + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'API documentation build files must be outside the checkout.'
}
# Each run uses a clean staging directory; generated files are published only after validation.
$stage = Join-Path $WorkDir ([Guid]::NewGuid().ToString('N'))
$generated = Join-Path $stage 'generated'
& (Join-Path $PSScriptRoot 'build-cli.ps1') -Bds $Bds -Platform Win64 -OutputDir (Join-Path $stage 'cli')
if ($LASTEXITCODE) { throw 'CLI build failed' }
& (Join-Path $stage 'cli\Win64\XmlDocGen.exe') --directory (Join-Path $repo 'src') --output $generated --format html,md --title 'XmlDocPlugin API Reference'
if ($LASTEXITCODE) { throw 'API documentation generation failed' }
Get-ChildItem -LiteralPath $generated -Filter '*.md' -File -Recurse | ForEach-Object {
    $text = [IO.File]::ReadAllText($_.FullName).TrimEnd("`r", "`n") + "`r`n"
    [IO.File]::WriteAllText($_.FullName, $text, [Text.UTF8Encoding]::new($false))
}
& python (Join-Path $repo 'tests\Validate-ApiDocs.py') $generated (Join-Path $repo 'src')
if ($LASTEXITCODE) { throw 'API documentation validation failed' }
$destination = Join-Path $repo 'docs'
$units = [IO.Path]::GetFullPath((Join-Path $destination 'units'))
if ($units -ne (Join-Path $repo 'docs\units')) { throw 'Unexpected API reference destination' }
New-Item -ItemType Directory -Force $units, (Join-Path $destination 'assets') | Out-Null
# Delete only stale generated pages. Authored guides, screenshots and examples stay in place.
$names = @(Get-ChildItem -LiteralPath (Join-Path $generated 'units') -File | Select-Object -ExpandProperty Name)
Get-ChildItem -LiteralPath $units -File | Where-Object { $_.Extension -in @('.html', '.md') -and $_.Name -notin $names } | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName
}
Copy-Item -LiteralPath (Join-Path $generated 'units') -Destination $destination -Recurse -Force
foreach ($file in @('index.html','README.md','SUMMARY.md','_sidebar.md','assets\style.css','assets\search-index.json')) {
    Copy-Item -LiteralPath (Join-Path $generated $file) -Destination (Join-Path $destination $file) -Force
}
# Older generator versions wrote this index at the root; current pages use assets/search-index.json.
$oldIndex = Join-Path $destination 'search-index.json'
if (Test-Path -LiteralPath $oldIndex) { Remove-Item -LiteralPath $oldIndex }
Write-Host "Updated API reference in $destination"
