/// <summary>Plugin diagnostics, exception logging and IDE message callbacks.</summary>
unit XmlDoc.ErrorHandler;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  ToolsAPI,
  XmlDoc.Logger;

type
  /// <summary>Diagnostic severity.</summary>
  TErrorSeverity = (
    esRecoverable,
    esElementSkip,
    esUnitSkip,
    esFatal
  );

  /// <summary>A plugin diagnostic with context and source location.</summary>
  TPluginError = record
    Context: string;
    ExceptionClass: string;
    FileName: string;
    Line: Integer;
    Message: string;
    Severity: TErrorSeverity;
    Timestamp: TDateTime;
  end;

  TErrorCallback = reference to procedure(const AError: TPluginError);

  /// <summary>Collects plugin diagnostics and supports an IDE message callback.</summary>
  TErrorHandler = class
  strict private
    class var FInstance: TErrorHandler;
  private
    FErrors: TList<TPluginError>;
    FOnError: TErrorCallback;
  public
    constructor Create;
    destructor Destroy; override;

    class function Instance: TErrorHandler;
    class procedure ReleaseInstance;

    /// <summary>Records an exception as a diagnostic and writes it to the log.</summary>
    /// <param name="E">Exception being reported.</param>
    /// <param name="ASeverity">Diagnostic severity.</param>
    /// <param name="AContext">Module or operation that produced the diagnostic.</param>
    procedure HandleException(E: Exception; ASeverity: TErrorSeverity; const AContext: string);

    /// <summary>Sends a message to the registered IDE message callback.</summary>
    /// <param name="AMsg">Message to report.</param>
    /// <param name="AFileName">Optional source file path.</param>
    /// <param name="ALine">Optional source line number.</param>
    procedure ReportToIDE(const AMsg: string; const AFileName: string = ''; ALine: Integer = 0);

    /// <summary>Adds a diagnostic without an exception object.</summary>
    /// <param name="ASeverity">Diagnostic severity.</param>
    /// <param name="AMessage">Diagnostic message.</param>
    /// <param name="AContext">Diagnostic context.</param>
    procedure AddError(ASeverity: TErrorSeverity; const AMessage, AContext: string);

    /// <summary>Clears collected diagnostics.</summary>
    procedure ClearErrors;

    property Errors: TList<TPluginError> read FErrors;
    property OnError: TErrorCallback read FOnError write FOnError;
  end;

implementation

{ TErrorHandler }

constructor TErrorHandler.Create;
begin
  inherited Create;
  FErrors := TList<TPluginError>.Create;
end;

destructor TErrorHandler.Destroy;
begin
  FErrors.Free;
  inherited;
end;

class function TErrorHandler.Instance: TErrorHandler;
begin
  if not Assigned(FInstance) then
    FInstance := TErrorHandler.Create;
  Result := FInstance;
end;

class procedure TErrorHandler.ReleaseInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TErrorHandler.HandleException(E: Exception; ASeverity: TErrorSeverity; const AContext: string);
var
  LError: TPluginError;
begin
  LError.Timestamp := Now;
  LError.Severity := ASeverity;
  LError.Message := E.Message;
  LError.Context := AContext;
  LError.ExceptionClass := E.ClassName;
  LError.FileName := '';
  LError.Line := -1;
  FErrors.Add(LError);

  // 로깅
  case ASeverity of
    esRecoverable:
      TLogger.Instance.Warn(Format('%s: %s', [E.ClassName, E.Message]), AContext);
    esElementSkip, esUnitSkip:
      TLogger.Instance.Error(E, AContext);
    esFatal:
      TLogger.Instance.Fatal(Format('%s: %s', [E.ClassName, E.Message]), AContext);
  end;

  // 콜백
  if Assigned(FOnError) then
    FOnError(LError);

  // IDE 메시지 패널 출력
  ReportToIDE(Format('[XmlDoc] %s — %s: %s', [AContext, E.ClassName, E.Message]));
end;

procedure TErrorHandler.ReportToIDE(const AMsg: string; const AFileName: string; ALine: Integer);
var
  LMsgServices: IOTAMessageServices;
begin
  if Supports(BorlandIDEServices, IOTAMessageServices, LMsgServices) then
  begin
    LMsgServices.AddToolMessage(AFileName, AMsg, 'XmlDoc', ALine, 0);
    LMsgServices.ShowMessageView(nil);
  end;
end;

procedure TErrorHandler.AddError(ASeverity: TErrorSeverity; const AMessage, AContext: string);
var
  LError: TPluginError;
begin
  LError.Timestamp := Now;
  LError.Severity := ASeverity;
  LError.Message := AMessage;
  LError.Context := AContext;
  LError.ExceptionClass := '';
  LError.FileName := '';
  LError.Line := -1;
  FErrors.Add(LError);

  if Assigned(FOnError) then
    FOnError(LError);
end;

procedure TErrorHandler.ClearErrors;
begin
  FErrors.Clear;
end;

initialization

finalization
  TErrorHandler.ReleaseInstance;

end.
