/// <summary>Second file for delayed-save and project navigation tests.</summary>
unit Workbench.Second;
interface
type
 /// <summary>A different document with the same method name.</summary>
 TSecond=class
 public
  /// <summary>Must not receive edits intended for another file.</summary>
  procedure Run(Value:Integer);
 end;
/// <summary>Configuration and platform context without changing source text.</summary>
procedure ContextProbe(Value:{$IFDEF DEBUG}Integer{$ELSE}string{$ENDIF}; Native:{$IFDEF WIN64}Int64{$ELSE}Integer{$ENDIF});
implementation
procedure ContextProbe(Value:{$IFDEF DEBUG}Integer{$ELSE}string{$ENDIF}; Native:{$IFDEF WIN64}Int64{$ELSE}Integer{$ENDIF});
begin end;
procedure TSecond.Run(Value:Integer);
begin end;
end.
