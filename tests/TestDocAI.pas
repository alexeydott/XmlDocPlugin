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
 [Test] procedure ProfileIdentity;
 end;
implementation
uses System.IOUtils,System.SysUtils,System.JSON,XmlDoc.Parser,XmlDoc.Consts,XmlDoc.AI.Contracts,XmlDoc.AI.Context,XmlDoc.AI.Prompts,XmlDoc.AI.OpenAI,XmlDoc.AI.Transport;
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
  for E in P.GetAllElements do if E.Name='Missing' then Assert.IsFalse(P.MethodSource(E,Code,Reason));
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
 R.Status:=200;for var Body in ['','{','{}','{} trailing','{}{}','{"choices":[]}','{"choices":[{"finish_reason":"length","message":{"content":"{}"}}]}'] do begin R.Body:=Body;Assert.WillRaise(procedure begin ParseAIResponse(R);end,EAIError);end;
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
initialization TDUnitX.RegisterTestFixture(TDocAITests);
end.
