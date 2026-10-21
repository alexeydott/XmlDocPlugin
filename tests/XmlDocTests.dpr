program XmlDocTests;

{$APPTYPE CONSOLE}
uses
  System.SysUtils, TestDocHelpInsight,
  Winapi.ActiveX,
  DUnitX.TestFramework, DUnitX.Loggers.Console,
  TestDocPasDoc, TestDocModel, TestDocParser, TestDocCodeGen, TestDocStubGen, TestDocHMXP, TestDocCoverage, TestDocPublish, TestDocNavigation, TestDocUnit, TestDocASTCompatibility, TestDocDeclared, TestDocAutomaticDeclared, TestDocImprovements, TestDocThemes, TestDocReview, TestDocQuickScope, TestDocAI;
var
  Runner: ITestRunner;
  Results: IRunResults;
begin
  CoInitialize(nil);
  try
  Runner := TDUnitX.CreateRunner;
  Runner.UseRTTI := True;
  Runner.AddLogger(TDUnitXConsoleLogger.Create(True));
  Results := Runner.Execute;
  if not Results.AllPassed then ExitCode := 1;
  finally
    CoUninitialize;
  end;
end.
