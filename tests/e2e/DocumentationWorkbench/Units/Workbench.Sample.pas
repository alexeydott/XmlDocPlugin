/// <summary>Editor acceptance scenarios: overloads, Unicode and mixed XML.</summary>
unit Workbench.Sample;
interface
uses Workbench.Contracts;
type
 /// <summary>A documented sample.</summary>
 TDocumented=class(TDocumentedBase,IOperation)
 public
  /// <inheritdoc/>
  /// <remarks>Local remarks extend the inherited summary.</remarks>
  procedure Run(Value:Integer);overload;override;
  /// <summary>Processes <b>text</b>, <i>including Unicode</i><br/>and <custom preserve="yes">unknown markup</custom>.</summary>
  /// <param name="Value">The text to process.</param>
  /// <example title="Unicode &amp; escaping" source="Examples/Workbench.Examples.pas" region="Usage">
  /// <para>Example explanation: Пример.</para>
  /// <code>if A &lt; B then
  ///   WriteLn('A &amp; B');
  ///
  /// Done;</code>
  /// </example>
  /// <seealso cref="TDocumentedBase">Base description</seealso>
  /// <remarks><image src="Resources/sample.png"/></remarks>
  /// <custom-root keep="yes"/>
  procedure Run(const Value:string);overload;
  /// <summary>TODO: Documentation needs synchronization.</summary>
  /// <param name="OldName">Description to map explicitly.</param>
  /// <remarks>See <paramref name="OldName"/>.</remarks>
  function RenameScenario(const NewName:string;Options:Integer):Boolean;
  /// <summary>Malformed XML remains available for repair.
  procedure BrokenDocumentation;
  procedure UndocumentedFirst;
  procedure UndocumentedSecond;
  /// <summary>Explains <b>pending work</b><br/>without an implementation.</summary>
  procedure NoBody;virtual;abstract;
  procedure ScopeProbe;
  /// <summary>Adds two numbers.</summary>
  /// <param name="Value">Old first parameter description.</param>
  /// <param name="Other">Keep second parameter description.</param>
  /// <returns>TODO: Describe the result.</returns>
  /// <remarks>Keep local calculation remarks.</remarks>
  function Calculate(Value,Other:Integer):Integer;
 end;
 TLocalProc=reference to procedure(Value:Integer);
 TTextBase=class
  procedure Run(Value:UnicodeString);overload;
 end;
 TTextWorker=class(TTextBase)
  procedure Run(Value:WideString);overload;
  procedure Caller(U:UnicodeString;W:WideString);
 end;
implementation
procedure TTextBase.Run(Value:UnicodeString);
begin end;
procedure TTextWorker.Run(Value:WideString);
begin end;
procedure TTextWorker.Caller(U:UnicodeString;W:WideString);
begin
 Self.Run(U); // review-text-unicode
 Self.Run(W); // review-text-wide
 var Run:TLocalProc := procedure(Value:Integer) begin end;
 Run(1); // review-inline-local
 Self.Run(U); // review-inline-self
end;
procedure TDocumented.Run(Value:Integer);
begin inherited Run(Value);end;
procedure TDocumented.Run(const Value:string);
begin if Value='' then Exit;end;
function TDocumented.RenameScenario(const NewName:string;Options:Integer):Boolean;
begin Result:=(NewName<>'') and (Options>=0);end;
procedure TDocumented.BrokenDocumentation;
begin end;
procedure TDocumented.UndocumentedFirst;
begin end;
procedure TDocumented.UndocumentedSecond;
begin end;
procedure TDocumented.ScopeProbe;
  /// <summary>Local scope operation.</summary>
  procedure Run(Value:Integer);
  begin end;
begin
  Run(1); // review-local-call
  Self.Run(1); // review-self-call
end;
function TDocumented.Calculate(Value,Other:Integer):Integer;
begin Result:=Value+Other;end;
end.
