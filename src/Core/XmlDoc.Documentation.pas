/// <summary>Documentation validation, stable identities, authoring configuration and public API comparison.</summary>
unit XmlDoc.Documentation;
interface
uses System.SysUtils,XmlDoc.Consts,XmlDoc.Model;
type
 TDocIssue=record
  Code,Message,SymbolId,FileName,Fix:string;
  Line,Column:Integer;
 end;
 TDocumentation=class
 public
  class function Analyze(const Element:TCodeElementInfo;Model:TXmlDocModel;const Symbols:TArray<TCodeElementInfo>;const ProjectDir:string='';const PlaceholderPrefix:string='TODO: '):TArray<TDocIssue>;static;
  class procedure Synchronize(const Element:TCodeElementInfo;Model:TXmlDocModel;const Renames:TArray<string>);static;
  class function Meaningful(const Text:string;const PlaceholderPrefix:string='TODO: '):Boolean;static;
 end;
implementation
uses XmlDoc.XmlFragments,System.Generics.Collections,System.RegularExpressions,Xml.XMLIntf,Xml.XMLDoc,System.IOUtils,XmlDoc.SourceText;
class function TDocumentation.Meaningful(const Text:string;const PlaceholderPrefix:string):Boolean;
begin
 var Prefix:=Trim(PlaceholderPrefix);if Prefix='' then Prefix:='TODO:';
 Result:=(Trim(Text)<>'') and not TRegEx.IsMatch(Text,'(?i)\bTODO\b') and
  not TRegEx.IsMatch(Text,'(?i)(?:^|>)[\s]*'+TRegEx.Escape(Prefix));
end;
class function TDocumentation.Analyze(const Element:TCodeElementInfo;Model:TXmlDocModel;const Symbols:TArray<TCodeElementInfo>;const ProjectDir,PlaceholderPrefix:string):TArray<TDocIssue>;
var Issues:TList<TDocIssue>;Names,Seen:TDictionary<string,Boolean>;D:IXMLDocument;
 P:TParamInfo;G:string;I:Integer;PD:TParamDoc;TP:TTypeParamDoc;
 procedure Add(const Code,Message,Fix:string;const Token:string='');
 var Issue:TDocIssue;
 begin Issue:=Default(TDocIssue);Issue.Code:=Code;Issue.Message:=Message;Issue.Fix:=Fix;
  Issue.SymbolId:=Element.SymbolId;Issue.FileName:=Element.FileName;
  Issue.Line:=Element.CommentStartLine;if Issue.Line<1 then Issue.Line:=Element.LineNumber;
  Issue.Column:=Element.IndentLevel+5;
  if Token<>'' then begin
   var Offset:=Pos(Token,Model.SourceXml);if Offset>0 then begin
    var Prefix:=Copy(Model.SourceXml,1,Offset-1);var LastLine:=LastDelimiter(#10,Prefix);
    Inc(Issue.Line,Length(Prefix)-Length(Prefix.Replace(#10,'')));
    Issue.Column:=Element.IndentLevel+5+Length(Prefix)-LastLine;
   end;
  end;
  if (Code='XD001') and (Model.ParseErrorLine>0) then begin Inc(Issue.Line,Model.ParseErrorLine-1);Issue.Column:=Element.IndentLevel+4+Model.ParseErrorColumn;end;
  Issues.Add(Issue);
 end;
 procedure Visit(Node:IXMLNode);
 var N:IXMLNode;J,Count:Integer;PP:TParamInfo;GG:string;Name,Target,Root,FileName,Region:string;S:TCodeElementInfo;Matches:TDictionary<string,Boolean>;
 begin
  for J:=0 to Node.ChildNodes.Count-1 do begin N:=Node.ChildNodes[J];
   if N.NodeType<>ntElement then Continue;
   if (N.NodeName='paramref') or (N.NodeName='typeparamref') then begin
    Name:=N.Attributes['name'];Count:=0;
    if N.NodeName='paramref' then begin for PP in Element.Params do if SameText(PP.Name,Name) then Inc(Count);end
    else for GG in Element.GenericParams do if SameText(GG,Name) then Inc(Count);
    if Count=0 then Add('XD005','Unknown '+N.NodeName+' '+Name,'map-name',Name);
   end;
   if ((N.NodeName='example') and N.HasAttribute('source')) or (((N.NodeName='image') or (N.NodeName='img')) and N.HasAttribute('src')) then begin
    if N.NodeName='example' then Target:=N.Attributes['source'] else Target:=N.Attributes['src'];
    if Element.FileName<>'' then begin
     try FileName:=ResolveDocumentationResource(Target,Element.FileName,ProjectDir);
      if not TFile.Exists(FileName) then Add('XD013','Linked documentation resource does not exist: '+Target,'edit-xml')
      else if N.HasAttribute('region') then begin
       Region:=N.Attributes['region'];var Text:=ReadSourceFile(FileName);
       if not TRegEx.IsMatch(Text,'(?im)\{\$REGION\s+[''" ]*'+TRegEx.Escape(Region)+'[''" ]*\}') then Add('XD013','Linked example region does not exist: '+Region,'edit-xml');
      end;
     except on Ex:Exception do Add('XD013',Ex.Message,'edit-xml');end;
    end;
   end;
   if N.HasAttribute('cref') and (Length(Symbols)>0) then begin
    Target:=N.Attributes['cref'];Matches:=TDictionary<string,Boolean>.Create;
    try
     for S in Symbols do if SameText(S.SymbolId,Target) or SameText(S.FullName,Target) or SameText(S.CanonicalName,Target) or
       SameText(S.Name,Target) or S.FullName.EndsWith('.'+Target,True) then Matches.AddOrSetValue(S.SymbolId,True);
     if Matches.Count=0 then Add('XD006','Unknown reference '+Target,'choose-reference',Target)
     else if Matches.Count>1 then Add('XD007','Ambiguous reference '+Target,'choose-reference',Target);
    finally Matches.Free;end;
   end;
   Visit(N);
  end;
 end;
begin
 Issues:=TList<TDocIssue>.Create;Names:=TDictionary<string,Boolean>.Create;Seen:=TDictionary<string,Boolean>.Create;
 try
  if Model.ParseError<>'' then Add('XD001',Model.ParseError,'edit-xml')
  else begin
   for P in Element.Params do Names.AddOrSetValue(LowerCase(P.Name),True);
   for PD in Model.Params do begin
    if not Names.ContainsKey(LowerCase(PD.Name)) then Add('XD002','Unknown param '+PD.Name,'map-name',PD.Name);
    if Seen.ContainsKey(LowerCase(PD.Name)) then Add('XD003','Duplicate param '+PD.Name,'edit-xml');
    if not Meaningful(PD.Description,PlaceholderPrefix) then Add('XD004','Missing param description '+PD.Name,'edit-description',PD.Name);
    Seen.AddOrSetValue(LowerCase(PD.Name),True);
   end;
   for P in Element.Params do if not Seen.ContainsKey(LowerCase(P.Name)) then Add('XD004','Missing param '+P.Name,'synchronize');
   for TP in Model.TypeParams do if not Meaningful(TP.Description,PlaceholderPrefix) then Add('XD004','Missing typeparam description '+TP.Name,'edit-description',TP.Name);
   for G in Element.GenericParams do begin
    I:=0;for TP in Model.TypeParams do if SameText(TP.Name,G) then Inc(I);
    if I=0 then Add('XD004','Missing typeparam '+G,'synchronize');
    if I>1 then Add('XD003','Duplicate typeparam '+G,'edit-xml');
   end;
   if Trim(Model.Summary)='' then Add('XD000','Missing summary description','edit-description');
   if Model.InheritedFrom.StartsWith('Ambiguous') then Add('XD012',Model.InheritedFrom,'choose-inheritance');
   if not Meaningful(Model.ToXml,PlaceholderPrefix) and (Trim(Model.ToXml)<>'') then Add('XD008','Unfinished placeholder documentation','edit-description');
   if (Model.Returns<>'') and ((Element.Kind<>dekMethod) or (Element.ReturnType='')) then Add('XD009','Returns is not valid for this declaration','edit-xml');
   if (Model.Value<>'') and (Element.Kind<>dekProperty) then Add('XD009','Value is only valid for a property','edit-xml');
   if (Element.Kind=dekUnit) and (Model.Exceptions.Count>0) then Add('XD009','Exceptions are not valid for a unit','edit-xml');
   if (Element.Kind=dekMethod) and (Element.ReturnType<>'') and not Meaningful(Model.Returns,PlaceholderPrefix) then Add('XD010','Missing result description','synchronize');
   if (Element.Kind=dekProperty) and not Meaningful(Model.Value,PlaceholderPrefix) then Add('XD010','Missing property value description','synchronize');
   D:=LoadXMLData('<doc>'+Model.ToXml+'</doc>');Visit(D.DocumentElement);
  end;
  Result:=Issues.ToArray;
 finally Seen.Free;Names.Free;Issues.Free;end;
end;
class procedure TDocumentation.Synchronize(const Element:TCodeElementInfo;Model:TXmlDocModel;const Renames:TArray<string>);
var Pair,OldName,NewName,Xml:string;Parts:TArray<string>;P:TParamInfo;PD:TParamDoc;TP:TTypeParamDoc;
 Ordered:TList<TParamDoc>;OrderedTypes:TList<TTypeParamDoc>;Seen:TDictionary<string,Boolean>;G:string;Found:Boolean;
begin
 if Model.ParseError<>'' then raise Exception.Create('Repair XML before synchronizing');
 // Renames must be explicit and one-to-one. Never infer a rename by position.
 Seen:=TDictionary<string,Boolean>.Create;
 try
  Xml:=Model.ToXml;
  for Pair in Renames do begin
   Parts:=Pair.Split(['=']);if Length(Parts)<>2 then raise Exception.Create('Expected old=new rename mapping');
   OldName:=Trim(Parts[0]);NewName:=Trim(Parts[1]);Found:=False;
   for P in Element.Params do if SameText(P.Name,NewName) then Found:=True;
   for G in Element.GenericParams do if SameText(G,NewName) then Found:=True;
   if not Found or Seen.ContainsKey(LowerCase(NewName)) then raise Exception.Create('Invalid or ambiguous rename mapping');
   Seen.Add(LowerCase(NewName),True);
  end;
  var Map:=TDictionary<string,string>.Create;var Counts:=TDictionary<string,Integer>.Create;var Changed:=TDictionary<string,Boolean>.Create;
  try
   for Pair in Renames do begin Parts:=Pair.Split(['=']);Map.Add(LowerCase(Trim(Parts[0])),Trim(Parts[1]));end;
   for var Kind in ['param','typeparam'] do begin
    Counts.Clear;Changed.Clear;
    var Entries:TArray<string>:=nil;
    if Kind='param' then begin for PD in Model.Params do Entries:=Entries+[PD.Name];end
    else for TP in Model.TypeParams do Entries:=Entries+[TP.Name];
    for OldName in Entries do begin
     if not Map.TryGetValue(LowerCase(OldName),NewName) then NewName:=OldName;
     var N:=0;Counts.TryGetValue(LowerCase(NewName),N);Counts.AddOrSetValue(LowerCase(NewName),N+1);
     if not SameText(OldName,NewName) then Changed.AddOrSetValue(LowerCase(NewName),True);
    end;
    for NewName in Changed.Keys do if Counts[NewName]>1 then raise Exception.Create('Rename conflicts with an existing description; resolve in XML');
   end;
  finally Changed.Free;Counts.Free;Map.Free;end;
  if Length(Renames)>0 then Model.LoadFromXml(RenameDocNames(Xml,Renames));
 finally Seen.Free;end;
 Ordered:=TList<TParamDoc>.Create;OrderedTypes:=TList<TTypeParamDoc>.Create;
 try
  for P in Element.Params do begin
   Found:=False;for PD in Model.Params do if SameText(PD.Name,P.Name) then begin Ordered.Add(PD);Found:=True;end;
   if not Found then begin PD.Name:=P.Name;PD.Description:='';Ordered.Add(PD);end;
  end;
  for PD in Model.Params do begin Found:=False;for P in Element.Params do if SameText(P.Name,PD.Name) then Found:=True;
   if not Found then Ordered.Add(PD);end;
  for G in Element.GenericParams do begin
   Found:=False;for TP in Model.TypeParams do if SameText(TP.Name,G) then begin OrderedTypes.Add(TP);Found:=True;end;
   if not Found then begin TP.Name:=G;TP.Description:='';OrderedTypes.Add(TP);end;
  end;
  for TP in Model.TypeParams do begin Found:=False;for G in Element.GenericParams do if SameText(G,TP.Name) then Found:=True;
   if not Found then OrderedTypes.Add(TP);end;
  Model.Params.Clear;Model.Params.AddRange(Ordered);Model.TypeParams.Clear;Model.TypeParams.AddRange(OrderedTypes);
  if (Element.Kind=dekMethod) and (Element.ReturnType<>'') and (Model.Returns='') then Model.Returns:='TODO: Describe the result.';
  if (Element.Kind=dekProperty) and (Model.Value='') then Model.Value:='TODO: Describe the property value.';
 finally OrderedTypes.Free;Ordered.Free;end;
end;
end.
