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
implementation
procedure TSecond.Run(Value:Integer);
begin end;
end.
