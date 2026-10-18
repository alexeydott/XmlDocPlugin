unit TestDocDeclared;
interface
uses DUnitX.TestFramework,SimpleParser.Lexer;
type
  [TestFixture] TTestDocDeclared=class
  private
    FExternalDeclared:Boolean;
    function Resolve(Sender:TmwBasePasLex;const Identifier:string;out Declared:Boolean):Boolean;
  public
    [Test] procedure VisibleAndMissing;
    [Test] procedure PredefinedSkiaAliases;
    [Test] procedure QualifiedDiagnostic;
    [Test] procedure OtherMethodScope;
    [Test] procedure BlockScope;
    [Test] procedure InlineVariable;
    [Test] procedure UnknownImportIsError;
    [Test] procedure ExternalResolverAndCache;
    [Test] procedure BatchFailure;
    [Test] procedure LocalVariableAndParameter;
    [Test] procedure InactiveUnknown;
    [Test] procedure UnknownWithoutImports;
  end;
implementation
uses System.SysUtils,System.IOUtils,XmlDoc.Parser,XmlDoc.HelpGen.BatchParser;
function TTestDocDeclared.Resolve(Sender:TmwBasePasLex;const Identifier:string;out Declared:Boolean):Boolean;
begin
  Result:=SameText(Identifier,'ExternalSymbol') or SameText(Identifier,'Missing') or SameText(Identifier,'Hidden');
  Declared:=SameText(Identifier,'ExternalSymbol') and FExternalDeclared;
end;
{$IF NOT DECLARED(UTF8Char) OR NOT DECLARED(FixedInt) OR NOT DECLARED(FixedUInt)}
{$MESSAGE ERROR 'System alias assumptions must match the target compiler'}
{$IFEND}
procedure TTestDocDeclared.PredefinedSkiaAliases;
var P:TDocParser;
begin
  P:=TDocParser.Create;
  try
    P.ParseSource('unit D; interface {$IF DECLARED(UTF8Char) AND DECLARED(FixedInt) AND DECLARED(FixedUInt)} '+
      'type TSelected=class end; {$ELSE} invalid syntax {$ENDIF} implementation end.');
    Assert.IsNotNull(P.RootNode);
  finally P.Free;end;
end;
procedure TTestDocDeclared.VisibleAndMissing;
var P:TDocParser;
begin
  P:=TDocParser.Create;
  try
    P.OnResolveDeclaration:=Resolve;
    P.ParseSource('unit D; interface type TBefore=class end; '+
      '{$IF DECLARED(TBefore) AND DECLARED(Integer) AND NOT DECLARED(Missing)} '+
      'type TSelected=class end; {$ELSE} invalid syntax {$ENDIF} implementation end.');
    Assert.IsNotNull(P.RootNode);
  finally P.Free;end;
end;
procedure TTestDocDeclared.QualifiedDiagnostic;
var P:TDocParser;
begin
  P:=TDocParser.Create;
  try
    Assert.WillRaise(procedure begin
      P.ParseSource('unit D; interface type TRec=record Value:Integer; end; {$IF DECLARED(TRec.Value)} {$ENDIF} implementation end.');
    end);
  finally P.Free;end;
end;
procedure TTestDocDeclared.OtherMethodScope;
var P:TDocParser;
begin
  P:=TDocParser.Create;
  try
    P.OnResolveDeclaration:=Resolve;
    P.ParseSource('unit D; interface implementation procedure A; var Hidden:Integer; begin end; '+
      'procedure B; {$IF DECLARED(Hidden)} invalid syntax {$ELSE} begin end; {$ENDIF} end.');
    Assert.IsNotNull(P.RootNode);
  finally P.Free;end;
end;
procedure TTestDocDeclared.BlockScope;
var P:TDocParser;
begin
  P:=TDocParser.Create;
  try
    P.OnResolveDeclaration:=Resolve;
    P.ParseSource('unit D; interface implementation procedure Run; begin begin var Hidden:=1; end; '+
      '{$IF DECLARED(Hidden)} invalid syntax {$ENDIF} end; end.');
    Assert.IsNotNull(P.RootNode);
  finally P.Free;end;
end;
procedure TTestDocDeclared.InlineVariable;
var P:TDocParser;
begin
  P:=TDocParser.Create;
  try
    P.ParseSource('unit D; interface implementation procedure Run; begin var Local:=1; '+
      '{$IF DECLARED(Local)} Local:=2; {$ELSE} invalid syntax {$ENDIF} end; end.');
    Assert.IsNotNull(P.RootNode);
  finally P.Free;end;
end;
procedure TTestDocDeclared.UnknownImportIsError;
var P:TDocParser;Failed:Boolean;
begin
  P:=TDocParser.Create;
  try
    Failed:=False;
    try P.ParseSource('unit D; interface uses UnknownUnit; {$IF DECLARED(UnknownSymbol)} type TSelected=class end; {$ENDIF} implementation end.');
    except on E:Exception do begin Failed:=True;Assert.IsTrue(E.Message.Contains('DECLARED'));end;end;
    Assert.IsTrue(Failed);Assert.IsNull(P.RootNode);
    Assert.IsFalse(P.IsUpToDate(P.SourceText));
    P.ParseSource('unit Valid; interface implementation end.');Assert.IsNotNull(P.RootNode);
  finally P.Free;end;
end;
procedure TTestDocDeclared.ExternalResolverAndCache;
const Source='unit D; interface uses UnknownUnit; {$IF DECLARED(ExternalSymbol)} type TSelected=class end; {$ELSE} invalid syntax {$ENDIF} implementation end.';
var P:TDocParser;
begin
  P:=TDocParser.Create;
  try
    FExternalDeclared:=True;
    P.OnResolveDeclaration:=Resolve;P.ParseSource(Source);Assert.IsNotNull(P.RootNode);
    Assert.IsFalse(P.IsUpToDate(Source),'External visibility can change without source edits');
    FExternalDeclared:=False;
    Assert.WillRaise(procedure begin P.ParseSource(Source);end);
    FExternalDeclared:=True;P.ParseSource(Source);Assert.IsNotNull(P.RootNode);
    P.OnResolveDeclaration:=nil;
    Assert.WillRaise(procedure begin P.ParseSource(Source);end);
  finally P.Free;end;
end;
procedure TTestDocDeclared.BatchFailure;
var Dir,FileName:string;P:TBatchParser;Failed:Boolean;
begin
  Dir:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);TDirectory.CreateDirectory(Dir);
  FileName:=TPath.Combine(Dir,'BadDeclared.pas');P:=TBatchParser.Create;
  try
    TFile.WriteAllText(FileName,'unit BadDeclared; interface uses MissingUnit; {$IF DECLARED(MissingSymbol)} {$ENDIF} implementation end.');
    Failed:=False;
    try P.ParseAll([FileName]);except on E:Exception do begin Failed:=True;Assert.IsTrue(E.Message.Contains(FileName));Assert.IsTrue(E.Message.Contains('DECLARED'));end;end;
    Assert.IsTrue(Failed);Assert.AreEqual<NativeInt>(0,P.Units.Count);
  finally P.Free;TFile.Delete(FileName);TDirectory.Delete(Dir);end;
end;
procedure TTestDocDeclared.LocalVariableAndParameter;
var P:TDocParser;
begin
  P:=TDocParser.Create;
  try
    P.ParseSource('unit D; interface implementation procedure Run(Value:Integer); var Local:Integer; '+
      '{$IF DECLARED(Value) AND DECLARED(Local)} begin end; {$ELSE} invalid syntax {$ENDIF} end.');
    Assert.IsNotNull(P.RootNode);
  finally P.Free;end;
end;
procedure TTestDocDeclared.InactiveUnknown;
var P:TDocParser;
begin
  P:=TDocParser.Create;
  try
    P.ParseSource('unit D; interface {$IF False} {$IF DECLARED(UnknownSymbol)} invalid syntax {$ENDIF} {$ENDIF} implementation end.');
    Assert.IsNotNull(P.RootNode);
  finally P.Free;end;
end;
procedure TTestDocDeclared.UnknownWithoutImports;
var P:TDocParser;
begin
  P:=TDocParser.Create;
  try
    P.ParseSource('unit D; interface {$IF DECLARED(UnknownSystemSymbol)} invalid syntax {$ENDIF} implementation end.');
    Assert.IsNotNull(P.RootNode);
  finally P.Free;end;
end;
initialization
 TDUnitX.RegisterTestFixture(TTestDocDeclared);
end.
