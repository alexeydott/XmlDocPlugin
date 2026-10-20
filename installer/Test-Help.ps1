param([Parameter(Mandatory)][string]$HelpDir)
$ErrorActionPreference = 'Stop'
$HelpDir = [IO.Path]::GetFullPath($HelpDir)
$html = [IO.File]::ReadAllText((Join-Path $HelpDir 'index.html'))
if ($html -match '<script\b|<(?:link|iframe)\b|(?:src|srcset)\s*=\s*["''](?:https?:)?//|@import|url\(') {
    throw 'Offline help must not depend on scripts, remote media or external stylesheets.'
}
if ($html -match 'XmlDocE2E|editor views captured in a browser|Offline user guide\.') { throw 'Help contains test-project references or removed introductory text.' }
if ($html -match '(?i)neuraldeep') { throw 'Help must not expose internal provider details.' }
$ids = @{}
foreach ($match in [regex]::Matches($html, '\bid="([^"]+)"')) {
    $id = $match.Groups[1].Value
    if ($ids.ContainsKey($id)) { throw "Duplicate help anchor: $id" }
    $ids[$id] = $true
}
$checked = 0
foreach ($match in [regex]::Matches($html, '\b(?:href|src)="([^"]+)"')) {
    $target = [Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
    if ($target -match '^https?://') { continue } # Explicit repository/download links only.
    if ($target -match '^[a-z]+:|^//') { throw "Unsupported help resource: $target" }
    if ($target.StartsWith('#')) {
        if (!$ids.ContainsKey($target.Substring(1))) { throw "Missing help anchor: $target" }
    } else {
        $path = [IO.Path]::GetFullPath((Join-Path $HelpDir ($target.Split('#')[0])))
        if (!$path.StartsWith($HelpDir + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw "Help link escapes package: $target" }
        if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing offline help resource: $target" }
    }
    $checked++
}
foreach ($required in @('documentation-tools','recover-drafts','synchronize-a-changed-signature','save-wording-and-terminology','add-examples-and-replace-prose','generate-documentation','use-the-command-line')) {
    if (!$ids.ContainsKey($required)) { throw "Offline help section is missing: $required" }
}
if (@([regex]::Matches($html, '<img\b')).Count -lt 5) { throw 'Illustrated help must include the editor screenshots.' }
$authoring = Get-Content (Join-Path $HelpDir 'examples\authoring.json') -Raw | ConvertFrom-Json
if (!$authoring.authoring.templates -or !$authoring.authoring.terminology) { throw 'Authoring example is incomplete.' }
if (Get-ChildItem $HelpDir -Recurse -File | Where-Object Extension -in @('.exe','.dcu','.identcache','.delphilsp','.bpl')) { throw 'Offline help includes build artifacts or IDE caches.' }
Write-Host "PASS: offline help anchors, $checked local references, screenshots and authoring configuration"
