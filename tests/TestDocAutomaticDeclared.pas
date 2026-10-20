unit TestDocAutomaticDeclared;
interface
uses DUnitX.TestFramework;
type
 [TestFixture] TAutomaticDeclaredTests=class
 private FDir:string;
 procedure Put(const Name,Text:string);
 procedure Check(const Source:string);
 public
 [Setup] procedure Setup;
 [TearDown] procedure Cleanup;
 [Test] procedure ImportedSymbols;
 [Test] procedure InheritedMethodAndProperty;
 [Test] procedure ImportPrecedence;
 [Test] procedure IncludeCycle;
 [Test] procedure RTLImport;
 [Test] procedure SearchPath;
 [Test] procedure ConditionalImportCycle;
 [Test] procedure AncestorCycle;
 [Test] procedure EnumerationVisibility;
 [Test] procedure ImportedVisibility;
 [Test] procedure InheritedVisibility;
 [Test] procedure SameUnitVisibility;
 [Test] procedure QualifiedAncestorAndAlias;
 [Test] procedure DependencyRefresh;
 [Test] procedure SourceFileMapping;
 [Test] procedure IncludedDeclarations;
 [Test] procedure MissingSourceDiagnostic;
 end;
implementation
uses System.SysUtils,System.IOUtils,XmlDoc.Parser;
procedure TAutomaticDeclaredTests.Setup;
begin FDir:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);TDirectory.CreateDirectory(FDir);end;
procedure TAutomaticDeclaredTests.Cleanup;
begin TDirectory.Delete(FDir,True);end;
procedure TAutomaticDeclaredTests.Put(const Name,Text:string);
begin TFile.WriteAllText(TPath.Combine(FDir,Name),Text,TEncoding.UTF8);end;
procedure TAutomaticDeclaredTests.Check(const Source:string);
var P:TDocParser;
begin P:=TDocParser.Create;try P.ParseSource(Source,TPath.Combine(FDir,'Child.pas'));Assert.IsNotNull(P.RootNode);finally P.Free;end;end;
procedure TAutomaticDeclaredTests.EnumerationVisibility;
begin
 Put('Parent.pas','unit Parent; interface type TEnum=(First,Second); {$SCOPEDENUMS ON} TScoped=(Third,Fourth); implementation end.');
 Check('unit Child; interface uses Parent; {$IF NOT DECLARED(First) OR DECLARED(Third)} invalid syntax {$ENDIF} implementation end.');
end;
procedure TAutomaticDeclaredTests.RTLImport;
begin
 Check('unit Child; interface uses System.SysUtils; {$IF NOT DECLARED(Exception)} invalid syntax {$ENDIF} implementation end.');
end;
procedure TAutomaticDeclaredTests.SearchPath;
var P:TDocParser;
begin
 TDirectory.CreateDirectory(TPath.Combine(FDir,'nested'));
 Put('nested\Parent.pas','unit Parent; interface const Imported=1; implementation end.');
 P:=TDocParser.Create;try
 P.SearchPaths:=[TPath.Combine(FDir,'nested')];
 P.ParseSource('unit Child; interface uses Parent; {$IF NOT DECLARED(Imported)} invalid syntax {$ENDIF} implementation end.',TPath.Combine(FDir,'Child.pas'));
 Assert.IsNotNull(P.RootNode);
 finally P.Free;end;
end;
procedure TAutomaticDeclaredTests.ConditionalImportCycle;
var P:TDocParser;
begin
 Put('Parent.pas','unit Parent; interface uses Other; {$IF DECLARED(Anything)} {$ENDIF} implementation end.');
 Put('Other.pas','unit Other; interface uses Parent; {$IF DECLARED(Anything)} {$ENDIF} implementation end.');
 P:=TDocParser.Create;try
 Assert.WillRaise(procedure begin P.ParseSource('unit Child; interface uses Parent; {$IF DECLARED(Anything)} {$ENDIF} implementation end.',TPath.Combine(FDir,'Child.pas'));end);
 Assert.IsNull(P.RootNode);
 finally P.Free;end;
end;
procedure TAutomaticDeclaredTests.AncestorCycle;
var P:TDocParser;
begin
 Put('Parent.pas','unit Parent; interface type TA=class(TB) end; TB=class(TA) end; implementation end.');
 P:=TDocParser.Create;try
 Assert.WillRaise(procedure begin P.ParseSource('unit Child; interface uses Parent; type TC=class(TA) {$IF DECLARED(Anything)} {$ENDIF} end; implementation end.',TPath.Combine(FDir,'Child.pas'));end);
 Assert.IsNull(P.RootNode);
 finally P.Free;end;
end;
procedure TAutomaticDeclaredTests.InheritedMethodAndProperty;
begin
 Put('Parent.pas','unit Parent; interface type TBase=class private FValue:Integer; public procedure Act; property Value:Integer read FValue; end; implementation end.');
 Check('unit Child; interface uses Parent; type TChild=class(TBase) {$IF NOT DECLARED(Act) OR NOT DECLARED(Value) OR NOT DECLARED(Create)} invalid syntax {$ENDIF} end; implementation end.');
end;
procedure TAutomaticDeclaredTests.ImportPrecedence;
begin
 Put('Parent.pas','unit Parent; interface type TBase=class public Earlier:Integer; end; implementation end.');
 Put('Other.pas','unit Other; interface type TBase=class public Later:Integer; end; implementation end.');
 Check('unit Child; interface uses Parent,Other; type TChild=class(TBase) {$IF NOT DECLARED(Later) OR DECLARED(Earlier)} invalid syntax {$ENDIF} end; implementation end.');
end;
procedure TAutomaticDeclaredTests.IncludeCycle;
var P:TDocParser;
begin
 Put('a.inc','{$I b.inc}');Put('b.inc','{$I a.inc}');
 P:=TDocParser.Create;try
 Assert.WillRaise(procedure begin P.ParseSource('unit Child; interface {$I a.inc} implementation end.',TPath.Combine(FDir,'Child.pas'));end);
 Assert.IsNull(P.RootNode);
 finally P.Free;end;
end;
procedure TAutomaticDeclaredTests.ImportedSymbols;
begin
 Put('Parent.pas','unit Parent; interface type TImported=class end; const ImportedConstant=1; var ImportedVariable:Integer; procedure ImportedRoutine; implementation procedure ImportedRoutine; begin end; end.');
 Check('unit Child; interface uses Parent; {$IF DECLARED(TImported) AND DECLARED(ImportedConstant) AND DECLARED(ImportedVariable) AND DECLARED(ImportedRoutine) AND NOT DECLARED(Absent)} type TGood=class end; {$ELSE} invalid syntax {$ENDIF} implementation end.');
end;
procedure TAutomaticDeclaredTests.ImportedVisibility;
begin
 Put('Indirect.pas','unit Indirect; interface type TIndirect=class end; implementation end.');
 Put('Parent.pas','unit Parent; interface uses Indirect; implementation type THidden=class end; end.');
 Check('unit Child; interface uses Parent; {$IF DECLARED(THidden) OR DECLARED(TIndirect)} invalid syntax {$ENDIF} implementation end.');
end;
procedure TAutomaticDeclaredTests.InheritedVisibility;
begin
 Put('Parent.pas','unit Parent; interface type TBase=class private Secret:Integer; strict private StrictSecret:Integer; protected Prot:Integer; strict protected StrictProt:Integer; public Pub:Integer; end; TMiddle=class(TBase) end; implementation end.');
 Check('unit Child; interface uses Parent; type TChild=class(TMiddle) procedure Run; end; implementation pro' +
  'cedure TChild.Run; {$IF NOT DECLARED(Prot) OR NOT DECLARED(StrictProt) OR NOT DECLARED(Pub) OR DECLA' +
  'RED(Secret) OR DECLARED(StrictSecret)} invalid syntax {$ENDIF} begin end; end.');
end;
procedure TAutomaticDeclaredTests.SameUnitVisibility;
begin
 Check('unit Child; interface type TBase=class private Secret:Integer; strict private StrictSecret:Integer; ' +
  'end; TChild=class(TBase) procedure Run; end; implementation procedure TChild.Run; {$IF NOT DECLARED(' +
  'Secret) OR DECLARED(StrictSecret)} invalid syntax {$ENDIF} begin end; end.');
end;
procedure TAutomaticDeclaredTests.QualifiedAncestorAndAlias;
begin
 Put('Parent.pas','unit Parent; interface type TBase=class public InheritedField:Integer; end; TAlias=TBase; implementation end.');
 Check('unit Child; interface uses Parent; type TChild=class(Parent.TAlias) {$IF NOT DECLARED(InheritedField)} invalid syntax {$ENDIF} end; implementation end.');
end;
procedure TAutomaticDeclaredTests.DependencyRefresh;
var P:TDocParser;S:string;
begin
 P:=TDocParser.Create;try
 S:='unit Child; interface uses Parent; {$IF DECLARED(TImported)} type TGood=class end; {$ELSE} invalid syntax {$ENDIF} implementation end.';
 Put('Parent.pas','unit Parent; interface type TImported=class end; implementation end.');
 P.ParseSource(S,TPath.Combine(FDir,'Child.pas'));
 Put('Parent.pas','unit Parent; interface implementation end.');
 Assert.WillRaise(procedure begin P.ParseSource(S,TPath.Combine(FDir,'Child.pas'));end);
 Assert.IsNull(P.RootNode);
 finally P.Free;end;
end;
procedure TAutomaticDeclaredTests.SourceFileMapping;
var P:TDocParser;
begin
 TDirectory.CreateDirectory(TPath.Combine(FDir,'nested'));
 Put('nested\Parent.pas','unit Parent; interface const Imported=1; implementation end.');
 P:=TDocParser.Create;try
 P.SourceFiles:=[TPath.Combine(FDir,'nested\Parent.pas')];
 P.ParseSource('unit Child; interface uses Parent; {$IF NOT DECLARED(Imported)} invalid syntax {$ENDIF} implementation end.',TPath.Combine(FDir,'Child.pas'));
 Assert.IsNotNull(P.RootNode);
 finally P.Free;end;
end;
procedure TAutomaticDeclaredTests.IncludedDeclarations;
begin
 Put('decl.inc','type TIncluded=class end;');
 Check('unit Child; interface {$I decl.inc} {$IF NOT DECLARED(TIncluded)} invalid syntax {$ENDIF} implementation end.');
end;
procedure TAutomaticDeclaredTests.MissingSourceDiagnostic;
var P:TDocParser;
begin P:=TDocParser.Create;try
 try P.ParseSource('unit Child; interface uses MissingDependency; {$IF DECLARED(Anything)} {$ENDIF} implementation end.',TPath.Combine(FDir,'Child.pas'));Assert.Fail('Expected diagnostic');
 except on E:Exception do begin Assert.IsTrue(E.Message.Contains('DECLARED'));Assert.IsTrue(E.Message.Contains('MissingDependency'));end;end;
 Assert.IsNull(P.RootNode);
 finally P.Free;end;
end;
initialization TDUnitX.RegisterTestFixture(TAutomaticDeclaredTests);
end.
