unit XmlDoc.AI.OpenAI;
interface
uses System.SysUtils,XmlDoc.AI.Contracts,XmlDoc.AI.Prompts;
function AIRequestURL(const Endpoint,RequestPath:string):string;
procedure ValidateAIProfileIdentity(const Profile:TAIProfile;const Existing:TArray<TAIProfile>);
function BuildAIRequest(const Profile:TAIProfile;const Prompt:TAIPrompt;const Context:TAIContext;const Key:string):TAIHttpRequest;
function ParseAIResponse(const Response:TAIHttpResponse):TAIProposal;
function ExecuteAI(const Transport:IAITransport;const Request:TAIHttpRequest):TAIProposal;
implementation
uses System.JSON,System.Net.URLClient;
procedure ValidateAIProfileIdentity(const Profile:TAIProfile;const Existing:TArray<TAIProfile>);
var URL:string;UnchangedConnection:Boolean;
begin
 if Trim(Profile.Name)='' then raise EAIError.Create('Profile name is required');
 URL:=AIRequestURL(Profile.Endpoint,Profile.RequestPath);
 UnchangedConnection:=False;
 for var Other in Existing do if (Other.Id=Profile.Id) and
   (AIRequestURL(Other.Endpoint,Other.RequestPath)=URL) and (Other.Model=Profile.Model) and
   (Other.Authorization=Profile.Authorization) then UnchangedConnection:=True;
 for var Other in Existing do if Other.Id<>Profile.Id then begin
  if SameText(Trim(Other.Name),Trim(Profile.Name)) then raise EAIError.Create('Profile name already exists');
  if not UnchangedConnection and (AIRequestURL(Other.Endpoint,Other.RequestPath)=URL) and (Other.Model=Profile.Model) and
    (Other.Authorization=Profile.Authorization) then raise EAIError.Create('A matching connection profile already exists');
 end;
end;
function AIRequestURL(const Endpoint,RequestPath:string):string;
var Base,Path:string;URI:TURI;
begin
 Base:=Trim(Endpoint).TrimRight(['/']);Path:=Trim(RequestPath).Trim(['/']);URI:=TURI.Create(Base);
 if not SameText(URI.Scheme,'https') and not (SameText(URI.Scheme,'http') and
   (SameText(URI.Host,'localhost') or (URI.Host='127.0.0.1') or (URI.Host='::1'))) then raise EAIError.Create('Use HTTPS or a local HTTP endpoint');
 if (URI.Host='') or (URI.Username<>'') or (URI.Password<>'') or (URI.Query<>'') or (URI.Fragment<>'') or
   Base.Contains(#10) or Base.Contains(#13) then raise EAIError.Create('Invalid API endpoint');
 if (Path='') or Path.Contains(':') or Path.Contains('?') or Path.Contains('#') or Path.Contains('..') or Path.Contains('\') or Path.Contains(#10) or Path.Contains(#13) then raise EAIError.Create('Invalid API request path');
 if Base.EndsWith('/'+Path) then Result:=Base else Result:=Base+'/'+Path;
end;
function BuildAIRequest(const Profile:TAIProfile;const Prompt:TAIPrompt;const Context:TAIContext;const Key:string):TAIHttpRequest;
var Json:TJSONObject;Messages:TJSONArray;SystemText,UserText:string;
begin
 if Trim(Profile.Model)='' then raise EAIError.Create('Model is required');
 if (Profile.TimeoutMs<100) or (Profile.TimeoutMs>300000) or (Profile.MaxResponseBytes<1024) or (Profile.MaxResponseBytes>1048576) or
    (Profile.MaxContextChars<100) or (Profile.MaxContextChars>2000000) then raise EAIError.Create('Invalid AI limits');
 Result:=Default(TAIHttpRequest);Result.URL:=AIRequestURL(Profile.Endpoint,Profile.RequestPath);
 if Profile.Authorization='bearer' then begin
  if (Trim(Key)='') or Key.Contains(#10) or Key.Contains(#13) then raise EAIError.Create('API key is required');Result.Authorization:='Bearer '+Key;
 end else if Profile.Authorization<>'none' then raise EAIError.Create('Unsupported authorization mode');
 if (Context.Signature='') or (Context.Code='') then raise EAIError.Create('Method implementation is required');
 if (Prompt.Operation=aoRephrase) and (Trim(Context.Documentation)='') then raise EAIError.Create('Summary is empty');
 if (Prompt.Operation=aoDescribe) and (not (Prompt.SystemText+Prompt.UserText).Contains('{{implementation}}') or
   not (Prompt.SystemText+Prompt.UserText).Contains('{{signature}}')) then raise EAIError.Create('Template must include signature and implementation');
 if (Prompt.Operation=aoRephrase) and not (Prompt.SystemText+Prompt.UserText).Contains('{{documentation}}') then raise EAIError.Create('Template must include existing documentation');
 SystemText:=ExpandPrompt(Prompt.SystemText,Context,Profile.Language);UserText:=ExpandPrompt(Prompt.UserText,Context,Profile.Language);
 if Length(SystemText)+Length(UserText)>Profile.MaxContextChars then raise EAIError.Create('Method context exceeds the configured limit; no source was sent');
 Json:=TJSONObject.Create;
 try
  Json.AddPair('model',Profile.Model);Messages:=TJSONArray.Create;Json.AddPair('messages',Messages);
  Messages.AddElement(TJSONObject.Create.AddPair('role','system').AddPair('content',SystemText));
  Messages.AddElement(TJSONObject.Create.AddPair('role','user').AddPair('content',UserText));Json.AddPair('stream',TJSONBool.Create(False));
  if Profile.JsonMode then Json.AddPair('response_format',TJSONObject.Create.AddPair('type','json_object'));
  if Profile.OutputLimitParameter<>'' then begin
   if (Profile.OutputLimitParameter<>'max_tokens') and (Profile.OutputLimitParameter<>'max_completion_tokens') then raise EAIError.Create('Unsupported output limit parameter');
   if Profile.MaxOutputTokens<=0 then raise EAIError.Create('Output token limit is required');
   Json.AddPair(Profile.OutputLimitParameter,TJSONNumber.Create(Profile.MaxOutputTokens));
  end;
  Result.Body:=Json.ToJSON;Result.TimeoutMs:=Profile.TimeoutMs;Result.MaxResponseBytes:=Profile.MaxResponseBytes;
 finally Json.Free;end;
end;
function CheckedJSON(const Text:string):TJSONValue;
var Depth:Integer;Quoted,Escaped,Started,Completed:Boolean;
begin
 if Length(Text)>1048576 then raise EAIError.Create('AI response exceeds the configured limit');
 Depth:=0;Quoted:=False;Escaped:=False;Started:=False;Completed:=False;
 for var C in Text do begin
  if Completed then begin if not CharInSet(C,[#9,#10,#13,' ']) then raise EAIError.Create('Invalid API JSON response');Continue;end;
  if not Started then begin
   if CharInSet(C,[#9,#10,#13,' ']) then Continue;
   if C<>'{' then raise EAIError.Create('Invalid API JSON response');Started:=True;
  end;
  if Quoted then begin if Escaped then Escaped:=False else if C='\' then Escaped:=True else if C='"' then Quoted:=False;end
  else if C='"' then Quoted:=True
  else if CharInSet(C,['{','[']) then begin Inc(Depth);if Depth>64 then raise EAIError.Create('Invalid API JSON response');end
  else if CharInSet(C,['}',']']) then begin Dec(Depth);if Depth=0 then Completed:=True;end;
 end;
 if not Completed or Quoted or (Depth<>0) then raise EAIError.Create('Invalid API JSON response');
 Result:=TJSONObject.ParseJSONValue(Text);
end;
function ParseAIResponse(const Response:TAIHttpResponse):TAIProposal;
var Envelope,Value:TJSONValue;Choice,Message,Content:TJSONObject;Choices,Uncertainties:TJSONArray;
begin
 Result:=Default(TAIProposal);
 if (Response.Status<200) or (Response.Status>=300) then raise EAIError.CreateFmt('AI HTTP error %d',[Response.Status]);
 Envelope:=CheckedJSON(Response.Body);Value:=nil;
 try
 try
  if not (Envelope is TJSONObject) then raise EAIError.Create('Invalid API JSON response');
  Choices:=(Envelope as TJSONObject).GetValue<TJSONArray>('choices');
  if (Choices.Count<>1) or not (Choices.Items[0] is TJSONObject) then raise EAIError.Create('Expected one AI choice');
  Choice:=Choices.Items[0] as TJSONObject;
  if Choice.GetValue<string>('finish_reason','')<>'stop' then raise EAIError.Create('AI response is incomplete or refused');
  Message:=Choice.GetValue<TJSONObject>('message');
  if Assigned(Message.GetValue('tool_calls')) or ((Message.GetValue('refusal') is TJSONString) and (Message.GetValue<string>('refusal')<>'')) then raise EAIError.Create('AI response is incomplete or refused');
  if not (Message.GetValue('content') is TJSONString) then raise EAIError.Create('AI message content is missing');
  Value:=CheckedJSON(Message.GetValue<string>('content'));
  if not (Value is TJSONObject) then raise EAIError.Create('Invalid proposal JSON');Content:=Value as TJSONObject;
  if (Content.Count<>2) or not (Content.GetValue('summary') is TJSONString) or not (Content.GetValue('uncertainties') is TJSONArray) then raise EAIError.Create('Invalid proposal contract');
  Result.Summary:=Content.GetValue<string>('summary');if Trim(Result.Summary)='' then raise EAIError.Create('AI summary is empty');
  Uncertainties:=Content.GetValue<TJSONArray>('uncertainties');
  for var Item in Uncertainties do begin if not (Item is TJSONString) then raise EAIError.Create('Invalid uncertainty');Result.Uncertainties:=Result.Uncertainties+[Item.Value];end;
 except
  on E:EAIError do raise;
  on E:Exception do raise EAIError.Create('Invalid API response structure');
 end;
 finally Value.Free;Envelope.Free;end;
end;
function ExecuteAI(const Transport:IAITransport;const Request:TAIHttpRequest):TAIProposal;
var Reply:TAIHttpResponse;
begin
 Reply:=Transport.Execute(Request);
 if TEncoding.UTF8.GetByteCount(Reply.Body)>Request.MaxResponseBytes then raise EAIError.Create('AI response exceeds the configured limit');
 Result:=ParseAIResponse(Reply);
end;
end.
