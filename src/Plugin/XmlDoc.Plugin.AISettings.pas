unit XmlDoc.Plugin.AISettings;
interface
uses System.SysUtils,System.JSON,XmlDoc.AI.Contracts,XmlDoc.AI.Prompts;
function AIConfigurationPath:string;
function LoadAIConfiguration:TJSONObject;
procedure SaveAIConfiguration(Config:TJSONObject);
function AIProfileFromJson(Json:TJSONObject):TAIProfile;
function AIProfileJson(const Profile:TAIProfile):TJSONObject;
function AICredentialTarget(const Profile:TAIProfile):string;
function ReadAIKey(const Profile:TAIProfile):string;
procedure WriteAIKey(const Profile:TAIProfile;const Key:string);
function AIPrompts(const ProjectDir:string):TJSONArray;
procedure SaveAIPrompts(Prompts:TJSONArray;const ProjectDir:string);
procedure ShowAISettings(const ProjectDir:string='');
implementation
uses ToolsAPI,System.Classes,System.IOUtils,System.Hash,System.StrUtils,Winapi.Windows,Winapi.WinCred,Vcl.Forms,Vcl.StdCtrls,Vcl.ExtCtrls,Vcl.Controls,Vcl.ComCtrls,Vcl.Dialogs,
 XmlDoc.AI.OpenAI,XmlDoc.Plugin.Localization,XmlDoc.I18n;
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
procedure AtomicJson(const Path:string;Value:TJSONObject);
var Temp:string;
begin
 TDirectory.CreateDirectory(ExtractFilePath(Path));Temp:=Path+'.'+TGUID.NewGuid.ToString+'.tmp';
 try TFile.WriteAllText(Temp,Value.ToJSON,TEncoding.UTF8);if not MoveFileEx(PChar(Temp),PChar(Path),MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then RaiseLastOSError;finally if TFile.Exists(Temp) then TFile.Delete(Temp);end;
end;
procedure SaveAIConfiguration(Config:TJSONObject);
begin AtomicJson(AIConfigurationPath,Config);end;
function AIProfileFromJson(Json:TJSONObject):TAIProfile;
begin
 Result:=TAIProfile.Defaults;Result.Id:=Json.GetValue<string>('id','');Result.Name:=Json.GetValue<string>('name','Default');
 Result.Endpoint:=Json.GetValue<string>('endpoint',Result.Endpoint);Result.RequestPath:=Json.GetValue<string>('path',Result.RequestPath);
 Result.Model:=Json.GetValue<string>('model','');Result.Language:=Json.GetValue<string>('language',Result.Language);
 Result.Authorization:=Json.GetValue<string>('authorization',Result.Authorization);Result.TimeoutMs:=Json.GetValue<Integer>('timeoutMs',Result.TimeoutMs);
 Result.MaxContextChars:=Json.GetValue<Integer>('maxContextChars',Result.MaxContextChars);Result.MaxResponseBytes:=Json.GetValue<Integer>('maxResponseBytes',Result.MaxResponseBytes);
 Result.OutputLimitParameter:=Json.GetValue<string>('outputLimitParameter','');Result.MaxOutputTokens:=Json.GetValue<Integer>('maxOutputTokens',0);Result.JsonMode:=Json.GetValue<Boolean>('jsonMode',False);
end;
function AIProfileJson(const Profile:TAIProfile):TJSONObject;
begin
 Result:=TJSONObject.Create.AddPair('id',Profile.Id).AddPair('name',Profile.Name).AddPair('endpoint',Profile.Endpoint).AddPair('path',Profile.RequestPath).AddPair('model',Profile.Model).AddPair('language',Profile.Language).AddPair('authorization',Profile.Authorization);
 Result.AddPair('timeoutMs',TJSONNumber.Create(Profile.TimeoutMs)).AddPair('maxContextChars',TJSONNumber.Create(Profile.MaxContextChars)).AddPair('maxResponseBytes',TJSONNumber.Create(Profile.MaxResponseBytes)).AddPair('outputLimitParameter',Profile.OutputLimitParameter).AddPair('maxOutputTokens',TJSONNumber.Create(Profile.MaxOutputTokens)).AddPair('jsonMode',TJSONBool.Create(Profile.JsonMode));
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
procedure WriteAIKey(const Profile:TAIProfile;const Key:string);
var Credential:CREDENTIALW;Name,User:string;
begin
 Name:=AICredentialTarget(Profile);if Key='' then begin CredDeleteW(PChar(Name),CRED_TYPE_GENERIC,0);Exit;end;
 Credential:=Default(CREDENTIALW);User:='XmlDocPlugin';Credential.&Type:=CRED_TYPE_GENERIC;Credential.TargetName:=PChar(Name);Credential.UserName:=PChar(User);
 Credential.CredentialBlobSize:=Length(Key)*SizeOf(Char);Credential.CredentialBlob:=PByte(PChar(Key));Credential.Persist:=CRED_PERSIST_LOCAL_MACHINE;
 if not CredWriteW(@Credential,0) then RaiseLastOSError;
end;
function PromptJson(Operation:TAIOperation):TJSONObject;
var P:TAIPrompt;
begin P:=TAIPrompt.BuiltIn(Operation);Result:=TJSONObject.Create.AddPair('id',P.Id).AddPair('name',P.Name).AddPair('operation',P.Id).AddPair('system',P.SystemText).AddPair('user',P.UserText);end;
procedure ValidateTemplates(Items:TJSONArray);
var IDs:TStringList;Context:TAIContext;
begin
 if (Items.Count=0) or (Items.Count>100) then raise EAIError.Create('Invalid AI template');
 IDs:=TStringList.Create;
 try
  Context:=Default(TAIContext);Context.Signature:='validation';Context.Code:='validation';
  for var Value in Items do begin
   if not (Value is TJSONObject) then raise EAIError.Create('Invalid AI template');var Item:=Value as TJSONObject;
   for var Key in ['id','name','operation','system','user'] do if not (Item.GetValue(Key) is TJSONString) then raise EAIError.Create('Invalid AI template');
   if (Item.Count<>5) or (Item.GetValue<string>('id')='') or (Item.GetValue<string>('name')='') or (Length(Item.GetValue<string>('id'))>128) or IDs.Contains(Item.GetValue<string>('id')) then raise EAIError.Create('Invalid AI template');
   if (Item.GetValue<string>('operation')<>'describe') and (Item.GetValue<string>('operation')<>'rephrase') then raise EAIError.Create('Invalid AI template');
   if Trim(Item.GetValue<string>('user'))='' then raise EAIError.Create('Invalid AI template');
   IDs.Add(Item.GetValue<string>('id'));ExpandPrompt(Item.GetValue<string>('system'),Context,'validation');ExpandPrompt(Item.GetValue<string>('user'),Context,'validation');
  end;
 finally IDs.Free;end;
end;
function AIPrompts(const ProjectDir:string):TJSONArray;
var Config:TJSONObject;Global,Local:TJSONArray;FileName,Id:string;ReplaceIndex:Integer;
begin
 Result:=TJSONArray.Create;Result.AddElement(PromptJson(aoDescribe));Result.AddElement(PromptJson(aoRephrase));
 try
  for var Scope in ['',ProjectDir] do begin
   if (Scope='') and (ProjectDir='') and (Result.Count>2) then Break;
   Config:=nil;
   try
    if Scope='' then Config:=LoadAIConfiguration else begin FileName:=TPath.Combine(Scope,'.xmldocplugin.json');if TFile.Exists(FileName) then Config:=ReadConfigObject(FileName);end;
    if not Assigned(Config) then Continue;
    if Scope='' then Local:=Config.GetValue<TJSONArray>('templates',nil)
    else Local:=Config.GetValue<TJSONArray>('authoring.ai.templates',nil);
    if Assigned(Local) then begin ValidateTemplates(Local);end;
    if Assigned(Local) then for var Item in Local do begin
     if not (Item is TJSONObject) then raise EAIError.Create('Invalid AI template');Id:=TJSONObject(Item).GetValue<string>('id');ReplaceIndex:=-1;
     for var I:=0 to Result.Count-1 do if TJSONObject(Result[I]).GetValue<string>('id')=Id then ReplaceIndex:=I;
     if ReplaceIndex>=0 then Result.Remove(ReplaceIndex).Free;Result.AddElement(Item.Clone as TJSONObject);
    end;
   finally Config.Free;end;
   if ProjectDir='' then Break;
  end;
 except Result.Free;raise;end;
end;
procedure SaveAIPrompts(Prompts:TJSONArray;const ProjectDir:string);
var Config,Authoring,AI:TJSONObject;Path:string;
begin
 ValidateTemplates(Prompts);Config:=nil;
 try
  if ProjectDir='' then begin Config:=LoadAIConfiguration;Config.RemovePair('templates').Free;Config.AddPair('templates',Prompts.Clone as TJSONArray);SaveAIConfiguration(Config);end
  else begin
   Path:=TPath.Combine(ProjectDir,'.xmldocplugin.json');if TFile.Exists(Path) then Config:=ReadConfigObject(Path);
   if not Assigned(Config) then Config:=TJSONObject.Create;
   Authoring:=Config.GetValue<TJSONObject>('authoring',nil);if not Assigned(Authoring) then begin Authoring:=TJSONObject.Create;Config.AddPair('authoring',Authoring);end;
   AI:=Authoring.GetValue<TJSONObject>('ai',nil);if not Assigned(AI) then begin AI:=TJSONObject.Create;Authoring.AddPair('ai',AI);end;
   AI.RemovePair('templates').Free;AI.AddPair('templates',Prompts.Clone as TJSONArray);AtomicJson(Path,Config);
  end;
 finally Config.Free;end;
end;

type TAISettingsForm=class(TForm)
 private
  Config:TJSONObject;Templates:TJSONArray;ProjectDir:string;
  Profiles,TemplateList:TComboBox;Fields:TArray<TEdit>;Auth,Limit:TComboBox;JsonMode,ProjectScope:TCheckBox;
  KeyEdit:TEdit;FullURL:TLabel;SystemPrompt,UserPrompt:TMemo;TemplateName:TEdit;Operation:TComboBox;
  procedure ProfileChanged(Sender:TObject);procedure SaveProfile(Sender:TObject);procedure NewProfile(Sender:TObject);
  procedure TemplateChanged(Sender:TObject);procedure SaveTemplate(Sender:TObject);procedure NewTemplate(Sender:TObject);procedure ResetTemplate(Sender:TObject);
  procedure ImportTemplates(Sender:TObject);procedure ExportTemplates(Sender:TObject);procedure UpdateURL(Sender:TObject);
  procedure ClearKey(Sender:TObject);
 public
  constructor CreateForProject(const Directory:string);
  destructor Destroy;override;
 end;
constructor TAISettingsForm.CreateForProject(const Directory:string);
var Pages:TPageControl;Page:TTabSheet;LabelControl:TLabel;Button:TButton;Names:TArray<string>;I:Integer;
 procedure AddButton(Parent:TWinControl;const Text:string;X,Y:Integer;Handler:TNotifyEvent);
 begin Button:=TButton.Create(Self);Button.Parent:=Parent;Button.SetBounds(X,Y,170,28);Button.Name:='AIButton'+Text.Replace(' ','').Replace('-','');Button.Caption:=Text;Button.OnClick:=Handler;end;
begin
 inherited CreateNew(nil);ProjectDir:=Directory;Caption:='AI profiles and prompts';Position:=poScreenCenter;ClientWidth:=850;ClientHeight:=700;
 Config:=LoadAIConfiguration;Templates:=AIPrompts(ProjectDir);Pages:=TPageControl.Create(Self);Pages.Parent:=Self;Pages.Align:=alClient;
 Page:=TTabSheet.Create(Self);Page.PageControl:=Pages;Page.Caption:='Connection profiles';
 Profiles:=TComboBox.Create(Self);Profiles.Parent:=Page;Profiles.SetBounds(16,12,400,24);Profiles.Style:=csDropDownList;Profiles.OnChange:=ProfileChanged;
 for var Item in Config.GetValue<TJSONArray>('profiles') do Profiles.Items.Add((Item as TJSONObject).GetValue<string>('name'));
 AddButton(Page,'New profile',430,10,NewProfile);AddButton(Page,'Save profile',610,10,SaveProfile);
 Names:= ['Profile name','Endpoint','Request path','Model','Documentation language','Timeout (ms)','Context limit (characters)','Response limit (bytes)','Output token limit'];SetLength(Fields,Length(Names));
 for I:=0 to High(Names) do begin LabelControl:=TLabel.Create(Self);LabelControl.Parent:=Page;LabelControl.SetBounds(16,55+I*36,230,24);LabelControl.Caption:=Names[I];Fields[I]:=TEdit.Create(Self);Fields[I].Name:='AIField'+IntToStr(I);Fields[I].Parent:=Page;Fields[I].SetBounds(260,52+I*36,540,24);end;
 Fields[1].OnChange:=UpdateURL;Fields[2].OnChange:=UpdateURL;
 LabelControl:=TLabel.Create(Self);LabelControl.Parent:=Page;LabelControl.SetBounds(16,382,230,24);LabelControl.Caption:='Authorization';Auth:=TComboBox.Create(Self);Auth.Parent:=Page;Auth.SetBounds(260,378,170,24);Auth.Style:=csDropDownList;Auth.Items.Add('Bearer');Auth.Items.Add(TI18n.Instance.T('None'));
 LabelControl:=TLabel.Create(Self);LabelControl.Parent:=Page;LabelControl.SetBounds(16,416,230,24);LabelControl.Caption:='API key';KeyEdit:=TEdit.Create(Self);KeyEdit.Name:='AIKey';KeyEdit.Parent:=Page;KeyEdit.SetBounds(260,412,360,24);KeyEdit.PasswordChar:='*';KeyEdit.TextHint:='Blank keeps the stored key';AddButton(Page,'Delete stored key',630,410,ClearKey);
 LabelControl:=TLabel.Create(Self);LabelControl.Parent:=Page;LabelControl.SetBounds(16,450,230,24);LabelControl.Caption:='Output limit parameter';Limit:=TComboBox.Create(Self);Limit.Parent:=Page;Limit.SetBounds(260,446,240,24);Limit.Style:=csDropDownList;Limit.Items.Add('');Limit.Items.Add('max_tokens');Limit.Items.Add('max_completion_tokens');
 JsonMode:=TCheckBox.Create(Self);JsonMode.Parent:=Page;JsonMode.SetBounds(260,480,400,24);JsonMode.Caption:='Request JSON mode (if supported)';
 FullURL:=TLabel.Create(Self);FullURL.Parent:=Page;FullURL.SetBounds(16,525,780,65);FullURL.AutoSize:=False;FullURL.WordWrap:=True;
 LabelControl:=TLabel.Create(Self);LabelControl.Parent:=Page;LabelControl.SetBounds(16,600,780,45);LabelControl.AutoSize:=False;LabelControl.WordWrap:=True;LabelControl.Caption:='Keys stay in Windows Credential Manager. Changing the destination requires a new key. Test the connection from the assistant before sending source.';
 Page:=TTabSheet.Create(Self);Page.PageControl:=Pages;Page.Caption:='Prompt templates';TemplateList:=TComboBox.Create(Self);TemplateList.Parent:=Page;TemplateList.SetBounds(16,12,370,24);TemplateList.Style:=csDropDownList;TemplateList.OnChange:=TemplateChanged;
 for var Item in Templates do TemplateList.Items.Add(TI18n.Instance.T((Item as TJSONObject).GetValue<string>('name')));
 AddButton(Page,'Duplicate template',410,10,NewTemplate);AddButton(Page,'Restore built-in',600,10,ResetTemplate);
 TemplateName:=TEdit.Create(Self);TemplateName.Parent:=Page;TemplateName.SetBounds(16,52,370,24);Operation:=TComboBox.Create(Self);Operation.Parent:=Page;Operation.SetBounds(410,52,200,24);Operation.Style:=csDropDownList;Operation.Items.Add(TI18n.Instance.T('Describe method from code'));Operation.Items.Add(TI18n.Instance.T('Rephrase summary'));
 SystemPrompt:=TMemo.Create(Self);SystemPrompt.Name:='AISystemPrompt';SystemPrompt.Parent:=Page;SystemPrompt.SetBounds(16,92,780,135);SystemPrompt.ScrollBars:=ssVertical;SystemPrompt.Hint:='System instruction';SystemPrompt.ShowHint:=True;
 UserPrompt:=TMemo.Create(Self);UserPrompt.Name:='AIUserPrompt';UserPrompt.Parent:=Page;UserPrompt.SetBounds(16,240,780,245);UserPrompt.ScrollBars:=ssVertical;UserPrompt.Hint:='User prompt';UserPrompt.ShowHint:=True;
 ProjectScope:=TCheckBox.Create(Self);ProjectScope.Parent:=Page;ProjectScope.SetBounds(16,500,780,24);ProjectScope.Caption:='Save templates as project overrides';ProjectScope.Enabled:=ProjectDir<>'';
 AddButton(Page,'Save template',16,540,SaveTemplate);AddButton(Page,'Import templates',210,540,ImportTemplates);AddButton(Page,'Export templates',410,540,ExportTemplates);
 LabelControl:=TLabel.Create(Self);LabelControl.Parent:=Page;LabelControl.SetBounds(16,585,780,60);LabelControl.AutoSize:=False;LabelControl.WordWrap:=True;LabelControl.Caption:=TI18n.Instance.T('Prompt variables')+': {{language}}, {{signature}}, {{implementation}}, {{documentation}}, {{parameters}}, {{return_type}}, {{type_context}}, {{project_terms}}, {{user_instruction}}';LabelControl.Tag:=-1;
 if Profiles.Items.Count>0 then begin Profiles.ItemIndex:=0;ProfileChanged(nil);end else NewProfile(nil);
 TemplateList.ItemIndex:=0;TemplateChanged(nil);LocalizePluginUi(Self);var Theme:IOTAIDEThemingServices;if Supports(BorlandIDEServices,IOTAIDEThemingServices,Theme) and Theme.IDEThemingEnabled then Theme.ApplyTheme(Self);
end;
destructor TAISettingsForm.Destroy;
begin Templates.Free;Config.Free;inherited;end;
procedure TAISettingsForm.NewProfile(Sender:TObject);
var Profile:TAIProfile;
begin Profile:=TAIProfile.Defaults;Profile.Id:=TGUID.NewGuid.ToString;Config.GetValue<TJSONArray>('profiles').AddElement(AIProfileJson(Profile));Profiles.Items.Add(Profile.Name);Profiles.ItemIndex:=Profiles.Items.Count-1;ProfileChanged(nil);end;
procedure TAISettingsForm.ProfileChanged(Sender:TObject);
var P:TAIProfile;
begin
 if Profiles.ItemIndex<0 then Exit;P:=AIProfileFromJson(Config.GetValue<TJSONArray>('profiles')[Profiles.ItemIndex] as TJSONObject);
 Fields[0].Text:=P.Name;Fields[1].Text:=P.Endpoint;Fields[2].Text:=P.RequestPath;Fields[3].Text:=P.Model;Fields[4].Text:=P.Language;
 Fields[5].Text:=IntToStr(P.TimeoutMs);Fields[6].Text:=IntToStr(P.MaxContextChars);Fields[7].Text:=IntToStr(P.MaxResponseBytes);Fields[8].Text:=IntToStr(P.MaxOutputTokens);
 if P.Authorization='bearer' then Auth.ItemIndex:=0 else Auth.ItemIndex:=1;Limit.ItemIndex:=Limit.Items.IndexOf(P.OutputLimitParameter);JsonMode.Checked:=P.JsonMode;KeyEdit.Clear;UpdateURL(nil);
end;
procedure TAISettingsForm.UpdateURL(Sender:TObject);
begin try FullURL.Caption:=AIRequestURL(Fields[1].Text,Fields[2].Text);except on E:Exception do FullURL.Caption:=TI18n.Instance.T(E.Message);end;end;
procedure TAISettingsForm.SaveProfile(Sender:TObject);
var P,Old:TAIProfile;ProfilesJson:TJSONArray;Context:TAIContext;Request:TAIHttpRequest;
begin
 try
  ProfilesJson:=Config.GetValue<TJSONArray>('profiles');Old:=AIProfileFromJson(ProfilesJson[Profiles.ItemIndex] as TJSONObject);P:=Old;
  P.Name:=Fields[0].Text;P.Endpoint:=Fields[1].Text;P.RequestPath:=Fields[2].Text;P.Model:=Fields[3].Text;P.Language:=Fields[4].Text;
  P.TimeoutMs:=StrToInt(Fields[5].Text);P.MaxContextChars:=StrToInt(Fields[6].Text);P.MaxResponseBytes:=StrToInt(Fields[7].Text);P.MaxOutputTokens:=StrToInt(Fields[8].Text);P.Authorization:=IfThen(Auth.ItemIndex=0,'bearer','none');P.OutputLimitParameter:=Limit.Text;P.JsonMode:=JsonMode.Checked;
  Context:=Default(TAIContext);Context.Signature:='Connection check';Context.Code:='No source code is included.';
  Request:=BuildAIRequest(P,TAIPrompt.BuiltIn(aoDescribe),Context,'validation-placeholder');
  if KeyEdit.Text<>'' then WriteAIKey(P,KeyEdit.Text);
  ProfilesJson.Remove(Profiles.ItemIndex).Free;ProfilesJson.AddElement(AIProfileJson(P));SaveAIConfiguration(Config);
  Profiles.Items.Delete(Profiles.ItemIndex);Profiles.Items.Add(P.Name);Profiles.ItemIndex:=Profiles.Items.Count-1;ProfileChanged(nil);
 except on E:Exception do ShowMessage(TI18n.Instance.T(E.Message));end;
end;
procedure TAISettingsForm.ClearKey(Sender:TObject);
begin if Profiles.ItemIndex>=0 then WriteAIKey(AIProfileFromJson(Config.GetValue<TJSONArray>('profiles')[Profiles.ItemIndex] as TJSONObject),'');KeyEdit.Clear;end;
procedure TAISettingsForm.TemplateChanged(Sender:TObject);
var P:TJSONObject;
begin if TemplateList.ItemIndex<0 then Exit;P:=Templates[TemplateList.ItemIndex] as TJSONObject;TemplateName.Text:=P.GetValue<string>('name');if P.GetValue<string>('operation')='describe' then Operation.ItemIndex:=0 else Operation.ItemIndex:=1;SystemPrompt.Text:=P.GetValue<string>('system');UserPrompt.Text:=P.GetValue<string>('user');end;
procedure TAISettingsForm.NewTemplate(Sender:TObject);
var P:TJSONObject;
begin P:=Templates[TemplateList.ItemIndex].Clone as TJSONObject;P.RemovePair('id').Free;P.AddPair('id',TGUID.NewGuid.ToString);P.RemovePair('name').Free;P.AddPair('name',TemplateName.Text+' (copy)');Templates.AddElement(P);TemplateList.Items.Add(P.GetValue<string>('name'));TemplateList.ItemIndex:=Templates.Count-1;TemplateChanged(nil);end;
procedure TAISettingsForm.ResetTemplate(Sender:TObject);
var P:TJSONObject;
begin P:=PromptJson(TAIOperation(Operation.ItemIndex));SystemPrompt.Text:=P.GetValue<string>('system');UserPrompt.Text:=P.GetValue<string>('user');P.Free;end;
procedure TAISettingsForm.SaveTemplate(Sender:TObject);
var Context:TAIContext;P:TJSONObject;
begin
 try
  Context:=Default(TAIContext);Context.Signature:='validation';Context.Code:='validation';ExpandPrompt(SystemPrompt.Text,Context,'validation');ExpandPrompt(UserPrompt.Text,Context,'validation');
  P:=Templates[TemplateList.ItemIndex] as TJSONObject;P.RemovePair('name').Free;P.AddPair('name',TemplateName.Text);P.RemovePair('operation').Free;P.AddPair('operation',IfThen(Operation.ItemIndex=0,'describe','rephrase'));P.RemovePair('system').Free;P.AddPair('system',SystemPrompt.Text);P.RemovePair('user').Free;P.AddPair('user',UserPrompt.Text);
  SaveAIPrompts(Templates,IfThen(ProjectScope.Checked,ProjectDir,''));TemplateList.Items[TemplateList.ItemIndex]:=TemplateName.Text;
 except on E:Exception do ShowMessage(TI18n.Instance.T(E.Message));end;
end;
procedure TAISettingsForm.ExportTemplates(Sender:TObject);
var D:TSaveDialog;Value:TJSONObject;
begin D:=TSaveDialog.Create(Self);try D.Filter:='JSON|*.json';D.DefaultExt:='json';if D.Execute then begin Value:=TJSONObject.Create.AddPair('version',TJSONNumber.Create(1)).AddPair('templates',Templates.Clone as TJSONArray);try AtomicJson(D.FileName,Value);finally Value.Free;end;end;finally D.Free;end;end;
procedure TAISettingsForm.ImportTemplates(Sender:TObject);
var D:TOpenDialog;Value:TJSONObject;Parsed:TJSONValue;Items:TJSONArray;Context:TAIContext;
begin
 D:=TOpenDialog.Create(Self);Value:=nil;Parsed:=nil;
 try
 try
  D.Filter:='JSON|*.json';if not D.Execute then Exit;Parsed:=TJSONObject.ParseJSONValue(TFile.ReadAllText(D.FileName,TEncoding.UTF8));if not (Parsed is TJSONObject) then raise EAIError.Create('Invalid AI template');Value:=Parsed as TJSONObject;Parsed:=nil;
  if not Assigned(Value) or (Value.GetValue<Integer>('version',0)<>1) then raise EAIError.Create('Unsupported AI template version');Items:=Value.GetValue<TJSONArray>('templates');Context:=Default(TAIContext);Context.Signature:='validation';Context.Code:='validation';
  ValidateTemplates(Items);
  for var Item in Items do begin ExpandPrompt((Item as TJSONObject).GetValue<string>('system'),Context,'validation');ExpandPrompt((Item as TJSONObject).GetValue<string>('user'),Context,'validation');end;
  Templates.Free;Templates:=Items.Clone as TJSONArray;TemplateList.Items.Clear;for var Item in Templates do TemplateList.Items.Add(TI18n.Instance.T((Item as TJSONObject).GetValue<string>('name')));if Templates.Count>0 then begin TemplateList.ItemIndex:=0;TemplateChanged(nil);end;
 except on E:Exception do ShowMessage(TI18n.Instance.T(E.Message));end;
 finally Parsed.Free;Value.Free;D.Free;end;
end;
procedure ShowAISettings(const ProjectDir:string);
var Form:TAISettingsForm;
begin Form:=TAISettingsForm.CreateForProject(ProjectDir);try Form.ShowModal;finally Form.Free;end;end;
end.
