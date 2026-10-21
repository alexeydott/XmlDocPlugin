unit HelpInsightProbe;
interface
procedure Register;
implementation
uses System.SysUtils,System.Classes,System.IOUtils,System.JSON,System.Win.Registry,
 Winapi.Windows,Winapi.Messages,Vcl.Forms,Vcl.Controls,Vcl.ExtCtrls,Vcl.ActnList,Vcl.Menus,ToolsAPI,
 XmlDoc.Plugin.HelpInsight,XmlDoc.Plugin.Settings,XmlDoc.Plugin.SettingsDialog,
 XmlDoc.Plugin.EditSession;
type THintProbe=class(TComponent)
 private Timer:TTimer;Root,FileName,Css,Xsl:string;CssBefore,XslBefore,RootXslBefore:TBytes;
  SettingsBefore:TGlobalSettings;Started,PendingHint:Boolean;Step:Integer;
  procedure Tick(Sender:TObject);procedure Log(const Text:string);procedure ShowHint(const SymbolName:string);procedure InvokeHint;
 public constructor Create;destructor Destroy;override;
end;
var Probe:THintProbe;
constructor THintProbe.Create;
begin
 inherited Create(nil);Root:=GetEnvironmentVariable('XMLDOC_HINT_ROOT');
 Timer:=TTimer.Create(Self);Timer.Interval:=15000;Timer.OnTimer:=Tick;Timer.Enabled:=True;
end;
procedure THintProbe.Log(const Text:string);
begin TFile.AppendAllText(TPath.Combine(Root,'runtime.log'),Text+sLineBreak,TEncoding.UTF8);end;
procedure THintProbe.ShowHint(const SymbolName:string);
var Services:IOTAModuleServices;Module:IOTAModule;Hint:IOTAHelpInsight;Editor:IOTASourceEditor;Source:string;Line,Col,Width:Integer;Pos:TOTAEditPos;
begin
 if not (BorlandIDEServices as IOTAActionServices).OpenFile(FileName) then raise Exception.Create('Fixture did not open');
 Editor:=SourceEditorForFile(FileName);Source:=EditorSource(Editor);
 var At:=Source.LastIndexOf(SymbolName);if At<0 then raise Exception.Create('Call is absent: '+SymbolName);
 var UnitAt:=Source.IndexOf(SymbolName+' in ');if UnitAt>=0 then At:=UnitAt;
 Line:=1;Col:=1;for var I:=1 to At do if Source[I]=#10 then begin Inc(Line);Col:=1;end else Inc(Col);
 Inc(Col,SymbolName.LastIndexOf('.')+4);Pos.Line:=Line;Pos.Col:=Col;Editor.EditViews[0].SetCursorPos(Pos);Editor.EditViews[0].MoveViewToCursor;Editor.Show;
 Services:=BorlandIDEServices as IOTAModuleServices;Module:=Services.FindModule(FileName);
 if Supports(Module,IOTAHelpInsight,Hint) then begin
  Width:=720;var Html:=string(Hint.GetEditorDocInfo(Line,Col,Width));
  TFile.WriteAllText(TPath.Combine(Root,'native-hint.html'),Html,TEncoding.UTF8);Log('Native Help Insight enabled='+BoolToStr(Hint.IsEnabled,True)+' html bytes='+IntToStr(Length(Html)));
 end else Log('Module uses asynchronous Help Insight');
 PendingHint:=True;Log('Prepared hint at '+IntToStr(Line)+':'+IntToStr(Col));
end;
procedure THintProbe.InvokeHint;
begin
 var Actions:=(BorlandIDEServices as INTAServices).ActionList;var Found:=False;
 for var I:=0 to Actions.ActionCount-1 do if Actions.Actions[I] is TAction then begin
  var A:=TAction(Actions.Actions[I]);if LowerCase(A.Name).Contains('helpinsight') then begin
   A.Update;Log('Hint action '+A.Name+' enabled='+BoolToStr(A.Enabled,True));
   if not Found and A.Enabled then begin A.Execute;Found:=True;end;
  end;
 end;
 Log('Hint invoked='+BoolToStr(Found,True));
 var Services:=BorlandIDEServices as IOTACodeInsightServices;
 var Manager:IOTACodeInsightManager;Services.GetCurrentCodeInsightManager(Manager);
 if Assigned(Manager) then Log('Current manager '+Manager.Name+' '+Manager.GetIDString) else Log('No active code insight manager');
 for var Index:=0 to Services.CodeInsightManagerCount-1 do begin
  Manager:=Services.CodeInsightManager[Index];Log('Manager '+Manager.Name+' '+Manager.GetIDString+' enabled='+BoolToStr(Manager.Enabled,True));
  var Options:IOTACodeInsightManagerEnvOptions;
  if Supports(Manager,IOTACodeInsightManagerEnvOptions,Options) then Log('Native Help Insight visible='+BoolToStr(Options.IsToolTipHelpInsightVisible,True));
 end;
end;
procedure THintProbe.Tick(Sender:TObject);
var NativeClassName:array[0..255] of Char;
begin
 Timer.Enabled:=False;
 try
  if PendingHint then begin PendingHint:=False;InvokeHint;end;
  if not Started then begin
   Log('IDE registry '+(BorlandIDEServices as IOTAServices).GetBaseRegistryKey);Css:=HelpInsightCssPath;Xsl:=IDEHelpInsightXsltPath;CssBefore:=TFile.ReadAllBytes(TPath.Combine(Root,'original.css'));XslBefore:=TFile.ReadAllBytes(TPath.Combine(Root,'original.xsl'));RootXslBefore:=TFile.ReadAllBytes(TPath.Combine(Root,'original-root.xsl'));SettingsBefore:=TPluginSettings.Instance.Global;Started:=True;
   var S:=SettingsBefore;S.HelpInsight.Enabled:=True;S.HelpInsight.Extended:=True;S.HelpInsight.Width:=720;S.HelpInsight.FontSize:=10;
   var Appearance:=TPath.Combine(Root,'appearance.txt');if TFile.Exists(Appearance) then S.HelpInsight.Extended:=not SameText(TFile.ReadAllText(Appearance).Trim,'IDEdefault');
   TPluginSettings.Instance.Global:=S;
   ApplyHelpInsightPresentation(Css,S.HelpInsight,IDEHelpInsightPalette,Xsl);Log('Template path '+Css);if (BorlandIDEServices as IOTAIDEThemingServices).IDEThemingEnabled then Log('Theme '+(BorlandIDEServices as IOTAIDEThemingServices).ActiveTheme) else Log('Theme disabled (native light)');Log('Applied extended hint background='+IDEHelpInsightPalette.Background);
   var Capture:=TPath.Combine(Root,'capture.xsl');
   if TFile.Exists(Capture) then begin TFile.Copy(Capture,Xsl,True);TFile.Copy(Capture,ChangeFileExt(Css,'.xsl'),True);end;
   FileName:=TPath.Combine(Root,'LongHintParagraphs.dpr');
   var ProjectName:=FileName;
   if TFile.Exists(TPath.Combine(Root,'project.txt')) then begin
    ProjectName:=TFile.ReadAllText(TPath.Combine(Root,'project.txt')).Trim;
    FileName:=ChangeFileExt(ProjectName,'.dpr');
   end;
   (BorlandIDEServices as IOTAActionServices).OpenProject(ProjectName,True);Step:=1;
  end else if Step=1 then begin
   var InitialSymbol:='TMapDocumentation.PrepareAndRenderMapWithClippingAndPixelDensity';
   if TFile.Exists(TPath.Combine(Root,'initial-symbol.txt')) then InitialSymbol:=TFile.ReadAllText(TPath.Combine(Root,'initial-symbol.txt')).Trim;
   ShowHint(InitialSymbol);Step:=2;Log('READY');
  end else begin
   var Command:=TPath.Combine(Root,'command.json');
   if TFile.Exists(Command) then begin
    var J:=TJSONObject.ParseJSONValue(TFile.ReadAllText(Command,TEncoding.UTF8)) as TJSONObject;TFile.Delete(Command);
    try var Action:=J.GetValue<string>('action');
     if Action='show' then ShowHint(J.GetValue<string>('symbol','TMapDocumentation.PrepareAndRenderMapWithClippingAndPixelDensity'))
     else if Action='settings' then ShowSettingsDialog
     else if Action='actions' then begin
      var Actions:=(BorlandIDEServices as INTAServices).ActionList;
      for var I:=0 to Actions.ActionCount-1 do if Actions.Actions[I] is TAction then begin var A:=TAction(Actions.Actions[I]);if LowerCase(A.Name).Contains('theme') then Log('Action '+A.Name+' '+A.Caption);end;
     end
     else if Action='theme' then begin
      var ThemeActions:=(BorlandIDEServices as INTAServices).ActionList;
      for var ThemeIndex:=0 to ThemeActions.ActionCount-1 do if SameText(ThemeActions.Actions[ThemeIndex].Name,J.GetValue<string>('name')) and (ThemeActions.Actions[ThemeIndex] is TAction) then TAction(ThemeActions.Actions[ThemeIndex]).Execute;
     end
     else if Action='open' then begin FileName:=TPath.Combine(Root,J.GetValue<string>('file'));(BorlandIDEServices as IOTAActionServices).OpenProject(FileName,True);end
     else if (Action='dpi') or (Action='windows') then begin
      var H:=GetWindow(GetDesktopWindow,GW_CHILD);
      while H<>0 do begin
       var ProcessId:DWORD;GetWindowThreadProcessId(H,ProcessId);
       if ProcessId=GetCurrentProcessId then begin
        var Control:=FindControl(H);
        if IsWindowVisible(H) then begin GetClassName(H,NativeClassName,Length(NativeClassName));Log('Visible native window '+string(NativeClassName)+' DPI='+IntToStr(GetDpiForWindow(H)));end;
        if Assigned(Control) and IsWindowVisible(H) then begin
         Log('Native window '+Control.ClassName+' '+IntToStr(Control.Width)+'x'+IntToStr(Control.Height)+' PPI='+IntToStr(Control.CurrentPPI));
         if (Action='dpi') and Control.ClassName.ToLower.Contains('hint') then begin Control.ScaleForPPI(J.GetValue<Integer>('ppi'));Log('SCALED '+Control.ClassName+' PPI='+IntToStr(Control.CurrentPPI)+' '+IntToStr(Control.Width)+'x'+IntToStr(Control.Height));end;
        end;
       end;
       H:=GetWindow(H,GW_HWNDNEXT);
      end;
     end
     else if Action='close' then begin
      TFile.WriteAllBytes(Css,CssBefore);TFile.WriteAllBytes(Xsl,XslBefore);TFile.WriteAllBytes(ChangeFileExt(Css,'.xsl'),RootXslBefore);TPluginSettings.Instance.Global:=SettingsBefore;Log('RESTORED');
      var Services:=BorlandIDEServices as IOTAModuleServices;
      if Assigned(Services.GetActiveProject) then Services.GetActiveProject.CloseModule(True);
      if Assigned(Services.MainProjectGroup) then Services.MainProjectGroup.CloseModule(True);
      var Menu:=(BorlandIDEServices as INTAServices).MainMenu;
      for var Item in Menu.Items do if SameText(Item.Name,'FileMenu') or StringReplace(Item.Caption,'&','',[rfReplaceAll]).Equals('File') then
       for var Child in Item do if StringReplace(Child.Caption,'&','',[rfReplaceAll]).Equals('Exit') then Child.Click;
     end;
    finally J.Free;end;
   end;
  end;
 except on E:Exception do Log('ERROR '+E.ClassName+': '+E.Message);end;
 Timer.Interval:=1000;Timer.Enabled:=True;
end;
destructor THintProbe.Destroy;
begin
 Timer.Enabled:=False;
 if Started then begin TFile.WriteAllBytes(Css,CssBefore);TFile.WriteAllBytes(Xsl,XslBefore);TFile.WriteAllBytes(ChangeFileExt(Css,'.xsl'),RootXslBefore);TPluginSettings.Instance.Global:=SettingsBefore;end;
 inherited;
end;
procedure Register;
begin if (Probe=nil) and (GetEnvironmentVariable('XMLDOC_HINT_ROOT')<>'') then Probe:=THintProbe.Create;end;
initialization
finalization
 Probe.Free;
end.



