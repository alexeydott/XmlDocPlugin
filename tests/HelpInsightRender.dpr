program HelpInsightRender;
{$APPTYPE CONSOLE}
uses System.SysUtils,System.IOUtils,Winapi.ActiveX,XmlDoc.Plugin.HelpInsight;
begin
 CoInitialize(nil);
 try
  var S:=THelpInsightSettings.Defaults;S.Enabled:=True;S.Extended:=True;S.FontSize:=10;
  var Palette:=THelpInsightPalette.Light;if SameText(ParamStr(2),'Dark') then Palette:=THelpInsightPalette.Dark;
  if ParamStr(1)='apply' then ApplyHelpInsightPresentation(ParamStr(3),S,Palette,ParamStr(4))
  else if ParamStr(1)='render' then TFile.WriteAllText(ParamStr(4),RenderHelpInsightPreview(TFile.ReadAllText(ParamStr(3),TEncoding.UTF8),S,Palette),TEncoding.UTF8)
  else raise EArgumentException.Create('Expected apply or render');
 finally CoUninitialize;end;
end.
