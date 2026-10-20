/// <summary>Captures the exact method implementation and project dependencies used by an AI request.</summary>
unit XmlDoc.AI.Context;
interface
uses XmlDoc.AI.Contracts,XmlDoc.Parser,XmlDoc.Consts;
function CaptureMethodContext(Parser:TDocParser;const Target:TCodeElementInfo;
 const Documentation,Terms,Instruction:string):TAIContext;
implementation
uses System.SysUtils,System.JSON,System.Hash,System.RegularExpressions,System.Generics.Collections,System.Generics.Defaults;
function CaptureMethodContext(Parser:TDocParser;const Target:TCodeElementInfo;
 const Documentation,Terms,Instruction:string):TAIContext;
var Reason,Stamp:string;Parameters,Dependencies:TJSONArray;Owner:TJSONObject;
begin
 Result:=Default(TAIContext);
 if not Parser.MethodSource(Target,Result.Code,Reason) then raise EAIError.Create(Reason);
 Result.Signature:=Target.Signature;Result.Documentation:=Documentation;
 Result.ReturnType:=Target.ReturnType;Result.ProjectTerms:=Terms;Result.UserInstruction:=Instruction;
 Parameters:=TJSONArray.Create;Dependencies:=TJSONArray.Create;Owner:=TJSONObject.Create;
 try
  for var Param in Target.Params do Parameters.AddElement(TJSONObject.Create.AddPair('name',Param.Name).AddPair('type',Param.TypeName));
  Result.Parameters:=Parameters.ToJSON;Owner.AddPair('owner',Target.QualifiedParent);Owner.AddPair('platform',Parser.Platform);Owner.AddPair('compilerVersion',TJSONNumber.Create(CompilerVersion));
  var Defines:=TJSONArray.Create;Owner.AddPair('defines',Defines);for var Define in Parser.Defines do Defines.Add(Define);
  for var Element in Parser.GetAllElements do if SameText(Element.Name,Target.QualifiedParent) or
   SameText(TRegEx.Replace(Element.FullName,'<[^>]+>',''),TRegEx.Replace(Target.QualifiedParent,'<[^>]+>','')) then begin Owner.AddPair('ancestor',Element.Ancestor);Break;end;
  var Snapshots:=Copy(Parser.DependencySnapshots);TArray.Sort<TSourceSnapshot>(Snapshots,TComparer<TSourceSnapshot>.Construct(function(const Left,Right:TSourceSnapshot):Integer begin Result:=CompareText(Left.FileName,Right.FileName);end));
  for var Dependency in Snapshots do begin
   var Entry:=TJSONObject.Create.AddPair('file',Dependency.FileName).AddPair('revision',THashSHA2.GetHashString(Dependency.Source));
   // Imported units affect freshness, but their entire implementations are not
   // part of the selected method's prompt. Include bodies remain available.
   if SameText(ExtractFileExt(Dependency.FileName),'.inc') then Entry.AddPair('source',Dependency.Source);
   Dependencies.AddElement(Entry);
  end;
  Owner.AddPair('includesAndDependencies',Dependencies);Dependencies:=nil;Result.TypeContext:=Owner.ToJSON;
  Stamp:=Parser.SourceText+#0+Parser.Platform+#0+string.Join(';',Parser.Defines)+#0+string.Join(';',Parser.SearchPaths)+#0+string.Join(';',Parser.SourceFiles)+#0+Result.TypeContext+#0+Terms;
  Result.Fingerprint:=THashSHA2.GetHashString(Stamp);
 finally Owner.Free;Dependencies.Free;Parameters.Free;end;
end;
end.
