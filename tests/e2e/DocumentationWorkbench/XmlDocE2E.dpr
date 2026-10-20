program XmlDocE2E;
{$APPTYPE CONSOLE}
uses
 Workbench.Contracts in 'Units\Workbench.Contracts.pas',
 Workbench.Sample in 'Units\Workbench.Sample.pas',
 Workbench.Second in 'Units\Workbench.Second.pas',
 Workbench.Markup in 'Units\Workbench.Markup.pas',
 Workbench.Examples in 'Examples\Workbench.Examples.pas';
var Sample:TDocumented;
begin
 RunUsageExample;Sample:=TDocumented.Create;
 try
  Sample.Run(7);Sample.Run('hello');
  if Sample.Count<>7 then Halt(1);
  Writeln('PASS DocumentationWorkbench fixture');
 finally Sample.Free;end;
end.
