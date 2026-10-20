unit TestDocAI;
interface
uses DUnitX.TestFramework;
type [TestFixture] TDocAITests=class
 public
 [Test] procedure ExactMethodContext;
 [Test] procedure PromptsAndProtection;
 [Test] procedure ResponseContracts;
 [Test] procedure GenericConditionalIncludeContext;
 [Test] procedure PromptAndReplyFuzz;
 [Test] procedure RealQualityCorpusContexts;
 [Test] procedure MethodContextFuzz;
 [Test] procedure ParameterProposals;
 [Test] procedure ProfileIdentity;
 [Test] procedure RetryRequests;
 [Test] procedure DisableThinkingRequests;
 [Test] procedure ToonMethodRequests;
 [Test] procedure HTMLProseCleanup;
 [Test] procedure ReviewRegressionContracts;
 end;
implementation
uses System.IOUtils,System.SysUtils,System.JSON,XmlDoc.Parser,XmlDoc.Consts,XmlDoc.AI.Contracts,XmlDoc.AI.Context,XmlDoc.AI.Prompts,XmlDoc.AI.OpenAI,XmlDoc.AI.Transport,XmlDoc.AI.Text,XmlDoc.AI.Toon,XmlDoc.Model,XmlDoc.SourceAccess;
type TRetryAITransport=class(TInterfacedObject,IAITransport)
 Calls,Failures,Status:Integer;Failure:string;LastBody:string;
 function Execute(const Request:TAIHttpRequest):TAIHttpResponse;
 procedure Cancel;
end;
function TRetryAITransport.Execute(const Request:TAIHttpRequest):TAIHttpResponse;
begin
 Inc(Calls);if LastBody<>'' then Assert.AreEqual(LastBody,Request.Body);LastBody:=Request.Body;
 if Calls<=Failures then begin if Failure<>'' then raise EAIError.Create(Failure);Result.Status:=Status;Result.Body:='unavailable';end
 else begin Result.Status:=200;Result.Body:='{"choices":[{"finish_reason":"stop","message":{"content":"{\"summary\":\"Recovered\",\"uncertainties\":[]}"}}]}';end;
end;
procedure TRetryAITransport.Cancel;
begin end;
procedure TDocAITests.RetryRequests;
var Raw:TRetryAITransport;Transport:IAITransport;Request:TAIHttpRequest;Waits:TArray<Integer>;Wait:TProc<Integer>;P:TAIProfile;C:TAIContext;
 procedure Reset(Status,Failures:Integer;const Error:string='');
 begin Raw:=TRetryAITransport.Create;Transport:=Raw;Raw.Status:=Status;Raw.Failures:=Failures;Raw.Failure:=Error;Waits:=nil;end;
begin
 Wait:=procedure(Delay:Integer) begin if Delay>0 then Waits:=Waits+[Delay];end;
 P:=TAIProfile.Defaults;Assert.AreEqual(3,P.RetryCount);P.Model:='fixture';C:=Default(TAIContext);C.Signature:='procedure Run';C.Code:='begin end;';
 Request:=BuildAIRequest(P,TAIPrompt.BuiltIn(aoDescribe),C,'test-key');Assert.AreEqual(3,Request.RetryCount);
 Reset(503,2);Assert.AreEqual('Recovered',ExecuteAI(Transport,Request,Wait).Summary);Assert.AreEqual(3,Raw.Calls);Assert.AreEqual<NativeInt>(2,Length(Waits));Assert.AreEqual(1000,Waits[0]);Assert.AreEqual(2000,Waits[1]);
 Reset(503,10);Assert.WillRaise(procedure begin ExecuteAI(Transport,Request,Wait);end,EAIError);Assert.AreEqual(4,Raw.Calls);Assert.AreEqual(4000,Waits[2]);
 Request.RetryCount:=0;Reset(503,10);Assert.WillRaise(procedure begin ExecuteAI(Transport,Request,Wait);end,EAIError);Assert.AreEqual(1,Raw.Calls);Assert.AreEqual<NativeInt>(0,Length(Waits));Request.RetryCount:=3;
 for var Code in [401,404] do begin Reset(Code,10);Assert.WillRaise(procedure begin ExecuteAI(Transport,Request,Wait);end,EAIError);Assert.AreEqual(1,Raw.Calls);end;
 for var Code in [408,429,500,502,503,504] do begin Reset(Code,1);Assert.AreEqual('Recovered',ExecuteAI(Transport,Request,Wait).Summary);Assert.AreEqual(2,Raw.Calls);end;
 for var Error in ['AI request timed out','AI transport failed'] do begin Reset(0,1,Error);Assert.AreEqual('Recovered',ExecuteAI(Transport,Request,Wait).Summary);end;
 for var Error in ['AI request cancelled','AI response exceeds the configured limit'] do begin Reset(0,10,Error);Assert.WillRaise(procedure begin ExecuteAI(Transport,Request,Wait);end,EAIError);Assert.AreEqual(1,Raw.Calls);end;
 Reset(200,10);Assert.WillRaise(procedure begin ExecuteAI(Transport,Request,Wait);end,EAIError);Assert.AreEqual(1,Raw.Calls);
 Reset(503,10);try ExecuteAI(Transport,Request,procedure(Delay:Integer) begin if Delay>0 then raise EAIError.Create('AI request cancelled');end);Assert.Fail('Cancellation must escape retry wait');except on E:EAIError do Assert.AreEqual('AI request cancelled',E.Message);end;Assert.AreEqual(1,Raw.Calls);
end;
procedure TDocAITests.DisableThinkingRequests;
var P:TAIProfile;C:TAIContext;Request:TAIHttpRequest;Json:TJSONObject;
 procedure Check(const Expected:string;Disabled:Boolean);
 begin
  P.DisableThinking:=Disabled;Request:=BuildAIRequest(P,TAIPrompt.BuiltIn(aoDescribe),C,'test-key');
  Json:=TJSONObject.ParseJSONValue(Request.Body) as TJSONObject;
  try
   Assert.AreEqual(Expected,Json.GetValue<string>('model'));
   Assert.AreEqual(Disabled,TJSONObject(Json.GetValue<TJSONArray>('messages')[0]).GetValue<string>('content').Contains('/no_think'));
   Assert.IsFalse(Assigned(Json.GetValue('enable_thinking')),'Unsupported generic API fields must not be sent');
  finally Json.Free;end;
 end;
begin
 P:=TAIProfile.Defaults;Assert.IsFalse(P.DisableThinking);P.Endpoint:='https://api.neuraldeep.ru/v1';
 C:=Default(TAIContext);C.Signature:='procedure Run';C.Code:='begin end;';
 for var Model in ['qwen3.8-27b','qwen3.6-35b-a3b','qwen3.6-fp8','gemma-4-31b','qwen3.6-unlim','qwen3.6-unlim-xl'] do begin
  P.Model:=Model;Check(Model,False);Check(Model+'-noreason',True);Assert.AreEqual(Model,P.Model);
 end;
 P.Model:='qwen3.8-27b-noreason';Check(P.Model,True);
 P.Model:='unknown-model';Check(P.Model,True);
 P.Model:='qwen3.8-27b';P.Endpoint:='https://example.invalid/v1';Check(P.Model,True);
 P.Endpoint:='https://api.neuraldeep.ru.example.invalid/v1';Check(P.Model,True);
end;
procedure TDocAITests.ToonMethodRequests;
var C:TAIContext;P:TAIProfile;Prompt:TAIPrompt;Request:TAIHttpRequest;Json:TJSONObject;Text:string;
begin
 C:=Default(TAIContext);C.Signature:='procedure Run(Value: string)';C.Code:='begin'+#13#10+'  WriteLn(''Пример, 中文, 한국어, 日本語'');'+#13#10+'end;';
 C.Parameters:='[{"name":"Value","type":"string"}]';C.TypeContext:='{"owner":"TExample","defines":["DEBUG","UNICODE"]}';
 P:=TAIProfile.Defaults;P.Model:='test';Prompt:=TAIPrompt.BuiltIn(aoDescribe);Request:=BuildAIRequest(P,Prompt,C,'secret');
 Json:=TJSONObject.ParseJSONValue(Request.Body) as TJSONObject;
 try
  Text:=TJSONObject(Json.GetValue<TJSONArray>('messages')[1]).GetValue<string>('content');
  Assert.IsTrue(Text.StartsWith('instructions: '));Assert.IsTrue(Text.Contains(#10+'context:'));
  Assert.IsTrue(Text.Contains('parameters[1]{name,type}:'+ #10+'    Value,string'));
  Assert.IsTrue(Text.Contains('implementation: "begin\r\n'));Assert.IsTrue(Text.Contains('Пример, 中文, 한국어, 日本語'));
  Assert.IsTrue(Text.Contains('defines[2]: DEBUG,UNICODE'));Assert.IsFalse(Text.Contains('secret'));
 finally Json.Free;end;
 Assert.IsTrue(ToonPrompt('{{  implementation  }}',C,'en').Contains('implementation:'));
 var Invalid:=TJSONString.Create(Char($D800));try Assert.WillRaise(procedure begin AIToon(Invalid);end,EArgumentException);finally Invalid.Free;end;
end;
procedure TDocAITests.HTMLProseCleanup;
var Text,Plain:string;F:TArray<TAIProtectedFragment>;
begin
 Text:='<html><head><style>.x {color:red}</style></head><body><p class="x">First <strong>formatted</strong> &amp; safe.</p><div>Second<br>line.</div><script>alert(1)</script><!-- hidden --></body></html>';
 var Model:=TXmlDocModel.Create;try var Prose:=AITextXml(Text);Model.LoadFromXml('<summary>'+Prose+'</summary>');Assert.AreEqual(Prose,Model.Summary);Assert.IsTrue(Model.ToXml.Contains(Prose));finally Model.Free;end;
 Plain:=CleanAIText(Text);Assert.AreEqual('First formatted & safe.'+#10#10+'Second'+#10+'line.',Plain);
 Assert.AreEqual('<para>First formatted &amp; safe.</para><para>Second<br/>line.</para>',AITextXml(Text));
 Assert.AreEqual('List<T> and x < y.',CleanAIText('List<T> and x < y.'));
 Assert.AreEqual('TList<A> and TList<B>',CleanAIText('TList<A> and TList<B>'));
 Assert.AreEqual('safe',CleanAIText('safe<script src="x">unterminated'));
 Assert.AreEqual('Safe',CleanAIText('&lt;p class=&quot;x&quot;&gt;Safe&lt;/p&gt;'));
 var Protected:=ProtectSummary('Use <see cref="TExample"/>.',F);
 Assert.AreEqual(RestoreSummary(Protected,F),RestoreSummary('<p>'+Protected+'</p><script>bad</script>',F));
 // Fuzz HTML boundaries, attributes, case, entities and truncation without a browser/COM parser.
 for var I:=0 to 255 do begin
  Text:='<DIV title="'+StringOfChar('>',I mod 17)+'">Пример '+I.ToString+'</DIV><ScRiPt>evil'+I.ToString+'</sCrIpT><style>bad</style>';

 Plain:=CleanAIText(Text);Assert.AreEqual('Пример '+I.ToString,Plain);Assert.IsFalse(AITextXml(Text).Contains('evil'));
  CleanAIText(Copy(Text,1,I mod Length(Text)));
 end;
end;
procedure TDocAITests.ExactMethodContext;
var P:TDocParser;E:TCodeElementInfo;Code,Reason,Source,Expected:string;C:TAIContext;
begin
 P:=TDocParser.Create;
 try
  Expected:='procedure TTest.Run(Value:Integer); var S:string; procedure Nested; begin S:=''end; Пример''; end; begin Nested; end;';
  Source:='unit CaseA; interface type TTest=class procedure Run(Value:Integer); overload; procedure Run(Value:string); overload; procedure Missing; virtual; abstract; end; implementation '+Expected+' procedure TTest.Run(Value:string); begin end; end.';
  P.ParseSource(Source,'CaseA.pas');
  for E in P.GetAllElements do if (E.Name='Run') and (E.SourceSection='interface') and (E.Params[0].TypeName='Integer') then begin
   Assert.IsTrue(P.MethodSource(E,Code,Reason),Reason);Assert.AreEqual(Expected,Code);C:=CaptureMethodContext(P,E,'Original','','');Assert.AreEqual(Expected,C.Code);Assert.IsTrue(C.Fingerprint<>'');
  end;
  for E in P.GetAllElements do if E.Name='Missing' then begin Assert.IsFalse(P.MethodSource(E,Code,Reason));C:=CaptureMethodContext(P,E,'Existing summary','','',False);Assert.AreEqual('',C.Code);Assert.AreEqual('Existing summary',C.Documentation);end;
 finally P.Free;end;
end;
procedure TDocAITests.PromptsAndProtection;
var C:TAIContext;F:TArray<TAIProtectedFragment>;Protected,Restored:string;Profile:TAIProfile;Request:TAIHttpRequest;Prompt:TAIPrompt;
begin
 C:=Default(TAIContext);C.Signature:='Run';C.Code:='begin {{unknown}} end;';
 Assert.AreEqual(C.Code,ExpandPrompt('{{implementation}}',C,'ru'));
 Assert.WillRaise(procedure begin ExpandPrompt('{{unknown}}',C,'ru');end,EAIError);
 Assert.WillRaise(procedure begin ExpandPrompt('{{language}}',C,'');end,EAIError);
 Protected:=ProtectSummary('Read &amp; use <see cref=''X''/> or <opaque data="a&gt;b"><b>Value</b></opaque>.',F);
 Assert.AreEqual<NativeInt>(2,Length(F));Restored:=RestoreSummary(Protected,F);Assert.AreEqual('Read &amp; use <see cref=''X''/> or <opaque data="a&gt;b"><b>Value</b></opaque>.',Restored);
 Assert.WillRaise(procedure begin RestoreSummary('lost',F);end,EAIError);
 Assert.WillRaise(procedure begin RestoreSummary(Protected+F[0].Token,F);end,EAIError);
 Profile:=TAIProfile.Defaults;Profile.Model:='test';Prompt:=TAIPrompt.BuiltIn(aoDescribe);Request:=BuildAIRequest(Profile,Prompt,C,'secret');
 Assert.AreEqual('https://api.openai.com/v1/chat/completions',Request.URL);Assert.AreEqual('Bearer secret',Request.Authorization);Assert.IsFalse(Request.Body.Contains('secret'));
 Assert.WillRaise(procedure begin AIRequestURL(Profile.Endpoint,'https://other.example/');end,EAIError);
end;
procedure TDocAITests.ResponseContracts;
var R:TAIHttpResponse;P:TAIProposal;
begin
 R.Status:=200;R.Body:='{"choices":[{"finish_reason":"stop","message":{"content":"{\"summary\":\"Пример\",\"uncertainties\":[]}"}}]}';P:=ParseAIResponse(R);Assert.AreEqual('Пример',P.Summary);
 for var Status in [401,404,429,500,503] do begin R.Status:=Status;Assert.WillRaise(procedure begin ParseAIResponse(R);end,EAIError);end;
 R.Status:=404;try ParseAIResponse(R);Assert.Fail('404 must fail');except on E:EAIError do Assert.IsTrue(E.Message.Contains('exact model ID'));end;
 R.Status:=200;for var Body in ['','{','{}','{} trailing','{}{}','{"choices":[]}','{"choices":[{"finish_reason":"length","message":{"content":"{}"}}]}'] do begin R.Body:=Body;Assert.WillRaise(procedure begin ParseAIResponse(R);end,EAIError);end;
 for var Body in ['{"content":"","reasoning_content":"Internal reasoning only"}',
  '{"content":" \n\t","reasoning_content":"Internal reasoning only"}',
  '{"content":null,"reasoning_content":"Internal reasoning only"}'] do begin
  R.Body:='{"choices":[{"finish_reason":"stop","message":'+Body+'}]}';
  try ParseAIResponse(R);Assert.Fail('Reasoning without final content must fail');
  except on E:EAIError do Assert.AreEqual('AI message content is missing',E.Message);end;
 end;
end;
procedure TDocAITests.ParameterProposals;
var R:TAIHttpResponse;Envelope,Content:TJSONObject;P:TAIProposal;
begin
 Assert.IsTrue(TAIPrompt.BuiltIn(aoDescribe).SystemText.Contains('every method parameter'));
 for var Payload in ['{"summary":"Text","uncertainties":[],"parameters":[{"name":"Value","description":"Input"}]}','{"summary":"Text","uncertainties":[],"parameters":[{"name":"Value","description":"Input"},{"name":"value","description":"Duplicate"}]}','{"summary":"Text","uncertainties":[],"parameters":[{"name":"","description":"Input"}]}'] do begin
  Content:=TJSONObject.Create.AddPair('content',Payload);Envelope:=TJSONObject.Create.AddPair('choices',TJSONArray.Create(TJSONObject.Create.AddPair('finish_reason','stop').AddPair('message',Content)));
  try R.Status:=200;R.Body:=Envelope.ToJSON;if Payload.Contains('Duplicate') or Payload.Contains('"name":""') then Assert.WillRaise(procedure begin ParseAIResponse(R);end,EAIError) else begin P:=ParseAIResponse(R);Assert.AreEqual<NativeInt>(1,Length(P.Parameters));Assert.AreEqual('Value',P.Parameters[0].Name);end;finally Envelope.Free;end;
 end;
end;
procedure TDocAITests.GenericConditionalIncludeContext;
var P:TDocParser;E:TCodeElementInfo;Directory,FileName,IncludeFile,Source,Expected,Code,Reason,Fingerprint:string;C:TAIContext;Snapshot:TSourceSnapshot;
begin
 Directory:=TPath.Combine(TPath.GetTempPath,TGUID.NewGuid.ToString);TDirectory.CreateDirectory(Directory);FileName:=TPath.Combine(Directory,'CaseGeneric.pas');IncludeFile:=TPath.Combine(Directory,'body.inc');TFile.WriteAllText(IncludeFile,'Value := 1;',TEncoding.UTF8);
 P:=TDocParser.Create;
 try
  P.Defines:=['ACTIVE'];P.SearchPaths:=[Directory];
  Expected:='class procedure TTest<T>.Run<U>(Value:T); var S:string; begin {$I body.inc} S:=''Юникод end''; end;';
  Source:='unit CaseGeneric; interface type TTest<T>=class class procedure Run<U>(Value:T); end; implementation {$IFDEF ACTIVE}'+Expected+'{$ELSE}class procedure TTest<T>.Run<U>(Value:T); begin end;{$ENDIF} end.';
  P.ParseSource(Source,FileName);Fingerprint:='';
  for E in P.GetAllElements do if (E.Name='Run') and (E.SourceSection='interface') then begin
   Assert.IsTrue(P.MethodSource(E,Code,Reason),Reason);Assert.AreEqual(Expected,Code);C:=CaptureMethodContext(P,E,'','','');Assert.IsTrue(C.TypeContext.Contains('Value := 1;'));Fingerprint:=C.Fingerprint;
  end;
  Assert.IsTrue(Fingerprint<>'');Snapshot.FileName:=IncludeFile;Snapshot.Source:='Value := 2;';P.SourceSnapshots:=[Snapshot];P.ParseSource(Source,FileName);
  for E in P.GetAllElements do if (E.Name='Run') and (E.SourceSection='interface') then begin C:=CaptureMethodContext(P,E,'','','');Assert.IsTrue(Fingerprint<>C.Fingerprint,'Unsaved include snapshot must change the context identity');end;
 finally P.Free;TDirectory.Delete(Directory,True);end;
end;
procedure TDocAITests.PromptAndReplyFuzz;
var C:TAIContext;Seed:Cardinal;Template,Body:string;Reply:TAIHttpResponse;
begin
 C:=Default(TAIContext);C.Signature:='Run';Seed:=12345;
 for var I:=1 to 500 do begin
  Seed:=Seed*1664525+1013904223;C.Code:='begin {{unknown_'+IntToStr(Seed)+'}} Пример end;';Template:='{{implementation}}';Assert.AreEqual(C.Code,ExpandPrompt(Template,C,'ru'));
  Template:='{{unknown_'+IntToStr(Seed)+'}}';Assert.WillRaise(procedure begin ExpandPrompt(Template,C,'ru');end,EAIError);
 end;
 Reply.Status:=200;Body:='{"choices":[{"finish_reason":"stop","message":{"content":"{\"summary\":\"Text\",\"uncertainties\":[]}"}}]}';
 for var I:=0 to Length(Body)-1 do begin Reply.Body:=Copy(Body,1,I);Assert.WillRaise(procedure begin ParseAIResponse(Reply);end,EAIError);end;
 Reply.Body:=StringOfChar('[',1000)+StringOfChar(']',1000);Assert.WillRaise(procedure begin ParseAIResponse(Reply);end,EAIError);
end;
procedure TDocAITests.RealQualityCorpusContexts;
var Corpus:TJSONObject;Parser:TDocParser;Context:TAIContext;Count:Integer;
begin
 Corpus:=TJSONObject.ParseJSONValue(TFile.ReadAllText('tests\ai-quality\corpus.json',TEncoding.UTF8)) as TJSONObject;Parser:=TDocParser.Create;
 try
  for var Value in Corpus.GetValue<TJSONArray>('cases') do begin
   var Item:=Value as TJSONObject;var FileName:=TPath.GetFullPath(Item.GetValue<string>('file'));Parser.ParseSource(TFile.ReadAllText(FileName,TEncoding.UTF8),FileName);Count:=0;
   for var Element in Parser.GetAllElements do if (Element.Name=Item.GetValue<string>('method')) and (Element.SourceSection='interface') then begin
    Context:=CaptureMethodContext(Parser,Element,'','','');Assert.IsTrue(Context.Code.Contains(Item.GetValue<string>('method')));Assert.IsTrue(Context.Code.EndsWith(';'));Inc(Count);
   end;
   Assert.AreEqual(1,Count,Item.GetValue<string>('id'));
  end;
 finally Parser.Free;Corpus.Free;end;
end;
procedure TDocAITests.MethodContextFuzz;
var Parser:TDocParser;Expected,Source,Code,Reason:string;Count:Integer;Seed:Cardinal;
begin
 Parser:=TDocParser.Create;Seed:=7291;
 try
  for var I:=1 to 100 do begin
   Seed:=Seed*1664525+1013904223;
   Expected:='procedure TFuzz.Run(Value:Integer); var Local:string; procedure Nested; begin Local:=''end; Юникод '+UIntToStr(Seed)+'''; end; begin {end;} Nested; end;';
   Source:='unit ContextFuzz; interface type TFuzz=class procedure Run(Value:Integer); overload; procedure Run(Value:string); overload; end; implementation '+Expected+' procedure TFuzz.Run(Value:string); begin {different overload} end; end.';
   Parser.ParseSource(Source,'ContextFuzz.pas');Count:=0;
   for var Element in Parser.GetAllElements do if (Element.Name='Run') and (Element.SourceSection='interface') and (Element.Params[0].TypeName='Integer') then begin
    Inc(Count);Assert.IsTrue(Parser.MethodSource(Element,Code,Reason),Reason);Assert.AreEqual(Expected,Code);
   end;
   Assert.AreEqual(1,Count);
  end;
 finally Parser.Free;end;
end;
procedure TDocAITests.ProfileIdentity;
var Profile,Other:TAIProfile;
begin
 Profile:=TAIProfile.Defaults;Profile.Id:='first';Profile.Name:='Work';Profile.Model:='model';Other:=Profile;
 ValidateAIProfileIdentity(Profile,[Other]);
 Other.Id:='second';Other.Name:=' work ';Other.Model:='another';
 Assert.WillRaise(procedure begin ValidateAIProfileIdentity(Profile,[Other]);end,EAIError);
 Other.Name:='Other';Other.Model:='model';Other.Endpoint:=Other.Endpoint+'/';
 Assert.WillRaise(procedure begin ValidateAIProfileIdentity(Profile,[Other]);end,EAIError);
 ValidateAIProfileIdentity(Profile,[Profile,Other]);
 Other.Model:='another';ValidateAIProfileIdentity(Profile,[Other]);
 Profile.Name:='  ';Assert.WillRaise(procedure begin ValidateAIProfileIdentity(Profile,[]);end,EAIError);
end;
procedure TDocAITests.ReviewRegressionContracts;
var Fragments:TArray<TAIProtectedFragment>;Protected,Restored:string;C:TAIContext;P:TAIProfile;Prompt:TAIPrompt;
begin
 Protected:=ProtectSummary('<para>Finds a <b>route</b> using <see cref="TMap"/>.</para><para>Returns <c>$&amp;</c> if missing.</para>',Fragments);
 Assert.IsTrue(Protected.Contains('Finds a'));Assert.IsTrue(Protected.Contains('Returns'));
 Restored:=RestoreSummary(Protected.Replace('Finds a','Locates a'),Fragments);
 Assert.IsTrue(Restored.Contains('Locates a'));Assert.IsTrue(Restored.Contains('<b>route</b>'));Assert.IsTrue(Restored.Contains('<see cref="TMap"/>'));Assert.IsTrue(Restored.Contains('<c>$&amp;</c>'));
 Protected:=ProtectSummary(AITextXml('First description.'+#10#10+'Second paragraph.'),Fragments);
 Assert.IsTrue(Protected.Contains('First description.'));Assert.IsTrue(RestoreSummary(Protected.Replace('First','Rephrased'),Fragments).Contains('Rephrased description.'));
 for var Tag in ['para','b','i','strong','em','u'] do for var I:=0 to 31 do begin
  var Original:='<'+Tag+'>Editable '+I.ToString+' <see cref="TMap"/> <c>$&amp;</c><opaque>Hidden</opaque></'+Tag+'>';
  Protected:=ProtectSummary(Original,Fragments);Assert.IsTrue(Protected.Contains('Editable '+I.ToString));Assert.IsFalse(Protected.Contains('Hidden'));
  Restored:=RestoreSummary(Protected.Replace('Editable','Rephrased'),Fragments);
  Assert.IsTrue(Restored.Contains('Rephrased '+I.ToString));Assert.IsTrue(Restored.Contains('<see cref="TMap"/>'));Assert.IsTrue(Restored.Contains('<c>$&amp;</c>'));Assert.IsTrue(Restored.Contains('<opaque>Hidden</opaque>'));
 end;
 C:=Default(TAIContext);C.Signature:='procedure Run';C.Documentation:='Existing description.';P:=TAIProfile.Defaults;P.Authorization:='none';P.Model:='fixture';
 Prompt:=TAIPrompt.BuiltIn(aoRephrase);BuildAIRequest(P,Prompt,C,'');
 Prompt:=TAIPrompt.BuiltIn(aoDescribe);C.Code:='begin end;';Prompt.UserText:='{{ signature }} {{ implementation }}';BuildAIRequest(P,Prompt,C,'');
 C.Code:='';Assert.WillRaise(procedure begin BuildAIRequest(P,Prompt,C,'');end,EAIError);
 Assert.AreEqual('22.0',RADVersionForCompiler(35));Assert.AreEqual('23.0',RADVersionForCompiler(36));Assert.AreEqual('37.0',RADVersionForCompiler(37));
 Assert.IsTrue(TFile.Exists(TPath.Combine(CurrentRADRoot,'source\rtl\sys\System.pas')));
 Assert.IsTrue(IsCompilerSource(TPath.Combine(CurrentRADRoot,'source\rtl\sys\System.pas')));
end;
initialization TDUnitX.RegisterTestFixture(TDocAITests);
end.
