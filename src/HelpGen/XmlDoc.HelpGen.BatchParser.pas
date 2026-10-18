unit XmlDoc.HelpGen.BatchParser;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  XmlDoc.Consts,
  XmlDoc.Model,
  XmlDoc.Parser,
  XmlDoc.HelpGen.Types;

type
  /// <summary>다수의 .pas 파일을 배치 파싱하여 유닛/타입/멤버 문서 계층을 구축합니다.</summary>
  TBatchParser = class
  private
    FSymbolIndex: TDictionary<string, TElementDocInfo>;
    FUnits: TObjectList<TUnitDocInfo>;
    FSourceFiles,FSearchPaths,FDefines:TArray<string>;
    FSnapshots:TArray<TSourceSnapshot>;
    FPlatform:string;
    FConfigure:TProc<TDocParser,string>;
    FParsedElements:TFunc<string,TArray<TCodeElementInfo>>;
    FIndexOwners:TObjectList<TElementDocInfo>;

    FOnProgress: TProgressCallback;

    procedure BuildSymbolIndex;
    procedure ParseUnit(const AFilePath: string);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>파일 목록을 모두 파싱합니다.</summary>
    /// <param name="AFiles">절대 경로 .pas 파일 배열</param>
    procedure ParseAll(const AFiles: TArray<string>);

    property ParsedElements:TFunc<string,TArray<TCodeElementInfo>> read FParsedElements write FParsedElements;
    property OnConfigureParser:TProc<TDocParser,string> read FConfigure write FConfigure;
    property Platform:string read FPlatform write FPlatform;
    property SourceSnapshots:TArray<TSourceSnapshot> read FSnapshots write FSnapshots;
    property SearchPaths:TArray<string> read FSearchPaths write FSearchPaths;
    property Defines:TArray<string> read FDefines write FDefines;
    property SymbolIndex: TDictionary<string, TElementDocInfo> read FSymbolIndex;
    property Units: TObjectList<TUnitDocInfo> read FUnits;

    property OnProgress: TProgressCallback read FOnProgress write FOnProgress;
  end;

implementation

uses
  System.IOUtils,XmlDoc.HelpGen.Inheritance,XmlDoc.SourceText;

{ TBatchParser }

constructor TBatchParser.Create;
begin
  inherited Create;

  FUnits := TObjectList<TUnitDocInfo>.Create(True);
  FIndexOwners:=TObjectList<TElementDocInfo>.Create(True);
  FSymbolIndex := TDictionary<string, TElementDocInfo>.Create;
end;

destructor TBatchParser.Destroy;
begin
  FIndexOwners.Free;
  FSymbolIndex.Free;
  FUnits.Free;

  inherited;
end;

procedure TBatchParser.BuildSymbolIndex;
var U:TUnitDocInfo;T:TTypeDocInfo;E,IndexItem:TElementDocInfo;Ambiguous:TDictionary<string,Boolean>;
 procedure Add(Element:TElementDocInfo);
 begin
  if Element.CodeElement.SymbolId<>'' then FSymbolIndex.AddOrSetValue(Element.CodeElement.SymbolId,Element);
  if Element.FullName='' then Exit;
  if FSymbolIndex.ContainsKey(Element.FullName) then begin FSymbolIndex.Remove(Element.FullName);Ambiguous.AddOrSetValue(Element.FullName,True);end
  else if not Ambiguous.ContainsKey(Element.FullName) then FSymbolIndex.Add(Element.FullName,Element);
 end;
 procedure IndexType(Typ:TTypeDocInfo);
 var M:TElementDocInfo;N:TTypeDocInfo;
 begin
  M:=TElementDocInfo.Create;FIndexOwners.Add(M);M.FullName:=Typ.FullName;M.Name:=Typ.Name;M.Kind:=Typ.Kind;
  M.CodeElement:=Typ.CodeElement;M.Doc.Assign(Typ.Doc);Add(M);
  for M in Typ.Members do Add(M);
  for N in Typ.NestedTypes do IndexType(N);
 end;
begin
 FSymbolIndex.Clear;FIndexOwners.Clear;Ambiguous:=TDictionary<string,Boolean>.Create;
 try
  for U in FUnits do begin
   IndexItem:=TElementDocInfo.Create;FIndexOwners.Add(IndexItem);IndexItem.FullName:=U.UnitName;
   IndexItem.Name:=U.UnitName;IndexItem.Kind:=dekUnit;IndexItem.CodeElement:=U.UnitElement;IndexItem.Doc.Assign(U.UnitDoc);Add(IndexItem);
   for E in U.StandaloneMethods do Add(E);for E in U.Constants do Add(E);for E in U.Variables do Add(E);
   for T in U.Types do IndexType(T);
  end;
 finally Ambiguous.Free;end;
end;

procedure TBatchParser.ParseUnit(const AFilePath: string);
var
  LDocParser: TDocParser;
  LSource: string;
  LElements: TArray<TCodeElementInfo>;
  LUnitDoc: TUnitDocInfo;
  LTypeDoc: TTypeDocInfo;
  LElem: TElementDocInfo;
  LTypeMap: TDictionary<string, TTypeDocInfo>;
  LImplLine: Integer;
  LLines: TArray<string>;
  I: Integer;
  LCodeElem: TCodeElementInfo;
  LLine, LTypeKey: string;
begin
  LSource:='';var HasSnapshot:=False;for var Snapshot in FSnapshots do if SameText(Snapshot.FileName,AFilePath) then begin LSource:=Snapshot.Source;HasSnapshot:=True;Break;end;
  if not HasSnapshot then LSource := ReadSourceFile(AFilePath);
  for var Snapshot in FSnapshots do if SameText(Snapshot.FileName,AFilePath) then begin LSource:=Snapshot.Source;Break;end;

  // TDocParser로 소스 파싱
  LDocParser := TDocParser.Create;
  try
    try
      LDocParser.Platform:=FPlatform;LDocParser.SourceSnapshots:=FSnapshots;LDocParser.SourceFiles:=FSourceFiles;LDocParser.SearchPaths:=FSearchPaths;LDocParser.Defines:=FDefines;
      if Assigned(FConfigure) then FConfigure(LDocParser,AFilePath);
      if not Assigned(FParsedElements) then LDocParser.ParseSource(LSource,AFilePath);
    except
      on E:Exception do raise Exception.CreateFmt('Cannot parse %s: %s', [AFilePath,E.Message]);
    end;

    if not Assigned(FParsedElements) and not Assigned(LDocParser.RootNode) then
      Exit;

    if Assigned(FParsedElements) then LElements:=FParsedElements(AFilePath) else LElements := LDocParser.GetAllElements;

    LUnitDoc := TUnitDocInfo.Create;
    LUnitDoc.FilePath := AFilePath;
    LUnitDoc.UnitName := TPath.GetFileNameWithoutExtension(AFilePath);

    // 타입 맵: 타입 이름 → TTypeDocInfo (멤버 연결용)
    LTypeMap := TDictionary<string, TTypeDocInfo>.Create;
    try
      for I := 0 to Length(LElements) - 1 do
      begin
        LCodeElem := LElements[I];

        // implementation 섹션 이후 요소는 스킵
        if LCodeElem.SourceSection='implementation' then
          Continue;

        // 이름이 없는 요소는 스킵
        if LCodeElem.Name = '' then
          Continue;

        case LCodeElem.Kind of
          dekUnit:
          begin
            LUnitDoc.UnitElement := LCodeElem;
            LUnitDoc.UnitName := LCodeElem.Name;
            if LCodeElem.ExistingDocXml <> '' then
              LUnitDoc.UnitDoc.LoadFromXml(LCodeElem.ExistingDocXml);
          end;
          dekClass, dekRecord, dekInterface, dekType:
          begin
            LTypeDoc := TTypeDocInfo.Create;
            LTypeDoc.CodeElement:=LCodeElem;LTypeDoc.Visibility:=LCodeElem.Visibility;
            LTypeDoc.Ancestor:=LCodeElem.Ancestor;LTypeDoc.Implements:=Copy(LCodeElem.Implements);
            LTypeDoc.Name := LCodeElem.Name;
            LTypeKey := LCodeElem.Name;
            if LCodeElem.QualifiedParent <> '' then
              LTypeKey := LCodeElem.QualifiedParent + '.' + LTypeKey;
            LTypeDoc.FullName := LUnitDoc.UnitName + '.' + LTypeKey;
            LTypeDoc.Kind := LCodeElem.Kind;

            if LCodeElem.ExistingDocXml <> '' then
              LTypeDoc.Doc.LoadFromXml(LCodeElem.ExistingDocXml);

            if (LCodeElem.QualifiedParent <> '') and LTypeMap.ContainsKey(LCodeElem.QualifiedParent) then
              LTypeMap[LCodeElem.QualifiedParent].NestedTypes.Add(LTypeDoc)
            else LUnitDoc.Types.Add(LTypeDoc);
            LTypeMap.AddOrSetValue(LTypeKey, LTypeDoc);
            if Length(LCodeElem.GenericParams)>0 then LTypeMap.AddOrSetValue(LTypeKey+'<'+string.Join(',',LCodeElem.GenericParams)+'>',LTypeDoc);
          end;

          dekMethod, dekProperty, dekField:
          begin
            LElem := TElementDocInfo.Create;
            LElem.Name := LCodeElem.Name;
            LElem.Kind := LCodeElem.Kind;
            LElem.Visibility := LCodeElem.Visibility;
            LElem.CodeElement := LCodeElem;LElem.Signature:=LCodeElem.Signature;

            if LCodeElem.ExistingDocXml <> '' then
              LElem.Doc.LoadFromXml(LCodeElem.ExistingDocXml);

            // QualifiedParent가 있으면 해당 타입의 멤버
            if (LCodeElem.QualifiedParent <> '') and
               LTypeMap.ContainsKey(LCodeElem.QualifiedParent) then
            begin
              LElem.FullName := LUnitDoc.UnitName + '.' +
                LCodeElem.QualifiedParent + '.' + LCodeElem.Name;
              LTypeMap[LCodeElem.QualifiedParent].Members.Add(LElem);
            end
            else
            begin
              LElem.FullName := LUnitDoc.UnitName + '.' + LCodeElem.Name;
              LUnitDoc.StandaloneMethods.Add(LElem);
            end;
          end;

          dekConstant:
          begin
            LElem := TElementDocInfo.Create;
            LElem.Name := LCodeElem.Name;
            LElem.Kind := dekConstant;
            LElem.Visibility := LCodeElem.Visibility;
            LElem.CodeElement := LCodeElem;LElem.Signature:=LCodeElem.Signature;

            if LCodeElem.ExistingDocXml <> '' then
              LElem.Doc.LoadFromXml(LCodeElem.ExistingDocXml);

            if (LCodeElem.QualifiedParent <> '') and
               LTypeMap.ContainsKey(LCodeElem.QualifiedParent) then
            begin
              LElem.FullName := LUnitDoc.UnitName + '.' +
                LCodeElem.QualifiedParent + '.' + LCodeElem.Name;
              LTypeMap[LCodeElem.QualifiedParent].Members.Add(LElem);
            end
            else
            begin
              LElem.FullName := LUnitDoc.UnitName + '.' + LCodeElem.Name;
              LUnitDoc.Constants.Add(LElem);
            end;
          end;
        end;
      end;
    finally
      LTypeMap.Free;
    end;

    FUnits.Add(LUnitDoc);
  finally
    LDocParser.Free;
  end;
end;

procedure TBatchParser.ParseAll(const AFiles: TArray<string>);
var
  I: Integer;
begin
  FUnits.Clear;
  FSymbolIndex.Clear;
  FSourceFiles:=Copy(AFiles);

  for I := 0 to Length(AFiles) - 1 do
  begin
    if Assigned(FOnProgress) then
      FOnProgress(I + 1, Length(AFiles), ExtractFileName(AFiles[I]));

    ParseUnit(AFiles[I]);
  end;

  var Inheritance:=TInheritanceResolver.Create;
  try Inheritance.Apply(FUnits);finally Inheritance.Free;end;
  BuildSymbolIndex;
end;

end.
