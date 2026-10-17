unit TestDocNavigation;
interface
uses DUnitX.TestFramework;
type
 [TestFixture] TTestDocNavigation=class
 public
  [Test] procedure TestGroupsAndStableNumericMapping;
  [Test] procedure TestNumericExportsWithLongSymbols;
  [Test] procedure TestFailedCompilerRemovesPartialOutput;
  [Test] procedure TestCHMPathBudget;
 end;
implementation
uses System.SysUtils,System.Classes,System.IOUtils,System.JSON,System.Generics.Collections,
 XmlDoc.Consts,XmlDoc.HelpGen.Types,XmlDoc.HelpGen.Navigation,XmlDoc.HelpGen.Renderer,
 XmlDoc.HelpGen.Renderer.HTML,XmlDoc.HelpGen.Renderer.MD,XmlDoc.HelpGen.Renderer.CHM,
 XmlDoc.HelpGen.Renderer.HMXP,XmlDoc.HelpGen.SitePublisher;
function Child(N:TDocNavNode;const Caption:string):TDocNavNode;
var C:TDocNavNode;
begin
 for C in N.Children do if C.Caption=Caption then Exit(C);
 raise Exception.Create('Missing navigation node '+Caption);
end;
function NewType(U:TUnitDocInfo;const Name:string;Kind:TDocElementKind):TTypeDocInfo;
begin
 Result:=TTypeDocInfo.Create;Result.Name:=Name;Result.Kind:=Kind;
 Result.FullName:=U.UnitName+'.'+Name;U.Types.Add(Result);
end;
procedure TTestDocNavigation.TestGroupsAndStableNumericMapping;
var Units:TObjectList<TUnitDocInfo>;U:TUnitDocInfo;T,Nested:TTypeDocInfo;E:TElementDocInfo;
 Root:TDocNavNode;First,Second:TTopicNameMap;A,B:string;
begin
 Units:=TObjectList<TUnitDocInfo>.Create(True);
 try
  U:=TUnitDocInfo.Create;U.UnitName:='Z.Unit';Units.Add(U);
  T:=NewType(U,'ZClass',dekClass);
  NewType(U,'ARecord',dekRecord);NewType(U,'AClass',dekClass);
  E:=TElementDocInfo.Create;E.Name:='ZMethod';E.Kind:=dekMethod;T.Members.Add(E);
  E:=TElementDocInfo.Create;E.Name:='Create';E.Kind:=dekMethod;E.CodeElement.MethodKind:='constructor';T.Members.Add(E);
  E:=TElementDocInfo.Create;E.Name:='AProperty';E.Kind:=dekProperty;T.Members.Add(E);
  Nested:=TTypeDocInfo.Create;Nested.Name:='Inner';Nested.Kind:=dekRecord;Nested.FullName:=T.FullName+'.Inner';T.NestedTypes.Add(Nested);
  First:=TTopicNameMap.Create(Units,True);
  try A:=First.FileName(T.FullName,'.html');finally First.Free;end;
  U.Types.Exchange(0,2);SortDocumentation(Units);
  Second:=TTopicNameMap.Create(Units,True);
  try B:=Second.FileName(T.FullName,'.html');finally Second.Free;end;
  Assert.AreEqual(A,B);
  Root:=BuildNavigation(Units,'Demo','.html',False,True);
  try
   Assert.AreEqual('AClass',Child(Child(Root,'Z.Unit'),'Classes').Children[0].Caption);
   T:=U.Types[1];
   Assert.AreEqual('ZClass',T.Name);
   Assert.AreEqual('Create',T.Members[0].Name);
   Assert.AreEqual('Create',Child(Child(Child(Child(Root,'Z.Unit'),'Classes'),'ZClass'),'Constructors').Children[0].Caption);
   Assert.AreEqual('Inner',Child(Child(Child(Child(Root,'Z.Unit'),'Classes'),'ZClass'),'Records').Children[0].Caption);
  finally Root.Free;end;
 finally Units.Free;end;
end;
procedure TTestDocNavigation.TestNumericExportsWithLongSymbols;
var Units:TObjectList<TUnitDocInfo>;U:TUnitDocInfo;T:TTypeDocInfo;E:TElementDocInfo;
 Root,Name,FileName,Text:string;Options:TRenderOptions;Renderer:IDocRenderer;Files:TArray<string>;
 Map:TTopicNameMap;Pub:TSitePublisher;Site:TSitePublishOptions;Kind:TSiteGenerator;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);
 Units:=TObjectList<TUnitDocInfo>.Create(True);
 try
  U:=TUnitDocInfo.Create;U.UnitName:='Unit'+StringOfChar('U',96);Units.Add(U);
  T:=NewType(U,'T'+StringOfChar('C',199),dekClass);
  E:=TElementDocInfo.Create;E.Name:='M'+StringOfChar('A',179);E.Kind:=dekMethod;E.FullName:=T.FullName+'.'+E.Name;T.Members.Add(E);
  Map:=TTopicNameMap.Create(Units,True);
  try Name:=Map.FileName(T.FullName,'.html');finally Map.Free;end;
  Options:=Default(TRenderOptions);Options.OutputDir:=Root;Options.ProjectName:='LongNames';Options.Title:='Long names';Options.NumericFileNames:=True;
  Renderer:=THTMLDocRenderer.Create;Renderer.Render(Units,nil,Options);
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'units/'+Name)));
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'topic-map.json')));
  Text:=TFile.ReadAllText(TPath.Combine(Root,'index.html'));
  Assert.IsTrue(Text.Contains('Classes'));Assert.IsTrue(Text.Contains('Methods'));
  Renderer:=TMarkdownDocRenderer.Create;Renderer.Render(Units,nil,Options);
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'units/'+ChangeFileExt(Name,'.md'))));
  Renderer:=THMXPDocRenderer.Create;Renderer.Render(Units,nil,Options);
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'hmxp/Topics/T000001.xml')));
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'hmxp/Baggage/topic-map.json')));
  Renderer:=TCHMDocRenderer.Create;
  try Renderer.Render(Units,nil,Options);
  except on X:ECHMBuildError do if not X.Message.Contains('was not found') then raise;end;
  Files:=TDirectory.GetFiles(TPath.Combine(Root,'_chm_html/units'),'*.html');
  for FileName in Files do Assert.IsTrue(Length(ExtractFileName(FileName))<32);
  Text:=TFile.ReadAllText(TPath.Combine(Root,'LongNames.hhc'));
  Assert.IsTrue(Text.Contains('Classes'));Assert.IsTrue(Text.Contains('Methods'));
  Options.NumericFileNames:=False;
  Options.OutputDir:=TPath.Combine(Root,'hashed-chm');
  Renderer:=TCHMDocRenderer.Create;
  try Renderer.Render(Units,nil,Options);
  except on X:ECHMBuildError do if not X.Message.Contains('was not found') then raise;end;
  Map:=TTopicNameMap.Create(Units,True,False);
  try FileName:=Map.FileName(T.FullName,'.html');finally Map.Free;end;
  Assert.IsTrue(Length(FileName)<80);
  Assert.IsTrue(TFile.Exists(TPath.Combine(Options.OutputDir,'_chm_html/units/'+FileName)));
  Options.NumericFileNames:=True;Options.OutputDir:=Root;
  Pub:=TSitePublisher.Create;
  try
   Site:=Default(TSitePublishOptions);Site.SiteName:=Options.Title;
   for Kind:=Low(TSiteGenerator) to High(TSiteGenerator) do begin Site.Generator:=Kind;Pub.Publish(Units,nil,Site,Options);end;
  finally Pub.Free;end;
  Text:=TFile.ReadAllText(TPath.Combine(Root,'site-mkdocs/mkdocs.yml'));
  Assert.IsTrue(Text.Contains('Classes'));Assert.IsTrue(Text.Contains('t000'));
  Assert.IsFalse(Text.Contains('#'),'MkDocs nav must contain pages, not member anchors');
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'site-docusaurus/sidebars.js')));
 finally Renderer:=nil;Units.Free;if TDirectory.Exists(Root) then TDirectory.Delete(Root,True);end;
end;
procedure TTestDocNavigation.TestFailedCompilerRemovesPartialOutput;
var Units:TObjectList<TUnitDocInfo>;U:TUnitDocInfo;Root:string;Options:TRenderOptions;
 Renderer:IDocRenderer;Raised:Boolean;
begin
 Root:=TPath.Combine(TPath.GetTempPath,TPath.GetRandomFileName);
 Units:=TObjectList<TUnitDocInfo>.Create(True);
 try
  U:=TUnitDocInfo.Create;U.UnitName:='TestUnit';Units.Add(U);
  Options:=Default(TRenderOptions);Options.OutputDir:=Root;Options.ProjectName:='Partial';Options.Title:='Failure test';
  Assert.IsTrue(TFile.Exists(TPath.Combine(ExtractFilePath(ParamStr(0)),'FakeHHC.exe')));
  Renderer:=TCHMDocRenderer.Create(TPath.Combine(ExtractFilePath(ParamStr(0)),'FakeHHC.exe'));
  Raised:=False;
  try Renderer.Render(Units,nil,Options);
  except on E:ECHMBuildError do begin Raised:=True;Assert.IsTrue(E.Message.Contains('exit 0'));end;end;
  Assert.IsTrue(Raised,'Compiler failure must reach the caller');
  Assert.IsFalse(TFile.Exists(TPath.Combine(Root,'Partial.chm')));
  Assert.IsTrue(TFile.Exists(TPath.Combine(Root,'Partial.hhp')));
  Assert.IsTrue(TFile.ReadAllText(TPath.Combine(Root,'chm-compiler.log')).Contains('simulated compiler failure'));
 finally Renderer:=nil;Units.Free;if TDirectory.Exists(Root) then TDirectory.Delete(Root,True);end;
end;
procedure TTestDocNavigation.TestCHMPathBudget;
var Units:TObjectList<TUnitDocInfo>;Options:TRenderOptions;Renderer:IDocRenderer;Raised:Boolean;
begin
 Units:=TObjectList<TUnitDocInfo>.Create(True);
 try
  Options:=Default(TRenderOptions);Options.OutputDir:=TPath.Combine(TPath.GetTempPath,StringOfChar('L',220));Options.ProjectName:='Budget';
  Renderer:=TCHMDocRenderer.Create;Raised:=False;
  try Renderer.Render(Units,nil,Options);
  except on E:ECHMBuildError do begin Raised:=True;Assert.IsTrue(E.Message.Contains('shorter than 260'));end;end;
  Assert.IsTrue(Raised,'Long destination must be rejected before filesystem/compiler calls');
 finally Renderer:=nil;Units.Free;end;
end;
initialization
 TDUnitX.RegisterTestFixture(TTestDocNavigation);
end.
