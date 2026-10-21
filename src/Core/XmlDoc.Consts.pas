/// <summary>Shared declaration metadata and structured documentation records.</summary>
unit XmlDoc.Consts;

interface

uses
  System.SysUtils;

type
  /// <summary>Kinds of declarations supported by the documentation tools.</summary>
  TDocElementKind = (
    dekUnit,
    dekClass,
    dekRecord,
    dekInterface,
    dekMethod,
    dekProperty,
    dekField,
    dekType,
    dekConstant
  );

  /// <summary>A parameter name and its description.</summary>
  TParamDoc = record
    Name: string;
    Description: string;
  end;

  /// <summary>A generic type parameter and its description.</summary>
  TTypeParamDoc = record
    Name: string;
    Description: string;
  end;

  /// <summary>An exception reference and its description.</summary>
  TExceptionDoc = record
    TypeRef: string;
    Description: string;
  end;

  /// <summary>An example with optional source and region metadata.</summary>
  TExampleDoc = record
    SourceFile,Region:string;
    Title: string;
    Code: string;
    Description: string;
  end;

  /// <summary>A related-symbol reference and optional display text.</summary>
  TSeeAlsoDoc = record
    Cref: string;
    Description: string;
  end;

  /// <summary>Parameter signature extracted from source.</summary>
  TParamInfo = record
    Name: string;
    TypeName: string;
    DefaultValue: string;
    HasDefault:Boolean;
    IsConst: Boolean;
    IsVar: Boolean;
    IsOut: Boolean;
  end;

  /// <summary>Declaration metadata, documentation and source ranges extracted by the parser.</summary>
  TCodeElementInfo = record
    Kind: TDocElementKind;
    Name: string;
    FullName: string;
    SymbolId: string;
    UnitName,CanonicalName:string;
    SourceSection:string;
    IsOverload,IsReintroduce:Boolean;
    MethodBinding:string;
    FileName: string;
    Signature: string;
    Ancestor: string;
    Implements: TArray<string>;
    QualifiedParent: string;
    Visibility: string;
    Params: TArray<TParamInfo>;
    ReturnType: string;
    GenericParams: TArray<string>;
    MethodKind: string;
    LineNumber: Integer;
    EndLineNumber: Integer;
    IndentLevel: Integer;
    CommentStartLine: Integer;
    CommentEndLine: Integer;
    ExistingDocXml: string;
    IsLegacyComment: Boolean;
  end;

  TSourceSnapshot=record
    FileName,Source:string;
  end;

  /// <summary>Helpers for declaration kind names and JSON metadata.</summary>
  TDocElementKindHelper = record helper for TDocElementKind
    function ToString: string;
    class function FromString(const AValue: string): TDocElementKind; static;
  end;

function MemberAnchor(const Element:TCodeElementInfo;const Name:string):string;

implementation

uses System.Hash;

function MemberAnchor(const Element:TCodeElementInfo;const Name:string):string;
begin
 if Element.IsOverload and (Element.SymbolId<>'') then Result:='m'+Copy(THashSHA2.GetHashString(Element.SymbolId),1,20) else Result:=Name;
end;

{ TDocElementKindHelper }

class function TDocElementKindHelper.FromString(const AValue: string): TDocElementKind;
var
  LValue: string;
begin
  LValue := LowerCase(AValue);
  if LValue = 'unit' then
    Result := dekUnit
  else if LValue = 'class' then
    Result := dekClass
  else if LValue = 'record' then
    Result := dekRecord
  else if LValue = 'interface' then
    Result := dekInterface
  else if LValue = 'method' then
    Result := dekMethod
  else if LValue = 'property' then
    Result := dekProperty
  else if LValue = 'field' then
    Result := dekField
  else if LValue = 'type' then
    Result := dekType
  else if LValue = 'constant' then
    Result := dekConstant
  else
    Result := dekType;
end;

function TDocElementKindHelper.ToString: string;
begin
  case Self of
    dekUnit:      Result := 'unit';
    dekClass:     Result := 'class';
    dekRecord:    Result := 'record';
    dekInterface: Result := 'interface';
    dekMethod:    Result := 'method';
    dekProperty:  Result := 'property';
    dekField:     Result := 'field';
    dekType:      Result := 'type';
    dekConstant:  Result := 'constant';
  else
    Result := 'unknown';
  end;
end;

end.
