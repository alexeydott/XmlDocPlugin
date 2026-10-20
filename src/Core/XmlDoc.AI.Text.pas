/// <summary>Removes provider HTML from AI prose and emits safe XML paragraphs without executing markup.</summary>
unit XmlDoc.AI.Text;
interface
function CleanAIText(const Text:string):string;
function AITextXml(const Text:string):string;
implementation
uses System.SysUtils,System.Classes,System.StrUtils,System.NetEncoding,System.RegularExpressions;
function CleanAIText(const Text:string):string;
const
 Tags='|html|body|head|title|meta|link|base|p|div|span|b|strong|i|em|u|s|small|mark|font|a|img|br|hr|pre|co' +
  'de|blockquote|ul|ol|li|dl|dt|dd|table|thead|tbody|tfoot|tr|td|th|caption|h1|h2|h3|h4|h5|h6|section|a' +
  'rticle|header|footer|nav|main|aside|figure|figcaption|script|style|iframe|object|embed|svg|math|temp' +
  'late|form|input|button|textarea|select|option|';
 Blocks='|p|div|pre|blockquote|ul|ol|li|dl|dt|dd|table|tr|h1|h2|h3|h4|h5|h6|section|article|header|footer|figure|figcaption|';
 Hidden='|script|style|head|iframe|object|svg|math|template|';
var S,Lower,Name:string;B:TStringBuilder;I,J,K,Finish:Integer;Quote:Char;
begin
 S:=TNetEncoding.HTML.Decode(Text).Replace(#13#10,#10).Replace(#13,#10);Lower:=LowerCase(S);B:=TStringBuilder.Create;
 try
  I:=1;
  while I<=Length(S) do begin
   if Copy(S,I,4)='<!--' then begin J:=Pos('-->',S,I+4);if J=0 then Break;I:=J+3;Continue;end;
   if S[I]='<' then begin
    K:=I+1;if (K<=Length(S)) and (S[K]='/') then Inc(K);J:=K;
    while (J<=Length(S)) and CharInSet(S[J],['A'..'Z','a'..'z','0'..'9']) do Inc(J);
    Name:=LowerCase(Copy(S,K,J-K));
    // A generic argument such as TList<A> is prose/code, not an HTML anchor.
    if (I>1) and CharInSet(S[I-1],['A'..'Z','a'..'z','0'..'9','_']) and
     CharInSet(S[I+1],['A'..'Z','a'..'z']) and (Pos('</'+Name+'>',Lower,J)=0) and
     MatchText(Name,['a','b','i','s','u','em','strong','small','code','span','font']) then Name:='';
    if (Name<>'') and Tags.Contains('|'+Name+'|') and ((J>Length(S)) or CharInSet(S[J],[' ',#9,#10,'/','>'])) then begin
     Finish:=J;Quote:=#0;
     while Finish<=Length(S) do begin
      if Quote<>#0 then begin if S[Finish]=Quote then Quote:=#0;end
      else if CharInSet(S[Finish],['"','''']) then Quote:=S[Finish]
      else if S[Finish]='>' then Break;Inc(Finish);
     end;
     if Finish>Length(S) then Break;
     if Hidden.Contains('|'+Name+'|') and (S[I+1]<>'/') then begin
      J:=Pos('</'+Name,Lower,Finish+1);
      while (J>0) and (J+Length(Name)+2<=Length(S)) and not CharInSet(S[J+Length(Name)+2],[' ',#9,#10,'>']) do J:=Pos('</'+Name,Lower,J+2);
      if J=0 then Break;Finish:=Pos('>',S,J);if Finish=0 then Break;
     end;
     if Blocks.Contains('|'+Name+'|') then B.Append(#10#10)
     else if (Name='br') or (Name='hr') then B.Append(#10)
     else if (Name='td') or (Name='th') then B.Append(' ');
     I:=Finish+1;Continue;
    end;
    if SameText(Copy(S,I,9),'<!doctype') then begin J:=Pos('>',S,I+9);if J=0 then Break;I:=J+1;Continue;end;
   end;
   B.Append(S[I]);Inc(I);
  end;
  Result:=B.ToString.Replace(Char($00A0),' ');
  Result:=TRegEx.Replace(Result,'[ \t]+',' ');
  Result:=TRegEx.Replace(Result,' *\n *',#10);
  Result:=TRegEx.Replace(Result,'\n{3,}',#10#10).Trim;
 finally B.Free;end;
end;
function AITextXml(const Text:string):string;
var S:string;
begin
 S:=CleanAIText(Text).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;');
 if S.Contains(#10) then begin
  Result:='';for var Paragraph in S.Split([#10#10],TStringSplitOptions.ExcludeEmpty) do Result:=Result+'<para>'+Paragraph.Replace(#10,'<br/>')+'</para>';
 end else Result:=S;
end;
end.
