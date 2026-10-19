/// <summary>Documentation coverage analysis and HTML or console reports.</summary>
unit XmlDoc.HelpGen.Coverage;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.HelpGen.Types;

type
  /// <summary>Documentation completeness level.</summary>
  TCoverageLevel = (
    clNone,
    clSummaryOnly,
    clPartial,
    clComplete
  );

  /// <summary>Coverage information for a declaration.</summary>
  TCoverageItem = record
    ElementFullName: string;
    Kind: TDocElementKind;
    Level: TCoverageLevel;
    MissingTags: TArray<string>;
    Visibility: string;
    Ready:Boolean;
  end;

  /// <summary>Documentation coverage statistics.</summary>
  TCoverageStats = record
    ByKind: TDictionary<TDocElementKind, Integer>;
    ByUnit: TDictionary<string, Double>;
    ByVisibility: TDictionary<string, Integer>;
    Ready:Integer;
    ReadyPercent:Double;
    Complete: Integer;
    CompletePercent: Double;
    CoveragePercent: Double;
    Documented: Integer;
    TotalElements: Integer;
  end;

  /// <summary>Analyzes documentation coverage and renders reports.</summary>
  TDocCoverageReport = class
  private
    FSymbols:TArray<TCodeElementInfo>;
    FPlaceholderPrefix:string;
    FPlaceholderMarkers:string;
    procedure CollectSymbols(const Units:TObjectList<TUnitDocInfo>);
    function AnalyzeElement(const AElem: TElementDocInfo): TCoverageItem;
    function AnalyzeType(const AType: TTypeDocInfo): TCoverageItem;
    function AnalyzeUnit(const AUnit: TUnitDocInfo): TCoverageItem;
    function CoverageLevelToString(ALevel: TCoverageLevel): string;
  public
    /// <summary>Explains failed comment-presence and readiness thresholds separately; empty means both pass.</summary>
    class function ThresholdFailure(const Stats:TCoverageStats;CoverageMin,ReadyMin:Integer):string;static;
    constructor Create;
    property PlaceholderMarkers:string read FPlaceholderMarkers write FPlaceholderMarkers;
    property PlaceholderPrefix:string read FPlaceholderPrefix write FPlaceholderPrefix;
    /// <summary>Computes documentation coverage for the supplied units.</summary>
    /// <param name="AUnits">Units to analyze.</param>
    /// <returns>Documentation coverage statistics.</returns>
    function Analyze(const AUnits: TObjectList<TUnitDocInfo>): TCoverageStats;

    /// <summary>Returns declarations that need documentation.</summary>
    /// <param name="AUnits">Units to process.</param>
    /// <param name="AMinVisibility">Minimum visibility to include; defaults to public.</param>
    /// <returns>Declarations that need documentation.</returns>
    function GetUndocumented(const AUnits: TObjectList<TUnitDocInfo>; const AMinVisibility: string = 'public'): TArray<TCoverageItem>;

    /// <summary>Writes a coverage report to the console.</summary>
    /// <param name="AStats">Documentation coverage statistics.</param>
    procedure RenderConsoleReport(const AStats: TCoverageStats);

    /// <summary>Writes an HTML coverage report.</summary>
    /// <param name="AStats">Documentation coverage statistics.</param>
    /// <param name="AItems">Coverage entries to include.</param>
    /// <param name="AOutputPath">Destination file path.</param>
    procedure RenderHTMLReport(const AStats: TCoverageStats; const AItems: TArray<TCoverageItem>; const AOutputPath: string);
  end;

implementation

uses XmlDoc.Documentation;

function HasParamDoc(const ADoc: TXmlDocModel; const AParamName, PlaceholderPrefix, PlaceholderMarkers: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to ADoc.Params.Count - 1 do
  begin
    if SameText(ADoc.Params[I].Name, AParamName) then
    begin
      Result := TDocumentation.Meaningful(ADoc.Params[I].Description,PlaceholderPrefix,PlaceholderMarkers);
      Exit;
    end;
  end;
end;

{ TDocCoverageReport }
class function TDocCoverageReport.ThresholdFailure(const Stats:TCoverageStats;CoverageMin,ReadyMin:Integer):string;
begin
 if (CoverageMin<0) or (CoverageMin>100) or (ReadyMin<0) or (ReadyMin>100) then raise EArgumentException.Create('Quality thresholds must be between 0 and 100.');
 Result:='';
 if Stats.CoveragePercent<CoverageMin then Result:=Format('Comment presence %.1f%% is below the required %d%%.',[Stats.CoveragePercent,CoverageMin]);
 if Stats.ReadyPercent<ReadyMin then begin if Result<>'' then Result:=Result+sLineBreak;Result:=Result+Format('Ready documentation %.1f%% is below the required %d%%.',[Stats.ReadyPercent,ReadyMin]);end;
end;
constructor TDocCoverageReport.Create;
begin inherited Create;FPlaceholderPrefix:='TODO: ';FPlaceholderMarkers:=CDefaultPlaceholderMarkers;end;


procedure TDocCoverageReport.CollectSymbols(const Units:TObjectList<TUnitDocInfo>);
var Items:TList<TCodeElementInfo>;U:TUnitDocInfo;T:TTypeDocInfo;E:TElementDocInfo;
 procedure AddType(Typ:TTypeDocInfo);
 var Member:TElementDocInfo;Nested:TTypeDocInfo;
 begin Items.Add(Typ.CodeElement);for Member in Typ.Members do Items.Add(Member.CodeElement);for Nested in Typ.NestedTypes do AddType(Nested);end;
begin
 Items:=TList<TCodeElementInfo>.Create;
 try for U in Units do begin Items.Add(U.UnitElement);for T in U.Types do AddType(T);
  for E in U.StandaloneMethods do Items.Add(E.CodeElement);for E in U.Constants do Items.Add(E.CodeElement);for E in U.Variables do Items.Add(E.CodeElement);
 end;FSymbols:=Items.ToArray;finally Items.Free;end;
end;

function TDocCoverageReport.AnalyzeElement(const AElem: TElementDocInfo): TCoverageItem;
var
  LMissing: TList<string>;
  I: Integer;
begin
  Result:=Default(TCoverageItem);
  Result.ElementFullName := AElem.FullName;
  Result.Kind := AElem.Kind;
  Result.Visibility := AElem.Visibility;

  if AElem.Doc.IsEmpty then
  begin
    Result.Level := clNone;
    Result.MissingTags := ['summary'];
    Exit;
  end;

  LMissing := TList<string>.Create;
  try
    if not TDocumentation.Meaningful(AElem.Doc.Summary,FPlaceholderPrefix,FPlaceholderMarkers) then
      LMissing.Add('summary');

    // 메서드: 파라미터와 리턴값 체크
    if AElem.Kind = dekMethod then
    begin
      for I := 0 to Length(AElem.CodeElement.Params) - 1 do
      begin
        if not HasParamDoc(AElem.Doc, AElem.CodeElement.Params[I].Name,FPlaceholderPrefix,FPlaceholderMarkers) then
          LMissing.Add('param:' + AElem.CodeElement.Params[I].Name);
      end;

      if (AElem.CodeElement.ReturnType <> '') and (not TDocumentation.Meaningful(AElem.Doc.Returns,FPlaceholderPrefix,FPlaceholderMarkers)) then
        LMissing.Add('returns');
    end;

    for var Generic in AElem.CodeElement.GenericParams do begin
      var Found:=False;for var Param in AElem.Doc.TypeParams do
        if SameText(Param.Name,Generic) and TDocumentation.Meaningful(Param.Description,FPlaceholderPrefix,FPlaceholderMarkers) then Found:=True;
      if not Found then LMissing.Add('typeparam:'+Generic);
    end;
    if (AElem.Kind=dekProperty) and not TDocumentation.Meaningful(AElem.Doc.Value,FPlaceholderPrefix,FPlaceholderMarkers) then LMissing.Add('value');
    if AElem.Doc.ParseError<>'' then LMissing.Add('invalid-xml');
    Result.Ready:=(LMissing.Count=0) and (Length(TDocumentation.Analyze(AElem.CodeElement,AElem.Doc,FSymbols,'',FPlaceholderPrefix,FPlaceholderMarkers))=0);
    Result.MissingTags := LMissing.ToArray;

    if LMissing.Count = 0 then
      Result.Level := clComplete
    else
    if AElem.Doc.Summary <> '' then
      Result.Level := clPartial
    else
      Result.Level := clSummaryOnly;
  finally
    LMissing.Free;
  end;
end;

function TDocCoverageReport.AnalyzeType(const AType:TTypeDocInfo):TCoverageItem;
var E:TElementDocInfo;
begin
 E:=TElementDocInfo.Create;
 try E.FullName:=AType.FullName;E.Kind:=AType.Kind;E.Visibility:=AType.Visibility;
  E.CodeElement:=AType.CodeElement;E.Doc.Assign(AType.Doc);Result:=AnalyzeElement(E);
 finally E.Free;end;
end;
function TDocCoverageReport.AnalyzeUnit(const AUnit:TUnitDocInfo):TCoverageItem;
var E:TElementDocInfo;
begin
 E:=TElementDocInfo.Create;
 try E.FullName:=AUnit.UnitName;E.Kind:=dekUnit;E.CodeElement:=AUnit.UnitElement;E.Doc.Assign(AUnit.UnitDoc);Result:=AnalyzeElement(E);
 finally E.Free;end;
end;

function TDocCoverageReport.CoverageLevelToString(ALevel: TCoverageLevel): string;
begin
  case ALevel of
    clNone:        Result := 'None';
    clSummaryOnly: Result := 'Summary Only';
    clPartial:     Result := 'Partial';
    clComplete:    Result := 'Complete';
  else
    Result := 'Unknown';
  end;
end;

function TDocCoverageReport.Analyze(const AUnits:TObjectList<TUnitDocInfo>):TCoverageStats;
var U:TUnitDocInfo;E:TElementDocInfo;T:TTypeDocInfo;UnitTotal,UnitDocumented,Count:Integer;Stats:TCoverageStats;
 procedure Add(const Item:TCoverageItem);
 var N:Integer;
 begin
  Inc(Stats.TotalElements);Inc(UnitTotal);
  if Item.Level<>clNone then begin Inc(Stats.Documented);Inc(UnitDocumented);end;
  if Item.Level=clComplete then Inc(Stats.Complete);
  if Item.Ready then Inc(Stats.Ready);
  if not Stats.ByKind.TryGetValue(Item.Kind,N) then N:=0;Stats.ByKind.AddOrSetValue(Item.Kind,N+1);
  if not Stats.ByVisibility.TryGetValue(Item.Visibility,N) then N:=0;Stats.ByVisibility.AddOrSetValue(Item.Visibility,N+1);
 end;
 procedure VisitType(Typ:TTypeDocInfo);
 var M:TElementDocInfo;N:TTypeDocInfo;
 begin Add(AnalyzeType(Typ));for M in Typ.Members do Add(AnalyzeElement(M));for N in Typ.NestedTypes do VisitType(N);end;
begin
 CollectSymbols(AUnits);
 Stats:=Default(TCoverageStats);Stats.ByKind:=TDictionary<TDocElementKind,Integer>.Create;
 Stats.ByUnit:=TDictionary<string,Double>.Create;Stats.ByVisibility:=TDictionary<string,Integer>.Create;
 for U in AUnits do begin
  UnitTotal:=0;UnitDocumented:=0;Add(AnalyzeUnit(U));
  for T in U.Types do VisitType(T);for E in U.StandaloneMethods do Add(AnalyzeElement(E));
  for E in U.Constants do Add(AnalyzeElement(E));for E in U.Variables do Add(AnalyzeElement(E));
  if UnitTotal>0 then Stats.ByUnit.AddOrSetValue(U.UnitName,100*UnitDocumented/UnitTotal);
 end;
 if Stats.TotalElements>0 then begin Stats.CoveragePercent:=100*Stats.Documented/Stats.TotalElements;
  Stats.CompletePercent:=100*Stats.Complete/Stats.TotalElements;Stats.ReadyPercent:=100*Stats.Ready/Stats.TotalElements;end;
 Result:=Stats;
end;

function TDocCoverageReport.GetUndocumented(const AUnits:TObjectList<TUnitDocInfo>;const AMinVisibility:string):TArray<TCoverageItem>;
var Results:TList<TCoverageItem>;U:TUnitDocInfo;T:TTypeDocInfo;E:TElementDocInfo;
 procedure Add(const Item:TCoverageItem);
 begin
  if Item.Level<>clNone then Exit;
  if SameText(AMinVisibility,'public') and (Item.Visibility<>'') and not SameText(Item.Visibility,'public') and not SameText(Item.Visibility,'published') then Exit;
  if SameText(AMinVisibility,'protected') and (Item.Visibility<>'') and not SameText(Item.Visibility,'public') and not SameText(Item.Visibility,'published') and not SameText(Item.Visibility,'protected') then Exit;
  Results.Add(Item);
 end;
 procedure VisitType(Typ:TTypeDocInfo);
 var Member:TElementDocInfo;Nested:TTypeDocInfo;
 begin Add(AnalyzeType(Typ));for Member in Typ.Members do Add(AnalyzeElement(Member));for Nested in Typ.NestedTypes do VisitType(Nested);end;
begin
 CollectSymbols(AUnits);Results:=TList<TCoverageItem>.Create;
 try
  for U in AUnits do begin Add(AnalyzeUnit(U));for T in U.Types do VisitType(T);
   for E in U.StandaloneMethods do Add(AnalyzeElement(E));for E in U.Constants do Add(AnalyzeElement(E));for E in U.Variables do Add(AnalyzeElement(E));
  end;Result:=Results.ToArray;
 finally Results.Free;end;
end;

procedure TDocCoverageReport.RenderConsoleReport(const AStats: TCoverageStats);
begin
  WriteLn('=== Documentation Coverage Report ===');
  WriteLn(Format('Total elements: %d', [AStats.TotalElements]));
  WriteLn(Format('Documented:     %d (%.1f%%)', [AStats.Documented, AStats.CoveragePercent]));
  WriteLn(Format('Complete:       %d (%.1f%%)', [AStats.Complete, AStats.CompletePercent]));
  WriteLn(Format('Ready:          %d (%.1f%%)', [AStats.Ready, AStats.ReadyPercent]));
  WriteLn;
end;

procedure TDocCoverageReport.RenderHTMLReport(
  const AStats: TCoverageStats;
  const AItems: TArray<TCoverageItem>;
  const AOutputPath: string);
var
  LSB: TStringBuilder;
  I: Integer;
  LItem: TCoverageItem;
  LBarColor: string;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('<!DOCTYPE html><html lang="en"><head>');
    LSB.AppendLine('<meta charset="UTF-8"><title>Documentation Coverage Report</title>');
    LSB.AppendLine('<style>');
    LSB.AppendLine('body{font-family:-apple-system,sans-serif;max-width:900px;margin:40px auto;padding:0 20px}');
    LSB.AppendLine('h1{margin-bottom:20px}');
    LSB.AppendLine('.stat{display:inline-block;margin:0 20px 20px 0;padding:16px;border:1px solid #dee2e6;border-radius:8px;text-align:center}');
    LSB.AppendLine('.stat-val{font-size:32px;font-weight:700;color:#0d6efd}');
    LSB.AppendLine('.stat-label{font-size:12px;color:#6c757d;margin-top:4px}');
    LSB.AppendLine('.bar{width:100%;height:24px;background:#e9ecef;border-radius:4px;margin:16px 0;overflow:hidden}');
    LSB.AppendLine('.bar-fill{height:100%;border-radius:4px;transition:width 0.3s}');
    LSB.AppendLine('table{border-collapse:collapse;width:100%;margin:16px 0}');
    LSB.AppendLine('th,td{border:1px solid #dee2e6;padding:6px 10px;text-align:left;font-size:13px}');
    LSB.AppendLine('th{background:#f8f9fa}.none{color:#dc3545}.partial{color:#ffc107}.complete{color:#198754}');
    LSB.AppendLine('</style></head><body>');

    LSB.AppendLine('<h1>Documentation Coverage Report</h1>');

    // Stats cards
    LSB.AppendLine('<div>');
    LSB.AppendFormat('<div class="stat"><div class="stat-val">%d</div><div class="stat-label">Total</div></div>',
      [AStats.TotalElements]);
    LSB.AppendFormat('<div class="stat"><div class="stat-val">%.1f%%</div><div class="stat-label">Documented</div></div>',
      [AStats.CoveragePercent]);
    LSB.AppendFormat('<div class="stat"><div class="stat-val">%.1f%%</div><div class="stat-label">Complete</div></div>',
      [AStats.CompletePercent]);
    LSB.AppendFormat('<div class="stat"><div class="stat-val">%.1f%%</div><div class="stat-label">Ready</div></div>',[AStats.ReadyPercent]);
    LSB.AppendLine('</div>');

    // Progress bar
    if AStats.CoveragePercent >= 80 then
      LBarColor := '#198754'
    else
    if AStats.CoveragePercent >= 50 then
      LBarColor := '#ffc107'
    else
      LBarColor := '#dc3545';

    LSB.AppendFormat('<div class="bar"><div class="bar-fill" style="width:%.1f%%;background:%s"></div></div>',
      [AStats.CoveragePercent, LBarColor]);

    // Undocumented items table
    if Length(AItems) > 0 then
    begin
      LSB.AppendLine('<h2>Undocumented Elements</h2>');
      LSB.AppendLine('<table><tr><th>Element</th><th>Kind</th><th>Level</th><th>Missing</th></tr>');

      for I := 0 to Length(AItems) - 1 do
      begin
        LItem := AItems[I];
        LSB.AppendFormat('<tr><td><code>%s</code></td><td>%s</td><td class="%s">%s</td><td>%s</td></tr>',
          [LItem.ElementFullName,
           LItem.Kind.ToString,
           LowerCase(CoverageLevelToString(LItem.Level)),
           CoverageLevelToString(LItem.Level),
           string.Join(', ', LItem.MissingTags)]);
        LSB.AppendLine;
      end;

      LSB.AppendLine('</table>');
    end;

    LSB.AppendLine('</body></html>');

    TFile.WriteAllText(AOutputPath, LSB.ToString, TEncoding.UTF8);
  finally
    LSB.Free;
  end;
end;

end.
