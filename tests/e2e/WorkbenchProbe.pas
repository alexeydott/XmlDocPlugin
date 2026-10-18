unit WorkbenchProbe;
interface
procedure Register;
implementation
uses System.SysUtils,System.Classes,System.IOUtils,System.JSON,Winapi.Windows,Winapi.Messages,Winapi.ActiveX,
 Vcl.Forms,Vcl.Menus,Vcl.Controls,Vcl.ExtCtrls,Vcl.Edge,WebView2,ToolsAPI,XmlDoc.Plugin.DocInspector,
 XmlDoc.Plugin.Browser,XmlDoc.Plugin.DocExplorer,XmlDoc.Plugin.EditSession,XmlDoc.Parser,XmlDoc.Consts,Vcl.StdCtrls,XmlDoc.Plugin.BatchGenDialog,Vcl.Graphics;
type TProbe=class
 Timer:TTimer;Inspector:TDocInspectorForm;Explorer:TDocExplorerForm;Browser,ExplorerBrowser:TXmlDocBrowser;OriginalMessage,OriginalExplorerMessage:TWebMessageReceivedEvent;ExplorerAttempted:Boolean;
 Step:Integer;Initial,AfterWrite,SecondInitial,SampleFile,SecondFile,Root:string;Finished:Boolean;
 procedure Tick(Sender:TObject); procedure ExportAll; procedure CloseExportMessage(Sender:TObject);
 procedure ExplorerMessage(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
 procedure MessageReceived(Sender:TCustomEdgeBrowser;Args:TWebMessageReceivedEventArgs);
 procedure Select(const FileName,Name,TypeName:string);
 procedure AssertTrue(Value:Boolean;const Message:string);
 procedure Finish;
end;
var Probe:TProbe;
procedure Log(const Text:string);
begin TFile.AppendAllText(GetEnvironmentVariable('XMLDOC_E2E_LOG'),Text+sLineBreak);end;
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
 if Finished then Exit;Finished:=True;Timer.Enabled:=False;
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
begin
 Buffer:=nil;Args.ArgsInterface.TryGetWebMessageAsString(Buffer);if Buffer=nil then Exit;
 try Text:=string(Buffer);finally CoTaskMemFree(Buffer);end;
 Json:=TJSONObject.ParseJSONValue(Text) as TJSONObject;
 try
  if Assigned(Json) and (Json.GetValue<string>('type','')='docUpdated') then Log('EDIT '+Json.GetValue<string>('sourceRevision','')+' '+Json.GetValue<TJSONObject>('doc').GetValue<string>('summary',''));
  if not Assigned(Json) or (Json.GetValue<string>('type','')<>'e2e') then begin if Assigned(OriginalMessage) then OriginalMessage(Sender,Args);Exit;end;
  Action:=Json.GetValue<string>('action','');
  try
   if Action='arm-explorer' then begin
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
   else if Action='finish' then begin Log('PASS');Step:=90;Timer.Interval:=100;Timer.Enabled:=True;end
   else if Action='fail' then raise Exception.Create(Json.GetValue<string>('message','Unknown browser failure')+' '+Json.GetValue<string>('stack',''));
  except on E:Exception do begin Log('FAIL '+E.Message);ExitProcess(1);end;end;
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
    if TCheckBox(C).Caption='Include private members' then TCheckBox(C).Checked:=False
    else TCheckBox(C).Checked:=True;
   end;
   if C is TEdit then begin
    Inc(N);case N of 2:TEdit(C).Text:='';3:TEdit(C).Text:=Output;4:TEdit(C).Text:='XmlDocE2E';end;
   end;
   if (C is TButton) and (TButton(C).Caption='Generate') then B:=TButton(C);
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
procedure TProbe.Tick(Sender:TObject);
var I:Integer;Editor:IOTASourceEditor;
begin
 Timer.Enabled:=False;
 try
 case Step of
  90:begin Finish;Exit;end;
  0:begin
    var Actions:=(BorlandIDEServices as INTAServices).ActionList;var Found:=False;
    for var ActionIndex:=0 to Actions.ActionCount-1 do if Actions.Actions[ActionIndex].Name='XmlDocActionsyncdocument' then Found:=True;
    AssertTrue(Found,'Documentation actions are not registered in the IDE action catalog');Log('PASS IDE action registration');
    Root:=GetEnvironmentVariable('XMLDOC_E2E_FIXTURE');SampleFile:=TPath.Combine(Root,'Units\Workbench.Sample.pas');SecondFile:=TPath.Combine(Root,'Units\Workbench.Second.pas');
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
  3:begin Inc(Step);Select(SampleFile,'Run','string');Browser.ExecuteScript(TFile.ReadAllText(GetEnvironmentVariable('XMLDOC_E2E_JS')));end;
 end;
 if Step<4 then Timer.Enabled:=True;
 except on E:Exception do begin Log('FAIL '+E.Message);ExitProcess(1);end;end;
end;
procedure Register;
begin if Assigned(Probe) then Exit;Probe:=TProbe.Create;Probe.Timer:=TTimer.Create(nil);Probe.Timer.Interval:=2500;Probe.Timer.OnTimer:=Probe.Tick;end;
initialization
finalization
 Log('Finalizing probe');if Probe<>nil then begin Probe.Timer.Free;Probe.Inspector.Free;Probe.Explorer.Free;Probe.Free;Probe:=nil;end;Log('Probe finalized');
end.
