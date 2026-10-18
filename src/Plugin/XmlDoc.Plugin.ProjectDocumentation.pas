unit XmlDoc.Plugin.ProjectDocumentation;
interface
uses Vcl.ExtCtrls,XmlDoc.Parser,XmlDoc.ProjectIndex,System.SysUtils,System.JSON,System.Generics.Collections,ToolsAPI,XmlDoc.Consts,XmlDoc.Plugin.Browser,XmlDoc.Plugin.QuickDocPreview;
type
 TProjectDocumentation=class
 private
  FElements:TDictionary<string,TCodeElementInfo>;
  FQuickPreview:TQuickDocPreview;
  FIndex:TDocumentationIndex;
  FAnalysisTimer:TTimer;
  FJobFiles:TArray<string>;
  FJobParsers:TObjectDictionary<string,TDocParser>;
  FJobSources:TDictionary<string,string>;
  FJobBrowser:TXmlDocBrowser;
  FJobPosition:Integer;
  FQuickPending:Boolean;
  FQuickSource,FQuickFile:string;
  FQuickPosition,FQuickLine:Integer;
  FEffective:TDictionary<string,string>;
  FSources,FSessions:TDictionary<string,string>;
  procedure AnalysisTick(Sender:TObject);
  procedure AnalysisState(const State:string);
  procedure CancelAnalysis;
  procedure PublishCatalog;
  procedure ShowQuickDoc;

  function Key(const FileName,SymbolId:string):string;
  function DraftPath(Message:TJSONObject):string;
  procedure Draft(Message:TJSONObject;Browser:TXmlDocBrowser);
  procedure Catalog(const Scope:string;Browser:TXmlDocBrowser);
  procedure Authoring(Message:TJSONObject;Browser:TXmlDocBrowser);
  procedure QuickDoc(Browser:TXmlDocBrowser);
  procedure ApplyBatch(Changes:TJSONArray;Browser:TXmlDocBrowser);
 public
  constructor Create;
  destructor Destroy;override;
  procedure Acknowledge(Message:TJSONObject);
  function Handle(Message:TJSONObject;Browser:TXmlDocBrowser):Boolean;
 end;
implementation
uses System.Classes,System.IOUtils,System.Generics.Defaults,XmlDoc.Model,
 XmlDoc.Expressions,Vcl.Controls,System.RegularExpressions,System.Win.Registry,Winapi.Windows,System.Hash,XmlDoc.CodeGen,XmlDoc.Plugin.EditSession,XmlDoc.Plugin.DeclarationContext,XmlDoc.Plugin.Settings,XmlDoc.HelpGen.BatchParser,XmlDoc.SourceText;
constructor TProjectDocumentation.Create;
begin inherited;FIndex:=TDocumentationIndex.Create;FJobParsers:=TObjectDictionary<string,TDocParser>.Create([doOwnsValues]);FJobSources:=TDictionary<string,string>.Create;
 FAnalysisTimer:=TTimer.Create(nil);FAnalysisTimer.Enabled:=False;FAnalysisTimer.Interval:=10;FAnalysisTimer.OnTimer:=AnalysisTick;
 FEffective:=TDictionary<string,string>.Create;FElements:=TDictionary<string,TCodeElementInfo>.Create;
 FSources:=TDictionary<string,string>.Create;FSessions:=TDictionary<string,string>.Create;end;
destructor TProjectDocumentation.Destroy;
begin FAnalysisTimer.Free;FJobParsers.Free;FJobSources.Free;FIndex.Free;FEffective.Free;FQuickPreview.Free;FSessions.Free;FSources.Free;FElements.Free;inherited;end;
function TProjectDocumentation.Key(const FileName,SymbolId:string):string;
begin Result:=LowerCase(FileName)+'|'+SymbolId;end;
function DraftDirectory:string;
begin Result:=GetEnvironmentVariable('XMLDOC_DRAFT_DIR');if Result='' then Result:=TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'),'XmlDocPlugin\Drafts');Result:=TPath.GetFullPath(Result);end;
function TProjectDocumentation.DraftPath(Message:TJSONObject):string;
var Identity:string;
begin
 Identity:=LowerCase(Message.GetValue<string>('fileName',''))+'|'+Message.GetValue<string>('locationId',Message.GetValue<string>('declarationId',Message.GetValue<string>('symbolId','')));
 Result:=TPath.Combine(DraftDirectory,THashSHA2.GetHashString(Identity)+'.json');
end;
procedure TProjectDocumentation.Acknowledge(Message:TJSONObject);
var FileName:string;Saved:TJSONObject;
begin FileName:=DraftPath(Message);if not TFile.Exists(FileName) then Exit;
 Saved:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName)) as TJSONObject;
 try if Assigned(Saved) and Assigned(Saved.GetValue('doc')) and Assigned(Message.GetValue('doc')) and
  (Saved.GetValue('doc').ToJSON=Message.GetValue('doc').ToJSON) then TFile.Delete(FileName);
 finally Saved.Free;end;
end;
procedure TProjectDocumentation.Draft(Message:TJSONObject;Browser:TXmlDocBrowser);
var FileName,RootPath:string;Project:IOTAProject;Json,Reply:TJSONObject;Drafts:TJSONArray;
 function BelongsToWorkspace(Item:TJSONObject):Boolean;
 var ProjectFile:string;Group:IOTAProjectGroup;
 begin
  ProjectFile:=Item.GetValue<string>('projectFile','');Result:=Assigned(Project) and SameText(Project.FileName,ProjectFile);
  if not Result and (ProjectFile<>'') then begin Group:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;if Assigned(Group) then for var I:=0 to Group.ProjectCount-1 do if SameText(Group.Projects[I].FileName,ProjectFile) then Exit(True);end;
  if not Result and (ProjectFile='') then Result:=(RootPath<>'') and Item.GetValue<string>('fileName','').StartsWith(RootPath,True);
 end;
begin
 if Message.GetValue<string>('type','')='draftUpdated' then begin
  if SourceEditProtection(Message.GetValue<string>('fileName',''))<>'' then Exit;
  if (Message.GetValue<string>('fileName','')='') or (Message.GetValue<string>('symbolId','')='') then Exit;
  ForceDirectories(DraftDirectory);FileName:=DraftPath(Message);
  TFile.WriteAllText(FileName+'.tmp',Message.ToJSON,TEncoding.UTF8);
  if not MoveFileEx(PChar(FileName+'.tmp'),PChar(FileName),MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then RaiseLastOSError;
 end else begin
  Reply:=TJSONObject.Create;Drafts:=TJSONArray.Create;Reply.AddPair('drafts',Drafts);
  try
   Project:=GetActiveProject;RootPath:='';if Assigned(Project) then RootPath:=ExtractFilePath(Project.FileName);
   if TDirectory.Exists(DraftDirectory) then for FileName in TDirectory.GetFiles(DraftDirectory,'*.json') do begin
    Json:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName)) as TJSONObject;
    if not Assigned(Json) then Continue;
    if BelongsToWorkspace(Json) then begin Json.AddPair('draftId',TPath.GetFileNameWithoutExtension(FileName));Drafts.AddElement(Json);end else Json.Free;
   end;
   Browser.ExecuteScript('window.xmlDocWorkbench?.receiveDrafts('+Reply.ToJSON+');');
  finally Reply.Free;end;
 end;
end;

procedure TProjectDocumentation.AnalysisState(const State:string);
var Json:TJSONObject;
begin
 if not Assigned(FJobBrowser) then Exit;Json:=TJSONObject.Create;
 try Json.AddPair('state',State);Json.AddPair('completed',TJSONNumber.Create(FJobPosition));Json.AddPair('total',TJSONNumber.Create(Length(FJobFiles)));Json.AddPair('parsed',TJSONNumber.Create(FIndex.Parsed));Json.AddPair('reused',TJSONNumber.Create(FIndex.Reused));
 FJobBrowser.ExecuteScript('window.xmlDocWorkbench?.receiveAnalysis('+Json.ToJSON+');');finally Json.Free;end;
end;
procedure TProjectDocumentation.CancelAnalysis;
begin FAnalysisTimer.Enabled:=False;FQuickPending:=False;AnalysisState('cancelled');end;
procedure TProjectDocumentation.Catalog(const Scope:string;Browser:TXmlDocBrowser);
var Files:TList<string>;Projects:TDictionary<string,IOTAProject>;Services:IOTAModuleServices;Project:IOTAProject;Group:IOTAProjectGroup;EditorServices:IOTAEditorServices;
 procedure AddProject(P:IOTAProject);
 begin if not Assigned(P) then Exit;for var I:=0 to P.GetModuleCount-1 do begin var FileName:=P.GetModule(I).FileName;
  if SameText(ExtractFileExt(FileName),'.pas') then begin if not Files.Contains(FileName) then Files.Add(FileName);Projects.AddOrSetValue(LowerCase(FileName),P);end;
 end;end;
begin
 FAnalysisTimer.Enabled:=False;FJobBrowser:=Browser;FJobPosition:=0;FJobParsers.Clear;FJobSources.Clear;FIndex.ResetStatistics;
 Files:=TList<string>.Create;Projects:=TDictionary<string,IOTAProject>.Create;
 try
 try
  Services:=BorlandIDEServices as IOTAModuleServices;Project:=Services.GetActiveProject;
  if Scope='group' then begin Group:=Services.MainProjectGroup;if Assigned(Group) then for var I:=0 to Group.ProjectCount-1 do AddProject(Group.Projects[I]);end else if Scope='project' then AddProject(Project);
  if Files.Count=0 then if Supports(BorlandIDEServices,IOTAEditorServices,EditorServices) and Assigned(EditorServices.TopView) then Files.Add(EditorServices.TopView.Buffer.FileName);
  FJobFiles:=Files.ToArray;AnalysisState('running');
  for var FileName in FJobFiles do begin
   var Editor:=SourceEditorForFile(FileName);var Source:='';if Assigned(Editor) then Source:=EditorSource(Editor) else Source:=ReadSourceFile(FileName);
   FJobSources.AddOrSetValue(LowerCase(FileName),Source);var Parser:=TDocParser.Create;
   try
    var Owner:IOTAProject:=nil;Projects.TryGetValue(LowerCase(FileName),Owner);ConfigureDeclarationContext(Parser,Owner,FileName);Parser.SourceFiles:=FJobFiles;
    FJobParsers.Add(LowerCase(FileName),Parser);Parser:=nil;
   finally Parser.Free;end;
  end;
  FAnalysisTimer.Enabled:=True;
 except AnalysisState('failed');FQuickPending:=False;raise;
 end;
 finally Files.Free;Projects.Free;end;
end;
procedure TProjectDocumentation.AnalysisTick(Sender:TObject);
begin
 if not FAnalysisTimer.Enabled then Exit;
 FAnalysisTimer.Enabled:=False;
 try
  if FJobPosition<Length(FJobFiles) then begin
   var FileName:=FJobFiles[FJobPosition];FIndex.Update(FileName,FJobSources[LowerCase(FileName)],FJobParsers[LowerCase(FileName)]);Inc(FJobPosition);AnalysisState('running');FAnalysisTimer.Enabled:=True;
  end else begin PublishCatalog;AnalysisState('completed');if FQuickPending then begin FQuickPending:=False;ShowQuickDoc;end;end;
 except on Ex:Exception do begin AnalysisState('failed');FQuickPending:=False;
  var Json:=TJSONString.Create(Ex.Message);try FJobBrowser.ExecuteScript('window.bridge.setStatus('+Json.ToJSON+');');finally Json.Free;end;
 end;end;
end;
procedure TProjectDocumentation.PublishCatalog;
var FileName,Source,Session:string;E:TCodeElementInfo;Root,Json,Param:TJSONObject;Elements,Errors,Params,Generics,Interfaces:TJSONArray;Model:TXmlDocModel;P:TParamInfo;G:string;Batch:TBatchParser;NewElements:TDictionary<string,TCodeElementInfo>;NewSources,NewSessions,NewEffective:TDictionary<string,string>;
begin
 for var PendingFile in FJobFiles do begin
  var LiveEditor:=SourceEditorForFile(PendingFile);var LiveSource:='';if Assigned(LiveEditor) then LiveSource:=EditorSource(LiveEditor) else LiveSource:=ReadSourceFile(PendingFile);
  if LiveSource<>FJobSources[LowerCase(PendingFile)] then raise Exception.Create('Source changed during analysis — refresh the workspace');
  var CapturedParser:=FJobParsers[LowerCase(PendingFile)];ConfigureDeclarationContext(CapturedParser,nil,PendingFile);CapturedParser.SourceFiles:=FJobFiles;
  if not FIndex.IsCurrent(PendingFile,LiveSource,CapturedParser) then raise Exception.Create('Project context or a dependency changed during analysis — refresh the workspace');
 end;
 Root:=TJSONObject.Create;Elements:=TJSONArray.Create;Errors:=TJSONArray.Create;Root.AddPair('elements',Elements);Root.AddPair('errors',Errors);
 Model:=TXmlDocModel.Create;Batch:=TBatchParser.Create;NewElements:=TDictionary<string,TCodeElementInfo>.Create;NewSources:=TDictionary<string,string>.Create;NewSessions:=TDictionary<string,string>.Create;NewEffective:=TDictionary<string,string>.Create;
 try

  for FileName in FJobFiles do begin Source:=FJobSources[LowerCase(FileName)];Session:=TGUID.NewGuid.ToString;NewSources.AddOrSetValue(LowerCase(FileName),Source);NewSessions.AddOrSetValue(LowerCase(FileName),Session);
     for E in FIndex.Elements(FileName) do begin
      if (E.Name='') or NewElements.ContainsKey(Key(FileName,E.SymbolId)) then Continue;
      NewElements.Add(Key(FileName,E.SymbolId),E);Json:=TJSONObject.Create;

      Json.AddPair('kind',E.Kind.ToString);Json.AddPair('name',E.Name);Json.AddPair('fullName',E.FullName);
      Json.AddPair('qualifiedParent',E.QualifiedParent);Json.AddPair('visibility',E.Visibility);
 Json.AddPair('methodBinding',E.MethodBinding);Json.AddPair('isReintroduce',TJSONBool.Create(E.IsReintroduce));
      Json.AddPair('returnType',E.ReturnType);Json.AddPair('lineNumber',TJSONNumber.Create(E.LineNumber));
      AddEditContext(Json,E,FileName,Session,Source);
      Params:=TJSONArray.Create;for P in E.Params do begin Param:=TJSONObject.Create;Param.AddPair('name',P.Name);Param.AddPair('type',P.TypeName);Param.AddPair('isVar',TJSONBool.Create(P.IsVar));Param.AddPair('isConst',TJSONBool.Create(P.IsConst));Param.AddPair('isOut',TJSONBool.Create(P.IsOut));Params.AddElement(Param);end;Json.AddPair('params',Params);
      Generics:=TJSONArray.Create;for G in E.GenericParams do Generics.Add(G);Json.AddPair('genericParams',Generics);
      Interfaces:=TJSONArray.Create;for G in E.Implements do Interfaces.Add(G);Json.AddPair('implements',Interfaces);
      Model.LoadFromXml(E.ExistingDocXml);Json.AddPair('doc',TJSONObject.ParseJSONValue(Model.ToJson));Elements.AddElement(Json);
     end;

  end;
  Batch.ParsedElements:=function(FileName:string):TArray<TCodeElementInfo> begin Result:=FIndex.Elements(FileName);end;
  Batch.SourceSnapshots:=CurrentSourceSnapshots;Batch.ParseAll(FJobFiles);
  for var Value in Elements do begin var Item:=Value as TJSONObject;var Id:=Item.GetValue<string>('symbolId','');
   if Batch.SymbolIndex.ContainsKey(Id) then begin var Effective:=Batch.SymbolIndex[Id].Doc.ToJson;NewEffective.AddOrSetValue(Key(Item.GetValue<string>('fileName',''),Id),Effective);Item.AddPair('effectiveDoc',TJSONObject.ParseJSONValue(Effective));end;
  end;
  FElements.Free;FElements:=NewElements;NewElements:=nil;FSources.Free;FSources:=NewSources;NewSources:=nil;FSessions.Free;FSessions:=NewSessions;NewSessions:=nil;FEffective.Free;FEffective:=NewEffective;NewEffective:=nil;
  FJobBrowser.ExecuteScript('window.xmlDocWorkbench?.receiveCatalog('+Root.ToJSON+');');
 finally NewElements.Free;NewSources.Free;NewSessions.Free;NewEffective.Free;Batch.Free;Model.Free;Root.Free;end;
end;
procedure TProjectDocumentation.Authoring(Message:TJSONObject;Browser:TXmlDocBrowser);
var Project:IOTAProject;FileName,Scope,Text:string;Root,Payload,Reply,Global:TJSONObject;
 Registry:TRegistry;Value:TJSONValue;
begin
 Project:=GetActiveProject;if not Assigned(Project) then raise Exception.Create('Open a project to configure authoring');
 FileName:=TPath.Combine(ExtractFilePath(Project.FileName),'.xmldocplugin.json');Root:=nil;Global:=nil;Reply:=TJSONObject.Create;Registry:=TRegistry.Create(KEY_READ or KEY_WRITE);
 try
  if TFile.Exists(FileName) then Root:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName)) as TJSONObject;
  if not Assigned(Root) then Root:=TJSONObject.Create;
  Registry.RootKey:=HKEY_CURRENT_USER;
  if Registry.OpenKey('Software\XmlDocPlugin\Authoring',True) and Registry.ValueExists('Data') then Global:=TJSONObject.ParseJSONValue(Registry.ReadString('Data')) as TJSONObject;
  if not Assigned(Global) then Global:=TJSONObject.Create;
  if Message.GetValue<string>('type','')='saveAuthoring' then begin
   Payload:=Message.GetValue<TJSONObject>('data');if not Assigned(Payload) then raise Exception.Create('Authoring data is missing');
   Scope:=Message.GetValue<string>('scope','project');
   if Scope='global' then begin Global.Free;Global:=TJSONObject.ParseJSONValue(Payload.ToJSON) as TJSONObject;Registry.WriteString('Data',Global.ToJSON);end
   else begin
    Root.RemovePair('authoring').Free;Root.AddPair('authoring',TJSONObject.ParseJSONValue(Payload.ToJSON));
    TFile.WriteAllText(FileName,Root.Format(2),TEncoding.UTF8);TPluginSettings.Instance.LoadProject(ExtractFilePath(Project.FileName));
   end;
  end;
  Value:=Root.GetValue('authoring');if Assigned(Value) then Reply.AddPair('project',TJSONObject.ParseJSONValue(Value.ToJSON)) else Reply.AddPair('project',TJSONObject.Create);
  Reply.AddPair('global',TJSONObject.ParseJSONValue(Global.ToJSON));
  Reply.AddPair('projectFile',Project.FileName);
  Browser.ExecuteScript('window.xmlDocWorkbench?.receiveAuthoring('+Reply.ToJSON+');');
 finally Registry.Free;Reply.Free;Global.Free;Root.Free;end;
end;

procedure TProjectDocumentation.QuickDoc(Browser:TXmlDocBrowser);
var View:IOTAEditView;EditPos:TOTAEditPos;CharPos:TOTACharPos;Utf8:UTF8String;
begin
 View:=(BorlandIDEServices as IOTAEditorServices).TopView;if not Assigned(View) then Exit;
 FQuickSource:=EditorSource(View.Buffer);FQuickFile:=View.Buffer.FileName;EditPos:=View.CursorPos;FQuickLine:=EditPos.Line;View.ConvertPos(True,EditPos,CharPos);
 Utf8:=UTF8Encode(FQuickSource);FQuickPosition:=Length(UTF8ToString(Copy(Utf8,1,View.CharPosToPos(CharPos))));FQuickPending:=True;Catalog('group',Browser);
end;
procedure TProjectDocumentation.ShowQuickDoc;
var Query,Reason:string;MatchesInfo:TArray<TCodeElementInfo>;Matches:TJSONArray;Root,Item:TJSONObject;E,Only:TCodeElementInfo;Model:TXmlDocModel;Resolved:Boolean;Parser:TDocParser;Browser:TXmlDocBrowser;
begin
 Browser:=FJobBrowser;var Editor:=SourceEditorForFile(FQuickFile);if not Assigned(Editor) or (EditorSource(Editor)<>FQuickSource) then begin Browser.ExecuteScript('window.bridge.setStatus("Source changed — request Quick documentation again");');Exit;end;
 Parser:=TDocParser.Create;
 try ConfigureDeclarationContext(Parser,nil,FQuickFile);Parser.ParseSource(FQuickSource,FQuickFile);MatchesInfo:=ResolveDocumentationExpression(Parser,FQuickSource,FQuickPosition,FQuickLine,FElements.Values.ToArray,Query,Reason);
 finally Parser.Free;end;
 Root:=TJSONObject.Create;Matches:=TJSONArray.Create;Root.AddPair('matches',Matches);Root.AddPair('query',Query);Model:=TXmlDocModel.Create;
 try
  for E in MatchesInfo do begin
   if FEffective.ContainsKey(Key(E.FileName,E.SymbolId)) then Model.FromJson(FEffective[Key(E.FileName,E.SymbolId)]) else Model.LoadFromXml(E.ExistingDocXml);Item:=TJSONObject.Create;Item.AddPair('name',E.Name);Item.AddPair('signature',E.Signature);
   Item.AddPair('symbolId',E.SymbolId);Item.AddPair('fileName',E.FileName);Item.AddPair('lineNumber',TJSONNumber.Create(E.LineNumber));
   Item.AddPair('doc',TJSONObject.ParseJSONValue(Model.ToJson));Matches.AddElement(Item);Only:=E;
  end;
  Resolved:=(Matches.Count=1) and (Reason='');Root.AddPair('reason',Reason);
  Root.AddPair('resolved',TJSONBool.Create(Resolved));
  Browser.ExecuteScript('window.xmlDocWorkbench?.receiveQuickDoc('+Root.ToJSON+');');
  if Resolved then begin
   if not Assigned(FQuickPreview) then FQuickPreview:=TQuickDocPreview.Create;
   if FEffective.ContainsKey(Key(Only.FileName,Only.SymbolId)) then Model.FromJson(FEffective[Key(Only.FileName,Only.SymbolId)]) else Model.LoadFromXml(Only.ExistingDocXml);FQuickPreview.ShowPreview(Only,Model,Mouse.CursorPos);
  end;
 finally Model.Free;Root.Free;end;
end;

procedure ReplaceSource(Editor:IOTASourceEditor;const Source:string);
var Reader:IOTAEditReader;Writer:IOTAEditWriter;Chunk:TBytes;Offset,N:Integer;Utf8:UTF8String;BOM:Boolean;
begin
 if SourceEditProtection(Editor.FileName)<>'' then raise Exception.Create(SourceEditProtection(Editor.FileName));
 Reader:=Editor.CreateReader;SetLength(Chunk,32768);Offset:=0;BOM:=False;
 repeat N:=Reader.GetText(Offset,PAnsiChar(Chunk),Length(Chunk));
 if Offset=0 then BOM:=(N>=3) and (Chunk[0]=$EF) and (Chunk[1]=$BB) and (Chunk[2]=$BF);
 Inc(Offset,N);until N<Length(Chunk);Reader:=nil;
 Utf8:=UTF8Encode(Source);if BOM then Utf8:=UTF8String(AnsiChar($EF)+AnsiChar($BB)+AnsiChar($BF))+Utf8;
 Writer:=Editor.CreateUndoableWriter;Writer.CopyTo(0);Writer.DeleteTo(Offset);Writer.Insert(PAnsiChar(Utf8));Writer:=nil;
end;
procedure TProjectDocumentation.ApplyBatch(Changes:TJSONArray;Browser:TXmlDocBrowser);
var Sorted:TList<TJSONObject>;Plans:TDictionary<string,string>;Change,ElementJson,DocJson:TJSONObject;
 E:TCodeElementInfo;Model:TXmlDocModel;FileName,Source,Session:string;Editor:IOTASourceEditor;Actions:IOTAActionServices;
 I:Integer;Plan:TPair<string,string>;Seen:TDictionary<string,Boolean>;
begin
 if not Assigned(Changes) then Exit;
 Sorted:=TList<TJSONObject>.Create;Plans:=TDictionary<string,string>.Create;Seen:=TDictionary<string,Boolean>.Create;Model:=TXmlDocModel.Create;
 try
  for I:=0 to Changes.Count-1 do Sorted.Add(Changes.Items[I] as TJSONObject);
  Sorted.Sort(TComparer<TJSONObject>.Construct(function(const A,B:TJSONObject):Integer
   begin Result:=B.GetValue<TJSONObject>('element').GetValue<Integer>('lineNumber',0)-A.GetValue<TJSONObject>('element').GetValue<Integer>('lineNumber',0);end));
  // Validate the entire selection before the first write. Apply each file in one undo operation.
  for Change in Sorted do begin
   ElementJson:=Change.GetValue<TJSONObject>('element');DocJson:=Change.GetValue<TJSONObject>('doc');
   FileName:=ElementJson.GetValue<string>('fileName','');
   if SourceEditProtection(FileName)<>'' then raise Exception.Create(SourceEditProtection(FileName)+': '+FileName);
   var ChangeKey:=Key(FileName,ElementJson.GetValue<string>('symbolId',''));
   if Seen.ContainsKey(ChangeKey) then raise Exception.Create('Duplicate declaration in batch');Seen.Add(ChangeKey,True);
   if not FElements.TryGetValue(Key(FileName,ElementJson.GetValue<string>('symbolId','')),E) then raise Exception.Create('Refresh the project workspace before applying summaries');
   Session:=FSessions[LowerCase(FileName)];
   if (ElementJson.GetValue<string>('sessionId','')<>Session) or (ElementJson.GetValue<string>('sourceRevision','')<>SourceRevision(FSources[LowerCase(FileName)])) then raise Exception.Create('Stale documentation selection');
   Editor:=SourceEditorForFile(FileName);if Assigned(Editor) then Source:=EditorSource(Editor) else Source:=ReadSourceFile(FileName);
   if Source<>FSources[LowerCase(FileName)] then raise Exception.Create('Source changed: '+FileName);
   if not Plans.ContainsKey(FileName) then Plans.Add(FileName,Source);
   Model.FromJson(DocJson.ToJSON);if Model.ParseError<>'' then raise Exception.Create('Invalid documentation XML');
   Source:=TDocCodeGenerator.ApplyToSourceText(Plans[FileName],E,Model);Plans[FileName]:=Source;
  end;
  Actions:=BorlandIDEServices as IOTAActionServices;
  for Plan in Plans do begin
   Editor:=SourceEditorForFile(Plan.Key);
   if not Assigned(Editor) then begin if not Actions.OpenFile(Plan.Key) then raise Exception.Create('Cannot open '+Plan.Key);Editor:=SourceEditorForFile(Plan.Key);end;
   if not Assigned(Editor) then raise Exception.Create('Source editor is unavailable');
   if EditorSource(Editor)<>FSources[LowerCase(Plan.Key)] then raise Exception.Create('Source changed before apply');
   ReplaceSource(Editor,Plan.Value);
  end;
  Browser.ExecuteScript('window.bridge.setStatus("Applied selected summaries");');Catalog('project',Browser);
 finally Seen.Free;Model.Free;Plans.Free;Sorted.Free;end;
end;
function TProjectDocumentation.Handle(Message:TJSONObject;Browser:TXmlDocBrowser):Boolean;
var Kind,FileName,SymbolId,Selection,ProjectFile:string;Project:IOTAProject;Group:IOTAProjectGroup;Actions:IOTAActionServices;Editor:IOTASourceEditor;View:IOTAEditView;
 Pos:TOTAEditPos;Elide:IOTAElideActions;Utf8Selection:UTF8String;E:TCodeElementInfo;Parser:TDocParser;Found:Boolean;J:TJSONString;Recovery:TJSONObject;DraftId:string;
begin
 Kind:=Message.GetValue<string>('type','');Result:=(Kind='recoverDraft') or (Kind='cancelAnalysis') or (Kind='requestCatalog') or (Kind='openSymbol') or (Kind='batchUpdated') or (Kind='copySelection') or (Kind='requestQuickDoc') or (Kind='foldDocumentation') or (Kind='loadAuthoring') or (Kind='saveAuthoring') or (Kind='draftUpdated') or (Kind='listDrafts');if not Result then Exit;
 Recovery:=nil;
 try
 try
  if Kind='recoverDraft' then begin
   DraftId:=Message.GetValue<string>('draftId','');if not TRegEx.IsMatch(DraftId,'^[0-9a-fA-F]{64}$') then raise Exception.Create('Invalid draft identity');
   Recovery:=TJSONObject.ParseJSONValue(TFile.ReadAllText(TPath.Combine(DraftDirectory,DraftId+'.json'))) as TJSONObject;
   if not Assigned(Recovery) then raise Exception.Create('Draft is invalid');
   if Recovery.GetValue<string>('locationId','')='' then raise Exception.Create('This legacy draft has no stable source location. Its content is retained; review and copy it manually from the drafts folder.');
   for var Field in ['fileName','symbolId','locationId','projectFile'] do begin Message.RemovePair(Field).Free;Message.AddPair(Field,Recovery.GetValue<string>(Field,''));end;
  end;
  if Assigned(FQuickPreview) then FQuickPreview.HidePreview;
  if (Kind='draftUpdated') or (Kind='listDrafts') then Draft(Message,Browser)
  else if (Kind='loadAuthoring') or (Kind='saveAuthoring') then Authoring(Message,Browser)
  else if Kind='requestQuickDoc' then QuickDoc(Browser)
  else if Kind='foldDocumentation' then begin
    View:=(BorlandIDEServices as IOTAEditorServices).TopView;
    if Assigned(View) and Supports(View,IOTAElideActions,Elide) then Elide.ElideDocRegions;
  end
  else if Kind='cancelAnalysis' then CancelAnalysis
  else if Kind='requestCatalog' then begin FQuickPending:=False;Catalog(Message.GetValue<string>('scope','project'),Browser);end
  else if Kind='batchUpdated' then ApplyBatch(Message.GetValue<TJSONArray>('changes'),Browser)
  else if Kind='copySelection' then begin
   View:=(BorlandIDEServices as IOTAEditorServices).TopView;
   if Assigned(View) then begin
    Editor:=View.Buffer;Selection:=EditorSource(Editor);
    // Selection coordinates are character positions in the source buffer.
    Utf8Selection:=UTF8Encode(Selection);
    Selection:=UTF8ToString(Copy(Utf8Selection,View.CharPosToPos(Editor.BlockStart)+1,View.CharPosToPos(Editor.BlockAfter)-View.CharPosToPos(Editor.BlockStart)));
    J:=TJSONString.Create(Selection);try Browser.ExecuteScript('window.xmlDocWorkbench?.receiveSelection('+J.ToJSON+');');finally J.Free;end;
   end;
  end else begin
   FileName:=Message.GetValue<string>('fileName','');SymbolId:=Message.GetValue<string>('symbolId','');
   if FileName='' then Exit;
   Actions:=BorlandIDEServices as IOTAActionServices;if not Actions.OpenFile(FileName) then Exit;
   Editor:=SourceEditorForFile(FileName);if not Assigned(Editor) then Exit;
   Parser:=TDocParser.Create;
   try
    Project:=nil;ProjectFile:=Message.GetValue<string>('projectFile','');
    if ProjectFile<>'' then begin
     Group:=(BorlandIDEServices as IOTAModuleServices).MainProjectGroup;
     if Assigned(Group) then for var I:=0 to Group.ProjectCount-1 do if SameText(Group.Projects[I].FileName,ProjectFile) then begin Project:=Group.Projects[I];Break;end;
     if not Assigned(Project) then raise Exception.Create('Project context is unavailable: '+ProjectFile);
    end;
    ConfigureDeclarationContext(Parser,Project,FileName);Parser.ParseSource(EditorSource(Editor),FileName);Found:=False;
    for E in Parser.GetAllElements do if (E.SymbolId=SymbolId) and ((Message.GetValue<string>('locationId','')='') or (Message.GetValue<string>('locationId','')=E.SymbolId+'@'+E.SourceSection)) then begin Found:=True;Break;end;
    if not Found then raise Exception.Create('Declaration changed — the draft has been retained; locate the declaration before recovering it');
    if Assigned(Recovery) then begin
     Recovery.AddPair('currentRevision',SourceRevision(EditorSource(Editor)));Recovery.AddPair('currentXml',E.ExistingDocXml);Recovery.AddPair('conflict',TJSONBool.Create(Recovery.GetValue<string>('baseXml','')<>E.ExistingDocXml));
     Recovery.AddPair('readOnly',TJSONBool.Create(SourceEditProtection(FileName)<>''));
     Browser.ExecuteScript('window.xmlDocWorkbench?.receiveRecovery('+Recovery.ToJSON+');');
    end;
    Message.RemovePair('line').Free;Message.AddPair('line',TJSONNumber.Create(E.LineNumber));
    View:=Editor.EditViews[0];Pos.Line:=E.LineNumber;Pos.Col:=1;View.SetCursorPos(Pos);View.MoveViewToCursor;View.Paint;
   finally Parser.Free;end;
  end;
 except on Ex:Exception do begin J:=TJSONString.Create(Ex.Message);try Browser.ExecuteScript('window.bridge.setStatus('+J.ToJSON+');');finally J.Free;end;end;end;
 finally Recovery.Free;end;
end;
end.
