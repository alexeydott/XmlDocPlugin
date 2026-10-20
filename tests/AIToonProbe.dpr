program AIToonProbe;
{$APPTYPE CONSOLE}
uses System.SysUtils,System.IOUtils,System.JSON,XmlDoc.AI.Toon;
var Input:TJSONArray;Output:TJSONArray;
begin
 try
  Input:=TJSONObject.ParseJSONValue(TFile.ReadAllText(ParamStr(1),TEncoding.UTF8)) as TJSONArray;
  Output:=TJSONArray.Create;
  try
   for var Item in Input do Output.AddElement(TJSONObject.Create.AddPair('value',Item.Clone as TJSONValue).AddPair('toon',AIToon(Item)));
   TFile.WriteAllText(ParamStr(2),Output.ToJSON,TEncoding.UTF8);
  finally Output.Free;Input.Free;end;
 except on E:Exception do begin Writeln(E.ClassName+': '+E.Message);Halt(1);end;end;
end.
