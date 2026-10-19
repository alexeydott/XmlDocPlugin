/// <summary>Documentation cross-reference resolution across units and declarations.</summary>
unit XmlDoc.HelpGen.CrossRef;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.HelpGen.Types;

type
  /// <summary>A documentation reference that could not be resolved.</summary>
  TUnresolvedRef = record
    Cref: string;
    SourceElement: string;
    SourceFile: string;
    Line: Integer;
  end;

  /// <summary>Resolves documentation cref attributes against the parsed symbol catalog.</summary>
  TCrossRefResolver = class
  private
    FSymbolIndex: TDictionary<string, TElementDocInfo>;
    FUnresolved: TList<TUnresolvedRef>;

    function TryResolve(const ACref, AContextUnit: string): string;
  public
    constructor Create(ASymbolIndex: TDictionary<string, TElementDocInfo>);
    destructor Destroy; override;

    /// <summary>Resolves a reference in the context of its containing declaration.</summary>
    /// <param name="ACref">Original cref attribute value.</param>
    /// <param name="AContext">Declaration containing the reference.</param>
    /// <returns>Resolved full name, or the original reference if resolution fails.</returns>
    function ResolveReference(const Cref,UnitName:string):string;
    function ResolveCref(const ACref: string; const AContext: TElementDocInfo): string;

    /// <summary>Resolves references across the supplied units.</summary>
    /// <param name="AUnits">Units to process.</param>
    procedure ResolveAllRefs(const AUnits: TObjectList<TUnitDocInfo>);

    property Unresolved: TList<TUnresolvedRef> read FUnresolved;
  end;

implementation

uses Xml.XMLIntf,XmlDoc.XmlFragments;

{ TCrossRefResolver }

constructor TCrossRefResolver.Create(ASymbolIndex: TDictionary<string, TElementDocInfo>);
begin
  inherited Create;

  FSymbolIndex := ASymbolIndex;
  FUnresolved := TList<TUnresolvedRef>.Create;
end;

destructor TCrossRefResolver.Destroy;
begin
  FUnresolved.Free;

  inherited;
end;

function TCrossRefResolver.TryResolve(const ACref,AContextUnit:string):string;
var Pair:TPair<string,TElementDocInfo>;Found:TElementDocInfo;Candidate:TElementDocInfo;
begin
 Result:='';Found:=nil;
 if FSymbolIndex.TryGetValue(ACref,Found) then begin
  if Found.CodeElement.IsOverload then Exit(Found.CodeElement.SymbolId);Exit(Found.FullName);end;
 for Pair in FSymbolIndex do begin
  Candidate:=Pair.Value;
  if SameText(Pair.Key,ACref) or SameText(Candidate.FullName,ACref) or SameText(Candidate.CodeElement.Signature,ACref) or
   SameText(Candidate.FullName,AContextUnit+'.'+ACref) or Candidate.FullName.EndsWith('.'+ACref,True) then begin
   if Assigned(Found) and (Found<>Candidate) then Exit('');Found:=Candidate;
  end;
 end;
 if Assigned(Found) then begin if Found.CodeElement.IsOverload then Result:=Found.CodeElement.SymbolId else Result:=Found.FullName;end;
end;

function TCrossRefResolver.ResolveReference(const Cref,UnitName:string):string;
begin Result:=TryResolve(Cref,UnitName);end;

function TCrossRefResolver.ResolveCref(const ACref: string; const AContext: TElementDocInfo): string;
var
  LContextUnit: string;
  LDotPos: Integer;
begin
  if ACref = '' then
  begin
    Result := '';
    Exit;
  end;

  // 컨텍스트에서 유닛 이름 추출
  LContextUnit := '';
  if Assigned(AContext) and (AContext.FullName <> '') then
  begin
    LDotPos := Pos('.', AContext.FullName);
    if LDotPos > 0 then
      LContextUnit := Copy(AContext.FullName, 1, LDotPos - 1);
  end;

  Result := TryResolve(ACref, LContextUnit);
  if Result = '' then
    Result := ACref;  // 해석 실패 시 원본 반환
end;

procedure TCrossRefResolver.ResolveAllRefs(const AUnits: TObjectList<TUnitDocInfo>);
  procedure Check(Model:TXmlDocModel;const Element:TCodeElementInfo;const Name,UnitName,FileName:string);
  var Doc:IXMLDocument;Ref:TUnresolvedRef;I:Integer;See:TSeeAlsoDoc;Exc:TExceptionDoc;Resolved:string;
    procedure Visit(Node:IXMLNode);
    var J:Integer;Child:IXMLNode;Target:string;
    begin
      for J:=0 to Node.ChildNodes.Count-1 do begin
        Child:=Node.ChildNodes[J];if Child.NodeType<>ntElement then Continue;
        if Child.HasAttribute('cref') then begin
          Target:=Child.Attributes['cref'];
          if (Target<>'') and (TryResolve(Target,UnitName)='') then begin
            Ref:=Default(TUnresolvedRef);Ref.Cref:=Target;Ref.SourceElement:=Name;Ref.SourceFile:=FileName;
            Ref.Line:=Element.CommentStartLine;if Ref.Line<1 then Ref.Line:=Element.LineNumber;
            FUnresolved.Add(Ref);
          end;
        end;
        Visit(Child);
      end;
    end;
  begin
    if Model.ParseError<>'' then Exit;
    Doc:=LoadDocXml('<doc>'+Model.ToXml+'</doc>');Visit(Doc.DocumentElement);
    for I:=0 to Model.SeeAlso.Count-1 do begin
      See:=Model.SeeAlso[I];Resolved:=TryResolve(See.Cref,UnitName);
      if Resolved<>'' then begin See.Cref:=Resolved;Model.SeeAlso[I]:=See;end;
    end;
    for I:=0 to Model.Exceptions.Count-1 do begin
      Exc:=Model.Exceptions[I];Resolved:=TryResolve(Exc.TypeRef,UnitName);
      if Resolved<>'' then begin Exc.TypeRef:=Resolved;Model.Exceptions[I]:=Exc;end;
    end;
  end;
  procedure CheckType(Typ:TTypeDocInfo;UnitDoc:TUnitDocInfo);
  var Member:TElementDocInfo;Nested:TTypeDocInfo;
  begin
    Check(Typ.Doc,Typ.CodeElement,Typ.FullName,UnitDoc.UnitName,UnitDoc.FilePath);
    for Member in Typ.Members do Check(Member.Doc,Member.CodeElement,Member.FullName,UnitDoc.UnitName,UnitDoc.FilePath);
    for Nested in Typ.NestedTypes do CheckType(Nested,UnitDoc);
  end;
var UnitDoc:TUnitDocInfo;Typ:TTypeDocInfo;Element:TElementDocInfo;
begin
  FUnresolved.Clear;
  for UnitDoc in AUnits do begin
    Check(UnitDoc.UnitDoc,UnitDoc.UnitElement,UnitDoc.UnitName,UnitDoc.UnitName,UnitDoc.FilePath);
    for Typ in UnitDoc.Types do CheckType(Typ,UnitDoc);
    for Element in UnitDoc.StandaloneMethods do Check(Element.Doc,Element.CodeElement,Element.FullName,UnitDoc.UnitName,UnitDoc.FilePath);
    for Element in UnitDoc.Constants do Check(Element.Doc,Element.CodeElement,Element.FullName,UnitDoc.UnitName,UnitDoc.FilePath);
    for Element in UnitDoc.Variables do Check(Element.Doc,Element.CodeElement,Element.FullName,UnitDoc.UnitName,UnitDoc.FilePath);
  end;
end;

end.
