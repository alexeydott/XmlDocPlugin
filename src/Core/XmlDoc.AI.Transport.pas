unit XmlDoc.AI.Transport;
interface
uses System.SysUtils,System.Classes,System.Net.HttpClient,XmlDoc.AI.Contracts;
type
 TAIHTTPTransport=class(TInterfacedObject,IAITransport)
 private
  FCancelled,FMaxResponse,FTooLarge:Integer;
  procedure ReceiveData(const Sender:TObject;ContentLength,ReadCount:Int64;var Abort:Boolean);
 public
  function Execute(const Request:TAIHttpRequest):TAIHttpResponse;
  procedure Cancel;
 end;
implementation
uses System.Net.URLClient,System.Types,System.SyncObjs,Winapi.Windows;
type TBoundedAIStream=class(TMemoryStream)
 Limit:Integer;Exceeded:Boolean;
 function Write(const Buffer;Count:Longint):Longint;override;
end;
function TBoundedAIStream.Write(const Buffer;Count:Longint):Longint;
begin
 if (Count<0) or (Position+Count>Limit) then begin Exceeded:=True;raise EAIError.Create('AI response exceeds the configured limit');end;
 Result:=inherited Write(Buffer,Count);
end;
procedure TAIHTTPTransport.Cancel;
begin TInterlocked.Exchange(FCancelled,1);end;
procedure TAIHTTPTransport.ReceiveData(const Sender:TObject;ContentLength,ReadCount:Int64;var Abort:Boolean);
begin if (ReadCount>FMaxResponse) or (ContentLength>FMaxResponse) then TInterlocked.Exchange(FTooLarge,1);Abort:=(TInterlocked.CompareExchange(FCancelled,0,0)<>0) or (TInterlocked.CompareExchange(FTooLarge,0,0)<>0);end;
function TAIHTTPTransport.Execute(const Request:TAIHttpRequest):TAIHttpResponse;
var Client:THTTPClient;Input:TStringStream;Output:TBoundedAIStream;Async:IAsyncResult;Reply:IHTTPResponse;
 Bytes:TBytes;Headers:TNetHeaders;Started:UInt64;Cancelled,TimedOut:Boolean;
begin
 Result:=Default(TAIHttpResponse);
 if TInterlocked.CompareExchange(FCancelled,0,0)<>0 then raise EAIError.Create('AI request cancelled');
 FMaxResponse:=Request.MaxResponseBytes;Client:=THTTPClient.Create;Input:=TStringStream.Create(Request.Body,TEncoding.UTF8);Output:=TBoundedAIStream.Create;Output.Limit:=Request.MaxResponseBytes;
 try
  Client.HandleRedirects:=False;Client.AllowCookies:=False;
  Client.ConnectionTimeout:=Request.TimeoutMs;Client.SendTimeout:=Request.TimeoutMs;Client.ResponseTimeout:=Request.TimeoutMs;
  Client.OnReceiveData:=ReceiveData;
  Headers:=[TNameValuePair.Create('Content-Type','application/json; charset=utf-8')];
  if Request.Authorization<>'' then Headers:=Headers+[TNameValuePair.Create('Authorization',Request.Authorization)];
  Started:=GetTickCount64;Cancelled:=False;TimedOut:=False;
  Async:=Client.BeginPost(Request.URL,Input,Output,Headers);
  while not Async.IsCompleted do begin
   Cancelled:=TInterlocked.CompareExchange(FCancelled,0,0)<>0;TimedOut:=GetTickCount64-Started>UInt64(Request.TimeoutMs);
   if Cancelled or TimedOut then begin Async.Cancel;Break;end;TThread.Sleep(10);
  end;
  try Reply:=THTTPClient.EndAsyncHTTP(Async);
  except on E:Exception do begin
   if Output.Exceeded or (TInterlocked.CompareExchange(FTooLarge,0,0)<>0) then raise EAIError.Create('AI response exceeds the configured limit');
   if Cancelled then raise EAIError.Create('AI request cancelled');
   if TimedOut then raise EAIError.Create('AI request timed out');
   raise EAIError.Create('AI transport failed');
  end;end;
  if Cancelled then raise EAIError.Create('AI request cancelled');if TimedOut then raise EAIError.Create('AI request timed out');
  if Output.Exceeded or (TInterlocked.CompareExchange(FTooLarge,0,0)<>0) or (Output.Size>Request.MaxResponseBytes) then raise EAIError.Create('AI response exceeds the configured limit');
  SetLength(Bytes,Output.Size);if Output.Size>0 then Move(Output.Memory^,Bytes[0],Output.Size);Result.Status:=Reply.StatusCode;Result.Body:=TEncoding.UTF8.GetString(Bytes);
 finally Async:=nil;Reply:=nil;Output.Free;Input.Free;Client.Free;end;
end;
end.
