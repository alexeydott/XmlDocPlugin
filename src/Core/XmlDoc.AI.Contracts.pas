/// <summary>Shared request, context, transport and reviewable proposal contracts for AI documentation.</summary>
unit XmlDoc.AI.Contracts;
interface
uses System.SysUtils;
type
 /// <summary>Reports invalid AI configuration, context, transport or response data without accepting a proposal.</summary>
 EAIError=class(Exception);
 TAIOperation=(aoDescribe,aoRephrase);
 TAIContext=record
  Signature,Code,Documentation,Parameters,ReturnType,TypeContext,ProjectTerms,UserInstruction,Fingerprint:string;
 end;
 TAIProfile=record
  Id,Name,Endpoint,RequestPath,Model,Language,Authorization,OutputLimitParameter:string;
  TimeoutMs,MaxContextChars,MaxResponseBytes,MaxOutputTokens,RetryCount:Integer;
  JsonMode,DisableThinking:Boolean;
  class function Defaults:TAIProfile;static;
 end;
 TAIHttpRequest=record
  URL,Body,Authorization:string;
  TimeoutMs,MaxResponseBytes,RetryCount:Integer;
 end;
 TAIHttpResponse=record
  Status:Integer;
  Body:string;
 end;
 IAITransport=interface
  ['{85C555DE-EC5D-4D3B-BFA7-329BD4CB6408}']
  function Execute(const Request:TAIHttpRequest):TAIHttpResponse;
  procedure Cancel;
 end;
 /// <summary>Plain parameter prose returned by a provider; the host validates declaration names before applying it.</summary>
 TAIParameter=record Name,Description:string;end;
 /// <summary>Reviewable summary, optional parameter descriptions and explicit uncertainties.</summary>
 TAIProposal=record
  Summary:string;
  Parameters:TArray<TAIParameter>;
  Uncertainties:TArray<string>;
 end;
implementation
class function TAIProfile.Defaults:TAIProfile;
begin
 Result:=Default(TAIProfile);Result.Name:='Default';Result.Endpoint:='https://api.openai.com/v1';
 Result.RequestPath:='chat/completions';Result.Authorization:='bearer';Result.Language:='English';
 Result.RetryCount:=3;Result.TimeoutMs:=30000;Result.MaxContextChars:=60000;Result.MaxResponseBytes:=262144;
end;
end.
