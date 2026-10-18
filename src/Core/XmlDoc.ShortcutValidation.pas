unit XmlDoc.ShortcutValidation;
interface
uses System.SysUtils,System.Classes,Vcl.ActnList,Vcl.Menus;
function DocumentationShortcutConflicts(const Keys:TArray<TShortCut>;const Names:TArray<string>;Actions:TCustomActionList;
 RootMenu:TMenuItem=nil;const PreviousKeys:TArray<TShortCut>=nil):TArray<string>;
implementation
uses System.Generics.Collections;
function DocumentationShortcutConflicts(const Keys:TArray<TShortCut>;const Names:TArray<string>;Actions:TCustomActionList;
 RootMenu:TMenuItem;const PreviousKeys:TArray<TShortCut>):TArray<string>;
var Results:TList<string>;I,J:Integer;Action:TCustomAction;
 function Changed(Index:Integer):Boolean;
 begin Result:=(Length(PreviousKeys)=0) or (Keys[Index]<>PreviousKeys[Index]);end;
 function OwnMenuAction(Menu:TMenuItem;Inside:Boolean):Boolean;
 begin
  Result:=False;if not Assigned(Menu) then Exit;
  Inside:=Inside or SameText(Menu.Name,'XmlDocDocumentMenu');
  if Inside and (Menu.Action=Action) then Exit(True);
  for var ChildIndex:=0 to Menu.Count-1 do if OwnMenuAction(Menu.Items[ChildIndex],Inside) then Exit(True);
 end;
begin
 if Length(Keys)<>Length(Names) then raise EArgumentException.Create('Shortcut labels must match shortcuts');
 if (Length(PreviousKeys)<>0) and (Length(PreviousKeys)<>Length(Keys)) then raise EArgumentException.Create('Previous shortcuts must match shortcuts');
 Results:=TList<string>.Create;
 try
  for I:=0 to High(Keys) do if Keys[I]<>0 then begin
   for J:=0 to I-1 do if (Keys[I]=Keys[J]) and (Changed(I) or Changed(J)) then Results.Add(Names[I]+' conflicts with '+Names[J]+' ('+ShortCutToText(Keys[I])+')');
   if Changed(I) and Assigned(Actions) then for J:=0 to Actions.ActionCount-1 do if Actions.Actions[J] is TCustomAction then begin
    Action:=TCustomAction(Actions.Actions[J]);
    if not SameText(Copy(Action.Name,1,6),'XmlDoc') and (Action.ShortCut=Keys[I]) and not OwnMenuAction(RootMenu,False) then
     Results.Add(Names[I]+' conflicts with IDE action '+Action.Caption+' ('+ShortCutToText(Keys[I])+')');
   end;
  end;Result:=Results.ToArray;
 finally Results.Free;end;
end;
end.
