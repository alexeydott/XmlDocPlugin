/// <summary>Coordinates AI requests, source freshness checks and explicit proposal application inside the IDE.</summary>
unit XmlDoc.Plugin.AIAssistant;
interface
uses System.Classes,System.SysUtils,System.JSON,System.Generics.Collections,Vcl.ExtCtrls,XmlDoc.Plugin.Browser,XmlDoc.Parser,XmlDoc.Consts,
 XmlDoc.AI.Contracts,XmlDoc.AI.Prompts;
type
 /// <summary>Executes a prepared request outside the UI thread and exposes its proposal or error after completion.</summary>
 TAIWorker=class(TThread)
 private
  FTransport:IAITransport;FRequest:TAIHttpRequest;
 protected procedure Execute;override;
 public
  Proposal:TAIProposal;Error:string;
  constructor Create(const Request:TAIHttpRequest;const Transport:IAITransport);
  procedure Cancel;
 end;
 /// <summary>Owns request preparation, worker cancellation and source-checked application for an Inspector or Explorer view.</summary>
 TAIAssistant=class(TComponent)
 private
  FTimer:TTimer;FWorker:TAIWorker;FBrowser:TXmlDocBrowser;
  FPrepared:TAIHttpRequest;FContext:TAIContext;FFragments:TArray<TAIProtectedFragment>;
  FSectionFragments:TDictionary<string,TArray<TAIProtectedFragment>>;FHasReturns,FHasRemarks:Boolean;
  FOriginal:TJSONObject;FRequestId,FFile,FSession,FError,FOriginalSummary:string;FTarget:TCodeElementInfo;
  FReady,FCheckOnly:Boolean;FOperation:TAIOperation;FParameterNames:TArray<string>;FTransportFactory:TFunc<IAITransport>;
  function NewTransport:IAITransport;
  function IsBusy:Boolean;
  function Capture(const Summary,Instruction:string):TAIContext;
  function Fresh:Boolean;
  function ProtectSection(const Name,Text:string):string;
  function RestoreSection(const Name,Text:string):string;
  procedure Reply(Value:TJSONObject);
  procedure Tick(Sender:TObject);
  procedure Stop;
 protected procedure Notification(AComponent:TComponent;Operation:TOperation);override;
 public
  property Busy:Boolean read IsBusy;
  property TransportFactory:TFunc<IAITransport> read FTransportFactory write FTransportFactory;
  constructor Create(AOwner:TComponent);override;
  destructor Destroy;override;
  function Handle(Message:TJSONObject;Browser:TXmlDocBrowser;Parser:TDocParser;const Target:TCodeElementInfo;const FileName,Session:string):Boolean;
 end;
implementation
uses System.IOUtils,System.StrUtils,ToolsAPI,XmlDoc.AI.Context,XmlDoc.AI.OpenAI,XmlDoc.AI.Transport,XmlDoc.Plugin.AISettings,
 XmlDoc.Plugin.DeclarationContext,XmlDoc.Plugin.EditSession,XmlDoc.Model,XmlDoc.SourceText,XmlDoc.AI.Text;
constructor TAIWorker.Create(const Request:TAIHttpRequest;const Transport:IAITransport);
begin inherited Create(True);FreeOnTerminate:=False;FRequest:=Request;FTransport:=Transport;end;
procedure TAIWorker.Execute;
begin try Proposal:=ExecuteAI(FTransport,FRequest,procedure(Delay:Integer)
 var Remaining,Slice:Integer;
 begin
  Remaining:=Delay;repeat
   if Terminated then raise EAIError.Create('AI request cancelled');
   Slice:=Remaining;if Slice>25 then Slice:=25;
   if Slice>0 then TThread.Sleep(Slice);Dec(Remaining,Slice);
  until Remaining=0;
 end);except on E:Exception do Error:=E.Message;end;FRequest.Authorization:='';end;
procedure TAIWorker.Cancel;
begin Terminate;FTransport.Cancel;end;
function TAIAssistant.IsBusy:Boolean;
begin Result:=Assigned(FWorker) and not FWorker.Finished;end;
function TAIAssistant.NewTransport:IAITransport;
begin if Assigned(FTransportFactory) then Result:=FTransportFactory() else Result:=TAIHTTPTransport.Create;end;
constructor TAIAssistant.Create(AOwner:TComponent);
begin inherited;FSectionFragments:=TDictionary<string,TArray<TAIProtectedFragment>>.Create;FTimer:=TTimer.Create(Self);FTimer.Enabled:=False;FTimer.Interval:=30;FTimer.OnTimer:=Tick;end;
destructor TAIAssistant.Destroy;
begin Stop;FOriginal.Free;FSectionFragments.Free;inherited;end;
function TAIAssistant.ProtectSection(const Name,Text:string):string;
var Fragments:TArray<TAIProtectedFragment>;
begin Result:=ProtectSummary(Text,Fragments);FSectionFragments.AddOrSetValue(LowerCase(Name),Fragments);end;
function TAIAssistant.RestoreSection(const Name,Text:string):string;
var Fragments:TArray<TAIProtectedFragment>;
begin FSectionFragments.TryGetValue(LowerCase(Name),Fragments);Result:=RestoreSummary(Text,Fragments);end;
procedure TAIAssistant.Stop;
begin
 FTimer.Enabled:=False;if Assigned(FWorker) then begin FWorker.Cancel;FWorker.WaitFor;FreeAndNil(FWorker);end;
 FPrepared.Authorization:='';FReady:=False;
end;
procedure TAIAssistant.Notification(AComponent:TComponent;Operation:TOperation);
begin inherited;if (Operation=opRemove) and (AComponent=FBrowser) then begin FBrowser:=nil;Stop;end;end;
procedure TAIAssistant.Reply(Value:TJSONObject);
begin
 try if Assigned(FBrowser) then begin Value.AddPair('requestId',FRequestId);FBrowser.ExecuteScript('window.xmlDocAI?.receive('+Value.ToJSON+');');end;finally Value.Free;end;
end;
function TAIAssistant.Capture(const Summary,Instruction:string):TAIContext;
var P:TDocParser;Source,Terms,ProjectDir:string;Editor:IOTASourceEditor;Config:TJSONObject;Element,Found:TCodeElementInfo;Matches:Integer;Project:IOTAProject;
begin
 Editor:=SourceEditorForFile(FFile);if Assigned(Editor) then Source:=EditorSource(Editor) else Source:=ReadSourceFile(FFile);
 P:=TDocParser.Create;Config:=nil;
 try
  Project:=DocumentationProjectForFile(FFile);ConfigureCapturedDeclarationContext(P,Project,FFile,CurrentSourceSnapshots);P.ParseSource(Source,FFile);Found:=Default(TCodeElementInfo);Matches:=0;
  for Element in P.GetAllElements do if (Element.SymbolId=FTarget.SymbolId) and (Element.LineNumber=FTarget.LineNumber) and (Element.SourceSection=FTarget.SourceSection) then begin Found:=Element;Inc(Matches);end;
  if Matches<>1 then raise EAIError.Create('Selected declaration has changed');
  Terms:='';if Assigned(Project) then begin ProjectDir:=ExtractFilePath(Project.FileName);if TFile.Exists(TPath.Combine(ProjectDir,'.xmldocplugin.json')) then begin
   Config:=TJSONObject.ParseJSONValue(TFile.ReadAllText(TPath.Combine(ProjectDir,'.xmldocplugin.json'),TEncoding.UTF8)) as TJSONObject;
   if Assigned(Config) and Assigned(Config.GetValue('authoring.terminology')) then Terms:=Config.GetValue('authoring.terminology').ToJSON;
  end;end;
  Result:=CaptureMethodContext(P,Found,Summary,Terms,Instruction,FOperation<>aoRephrase);
 finally Config.Free;P.Free;end;
end;
function TAIAssistant.Fresh:Boolean;
var Now:TAIContext;
begin
 Result:=False;
 if not Assigned(FOriginal) then Exit;
 try
  if not Assigned(SourceEditorForFile(FFile)) or (SourceEditProtection(FFile)<>'') then Exit;
  if Assigned(SourceEditorForFile(FFile)) and (SourceRevision(EditorSource(SourceEditorForFile(FFile)))<>FOriginal.GetValue<string>('sourceRevision','')) then Exit;
  Now:=Capture(FContext.Documentation,FContext.UserInstruction);Result:=Now.Fingerprint=FContext.Fingerprint;
 except Result:=False;end;
end;
procedure TAIAssistant.Tick(Sender:TObject);
var Data:TJSONObject;Items:TJSONArray;
begin
 if not Assigned(FWorker) or not FWorker.Finished then Exit;FTimer.Enabled:=False;
 try
 try
  if FWorker.Error<>'' then begin Reply(TJSONObject.Create.AddPair('state','error').AddPair('message',FWorker.Error));Exit;end;
  if FCheckOnly then begin Reply(TJSONObject.Create.AddPair('state','checked'));Exit;end;
  RestoreSummary(FWorker.Proposal.Summary,FFragments);
  if FOperation<>aoRephrase then for var Parameter in FWorker.Proposal.Parameters do begin
   var Found:=False;for var Declared in FTarget.Params do if SameText(Declared.Name,Parameter.Name) then Found:=True;
   if not Found then raise EAIError.Create('Invalid proposal contract');
   RestoreSection('param:'+Parameter.Name,Parameter.Description);
  end;
  FHasReturns:=(FOperation<>aoRephrase) and FWorker.Proposal.HasReturns and (FTarget.ReturnType<>'');
  FHasRemarks:=(FOperation<>aoRephrase) and FWorker.Proposal.HasRemarks;
  if FHasReturns then RestoreSection('returns',FWorker.Proposal.Returns);
  if FHasRemarks then RestoreSection('remarks',FWorker.Proposal.Remarks);
  FReady:=Fresh;Data:=TJSONObject.Create.AddPair('state','proposal').AddPair('fresh',TJSONBool.Create(FReady)).AddPair('summary',FWorker.Proposal.Summary);
  var Parameters:=TJSONArray.Create;Data.AddPair('parameters',Parameters);FParameterNames:=nil;
  if FOperation<>aoRephrase then for var Parameter in FWorker.Proposal.Parameters do begin
   var Name:='';for var Declared in FTarget.Params do if SameText(Declared.Name,Parameter.Name) then Name:=Declared.Name;
   FParameterNames:=FParameterNames+[Name];Parameters.AddElement(TJSONObject.Create.AddPair('name',Name).AddPair('description',Parameter.Description));
  end;
  if FHasReturns then Data.AddPair('returns',FWorker.Proposal.Returns);
  if FHasRemarks then Data.AddPair('remarks',FWorker.Proposal.Remarks);
  var Changes:=TJSONArray.Create;Data.AddPair('changes',Changes);for var Change in FWorker.Proposal.Changes do Changes.Add(Change);
  Items:=TJSONArray.Create;Data.AddPair('uncertainties',Items);for var Item in FWorker.Proposal.Uncertainties do Items.Add(Item);
  // Validate opaque XML tokens before exposing an applicable proposal.
  Reply(Data);
 except on E:Exception do begin FReady:=False;Reply(TJSONObject.Create.AddPair('state','error').AddPair('message',E.Message));end;end;
 finally FreeAndNil(FWorker);FPrepared.Authorization:='';end;
end;
function TAIAssistant.Handle(Message:TJSONObject;Browser:TXmlDocBrowser;Parser:TDocParser;const Target:TCodeElementInfo;const FileName,Session:string):Boolean;
var Kind,OperationName,ProjectDir,Summary,Instruction,ProfileId,TemplateId:string;Config,ProfileJson,Template:TJSONObject;Profiles,Templates:TJSONArray;Profile:TAIProfile;Prompt:TAIPrompt;Context:TAIContext;Operation:TAIOperation;
begin
 Kind:=Message.GetValue<string>('type','');Result:=Kind.StartsWith('ai');if not Result then Exit;
 Config:=nil;Templates:=nil;ProfileJson:=nil;Template:=nil;FBrowser:=Browser;
 try
 try
  if Kind='aiCancel' then begin if Message.GetValue<string>('requestId','')=FRequestId then Stop;Exit;end;
  if Kind='aiSettings' then begin var Project:=DocumentationProjectForFile(FileName);if Assigned(Project) then ShowAISettings(ExtractFilePath(Project.FileName)) else ShowAISettings;Browser.ExecuteScript('window.xmlDocAI?.reload();');Exit;end;
  if Kind='aiLoad' then begin
   var Data:=TJSONObject.Create.AddPair('state','configuration');Config:=LoadAIConfiguration;Data.AddPair('previewRequests',TJSONBool.Create(Config.GetValue<Boolean>('previewRequests',False)));Profiles:=TJSONArray.Create;Data.AddPair('profiles',Profiles);
   for var Item in Config.GetValue<TJSONArray>('profiles') do begin Profile:=AIProfileFromJson(Item as TJSONObject);Profiles.AddElement(TJSONObject.Create.AddPair('id',Profile.Id).AddPair('name',Profile.Name).AddPair('language',Profile.Language).AddPair('hasKey',TJSONBool.Create(ReadAIKey(Profile)<>'')));end;
   var Project:=DocumentationProjectForFile(FileName);ProjectDir:='';if Assigned(Project) then ProjectDir:=ExtractFilePath(Project.FileName);Data.AddPair('templates',AIPrompts(ProjectDir));FBrowser:=Browser;Browser.FreeNotification(Self);Reply(Data);Exit;
  end;
  if Kind='aiSend' then begin
   if Message.GetValue<string>('requestId','')<>FRequestId then raise EAIError.Create('AI request is no longer current');
   if Assigned(FWorker) then raise EAIError.Create('AI request is already running');
   if not FCheckOnly and not Fresh then raise EAIError.Create('Source changed — review again');
   FWorker:=TAIWorker.Create(FPrepared,NewTransport);FWorker.Start;FTimer.Enabled:=True;Reply(TJSONObject.Create.AddPair('state','running'));Exit;
  end;
  if Kind='aiApply' then begin
   if (Message.GetValue<string>('requestId','')<>FRequestId) or not FReady or not Fresh or not ValidateEdit(Message,Target,FileName,Session,Parser.SourceText) then raise EAIError.Create('Source changed — review again');
   if Message.GetValue<Boolean>('summarySelected',True) then Summary:=RestoreSummary(Message.GetValue<string>('summary'),FFragments)
   else Summary:=FOriginalSummary;
   FReady:=False;
   var Approved:=TJSONObject.Create.AddPair('state','approved').AddPair('summaryXml',Summary);var Parameters:=TJSONArray.Create;Approved.AddPair('parameters',Parameters);
   try
    if Message.GetValue<Boolean>('returnsSelected',False) then begin if not FHasReturns then raise EAIError.Create('Invalid proposal contract');Approved.AddPair('returnsXml',RestoreSection('returns',Message.GetValue<string>('returns')));end;
    if Message.GetValue<Boolean>('remarksSelected',False) then begin if not FHasRemarks then raise EAIError.Create('Invalid proposal contract');Approved.AddPair('remarksXml',RestoreSection('remarks',Message.GetValue<string>('remarks')));end;
    var Submitted:=Message.GetValue<TJSONArray>('parameters',nil);if Assigned(Submitted) then for var Item in Submitted do begin
     if not (Item is TJSONObject) then raise EAIError.Create('Invalid proposal contract');
     var Name:=TJSONObject(Item).GetValue<string>('name');if not MatchText(Name,FParameterNames) then raise EAIError.Create('Invalid proposal contract');
     for var Allowed in FParameterNames do if SameText(Allowed,Name) then Name:=Allowed;
     for var Existing in Parameters do if SameText(TJSONObject(Existing).GetValue<string>('name'),Name) then raise EAIError.Create('Invalid proposal contract');
     var Text:=RestoreSection('param:'+Name,TJSONObject(Item).GetValue<string>('description'));
     Parameters.AddElement(TJSONObject.Create.AddPair('name',Name).AddPair('description',Text));
    end;
    var Response:=Approved;Approved:=nil;Reply(Response);
   finally Approved.Free;end;Exit;
  end;
  if (Kind<>'aiPrepare') and (Kind<>'aiCheck') then raise EAIError.Create('Unknown AI command');
  Stop;FBrowser:=Browser;Browser.FreeNotification(Self);FRequestId:=Message.GetValue<string>('requestId','');if (FRequestId='') or (Length(FRequestId)>100) then raise EAIError.Create('Invalid AI request identity');
  FCheckOnly:=Kind='aiCheck';Config:=LoadAIConfiguration;ProfileId:=Message.GetValue<string>('profileId','');
  for var Item in Config.GetValue<TJSONArray>('profiles') do if (Item as TJSONObject).GetValue<string>('id')=ProfileId then ProfileJson:=Item as TJSONObject;
  if not Assigned(ProfileJson) then raise EAIError.Create('Choose an AI profile');Profile:=AIProfileFromJson(ProfileJson);
  if FCheckOnly then begin
   Context:=Default(TAIContext);Context.Signature:='Connection check';Context.Code:='No source code is included.';Context.Documentation:='Connection check';
   Prompt:=TAIPrompt.BuiltIn(aoRephrase);Prompt.UserText:='Reply with {"summary":"Connection OK","uncertainties":[]}. Check: {{documentation}}';FPrepared:=BuildAIRequest(Profile,Prompt,Context,ReadAIKey(Profile));
   FWorker:=TAIWorker.Create(FPrepared,NewTransport);FWorker.Start;FTimer.Enabled:=True;Reply(TJSONObject.Create.AddPair('state','running'));Exit;
  end;
  if not ValidateEdit(Message,Target,FileName,Session,Parser.SourceText) then raise EAIError.Create('Source changed — reload before applying');
  FFile:=FileName;FSession:=Session;FTarget:=Target;FreeAndNil(FOriginal);FOriginal:=Message.Clone as TJSONObject;
  Summary:=Message.GetValue<string>('summary','');Instruction:=Message.GetValue<string>('instruction','');FOriginalSummary:=Summary;
  OperationName:=Message.GetValue<string>('operation','');if OperationName='describe' then Operation:=aoDescribe else if OperationName='rephrase' then Operation:=aoRephrase else if OperationName='review' then Operation:=aoReview else raise EAIError.Create('Unknown AI operation');
  FOperation:=Operation;
  FSectionFragments.Clear;FHasReturns:=False;FHasRemarks:=False;
  Context:=Capture(Summary,Instruction);Context.Documentation:=ProtectSection('summary',Summary);FSectionFragments.TryGetValue('summary',FFragments);
  var OriginalDoc:=Message.GetValue<TJSONObject>('documentation',nil);
  if (Operation<>aoRephrase) and Assigned(OriginalDoc) then begin
   var Sections:=TJSONObject.Create.AddPair('summary',Context.Documentation);
   try
    for var Name in ['returns','remarks'] do Sections.AddPair(Name,ProtectSection(Name,OriginalDoc.GetValue<string>(Name,'')));
    var Parameters:=TJSONArray.Create;Sections.AddPair('parameters',Parameters);
    var OriginalParams:=OriginalDoc.GetValue<TJSONArray>('params',nil);if Assigned(OriginalParams) then for var Param in OriginalParams do begin
     var Name:=TJSONObject(Param).GetValue<string>('name');
     Parameters.AddElement(TJSONObject.Create.AddPair('name',Name).AddPair('description',ProtectSection('param:'+Name,TJSONObject(Param).GetValue<string>('description',''))));
    end;
    Context.Documentation:=Sections.ToJSON;
   finally Sections.Free;end;
  end;
  FContext:=Context;
  FParameterNames:=nil;Prompt:=TAIPrompt.BuiltIn(Operation);TemplateId:=Message.GetValue<string>('templateId',Prompt.Id);var Project:=DocumentationProjectForFile(FileName);ProjectDir:='';if Assigned(Project) then ProjectDir:=ExtractFilePath(Project.FileName);
  Templates:=AIPrompts(ProjectDir);for var Item in Templates do if (Item as TJSONObject).GetValue<string>('id')=TemplateId then Template:=Item as TJSONObject;
  if not Assigned(Template) or (Template.GetValue<string>('operation')<>OperationName) then raise EAIError.Create('Choose a matching AI template');Prompt.SystemText:=Template.GetValue<string>('system');Prompt.UserText:=Template.GetValue<string>('user');
  FPrepared:=BuildAIRequest(Profile,Prompt,Context,ReadAIKey(Profile));
  var Preview:=Config.GetValue<Boolean>('previewRequests',False) or Message.GetValue<Boolean>('forcePreview',False);
  var Prepared:=TJSONObject.Create.AddPair('state','prepared').AddPair('previewRequired',TJSONBool.Create(Preview)).AddPair('fingerprint',Context.Fingerprint);
  if Preview then begin Prepared.AddPair('url',FPrepared.URL);Prepared.AddPair('request',FPrepared.Body);end;
  var Slots:=TJSONArray.Create;Prepared.AddPair('fragments',Slots);for var Fragment in FFragments do Slots.AddElement(TJSONObject.Create.AddPair('token',Fragment.Token).AddPair('xml',Fragment.Xml));
  var SectionSlots:=TJSONObject.Create;Prepared.AddPair('sectionFragments',SectionSlots);
  for var Section in FSectionFragments do begin var Items:=TJSONArray.Create;SectionSlots.AddPair(Section.Key,Items);for var Fragment in Section.Value do Items.AddElement(TJSONObject.Create.AddPair('token',Fragment.Token).AddPair('xml',Fragment.Xml));end;
  Reply(Prepared);
 except on E:Exception do begin FPrepared.Authorization:='';var ErrorState:='error';if (Kind='aiLoad') or (Kind='aiSettings') then ErrorState:='configurationError';Reply(TJSONObject.Create.AddPair('state',ErrorState).AddPair('message',E.Message));end;end;
 finally Templates.Free;Config.Free;end;
end;
end.
