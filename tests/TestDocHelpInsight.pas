unit TestDocHelpInsight;
interface
uses DUnitX.TestFramework;
type
  [TestFixture] THelpInsightTests = class
  public
    [Test] procedure ExtendedTransformAndSafeMarkup;
    [Test] procedure PresentationSwitchAndRollback;
    [Test] procedure ExtendedSettingsAndExport;
    [Test] procedure UpdateIsReversibleAndPreservesCustomCss;
    [Test] procedure RepeatedApplyAndFirstBackup;
    [Test] procedure MalformedBlockLeavesFileUntouched;
    [Test] procedure SettingsSurviveRecreation;
    [Test] procedure LegacyExperimentIsReplaced;
    [Test] procedure ReadOnlyStylesheetCanBeExportedWithoutChangingOriginal;
    [Test] procedure ShellCopyKeepsFirstBackupAndAppliesChanges;
  end;
implementation
uses XmlDoc.I18n,System.Classes,System.SysUtils, System.IOUtils, System.Win.Registry, Winapi.Windows,
  XmlDoc.Plugin.HelpInsight, XmlDoc.Plugin.Settings;

procedure THelpInsightTests.UpdateIsReversibleAndPreservesCustomCss;
var S: THelpInsightSettings; Original, Changed: string;
begin
  Original := 'body { color: WindowText; }' + #10 + '/* user override */  ';
  S := THelpInsightSettings.Defaults;
  Assert.AreEqual(Original, UpdateHelpInsightCss(Original, S));
  S.Enabled := True;
  Changed := UpdateHelpInsightCss(Original, S);
  Assert.IsTrue(Changed.StartsWith(Original));
  S.Width := 960;
  Changed := UpdateHelpInsightCss(Changed, S);
  Assert.IsTrue(Changed.Contains('width: 960px'));
  Assert.IsFalse(Changed.Contains('width: 720px'));
  S.Enabled := False;
  Assert.AreEqual(Original, UpdateHelpInsightCss(Changed, S));
end;

procedure THelpInsightTests.RepeatedApplyAndFirstBackup;
var Root, FileName, First: string; S: THelpInsightSettings;
begin
  Root := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  ForceDirectories(Root); FileName := TPath.Combine(Root, 'HelpInsight.css');
  try
    TFile.WriteAllText(FileName, 'body { color: WindowText; }');
    S := THelpInsightSettings.Defaults; S.Enabled := True;
    ApplyHelpInsightCss(FileName, S); First := TFile.ReadAllText(FileName);
    ApplyHelpInsightCss(FileName, S);
    Assert.AreEqual(First, TFile.ReadAllText(FileName));
    S.FontSize := 11; ApplyHelpInsightCss(FileName, S);
    Assert.AreEqual('body { color: WindowText; }', TFile.ReadAllText(FileName + '.xmldocplugin.bak'));
    S.Enabled := False; ApplyHelpInsightCss(FileName, S);
    Assert.AreEqual('body { color: WindowText; }', TFile.ReadAllText(FileName));
  finally TDirectory.Delete(Root, True); end;
end;

procedure THelpInsightTests.MalformedBlockLeavesFileUntouched;
var Root, FileName, Original: string; S: THelpInsightSettings;
begin
  Root := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  ForceDirectories(Root); FileName := TPath.Combine(Root, 'HelpInsight.css');
  Original := 'body {} /* XmlDocPlugin Help Insight: begin */ user style';
  try
    TFile.WriteAllText(FileName, Original);
    S := THelpInsightSettings.Defaults; S.Enabled := True;
    Assert.WillRaise(procedure begin ApplyHelpInsightCss(FileName, S); end, Exception);
    Assert.AreEqual(Original, TFile.ReadAllText(FileName));
    Assert.IsFalse(TFile.Exists(FileName + '.xmldocplugin.bak'));
  finally TDirectory.Delete(Root, True); end;
end;

procedure THelpInsightTests.SettingsSurviveRecreation;
var Root: string; Writer, Reader: TPluginSettings; S: TGlobalSettings; R: TRegistry;
begin
  Root := 'Software\XmlDocPlugin\Tests\' + TPath.GetRandomFileName;
  Writer := TPluginSettings.Create(Root);
  try
    S := Writer.Global;
    S.HelpInsight.Enabled := True; S.HelpInsight.Width := 940;
    S.HelpInsight.FontSize := 11; S.HelpInsight.LineHeight := 140;
    S.HelpInsight.ParameterWidth := 240;
    S.HelpInsight.WrapSignature := False; S.HelpInsight.CompactParameters := False;
    Writer.Global := S; Writer.Save;
    Reader := TPluginSettings.Create(Root);
    try
      Assert.IsTrue(Reader.Global.HelpInsight.Enabled);
      Assert.AreEqual(940, Reader.Global.HelpInsight.Width);
      Assert.AreEqual(11, Reader.Global.HelpInsight.FontSize);
      Assert.AreEqual(140, Reader.Global.HelpInsight.LineHeight);
      Assert.AreEqual(240, Reader.Global.HelpInsight.ParameterWidth);
      Assert.IsFalse(Reader.Global.HelpInsight.WrapSignature);
      Assert.IsFalse(Reader.Global.HelpInsight.CompactParameters);
    finally Reader.Free; end;
  finally
    Writer.Free; R := TRegistry.Create(KEY_ALL_ACCESS);
    try R.RootKey := HKEY_CURRENT_USER; R.DeleteKey(Root); finally R.Free; end;
  end;
end;

procedure THelpInsightTests.LegacyExperimentIsReplaced;
var S: THelpInsightSettings; Css: string;
begin
  Css := 'body { color: WindowText; }' + sLineBreak +
    '/* Compact Help Insight for Delphi 12. Original theme colours are preserved. */' + sLineBreak +
    'body { width: 720px; } dd p { margin: 0; }' + sLineBreak + '/* later user CSS */';
  S := THelpInsightSettings.Defaults; S.Enabled := True; S.Width := 800;
  Css := UpdateHelpInsightCss(Css, S);
  Assert.IsTrue(Css.Contains('/* later user CSS */'));
  Assert.IsTrue(Css.Contains('color: WindowText'));
  Assert.IsFalse(Css.Contains('width: 720px'));
  Assert.IsTrue(Css.Contains('width: 800px'));
end;

procedure THelpInsightTests.ReadOnlyStylesheetCanBeExportedWithoutChangingOriginal;
var Root, Source, Destination: string; Settings: THelpInsightSettings;
begin
  Root := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  ForceDirectories(Root);
  Source := TPath.Combine(Root, 'protected.css');
  Destination := TPath.Combine(Root, 'export.css');
  try
    TFile.WriteAllText(Source, 'body { color: WindowText; }');
    if not SetFileAttributes(PChar(Source), FILE_ATTRIBUTE_READONLY) then RaiseLastOSError;
    Settings := THelpInsightSettings.Defaults; Settings.Enabled := True; Settings.Width := 900;
    Assert.WillRaise(procedure begin ApplyHelpInsightCss(Source, Settings); end, EOSError);
    Assert.AreEqual('body { color: WindowText; }', TFile.ReadAllText(Source));
    ExportHelpInsightCss(Source, Destination, Settings);
    Assert.IsTrue(TFile.ReadAllText(Destination).Contains('width: 900px'));
    Assert.IsTrue(TFile.ReadAllText(Destination).Contains('color: WindowText'));
    Assert.AreEqual('body { color: WindowText; }', TFile.ReadAllText(Source));
    Assert.WillRaise(procedure begin ExportHelpInsightCss(Source, Source, Settings); end, EArgumentException);
  finally
    for var FileName in TDirectory.GetFiles(Root) do SetFileAttributes(PChar(FileName), FILE_ATTRIBUTE_NORMAL);
    TDirectory.Delete(Root, True);
  end;
end;

procedure THelpInsightTests.ShellCopyKeepsFirstBackupAndAppliesChanges;
var Root, FileName: string; Settings: THelpInsightSettings;
begin
  Root := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  ForceDirectories(Root); FileName := TPath.Combine(Root, 'HelpInsight.css');
  try
    TFile.WriteAllText(FileName, 'body { color: WindowText; }');
    Settings := THelpInsightSettings.Defaults; Settings.Enabled := True;
    ApplyHelpInsightCssWithShell(FileName, Settings, 0);
    Assert.IsTrue(TFile.ReadAllText(FileName).Contains('width: 720px'));
    Settings.Width := 880;
    ApplyHelpInsightCssWithShell(FileName, Settings, 0);
    Assert.IsTrue(TFile.ReadAllText(FileName).Contains('width: 880px'));
    Assert.AreEqual('body { color: WindowText; }', TFile.ReadAllText(FileName + '.xmldocplugin.bak'));
    Settings.Enabled := False;
    ApplyHelpInsightCssWithShell(FileName, Settings, 0);
    Assert.AreEqual('body { color: WindowText; }', TFile.ReadAllText(FileName));
  finally TDirectory.Delete(Root, True); end;
end;

procedure THelpInsightTests.ExtendedTransformAndSafeMarkup;
var S:THelpInsightSettings;Html,Xml:string;
begin
 S:=THelpInsightSettings.Defaults;S.Enabled:=True;S.Extended:=True;
 Xml:='<member DisplayName="TWorker.Run" ><source declaredIn="Work.pas" declaredOn="12" declaredAt="4"/><summary><para>Пример <b>bold</b><br/><i>italic</i></para></summary>'+
  '<param name="Value" type="Integer"><para>First</para><para>Second</para></param><returns>Result</returns><exception cref="EAbort">Raised</exception><remarks>'+
  '<list type="bullet"><item><description>Bullet</description></item></list><list type="number"><item><description>Number</description></item></list>'+
  '<list type="table"><listheader><term>Key</term><description>Meaning</description></listheader><item><term>A</term><description>B</description></item></list>'+
  '<note type="caller">Callers</note><see cref="TList&lt;Integer&gt;"/><see href="javascript:bad()">Unsafe</see><script>bad()</script></remarks></member>';
 for var Palette in [THelpInsightPalette.Light,THelpInsightPalette.Dark] do begin
  Html:=RenderHelpInsightPreview(Xml,S,Palette);
  Assert.IsTrue(Html.Contains(Palette.Background));Assert.IsTrue(Html.Contains(Palette.Foreground));
  for var Expected in ['TWorker.Run','helpinsight:/filelink:Work.pas?12,4','helpinsight:/typelink:TList{Integer}','<ul>','<ol>','<table','<th>','hint-note','First','Second','Raised','Пример'] do Assert.IsTrue(Html.Contains(Expected),Expected);
  Assert.IsFalse(Html.Contains('bad()'));Assert.IsFalse(Html.Contains('<script'));
 end;
 for var Round:=0 to 127 do begin
  var Open:='para';if Odd(Round) then Open:='b';if Round mod 3=0 then Open:='i';
  Xml:='<member DisplayName="A&amp;B"><summary><'+Open+'>payload '+IntToStr(Round)+' &amp; &lt; 中文 Пример<br/></'+Open+'><para/><b/><br/></summary></member>';
  Html:=RenderHelpInsightPreview(Xml,S,THelpInsightPalette.Dark);
  Assert.IsTrue(Html.Contains('payload '+IntToStr(Round)),IntToStr(Round));Assert.IsFalse(Html.Contains('@@'));
 end;
 var OldLanguage:=TI18n.Instance.CurrentLanguage;
 try
  for var Language in ['en','ru','zh','ko','ja'] do begin
   TI18n.Instance.SetLanguage(Language);
   Html:=RenderHelpInsightPreview('<member DisplayName="Run"><param name="Value">payload</param><returns>result</returns></member>',S,THelpInsightPalette.Light);
   Assert.IsTrue(Html.Contains(TI18n.Instance.T('Parameters')),Language);
   Assert.IsTrue(Html.Contains(TI18n.Instance.T('Returns')),Language);
   Assert.IsTrue(Html.Contains('Value'),'Parameter identifiers are not translated');
  end;
 finally TI18n.Instance.SetLanguage(OldLanguage);end;
 S.Width:=0;S.ParameterWidth:=-1;
 Assert.IsTrue(BuildEnhancedHelpInsightCss(S,THelpInsightPalette.Light).Contains('width:80px'));
 Assert.WillRaise(procedure begin RenderHelpInsightPreview('<!DOCTYPE member [<!ENTITY x SYSTEM "file:///C:/Windows/win.ini">]><member><summary>&x;</summary></member>',S,THelpInsightPalette.Light);end,EArgumentException);
end;

procedure THelpInsightTests.PresentationSwitchAndRollback;
var Root,Css,Xsl:string;S:THelpInsightSettings;Original:TBytes;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);ForceDirectories(Root);Css:=TPath.Combine(Root,'HelpInsight.css');Xsl:=ChangeFileExt(Css,'.xsl');
 try
  S:=THelpInsightSettings.Defaults;ApplyHelpInsightPresentation(Css,S,THelpInsightPalette.Light);Assert.IsFalse(TFile.Exists(Css));
  TFile.WriteAllText(Css,'body { color: WindowText; }');TFile.WriteAllText(Xsl,'original template',TEncoding.Unicode);Original:=TFile.ReadAllBytes(Xsl);
  S:=THelpInsightSettings.Defaults;S.Enabled:=True;S.Extended:=True;
  ApplyHelpInsightPresentation(Css,S,THelpInsightPalette.Dark);Assert.IsTrue(TFile.ReadAllText(Xsl).Contains('XmlDocPlugin native Help Insight'));
  ApplyHelpInsightPresentation(Css,S,THelpInsightPalette.Light);Assert.IsTrue(TFile.ReadAllText(Css).Contains('#ffffff'));
  Assert.AreEqual(TEncoding.Unicode.GetString(Original),TEncoding.Unicode.GetString(TFile.ReadAllBytes(Xsl+'.xmldocplugin.bak')));
  S.Extended:=False;ApplyHelpInsightPresentation(Css,S,THelpInsightPalette.Light);
  Assert.AreEqual(TEncoding.Unicode.GetString(Original),TEncoding.Unicode.GetString(TFile.ReadAllBytes(Xsl)));
  S.Extended:=True;var Locked:=TFileStream.Create(Css,fmOpenRead or fmShareExclusive);
  try Assert.WillRaise(procedure begin ApplyHelpInsightPresentation(Css,S,THelpInsightPalette.Dark);end,EInOutError);
  finally Locked.Free;end;
  Assert.AreEqual(TEncoding.Unicode.GetString(Original),TEncoding.Unicode.GetString(TFile.ReadAllBytes(Xsl)));
  ApplyHelpInsightPresentation(Css,S,THelpInsightPalette.Dark);RestoreHelpInsightTemplates(Css);
  Assert.AreEqual('body { color: WindowText; }',TFile.ReadAllText(Css));Assert.AreEqual(TEncoding.Unicode.GetString(Original),TEncoding.Unicode.GetString(TFile.ReadAllBytes(Xsl)));
  ForceDirectories(TPath.Combine(Root,'en'));
  var Localized:=TPath.Combine(Root,'en\HelpInsight.xsl');TFile.WriteAllText(Localized,'localized original');
  ApplyHelpInsightPresentation(Css,S,THelpInsightPalette.Dark,Localized);
  Assert.IsTrue(TFile.ReadAllText(Xsl).Contains('xmldoc-hint'),'LSP root template');
  Assert.IsTrue(TFile.ReadAllText(Localized).Contains('xmldoc-hint'),'Legacy localized template');
  S.Extended:=False;ApplyHelpInsightPresentation(Css,S,THelpInsightPalette.Light,Localized);
  Assert.AreEqual('localized original',TFile.ReadAllText(Localized));
  Assert.AreEqual(TEncoding.Unicode.GetString(Original),TEncoding.Unicode.GetString(TFile.ReadAllBytes(Xsl)));
  S.Extended:=True;ApplyHelpInsightPresentation(Css,S,THelpInsightPalette.Dark,Localized);RestoreHelpInsightTemplates(Css,Localized);
  Assert.AreEqual('localized original',TFile.ReadAllText(Localized));
  Assert.AreEqual(TEncoding.Unicode.GetString(Original),TEncoding.Unicode.GetString(TFile.ReadAllBytes(Xsl)));
 finally TDirectory.Delete(Root,True);end;
end;

procedure THelpInsightTests.ExtendedSettingsAndExport;
var Root,RegistryRoot,Css:string;Settings:TPluginSettings;S:TGlobalSettings;R:TRegistry;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);ForceDirectories(Root);RegistryRoot:='Software\XmlDocPlugin\Tests\'+TPath.GetRandomFileName;
 try
  Settings:=TPluginSettings.Create(RegistryRoot);try S:=Settings.Global;S.HelpInsight.Extended:=True;Settings.Global:=S;Settings.Save;finally Settings.Free;end;
  Settings:=TPluginSettings.Create(RegistryRoot);try Assert.IsTrue(Settings.Global.HelpInsight.Extended);finally Settings.Free;end;
  Css:=TPath.Combine(Root,'HelpInsight.css');TFile.WriteAllText(Css,'body{}');TFile.WriteAllText(ChangeFileExt(Css,'.xsl'),'original');ForceDirectories(TPath.Combine(Root,'export'));
  ForceDirectories(TPath.Combine(Root,'en'));var Localized:=TPath.Combine(Root,'en\HelpInsight.xsl');TFile.WriteAllText(Localized,'localized source');
  Assert.WillRaise(procedure begin ExportHelpInsightTemplates(Css,TPath.Combine(Root,'en\HelpInsight.css'),S.HelpInsight,THelpInsightPalette.Dark,Localized);end,EArgumentException);
  Assert.AreEqual('localized source',TFile.ReadAllText(Localized));
  S.HelpInsight.Enabled:=True;ExportHelpInsightTemplates(Css,TPath.Combine(Root,'export\HelpInsight.css'),S.HelpInsight,THelpInsightPalette.Dark);
  Assert.WillRaise(procedure begin ExportHelpInsightTemplates(Css,TPath.Combine(Root,'export\renamed.css'),S.HelpInsight,THelpInsightPalette.Dark);end,EArgumentException);
  Assert.AreEqual('original',TFile.ReadAllText(ChangeFileExt(Css,'.xsl')));Assert.IsTrue(TFile.ReadAllText(TPath.Combine(Root,'export\HelpInsight.xsl')).Contains('XmlDocPlugin native Help Insight'));
 finally
  TDirectory.Delete(Root,True);R:=TRegistry.Create;try R.RootKey:=HKEY_CURRENT_USER;R.DeleteKey(RegistryRoot+'\HelpInsight');R.DeleteKey(RegistryRoot);finally R.Free;end;
 end;
end;

initialization
  TDUnitX.RegisterTestFixture(THelpInsightTests);
end.

