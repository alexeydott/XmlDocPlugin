/// <summary>Imports PasDoc descriptions, sidecars, includes and structured tags into XML.</summary>
unit XmlDoc.PasDoc;
interface
uses System.SysUtils,XmlDoc.Consts;
/// <summary>Converts a declaration comment and matching sidecar section to XML without writing source files.</summary>
/// <param name="Text">Comment text without Pascal delimiters.</param>
/// <param name="Element">Declaration identity and signature.</param>
/// <param name="ExternalText">Already loaded same-name text file.</param>
/// <param name="ExternalLoaded">Avoids reading the sidecar again.</param>
/// <param name="ReadFile">Optional snapshot reader which records include dependencies.</param>
/// <returns>XML documentation including expanded file content.</returns>
function ImportLegacyComment(const Text:string;const Element:TCodeElementInfo;
 const ExternalText:string='';ExternalLoaded:Boolean=False;const ReadFile:TFunc<string,string>=nil):string;
/// <summary>Finds a named member/value description inside its owner's PasDoc comment.</summary>
function PasDocMember(const Text,Name:string):string;
implementation
uses System.Classes,System.IOUtils,System.StrUtils,System.RegularExpressions,
 System.Generics.Collections,Xml.XMLIntf,Xml.XMLDoc,XmlDoc.SourceText,XmlDoc.XmlFragments;
type
 TTag=record Name,Body,Raw:string;end;
 TPasDocImport=class
 private
  Element:TCodeElementInfo;
  Reader:TFunc<string,string>;
  Stack:TStringList;
  Summary,Prose,Remarks,Params,Returns,Extras,Headings:string;
  AbstractSet:Boolean;
  ExpandedSize:Integer;
  function ReadInclude(const FileName:string):string;
  function Expand(const S:string;Depth:Integer=0):string;
  function Render(const S:string;Depth:Integer=0):string;
  function RenderList(const Tag,Body:string;Depth:Integer):string;
  function RenderTable(const Body:string;Depth:Integer):string;
  procedure Consume(const S:string;External:Boolean);
 public
  constructor Create(const Info:TCodeElementInfo;const ReadFile:TFunc<string,string>);
  destructor Destroy;override;
 end;
function Escape(const S:string):string;
begin Result:=S.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;');end;
function NoArgs(const Name:string):Boolean;
begin Result:=MatchText(Name,['br','nil','true','false','name','classname','inherited','inheritedclass',
 'exclude','noautolinkhere','tableofcontents']);end;
function RawArgs(const Name:string):Boolean;
begin Result:=MatchText(Name,['html','latex','link','url','longcode','preformatted','includecode']);end;
function KnownTag(const Name:string):Boolean;
begin
 Result:=NoArgs(Name) or RawArgs(Name) or MatchText(Name,['include','abstract','param','return','returns','raises','seealso',
 'author','created','lastmod','cvs','deprecated','member','value','bold','italic','code','orderedlist','unorderedlist',
 'definitionlist','item','itemlabel','itemspacing','itemsetnumber','table','row','rowhead','cell','title','shorttitle',
 'section','anchor','note','warning','noautolink','image']);
end;
function NextTag(const S:string;var I:Integer;out Tag:TTag):Boolean;
var Start,BodyStart,Level:Integer;
begin
 Result:=False;Tag:=Default(TTag);if (I>Length(S)) or (S[I]<>'@') then Exit;
 Start:=I;Inc(I);if I>Length(S) then begin Tag.Raw:='@';Result:=True;Exit;end;
 if CharInSet(S[I],['@','(',')','-']) then begin Tag.Name:=S[I];Inc(I);end
 else begin
  BodyStart:=I;while (I<=Length(S)) and CharInSet(S[I],['a'..'z','A'..'Z']) do Inc(I);
  Tag.Name:=LowerCase(Copy(S,BodyStart,I-BodyStart));
  // Email/domain text must not turn a known macro name into a directive.
  if (Start>1) and not CharInSet(S[Start-1],[' ',#9,#10,#13,'@','(']) and
     (I<=Length(S)) and (S[I]='.') then begin
    while (I<=Length(S)) and not CharInSet(S[I],[' ',#9,#10,#13,'(',')',',',';']) do Inc(I);
    Tag.Name:='';Tag.Raw:=Copy(S,Start,I-Start);Result:=True;Exit;
  end;
  if Tag.Name='' then begin Tag.Raw:='@';Result:=True;Exit;end;
  if (I<=Length(S)) and (S[I]='(') then begin
   Inc(I);BodyStart:=I;Level:=1;
   while (I<=Length(S)) and (Level>0) do begin
    if not RawArgs(Tag.Name) and (S[I]='@') and (I<Length(S)) and CharInSet(S[I+1],['@','(',')']) then Inc(I)
    else if S[I]='(' then Inc(Level) else if S[I]=')' then Dec(Level);
    if Level>0 then Inc(I);
   end;
   if Level<>0 then raise EConvertError.CreateFmt('Unterminated PasDoc @%s at character %d',[Tag.Name,Start]);
   Tag.Body:=Copy(S,BodyStart,I-BodyStart);Inc(I);
  end else if not NoArgs(Tag.Name) then begin
   while (I<=Length(S)) and CharInSet(S[I],[' ',#9,':']) do Inc(I);
   BodyStart:=I;
   while I<=Length(S) do begin
    if CharInSet(S[I],[#10,#13]) then begin
     if (I>BodyStart) and (S[I-1]='\') then begin
      Tag.Body:=Tag.Body+Copy(S,BodyStart,I-BodyStart-1)+' ';
      if (S[I]=#13) and (I<Length(S)) and (S[I+1]=#10) then Inc(I);
      Inc(I);BodyStart:=I;Continue;
     end;
     Break;
    end;
    Inc(I);
   end;
   Tag.Body:=Tag.Body+Copy(S,BodyStart,I-BodyStart);
  end;
 end;
 Tag.Raw:=Copy(S,Start,I-Start);Result:=True;
end;
function SplitName(const S:string;out Rest:string):string;
var I:Integer;
begin
 I:=1;while (I<=Length(S)) and not CharInSet(S[I],[' ',#9,#10,#13]) do Inc(I);
 Result:=Copy(S,1,I-1);Rest:=Copy(S,I+1,MaxInt).Trim;
end;
constructor TPasDocImport.Create(const Info:TCodeElementInfo;const ReadFile:TFunc<string,string>);
begin inherited Create;Element:=Info;Reader:=ReadFile;Stack:=TStringList.Create;Stack.CaseSensitive:=False;end;
destructor TPasDocImport.Destroy;
begin Stack.Free;inherited;end;
function TPasDocImport.ReadInclude(const FileName:string):string;
var Path:string;
begin
 Path:=TPath.GetFullPath(TPath.Combine(ExtractFilePath(Element.FileName),FileName.Trim.Trim(['"'])));
 if Assigned(Reader) then Result:=Reader(Path)
 else begin
  if not TFile.Exists(Path) then raise EFileNotFoundException.Create('PasDoc include file not found: '+Path);
  Result:=ReadSourceFile(Path);
 end;
 Inc(ExpandedSize,Length(Result));
 if ExpandedSize>4*1024*1024 then raise EConvertError.Create('PasDoc includes exceed 4 MiB: '+Path);
end;
function TPasDocImport.Expand(const S:string;Depth:Integer):string;
var I,Start:Integer;Tag:TTag;Path,Content:string;
begin
 if Depth>32 then raise EConvertError.Create('PasDoc nesting exceeds 32 levels: '+Element.FileName);
 Result:='';I:=1;
 while I<=Length(S) do begin
  if S[I]<>'@' then begin Result:=Result+S[I];Inc(I);Continue;end;
  Start:=I;NextTag(S,I,Tag);
  if Tag.Name='include' then begin
   Path:=TPath.GetFullPath(TPath.Combine(ExtractFilePath(Element.FileName),Tag.Body.Trim.Trim(['"'])));
   if Stack.IndexOf(Path)>=0 then raise EConvertError.Create('Cyclic PasDoc @include: '+Path);
   Stack.Add(Path);
   try Content:=ReadInclude(Tag.Body);Result:=Result+Expand(Content,Depth+1);finally Stack.Delete(Stack.Count-1);end;
  end else if (Tag.Body<>'') and KnownTag(Tag.Name) and not RawArgs(Tag.Name) then begin
   // Expand includes inside structured arguments before interpreting their tags.
   Content:=Expand(Tag.Body,Depth+1);
   if Content=Tag.Body then Result:=Result+Tag.Raw else Result:=Result+'@'+Tag.Name+'('+Content+')';
  end else Result:=Result+Copy(S,Start,I-Start);
 end;
end;
function SafeHTML(const S:string):string;
var Doc:IXMLDocument;Text:string;
 function CopyNode(N:IXMLNode):string;
 var Name,Tag,Content:string;
 begin
  if N.NodeType in [ntText,ntCData] then Exit(Escape(N.Text));
  Result:='';if N.NodeType<>ntElement then Exit;Name:=LowerCase(N.NodeName);
  if MatchText(Name,['script','style','iframe','object','embed','head']) then Exit;
  Content:='';for var I:=0 to N.ChildNodes.Count-1 do Content:=Content+CopyNode(N.ChildNodes[I]);
  Tag:=Name;if MatchText(Name,['p','div']) then Tag:='para'
  else if Name='strong' then Tag:='b' else if Name='em' then Tag:='i'
  else if Name='pre' then Exit('<code>'+Escape(N.Text)+'</code>')
  else if Name='code' then Tag:='c';
  if (Name='img') and N.HasAttribute('src') then Exit('<image src="'+Escape(N.Attributes['src'])+'"/>');
  if Name='a' then begin
   if N.HasAttribute('href') then Exit('<see href="'+Escape(N.Attributes['href'])+'">'+Content+'</see>');
   if N.HasAttribute('id') then Exit('<a id="'+Escape(N.Attributes['id'])+'">'+Content+'</a>');
  end;
  if MatchText(Tag,['para','b','i','c','table','tr','td','th','thead','tbody','ul','ol','li','u']) then Exit('<'+Tag+'>'+Content+'</'+Tag+'>');
  if Tag='br' then Exit('<br/>');Result:=Content;
 end;
begin
 Text:=TRegEx.Replace(S,'(?i)<(br|hr|img)(\b[^>]*?)(?<!/)>','<$1$2/>').Replace('&nbsp;','&#160;');
 try
  Doc:=LoadDocXml('<doc>'+Text+'</doc>');Result:=CopyNode(Doc.DocumentElement);
 except on E:Exception do raise EConvertError.Create('Invalid PasDoc @html: '+E.Message);end;
end;
function TPasDocImport.RenderList(const Tag,Body:string;Depth:Integer):string;
var I,Number,NextNumber:Integer;T:TTag;LabelText,Items,Kind,Spacing,Attrs:string;
 procedure Item(const Description:string);
 begin
  Attrs:='';if Tag='orderedlist' then Attrs:=' number="'+IntToStr(Number)+'"';
  Items:=Items+'<item'+Attrs+'>';
  if LabelText<>'' then Items:=Items+'<term>'+LabelText+'</term>';
  Items:=Items+'<description>'+Description+'</description></item>';LabelText:='';Inc(Number);
 end;
begin
 I:=1;Number:=1;Items:='';LabelText:='';Spacing:='';Kind:='bullet';
 if Tag='orderedlist' then Kind:='number' else if Tag='definitionlist' then Kind:='table';
 while I<=Length(Body) do begin
  if Body[I]<>'@' then begin Inc(I);Continue;end;
  NextTag(Body,I,T);
  if T.Name='itemlabel' then begin if LabelText<>'' then Item('');LabelText:=Render(T.Body,Depth+1);end
  else if T.Name='item' then Item(Render(T.Body,Depth+1))
  else if T.Name='itemspacing' then begin
   if not MatchText(T.Body.Trim,['compact','paragraph']) then raise EConvertError.Create('Invalid PasDoc @itemSpacing: '+T.Body);
   Spacing:=' spacing="'+LowerCase(T.Body.Trim)+'"';
  end else if T.Name='itemsetnumber' then begin
   if not TryStrToInt(T.Body.Trim,NextNumber) then raise EConvertError.Create('Invalid PasDoc @itemSetNumber: '+T.Body);
   Number:=NextNumber;
  end;
 end;
 if LabelText<>'' then Item('');Result:='<list type="'+Kind+'"'+Spacing+'>'+Items+'</list>';
end;
function TPasDocImport.RenderTable(const Body:string;Depth:Integer):string;
var I,J:Integer;Row,Cell:TTag;CellName,Cells:string;
begin
 Result:='<table>';I:=1;
 while I<=Length(Body) do begin
  if Body[I]<>'@' then begin Inc(I);Continue;end;NextTag(Body,I,Row);
  if not MatchText(Row.Name,['row','rowhead']) then Continue;
  CellName:='td';if Row.Name='rowhead' then CellName:='th';J:=1;Cells:='';
  while J<=Length(Row.Body) do begin
   if Row.Body[J]<>'@' then begin Inc(J);Continue;end;NextTag(Row.Body,J,Cell);
   if Cell.Name='cell' then Cells:=Cells+'<'+CellName+'>'+Render(Cell.Body,Depth+1)+'</'+CellName+'>';
  end;
  Result:=Result+'<tr>'+Cells+'</tr>';
 end;Result:=Result+'</table>';
end;
function TPasDocImport.Render(const S:string;Depth:Integer):string;
var I:Integer;Tag:TTag;Value,Target,Caption,Content,ID:string;
begin
 if Depth>32 then raise EConvertError.Create('PasDoc nesting exceeds 32 levels: '+Element.FileName);
 Result:='';I:=1;
 while I<=Length(S) do begin
  if S[I]<>'@' then begin Result:=Result+Escape(S[I]);Inc(I);Continue;end;
  NextTag(S,I,Tag);Value:='';
  if Tag.Name='' then Value:=Escape(Tag.Raw)
  else if MatchText(Tag.Name,['@','(',')','-']) then Value:=Tag.Name
  else if not KnownTag(Tag.Name) then Value:=Escape(Tag.Raw)
  else if MatchText(Tag.Name,['longcode','preformatted','latex']) then Value:='<code>'+Escape(Tag.Body)+'</code>'
  else if Tag.Name='html' then Value:=SafeHTML(Tag.Body)
  else if Tag.Name='includecode' then begin
   if Tag.Body.Trim='' then raise EConvertError.Create('PasDoc @includeCode requires a file name');
   Content:='';for var FileName in TRegEx.Matches(Tag.Body,'"[^"]+"|\S+') do begin
    if Content<>'' then Content:=Content+#10;Content:=Content+ReadInclude(FileName.Value);
   end;
   Value:='<code>'+Escape(Content)+'</code>';
  end else if MatchText(Tag.Name,['orderedlist','unorderedlist','definitionlist']) then Value:=RenderList(Tag.Name,Tag.Body,Depth)
  else if Tag.Name='table' then Value:=RenderTable(Tag.Body,Depth)
  else if MatchText(Tag.Name,['link','url']) then begin
   Target:=SplitName(Tag.Body.Trim,Caption);
   if Tag.Name='url' then Value:='<see href="'+Escape(Target)+'"' else Value:='<see cref="'+Escape(Target)+'"';
   if Caption='' then Value:=Value+'/>' else Value:=Value+'>'+Escape(Caption)+'</see>';
  end else if Tag.Name='image' then Value:='<image src="'+Escape(Tag.Body.Trim)+'"/>'
  else if Tag.Name='br' then Value:='<br/>'
  else if MatchText(Tag.Name,['nil','true','false']) then Value:='<c>'+Tag.Name+'</c>'
  else if Tag.Name='name' then Value:=Escape(Element.Name)
  else if Tag.Name='classname' then begin
   if Element.Kind in [dekClass,dekInterface,dekRecord] then Value:=Escape(Element.FullName) else Value:=Escape(Element.QualifiedParent);
  end else if Tag.Name='inheritedclass' then Value:=Escape(Element.Ancestor)
  else if Tag.Name='inherited' then begin Value:=Element.Ancestor;if (Value<>'') and not (Element.Kind in [dekClass,dekInterface,dekRecord]) then Value:=Value+'.'+Element.Name;Value:=Escape(Value);end
  else if Tag.Name='anchor' then Value:='<a id="'+Escape(Tag.Body.Trim)+'"/>'
  else if Tag.Name='tableofcontents' then Value:='<pasdoc-toc/>'
  else if Tag.Name='exclude' then begin Extras:=Extras+'<exclude/>';Value:='';end
  else if Tag.Name='noautolinkhere' then Value:=''
  else begin
   Value:=Render(Tag.Body,Depth+1);
   if Tag.Name='bold' then Value:='<b>'+Value+'</b>'
   else if Tag.Name='italic' then Value:='<i>'+Value+'</i>'
   else if Tag.Name='code' then Value:='<c>'+Value+'</c>'
   else if MatchText(Tag.Name,['title','shorttitle','section']) then begin
    Caption:=Tag.Body;ID:='';if Tag.Name='section' then ID:=SplitName(Tag.Body.Trim,Caption);
    if ID='' then ID:='section'+IntToStr(Length(Headings));
    Value:=Render(Caption,Depth+1);
    Headings:=Headings+'<item><description><see href="#'+Escape(ID)+'">'+Value+'</see></description></item>';
    Value:='<para><a id="'+Escape(ID)+'"/><b>'+Value+'</b></para>';
   end else if MatchText(Tag.Name,['note','warning','author','created','lastmod','cvs','deprecated']) then
    Value:='<para><b>'+Tag.Name+': </b>'+Value+'</para>'
   else if MatchText(Tag.Name,['noautolink','abstract','item','cell','row','rowhead']) then Value:=Value
   else Value:='<para><b>@'+Escape(Tag.Name)+': </b>'+Value+'</para>';
  end;
  Result:=Result+Value;
 end;
end;
procedure TPasDocImport.Consume(const S:string;External:Boolean);
var I,Start:Integer;Tag:TTag;Text,Name,Description,Value:string;
 procedure FlushProse;
 begin
  if Text.Trim<>'' then begin
   Value:=Render(Text.Trim);
   if External and (AbstractSet or (Summary<>'')) then begin if Remarks<>'' then Remarks:=Remarks+#10;Remarks:=Remarks+Value;end
   else begin if Prose<>'' then Prose:=Prose+#10;Prose:=Prose+Value;end;
  end;Text:='';
 end;
begin
 Text:='';I:=1;
 while I<=Length(S) do begin
  if S[I]<>'@' then begin Text:=Text+S[I];Inc(I);Continue;end;
  Start:=I;NextTag(S,I,Tag);
  if not MatchText(Tag.Name,['abstract','param','return','returns','raises','seealso','author','created','lastmod','cvs','deprecated','member','value','exclude']) then begin
   Text:=Text+Copy(S,Start,I-Start);Continue;
  end;
  FlushProse;
  if Tag.Name='abstract' then begin if not AbstractSet then begin Summary:=Render(Tag.Body.Trim);AbstractSet:=True;end;end
  else if Tag.Name='param' then begin
   Name:=SplitName(Tag.Body.Trim,Description);
   for var Param in Element.Params do if SameText(Param.Name,Name) then begin
    if not Params.Contains('<param name="'+Escape(Param.Name)+'">') then Params:=Params+'<param name="'+Escape(Param.Name)+'">'+Render(Description)+'</param>';
    Break;
   end;
  end else if MatchText(Tag.Name,['return','returns']) then begin if Returns='' then Returns:=Render(Tag.Body.Trim);end
  else if Tag.Name='raises' then begin
   Name:=SplitName(Tag.Body.Trim,Description);if Name<>'' then Extras:=Extras+'<exception cref="'+Escape(Name)+'">'+Render(Description)+'</exception>';
  end else if Tag.Name='seealso' then begin
   Name:=SplitName(Tag.Body.Trim,Description);Extras:=Extras+'<seealso cref="'+Escape(Name)+'">'+Render(Description)+'</seealso>';
  end else if Tag.Name='exclude' then Extras:=Extras+'<exclude/>'
  else if MatchText(Tag.Name,['member','value']) then begin
   Name:=SplitName(Tag.Body.Trim,Description);Value:=Render(Description);
   Extras:=Extras+'<pasdoc-member name="'+Escape(Name)+'">'+Value+'</pasdoc-member>';
   Remarks:=Remarks+'<list type="table"><item><term>'+Escape(Name)+'</term><description>'+Value+'</description></item></list>';
  end else begin
   if Remarks<>'' then Remarks:=Remarks+#10;Remarks:=Remarks+Render(Tag.Raw);
  end;
 end;
 FlushProse;
end;
function PasDocMember(const Text,Name:string):string;
var I:Integer;Tag:TTag;MemberName,Description:string;
begin
 Result:='';I:=1;
 while I<=Length(Text) do begin
  if Text[I]<>'@' then begin Inc(I);Continue;end;NextTag(Text,I,Tag);
  if MatchText(Tag.Name,['member','value']) then begin MemberName:=SplitName(Tag.Body.Trim,Description);if SameText(MemberName,Name) then Exit(Description);end;
 end;
end;
function ImportLegacyComment(const Text:string;const Element:TCodeElementInfo;const ExternalText:string;
 ExternalLoaded:Boolean;const ReadFile:TFunc<string,string>):string;
var Import:TPasDocImport;Sidecar,Selected,Key,Line,ExternalContent:string;Active:Boolean;
begin
 Import:=TPasDocImport.Create(Element,ReadFile);
 try
  Import.Consume(Import.Expand(Text),False);
  Sidecar:=ChangeFileExt(Element.FileName,'.txt');
  ExternalContent:=ExternalText;
  if not ExternalLoaded and (Element.FileName<>'') and TFile.Exists(Sidecar) then begin
   if Assigned(ReadFile) then ExternalContent:=ReadFile(Sidecar) else ExternalContent:=ReadSourceFile(Sidecar);
  end;
  Key:=Element.UnitName+'.'+Element.FullName;Selected:='';Active:=False;
  for Line in ExternalContent.Replace(#13,'').Split([#10]) do begin
   if Line.Trim.StartsWith('#') then begin
    if Active then Break;Active:=SameText(Line.Trim.TrimLeft(['#',' ']),Key);
   end else if Active then Selected:=Selected+Line+#10;
  end;
  if Active then begin
   if not Import.AbstractSet and (Import.Prose<>'') then begin
    Import.Summary:=Import.Prose;Import.Prose:='';Import.AbstractSet:=True;
   end;
   Import.Consume(Import.Expand(Selected),True);
  end;
  if not Import.AbstractSet then begin Import.Summary:=Import.Prose;Import.Prose:='';end;
  if Import.Prose<>'' then Import.Remarks:=Import.Prose+#10+Import.Remarks;
  Result:='';if Import.Summary<>'' then Result:='<summary>'+Import.Summary+'</summary>';
  if Import.Remarks.Trim<>'' then Result:=Result+'<remarks>'+Import.Remarks.Trim+'</remarks>';
  Result:=Result+Import.Params+Import.Extras;
  if Import.Returns<>'' then Result:=Result+'<returns>'+Import.Returns+'</returns>';
  Result:=Result.Replace('<pasdoc-toc/>','<list type="bullet">'+Import.Headings+'</list>');
 finally Import.Free;end;
end;
end.
