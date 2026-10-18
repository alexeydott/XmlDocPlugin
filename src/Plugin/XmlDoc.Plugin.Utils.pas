unit XmlDoc.Plugin.Utils;

interface

/// <summary>BPL의 파일 버전 정보를 읽어 문자열로 반환합니다.</summary>
/// <returns>Major.Minor.Release.Build, or an empty string if metadata is unavailable.</returns>
function GetModuleVersion: string;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

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
