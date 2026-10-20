program QualitySmoke;
{$APPTYPE CONSOLE}
{$ASSERTIONS ON}
uses System.SysUtils,QualityCases;
var Remaining,Used,Value:Integer;Box:TQualityBox<Integer>;Raised:Boolean;
begin
 Remaining:=7;
 Assert(not TryConsume(Remaining,0,Used));Assert((Used=0) and (Remaining=7));
 Assert(not TryConsume(Remaining,8,Used));Assert((Used=0) and (Remaining=7));
 Assert(TryConsume(Remaining,3,Used));Assert((Used=3) and (Remaining=4));
 Assert(RequirePositive(2)=2);Raised:=False;try RequirePositive(0);except on E:EArgumentOutOfRangeException do Raised:=True;end;Assert(Raised);
 Assert(Normalize(-2)=0);Assert(Normalize(4)=4);Assert(Normalize(' a ')='a');Assert(Scale(4)=8);
 Box:=TQualityBox<Integer>.Create;try Assert(not Box.Pick([1,2],-1,Value));Assert(Value=0);Assert(Box.Pick([1,2],1,Value));Assert(Value=2);finally Box.Free;end;
 Writeln('PASS quality corpus runtime facts');
end.
