/// <summary>IDE theme detection, readable diagnostic colors and UI utilities.</summary>
unit XmlDoc.Plugin.Utils;

interface
uses System.Classes,Vcl.StdCtrls,Vcl.Graphics,Vcl.ExtCtrls,Vcl.Controls;

type TDocumentationErrorActions=class(TFlowPanel)
 private FMemo:TMemo;FCollapse:TButton;FExpanded:Boolean;procedure CopyDetails(Sender:TObject);procedure ToggleDetails(Sender:TObject);
 public constructor CreateForMemo(Owner:TComponent;Memo:TMemo;Retry,Navigate:TNotifyEvent);
 property Expanded:Boolean read FExpanded;
end;

/// <summary>Keep diagnostic text readable against the actual host background.</summary>
procedure ApplyDocumentationErrorTheme(Error:TMemo;Background:TColor);
function DocumentationThemeName(Background:TColor):string;

/// <summary>Read the package file version.</summary>
/// <returns>Major.Minor.Release.Build, or an empty string if metadata is unavailable.</returns>
function GetModuleVersion: string;

implementation

uses
  System.SysUtils,System.Math,XmlDoc.I18n,
  Winapi.Windows;

constructor TDocumentationErrorActions.CreateForMemo(Owner:TComponent;Memo:TMemo;Retry,Navigate:TNotifyEvent);
 function Add(const Caption:string;Handler:TNotifyEvent):TButton;
 begin Result:=TButton.Create(Self);Result.Parent:=Self;Result.Caption:=TI18n.Instance.T(Caption);Result.SetBounds(0,0,MulDiv(170,CurrentPPI,96),MulDiv(30,CurrentPPI,96));Result.OnClick:=Handler;end;
begin
 inherited Create(Owner);FMemo:=Memo;Parent:=Memo.Parent;Align:=alTop;AutoSize:=True;AutoWrap:=True;BevelOuter:=bvNone;
 FExpanded:=True;Add('Go to error',Navigate);Add('Retry parsing',Retry);Add('Copy details',CopyDetails);FCollapse:=Add('Hide details',ToggleDetails);Visible:=False;
end;
procedure TDocumentationErrorActions.ToggleDetails(Sender:TObject);
begin FExpanded:=not FExpanded;FMemo.Visible:=FExpanded;if FExpanded then FCollapse.Caption:=TI18n.Instance.T('Hide details') else FCollapse.Caption:=TI18n.Instance.T('Show details');end;
procedure TDocumentationErrorActions.CopyDetails(Sender:TObject);
begin FMemo.SelectAll;FMemo.CopyToClipboard;end;

function DocumentationThemeName(Background:TColor):string;
 function Linear(Value:Byte):Double;
 begin Result:=Value/255;if Result<=0.04045 then Result:=Result/12.92 else Result:=Power((Result+0.055)/1.055,2.4);end;
begin
 var Color:=ColorToRGB(Background);
 var Luminance:=0.2126*Linear(GetRValue(Color))+0.7152*Linear(GetGValue(Color))+0.0722*Linear(GetBValue(Color));
 if Luminance>0.179 then Result:='light' else Result:='dark';
end;

procedure ApplyDocumentationErrorTheme(Error:TMemo;Background:TColor);
begin
 if not Assigned(Error) then Exit;
 Error.StyleElements:=Error.StyleElements-[seFont,seClient];Error.ParentFont:=False;Error.Color:=Background;
 if DocumentationThemeName(Background)='light' then Error.Font.Color:=clBlack else Error.Font.Color:=clWhite;
end;

function GetModuleVersion: string;
var
  LFileName: string;
  LSize, LHandle: DWORD;
  LBuffer: TBytes;
  LInfo: PVSFixedFileInfo;
  LInfoLen: UINT;
begin
  Result := '';
  LFileName := GetModuleName(HInstance);
  LSize := GetFileVersionInfoSize(PChar(LFileName), LHandle);
  if LSize = 0 then
    Exit;

  SetLength(LBuffer, LSize);
  if not GetFileVersionInfo(PChar(LFileName), LHandle, LSize, @LBuffer[0]) then
    Exit;

  if VerQueryValue(@LBuffer[0], '\', Pointer(LInfo), LInfoLen) then
  begin
    Result := Format('%d.%d.%d.%d', [
      HiWord(LInfo.dwFileVersionMS),
      LoWord(LInfo.dwFileVersionMS),
      HiWord(LInfo.dwFileVersionLS),
      LoWord(LInfo.dwFileVersionLS)
    ]);
  end;
end;

end.
