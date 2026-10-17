program FakeHHC;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.IOUtils;
begin
  // A failed compiler can leave an apparently valid-looking CHM behind.
  if ParamCount > 0 then TFile.WriteAllText(ChangeFileExt(ParamStr(1), '.chm'), 'ITSFpartial');
  Writeln('HHC5003: Error: simulated compiler failure');
  ExitCode := 0;
end.
