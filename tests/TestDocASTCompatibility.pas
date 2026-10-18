unit TestDocASTCompatibility;
interface
uses DUnitX.TestFramework;
type
  [TestFixture] TTestDocASTCompatibility = class
  public
    [Test] procedure GenericMethodAndParameterNames;
    [Test] procedure ImplementationMethodScope;
    [Test] procedure FieldsAndConstructors;
  end;
implementation
uses System.SysUtils, XmlDoc.Parser, XmlDoc.Consts;
procedure TTestDocASTCompatibility.GenericMethodAndParameterNames;
var P:TDocParser;E:TCodeElementInfo;
begin
  P:=TDocParser.Create;
  try
    P.ParseSource('unit Modern;'+sLineBreak+'interface'+sLineBreak+
      'type TBox<T> = class'+sLineBreak+
      'class function Convert<U>(const Value:U):U; static;'+sLineBreak+
      'end;'+sLineBreak+'implementation'+sLineBreak+'end.');
    E:=P.GetElementAtLine(4);
    Assert.AreEqual('Convert',E.Name);Assert.AreEqual('TBox<T>',E.QualifiedParent);
    Assert.AreEqual<NativeInt>(1,Length(E.GenericParams));Assert.AreEqual('U',E.GenericParams[0]);
    Assert.AreEqual<NativeInt>(1,Length(E.Params));Assert.AreEqual('Value',E.Params[0].Name);
    Assert.IsTrue(E.Params[0].IsConst);Assert.AreEqual('U',E.ReturnType);
  finally P.Free;end;
end;
procedure TTestDocASTCompatibility.ImplementationMethodScope;
var P:TDocParser;E:TCodeElementInfo;
begin
  P:=TDocParser.Create;
  try
    P.ParseSource('unit Modern;'+sLineBreak+'interface'+sLineBreak+
      'type TBox = class procedure Run; end;'+sLineBreak+'implementation'+sLineBreak+
      'procedure TBox.Run;'+sLineBreak+'begin end;'+sLineBreak+'end.');
    E:=P.GetElementAtLine(5);Assert.AreEqual('Run',E.Name);
    Assert.AreEqual('TBox',E.QualifiedParent);Assert.AreEqual('TBox.Run',E.FullName);
  finally P.Free;end;
end;
procedure TTestDocASTCompatibility.FieldsAndConstructors;
var P:TDocParser;E:TCodeElementInfo;
begin
  P:=TDocParser.Create;
  try
    P.ParseSource('unit Modern;'+sLineBreak+'interface'+sLineBreak+'type TBox = class'+sLineBreak+
      'Value:Integer;'+sLineBreak+'constructor Create;'+sLineBreak+'end;'+sLineBreak+
      'implementation'+sLineBreak+'constructor TBox.Create;'+sLineBreak+'begin end;'+sLineBreak+'end.');
    E:=P.GetElementAtLine(4);Assert.AreEqual('Value',E.Name);Assert.AreEqual('TBox.Value',E.FullName);
    E:=P.GetElementAtLine(5);Assert.AreEqual('Create',E.Name);Assert.AreEqual('constructor',E.MethodKind);
    E:=P.GetElementAtLine(8);Assert.AreEqual('Create',E.Name);Assert.AreEqual('TBox.Create',E.FullName);
  finally P.Free;end;
end;
initialization
 TDUnitX.RegisterTestFixture(TTestDocASTCompatibility);
end.
