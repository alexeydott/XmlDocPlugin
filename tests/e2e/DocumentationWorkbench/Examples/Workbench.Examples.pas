/// <summary>Executable documentation examples with an explicit compiler context.</summary>
unit Workbench.Examples;
interface
/// <summary>Runs the documented usage example.</summary>
procedure RunUsageExample;
implementation
uses Workbench.Sample;
procedure RunUsageExample;
{$REGION 'Usage'}
var Sample:TDocumented;
begin
 Sample:=TDocumented.Create;
 try
  Sample.Run(7);
  if Sample.Count<>7 then Halt(2);
 finally Sample.Free;end;
end;
{$ENDREGION}
end.
