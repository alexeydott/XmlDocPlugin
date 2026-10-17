program XmlDocGen;

{$APPTYPE CONSOLE}


uses
  System.SysUtils,
  Winapi.ActiveX,
  XmlDoc.CLI.Main;

var
  LCLI: TCLIMain;
  LExitCode: Integer;
begin
  CoInitialize(nil);
  try
  try
    LCLI := TCLIMain.Create;
    try
      LExitCode := LCLI.Run;
    finally
      LCLI.Free;
    end;
    ExitCode := LExitCode;
  except
    on E: Exception do
    begin
      WriteLn('Fatal error: ', E.Message);
      ExitCode := 2;
    end;
  end;
  finally
    CoUninitialize;
  end;
end.
