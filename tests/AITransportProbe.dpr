program AITransportProbe;
{$APPTYPE CONSOLE}
uses System.SysUtils,System.Classes,Winapi.Windows,XmlDoc.AI.Contracts,XmlDoc.AI.Prompts,XmlDoc.AI.OpenAI,XmlDoc.AI.Transport;
var Profile:TAIProfile;Context:TAIContext;Request:TAIHttpRequest;Transport:IAITransport;Proposal:TAIProposal;Worker:TThread;Error:string;Started:UInt64;
begin
 try
  Profile:=TAIProfile.Defaults;Profile.Endpoint:='http://127.0.0.1:'+ParamStr(1)+'/v1';Profile.Model:='test';Context:=Default(TAIContext);Context.Signature:='Пример';Context.Code:='begin end;';
  Request:=BuildAIRequest(Profile,TAIPrompt.BuiltIn(aoDescribe),Context,'test-key');Transport:=TAIHTTPTransport.Create;Proposal:=ExecuteAI(Transport,Request);if Proposal.Summary<>'Пример Unicode' then raise Exception.Create('UTF-8 response failed');Writeln('PASS real HTTP UTF-8 and Bearer');
  for var Status in [401,404,429,500,503] do begin Request.URL:=Profile.Endpoint+'/'+IntToStr(Status);Transport:=TAIHTTPTransport.Create;Error:='';try ExecuteAI(Transport,Request);except on E:EAIError do Error:=E.Message;end;if not Error.Contains(IntToStr(Status)) then raise Exception.Create('HTTP error lost');end;Writeln('PASS real HTTP error status handling');
  Request.URL:=Profile.Endpoint+'/large';Transport:=TAIHTTPTransport.Create;Error:='';try ExecuteAI(Transport,Request);except on E:EAIError do Error:=E.Message;end;if not Error.Contains('exceeds') then raise Exception.Create('Response limit not enforced');Writeln('PASS bounded response buffering');
  for var Mode in ['cancel','timeout'] do begin
   Request.URL:=Profile.Endpoint+'/slow';Request.TimeoutMs:=5000;if Mode='timeout' then Request.TimeoutMs:=250;Transport:=TAIHTTPTransport.Create;Error:='';
   Worker:=TThread.CreateAnonymousThread(procedure begin try ExecuteAI(Transport,Request);except on E:Exception do Error:=E.Message;end;end);Worker.FreeOnTerminate:=False;Worker.Start;Sleep(100);Started:=GetTickCount64;if Mode='cancel' then Transport.Cancel;Worker.WaitFor;Worker.Free;
   if (GetTickCount64-Started>2000) or (Error='') then raise Exception.Create('Cancellation/timeout failed: '+Mode);Writeln('PASS real pending HTTP '+Mode+' joined in '+IntToStr(GetTickCount64-Started)+' ms');
  end;
 except on E:Exception do begin Writeln(E.ClassName+': '+E.Message);ExitCode:=1;end;end;
end.
