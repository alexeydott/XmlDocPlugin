param([string]$Version='',[switch]$IncrementVersion,[string]$Bds='',[string]$ResourceDir='')
$ErrorActionPreference='Stop'
$versionFile=Join-Path $PSScriptRoot 'installer\Version.txt'
if(!$Version){$Version=(Get-Content -LiteralPath $versionFile -Raw).Trim()}
if($Version -notmatch '^\d+\.\d+\.\d+(?:\.\d+)?$'){throw 'Version must have three or four numeric components'}
$parts=@($Version.Split('.') | ForEach-Object {[int]$_})
if($parts.Count -eq 3){$parts+=0}
if($IncrementVersion){$parts[3]++}
if(@($parts | Where-Object {$_ -gt 65535}).Count){throw 'Version components must be between 0 and 65535'}
$Version=$parts -join '.'
if((Get-Content -LiteralPath $versionFile -Raw).Trim() -ne $Version){[IO.File]::WriteAllText($versionFile,$Version+"`r`n",[Text.Encoding]::ASCII)}
if($ResourceDir){
 if(!$Bds){throw 'Bds is required to compile the version resource'}
 $ResourceDir=[IO.Path]::GetFullPath($ResourceDir)
 New-Item -ItemType Directory -Force $ResourceDir | Out-Null
 $rc=@"
1 VERSIONINFO
FILEVERSION $($parts -join ',')
PRODUCTVERSION $($parts -join ',')
FILEFLAGSMASK 0x3fL
FILEFLAGS 0
FILEOS 0x40004L
FILETYPE 0x1L
BEGIN
 BLOCK "StringFileInfo"
 BEGIN
  BLOCK "040904E4"
  BEGIN
   VALUE "FileDescription", "XmlDoc command-line documentation generator\0"
   VALUE "FileVersion", "$Version\0"
   VALUE "ProductName", "XmlDoc Plugin\0"
   VALUE "ProductVersion", "$Version\0"
  END
 END
 BLOCK "VarFileInfo"
 BEGIN
  VALUE "Translation", 0x409, 1252
 END
END
"@
 $rcPath=Join-Path $ResourceDir 'XmlDoc.Version.rc';$resPath=Join-Path $ResourceDir 'XmlDoc.Version.res'
 [IO.File]::WriteAllText($rcPath,$rc,[Text.Encoding]::ASCII)
 & "$Bds\bin\brcc32.exe" "-fo$resPath" $rcPath | Out-Host
 if($LASTEXITCODE){throw 'Version resource compilation failed'}
}
Write-Output $Version
