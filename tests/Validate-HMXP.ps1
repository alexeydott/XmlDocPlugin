param([Parameter(Mandatory)][string]$ProjectPath)
$ErrorActionPreference = 'Stop'
$ProjectPath = [IO.Path]::GetFullPath($ProjectPath)
$root = Split-Path $ProjectPath
$schemas = [Xml.Schema.XmlSchemaSet]::new()
$schemas.XmlResolver = [Xml.XmlUrlResolver]::new()
[void]$schemas.Add('', (Join-Path $root 'helpproject.xsd'))
$schemas.Compile()
function Read-Xml([string]$Path) {
    $doc = [Xml.XmlDocument]::new()
    $doc.PreserveWhitespace = $true
    $doc.Load($Path)
    return ,$doc
}
function Local-Path([string]$Href) {
    $path = [IO.Path]::GetFullPath((Join-Path $root $Href))
    if (!$path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Reference outside the exported project: $Href"
    }
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing resource: $Href" }
    return $path
}
foreach ($name in @([IO.Path]::GetFileName($ProjectPath), 'helpproject.xsd', 'helpproject.xsl', 'xml.xsd')) {
    if ([IO.File]::ReadAllText((Join-Path $root $name)).Contains('MapplGIS.hmxp')) {
        throw "Exported resource references another project: $name"
    }
}
$project = Read-Xml $ProjectPath
$includes = @($project.GetElementsByTagName('include', 'http://www.w3.org/2001/XInclude'))
foreach ($include in $includes) {
    $included = Read-Xml (Local-Path $include.GetAttribute('href'))
    $included.Schemas = $schemas
    $included.Validate($null)
    [void]$include.ParentNode.ReplaceChild($project.ImportNode($included.DocumentElement, $true), $include)
}
$project.Schemas = $schemas
$project.Validate($null)
$topics = @{}
$topicDocs = @{}
$styleNames = @{}
foreach ($style in $project.SelectNodes('/helpproject/config/styleclasses/styleclass')) {
    $styleNames[$style.GetAttribute('name')] = $true
}
$xslt = [Xml.Xsl.XslCompiledTransform]::new()
$xslt.Load((Join-Path $root 'helpproject.xsl'), [Xml.Xsl.XsltSettings]::new($true, $false), [Xml.XmlUrlResolver]::new())
foreach ($file in $project.SelectNodes('/helpproject/project-files/file[@filetype="topic"]')) {
    $href = $file.GetAttribute('href')
    $path = Local-Path $href
    $id = [IO.Path]::GetFileNameWithoutExtension($path)
    if ($topics.ContainsKey($id)) { throw "Duplicate topic: $id" }
    $doc = Read-Xml $path
    $doc.Schemas = $schemas
    $doc.Validate($null)
    if (!$doc.SelectSingleNode('/topic/title').InnerText) { throw "Missing title: $id" }
    foreach ($node in $doc.SelectNodes('//*[@styleclass]')) {
        if (!$styleNames.ContainsKey($node.GetAttribute('styleclass'))) { throw "Undefined style in $id" }
    }
    $topics[$id] = $path
    $topicDocs[$id] = $doc
    $reader = [Xml.XmlReader]::Create($path)
    $output = [IO.StringWriter]::new()
    $writer = [Xml.XmlWriter]::Create($output, $xslt.OutputSettings)
    try { $xslt.Transform($reader, $null, $writer, [Xml.XmlUrlResolver]::new()) }
    finally { $writer.Dispose(); $reader.Dispose() }
    if (!$output.ToString().Contains('<html')) { throw "XSL preview missing for $id" }
    $output.Dispose()
}
$referenced = @{}
foreach ($ref in $project.SelectNodes('/helpproject/map//topicref[@href]')) {
    $id = $ref.GetAttribute('href')
    if (!$topics.ContainsKey($id)) { throw "Broken TOC reference: $id" }
    $referenced[$id] = $true
}
if ($referenced.Count -ne $topics.Count) { throw 'Topics are missing from the table of contents' }
foreach ($doc in $topicDocs.Values) {
    foreach ($link in $doc.SelectNodes('//link[@type="topiclink"]')) {
        if (!$topics.ContainsKey($link.GetAttribute('href'))) { throw "Broken topic link: $($link.OuterXml)" }
    }
}
Write-Output "PASS: HMXP, TOC, $($topics.Count) topics, local XSD dependencies, styles, links, and XSL previews: $ProjectPath"
