program DocumentationHints;
{$APPTYPE CONSOLE}
uses System.SysUtils;
type
  TTextFormatter = class
  public
    /// <summary>Prepares text for reports and exported documents.</summary>
    /// <param name="Value">The text to format.</param>
    /// <param name="TrimWhitespace">Remove leading and trailing spaces when True.</param>
    /// <returns>The formatted text with its original letter case.</returns>
    /// <remarks><para>Use the result in a report heading or a document title.</para>
    /// <list type="bullet"><item><description>Letter case is preserved.</description></item><item><description>Whitespace inside the text is retained.</description></item></list>
    /// <list type="table"><listheader><term>Option</term><description>Effect</description></listheader>
    /// <item><term>True</term><description>Trim surrounding spaces.</description></item><item><term>False</term><description>Keep the original whitespace.</description></item></list>
    /// <note type="caller">Choose the whitespace policy before exporting.</note></remarks>
    class function NormalizeText(const Value: string; TrimWhitespace: Boolean): string; static;
  end;
class function TTextFormatter.NormalizeText(const Value: string; TrimWhitespace: Boolean): string;
begin
  if TrimWhitespace then Result := Trim(Value) else Result := Value;
end;
begin
  Writeln(TTextFormatter.NormalizeText('  Quarterly report  ', True));
end.
