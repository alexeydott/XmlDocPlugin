/// <summary>Theme-aware XSLT and reversible stylesheet preferences for native IDE Help Insight.</summary>
unit XmlDoc.Plugin.HelpInsight;

interface

type
/// <summary>Native hint layout and opt-in extended presentation preferences.</summary>
  THelpInsightSettings = record
    Enabled: Boolean;
    Extended: Boolean;
    Width: Integer;
    FontSize: Integer;
    LineHeight: Integer;
    ParameterWidth: Integer;
    WrapSignature: Boolean;
    CompactParameters: Boolean;
    class function Defaults: THelpInsightSettings; static;
  end;
/// <summary>CSS colours captured from the active IDE theme, with light and dark fallback palettes.</summary>
  THelpInsightPalette = record
    Background, Foreground, Surface, Border, Link: string;
    class function Light: THelpInsightPalette; static;
    class function Dark: THelpInsightPalette; static;
  end;

/// <summary>Builds viewer-compatible styles with bounded layout dimensions.</summary>
function BuildEnhancedHelpInsightCss(const Settings:THelpInsightSettings; const Palette:THelpInsightPalette):string;
/// <summary>Builds the bundled XSLT 1.0 template with localized section headings.</summary>
function BuildEnhancedHelpInsightXslt(const Settings: THelpInsightSettings;
  const Palette: THelpInsightPalette): string;
/// <summary>Transforms a sample without modifying IDE files; external XML entities are disabled.</summary>
function RenderHelpInsightPreview(const Xml: string; const Settings: THelpInsightSettings;
  const Palette: THelpInsightPalette; const NativeCssFile:string=''; const NativeXslFile:string=''): string;
/// <summary>Updates root and localized templates, preserving backups and rolling back failed writes.</summary>
procedure ApplyHelpInsightPresentation(const CssFile: string; const Settings: THelpInsightSettings;
  const Palette: THelpInsightPalette; const XslFile:string='');
/// <summary>Restores the first saved stylesheet and root/localized templates byte for byte.</summary>
procedure RestoreHelpInsightTemplates(const CssFile: string; const XslFile:string='');
/// <summary>Exports a matching HelpInsight.css and HelpInsight.xsl pair to a separate directory.</summary>
procedure ExportHelpInsightTemplates(const CssFile, DestinationCss: string;
  const Settings: THelpInsightSettings; const Palette: THelpInsightPalette; const XslFile:string='');

function HelpInsightCssPath(const Languages:string=''): string;
function BuildHelpInsightCss(const Settings: THelpInsightSettings): string;
function UpdateHelpInsightCss(const Original: string; const Settings: THelpInsightSettings): string;
/// <summary>Updates only the plugin block; preserves the first file backup and unrelated CSS.</summary>
procedure ApplyHelpInsightCss(const FileName: string; const Settings: THelpInsightSettings);
/// <summary>Exports a complete stylesheet for a separate administrator-assisted copy.</summary>
procedure ExportHelpInsightCss(const SourceFileName, DestinationFileName: string;
  const Settings: THelpInsightSettings);
/// <summary>Uses Windows Shell copy, allowing the user to approve UAC for a protected IDE folder.</summary>
procedure ApplyHelpInsightCssWithShell(const FileName: string;
  const Settings: THelpInsightSettings; OwnerWindow: NativeUInt);

implementation

uses System.SysUtils, System.IOUtils, System.Math, System.Variants, System.Win.ComObj, XmlDoc.I18n, Winapi.Windows,
  Winapi.ActiveX, Winapi.ShlObj, Winapi.ShellAPI;

{$I XmlDoc.HelpInsight.Template.inc}

class function THelpInsightPalette.Light: THelpInsightPalette;
begin Result.Background:='#ffffff';Result.Foreground:='#202020';Result.Surface:='#edf1f5';Result.Border:='#b8c2cc';Result.Link:='#005a9e';end;
class function THelpInsightPalette.Dark: THelpInsightPalette;
begin Result.Background:='#252525';Result.Foreground:='#eeeeee';Result.Surface:='#343b43';Result.Border:='#65707b';Result.Link:='#82c5ff';end;

function BuildEnhancedHelpInsightCss(const Settings: THelpInsightSettings;const Palette: THelpInsightPalette): string;
var Css:string;Width,Column:Integer;
begin
 Width:=EnsureRange(Settings.Width,360,1200);Column:=EnsureRange(Settings.ParameterWidth,80,Width div 2);
 Css:=Format('html,body { margin:0; padding:0; background:%s; color:%s; font-family:Segoe UI,Arial,sans-serif; font-size:%dpt; line-height:%d%%; } '+
  '.xmldoc-hint { width:auto; padding:8px; } .hint-caption { background:%s; border-bottom:1px solid %s; padding:5px; margin-bottom:7px; font-weight:bold; } '+
  'a { color:%s; text-decoration:none; } a:hover { text-decoration:underline; } '+
  'h4 { margin:8px 0 3px; font-size:100%%; clear:both; } p { margin:0 0 5px; } .hint-section { margin:0 0 5px; } '+
  'dl { margin:0; } dt { float:none; clear:none; width:auto; margin:5px 0 2px; font-weight:bold; } dd { margin:0 0 6px 16px; } '+
  'ul,ol { margin:4px 0 6px 24px; padding:0; } li { margin:2px 0; } '+
  'table { border-collapse:collapse; width:100%%; table-layout:fixed; } th,td { padding:5px; border:1px solid %s; vertical-align:top; } '+
  'th,.hint-note-title { background:%s; font-weight:bold; } .hint-note { border:1px solid %s; margin:7px 0; } .hint-note-title,.hint-note-content { padding:5px; } '+
  'pre { white-space:pre-wrap; word-wrap:break-word; border:1px solid %s; padding:6px; } code { font-family:Consolas,Courier New,monospace; } '+
  'td,dd,p,code,.hint-caption { word-wrap:break-word; }',
  [Palette.Background,Palette.Foreground,EnsureRange(Settings.FontSize,8,18),EnsureRange(Settings.LineHeight,100,180),
   Palette.Surface,Palette.Border,Palette.Link,Palette.Border,Palette.Surface,Palette.Border,Palette.Border]);
 if Settings.WrapSignature then Css:=Css+' .hint-caption { white-space:normal; }'
 else Css:=Css+' .hint-caption { white-space:nowrap; }';
 if Settings.CompactParameters then Css:=Css+' dt { margin-top:3px; } dd { margin-bottom:3px; }';
 if Settings.CompactParameters then Css:=Css+Format('dt { float:left; clear:left; width:%dpx; word-wrap:break-word; } dd { margin-left:%dpx; }',[Column,Column+12]);
 Result:=Css;
end;

function BuildEnhancedHelpInsightXslt(const Settings:THelpInsightSettings;const Palette:THelpInsightPalette):string;
begin
 Result:=CEnhancedHelpInsightXslt.Replace('@@CSS@@','');
 for var Caption in ['Type Parameters','Parameters','Returns','Value','Exceptions','Remarks','Examples','See Also','Notes to callers','Warning','Tip','Note'] do begin
  var Text:=TI18n.Instance.T(Caption).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;');
  Result:=Result.Replace('@@'+Caption+'@@',Text);
 end;
end;

function RenderHelpInsightPreview(const Xml:string;const Settings:THelpInsightSettings;const Palette:THelpInsightPalette;const NativeCssFile,NativeXslFile:string):string;
var Document,Template:OleVariant;
begin
 Document:=CreateOleObject('Msxml2.DOMDocument.6.0');Template:=CreateOleObject('Msxml2.DOMDocument.6.0');
 Document.async:=False;Document.resolveExternals:=False;Document.setProperty('ProhibitDTD',True);
 Template.async:=False;Template.resolveExternals:=False;Template.setProperty('ProhibitDTD',True);
 if not Document.loadXML(Xml) then raise EArgumentException.Create(string(Document.parseError.reason));
 var CssPath:=NativeCssFile;if CssPath='' then CssPath:=HelpInsightCssPath;
 var Xsl:=BuildEnhancedHelpInsightXslt(Settings,Palette);
 if not Settings.Extended then begin
  var Native:=NativeXslFile;if Native='' then Native:=ChangeFileExt(CssPath,'.xsl');
  if TFile.Exists(Native+'.xmldocplugin.bak') and TFile.ReadAllText(Native).Contains('XmlDocPlugin native Help Insight') then Native:=Native+'.xmldocplugin.bak';
  Xsl:=TFile.ReadAllText(Native);
 end;
 if not Template.loadXML(Xsl) then raise EArgumentException.Create(string(Template.parseError.reason));
 Result:=Document.transformNode(Template);
 Result:='<!DOCTYPE html>'+Result.Replace('<head>','<head><meta http-equiv="X-UA-Compatible" content="IE=edge">');
 if Settings.Extended then Result:=Result.Replace('</head>','<style type="text/css">'+BuildEnhancedHelpInsightCss(Settings,Palette)+' body { width:auto; }</style></head>');
 if not Settings.Extended then begin
  var Css:=UpdateHelpInsightCss(TFile.ReadAllText(CssPath),Settings);
  Result:=Result.Replace('href="HelpInsight.css"','href="'+CssPath+'"');
  Result:=Result.Replace('</head>','<style type="text/css">'+Css+'</style></head>');
 end;
end;

procedure WriteHintFile(const FileName:string;const Bytes:TBytes);
var Temp:string;
begin
 Temp:=FileName+'.'+TPath.GetRandomFileName;
 try TFile.WriteAllBytes(Temp,Bytes);
  if not ReplaceFile(PChar(FileName),PChar(Temp),nil,REPLACEFILE_IGNORE_MERGE_ERRORS,nil,nil) then RaiseLastOSError;
 finally if TFile.Exists(Temp) then TFile.Delete(Temp);end;
end;

procedure ApplySingleHelpInsightPresentation(const CssFile:string;const Settings:THelpInsightSettings;const Palette:THelpInsightPalette;const XslFile:string);
var Xsl,Backup,Updated:string;Before,Next,CssBefore:TBytes;Changed,CssChanged:Boolean;
begin
 CssChanged:=False;
 Xsl:=XslFile;if Xsl='' then Xsl:=ChangeFileExt(CssFile,'.xsl');Backup:=Xsl+'.xmldocplugin.bak';Changed:=False;CssBefore:=TFile.ReadAllBytes(CssFile);
 if Settings.Enabled and Settings.Extended then begin
  if not TFile.Exists(Xsl) then raise EArgumentException.Create('Help Insight template was not found: '+Xsl);
  Updated:=BuildEnhancedHelpInsightXslt(Settings,Palette);Before:=TFile.ReadAllBytes(Xsl);
  if not TFile.Exists(Backup) then begin
   if TFile.ReadAllText(Xsl).Contains('XmlDocPlugin native Help Insight') then raise EArgumentException.Create('Original Help Insight template backup is missing');
   TFile.Copy(Xsl,Backup);
  end;
  Next:=TEncoding.UTF8.GetBytes(Updated);
 end else if TFile.Exists(Xsl) and TFile.Exists(Backup) and TFile.ReadAllText(Xsl).Contains('XmlDocPlugin native Help Insight') then begin
  Before:=TFile.ReadAllBytes(Xsl);Next:=TFile.ReadAllBytes(Backup);
 end;
 try
  if Length(Next)>0 then begin WriteHintFile(Xsl,Next);Changed:=True;end;
  ApplyHelpInsightCss(CssFile,Settings);CssChanged:=True;
  if Settings.Enabled and Settings.Extended then begin
   var Text:=TFile.ReadAllText(CssFile).Replace('/* XmlDocPlugin Help Insight: end */',BuildEnhancedHelpInsightCss(Settings,Palette)+sLineBreak+'/* XmlDocPlugin Help Insight: end */');
   WriteHintFile(CssFile,TEncoding.UTF8.GetBytes(Text));
  end;
 except
  if Changed then WriteHintFile(Xsl,Before);
  if CssChanged then WriteHintFile(CssFile,CssBefore);
  raise;
 end;
end;

procedure ApplyHelpInsightPresentation(const CssFile:string;const Settings:THelpInsightSettings;const Palette:THelpInsightPalette;const XslFile:string);
var Root,Localized:string;CssBefore,RootBefore,LocalizedBefore:TBytes;
begin
 if not TFile.Exists(CssFile) then begin ApplyHelpInsightCss(CssFile,Settings);Exit;end;
 Root:=ChangeFileExt(CssFile,'.xsl');Localized:=XslFile;
 if (Localized='') or SameText(TPath.GetFullPath(Root),TPath.GetFullPath(Localized)) or not TFile.Exists(Root) then begin
  ApplySingleHelpInsightPresentation(CssFile,Settings,Palette,XslFile);Exit;
 end;
 // The LSP popup reads the root template; legacy Help Insight reads the localized one.
 CssBefore:=TFile.ReadAllBytes(CssFile);RootBefore:=TFile.ReadAllBytes(Root);LocalizedBefore:=TFile.ReadAllBytes(Localized);
 try
  ApplySingleHelpInsightPresentation(CssFile,Settings,Palette,Root);
  ApplySingleHelpInsightPresentation(CssFile,Settings,Palette,Localized);
 except
  WriteHintFile(Root,RootBefore);
  WriteHintFile(Localized,LocalizedBefore);WriteHintFile(CssFile,CssBefore);raise;
 end;
end;

procedure ExportHelpInsightTemplates(const CssFile,DestinationCss:string;const Settings:THelpInsightSettings;const Palette:THelpInsightPalette;const XslFile:string);
var Xsl,Css,DestinationXsl:string;CssExisted,XslExisted,CssChanged,XslChanged:Boolean;CssBefore,XslBefore:TBytes;
 procedure SaveOutput(const FileName,Text:string;Existed:Boolean);
 var Temp:string;
 begin
  if Existed then WriteHintFile(FileName,TEncoding.UTF8.GetBytes(Text))
  else begin
   Temp:=FileName+'.'+TPath.GetRandomFileName;
   try TFile.WriteAllText(Temp,Text,TEncoding.UTF8);TFile.Move(Temp,FileName);
   finally if TFile.Exists(Temp) then TFile.Delete(Temp);end;
  end;
 end;
begin
 if not SameText(ExtractFileName(DestinationCss),'HelpInsight.css') then raise EArgumentException.Create('Use the filename HelpInsight.css so the exported template can find its stylesheet');
 if SameText(TPath.GetFullPath(ExtractFilePath(CssFile)),TPath.GetFullPath(ExtractFilePath(DestinationCss))) then raise EArgumentException.Create('Export the stylesheet to a separate folder');
 Xsl:=XslFile;if Xsl='' then Xsl:=ChangeFileExt(CssFile,'.xsl');
 if SameText(TPath.GetFullPath(ChangeFileExt(DestinationCss,'.xsl')),TPath.GetFullPath(Xsl)) then raise EArgumentException.Create('Export the templates to a separate folder');
 if Settings.Enabled and Settings.Extended then Xsl:=BuildEnhancedHelpInsightXslt(Settings,Palette)
 else begin if TFile.Exists(Xsl+'.xmldocplugin.bak') and TFile.ReadAllText(Xsl).Contains('XmlDocPlugin native Help Insight') then Xsl:=Xsl+'.xmldocplugin.bak';Xsl:=TFile.ReadAllText(Xsl);end;
 Css:=UpdateHelpInsightCss(TFile.ReadAllText(CssFile),Settings);
 if Settings.Enabled and Settings.Extended then Css:=Css.Replace('/* XmlDocPlugin Help Insight: end */',BuildEnhancedHelpInsightCss(Settings,Palette)+sLineBreak+'/* XmlDocPlugin Help Insight: end */');
 DestinationXsl:=ChangeFileExt(DestinationCss,'.xsl');CssExisted:=TFile.Exists(DestinationCss);XslExisted:=TFile.Exists(DestinationXsl);
 if CssExisted then CssBefore:=TFile.ReadAllBytes(DestinationCss);
 if XslExisted then XslBefore:=TFile.ReadAllBytes(DestinationXsl);
 CssChanged:=False;XslChanged:=False;
 try
  SaveOutput(DestinationXsl,Xsl,XslExisted);XslChanged:=True;
  SaveOutput(DestinationCss,Css,CssExisted);CssChanged:=True;
 except
  if CssChanged then begin if CssExisted then WriteHintFile(DestinationCss,CssBefore) else TFile.Delete(DestinationCss);end;
  if XslChanged then begin if XslExisted then WriteHintFile(DestinationXsl,XslBefore) else TFile.Delete(DestinationXsl);end;
  raise;
 end;
end;

procedure RestoreSingleHelpInsightTemplates(const CssFile,XslFile:string);
var CssBefore,XslBefore:TBytes;Xsl,CssBackup,XslBackup:string;
begin
 Xsl:=XslFile;if Xsl='' then Xsl:=ChangeFileExt(CssFile,'.xsl');CssBackup:=CssFile+'.xmldocplugin.bak';XslBackup:=Xsl+'.xmldocplugin.bak';
 CssBefore:=TFile.ReadAllBytes(CssFile);XslBefore:=TFile.ReadAllBytes(Xsl);
 try
  if TFile.Exists(XslBackup) then WriteHintFile(Xsl,TFile.ReadAllBytes(XslBackup));
  if TFile.Exists(CssBackup) then WriteHintFile(CssFile,TFile.ReadAllBytes(CssBackup));
 except WriteHintFile(Xsl,XslBefore);WriteHintFile(CssFile,CssBefore);raise;end;
end;

procedure RestoreHelpInsightTemplates(const CssFile,XslFile:string);
var Root:string;CssBefore,RootBefore,LocalizedBefore:TBytes;
begin
 Root:=ChangeFileExt(CssFile,'.xsl');
 if (XslFile='') or SameText(TPath.GetFullPath(Root),TPath.GetFullPath(XslFile)) or not TFile.Exists(Root) then begin
  RestoreSingleHelpInsightTemplates(CssFile,XslFile);Exit;
 end;
 CssBefore:=TFile.ReadAllBytes(CssFile);RootBefore:=TFile.ReadAllBytes(Root);LocalizedBefore:=TFile.ReadAllBytes(XslFile);
 try RestoreSingleHelpInsightTemplates(CssFile,Root);RestoreSingleHelpInsightTemplates(CssFile,XslFile);
 except WriteHintFile(Root,RootBefore);WriteHintFile(XslFile,LocalizedBefore);WriteHintFile(CssFile,CssBefore);raise;end;
end;

const
  CBegin = '/* XmlDocPlugin Help Insight: begin */';
  CEnd = '/* XmlDocPlugin Help Insight: end */';
  CLegacyBegin = '/* Compact Help Insight for Delphi 12. Original theme colours are preserved. */';
  CLegacyEnd = 'dd p { margin: 0; }';

class function THelpInsightSettings.Defaults: THelpInsightSettings;
begin
  Result.Enabled := False;
  Result.Extended := False;
  Result.Width := 720;
  Result.FontSize := 9;
  Result.LineHeight := 125;
  Result.ParameterWidth := 160;
  Result.WrapSignature := True;
  Result.CompactParameters := True;
end;

function HelpInsightCssPath(const Languages:string): string;
begin
  // The executable, rather than BDS from a shell or another IDE installation.
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\ObjRepos\HelpInsight.css'));
  for var Language in Languages.Replace(';',',').Split([',']) do begin
   var Name:=Trim(Language).ToLower;var Dash:=Name.IndexOf('-');if Dash>=0 then Name:=Name.Substring(0,Dash);
   if (Name='en') or (Name='de') or (Name='fr') or (Name='ja') then begin
    var Candidate:=TPath.Combine(ExtractFilePath(Result),Name+'\HelpInsight.css');
    if TFile.Exists(Candidate) and TFile.Exists(ChangeFileExt(Candidate,'.xsl')) then Exit(Candidate);
   end;
  end;
end;

function BuildHelpInsightCss(const Settings: THelpInsightSettings): string;
var Width, FontSize, LineHeight, Column: Integer;
begin
  Width := EnsureRange(Settings.Width, 360, 1200);
  FontSize := EnsureRange(Settings.FontSize, 8, 18);
  LineHeight := EnsureRange(Settings.LineHeight, 100, 180);
  Column := EnsureRange(Settings.ParameterWidth, 80, Width div 2);
  Result := CBegin + sLineBreak +
    Format('body { width: %dpx; font-size: %dpt; line-height: %d%%; }', [Width, FontSize, LineHeight]) + sLineBreak +
    'h4 { clear: both; margin-top: 4px; margin-bottom: 2px; }' + sLineBreak;
  if Settings.WrapSignature then
    Result := Result + 'table { width: 100%; }' + sLineBreak +
      'td, .maincaption { white-space: normal; }' + sLineBreak;
  if Settings.CompactParameters then
    Result := Result + 'dl { margin-left: 4px; margin-bottom: 2px; }' + sLineBreak +
      Format('dt { float: left; clear: left; width: %dpx; margin: 0 0 0 8px; font-weight: bold; line-height: %d%%; }', [Column, LineHeight]) + sLineBreak +
      Format('dd { display: block; margin: 0 0 0 %dpx; line-height: %d%%; }', [Column + 14, LineHeight]) + sLineBreak +
      'dd p { margin: 0; }' + sLineBreak;
  Result := Result + CEnd;
end;

function UpdateHelpInsightCss(const Original: string; const Settings: THelpInsightSettings): string;
var First, Last, Count: Integer;
begin
  Result := Original;
  First := Pos(CBegin, Result);
  while First > 0 do
  begin
    Last := Pos(CEnd, Result, First);
    if Last = 0 then raise Exception.Create('Incomplete XmlDocPlugin Help Insight CSS block');
    Count := Last + Length(CEnd) - First;
    if Copy(Result, First + Count, Length(sLineBreak)) = sLineBreak then Inc(Count, Length(sLineBreak));
    if (First > Length(sLineBreak)) and
      (Copy(Result, First - Length(sLineBreak), Length(sLineBreak)) = sLineBreak) then
    begin
      Dec(First, Length(sLineBreak));
      Inc(Count, Length(sLineBreak));
    end;
    Delete(Result, First, Count);
    First := Pos(CBegin, Result);
  end;
  // Adopt the CSS experiment shipped before the preferences UI existed.
  First := Pos(CLegacyBegin, Result);
  if First > 0 then
  begin
    Last := Pos(CLegacyEnd, Result, First);
    if Last = 0 then raise Exception.Create('Incomplete compact Help Insight CSS block');
    Delete(Result, First, Last + Length(CLegacyEnd) - First);
  end;
  if Settings.Enabled then
    Result := Result + sLineBreak + BuildHelpInsightCss(Settings) + sLineBreak;
end;

procedure ApplyHelpInsightCss(const FileName: string; const Settings: THelpInsightSettings);
var Original, Updated, TempName, Backup: string;
begin
  if not TFile.Exists(FileName) then
  begin
    if not Settings.Enabled then Exit;
    raise Exception.CreateFmt('Help Insight stylesheet was not found: %s', [FileName]);
  end;
  Original := TFile.ReadAllText(FileName);
  Updated := UpdateHelpInsightCss(Original, Settings);
  if Original = Updated then Exit;
  Backup := FileName + '.xmldocplugin.bak';
  if not TFile.Exists(Backup) then TFile.Copy(FileName, Backup);
  TempName := FileName + '.' + TPath.GetRandomFileName;
  try
    TFile.WriteAllText(TempName, Updated, TEncoding.UTF8);
    if not ReplaceFile(PChar(FileName), PChar(TempName), nil,
      REPLACEFILE_IGNORE_MERGE_ERRORS, nil, nil) then RaiseLastOSError;
  finally
    if TFile.Exists(TempName) then TFile.Delete(TempName);
  end;
end;

procedure ExportHelpInsightCss(const SourceFileName, DestinationFileName: string;
  const Settings: THelpInsightSettings);
begin
  if SameText(TPath.GetFullPath(SourceFileName), TPath.GetFullPath(DestinationFileName)) or
     SameText(TPath.GetFullPath(SourceFileName + '.xmldocplugin.bak'), TPath.GetFullPath(DestinationFileName)) then
    raise EArgumentException.Create('Export the stylesheet to a separate folder');
  TFile.WriteAllText(DestinationFileName,
    UpdateHelpInsightCss(TFile.ReadAllText(SourceFileName), Settings), TEncoding.UTF8);
end;

procedure ApplyHelpInsightCssWithShell(const FileName: string;
  const Settings: THelpInsightSettings; OwnerWindow: NativeUInt);
var
  Operation: IFileOperation;
  Source, Folder, Existing: IShellItem;
  TempName, Backup, Updated: string;
  Cancelled: BOOL;
  Status: HRESULT;
begin
  Updated := UpdateHelpInsightCss(TFile.ReadAllText(FileName), Settings);
  if Updated = TFile.ReadAllText(FileName) then Exit;
  TempName := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  Backup := FileName + '.xmldocplugin.bak';
  try
    TFile.WriteAllText(TempName, Updated, TEncoding.UTF8);
    OleCheck(CoCreateInstance(CLSID_FileOperation, nil, CLSCTX_INPROC_SERVER, IFileOperation, Operation));
    OleCheck(Operation.SetOwnerWindow(OwnerWindow));
    OleCheck(Operation.SetOperationFlags(FOF_SILENT or FOF_NOCONFIRMATION or
      FOF_NOERRORUI or FOFX_SHOWELEVATIONPROMPT or FOFX_EARLYFAILURE));
    OleCheck(SHCreateItemFromParsingName(PChar(ExtractFilePath(FileName)), nil, IShellItem, Folder));
    if not TFile.Exists(Backup) then
    begin
      OleCheck(SHCreateItemFromParsingName(PChar(FileName), nil, IShellItem, Existing));
      OleCheck(Operation.CopyItem(Existing, Folder, PChar(ExtractFileName(Backup)), nil));
    end;
    OleCheck(SHCreateItemFromParsingName(PChar(TempName), nil, IShellItem, Source));
    OleCheck(Operation.CopyItem(Source, Folder, PChar(ExtractFileName(FileName)), nil));
    Status := Operation.PerformOperations;
    OleCheck(Operation.GetAnyOperationsAborted(Cancelled));
    if Cancelled then Abort;
    OleCheck(Status);
    if TFile.ReadAllText(FileName) <> Updated then
      raise Exception.Create('Windows did not apply the Help Insight stylesheet');
  finally
    Operation := nil; Source := nil; Folder := nil; Existing := nil;
    if TFile.Exists(TempName) then TFile.Delete(TempName);
  end;
end;

end.
