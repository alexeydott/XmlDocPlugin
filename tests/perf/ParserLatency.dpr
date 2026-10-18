program ParserLatency;
{$APPTYPE CONSOLE}
uses Winapi.ActiveX,System.SysUtils,System.Classes,System.Diagnostics,XmlDoc.Parser,XmlDoc.Consts,XmlDoc.ProjectContext,XmlDoc.SourceText;
var P:TDocParser;C:TProjectContext;Source:string;Watch:TStopwatch;E:TCodeElementInfo;Line,I:Integer;
begin
 CoInitialize(nil);
 try
  P:=TDocParser.Create;C:=TProjectContext.Create(ParamStr(2),'Debug','Win32');
  try
   P.Defines:=C.Defines;P.Platform:=C.Platform;P.SearchPaths:=[ExtractFilePath(ParamStr(2))]+C.IncludePaths+C.SearchPaths;P.SourceFiles:=C.SourceFiles;
   Source:=ReadSourceFile(ParamStr(1));Watch:=TStopwatch.StartNew;P.ParseSource(Source,ParamStr(1));
   Writeln('cold_parse_ms=',Watch.Elapsed.TotalMilliseconds:0:3);Line:=1;
   for E in P.GetAllElements do if SameText(E.Name,'WriteToChangeLogTable') and (E.SourceSection='implementation') then begin Line:=E.LineNumber;Break;end;
   Watch:=TStopwatch.StartNew;for I:=1 to 100 do begin P.ParseSource(Source,ParamStr(1));E:=P.GetElementAtLine(Line);end;
   Writeln('warm_parse_and_lookup_ms=',Watch.Elapsed.TotalMilliseconds/100:0:3);Writeln('method=',E.FullName);Writeln('line=',Line);Writeln('dependencies=',Length(P.DependencyFiles));
  finally C.Free;P.Free;end;
 except on E:Exception do begin Writeln(E.ClassName,': ',E.Message);ExitCode:=1;end;end;
 CoUninitialize;
end.
