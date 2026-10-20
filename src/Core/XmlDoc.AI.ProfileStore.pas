/// <summary>Reads AI profiles and scoped credentials without IDE or form dependencies.</summary>
unit XmlDoc.AI.ProfileStore;
interface
uses System.SysUtils,System.JSON,XmlDoc.AI.Contracts;
/// <summary>Returns the per-user profile file, or the explicitly overridden configuration path.</summary>
function AIConfigurationPath:string;
/// <summary>Reads a supported profile document without changing it or loading IDE services.</summary>
function LoadAIConfiguration:TJSONObject;
/// <summary>Loads connection options and limits while retaining defaults for absent optional fields.</summary>
function AIProfileFromJson(Json:TJSONObject):TAIProfile;
/// <summary>Scopes a credential identity to the profile and the exact request destination.</summary>
function AICredentialTarget(const Profile:TAIProfile):string;
/// <summary>Reads the scoped Windows credential without exposing it in profile JSON.</summary>
function ReadAIKey(const Profile:TAIProfile):string;
implementation
uses System.IOUtils,System.Hash,Winapi.Windows,Winapi.WinCred,XmlDoc.AI.OpenAI;
function AIConfigurationPath:string;
begin Result:=GetEnvironmentVariable('XMLDOC_AI_CONFIG');if Result='' then Result:=TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'),'XmlDocPlugin\ai.json') else Result:=TPath.GetFullPath(Result);end;
function ReadConfigObject(const Path:string):TJSONObject;
var Value:TJSONValue;
begin
 Value:=TJSONObject.ParseJSONValue(TFile.ReadAllText(Path,TEncoding.UTF8));
 if not (Value is TJSONObject) then begin Value.Free;raise EAIError.Create('Invalid AI configuration');end;
 Result:=Value as TJSONObject;
end;
function LoadAIConfiguration:TJSONObject;
var Value:TJSONValue;
begin
 Result:=nil;Value:=nil;
 if TFile.Exists(AIConfigurationPath) then begin
  Result:=ReadConfigObject(AIConfigurationPath);
 end else Result:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1)).AddPair('profiles',TJSONArray.Create);
 try if (Result.GetValue<Integer>('version',0)<>1) or not (Result.GetValue('profiles') is TJSONArray) then raise EAIError.Create('Unsupported AI configuration version');except Result.Free;raise;end;
end;
function AIProfileFromJson(Json:TJSONObject):TAIProfile;
begin
 Result:=TAIProfile.Defaults;Result.Id:=Json.GetValue<string>('id','');Result.Name:=Json.GetValue<string>('name','Default');
 Result.Endpoint:=Json.GetValue<string>('endpoint',Result.Endpoint);Result.RequestPath:=Json.GetValue<string>('path',Result.RequestPath);
 Result.Model:=Json.GetValue<string>('model','');Result.Language:=Json.GetValue<string>('language',Result.Language);
 Result.Authorization:=Json.GetValue<string>('authorization',Result.Authorization);Result.TimeoutMs:=Json.GetValue<Integer>('timeoutMs',Result.TimeoutMs);
 Result.MaxContextChars:=Json.GetValue<Integer>('maxContextChars',Result.MaxContextChars);Result.MaxResponseBytes:=Json.GetValue<Integer>('maxResponseBytes',Result.MaxResponseBytes);
 Result.OutputLimitParameter:=Json.GetValue<string>('outputLimitParameter','');Result.MaxOutputTokens:=Json.GetValue<Integer>('maxOutputTokens',0);Result.JsonMode:=Json.GetValue<Boolean>('jsonMode',False);Result.DisableThinking:=Json.GetValue<Boolean>('disableThinking',False);Result.RetryCount:=Json.GetValue<Integer>('retryCount',3);
end;
function AICredentialTarget(const Profile:TAIProfile):string;
begin Result:='XmlDocPlugin/AI/'+THashSHA2.GetHashString(Profile.Id+#0+AIRequestURL(Profile.Endpoint,Profile.RequestPath));end;
function ReadAIKey(const Profile:TAIProfile):string;
var Credential:PCREDENTIALW;Name:string;
begin
 Result:='';Name:=AICredentialTarget(Profile);
 if CredReadW(PChar(Name),CRED_TYPE_GENERIC,0,Credential) then
 try SetString(Result,PChar(Credential.CredentialBlob),Credential.CredentialBlobSize div SizeOf(Char));finally CredFree(Credential);end;
end;
end.
