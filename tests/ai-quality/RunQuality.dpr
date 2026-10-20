program RunQuality;
{$APPTYPE CONSOLE}
uses Winapi.ActiveX,System.SysUtils,System.IOUtils,System.JSON,System.Hash,XmlDoc.AI.Contracts,XmlDoc.AI.Context,
 XmlDoc.AI.Prompts,XmlDoc.AI.OpenAI,XmlDoc.AI.Transport,XmlDoc.Parser,XmlDoc.Consts,
 XmlDoc.Model,XmlDoc.AI.ProfileStore;
type TCaptureTransport=class(TInterfacedObject,IAITransport)
 private FDelegate:IAITransport;FPath:string;FAttempt:Integer;
 public constructor Create(const Path:string);
 function Execute(const Request:TAIHttpRequest):TAIHttpResponse;
 procedure Cancel;
end;
constructor TCaptureTransport.Create(const Path:string);
begin inherited Create;FPath:=Path;FDelegate:=TAIHTTPTransport.Create;end;
function TCaptureTransport.Execute(const Request:TAIHttpRequest):TAIHttpResponse;
begin
 Inc(FAttempt);Result:=FDelegate.Execute(Request);
 TFile.WriteAllText(FPath+'.'+IntToStr(FAttempt)+'.response.json',Result.Body,TEncoding.UTF8);
 TFile.WriteAllText(FPath+'.'+IntToStr(FAttempt)+'.status.txt',IntToStr(Result.Status),TEncoding.UTF8);
end;
procedure TCaptureTransport.Cancel;
begin FDelegate.Cancel;end;
var Config,Corpus,Item:TJSONObject;Parser:TDocParser;Profile:TAIProfile;Context:TAIContext;
 Results:TJSONArray;Prompt:TAIPrompt;Proposal:TAIProposal;Request:TAIHttpRequest;
 Target:TCodeElementInfo;Fragments:TArray<TAIProtectedFragment>;Model:TXmlDocModel;
 Count,ProfileCount:Integer;Output,Variant:string;
begin
 CoInitialize(nil);
 try
  if ParamCount<3 then raise Exception.Create('Usage: RunQuality profile-name corpus.json output-directory [built-in|fact-review]');
  Output:=TPath.GetFullPath(ParamStr(3));if TDirectory.Exists(Output) then raise Exception.Create('Use a fresh output directory');TDirectory.CreateDirectory(Output);
  Variant:=ParamStr(4);if Variant='' then Variant:='built-in';
  if (Variant<>'built-in') and (Variant<>'fact-review') then raise Exception.Create('Unknown prompt variant');
  Config:=LoadAIConfiguration;
  try
   ProfileCount:=0;for var Value in Config.GetValue<TJSONArray>('profiles') do if SameText(TJSONObject(Value).GetValue<string>('name'),ParamStr(1)) then begin Profile:=AIProfileFromJson(TJSONObject(Value));Inc(ProfileCount);end;
   if ProfileCount<>1 then raise Exception.Create('Select exactly one existing AI profile');
  finally Config.Free;end;
  Corpus:=TJSONObject.ParseJSONValue(TFile.ReadAllText(ParamStr(2),TEncoding.UTF8)) as TJSONObject;
  Parser:=TDocParser.Create;Results:=TJSONArray.Create;Model:=TXmlDocModel.Create;
  try
   for var Value in Corpus.GetValue<TJSONArray>('cases') do begin
    Item:=Value as TJSONObject;var Id:=Item.GetValue<string>('id');
    Parser.ParseSource(TFile.ReadAllText(Item.GetValue<string>('file'),TEncoding.UTF8),TPath.GetFullPath(Item.GetValue<string>('file')));Count:=0;
    for var Element in Parser.GetAllElements do if (Element.Name=Item.GetValue<string>('method')) and (Element.SourceSection='interface') and
      ((Item.GetValue<string>('parameterType','')='') or ((Length(Element.Params)>0) and SameText(Element.Params[0].TypeName,Item.GetValue<string>('parameterType')))) then begin Target:=Element;Inc(Count);end;
    if Count<>1 then raise Exception.Create('Ambiguous corpus target: '+Id);
    Model.LoadFromXml(Target.ExistingDocXml);Context:=CaptureMethodContext(Parser,Target,Model.Summary,'','');Context.Documentation:=ProtectSummary(Model.Summary,Fragments);
    Prompt:=TAIPrompt.BuiltIn(aoDescribe);
    if Variant='fact-review' then Context.UserInstruction:='Before writing, check every exit, var/out assignment, explicit raise and conditional branch in the supplied implementation. Preserve supported existing facts. State uncertain behav'+
  'ior explicitly. Prefer concise, concrete prose. Do not infer undocumented guarantees.';
    Request:=BuildAIRequest(Profile,Prompt,Context,ReadAIKey(Profile));
    // Never persist the Authorization header or credentials.
    TFile.WriteAllText(TPath.Combine(Output,Id+'.request.json'),Request.Body,TEncoding.UTF8);
    var SentRequest:=TJSONObject.ParseJSONValue(Request.Body) as TJSONObject;
    var SentModel:string;try SentModel:=SentRequest.GetValue<string>('model');finally SentRequest.Free;end;
    var ResultItem:=TJSONObject.Create.AddPair('id',Id).AddPair('model',SentModel).AddPair('configuredModel',Profile.Model).AddPair('promptId',Variant).AddPair('contextFingerprint',Context.Fingerprint).AddPair('requestDigest',THashSHA2.GetHashString(Request.Body));Results.AddElement(ResultItem);
    try
     Proposal:=ExecuteAI(TCaptureTransport.Create(TPath.Combine(Output,Id)),Request);RestoreSummary(Proposal.Summary,Fragments);
     ResultItem.AddPair('summary',RestoreSummary(Proposal.Summary,Fragments));
     if Proposal.HasReturns then ResultItem.AddPair('returns',Proposal.Returns);if Proposal.HasRemarks then ResultItem.AddPair('remarks',Proposal.Remarks);
     var Parameters:=TJSONArray.Create;ResultItem.AddPair('parameters',Parameters);for var Param in Proposal.Parameters do Parameters.AddElement(TJSONObject.Create.AddPair('name',Param.Name).AddPair('description',Param.Description));
     var Uncertainties:=TJSONArray.Create;ResultItem.AddPair('uncertainties',Uncertainties);for var Text in Proposal.Uncertainties do Uncertainties.Add(Text);
     Writeln('PASS response: ',Id);
    except on E:Exception do begin ResultItem.AddPair('summary','').AddPair('error',E.Message);Writeln('FAIL response: ',Id,': ',E.Message);ExitCode:=1;end;end;
    Request.Authorization:='';TFile.WriteAllText(TPath.Combine(Output,'responses.json'),Results.ToJSON,TEncoding.UTF8);
    Flush(System.Output);
   end;
  finally Model.Free;Results.Free;Parser.Free;Corpus.Free;end;
 except on E:Exception do begin Writeln(E.Message);ExitCode:=1;end;end;
 CoUninitialize;
end.
