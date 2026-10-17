unit TestDocCoverage;

interface
uses DUnitX.TestFramework;
type
  [TestFixture]
  TTestDocCoverage = class
  public
    [Test] procedure TestCurrentProjectSourceEncodings;
  end;

implementation
uses System.SysUtils, System.Classes, System.IOUtils,
  XmlDoc.HelpGen.Scanner, XmlDoc.HelpGen.BatchParser, XmlDoc.HelpGen.Coverage;

procedure TTestDocCoverage.TestCurrentProjectSourceEncodings;
var
  Root, ProjectPath, UnitPath, Source, Summary: string;
  Scanner: TProjectScanner;
  Parser: TBatchParser;
  Report: TDocCoverageReport;
  Options: TScanOptions;
  Stats: TCoverageStats;
  Files: TArray<string>;
  Encoding: TEncoding;
  I: Integer;
begin
  Root := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  TDirectory.CreateDirectory(Root);
  try
    ProjectPath := TPath.Combine(Root, 'CoverageProject.dproj');
    UnitPath := TPath.Combine(Root, 'CoverageUnit.pas');
    TFile.WriteAllText(ProjectPath, '<Project><MainSource>CoverageProject.dpk</MainSource></Project>', TEncoding.UTF8);
    for I := 0 to 3 do
    begin
      case I of
        0: Encoding := TEncoding.ANSI;
        1, 2: Encoding := TEncoding.UTF8;
      else Encoding := TEncoding.Unicode;
      end;
      Summary := 'Описание класса';
      if I = 0 then
        Summary := Encoding.GetString(Encoding.GetBytes(Summary));
      Source := 'unit CoverageUnit;' + sLineBreak + 'interface' + sLineBreak +
        '/// <summary>' + Summary + '</summary>' + sLineBreak +
        'type TCovered = class end;' + sLineBreak + 'implementation' + sLineBreak + 'end.';
      if I = 1 then
        TFile.WriteAllBytes(UnitPath, Encoding.GetBytes(Source))
      else TFile.WriteAllText(UnitPath, Source, Encoding);
      // Exercise Current Project scanning as well as source parsing.
      TFile.WriteAllText(TPath.Combine(Root, 'CoverageProject.dpk'),
        'package CoverageProject;' + sLineBreak + '// ' + Summary + sLineBreak +
        'contains CoverageUnit in ''CoverageUnit.pas'';' + sLineBreak + 'end.', Encoding);
      Options := Default(TScanOptions);
      Options.Source := ssProjectFile;
      Options.ProjectPath := ProjectPath;
      Scanner := TProjectScanner.Create;
      Parser := TBatchParser.Create;
      Report := TDocCoverageReport.Create;
      try
        Files := Scanner.Scan(Options);
        Assert.AreEqual<NativeInt>(1, Length(Files), 'Project scan encoding ' + IntToStr(I));
        Parser.ParseAll(Files);
        Assert.AreEqual<NativeInt>(1, Parser.Units.Count);
        Assert.AreEqual<NativeInt>(1, Parser.Units[0].Types.Count);
        Assert.AreEqual(Summary, Parser.Units[0].Types[0].Doc.Summary);
        Stats := Report.Analyze(Parser.Units);
        try
          Assert.AreEqual(1, Stats.TotalElements);
          Assert.AreEqual(1, Stats.Documented);
          Assert.AreEqual<NativeInt>(0, Length(Report.GetUndocumented(Parser.Units)));
        finally
          Stats.ByKind.Free;
          Stats.ByVisibility.Free;
          Stats.ByUnit.Free;
        end;
      finally
        Report.Free;
        Parser.Free;
        Scanner.Free;
      end;
    end;
  finally
    TDirectory.Delete(Root, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDocCoverage);
end.
