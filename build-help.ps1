param(
    [string]$OutputDir = (Join-Path $env:LOCALAPPDATA 'XmlDocPlugin\Help')
)
$ErrorActionPreference = 'Stop'
if (!(Get-Command ConvertFrom-Markdown -ErrorAction SilentlyContinue)) {
    throw 'Offline help generation requires PowerShell 7 (pwsh) with ConvertFrom-Markdown.'
}
$OutputDir = [IO.Path]::GetFullPath($OutputDir)
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'docs\user-guide.md'))
$html = (ConvertFrom-Markdown -InputObject $source).Html
$style = @'
:root{color-scheme:light dark;font:16px/1.6 system-ui,Segoe UI,sans-serif;background:#fff;color:#202936}body{max-width:1080px;margin:auto;padding:24px 32px 80px}a{color:#1769aa}h1,h2,h3{line-height:1.25;scroll-margin-top:16px}h2{margin-top:2.4em;border-bottom:1px solid #ccd3da;padding-bottom:.35em}img{max-width:100%;height:auto;border:1px solid #ccd3da;border-radius:5px}table{width:100%;border-collapse:collapse;display:block;overflow-x:auto}td,th{padding:9px 12px;border:1px solid #ccd3da;vertical-align:top;text-align:left}th{background:#edf2f7}pre{background:#f1f4f8;padding:16px;overflow:auto;border-radius:5px}code{font:.9em/1.5 Consolas,monospace;overflow-wrap:anywhere}p,li{overflow-wrap:anywhere}@media(prefers-color-scheme:dark){:root{background:#20242b;color:#e5e9ef}a{color:#87bfff}th,pre{background:#2b333e}td,th,h2,img{border-color:#505b69}}@media print{body{padding:0;font-size:11pt}a{color:inherit}pre,table,img{break-inside:avoid}}
'@
$page = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'"><title>XmlDocPlugin user guide</title><style>$style</style></head>
<body>
$html
</body></html>
"@
New-Item -ItemType Directory -Force $OutputDir | Out-Null
[IO.File]::WriteAllText((Join-Path $OutputDir 'index.html'), $page, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $OutputDir 'user-guide.md'), $source, [Text.UTF8Encoding]::new($false))
$images = Join-Path $OutputDir 'assets\user-guide'
New-Item -ItemType Directory -Force $images | Out-Null
Get-ChildItem (Join-Path $PSScriptRoot 'docs\assets\user-guide') -File | Where-Object Extension -in @('.png','.jpg','.jpeg') | Copy-Item -Destination $images -Force
$examples = Join-Path $OutputDir 'examples'
New-Item -ItemType Directory -Force $examples | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'docs\examples\authoring.json') $examples -Force
& (Join-Path $PSScriptRoot 'installer\Test-Help.ps1') -HelpDir $OutputDir
Write-Host "Offline help: $(Join-Path $OutputDir 'index.html')"
