unit Documentation.Sample;
interface
type
  /// <summary>Formats text for display and export.</summary>
  TDocumented = class
  public
    /// <summary>Removes surrounding whitespace from the supplied text.</summary>
    /// <param name="Value">The text to format. An empty value produces an empty result.</param>
    /// <returns>The trimmed text, preserving the original letter case.</returns>
    /// <remarks>Whitespace inside the text is preserved. Use the result in a report heading or a document title.</remarks>
    function Run(const Value: string): string;
  end;
implementation
uses System.SysUtils;
function TDocumented.Run(const Value: string): string;
begin
  if Value = '' then Exit('');
  Result := Trim(Value);
end;
end.
