unit XmlDoc.ShortcutValidation;
interface
uses System.SysUtils,System.Classes,Vcl.ActnList;
function DocumentationShortcutConflicts(const Keys:TArray<TShortCut>;const Names:TArray<string>;Actions:TCustomActionList):TArray<string>;
implementation
uses Vcl.Menus,System.Generics.Collections;
function DocumentationShortcutConflicts(const Keys:TArray<TShortCut>;const Names:TArray<string>;Actions:TCustomActionList):TArray<string>;
var Results:TList<string>;I,J:Integer;Action:TCustomAction;
begin
 if Length(Keys)<>Length(Names) then raise EArgumentException.Create('Shortcut labels must match shortcuts');
 Results:=TList<string>.Create;
 try
  for I:=0 to High(Keys) do if Keys[I]<>0 then begin
   for J:=0 to I-1 do if Keys[I]=Keys[J] then Results.Add(Names[I]+' conflicts with '+Names[J]+' ('+ShortCutToText(Keys[I])+')');
   if Assigned(Actions) then for J:=0 to Actions.ActionCount-1 do if Actions.Actions[J] is TCustomAction then begin
    Action:=TCustomAction(Actions.Actions[J]);
    if not SameText(Copy(Action.Name,1,6),'XmlDoc') and (Action.ShortCut=Keys[I]) then Results.Add(Names[I]+' conflicts with IDE action '+Action.Caption+' ('+ShortCutToText(Keys[I])+')');
   end;
  end;Result:=Results.ToArray;
 finally Results.Free;end;
end;
end.
