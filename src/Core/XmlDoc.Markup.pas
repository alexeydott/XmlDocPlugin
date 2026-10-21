/// <summary>Documentation markup conversion and safe rendering helpers.</summary>
unit XmlDoc.Markup;
interface
uses System.SysUtils;
type TMarkupLink=TFunc<string,string>;
function MarkupHTML(const Text:string;const Link:TMarkupLink=nil;const Image:TMarkupLink=nil):string;
function MarkupMarkdown(const Text:string;const Link:TMarkupLink=nil;const Image:TMarkupLink=nil):string;
function MarkupPlainText(const Text:string):string;
implementation
uses Xml.XMLIntf,Xml.XMLDoc,System.StrUtils,XmlDoc.XmlFragments;
function MarkupPlainText(const Text:string):string;
var Doc:IXMLDocument;
 function Render(Node:IXMLNode):string;
 begin
  if Node.NodeType in [ntText,ntCData] then Exit(Node.Text);
  Result:='';if Node.NodeType<>ntElement then Exit;
  for var I:=0 to Node.ChildNodes.Count-1 do Result:=Result+Render(Node.ChildNodes[I]);
  if MatchText(Node.NodeName,['paramref','typeparamref']) and Node.HasAttribute('name') then Result:=Node.Attributes['name'];
  if SameText(Node.NodeName,'see') and (Result='') and Node.HasAttribute('cref') then Result:=Node.Attributes['cref'];
  if MatchText(Node.NodeName,['para','br','item','code']) then Result:=Result+#10;
 end;
begin
 try Doc:=LoadDocXml('<doc>'+Text+'</doc>');Result:=Trim(Render(Doc.DocumentElement));except Result:=Text;end;
end;
function Escape(const S:string):string;
begin Result:=S.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;');end;
function SafeHref(const S:string):Boolean;
var Value:string;
begin
 Value:=LowerCase(Trim(S));
 Result:=(Pos(':',Value)=0) or Value.StartsWith('https:') or Value.StartsWith('http:') or Value.StartsWith('mailto:');
 for var Ch in Value do if Ord(Ch)<32 then Exit(False);
end;
function MarkupHTML(const Text:string;const Link:TMarkupLink;const Image:TMarkupLink):string;
var Doc:IXMLDocument;
 function Render(Node:IXMLNode):string;
 var I:Integer;Name,Content,Tag,Target:string;N:IXMLNode;
 begin
  if Node.NodeType in [ntText,ntCData] then Exit(Escape(Node.Text));
  if Node.NodeType<>ntElement then Exit('');Name:=LowerCase(Node.NodeName);Content:='';
  if (Name='image') or (Name='img') then begin Target:='';if Node.HasAttribute('src') then Target:=Node.Attributes['src'];if Assigned(Image) then Exit('<img src="'+Escape(Image(Target))+'" alt="'+Escape(Node.Text)+'">');Exit(Escape(Node.Text));end;
  if Name='code' then begin if Node.Text='' then Exit('');Exit('<pre><code>'+Escape(Node.Text)+'</code></pre>');end;
  for I:=0 to Node.ChildNodes.Count-1 do Content:=Content+Render(Node.ChildNodes[I]);
  if (Content='') and MatchText(Name,['b','strong','i','em','c','list']) then Exit('');
  if (Name='paramref') or (Name='typeparamref') then begin if Node.HasAttribute('name') then Content:=Escape(Node.Attributes['name']);Exit('<strong>'+Content+'</strong>');end;
  if (Name='see') and Node.HasAttribute('href') then begin
   Target:=Node.Attributes['href'];if Content='' then Content:=Escape(Target);
   if SafeHref(Target) then Exit('<a href="'+Escape(Target)+'">'+Content+'</a>');Exit(Content);
  end;
  if (Name='a') and Node.HasAttribute('id') then Exit('<a id="'+Escape(Node.Attributes['id'])+'">'+Content+'</a>');
  if MatchText(Name,['table','tr','td','th','thead','tbody','ul','ol','li','u']) then Exit('<'+Name+'>'+Content+'</'+Name+'>');
  if Name='see' then begin Target:='';if Node.HasAttribute('cref') then Target:=Node.Attributes['cref'];
   if Assigned(Link) then begin Result:=Link(Target);if Content<>'' then begin var P:=Pos('>',Result);var Q:=Pos('</a>',Result);if (P>0) and (Q>P) then Result:=Copy(Result,1,P)+Content+'</a>' else Result:=Content;end;Exit;end;if Content='' then Content:=Escape(Target);Exit('<code>'+Content+'</code>');end;
  if (Name='b') or (Name='strong') then Exit('<strong>'+Content+'</strong>');
  if (Name='i') or (Name='em') then Exit('<em>'+Content+'</em>');
  if Name='c' then Exit('<code>'+Content+'</code>');if Name='br' then Exit('<br>');
  if Name='para' then Exit('<p>'+Content+'</p>');
  if Name='list' then begin Tag:='ul';if Node.HasAttribute('type') then begin
   if SameText(Node.Attributes['type'],'number') then Tag:='ol';
   if SameText(Node.Attributes['type'],'table') then begin
    Content:='';for I:=0 to Node.ChildNodes.Count-1 do begin N:=Node.ChildNodes[I];if N.NodeType=ntElement then Content:=Content+'<tr>'+Render(N)+'</tr>';end;
    Exit('<table>'+Content+'</table>');
   end;
  end;Exit('<'+Tag+'>'+Content+'</'+Tag+'>');end;
  if Name='item' then begin if Assigned(Node.ParentNode) and Node.ParentNode.HasAttribute('type') and SameText(Node.ParentNode.Attributes['type'],'table') then Exit(Content);begin var Number:Integer;if Node.HasAttribute('number') and TryStrToInt(Node.Attributes['number'],Number) then Exit('<li value="'+IntToStr(Number)+'">'+Content+'</li>');Exit('<li>'+Content+'</li>');end;end;
  if (Name='term') or (Name='description') then begin
   if Assigned(Node.ParentNode) and Assigned(Node.ParentNode.ParentNode) and Node.ParentNode.ParentNode.HasAttribute('type') and SameText(Node.ParentNode.ParentNode.Attributes['type'],'table') then begin
    Tag:='td';if Node.ParentNode.NodeName='listheader' then Tag:='th';Exit('<'+Tag+'>'+Content+'</'+Tag+'>');end;
   if Name='term' then Exit('<strong>'+Content+'</strong> ');Exit(Content);
  end;
  // Unknown nodes remain in the saved XML, but cannot inject HTML or script.
  Result:=Content;
 end;
begin
 if HasForbiddenDeclarations(Text) then Exit(Escape(Text));
 try Doc:=LoadDocXml('<doc>'+Text+'</doc>');except Exit(Escape(Text));end;
 Result:=Render(Doc.DocumentElement);
end;
function MarkupMarkdown(const Text:string;const Link:TMarkupLink;const Image:TMarkupLink):string;
var Doc:IXMLDocument;
 function Render(Node:IXMLNode):string;
 var I,N:Integer;Name,Content,Fence,Line,Header,Rows,Term,Description,Prefix:string;
 begin
  if Node.NodeType in [ntText,ntCData] then begin
   Result:=Node.Text;for var Ch in TArray<string>.Create('\','*','_','[',']','<','>') do Result:=Result.Replace(Ch,'\'+Ch);Exit;
  end;
  if Node.NodeType<>ntElement then Exit('');Name:=LowerCase(Node.NodeName);Content:='';
  if (Name='image') or (Name='img') then begin if Assigned(Image) and Node.HasAttribute('src') then Exit('![]('+Image(Node.Attributes['src'])+')');Exit('');end;
  if (Name='code') or (Name='c') then begin
   if Node.Text='' then Exit('');
   Fence:='`';while Pos(Fence,Node.Text)>0 do Fence:=Fence+'`';
   if Name='code' then begin while Length(Fence)<3 do Fence:=Fence+'`';Exit(sLineBreak+Fence+'pascal'+sLineBreak+Node.Text+sLineBreak+Fence+sLineBreak);end;
   Exit(Fence+' '+Node.Text+' '+Fence);
  end;
  for I:=0 to Node.ChildNodes.Count-1 do Content:=Content+Render(Node.ChildNodes[I]);
  if (Content='') and ((Name='b') or (Name='strong') or (Name='i') or (Name='em') or (Name='para')) then Exit('');
  if (Name='b') or (Name='strong') then Exit('**'+Content+'**');
  if (Name='i') or (Name='em') then Exit('*'+Content+'*');
  if Name='br' then Exit('  '+sLineBreak);
  if Name='para' then Exit(Content+sLineBreak+sLineBreak);
  if (Name='paramref') or (Name='typeparamref') then begin if Node.HasAttribute('name') then Content:=Node.Attributes['name'];Exit('`'+Content+'`');end;
  if (Name='see') and Node.HasAttribute('href') then begin
   var Target:string:=Node.Attributes['href'];if Content='' then Content:=Target;
   if SafeHref(Target) then Exit('['+Content+']('+Target.Replace(' ','%20')+')');Exit(Content);
  end;
  if (Name='a') and Node.HasAttribute('id') then Exit('<a id="'+Escape(Node.Attributes['id'])+'"></a>'+Content);
  if Name='table' then begin
   var RowsText:string:='';var HeaderText:string:='';var Divider:string:='';
   for var RowIndex:=0 to Node.ChildNodes.Count-1 do begin
    var RowNode:=Node.ChildNodes[RowIndex];if not SameText(RowNode.NodeName,'tr') then Continue;
    var RowText:string:='|';var RowDivider:string:='|';
    for var CellIndex:=0 to RowNode.ChildNodes.Count-1 do begin
     var CellNode:=RowNode.ChildNodes[CellIndex];if not MatchText(CellNode.NodeName,['td','th']) then Continue;
     RowText:=RowText+' '+Trim(Render(CellNode)).Replace('|','\|').Replace(#10,' ')+' |';RowDivider:=RowDivider+' --- |';
    end;
    if HeaderText='' then begin HeaderText:=RowText;Divider:=RowDivider;end
    else RowsText:=RowsText+RowText+sLineBreak;
   end;
   Exit(sLineBreak+HeaderText+sLineBreak+Divider+sLineBreak+RowsText+sLineBreak);
  end;
  if Name='see' then begin
   if Assigned(Link) and Node.HasAttribute('cref') then begin
    Result:=Link(Node.Attributes['cref']);I:=Pos('](',Result);
    if (Content<>'') and (I>0) and Result.StartsWith('[') then Result:='['+Content+Copy(Result,I,MaxInt)
    else if Content<>'' then Result:=Content;Exit;
   end;
   if (Content='') and Node.HasAttribute('cref') then Content:=Node.Attributes['cref'];Exit('`'+Content+'`');
  end;
  if (Name='list') and Node.HasAttribute('type') and SameText(Node.Attributes['type'],'table') then begin
   Header:='| Term | Description |';Rows:='';
   for I:=0 to Node.ChildNodes.Count-1 do if Node.ChildNodes[I].NodeType=ntElement then begin
    Term:='';Description:='';for var J:=0 to Node.ChildNodes[I].ChildNodes.Count-1 do begin
     var Cell:=Node.ChildNodes[I].ChildNodes[J];Line:=Trim(Render(Cell));
     Line:=Line.Replace('|','\|').Replace(#13#10,' ').Replace(#10,' ').Replace(#13,' ');
     if SameText(Cell.NodeName,'term') then Term:=Line else if SameText(Cell.NodeName,'description') then Description:=Line;
    end;
    Line:='| '+Term+' | '+Description+' |';
    if SameText(Node.ChildNodes[I].NodeName,'listheader') then Header:=Line else Rows:=Rows+Line+sLineBreak;
   end;
   Exit(sLineBreak+Header+sLineBreak+'| --- | --- |'+sLineBreak+Rows+sLineBreak);
  end;
  if Name='item' then begin
   Prefix:='- ';if Assigned(Node.ParentNode) and Node.ParentNode.HasAttribute('type') and SameText(Node.ParentNode.Attributes['type'],'number') then begin
    N:=0;for I:=0 to Node.ParentNode.ChildNodes.Count-1 do begin
     var Item:=Node.ParentNode.ChildNodes[I];if Item.NodeName<>'item' then Continue;Inc(N);
     if Item.HasAttribute('number') then TryStrToInt(Item.Attributes['number'],N);if Item=Node then Break;
    end;Prefix:=N.ToString+'. ';
   end;
   Result:='';for Line in Trim(Content).Replace(#13#10,#10).Split([#10]) do begin if Result='' then Result:=Prefix+Line else Result:=Result+sLineBreak+StringOfChar(' ',Length(Prefix))+Line;end;Exit(Result+sLineBreak);
  end;
  if Name='term' then Exit('**'+Content+'** ');
  Result:=Content;
 end;
begin
 try Doc:=LoadDocXml('<doc>'+Text+'</doc>');except Exit(Text);end;
 Result:=Render(Doc.DocumentElement);
end;
end.
