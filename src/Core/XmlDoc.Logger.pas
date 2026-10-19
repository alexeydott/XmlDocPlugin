/// <summary>Severity-filtered file logging with rotation and configurable destinations.</summary>
unit XmlDoc.Logger;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.SyncObjs;

type
  /// <summary>Logging threshold.</summary>
  TLogLevel = (llDebug, llInfo, llWarn, llError, llFatal);

  /// <summary>Thread-safe file logger with rotation and configurable severity filtering.</summary>
  TLogger = class
  strict private
    class var FInstance: TLogger;
  private
    FLevel: TLogLevel;
    FLock: TCriticalSection;
    FLogPath: string;
    FMaxFileSize: Int64;
    FMaxFiles: Integer;
    FWriter: TStreamWriter;

    procedure EnsureWriter;
    procedure SetLogPath(const AValue: string);
    function FormatEntry(ALevel: TLogLevel; const AMsg, AContext: string): string;
    function LevelToString(ALevel: TLogLevel): string;
    procedure RotateIfNeeded;
    procedure WriteEntry(ALevel: TLogLevel; const AMsg, AContext: string);

  public
    /// <summary>Applies the log threshold and closes the writer when the destination changes.</summary>
    procedure Configure(ALevel: TLogLevel; const APath: string);
    constructor Create;
    destructor Destroy; override;

    class function Instance: TLogger;
    class procedure ReleaseInstance;

    procedure Debug(const AMsg: string; const AContext: string = '');
    procedure Error(const AMsg: string; const AContext: string = ''); overload;
    procedure Error(E: Exception; const AContext: string = ''); overload;
    procedure Fatal(const AMsg: string; const AContext: string = '');
    procedure Info(const AMsg: string; const AContext: string = '');
    procedure Warn(const AMsg: string; const AContext: string = '');

    property Level: TLogLevel read FLevel write FLevel;
    property LogPath: string read FLogPath write SetLogPath;
  end;

implementation

const
  CDefaultMaxFileSize = 5 * 1024 * 1024;  // 5 MB
  CDefaultMaxFiles = 3;

{ TLogger }

constructor TLogger.Create;
var
  LAppData: string;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FLevel := llInfo;
  FMaxFileSize := CDefaultMaxFileSize;
  FMaxFiles := CDefaultMaxFiles;

  LAppData := TPath.Combine(TPath.GetHomePath, 'XmlDocPlugin');
  if not TDirectory.Exists(LAppData) then
    TDirectory.CreateDirectory(LAppData);

  FLogPath := TPath.Combine(LAppData, 'xmldocplugin.log');
end;

destructor TLogger.Destroy;
begin
  FWriter.Free;
  FLock.Free;
  inherited;
end;

class function TLogger.Instance: TLogger;
begin
  if not Assigned(FInstance) then
    FInstance := TLogger.Create;
  Result := FInstance;
end;

class procedure TLogger.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TLogger.SetLogPath(const AValue: string);
begin
  Configure(FLevel, AValue);
end;

procedure TLogger.Configure(ALevel: TLogLevel; const APath: string);
var
  LPath: string;
begin
  LPath := APath;
  if LPath = '' then
    LPath := TPath.Combine(TPath.GetHomePath, 'XmlDocPlugin\xmldocplugin.log');
  FLock.Enter;
  try
    if LPath <> FLogPath then
    begin
      FreeAndNil(FWriter);
      FLogPath := LPath;
    end;
    FLevel := ALevel;
  finally
    FLock.Leave;
  end;
end;

procedure TLogger.EnsureWriter;
var
  LStream: TFileStream;
begin
  if Assigned(FWriter) then Exit;
  if ExtractFileDir(FLogPath) <> '' then
    ForceDirectories(ExtractFileDir(FLogPath));
  if TFile.Exists(FLogPath) then
    LStream := TFileStream.Create(FLogPath, fmOpenWrite or fmShareDenyNone)
  else
    LStream := TFileStream.Create(FLogPath, fmCreate or fmShareDenyNone);
  try
    LStream.Seek(0, soEnd);
    FWriter := TStreamWriter.Create(LStream, TEncoding.UTF8);
    FWriter.OwnStream;
  except
    LStream.Free;
    raise;
  end;
  FWriter.AutoFlush := True;
end;

function TLogger.FormatEntry(ALevel: TLogLevel;
  const AMsg, AContext: string): string;
begin
  if AContext <> '' then
    Result := Format('%s [%s] [%s] %s',
      [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
       LevelToString(ALevel), AContext, AMsg])
  else
    Result := Format('%s [%s] %s',
      [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now),
       LevelToString(ALevel), AMsg]);
end;

function TLogger.LevelToString(ALevel: TLogLevel): string;
begin
  case ALevel of
    llDebug: Result := 'DEBUG';
    llInfo:  Result := 'INFO';
    llWarn:  Result := 'WARN';
    llError: Result := 'ERROR';
    llFatal: Result := 'FATAL';
  else
    Result := '?';
  end;
end;

procedure TLogger.RotateIfNeeded;
var
  I: Integer;
  LSrc: string;
  LDst: string;
begin
  if not TFile.Exists(FLogPath) then
    Exit;

  if TFile.GetSize(FLogPath) < FMaxFileSize then
    Exit;

  FreeAndNil(FWriter);

  // 로그 파일 회전: .log.3 → 삭제, .log.2 → .log.3, .log.1 → .log.2, .log → .log.1
  for I := FMaxFiles downto 1 do
  begin
    LSrc := FLogPath + '.' + IntToStr(I);
    LDst := FLogPath + '.' + IntToStr(I + 1);
    if I = FMaxFiles then
    begin
      if TFile.Exists(LSrc) then
        TFile.Delete(LSrc);
    end
    else
    begin
      if TFile.Exists(LSrc) then
        TFile.Move(LSrc, LDst);
    end;
  end;

  if TFile.Exists(FLogPath) then
    TFile.Move(FLogPath, FLogPath + '.1');
end;

procedure TLogger.WriteEntry(ALevel: TLogLevel; const AMsg, AContext: string);
begin
  FLock.Enter;
  try
    if Ord(ALevel) < Ord(FLevel) then Exit;
    try
      RotateIfNeeded;
      EnsureWriter;
      FWriter.WriteLine(FormatEntry(ALevel, AMsg, AContext));
    except
      // 로그 실패는 무시
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLogger.Debug(const AMsg, AContext: string);
begin
  WriteEntry(llDebug, AMsg, AContext);
end;

procedure TLogger.Info(const AMsg, AContext: string);
begin
  WriteEntry(llInfo, AMsg, AContext);
end;

procedure TLogger.Warn(const AMsg, AContext: string);
begin
  WriteEntry(llWarn, AMsg, AContext);
end;

procedure TLogger.Error(const AMsg, AContext: string);
begin
  WriteEntry(llError, AMsg, AContext);
end;

procedure TLogger.Error(E: Exception; const AContext: string);
begin
  WriteEntry(llError, Format('%s: %s', [E.ClassName, E.Message]), AContext);
end;

procedure TLogger.Fatal(const AMsg, AContext: string);
begin
  WriteEntry(llFatal, AMsg, AContext);
end;

initialization

finalization
  TLogger.ReleaseInstance;

end.
