program HelpInsightCssProbe;
{$APPTYPE CONSOLE}
uses System.SysUtils;
type
  TDocumentationProbe = class
  public
    /// <summary>Выполняет отрисовку карты с преобразованием координат, отсечением, масштабированием, поворотом и размещением подписей. Длинное описание должно переноситься в пределах окна подсказки.</summary>
    /// <param name="AParameter1">Параметр 1 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter2">Параметр 2 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter3">Параметр 3 управляет преобразованием координат и отображением слоя карты.</param>
    /// <returns>Количество отрисованных объектов.</returns>
    class function RenderMapWith3ParametersAndLongDocumentation(AParameter1: Integer; AParameter2: Integer; AParameter3: Integer): Integer; static;
    /// <summary>Выполняет отрисовку карты с преобразованием координат, отсечением, масштабированием, поворотом и размещением подписей. Длинное описание должно переноситься в пределах окна подсказки.</summary>
    /// <param name="AParameter1">Параметр 1 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter2">Параметр 2 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter3">Параметр 3 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter4">Параметр 4 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter5">Параметр 5 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter6">Параметр 6 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter7">Параметр 7 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter8">Параметр 8 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter9">Параметр 9 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter10">Параметр 10 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter11">Параметр 11 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter12">Параметр 12 управляет преобразованием координат и отображением слоя карты.</param>
    /// <returns>Количество отрисованных объектов.</returns>
    class function RenderMapWith12ParametersAndLongDocumentation(AParameter1: Integer; AParameter2: Integer; AParameter3: Integer; AParameter4: Integer; AParameter5: Integer; AParameter6: Integer; AParameter7: Integer; AParameter8: Integer; AParameter9: Integer; AParameter10: Integer; AParameter11: Integer; AParameter12: Integer): Integer; static;
    /// <summary>Выполняет отрисовку карты с преобразованием координат, отсечением, масштабированием, поворотом и размещением подписей. Длинное описание должно переноситься в пределах окна подсказки.</summary>
    /// <param name="AParameter1">Параметр 1 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter2">Параметр 2 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter3">Параметр 3 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter4">Параметр 4 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter5">Параметр 5 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter6">Параметр 6 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter7">Параметр 7 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter8">Параметр 8 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter9">Параметр 9 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter10">Параметр 10 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter11">Параметр 11 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter12">Параметр 12 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter13">Параметр 13 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter14">Параметр 14 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter15">Параметр 15 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter16">Параметр 16 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter17">Параметр 17 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter18">Параметр 18 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter19">Параметр 19 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter20">Параметр 20 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter21">Параметр 21 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter22">Параметр 22 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter23">Параметр 23 управляет преобразованием координат и отображением слоя карты.</param>
    /// <param name="AParameter24">Параметр 24 управляет преобразованием координат и отображением слоя карты.</param>
    /// <returns>Количество отрисованных объектов.</returns>
    class function RenderMapWith24ParametersAndLongDocumentation(AParameter1: Integer; AParameter2: Integer; AParameter3: Integer; AParameter4: Integer; AParameter5: Integer; AParameter6: Integer; AParameter7: Integer; AParameter8: Integer; AParameter9: Integer; AParameter10: Integer; AParameter11: Integer; AParameter12: Integer; AParameter13: Integer; AParameter14: Integer; AParameter15: Integer; AParameter16: Integer; AParameter17: Integer; AParameter18: Integer; AParameter19: Integer; AParameter20: Integer; AParameter21: Integer; AParameter22: Integer; AParameter23: Integer; AParameter24: Integer): Integer; static;
  end;
class function TDocumentationProbe.RenderMapWith3ParametersAndLongDocumentation(AParameter1: Integer; AParameter2: Integer; AParameter3: Integer): Integer;
begin Result := AParameter1; end;
class function TDocumentationProbe.RenderMapWith12ParametersAndLongDocumentation(AParameter1: Integer; AParameter2: Integer; AParameter3: Integer; AParameter4: Integer; AParameter5: Integer; AParameter6: Integer; AParameter7: Integer; AParameter8: Integer; AParameter9: Integer; AParameter10: Integer; AParameter11: Integer; AParameter12: Integer): Integer;
begin Result := AParameter1; end;
class function TDocumentationProbe.RenderMapWith24ParametersAndLongDocumentation(AParameter1: Integer; AParameter2: Integer; AParameter3: Integer; AParameter4: Integer; AParameter5: Integer; AParameter6: Integer; AParameter7: Integer; AParameter8: Integer; AParameter9: Integer; AParameter10: Integer; AParameter11: Integer; AParameter12: Integer; AParameter13: Integer; AParameter14: Integer; AParameter15: Integer; AParameter16: Integer; AParameter17: Integer; AParameter18: Integer; AParameter19: Integer; AParameter20: Integer; AParameter21: Integer; AParameter22: Integer; AParameter23: Integer; AParameter24: Integer): Integer;
begin Result := AParameter1; end;
begin
  Writeln(TDocumentationProbe.RenderMapWith3ParametersAndLongDocumentation(1, 2, 3));
  Writeln(TDocumentationProbe.RenderMapWith12ParametersAndLongDocumentation(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12));
  Writeln(TDocumentationProbe.RenderMapWith24ParametersAndLongDocumentation(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24));
end.
