/// <summary>Hierarchical navigation and stable topic filename mapping shared by output formats.</summary>
unit XmlDoc.HelpGen.Navigation;

interface
uses System.SysUtils, System.Classes, System.Generics.Collections, System.JSON,
  XmlDoc.Consts, XmlDoc.HelpGen.Types;
type
  TTopicNameMap = class
  private
    FNames: TDictionary<string, string>;
    FEnabled: Boolean;
  public
    constructor Create(Units: TObjectList<TUnitDocInfo>; Enabled: Boolean; Numeric: Boolean = True);
    destructor Destroy; override;
    function FileName(const FullName, Extension: string): string;
    procedure Save(const Path: string);
  end;
  TDocNavNode = class
  public
    Caption, Target, SymbolName: string;
    Children: TObjectList<TDocNavNode>;
    constructor Create(const ACaption, ATarget: string);
    destructor Destroy; override;
    function ToJSON(IncludeLinks: Boolean = True): TJSONObject;
  end;
function TypeGroup(AKind: TDocElementKind): string;
function MemberGroup(AElement: TElementDocInfo): string;
procedure SortDocumentation(AUnits: TObjectList<TUnitDocInfo>);
function BuildNavigation(AUnits: TObjectList<TUnitDocInfo>; const ATitle,
  AExtension: string; ACompact: Boolean = False; ANumeric: Boolean = False): TDocNavNode;

implementation
uses System.Generics.Defaults, System.Hash, System.IOUtils;

constructor TTopicNameMap.Create(Units: TObjectList<TUnitDocInfo>; Enabled: Boolean; Numeric: Boolean);
var Names: TStringList; U: TUnitDocInfo; T: TTypeDocInfo; I: Integer;
  procedure AddType(AType: TTypeDocInfo; const Scope: string);
  var Child: TTypeDocInfo; FullName: string;
  begin
    FullName := AType.FullName;
    if FullName = '' then FullName := Scope + '.' + AType.Name;
    Names.Add(FullName);
    for Child in AType.NestedTypes do AddType(Child, FullName);
  end;
begin
  inherited Create; FEnabled := Enabled;
  FNames := TDictionary<string, string>.Create;
  Names := TStringList.Create;
  try
    Names.Sorted := True; Names.CaseSensitive := True; Names.Duplicates := dupIgnore;
    for U in Units do begin
      Names.Add(U.UnitName);
      for T in U.Types do AddType(T, U.UnitName);
    end;
    for I := 0 to Names.Count - 1 do
      if Numeric then FNames.Add(Names[I], Format('t%.6d', [I + 1]))
      else FNames.Add(Names[I], 't_' + LowerCase(THashSHA2.GetHashString(Names[I])));
  finally Names.Free; end;
end;
destructor TTopicNameMap.Destroy;
begin FNames.Free; inherited; end;
function TTopicNameMap.FileName(const FullName, Extension: string): string;
begin
  if not FEnabled then Exit(FullName + Extension);
  if not FNames.TryGetValue(FullName, Result) then
    raise Exception.Create('No topic filename mapping for ' + FullName);
  Result := Result + Extension;
end;
procedure TTopicNameMap.Save(const Path: string);
var J: TJSONObject; P: TPair<string, string>;
begin
  if not FEnabled then Exit;
  J := TJSONObject.Create;
  try
    for P in FNames do J.AddPair(P.Key, P.Value);
    TFile.WriteAllBytes(Path, TEncoding.UTF8.GetBytes(J.Format(2)));
  finally J.Free; end;
end;

constructor TDocNavNode.Create(const ACaption, ATarget: string);
begin
  inherited Create;
  Caption := ACaption; Target := ATarget;
  Children := TObjectList<TDocNavNode>.Create(True);
end;
destructor TDocNavNode.Destroy;
begin Children.Free; inherited; end;
function TDocNavNode.ToJSON(IncludeLinks: Boolean): TJSONObject;
var A: TJSONArray; N: TDocNavNode;
begin
  Result := TJSONObject.Create;
  Result.AddPair('text', Caption);
  if IncludeLinks and (Target <> '') then Result.AddPair('link', Target);
  if SymbolName <> '' then Result.AddPair('symbol', SymbolName);
  if Children.Count > 0 then begin
    A := TJSONArray.Create;
    for N in Children do A.AddElement(N.ToJSON(IncludeLinks));
    Result.AddPair('items', A);
  end;
end;
function TypeGroup(AKind: TDocElementKind): string;
begin
  case AKind of
    dekClass: Result := 'Classes';
    dekInterface: Result := 'Interfaces';
    dekRecord: Result := 'Records';
  else Result := 'Types'; end;
end;
function MemberGroup(AElement: TElementDocInfo): string;
begin
  case AElement.Kind of
    dekProperty: Result := 'Properties';
    dekField: Result := 'Fields';
    dekConstant: Result := 'Constants';
    dekType: Result := 'Types';
  else
    if SameText(AElement.CodeElement.MethodKind, 'constructor') then Result := 'Constructors'
    else if SameText(AElement.CodeElement.MethodKind, 'destructor') then Result := 'Destructors'
    else Result := 'Methods';
  end;
end;
procedure SortDocumentation(AUnits: TObjectList<TUnitDocInfo>);
var U: TUnitDocInfo;
  procedure SortTypes(Types: TObjectList<TTypeDocInfo>);
  var T: TTypeDocInfo;
  begin
    Types.Sort(TComparer<TTypeDocInfo>.Construct(
      function(const L, R: TTypeDocInfo): Integer
      begin
        Result := CompareText(TypeGroup(L.Kind), TypeGroup(R.Kind));
        if Result = 0 then Result := CompareText(L.Name, R.Name);
        if Result = 0 then Result := CompareStr(L.FullName, R.FullName);
      end));
    for T in Types do begin
      T.Members.Sort(TComparer<TElementDocInfo>.Construct(
        function(const L, R: TElementDocInfo): Integer
        begin
          Result := CompareText(MemberGroup(L), MemberGroup(R));
          if Result = 0 then Result := CompareText(L.Name, R.Name);
          if Result = 0 then Result := CompareStr(L.Signature, R.Signature);
        end));
      SortTypes(T.NestedTypes);
    end;
  end;
  procedure SortElements(Elements: TObjectList<TElementDocInfo>);
  begin
    Elements.Sort(TComparer<TElementDocInfo>.Construct(
      function(const L, R: TElementDocInfo): Integer
      begin
        Result := CompareText(L.Name, R.Name);
        if Result = 0 then Result := CompareStr(L.Signature, R.Signature);
      end));
  end;
begin
  AUnits.Sort(TComparer<TUnitDocInfo>.Construct(
    function(const L, R: TUnitDocInfo): Integer
    begin Result := CompareText(L.UnitName, R.UnitName); end));
  for U in AUnits do begin
    SortTypes(U.Types); SortElements(U.StandaloneMethods);
    SortElements(U.Constants); SortElements(U.Variables);
  end;
end;
function BuildNavigation(AUnits: TObjectList<TUnitDocInfo>; const ATitle,
  AExtension: string; ACompact: Boolean; ANumeric: Boolean): TDocNavNode;
var Names: TTopicNameMap; U: TUnitDocInfo; UnitNode, Leaf: TDocNavNode; T: TTypeDocInfo; E: TElementDocInfo;
  function Group(Parent: TDocNavNode; const Name: string): TDocNavNode;
  var N: TDocNavNode;
  begin
    for N in Parent.Children do if N.Caption = Name then Exit(N);
    Result := TDocNavNode.Create(Name, ''); Parent.Children.Add(Result);
  end;
  function Anchor(const Name: string): string;
  begin
    if ACompact then Result := 'a_' + LowerCase(THashSHA2.GetHashString(Name))
    else if AExtension = '.html' then Result := Name else Result := LowerCase(Name);
  end;
  procedure AddType(Parent: TDocNavNode; AType: TTypeDocInfo; const Scope: string);
  var N, MemberNode: TDocNavNode; Child: TTypeDocInfo; M: TElementDocInfo; FullName: string;
  begin
    FullName := AType.FullName;
    if FullName = '' then FullName := Scope + '.' + AType.Name;
    N := TDocNavNode.Create(AType.Name, 'units/' + Names.FileName(FullName, AExtension));
    N.SymbolName := FullName;
    Group(Parent, TypeGroup(AType.Kind)).Children.Add(N);
    for M in AType.Members do begin
      MemberNode := TDocNavNode.Create(M.Name, N.Target + '#' + Anchor(MemberAnchor(M.CodeElement,M.Name)));
      MemberNode.SymbolName := FullName + '.' + M.Name;
      Group(N, MemberGroup(M)).Children.Add(MemberNode);
    end;
    for Child in AType.NestedTypes do AddType(N, Child, FullName);
  end;
  procedure SortNodes(N: TDocNavNode);
  var Child: TDocNavNode;
  begin
    N.Children.Sort(TComparer<TDocNavNode>.Construct(
      function(const L, R: TDocNavNode): Integer
      begin Result := CompareText(L.Caption, R.Caption); if Result=0 then Result:=CompareStr(L.Target,R.Target); end));
    for Child in N.Children do SortNodes(Child);
  end;
begin
  Names := TTopicNameMap.Create(AUnits, ACompact or ANumeric, ANumeric);
  Result := TDocNavNode.Create(ATitle, '');
  try
    try
    for U in AUnits do begin
      UnitNode := TDocNavNode.Create(U.UnitName, 'units/' + Names.FileName(U.UnitName, AExtension));
      UnitNode.SymbolName := U.UnitName;
      Result.Children.Add(UnitNode);
      for T in U.Types do AddType(UnitNode, T, U.UnitName);
      for E in U.StandaloneMethods do begin
        Leaf := TDocNavNode.Create(E.Name, UnitNode.Target+'#'+Anchor(MemberAnchor(E.CodeElement,E.Name)));
        Leaf.SymbolName := U.UnitName + '.' + E.Name;
        if E.Kind = dekField then Group(UnitNode, 'Variables').Children.Add(Leaf)
        else Group(UnitNode, 'Routines').Children.Add(Leaf);
      end;
      for E in U.Constants do
        Group(UnitNode, 'Constants').Children.Add(TDocNavNode.Create(E.Name, UnitNode.Target+'#'+Anchor(MemberAnchor(E.CodeElement,E.Name))));
      for E in U.Variables do
        Group(UnitNode, 'Variables').Children.Add(TDocNavNode.Create(E.Name, UnitNode.Target+'#'+Anchor(MemberAnchor(E.CodeElement,E.Name))));
    end;
    SortNodes(Result);
    except Result.Free; raise; end;
  finally Names.Free; end;
end;
end.
