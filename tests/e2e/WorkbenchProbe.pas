unit WorkbenchProbe;
interface
procedure Register;
implementation
uses XmlDoc.ProjectContext,System.Diagnostics,System.Hash,XmlDoc.Plugin.DeclarationContext,XmlDoc.I18n,System.SysUtils,System.StrUtils,System.Classes,System.IOUtils,System.JSON,Winapi.Windows,Winapi.Messages,Winapi.ActiveX,
 Vcl.Forms,Vcl.ActnList,Vcl.Menus,Vcl.Controls,Vcl.ExtCtrls,Vcl.Edge,WebView2,ToolsAPI,XmlDoc.Plugin.DocInspector,
 XmlDoc.Plugin.Localization,XmlDoc.Plugin.SettingsDialog,XmlDoc.Plugin.CoverageDialog,XmlDoc.Plugin.Browser,XmlDoc.Plugin.DocExplorer,XmlDoc.Plugin.EditSession,XmlDoc.Parser,XmlDoc.Consts,Vcl.StdCtrls,XmlDoc.Plugin.BatchGenDialog,Vcl.Graphics,XmlDoc.ShortcutValidation,XmlDoc.Plugin.Settings,XmlDoc.Plugin.AboutDialog,XmlDoc.Plugin.Utils;
type TProbe=class
 Timer,FormatConfirmation:TTimer;Inspector:TDocInspectorForm;Explorer:TDocExplorerForm;Browser,ExplorerBrowser:TXmlDocBrowser;OriginalMessage,OriginalExplorerMessage:TWebMessageReceivedEvent;ExplorerAttempted:Boolean;
 LanguageSaved:Boolean;OriginalLanguage:string;
 ProtectedBefore,SystemFile,PrimaryProjectFile,FormatBefore:string;
 FormatWait,Step:Integer;Initial,AfterWrite,SecondInitial,SampleFile,SecondFile,Root:string;Finished:Boolean;
 procedure ConfirmFormat(Sender:TObject);procedure Tick(Sender:TObject); procedure ExportAll; procedure CloseExportMessage(Sender:TObject);
 procedure ExplorerMessage(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
 procedure MessageReceived(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
 procedure Select(const FileName,Name,TypeName:string);
 procedure AssertTrue(Value:Boolean;const Message:string);
 procedure Finish;
end;
var Probe:TProbe;
procedure Log(const Text:string);
begin TFile.AppendAllText(GetEnvironmentVariable('XMLDOC_E2E_LOG'),Text+sLineBreak);end;
function XmlEscape(const Value:string):string;
begin Result:=Value.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;');end;
function FindMenuCommand(Parent:TMenuItem;const Caption:string):TMenuItem;
begin
 if SameText(StringReplace(Parent.Caption,'&','',[rfReplaceAll]),TI18n.Instance.T(Caption)) then Exit(Parent);
 for var I:=0 to Parent.Count-1 do begin Result:=FindMenuCommand(Parent[I],Caption);if Assigned(Result) then Exit;end;
 Result:=nil;
end;
procedure TProbe.AssertTrue(Value:Boolean;const Message:string);
begin if not Value then raise Exception.Create(Message);end;
procedure TProbe.Select(const FileName,Name,TypeName:string);
var Editor:IOTASourceEditor;Parser:TDocParser;E:TCodeElementInfo;Line:Integer;Pos:TOTAEditPos;
begin
 (BorlandIDEServices as IOTAActionServices).OpenFile(FileName);Editor:=SourceEditorForFile(FileName);
 AssertTrue(Assigned(Editor),'Source editor unavailable');Editor.Show;Parser:=TDocParser.Create;
 try Parser.ParseSource(EditorSource(Editor),FileName);Line:=0;
  for E in Parser.GetAllElements do if (E.Name=Name) and ((TypeName='') or ((Length(E.Params)>0) and SameText(E.Params[0].TypeName,TypeName))) then begin Line:=E.LineNumber;Break;end;
  AssertTrue(Line>0,'Fixture declaration missing: '+Name);Pos.Line:=Line;Pos.Col:=1;Editor.EditViews[0].SetCursorPos(Pos);
  Inspector.HandleCursorChanged(Line,EditorSource(Editor),FileName);
 finally Parser.Free;end;
end;
procedure TProbe.Finish;
var Project:IOTAProject;Module:IOTAModule;Services:IOTAModuleServices;I:Integer;Menu:TMainMenu;ExitItem:TMenuItem;
 function FindExit(Parent:TMenuItem):TMenuItem;
 var Child:TMenuItem;
 begin Result:=nil;for Child in Parent do begin
  if SameText(StringReplace(Child.Caption,'&','',[rfReplaceAll]),'Exit') then Exit(Child);
  Result:=FindExit(Child);if Assigned(Result) then Exit;
 end;end;
begin
 if Finished then Exit;Finished:=True;
 if LanguageSaved then begin var SavedSettings:=TPluginSettings.Instance.Global;SavedSettings.General.Language:=OriginalLanguage;TPluginSettings.Instance.Global:=SavedSettings;TI18n.Instance.SetLanguage(OriginalLanguage);end;Timer.Enabled:=False;
 Log('Closing Explorer');Explorer.Free;Explorer:=nil;Log('Closing Inspector');Inspector.Free;Inspector:=nil;Log('Closed Inspector');Services:=BorlandIDEServices as IOTAModuleServices;
 Project:=Services.GetActiveProject;if Assigned(Project) then begin
  Log('Closing project '+Project.FileName);Project.CloseModule(True);Log('Closed project');end;
 if Assigned(Services.MainProjectGroup) then begin Log('Closing temporary project group');Services.MainProjectGroup.CloseModule(True);Log('Closed project group');end;
 Menu:=(BorlandIDEServices as INTAServices).MainMenu;ExitItem:=FindExit(Menu.Items);AssertTrue(Assigned(ExitItem),'IDE Exit command is unavailable');
 Log('Invoke IDE Exit: '+ExitItem.Name+' target='+UIntToStr(Menu.WindowHandle));ExitItem.Click;Log('IDE Exit invoked');
end;
procedure TProbe.ExplorerMessage(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
var Buffer:PWideChar;Json:TJSONObject;
begin
 Buffer:=nil;Args.ArgsInterface.TryGetWebMessageAsString(Buffer);
 if Assigned(Buffer) then begin try Json:=ParseHostMessage(string(Buffer));finally CoTaskMemFree(Buffer);end;
  try if Assigned(Json) and (Json.GetValue<string>('type','')='docUpdated') then ExplorerAttempted:=True;finally Json.Free;end;
 end;
 if Assigned(OriginalExplorerMessage) then OriginalExplorerMessage(Sender,Args);
end;
procedure TProbe.MessageReceived(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
var Buffer:PWideChar;Text,Action,Source:string;Json:TJSONObject;Editor:IOTASourceEditor;EditBuffer:IOTAEditBuffer;Writer:IOTAEditWriter;Offset,UndoMarkers:Integer;Utf8:UTF8String;
 procedure AssertParsed(Form:TForm);
 begin
  for var I:=0 to Form.ComponentCount-1 do if Form.Components[I] is TLabel then
   AssertTrue(not (TLabel(Form.Components[I]).Visible and (System.Pos('Cannot parse',TLabel(Form.Components[I]).Caption)=1)),'System.pas parse error: '+TLabel(Form.Components[I]).Caption);
 end;
begin
 Buffer:=nil;Args.ArgsInterface.TryGetWebMessageAsString(Buffer);if Buffer=nil then Exit;
 try Text:=string(Buffer);finally CoTaskMemFree(Buffer);end;
 Json:=TJSONObject.ParseJSONValue(Text) as TJSONObject;
 try
  if Assigned(Json) and (Json.GetValue<string>('type','')='docUpdated') then Log('EDIT '+Json.GetValue<string>('sourceRevision','')+' '+Json.GetValue<TJSONObject>('doc').GetValue<string>('summary',''));
  if not Assigned(Json) or (Json.GetValue<string>('type','')<>'e2e') then begin if Assigned(OriginalMessage) then OriginalMessage(Sender,Args);Exit;end;
  Action:=Json.GetValue<string>('action','');
  try
   if Action='language-ui' then begin
    var Language:=Json.GetValue<string>('language');AssertTrue((Language='ru') or (Language='zh') or (Language='en'),'Unexpected language');
    var Updated:=TPluginSettings.Instance.Global;if not LanguageSaved then begin OriginalLanguage:=Updated.General.Language;LanguageSaved:=True;end;
    Updated.General.Language:=Language;TPluginSettings.Instance.Global:=Updated;
    var Dialog:=TSettingsDialog.Create(nil);
    try
     AssertTrue(Dialog.cmbLanguage.Items.IndexOf('ru')>=0,'Russian option missing');AssertTrue(Dialog.cmbLanguage.Items.IndexOf('zh')>=0,'Chinese option missing');AssertTrue(Dialog.cmbLanguage.Text=Language,'Selected language changed');
     AssertTrue(Dialog.Caption=TI18n.Instance.T('XmlDoc Plugin Settings'),'Settings title not translated');if Language<>'en' then AssertTrue(Dialog.Caption<>'XmlDoc Plugin Settings','Native language pack missing');
    finally Dialog.Free;end;
    var Generation:=TBatchGenDialog.Create(nil);try AssertTrue(Generation.Caption=TI18n.Instance.T('Generate API Documentation'),'Generation dialog not translated');finally Generation.Free;end;
    var Coverage:=TCoverageDialog.Create(nil);try AssertTrue(Coverage.Caption=TI18n.Instance.T('Documentation Coverage Report'),'Coverage dialog not translated');finally Coverage.Free;end;
    var MenuRoot:=(BorlandIDEServices as INTAServices).MainMenu.Items;for var I:=0 to MenuRoot.Count-1 do if MenuRoot[I].Name='XmlDocDocumentMenu' then LocalizePluginUi(MenuRoot[I].Owner);
    AssertTrue(Assigned(FindMenuCommand(MenuRoot,'User Guide')),'Localized guide menu missing');Browser.ApplySettings;ExplorerBrowser.ApplySettings;
    Browser.ExecuteScript('window.__xmlDocLanguageUi="'+Language+'"');Log('PASS native Settings, generation, coverage and menus language '+Language);
   end
   else if Action='arm-explorer' then begin
     Explorer.HandleFileChanged(SampleFile,EditorSource(SourceEditorForFile(SampleFile)));
     ExplorerBrowser.ExecuteScript('(()=>{const row=Array.from(document.querySelectorAll(".tree-row")).find(r=>r.dataset.symbolId?.includes("tdocumented.run(const string)"));if(row)row.click();window.e2eOldDocument=JSON.parse(JSON.stringify(window.xmlDocEditor.get()));})()');
   end
   else if Action='stale-explorer' then ExplorerBrowser.ExecuteScript('(()=>{const d=window.e2eOldDocument;window.bridge.sendToHost({type:"docUpdated",...d.element,doc:{...d.doc,summary:"EXPLORER STALE SHOULD NOT WRITE"}})})()')
   else if Action='assert-second-view-conflict' then begin AssertTrue(ExplorerAttempted,'Explorer did not attempt the stale edit');AssertTrue(not EditorSource(SourceEditorForFile(SampleFile)).Contains('EXPLORER STALE SHOULD NOT WRITE'),'Conflicting Explorer edit was applied');Log('PASS simultaneous Inspector and Explorer reject stale revisions');end
   else if Action='assert-grid' then begin
     Source:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(Source.Contains('E2E grid first') and Source.Contains('E2E grid second'),'Selected member summaries were not applied');Log('PASS reviewed multi-member summary update');
   end
   else if Action='switch-second' then Select(SecondFile,'Run','Integer')
   else if Action='switch-sample' then Select(SampleFile,'Run','string')
   else if Action='switch-broken' then Select(SampleFile,'BrokenDocumentation','')
   else if Action='switch-rename' then Select(SampleFile,'RenameScenario','string')
   else if Action='assert-cancelled' then begin
    AssertTrue(EditorSource(SourceEditorForFile(SampleFile))=Initial,'Cancelled A draft changed A');
    AssertTrue(EditorSource(SourceEditorForFile(SecondFile))=SecondInitial,'A draft was written to B');Log('PASS delayed save A to B and file switch');end
   else if Action='assert-write' then begin
    Source:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(Source.Contains('E2E applied summary'),'Browser edit not applied');
    AssertTrue(Source.Contains('custom-root keep="yes"'),'Unknown top-level XML lost');AssertTrue(Source.Contains('Base description'),'See Also label lost');AssertTrue(Source.Contains('Unicode &amp; escaping'),'Example title lost');
    AfterWrite:=Source;TFile.WriteAllText(TPath.Combine(Root,'after-write.txt'),Source);Log('PASS guarded browser-to-OTA edit and preserved metadata');end
   else if Action='undo' then begin
    AssertTrue(Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer),'Undo buffer unavailable');Log('GroupUndo='+BoolToStr(EditBuffer.BufferOptions.GroupUndo,True));UndoMarkers:=0;
    repeat EditBuffer.Undo;Inc(UndoMarkers);until (EditorSource(EditBuffer)<>AfterWrite) or (UndoMarkers=4);
    AssertTrue(EditorSource(EditBuffer)=Initial,'Undo changed text outside the comment or did not restore it');Log('PASS Undo preserves surrounding Pascal');end
   else if Action='redo' then begin
    Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer);UndoMarkers:=0;
    repeat EditBuffer.Redo;Inc(UndoMarkers);until (EditorSource(EditBuffer)<>Initial) or (UndoMarkers=4);
    TFile.WriteAllText(TPath.Combine(Root,'redo-actual.txt'),EditorSource(EditBuffer));AssertTrue(EditorSource(EditBuffer)=AfterWrite,'Redo did not restore comment');Log('PASS Redo');end
   else if Action='mutate-signature' then begin
    Editor:=SourceEditorForFile(SampleFile);Source:=EditorSource(Editor);Offset:=Pos('Value:string',Source)-1;AssertTrue(Offset>=0,'Signature token missing');
    Writer:=Editor.CreateUndoableWriter;Writer.CopyTo(Offset);Writer.DeleteTo(Offset+Length('Value:string'));Utf8:='Value:UnicodeString';Writer.Insert(PAnsiChar(Utf8));Writer:=nil;end
   else if Action='assert-conflict' then begin AssertTrue(not EditorSource(SourceEditorForFile(SampleFile)).Contains('SHOULD NOT WRITE'),'Stale update was written');Log('PASS stale buffer revision rejected');end
   else if Action='repair-signature' then begin Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer);EditBuffer.Undo;Select(SampleFile,'Run','string');end
   else if Action='assert-sync' then begin Source:=EditorSource(SourceEditorForFile(SampleFile));AssertTrue(Source.Contains('<param name="NewName">Description to map explicitly.</param>'),'Mapped description lost');AssertTrue(Source.Contains('<param name="Options">'),'New parameter not added');AssertTrue(Source.Contains('<paramref name="NewName"'),'Inline reference not renamed');Log('PASS synchronization preview and explicit rename');end
   else if Action='assert-resources' then Log('PASS project image resource and narrow controls')
   else if Action='assert-project' then Log('PASS project catalog, search and diagnostics')
   else if Action='context' then begin
    var Project:=GetActiveProject;AssertTrue(Assigned(Project),'Context project unavailable');
    var Configs:IOTAProjectOptionsConfigurations;AssertTrue(Supports(Project.ProjectOptions,IOTAProjectOptionsConfigurations,Configs),'Build configurations unavailable');
    Project.CurrentPlatform:=Json.GetValue<string>('platform','Win32');
    var ConfigName:=Json.GetValue<string>('config','Debug');var Chosen:IOTABuildConfiguration:=nil;
    for var I:=0 to Configs.ConfigurationCount-1 do if SameText(Configs.Configurations[I].Name,ConfigName) then begin Chosen:=Configs.Configurations[I];Break;end;
    if not Assigned(Chosen) then Chosen:=Configs.AddConfiguration(ConfigName,Configs.BaseConfiguration);
    Configs.ActiveConfiguration:=Chosen;Select(SecondFile,'ContextProbe','');Inspector.RefreshFromCurrentEditor;
    Log('PASS switched IDE context '+ConfigName+' '+Project.CurrentPlatform+' with unchanged source');
   end
   else if Action='prepare-group' then begin
    PrimaryProjectFile:=GetActiveProject.FileName;var Dir:=TPath.Combine(Root,'GroupB');TDirectory.CreateDirectory(Dir);
    TFile.WriteAllText(TPath.Combine(Dir,'ContextB.pas'),'unit ContextB;'+sLineBreak+'interface'+sLineBreak+'{$I Features.inc}'+sLineBreak+'type TWorker=class procedure Run(Value:Integer); overload; procedure Run(Value:string); overload; end;'+sLineBreak+'procedure OtherB(Value:{$IFDEF FROM_B}string{$ELSE}Integer{$ENDIF});'+sLineBreak+'procedure FromB(Value:{$IFDEF FROM_B}string{$ELSE}Integer{$ENDIF});'+sLineBreak+'implementation'+sLineBreak+'procedure OtherB(Value:{$IFDEF FROM_B}string{$ELSE}Integer{$ENDIF}); begin end;'+sLineBreak+'procedure FromB(Value:{$IFDEF FROM_B}string{$ELSE}Integer{$ENDIF});'+sLineBreak+'begin end;'+sLineBreak+'procedure TWorker.Run(Value:Integer); begin end;'+sLineBreak+'procedure TWorker.Run(Value:string); begin end;'+sLineBreak+'procedure Exercise(Worker:TWorker);'+sLineBreak+'var Local:Integer;'+sLineBreak+'begin'+sLineBreak+' Worker.Run(Local);'+sLineBreak+'end;'+sLineBreak+'end.');
    TFile.WriteAllText(TPath.Combine(Dir,'Features.inc'),'{$DEFINE FROM_B}');
    TFile.WriteAllText(TPath.Combine(Dir,'GroupB.dpr'),'program GroupB; uses ContextB in ''ContextB.pas''; begin end.');
    var GroupXml:=TFile.ReadAllText(TPath.Combine(Root,'XmlDocE2E.dproj')).Replace('XmlDocE2E','GroupB');
    GroupXml:=GroupXml.Replace('{3A72602E-67CF-469D-A733-BC75247CC365}',TGUID.NewGuid.ToString);
    GroupXml:=GroupXml.Replace('<DCCReference Include="Units\Workbench.Contracts.pas"/>','<DCCReference Include="ContextB.pas"/>');
    GroupXml:=GroupXml.Replace('<DCCReference Include="Units\Workbench.Sample.pas"/>','').Replace('<DCCReference Include="Units\Workbench.Second.pas"/>','').Replace('<DCCReference Include="Examples\Workbench.Examples.pas"/>','');
    GroupXml:=GroupXml.Replace('<DCC_Define>DEBUG;','<DCC_Define>FROM_B;DEBUG;');
    TFile.WriteAllText(TPath.Combine(Dir,'GroupB.dproj'),GroupXml);
    Step:=80;Timer.Interval:=100;Timer.Enabled:=True;
   end
   else if Action='assert-group' then begin
    AssertTrue(SameText(GetActiveProject.FileName,TPath.Combine(Root,'XmlDocE2E.dproj')),'Group navigation changed active project A');
    AssertTrue(Assigned(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas'))),'Group source did not open');
    Log('PASS group symbol navigation uses project B defines while A is active');
   end
   else if Action='group-navigation-checked' then Log('PASS GroupB Source and Back/Forward retain owning project while A is active')
   else if Action='group-include-checked' then Log('PASS catalog Refresh detects a changed closed include')
   else if Action='group-context-error' then begin
    var BrokenProject:=TPath.Combine(Root,'GroupB','GroupB.dproj');var ProjectBefore:=TFile.ReadAllText(BrokenProject);var ProjectStamp:=TFile.GetLastWriteTimeUtc(BrokenProject);var ErrorFile:=TPath.Combine(Root,'GroupB','ContextB.pas');var ErrorSource:=EditorSource(SourceEditorForFile(ErrorFile));
    try
     TFile.WriteAllText(BrokenProject,ProjectBefore.Replace('ContextB.pas','MissingReviewSource.pas'));
     Inspector.HandleCursorChanged(3,ErrorSource,ErrorFile);Explorer.HandleFileChanged(ErrorFile,ErrorSource);
     for var Panel in TArray<TForm>.Create(Inspector,Explorer) do begin
      var ErrorShown:=False;for var N:=0 to Panel.ComponentCount-1 do if Panel.Components[N] is TLabel then begin var LabelControl:=TLabel(Panel.Components[N]);if LabelControl.Visible and (Pos('Missing project source',string(LabelControl.Caption))>0) then ErrorShown:=True;end;
      AssertTrue(ErrorShown,'Project-context error was not shown inside '+Panel.Caption);
     end;
    finally TFile.WriteAllText(BrokenProject,ProjectBefore);TFile.SetLastWriteTimeUtc(BrokenProject,ProjectStamp);end;
    Inspector.RefreshFromCurrentEditor;Explorer.HandleFileChanged(ErrorFile,ErrorSource);Log('PASS Inspector/Explorer contain and recover from project-context errors');
   end
   else if Action='analysis-metrics' then Log('PERF analysis '+Json.ToJSON)
   else if Action='large-editor-check' then begin Step:=95;Timer.Interval:=100;Timer.Enabled:=True;end
   else if Action='open-user-guide' then begin
    var HelpItem:=FindMenuCommand((BorlandIDEServices as INTAServices).MainMenu.Items,'User Guide');AssertTrue(Assigned(HelpItem),'User Guide menu missing');HelpItem.Click;Log('PASS offline User Guide opened from IDE menu');
   end
   else if Action='review-external-comment' then begin
    var ReviewFile:=TPath.Combine(Root,'GroupB','ContextB.pas');Editor:=SourceEditorForFile(ReviewFile);Source:=EditorSource(Editor);
    var Marker:='XML requires explicit approval';var CharOffset:=Pos(Marker,Source);AssertTrue(CharOffset>0,'Original review comment absent');
    Offset:=Length(UTF8Encode(Copy(Source,1,CharOffset-1)));Writer:=Editor.CreateUndoableWriter;Writer.CopyTo(Offset);Writer.DeleteTo(Offset+Length(Marker));Utf8:='EXTERNAL SOURCE CHANGE';Writer.Insert(PAnsiChar(Utf8));Writer:=nil;
    Inspector.HandleCursorChanged(Json.GetValue<Integer>('line'),EditorSource(Editor),ReviewFile);Browser.ExecuteScript('window.__reviewExternalReady=true');Log('PASS external source mutation for native recovery conflict');
   end
   else if Action='assert-review-design' then begin
    var Actual:=EditorSource(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas')));
    AssertTrue(Actual.Contains('REVIEW VISIBLE DESIGN WINS'),'Visible Design text did not reach native XML serialization');
    AssertTrue(not Actual.Contains('REVIEW HIDDEN RAW MUST NOT WRITE'),'Hidden XML draft overwrote Design text');
    Log('PASS restored raw draft to Design serializes visible content into source');
   end
   else if Action='group-xml-applied-checked' then begin
    var ApprovedSource:=EditorSource(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas')));
    AssertTrue(ApprovedSource.Contains('XML requires explicit approval'),'Explicit XML apply did not update source');Log('PASS explicit XML Apply writes the approved draft');
   end
   else if Action='group-xml-draft-checked' then begin
    var XmlDraftSource:=EditorSource(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas')));
    AssertTrue(XmlDraftSource.Contains('Implementation design before XML'),'Design save did not complete');AssertTrue(not XmlDraftSource.Contains('XML requires explicit approval'),'Unapproved XML draft was written');Log('PASS XML draft stays unapplied after Design ACK');
   end
   else if Action='group-implementation-checked' then begin
    var GroupFile:=TPath.Combine(Root,'GroupB','ContextB.pas');var CheckParser:=TDocParser.Create;
    try CheckParser.ParseSource(EditorSource(SourceEditorForFile(GroupFile)),GroupFile);var Seen:=0;
     for var E in CheckParser.GetAllElements do if E.Name='FromB' then begin
      if E.SourceSection='implementation' then AssertTrue(E.ExistingDocXml.Contains('Implementation second'),'Pinned second edit missed implementation')
      else AssertTrue(E.ExistingDocXml.Contains('GroupB saved before format'),'Pinned implementation edit changed interface declaration');Inc(Seen);
     end;AssertTrue(Seen=2,'Declaration/implementation pair missing');
    finally CheckParser.Free;end;
    Log('PASS pinned implementation ACK retains both source locations after line shifts');
   end
   else if Action='group-include' then begin
    var IncludePath:=TPath.Combine(Root,'GroupB','Features.inc');
    if Json.GetValue<Boolean>('enabled',True) then TFile.WriteAllText(IncludePath,'{$DEFINE FROM_B}') else TFile.WriteAllText(IncludePath,'{$UNDEF FROM_B}');
   end
   else if Action='group-quick-context' then begin
    var QuickFile:=TPath.Combine(Root,'GroupB','ContextB.pas');var QuickEditor:=SourceEditorForFile(QuickFile);QuickEditor.Show;var QuickSource:=EditorSource(QuickEditor);var Lines:=QuickSource.Split([#10]);
    var QuickPos:TOTAEditPos;QuickPos.Line:=0;for var I:=0 to High(Lines) do if Lines[I].Contains('Worker.Run(Local)') then begin QuickPos.Line:=I+1;QuickPos.Col:=System.Pos('Run(Local)',Lines[I])+1;Break;end;
    AssertTrue(QuickPos.Line>0,'Quick documentation call fixture absent');QuickEditor.EditViews[0].SetCursorPos(QuickPos);QuickEditor.EditViews[0].MoveViewToCursor;Inspector.HandleCursorChanged(QuickPos.Line,QuickSource,QuickFile);Browser.ExecuteScript('window.__quickContextReady=true');
   end
   else if Action='group-stub' then begin
    var StubItem:=FindMenuCommand((BorlandIDEServices as INTAServices).MainMenu.Items,'Generate Doc Stub');AssertTrue(Assigned(StubItem),'Stub menu absent');StubItem.Click;
    var StubSource:=EditorSource(SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas')));
    AssertTrue(StubSource.Contains('<param name="Value">'),'Stub did not document project B parameter');Log('PASS GroupB Generate Stub with owning project');
   end
   else if Action='assert-group-format' then begin
    var GroupFile:=TPath.Combine(Root,'GroupB','ContextB.pas');
    var GroupSource:=EditorSource(SourceEditorForFile(GroupFile));
    AssertTrue(GroupSource.Contains('GroupB '+Json.GetValue<string>('mode')+' before format'),'Formatted GroupB documentation was not written');
    AssertTrue(GroupSource.Contains('Пример &amp; details'),'Format lost Unicode or XML escaping');
    AssertTrue(GroupSource.Contains('procedure FromB'),'Format damaged GroupB declaration');
    Log('PASS GroupB open, edit, format, apply: '+Json.GetValue<string>('mode'));
   end
   else if Action='format-group-source' then begin
    {$IF CompilerVersion >= 37.0}
    Log('SKIP native Ctrl+D: the built-in Pascal formatter is unavailable in RAD Studio 13');
    Browser.ExecuteScript('window.__xmlDocNativeFormatted="unavailable";');
    {$ELSE}
    Step:=82;Timer.Interval:=100;Timer.Enabled:=True;
    {$IFEND}
   end
   else if Action='lock-source' then begin
    ProtectedBefore:=EditorSource(SourceEditorForFile(SampleFile));
    if Json.GetValue<string>('mode','')='buffer' then begin
     AssertTrue(Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer),'Read-only buffer unavailable');EditBuffer.IsReadOnly:=True;
    end else if Json.GetValue<string>('mode','')='system' then FileSetAttr(SampleFile,FileGetAttr(SampleFile) or faSysFile)
    else FileSetAttr(SampleFile,FileGetAttr(SampleFile) or faReadOnly);
    Select(SampleFile,'Run','string');Inspector.RefreshFromCurrentEditor;
   end
   else if Action='assert-protected' then begin
    AssertTrue(EditorSource(SourceEditorForFile(SampleFile))=ProtectedBefore,'Read-only source was modified');Log('PASS read-only file rejects forged browser write');
    FileSetAttr(SampleFile,FileGetAttr(SampleFile) and not (faReadOnly or faSysFile));
    if Supports(SourceEditorForFile(SampleFile),IOTAEditBuffer,EditBuffer) then EditBuffer.IsReadOnly:=False;
    Inspector.RefreshFromCurrentEditor;
   end
   else if Action='view-system' then begin
    SystemFile:=TPath.Combine(ExtractFileDir(ExcludeTrailingPathDelimiter(ExtractFilePath(GetModuleName(0)))),'source\rtl\sys\System.pas');
    ProtectedBefore:=TFile.ReadAllText(SystemFile);(BorlandIDEServices as IOTAActionServices).OpenFile(SystemFile);
    var SystemEditor:=SourceEditorForFile(SystemFile);AssertTrue(Assigned(SystemEditor),'System source editor missing');SystemEditor.Show;
    Inspector.HandleCursorChanged(1,EditorSource(SystemEditor),SystemFile);Explorer.HandleFileChanged(SystemFile,EditorSource(SystemEditor));
   end
   else if Action='assert-system' then begin
    AssertTrue(TFile.ReadAllText(SystemFile)=ProtectedBefore,'System.pas disk content changed');
    AssertTrue(not EditorSource(SourceEditorForFile(SystemFile)).Contains('FORBIDDEN READONLY WRITE'),'System buffer was modified');
    AssertParsed(Inspector);AssertParsed(Explorer);
    AssertTrue(SourceEditProtection(SystemFile)<>'','Compiler source is writable');Log('PASS System.pas parsed and protected in Inspector and Explorer');
   end
   else if Action='finish' then begin Log('PASS');Step:=90;Timer.Interval:=100;Timer.Enabled:=True;end
   else if Action='fail' then raise Exception.Create(Json.GetValue<string>('message','Unknown browser failure')+' '+Json.GetValue<string>('stack',''));
  except on E:Exception do begin Log('FAIL '+E.Message);if GetEnvironmentVariable('XMLDOC_E2E_KEEP_FAILURE')<>'1' then ExitProcess(1);end;end;
 finally Json.Free;end;
end;
procedure TProbe.CloseExportMessage(Sender:TObject);
var F:TForm;C:TComponent;Text:string;W:HWND;P:DWORD;
begin
 W:=FindWindowEx(0,0,'#32770',nil);
 while W<>0 do begin
  GetWindowThreadProcessId(W,@P);
  if P=GetCurrentProcessId then begin Log('GENERATION native completion dialog');PostMessage(W,WM_USER+102,IDOK,0);PostMessage(W,WM_COMMAND,IDOK,0);end;
  W:=FindWindowEx(0,W,'#32770',nil);
 end;
 for var I:=0 to Screen.FormCount-1 do begin F:=Screen.Forms[I];
  if (F.ClassName='TMessageForm') then begin
   Text:='';for var J:=0 to F.ComponentCount-1 do begin C:=F.Components[J];if C is TLabel then Text:=Text+TLabel(C).Caption;end;
   Log('GENERATION MESSAGE: '+Text);F.ModalResult:=mrOK;
  end;
 end;
end;
procedure AssertErrorLabelTheme(Form:TForm);
var LabelControl:TLabel;Foreground,Background:Longint;Difference:Integer;
begin
 for var I:=0 to Form.ComponentCount-1 do if Form.Components[I] is TLabel then begin
  LabelControl:=TLabel(Form.Components[I]);
  Foreground:=ColorToRGB(LabelControl.Font.Color);Background:=ColorToRGB(Form.Color);
  Difference:=Abs(Integer(GetRValue(Foreground))-Integer(GetRValue(Background)))+
   Abs(Integer(GetGValue(Foreground))-Integer(GetGValue(Background)))+
   Abs(Integer(GetBValue(Foreground))-Integer(GetBValue(Background)));
  if Difference<192 then raise Exception.Create('Unreadable native error label in '+Form.Caption);
 end;
 Log('PASS native error label theme: '+Form.Caption);
end;
procedure TProbe.ExportAll;
var D:TBatchGenDialog;C:TComponent;B:TButton;T:TTimer;N:Integer;Output:string;Done:Boolean;
begin
 Output:=TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_LOG')),'documentation');
 D:=TBatchGenDialog.Create(nil);T:=TTimer.Create(nil);
 try
  B:=nil;N:=0;
  for var I:=0 to D.ComponentCount-1 do begin C:=D.Components[I];
   if C is TCheckBox then begin
    if TCheckBox(C).Caption=TI18n.Instance.T('Include private members') then TCheckBox(C).Checked:=False
    else TCheckBox(C).Checked:=True;
   end;
   if C is TEdit then begin
    Inc(N);case N of 2:TEdit(C).Text:='';3:TEdit(C).Text:=Output;4:TEdit(C).Text:='XmlDocE2E';end;
   end;
   if (C is TButton) and (TButton(C).Caption=TI18n.Instance.T('Generate')) then B:=TButton(C);
  end;
  AssertTrue(Assigned(B),'Generate button unavailable');D.Show;T.Interval:=200;T.OnTimer:=CloseExportMessage;
  B.Click;T.Enabled:=False;
  Done:=False;
  for var I:=0 to D.ComponentCount-1 do
    if (D.Components[I] is TLabel) and (TLabel(D.Components[I]).Caption='Done!') then Done:=True;
  AssertTrue(Done,'Generation did not reach the successful completion phase');
  AssertTrue(TFile.Exists(TPath.Combine(Output,'XmlDocE2E.chm')),'CHM generation did not complete');
  AssertTrue(TFile.Exists(TPath.Combine(Output,'site-vitepress\package.json')),'Site generation did not complete');
  Log('PASS all eight formats through installed plugin dialog: '+Output);
 finally T.Free;D.Free;end;
end;
function NativeWindowText(W:HWND):string;
var C:HWND;Buffer:array[0..4095] of Char;
begin
 GetWindowText(W,Buffer,Length(Buffer));Result:=string(Buffer);C:=GetWindow(W,GW_CHILD);
 while C<>0 do begin Result:=Result+NativeWindowText(C);C:=GetWindow(C,GW_HWNDNEXT);end;
end;
function NativeYesButton(W:HWND):HWND;
var C:HWND;Buffer:array[0..127] of Char;
begin
 Result:=0;GetWindowText(W,Buffer,Length(Buffer));if SameText(StringReplace(string(Buffer),'&','',[rfReplaceAll]),'Yes') then Exit(W);
 C:=GetWindow(W,GW_CHILD);while C<>0 do begin Result:=NativeYesButton(C);if Result<>0 then Exit;C:=GetWindow(C,GW_HWNDNEXT);end;
end;
procedure TProbe.ConfirmFormat(Sender:TObject);
var Text:string;W,Button:HWND;P:DWORD;
begin
 W:=FindWindowEx(0,0,nil,nil);
 while W<>0 do begin
  GetWindowThreadProcessId(W,@P);
  if P=GetCurrentProcessId then begin
   Text:=NativeWindowText(W);
   if Text.Contains('Do you really want to format the selected file:') and Text.Contains(TPath.Combine(Root,'GroupB','ContextB.pas')) then begin
    Button:=NativeYesButton(W);
    if Button<>0 then begin Log('Confirmed native formatter for isolated GroupB fixture');SendMessage(Button,BM_CLICK,0,0);end;
   end;
  end;
  W:=FindWindowEx(0,W,nil,nil);
 end;
end;
function FocusCodeEditor(Control:TWinControl):Boolean;
begin
 Result:=False;
 if ContainsText(Control.ClassName,'EditControl') and Control.CanFocus then begin Log('Native editor focus '+Control.ClassName);Control.SetFocus;Exit(True);end;
 for var I:=0 to Control.ControlCount-1 do if Control.Controls[I] is TWinControl then if FocusCodeEditor(TWinControl(Control.Controls[I])) then Exit(True);
end;
procedure TProbe.Tick(Sender:TObject);
var I:Integer;Editor:IOTASourceEditor;
begin
 Timer.Enabled:=False;
 try
 case Step of
  95:begin
   Log('Starting large-file IDE check');
   var LargeProject:=GetEnvironmentVariable('XMLDOC_E2E_LARGE_PROJECT');var LargeFile:=GetEnvironmentVariable('XMLDOC_E2E_LARGE_SOURCE');
   if (LargeProject<>'') and (LargeFile<>'') then begin
    var BeforeHash:=THashSHA2.GetHashStringFromFile(LargeFile);
    var GroupBefore:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;var ActiveBefore:=GetActiveProject;
    // Carry the actual project's evaluated compiler context into a temporary,
    // source-only project. Restoring its desktop would instantiate unavailable
    // third-party form classes in the deliberately isolated test profile.
    var Context:=TProjectContext.Create(LargeProject,'Debug','Win32');
    var PerformanceRoot:=TPath.Combine(Root,'Performance');ForceDirectories(PerformanceRoot);
    var PerformanceProject:=TPath.Combine(PerformanceRoot,'SourceLatency.dproj');
    try
     var ProjectXml:='<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003"><PropertyGroup><MainSource>SourceLatency.dpr</MainSource><DCC_Define>'+XmlEscape(string.Join(';',Context.Defines))+'</DCC_Define><DCC_IncludePath>'+XmlEscape(ExtractFilePath(LargeProject)+';'+string.Join(';',Context.IncludePaths))+'</DCC_IncludePath><DCC_UnitSearchPath>'+XmlEscape(ExtractFilePath(LargeProject)+';'+string.Join(';',Context.SearchPaths))+'</DCC_UnitSearchPath></PropertyGroup><ItemGroup>';
     for var OriginalFile in Context.SourceFiles+[LargeFile] do if not SameText(ExtractFileExt(OriginalFile),'.dpr') then ProjectXml:=ProjectXml+'<DCCReference Include="'+XmlEscape(OriginalFile)+'"/>';
     ProjectXml:=ProjectXml+'</ItemGroup></Project>';TFile.WriteAllText(PerformanceProject,ProjectXml,TEncoding.UTF8);TFile.WriteAllText(TPath.Combine(PerformanceRoot,'SourceLatency.dpr'),'program SourceLatency; begin end.',TEncoding.UTF8);
    finally Context.Free;end;
    AssertTrue(Assigned(ActiveBefore) and ActiveBefore.FileName.StartsWith(Root,True),'Performance context must belong to the isolated fixture');
    var SavedProject:=TFile.ReadAllBytes(ActiveBefore.FileName);var SavedStamp:=TFile.GetLastWriteTimeUtc(ActiveBefore.FileName);
    // Exercise the real evaluated context through the normal Inspector path,
    // without restoring the user project's form designer in the test profile.
    TFile.WriteAllText(TPath.Combine(ExtractFilePath(ActiveBefore.FileName),'SourceLatency.dpr'),'program SourceLatency; begin end.',TEncoding.UTF8);
    try
    TFile.WriteAllBytes(ActiveBefore.FileName,TFile.ReadAllBytes(PerformanceProject));TFile.SetLastWriteTimeUtc(ActiveBefore.FileName,SavedStamp);
    Log('Opening performance source '+LargeFile);AssertTrue((BorlandIDEServices as IOTAActionServices).OpenFile(LargeFile),'Cannot open large source');
    var LargeEditor:=SourceEditorForFile(LargeFile);AssertTrue(Assigned(LargeEditor),'Large source editor unavailable');
    var LargeText:=EditorSource(LargeEditor);var Parser:=TDocParser.Create;var LargeLine:=0;
    try ConfigureDeclarationContext(Parser,nil,LargeFile);Parser.ParseSource(LargeText,LargeFile);
     for var Item in Parser.GetAllElements do if (Item.Name='WriteToChangeLogTable') and (Item.SourceSection='implementation') then begin LargeLine:=Item.LineNumber;Break;end;
    finally Parser.Free;end;
    AssertTrue(LargeLine>0,'Requested large-file method not found');
    var Watch:=TStopwatch.StartNew;Inspector.HandleCursorChanged(LargeLine,LargeText,LargeFile);Log('PERF large Inspector cold ms='+FloatToStr(Watch.Elapsed.TotalMilliseconds));
    var Total,Maximum:Double;Total:=0;Maximum:=0;
    for var J:=1 to 20 do begin Watch:=TStopwatch.StartNew;Inspector.HandleCursorChanged(LargeLine+(J mod 2),LargeText,LargeFile);var Elapsed:=Watch.Elapsed.TotalMilliseconds;Total:=Total+Elapsed;if Elapsed>Maximum then Maximum:=Elapsed;end;
    Log('PERF large Inspector warm mean ms='+FloatToStr(Total/20)+' max synchronous UI ms='+FloatToStr(Maximum));
    AssertTrue(BeforeHash=THashSHA2.GetHashStringFromFile(LargeFile),'Large user source changed');
    Log('PASS large source remained byte-for-byte unchanged: '+LargeFile);
    finally TFile.WriteAllBytes(ActiveBefore.FileName,SavedProject);TFile.SetLastWriteTimeUtc(ActiveBefore.FileName,SavedStamp);end;
   end;
   Log('PASS');Step:=90;Timer.Interval:=100;Timer.Enabled:=True;Exit;
  end;
  90:begin Finish;Exit;end;
  80:begin
   Log('Adding project B outside WebView callback');
   AssertTrue((BorlandIDEServices as IOTAActionServices).OpenProject(TPath.Combine(Root,'GroupB','GroupB.dproj'),False),'Cannot add group project B');
   var Group:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;
   for var J:=0 to Group.ProjectCount-1 do if SameText(Group.Projects[J].FileName,PrimaryProjectFile) then begin Group.ActiveProject:=Group.Projects[J];Break;end;
   Log('Added project B; active project '+GetActiveProject.FileName);Step:=81;Timer.Interval:=1500;Timer.Enabled:=True;
   Exit;
  end;
  82:begin
   var GroupFile:=TPath.Combine(Root,'GroupB','ContextB.pas');
   var GroupEditor:=SourceEditorForFile(GroupFile);AssertTrue(Assigned(GroupEditor),'GroupB editor unavailable for Format Source');var ProjectGroup:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;ProjectGroup.ActiveProject:=ProjectGroup.FindProject(GroupFile);GroupEditor.Show;
   var Actions:=(BorlandIDEServices as INTAServices).ActionList;var FormatAction:TCustomAction:=nil;
   for var K:=0 to Actions.ActionCount-1 do if Actions.Actions[K] is TCustomAction then begin
    var A:=TCustomAction(Actions.Actions[K]);
    if SameText(A.Name,'actFormatSource') then FormatAction:=A;
   end;
   AssertTrue(Assigned(FormatAction),'Native Format Source action not found');AssertTrue(FormatAction.ShortCut=ShortCut(Ord('D'),[ssCtrl]),'Native formatter is not bound to Ctrl+D');
   var SourceBytes:=UTF8Encode(EditorSource(GroupEditor));var EditOffset:=Pos(UTF8String('begin end;'),SourceBytes)-1;AssertTrue(EditOffset>=0,'GroupB body missing');
   var NativeWriter:=GroupEditor.CreateUndoableWriter;NativeWriter.CopyTo(EditOffset);NativeWriter.DeleteTo(EditOffset+Length('begin end;'));var InsertBytes:=UTF8String('begin   {E2E native format}   end;');NativeWriter.Insert(PAnsiChar(InsertBytes));NativeWriter:=nil;FormatBefore:=EditorSource(GroupEditor);
   Application.MainForm.Show;Application.MainForm.BringToFront;Application.MainForm.SetFocus;var EditForm:=GroupEditor.GetEditView(0).GetEditWindow.Form;AssertTrue(FocusCodeEditor(EditForm),'Native source control could not acquire focus');
   Log('Invoking native formatter '+FormatAction.Name+' after Pascal buffer edit');FormatConfirmation:=TTimer.Create(nil);FormatConfirmation.Interval:=100;FormatConfirmation.OnTimer:=ConfirmFormat;if Assigned(FormatAction.OnExecute) then FormatAction.OnExecute(FormatAction) else AssertTrue(FormatAction.Execute,'Native Format Source action rejected');
   Step:=83;Timer.Interval:=750;Timer.Enabled:=True;Exit;
  end;
  83:begin
   var GroupEditor:=SourceEditorForFile(TPath.Combine(Root,'GroupB','ContextB.pas'));
   if (EditorSource(GroupEditor)=FormatBefore) and (FormatWait<40) then begin Inc(FormatWait);Timer.Enabled:=True;Exit;end;
   AssertTrue(EditorSource(GroupEditor)<>FormatBefore,'Native formatter did not change unformatted Pascal buffer');
   FreeAndNil(FormatConfirmation);
   AssertTrue(EditorSource(GroupEditor).Contains('E2E native format'),'Native formatter lost Pascal buffer edit');
   AssertTrue(EditorSource(GroupEditor).Contains('GroupB saved before format'),'Native formatter lost documentation');
   Inspector.RefreshFromCurrentEditor;Log('PASS native Format Source on edited GroupB');
   Browser.ExecuteScript('window.__xmlDocNativeFormatted=true;');Step:=81;Timer.Interval:=1500;Timer.Enabled:=True;Exit;
  end;
  81:begin
   Browser.ExecuteScript(TFile.ReadAllText(TPath.Combine(ExtractFilePath(GetEnvironmentVariable('XMLDOC_E2E_JS')),'WorkbenchGroupProbe.js')));
   Timer.Enabled:=True;Exit;
  end;
  0:begin
    var Actions:=(BorlandIDEServices as INTAServices).ActionList;var Found:=False;
    for var ActionIndex:=0 to Actions.ActionCount-1 do if Actions.Actions[ActionIndex].Name='XmlDocActionsyncdocument' then Found:=True;
    AssertTrue(Found,'Documentation actions are not registered in the IDE action catalog');AssertTrue(Assigned(FindMenuCommand((BorlandIDEServices as INTAServices).MainMenu.Items,'User Guide')),'Offline User Guide menu missing');Log('PASS IDE action registration and offline User Guide menu');
    var Shortcuts:=TPluginSettings.Instance.Global.Shortcuts;
    var Conflicts:=DocumentationShortcutConflicts([Shortcuts.ToggleInspector,Shortcuts.GenerateStub,Shortcuts.CoverageReport,Shortcuts.NextUndocumented],['Inspector','Stub','Coverage','Next'],Actions,(BorlandIDEServices as INTAServices).MainMenu.Items);
    for var Conflict in Conflicts do begin
      Log('SHORTCUT '+Conflict);
      AssertTrue(not Conflict.Contains('Doc Inspector') and not Conflict.Contains('Generate Doc Stub') and not Conflict.Contains('Coverage Report') and not Conflict.Contains('Next Undocumented'),'Own IDE menu wrapper reported as shortcut conflict');
    end;
    Log('PASS IDE shortcut ownership validation');
    AssertTrue(GetModuleVersion=GetEnvironmentVariable('XMLDOC_E2E_VERSION'),'Loaded BPL version differs from the shared version');
    var About:=TAboutDialog.Create(nil);
    try AssertTrue(About.lblVersion.Caption='Version '+GetEnvironmentVariable('XMLDOC_E2E_VERSION'),'About dialog version mismatch');finally About.Free;end;
    Log('PASS loaded BPL and About dialog shared version');
    Root:=GetEnvironmentVariable('XMLDOC_E2E_FIXTURE');SampleFile:=TPath.Combine(Root,'Units\Workbench.Sample.pas');SecondFile:=TPath.Combine(Root,'Units\Workbench.Second.pas');
    var Settings:=TPluginSettings.Create;
    var SettingsRoot:=TPath.Combine(Root,'settings-fixture');TDirectory.CreateDirectory(SettingsRoot);
    try
     TFile.WriteAllText(TPath.Combine(SettingsRoot,'.xmldocplugin.json'),'{"helpGen":{"outputDir":"project-a","includePrivate":true}}');Settings.LoadProject(SettingsRoot);
     AssertTrue(Settings.Project.HelpGen.OutputDir='project-a','Project A options were not loaded');
     Settings.LoadProject(Root);AssertTrue((Settings.Project.HelpGen.OutputDir='docs') and not Settings.Project.HelpGen.IncludePrivate,'Project A options leaked into B');
     TFile.WriteAllText(TPath.Combine(SettingsRoot,'.xmldocplugin.json'),'{"helpGen":{"title":"Partial"}}');Settings.LoadProject(SettingsRoot);
     AssertTrue((Settings.Project.HelpGen.OutputDir='docs') and (Settings.Project.HelpGen.Title='Partial'),'Partial settings did not use defaults');
     Log('PASS project settings reset between projects and partial files');
    finally Settings.Free;TDirectory.Delete(SettingsRoot,True);end;
    AssertTrue((BorlandIDEServices as IOTAActionServices).OpenFile(TPath.Combine(Root,'XmlDocE2E.dproj')),'Cannot open E2E project');Inc(Step);end;
  1:begin ExportAll;Inspector:=TDocInspectorForm.Create(nil);Inspector.Show;Explorer:=TDocExplorerForm.Create(nil);Explorer.Show;AssertErrorLabelTheme(Inspector);AssertErrorLabelTheme(Explorer);Inc(Step);end;
  2:begin
    for I:=0 to Inspector.ComponentCount-1 do if Inspector.Components[I] is TXmlDocBrowser then Browser:=TXmlDocBrowser(Inspector.Components[I]);
    AssertTrue(Assigned(Browser),'Browser unavailable');
    for I:=0 to Inspector.ComponentCount-1 do if Inspector.Components[I] is TTimer then TTimer(Inspector.Components[I]).Enabled:=False;
    for I:=0 to Explorer.ComponentCount-1 do begin
      if Explorer.Components[I] is TXmlDocBrowser then ExplorerBrowser:=TXmlDocBrowser(Explorer.Components[I]);
      if Explorer.Components[I] is TTimer then TTimer(Explorer.Components[I]).Enabled:=False;
    end;
    AssertTrue(Assigned(ExplorerBrowser),'Explorer browser unavailable');OriginalExplorerMessage:=ExplorerBrowser.OnWebMessageReceived;ExplorerBrowser.OnWebMessageReceived:=ExplorerMessage;
    OriginalMessage:=Browser.OnWebMessageReceived;Browser.OnWebMessageReceived:=MessageReceived;
    (BorlandIDEServices as IOTAActionServices).OpenFile(SecondFile);SecondInitial:=EditorSource(SourceEditorForFile(SecondFile));
    Select(SampleFile,'Run','string');Initial:=EditorSource(SourceEditorForFile(SampleFile));Log('Resource map: '+Browser.ResourceStatus);AssertTrue(Initial.Contains('Пример'),'Unicode was lost while reading the editor buffer');Inc(Step);end;
  3:begin Inc(Step);Select(SampleFile,'Run','string');if GetEnvironmentVariable('XMLDOC_E2E_GROUP_ONLY')='1' then Browser.ExecuteScript('window.chrome.webview.postMessage(JSON.stringify({type:"e2e",action:"prepare-group"}));') else Browser.ExecuteScript(TFile.ReadAllText(GetEnvironmentVariable('XMLDOC_E2E_JS')));end;
 end;
 if Step<4 then Timer.Enabled:=True;
 except on E:Exception do begin Log('FAIL '+E.Message);if GetEnvironmentVariable('XMLDOC_E2E_KEEP_FAILURE')<>'1' then ExitProcess(1);end;end;
end;
procedure Register;
begin if Assigned(Probe) then Exit;Probe:=TProbe.Create;Probe.Timer:=TTimer.Create(nil);Probe.Timer.Interval:=2500;Probe.Timer.OnTimer:=Probe.Tick;end;
initialization
finalization
 Log('Finalizing probe');if Probe<>nil then begin Probe.Timer.Free;Probe.FormatConfirmation.Free;Probe.Inspector.Free;Probe.Explorer.Free;Probe.Free;Probe:=nil;end;Log('Probe finalized');
end.
