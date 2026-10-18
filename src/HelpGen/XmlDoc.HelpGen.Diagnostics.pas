unit XmlDoc.HelpGen.Diagnostics;
interface
uses System.SysUtils,System.Generics.Collections,XmlDoc.Consts,XmlDoc.Documentation,XmlDoc.HelpGen.Types;
type
 TDocumentationReport=class
 private
  FIssues:TList<TDocIssue>;
  FSymbols:TList<TCodeElementInfo>;
 public
  constructor Create;
  destructor Destroy;override;
  procedure Analyze(Units:TObjectList<TUnitDocInfo>);
  procedure Save(const FileName:string);
  procedure SaveBaseline(const FileName:string);
  function NewIssueCount(const BaselineFile:string):Integer;
  property Issues:TList<TDocIssue> read FIssues;
 end;
implementation
uses System.JSON,System.IOUtils,XmlDoc.Model;
function IssueKey(const Issue:TDocIssue):string;
var Key:TJSONArray;
begin Key:=TJSONArray.Create;try Key.Add(Issue.SymbolId);Key.Add(Issue.Code);if Issue.Code='XD001' then Key.Add('Invalid XML') else Key.Add(Issue.Message);Result:=Key.ToJSON;finally Key.Free;end;end;
constructor TDocumentationReport.Create;
begin inherited;FIssues:=TList<TDocIssue>.Create;FSymbols:=TList<TCodeElementInfo>.Create;end;
destructor TDocumentationReport.Destroy;
begin FSymbols.Free;FIssues.Free;inherited;end;
procedure TDocumentationReport.Analyze(Units:TObjectList<TUnitDocInfo>);
var U:TUnitDocInfo;T:TTypeDocInfo;E:TElementDocInfo;
 procedure AddType(Typ:TTypeDocInfo);
 var M:TElementDocInfo;N:TTypeDocInfo;
 begin FSymbols.Add(Typ.CodeElement);for M in Typ.Members do FSymbols.Add(M.CodeElement);for N in Typ.NestedTypes do AddType(N);end;
 procedure Check(const Code:TCodeElementInfo;Model:TXmlDocModel);
 begin FIssues.AddRange(TDocumentation.Analyze(Code,Model,FSymbols.ToArray));end;
 procedure CheckType(Typ:TTypeDocInfo);
 var M:TElementDocInfo;N:TTypeDocInfo;
 begin Check(Typ.CodeElement,Typ.Doc);for M in Typ.Members do Check(M.CodeElement,M.Doc);for N in Typ.NestedTypes do CheckType(N);end;
begin
 FIssues.Clear;FSymbols.Clear;
 for U in Units do begin FSymbols.Add(U.UnitElement);for T in U.Types do AddType(T);
  for E in U.StandaloneMethods do FSymbols.Add(E.CodeElement);for E in U.Constants do FSymbols.Add(E.CodeElement);for E in U.Variables do FSymbols.Add(E.CodeElement);end;
 for U in Units do begin Check(U.UnitElement,U.UnitDoc);for T in U.Types do CheckType(T);
  for E in U.StandaloneMethods do Check(E.CodeElement,E.Doc);for E in U.Constants do Check(E.CodeElement,E.Doc);for E in U.Variables do Check(E.CodeElement,E.Doc);end;
end;
procedure WriteJson(const FileName:string;Value:TJSONObject);
begin ForceDirectories(ExtractFilePath(TPath.GetFullPath(FileName)));TFile.WriteAllText(FileName,Value.ToJSON,TEncoding.UTF8);end;
procedure TDocumentationReport.Save(const FileName:string);
var Root,Item:TJSONObject;Items:TJSONArray;Issue:TDocIssue;
begin
 Root:=TJSONObject.Create;Items:=TJSONArray.Create;Root.AddPair('version',TJSONNumber.Create(1));Root.AddPair('issues',Items);
 try for Issue in FIssues do begin Item:=TJSONObject.Create;Item.AddPair('code',Issue.Code);Item.AddPair('message',Issue.Message);
  Item.AddPair('file',Issue.FileName);Item.AddPair('symbolId',Issue.SymbolId);Item.AddPair('fix',Issue.Fix);
  Item.AddPair('line',TJSONNumber.Create(Issue.Line));Item.AddPair('column',TJSONNumber.Create(Issue.Column));Items.AddElement(Item);end;WriteJson(FileName,Root);
 finally Root.Free;end;
end;
procedure TDocumentationReport.SaveBaseline(const FileName:string);
var Root:TJSONObject;Items,Symbols,PublicSymbols:TJSONArray;Issue:TDocIssue;E:TCodeElementInfo;Item:TJSONObject;
begin
 Root:=TJSONObject.Create;Items:=TJSONArray.Create;Symbols:=TJSONArray.Create;Root.AddPair('version',TJSONNumber.Create(1));Root.AddPair('issues',Items);Root.AddPair('symbols',Symbols);PublicSymbols:=TJSONArray.Create;Root.AddPair('publicSymbols',PublicSymbols);
 try for Issue in FIssues do Items.Add(IssueKey(Issue));for E in FSymbols do begin Symbols.Add(E.SymbolId);
  if (E.Visibility='') or SameText(E.Visibility,'public') or SameText(E.Visibility,'published') or SameText(E.Visibility,'protected') then begin
   Item:=TJSONObject.Create;Item.AddPair('symbolId',E.SymbolId);Item.AddPair('name',E.CanonicalName);Item.AddPair('file',E.FileName);Item.AddPair('line',TJSONNumber.Create(E.LineNumber));PublicSymbols.AddElement(Item);
  end;
 end;WriteJson(FileName,Root);finally Root.Free;end;
end;
function TDocumentationReport.NewIssueCount(const BaselineFile:string):Integer;
var Root:TJSONObject;Items:TJSONArray;Known:TDictionary<string,Boolean>;Value:TJSONValue;Issue:TDocIssue;PublicSymbols:TJSONArray;Item:TJSONObject;Found:Boolean;E:TCodeElementInfo;I:Integer;
begin
 for I:=FIssues.Count-1 downto 0 do if FIssues[I].Code='XD011' then FIssues.Delete(I);
 Result:=0;Known:=TDictionary<string,Boolean>.Create;Root:=nil;
 try
  if BaselineFile<>'' then begin Root:=TJSONObject.ParseJSONValue(TFile.ReadAllText(BaselineFile)) as TJSONObject;
   if not Assigned(Root) or (Root.GetValue<Integer>('version',0)<>1) then raise Exception.Create('Unsupported documentation baseline');
   Items:=Root.GetValue<TJSONArray>('issues');if not Assigned(Items) then raise Exception.Create('Baseline issue list is missing');
   for Value in Items do Known.AddOrSetValue(Value.Value,True);
   if Root.TryGetValue<TJSONArray>('publicSymbols',PublicSymbols) then for Value in PublicSymbols do begin
    Item:=Value as TJSONObject;Found:=False;
    for E in FSymbols do if E.SymbolId=Item.GetValue<string>('symbolId','') then begin Found:=True;Break;end;
    if not Found then begin
     Issue:=Default(TDocIssue);Issue.Code:='XD011';Issue.SymbolId:=Item.GetValue<string>('symbolId','');
     Issue.Message:='Public declaration removed or signature changed: '+Item.GetValue<string>('name',Issue.SymbolId);
     Issue.FileName:=Item.GetValue<string>('file','');Issue.Line:=Item.GetValue<Integer>('line',1);Issue.Column:=1;Issue.Fix:='review-api-change';
     FIssues.Add(Issue);
    end;
   end;
  end;
  for Issue in FIssues do if not Known.ContainsKey(IssueKey(Issue)) then Inc(Result);
 finally Root.Free;Known.Free;end;
end;
end.
