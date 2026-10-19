/// <summary>Validated XML fragment loading and serialization helpers.</summary>
unit XmlDoc.XmlFragments;
interface
uses System.SysUtils,Xml.XMLIntf;
function LoadDocXml(const Xml:string):IXMLDocument;
function HasForbiddenDeclarations(const Xml:string):Boolean;
function RenameDocNames(const Xml:string;const Mappings:TArray<string>):string;
implementation
uses System.Generics.Collections,System.RegularExpressions,System.StrUtils,Xml.XMLDoc;
function HasForbiddenDeclarations(const Xml:string):Boolean;
var Prose:string;
begin Prose:=TRegEx.Replace(Xml,'(?s)<!\[CDATA\[.*?\]\]>|<!--.*?-->','');Result:=ContainsText(Prose,'<!DOCTYPE') or ContainsText(Prose,'<!ENTITY');end;
function LoadDocXml(const Xml:string):IXMLDocument;
begin
 if HasForbiddenDeclarations(Xml) then raise Exception.Create('Document type declarations and entities are not allowed');
 Result:=TXMLDocument.Create(nil);Result.ParseOptions:=[poPreserveWhiteSpace];Result.Options:=[];Result.LoadFromXML(Xml);Result.Active:=True;
end;
function RenameDocNames(const Xml:string;const Mappings:TArray<string>):string;
var Names,Targets:TDictionary<string,string>;Pair:string;Parts:TArray<string>;Doc:IXMLDocument;I:Integer;
 procedure Visit(Node:IXMLNode);
 var Child:IXMLNode;J:Integer;OldName,NewName:string;
 begin
  if (Node.NodeType=ntElement) and ((Node.NodeName='param') or (Node.NodeName='paramref') or (Node.NodeName='typeparam') or (Node.NodeName='typeparamref')) and Node.HasAttribute('name') then begin
   OldName:=LowerCase(Node.Attributes['name']);if Names.TryGetValue(OldName,NewName) then Node.Attributes['name']:=NewName;
  end;
  for J:=0 to Node.ChildNodes.Count-1 do Visit(Node.ChildNodes[J]);
 end;
begin
 if Length(Mappings)=0 then Exit(Xml);
 Names:=TDictionary<string,string>.Create;Targets:=TDictionary<string,string>.Create;
 try
  for Pair in Mappings do begin Parts:=Pair.Split(['=']);if (Length(Parts)<>2) or (Trim(Parts[0])='') or (Trim(Parts[1])='') then raise Exception.Create('Expected old=new mapping');
   if Names.ContainsKey(LowerCase(Parts[0])) or Targets.ContainsKey(LowerCase(Parts[1])) then raise Exception.Create('Rename mappings must be one-to-one');
   Names.Add(LowerCase(Parts[0]),Parts[1]);Targets.Add(LowerCase(Parts[1]),Parts[0]);
  end;
  Doc:=LoadDocXml('<doc>'+Xml+'</doc>');Visit(Doc.DocumentElement);Result:='';
  for I:=0 to Doc.DocumentElement.ChildNodes.Count-1 do Result:=Result+Doc.DocumentElement.ChildNodes[I].XML;
 finally Targets.Free;Names.Free;end;
end;
end.
