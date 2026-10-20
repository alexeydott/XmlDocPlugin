/// <summary>Markup rendering acceptance examples.</summary>
unit Workbench.Markup;
interface
type
  /// <summary>A renderer example for <typeparamref name="T"/>.</summary>
  TMarkupExample<T> = class
  public
    /// <summary>
    /// <para>Paragraph one: <b>bold</b>, <strong>strong alias</strong>, <i>italic</i>, <em>emphasis alias</em>, <c>inline code</c>.</para>
    /// <para>Paragraph two<br/>after short break<br></br>after paired break.</para>
    /// <para/><b/><strong/><i/><em/><c/><code/><list type="bullet"/>
    /// </summary>
    /// <remarks>
    /// <para>References: <paramref name="Value"/>, <typeparamref name="T"/>, <see cref="TMarkupExample">custom reference label</see>.</para>
    /// <list type="bullet"><item><description>Bullet item</description></item></list>
    /// <list type="number"><item><description>Numbered first</description></item><item><description>Numbered second</description></item></list>
    /// <list type="table"><listheader><term>Key</term><description>Meaning</description></listheader><item><term>alpha</term><description>Table cell with <b>bold cell</b>.</description></item></list>
    /// <code>if Value &lt; 0 then Exit;</code>
    /// </remarks>
    /// <param name="Value"><para>First parameter paragraph.</para><para>Second parameter paragraph.</para></param>
    class procedure Render(Value: Integer); static;
  end;
implementation
class procedure TMarkupExample<T>.Render(Value: Integer);
begin
  if Value < 0 then Exit;
end;
end.
