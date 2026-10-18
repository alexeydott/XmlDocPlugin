unit XmlDoc.Plugin.ProjectDocumentation;
interface
uses System.SysUtils,System.JSON,System.Generics.Collections,ToolsAPI,XmlDoc.Consts,XmlDoc.Plugin.Browser,XmlDoc.Plugin.QuickDocPreview;
type
 TProjectDocumentation=class
 private
  FElements:TDictionary<string,TCodeElementInfo>;
  FQuickPreview:TQuickDocPreview;
  FEffective:TDictionary<string,string>;
  FSources,FSessions:TDictionary<string,string>;
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
uses System.Classes,System.IOUtils,System.Generics.Defaults,XmlDoc.Parser,XmlDoc.Model,
 Vcl.Controls,System.RegularExpressions,System.Win.Registry,Winapi.Windows,System.Hash,XmlDoc.CodeGen,XmlDoc.Plugin.EditSession,XmlDoc.Plugin.DeclarationContext,XmlDoc.Plugin.Settings,XmlDoc.HelpGen.BatchParser,XmlDoc.SourceText;
constructor TProjectDocumentation.Create;
begin inherited;FEffective:=TDictionary<string,string>.Create;FElements:=TDictionary<string,TCodeElementInfo>.Create;
 FSources:=TDictionary<string,string>.Create;FSessions:=TDictionary<string,string>.Create;end;
destructor TProjectDocumentation.Destroy;
begin FEffective.Free;FQuickPreview.Free;FSessions.Free;FSources.Free;FElements.Free;inherited;end;
function TProjectDocumentation.Key(const FileName,SymbolId:string):string;
begin Result:=LowerCase(FileName)+'|'+SymbolId;end;
function DraftDirectory:string;
begin Result:=GetEnvironmentVariable('XMLDOC_DRAFT_DIR');if Result='' then Result:=TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'),'XmlDocPlugin\Drafts');Result:=TPath.GetFullPath(Result);end;
function TProjectDocumentation.DraftPath(Message:TJSONObject):string;
var Identity:string;
begin
 Identity:=Message.GetValue<string>('fileName','')+'|'+Message.GetValue<string>('declarationId',Message.GetValue<string>('symbolId',''))+'|'+Message.GetValue<string>('sessionId','');
 Result:=TPath.Combine(DraftDirectory,THashSHA2.GetHashString(Identity)+'.json');
end;
procedure TProjectDocumentation.Acknowledge(Message:TJSONObject);
var FileName:string;
begin FileName:=DraftPath(Message);if TFile.Exists(FileName) then TFile.Delete(FileName);end;
procedure TProjectDocumentation.Draft(Message:TJSONObject;Browser:TXmlDocBrowser);
var FileName,RootPath:string;Project:IOTAProject;Json,Reply:TJSONObject;Drafts:TJSONArray;
begin
 if Message.GetValue<string>('type','')='draftUpdated' then begin
  if (Message.GetValue<string>('fileName','')='') or (Message.GetValue<string>('symbolId','')='') then Exit;
  ForceDirectories(DraftDirectory);FileName:=DraftPath(Message);
  TFile.WriteAllText(FileName+'.tmp',Message.ToJSON,TEncoding.UTF8);
  if TFile.Exists(FileName) then TFile.Replace(FileName+'.tmp',FileName,'') else TFile.Move(FileName+'.tmp',FileName);
 end else begin
  Reply:=TJSONObject.Create;Drafts:=TJSONArray.Create;Reply.AddPair('drafts',Drafts);
  try
   Project:=GetActiveProject;RootPath:='';if Assigned(Project) then RootPath:=ExtractFilePath(Project.FileName);
   if TDirectory.Exists(DraftDirectory) then for FileName in TDirectory.GetFiles(DraftDirectory,'*.json') do begin
    Json:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName)) as TJSONObject;
    if not Assigned(Json) then Continue;
    if (RootPath<>'') and Json.GetValue<string>('fileName','').StartsWith(RootPath,True) then Drafts.AddElement(Json) else Json.Free;
   end;
   Browser.ExecuteScript('window.xmlDocWorkbench?.receiveDrafts('+Reply.ToJSON+');');
  finally Reply.Free;end;
 end;
end;

procedure TProjectDocumentation.Catalog(const Scope:string;Browser:TXmlDocBrowser);
var Files:TList<string>;Services:IOTAModuleServices;Project:IOTAProject;Group:IOTAProjectGroup;
 I,J:Integer;EditorServices:IOTAEditorServices;FileName,Source,Session:string;Parser:TDocParser;Model:TXmlDocModel;E:TCodeElementInfo;
 Root,Json,Param:TJSONObject;Elements,Errors,Params,Generics,Interfaces:TJSONArray;P:TParamInfo;G:string;Editor:IOTASourceEditor;Batch:TBatchParser;Context:TDocParser;FileProjects:TDictionary<string,IOTAProject>;
 procedure AddProject(AProject:IOTAProject);
 var K:Integer;F:string;
 begin
  if not Assigned(AProject) then Exit;
  for K:=0 to AProject.GetModuleCount-1 do begin
   F:=AProject.GetModule(K).FileName;
   if SameText(ExtractFileExt(F),'.pas') and not Files.Contains(F) then Files.Add(F);
   if SameText(ExtractFileExt(F),'.pas') then FileProjects.AddOrSetValue(LowerCase(F),AProject);
  end;
 end;
begin
 FileProjects:=TDictionary<string,IOTAProject>.Create;Files:=TList<string>.Create;Root:=TJSONObject.Create;Elements:=TJSONArray.Create;Errors:=TJSONArray.Create;
 Root.AddPair('elements',Elements);Root.AddPair('errors',Errors);
 try
  Services:=BorlandIDEServices as IOTAModuleServices;Project:=Services.GetActiveProject;
  if Assigned(Project) then TPluginSettings.Instance.LoadProject(ExtractFilePath(Project.FileName));
  if Scope='group' then begin Group:=Services.MainProjectGroup;if Assigned(Group) then for I:=0 to Group.ProjectCount-1 do AddProject(Group.Projects[I]);end
  else if Scope='project' then AddProject(Project);
  if Files.Count=0 then begin
   if Supports(BorlandIDEServices,IOTAEditorServices,EditorServices) and Assigned(EditorServices.TopView) and Assigned(EditorServices.TopView.Buffer) then
     Files.Add(EditorServices.TopView.Buffer.FileName);
  end;
  FElements.Clear;FSources.Clear;FSessions.Clear;FEffective.Clear;
  for FileName in Files do begin
   Parser:=TDocParser.Create;Model:=TXmlDocModel.Create;
   try
    try
     Editor:=SourceEditorForFile(FileName);if Assigned(Editor) then Source:=EditorSource(Editor) else Source:=ReadSourceFile(FileName);
     Session:=TGUID.NewGuid.ToString;FSources.AddOrSetValue(LowerCase(FileName),Source);FSessions.AddOrSetValue(LowerCase(FileName),Session);
     if FileProjects.ContainsKey(LowerCase(FileName)) then ConfigureDeclarationContext(Parser,FileProjects[LowerCase(FileName)]) else ConfigureDeclarationContext(Parser);
     Parser.SourceFiles:=Files.ToArray;Parser.ParseSource(Source,FileName);
     for E in Parser.GetAllElements do begin
      if (E.Name='') or FElements.ContainsKey(Key(FileName,E.SymbolId)) then Continue;
      FElements.Add(Key(FileName,E.SymbolId),E);Json:=TJSONObject.Create;
      Json.AddPair('kind',E.Kind.ToString);Json.AddPair('name',E.Name);Json.AddPair('fullName',E.FullName);
      Json.AddPair('qualifiedParent',E.QualifiedParent);Json.AddPair('visibility',E.Visibility);
      Json.AddPair('returnType',E.ReturnType);Json.AddPair('lineNumber',TJSONNumber.Create(E.LineNumber));
      AddEditContext(Json,E,FileName,Session,Source);
      Params:=TJSONArray.Create;for P in E.Params do begin Param:=TJSONObject.Create;Param.AddPair('name',P.Name);Param.AddPair('type',P.TypeName);Param.AddPair('isVar',TJSONBool.Create(P.IsVar));Param.AddPair('isConst',TJSONBool.Create(P.IsConst));Param.AddPair('isOut',TJSONBool.Create(P.IsOut));Params.AddElement(Param);end;Json.AddPair('params',Params);
      Generics:=TJSONArray.Create;for G in E.GenericParams do Generics.Add(G);Json.AddPair('genericParams',Generics);
      Interfaces:=TJSONArray.Create;for G in E.Implements do Interfaces.Add(G);Json.AddPair('implements',Interfaces);
      Model.LoadFromXml(E.ExistingDocXml);Json.AddPair('doc',TJSONObject.ParseJSONValue(Model.ToJson));Elements.AddElement(Json);
     end;
    except on Ex:Exception do Errors.Add(FileName+': '+Ex.Message);end;
   finally Model.Free;Parser.Free;end;
  end;
  Batch:=TBatchParser.Create;Context:=TDocParser.Create;
  try
   try
    ConfigureDeclarationContext(Context);Batch.SourceSnapshots:=CurrentSourceSnapshots;Batch.SearchPaths:=Context.SearchPaths;Batch.Defines:=Context.Defines;Batch.Platform:=Context.Platform;
    Batch.OnConfigureParser:=procedure(P:TDocParser;FileName:string) begin
     if FileProjects.ContainsKey(LowerCase(FileName)) then ConfigureDeclarationContext(P,FileProjects[LowerCase(FileName)]);
    end;
    Batch.ParseAll(Files.ToArray);
    for var Value in Elements do begin
     var Item:=Value as TJSONObject;var Id:=Item.GetValue<string>('symbolId','');
     if Batch.SymbolIndex.ContainsKey(Id) then begin
      var Effective:=Batch.SymbolIndex[Id].Doc.ToJson;FEffective.AddOrSetValue(Key(Item.GetValue<string>('fileName',''),Id),Effective);
      Item.AddPair('effectiveDoc',TJSONObject.ParseJSONValue(Effective));
     end;
    end;
   except on Ex:Exception do Errors.Add('Inherited documentation: '+Ex.Message);end;
  finally Context.Free;Batch.Free;end;
  Browser.ExecuteScript('window.xmlDocWorkbench?.receiveCatalog('+Root.ToJSON+');');
 finally Root.Free;Files.Free;FileProjects.Free;end;
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
var View:IOTAEditView;EditPos:TOTAEditPos;CharPos:TOTACharPos;Position,First,Last,Dot:Integer;
 Source,Prefix,Query,Owner:string;Utf8:UTF8String;Matches:TJSONArray;Root,Item:TJSONObject;
 Pair:TPair<string,TCodeElementInfo>;E:TCodeElementInfo;Model:TXmlDocModel;Only:TCodeElementInfo;Resolved:Boolean;
begin
 View:=(BorlandIDEServices as IOTAEditorServices).TopView;if not Assigned(View) then Exit;
 Source:=EditorSource(View.Buffer);EditPos:=View.CursorPos;View.ConvertPos(True,EditPos,CharPos);Position:=View.CharPosToPos(CharPos);
 Utf8:=UTF8Encode(Source);Prefix:=UTF8ToString(Copy(Utf8,1,Position));First:=Length(Prefix);Last:=First+1;
 while (First>0) and CharInSet(Source[First],['A'..'Z','a'..'z','0'..'9','_','.']) do Dec(First);
 while (Last<=Length(Source)) and CharInSet(Source[Last],['A'..'Z','a'..'z','0'..'9','_','.']) do Inc(Last);
 Query:=Copy(Source,First+1,Last-First-1);if Query='' then Exit;
 Catalog('project',Browser);Owner:='';Dot:=LastDelimiter('.',Query);if Dot>0 then begin Owner:=Copy(Query,1,Dot-1);Query:=Copy(Query,Dot+1,MaxInt);end;
 Root:=TJSONObject.Create;Matches:=TJSONArray.Create;Root.AddPair('matches',Matches);Root.AddPair('query',Query);Model:=TXmlDocModel.Create;
 try
  for Pair in FElements do begin E:=Pair.Value;
   if not SameText(E.Name,Query) then Continue;
   // Qualified type/member references can be resolved exactly. Instance-qualified
   // and overloaded references are shown as candidates instead of guessed.
   if (Owner<>'') and not SameText(E.QualifiedParent,Owner) and not SameText(E.FullName,Owner+'.'+Query) then Continue;
   if FEffective.ContainsKey(Key(E.FileName,E.SymbolId)) then Model.FromJson(FEffective[Key(E.FileName,E.SymbolId)]) else Model.LoadFromXml(E.ExistingDocXml);Item:=TJSONObject.Create;Item.AddPair('name',E.Name);Item.AddPair('signature',E.Signature);
   Item.AddPair('symbolId',E.SymbolId);Item.AddPair('fileName',E.FileName);Item.AddPair('lineNumber',TJSONNumber.Create(E.LineNumber));
   Item.AddPair('doc',TJSONObject.ParseJSONValue(Model.ToJson));Matches.AddElement(Item);Only:=E;
  end;
  Resolved:=(Matches.Count=1) and ((Owner<>'') or (Only.Kind in [dekUnit,dekClass,dekInterface,dekRecord,dekType]));
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
var Kind,FileName,SymbolId,Selection:string;Actions:IOTAActionServices;Editor:IOTASourceEditor;View:IOTAEditView;
 Pos:TOTAEditPos;Elide:IOTAElideActions;Utf8Selection:UTF8String;E:TCodeElementInfo;Parser:TDocParser;Found:Boolean;J:TJSONString;
begin
 Kind:=Message.GetValue<string>('type','');Result:=(Kind='requestCatalog') or (Kind='openSymbol') or (Kind='batchUpdated') or (Kind='copySelection') or (Kind='requestQuickDoc') or (Kind='foldDocumentation') or (Kind='loadAuthoring') or (Kind='saveAuthoring') or (Kind='draftUpdated') or (Kind='listDrafts');if not Result then Exit;
 try
  if Assigned(FQuickPreview) then FQuickPreview.HidePreview;
  if (Kind='draftUpdated') or (Kind='listDrafts') then Draft(Message,Browser)
  else if (Kind='loadAuthoring') or (Kind='saveAuthoring') then Authoring(Message,Browser)
  else if Kind='requestQuickDoc' then QuickDoc(Browser)
  else if Kind='foldDocumentation' then begin
    View:=(BorlandIDEServices as IOTAEditorServices).TopView;
    if Assigned(View) and Supports(View,IOTAElideActions,Elide) then Elide.ElideDocRegions;
  end
  else if Kind='requestCatalog' then Catalog(Message.GetValue<string>('scope','project'),Browser)
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
   try ConfigureDeclarationContext(Parser);Parser.ParseSource(EditorSource(Editor),FileName);Found:=False;
    for E in Parser.GetAllElements do if E.SymbolId=SymbolId then begin Found:=True;Break;end;
    if not Found then raise Exception.Create('Declaration changed — refresh the workspace');
    View:=Editor.EditViews[0];Pos.Line:=E.LineNumber;Pos.Col:=1;View.SetCursorPos(Pos);View.MoveViewToCursor;View.Paint;
   finally Parser.Free;end;
  end;
 except on Ex:Exception do begin J:=TJSONString.Create(Ex.Message);try Browser.ExecuteScript('window.bridge.setStatus('+J.ToJSON+');');finally J.Free;end;end;end;
end;
end.
