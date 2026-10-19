/// <summary>Documentation markup conversion and safe rendering helpers.</summary>
unit XmlDoc.Markup;
interface
uses System.SysUtils;
type TMarkupLink=TFunc<string,string>;
function MarkupHTML(const Text:string;const Link:TMarkupLink=nil;const Image:TMarkupLink=nil):string;
function MarkupMarkdown(const Text:string;const Link:TMarkupLink=nil;const Image:TMarkupLink=nil):string;
implementation
uses Xml.XMLIntf,Xml.XMLDoc,System.StrUtils,XmlDoc.XmlFragments;
function Escape(const S:string):string;
begin Result:=S.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;');end;
function MarkupHTML(const Text:string;const Link:TMarkupLink;const Image:TMarkupLink):string;
var Doc:IXMLDocument;
 function Render(Node:IXMLNode):string;
 var I:Integer;Name,Content,Tag,Target:string;N:IXMLNode;
 begin
  if Node.NodeType in [ntText,ntCData] then Exit(Escape(Node.Text));
  if Node.NodeType<>ntElement then Exit('');Name:=LowerCase(Node.NodeName);Content:='';
  if (Name='image') or (Name='img') then begin Target:='';if Node.HasAttribute('src') then Target:=Node.Attributes['src'];if Assigned(Image) then Exit('<img src="'+Escape(Image(Target))+'" alt="'+Escape(Node.Text)+'">');Exit(Escape(Node.Text));end;
  if Name='code' then Exit('<pre><code>'+Escape(Node.Text)+'</code></pre>');
  for I:=0 to Node.ChildNodes.Count-1 do Content:=Content+Render(Node.ChildNodes[I]);
  if (Name='paramref') or (Name='typeparamref') then begin if Node.HasAttribute('name') then Content:=Escape(Node.Attributes['name']);Exit('<strong>'+Content+'</strong>');end;
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
  if Name='item' then begin if Assigned(Node.ParentNode) and Node.ParentNode.HasAttribute('type') and SameText(Node.ParentNode.Attributes['type'],'table') then Exit(Content);Exit('<li>'+Content+'</li>');end;
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
 var I:Integer;Name,Content,Fence,Line:string;
 begin
  if Node.NodeType in [ntText,ntCData] then begin
   Result:=Node.Text;for var Ch in TArray<string>.Create('\','*','_','[',']','<','>') do Result:=Result.Replace(Ch,'\'+Ch);Exit;
  end;
  if Node.NodeType<>ntElement then Exit('');Name:=LowerCase(Node.NodeName);Content:='';
  if (Name='image') or (Name='img') then begin if Assigned(Image) and Node.HasAttribute('src') then Exit('![]('+Image(Node.Attributes['src'])+')');Exit('');end;
  if (Name='code') or (Name='c') then begin
   Fence:='`';while Pos(Fence,Node.Text)>0 do Fence:=Fence+'`';
   if Name='code' then begin while Length(Fence)<3 do Fence:=Fence+'`';Exit(sLineBreak+Fence+'pascal'+sLineBreak+Node.Text+sLineBreak+Fence+sLineBreak);end;
   Exit(Fence+' '+Node.Text+' '+Fence);
  end;
  for I:=0 to Node.ChildNodes.Count-1 do Content:=Content+Render(Node.ChildNodes[I]);
  if (Name='b') or (Name='strong') then Exit('**'+Content+'**');
  if (Name='i') or (Name='em') then Exit('*'+Content+'*');
  if Name='br' then Exit('  '+sLineBreak);
  if Name='para' then Exit(Content+sLineBreak+sLineBreak);
  if (Name='paramref') or (Name='typeparamref') then begin if Node.HasAttribute('name') then Content:=Node.Attributes['name'];Exit('`'+Content+'`');end;
  if Name='see' then begin if Assigned(Link) and Node.HasAttribute('cref') then Exit(Link(Node.Attributes['cref']));if (Content='') and Node.HasAttribute('cref') then Content:=Node.Attributes['cref'];Exit('`'+Content+'`');end;
  if Name='item' then begin
   Result:='';for Line in Content.Split([sLineBreak]) do begin if Result='' then Result:='- '+Line else Result:=Result+sLineBreak+'  '+Line;end;Exit(Result+sLineBreak);
  end;
  if Name='term' then Exit('**'+Content+'** ');
  Result:=Content;
 end;
begin
 try Doc:=LoadDocXml('<doc>'+Text+'</doc>');except Exit(Text);end;
 Result:=Render(Doc.DocumentElement);
end;
end.
