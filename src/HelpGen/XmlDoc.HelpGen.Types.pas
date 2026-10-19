/// <summary>Owned documentation hierarchies for units, types and declarations.</summary>
unit XmlDoc.HelpGen.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  XmlDoc.Consts,
  XmlDoc.Model;

type
  TProgressCallback = reference to procedure(ACurrent, ATotal: Integer; const AMessage: string);

  /// <summary>Documentation and signature metadata for a declaration.</summary>
  TElementDocInfo = class
  public
    CodeElement: TCodeElementInfo;
    Doc: TXmlDocModel;
    FullName: string;
    Kind: TDocElementKind;
    Name: string;
    Signature: string;
    Visibility: string;

    constructor Create;
    destructor Destroy; override;
  end;

  /// <summary>A documented type and its members.</summary>
  TTypeDocInfo = class
  public
    CodeElement:TCodeElementInfo;
    Ancestor: string;
    Doc: TXmlDocModel;
    FullName: string;
    Implements: TArray<string>;
    Kind: TDocElementKind;
    Members: TObjectList<TElementDocInfo>;
    Name: string;
    NestedTypes: TObjectList<TTypeDocInfo>;
    Visibility: string;

    constructor Create;
    destructor Destroy; override;
  end;

  /// <summary>A documented unit with its types and global declarations.</summary>
  TUnitDocInfo = class
  public
    Constants: TObjectList<TElementDocInfo>;
    FilePath: string;
    StandaloneMethods: TObjectList<TElementDocInfo>;
    Types: TObjectList<TTypeDocInfo>;
    UnitDoc: TXmlDocModel;
    UnitElement: TCodeElementInfo;
    UnitName: string;
    Variables: TObjectList<TElementDocInfo>;

    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ TElementDocInfo }

constructor TElementDocInfo.Create;
begin
  inherited Create;
  Doc := TXmlDocModel.Create;
end;

destructor TElementDocInfo.Destroy;
begin
  Doc.Free;
  inherited;
end;

{ TTypeDocInfo }

constructor TTypeDocInfo.Create;
begin
  inherited Create;
  Doc := TXmlDocModel.Create;
  Members := TObjectList<TElementDocInfo>.Create(True);
  NestedTypes := TObjectList<TTypeDocInfo>.Create(True);
end;

destructor TTypeDocInfo.Destroy;
begin
  NestedTypes.Free;
  Members.Free;
  Doc.Free;
  inherited;
end;

{ TUnitDocInfo }

constructor TUnitDocInfo.Create;
begin
  inherited Create;
  UnitDoc := TXmlDocModel.Create;
  Types := TObjectList<TTypeDocInfo>.Create(True);
  StandaloneMethods := TObjectList<TElementDocInfo>.Create(True);
  Constants := TObjectList<TElementDocInfo>.Create(True);
  Variables := TObjectList<TElementDocInfo>.Create(True);
end;

destructor TUnitDocInfo.Destroy;
begin
  Variables.Free;
  Constants.Free;
  StandaloneMethods.Free;
  Types.Free;
  UnitDoc.Free;
  inherited;
end;

end.
