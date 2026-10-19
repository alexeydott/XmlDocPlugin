unit XmlDoc.Plugin.Utils;

interface
uses Vcl.StdCtrls,Vcl.Graphics;

/// <summary>Keep diagnostic text readable against the actual host background.</summary>
procedure ApplyDocumentationErrorTheme(Error:TMemo;Background:TColor);
function DocumentationThemeName(Background:TColor):string;

/// <summary>Read the package file version.</summary>
/// <returns>Major.Minor.Release.Build, or an empty string if metadata is unavailable.</returns>
function GetModuleVersion: string;

implementation

uses
  System.SysUtils,System.Math,Vcl.Controls,
  Winapi.Windows;

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
