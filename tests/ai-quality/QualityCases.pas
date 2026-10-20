unit QualityCases;
interface
uses System.SysUtils;
{$I QualityCases.inc}
type
 TQualityBox<T>=class
 public
  function Pick(const Values:TArray<T>;Index:Integer;out Value:T):Boolean;
 end;
 /// <summary>Уменьшает доступный остаток на использованное количество.</summary>
 function TryConsume(var Remaining:Integer;Requested:Integer;out Used:Integer):Boolean;
 function RequirePositive(Value:Integer):Integer;
 function Normalize(Value:Integer):Integer;overload;
 function Normalize(const Value:string):string;overload;
 function Scale(Value:Integer):Integer;
implementation
function TryConsume(var Remaining:Integer;Requested:Integer;out Used:Integer):Boolean;
begin
 Used:=0;
 if Requested<=0 then Exit(False);
 if Remaining<Requested then Exit(False);
 Used:=Requested;Dec(Remaining,Used);Result:=True;
end;
function RequirePositive(Value:Integer):Integer;
begin
 if Value<=0 then raise EArgumentOutOfRangeException.Create('Value must be positive');
 Result:=Value;
end;
function Normalize(Value:Integer):Integer;
begin
 if Value<0 then Exit(0);
 Result:=Value;
end;
function Normalize(const Value:string):string;
begin Result:=Trim(Value);end;
function Scale(Value:Integer):Integer;
begin
 {$IFDEF QUALITY_FAST}
 Result:=Value*2;
 {$ELSE}
 Result:=Value*3;
 {$ENDIF}
end;
function TQualityBox<T>.Pick(const Values:TArray<T>;Index:Integer;out Value:T):Boolean;
begin
 Value:=Default(T);
 if (Index<0) or (Index>=Length(Values)) then Exit(False);
 Value:=Values[Index];Result:=True;
end;
end.
