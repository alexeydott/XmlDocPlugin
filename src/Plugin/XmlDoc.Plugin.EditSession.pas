unit XmlDoc.Plugin.EditSession;
interface
uses System.SysUtils,System.JSON,ToolsAPI,XmlDoc.Consts;
function ParseHostMessage(const Text:string):TJSONObject;
function CurrentSourceSnapshots:TArray<TSourceSnapshot>;
function EditorSource(const Editor:IOTASourceEditor):string;
function SourceEditorForFile(const FileName:string):IOTASourceEditor;
function SourceEditProtection(const FileName:string):string;
function SourceRevision(const Source:string):string;
procedure AddEditContext(Json:TJSONObject;const Element:TCodeElementInfo;const FileName,SessionId,Source:string);
function ValidateEdit(Message:TJSONObject;const Element:TCodeElementInfo;const FileName,SessionId,Source:string):Boolean;
function EditResult(const SessionId,Status:string):string;
implementation
uses XmlDoc.SourceAccess,System.Classes,System.Hash,System.Generics.Collections,XmlDoc.SourceText;
function ParseHostMessage(const Text:string):TJSONObject;
var Value:TJSONValue;
begin
 Result:=nil;Value:=nil;
 try Value:=TJSONObject.ParseJSONValue(Text);if Value is TJSONObject then begin Result:=TJSONObject(Value);Value:=nil;end;
 finally Value.Free;end;
end;
function EditorSource(const Editor:IOTASourceEditor):string;
var Reader:IOTAEditReader;Bytes:TBytes;Data:TBytesStream;Count,Offset:Integer;
begin
 Result:='';if not Assigned(Editor) then Exit;
 Reader:=Editor.CreateReader;if not Assigned(Reader) then Exit;
 Data:=TBytesStream.Create;
 try
  Offset:=0;SetLength(Bytes,32768);
  repeat
   Count:=Reader.GetText(Offset,PAnsiChar(Bytes),Length(Bytes));
   if Count>0 then begin Data.WriteBuffer(Bytes[0],Count);Inc(Offset,Count);end;
  until Count<Length(Bytes);
  Offset:=0;
  if (Data.Size>=3) and (Data.Bytes[0]=$EF) and (Data.Bytes[1]=$BB) and (Data.Bytes[2]=$BF) then Offset:=3;
  Result:=DecodeSource(Data.Bytes,Offset,Data.Size-Offset);
 finally Data.Free;end;
end;
function CurrentSourceSnapshots:TArray<TSourceSnapshot>;
var Services:IOTAModuleServices;Module:IOTAModule;Editor:IOTASourceEditor;I,J:Integer;Snapshot:TSourceSnapshot;
 List:TList<TSourceSnapshot>;
begin
 List:=TList<TSourceSnapshot>.Create;
 try
  if Supports(BorlandIDEServices,IOTAModuleServices,Services) then for I:=0 to Services.ModuleCount-1 do begin
   Module:=Services.Modules[I];for J:=0 to Module.ModuleFileCount-1 do
    if Supports(Module.ModuleFileEditors[J],IOTASourceEditor,Editor) then begin
     Snapshot.FileName:=Editor.FileName;Snapshot.Source:=EditorSource(Editor);List.Add(Snapshot);
    end;
  end;
  Result:=List.ToArray;
 finally List.Free;end;
end;
function SourceEditorForFile(const FileName:string):IOTASourceEditor;
var Services:IOTAModuleServices;Module:IOTAModule;I:Integer;
begin
 Result:=nil;
 if not Supports(BorlandIDEServices,IOTAModuleServices,Services) then Exit;
 Module:=Services.FindModule(FileName);if not Assigned(Module) then Exit;
 for I:=0 to Module.ModuleFileCount-1 do
  if Supports(Module.ModuleFileEditors[I],IOTASourceEditor,Result) and SameText(Result.FileName,FileName) then Exit;
 Result:=nil;
end;
function SourceEditProtection(const FileName:string):string;
var Editor:IOTASourceEditor;Buffer:IOTAEditBuffer;
begin
 Result:=SourceReadOnlyReason(FileName);if Result<>'' then Exit;
 Editor:=SourceEditorForFile(FileName);
 if Assigned(Editor) and Supports(Editor,IOTAEditBuffer,Buffer) and Buffer.IsReadOnly then Result:='Read-only: IDE source buffer';
end;
function SourceRevision(const Source:string):string;
begin Result:=THashSHA2.GetHashString(Source);end;
procedure AddEditContext(Json:TJSONObject;const Element:TCodeElementInfo;const FileName,SessionId,Source:string);
begin
 Json.AddPair('readOnly',TJSONBool.Create(SourceEditProtection(FileName)<>''));
 Json.AddPair('readOnlyReason',SourceEditProtection(FileName));
 Json.AddPair('declarationId',Element.SymbolId+'@'+IntToStr(Element.LineNumber));
 Json.AddPair('canonicalName',Element.CanonicalName);Json.AddPair('unitName',Element.UnitName);
 Json.AddPair('symbolId',Element.SymbolId);Json.AddPair('signature',Element.Signature);
 Json.AddPair('sessionId',SessionId);Json.AddPair('sourceRevision',SourceRevision(Source));
 Json.RemovePair('fileName').Free;Json.AddPair('fileName',FileName);
 Json.AddPair('ancestor',Element.Ancestor);Json.AddPair('commentStartLine',TJSONNumber.Create(Element.CommentStartLine));
end;
function ValidateEdit(Message:TJSONObject;const Element:TCodeElementInfo;const FileName,SessionId,Source:string):Boolean;
var Editor:IOTASourceEditor;Services:IOTAEditorServices;
begin
 Result:=False;
 if SourceEditProtection(FileName)<>'' then Exit;
 if (Message.GetValue<string>('sessionId','')<>SessionId) or
  (SessionId='') or (Message.GetValue<string>('symbolId','')<>Element.SymbolId) or
  (Message.GetValue<string>('declarationId','')<>Element.SymbolId+'@'+IntToStr(Element.LineNumber)) or
  not SameText(Message.GetValue<string>('fileName',''),FileName) or
  (Message.GetValue<string>('sourceRevision','')<>SourceRevision(Source)) then Exit;
 Editor:=SourceEditorForFile(FileName);
 if not Assigned(Editor) then Exit;
 Result:=SourceRevision(EditorSource(Editor))=SourceRevision(Source);
end;
function EditResult(const SessionId,Status:string):string;
var Json:TJSONObject;
begin
 Json:=TJSONObject.Create;try Json.AddPair('type','editResult');Json.AddPair('sessionId',SessionId);
 Json.AddPair('status',Status);Result:='window.bridge.receive('+Json.ToJSON+');';finally Json.Free;end;
end;
end.
