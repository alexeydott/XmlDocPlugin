/// <summary>Contracts for documentation workbench acceptance tests.</summary>
unit Workbench.Contracts;
interface
type
 /// <summary>Describes an operation.</summary>
 IOperation=interface
 ['{910B57A9-087A-4810-B380-E96155FBF710}']
  /// <summary>Processes <paramref name="Value"/>.</summary>
  /// <param name="Value">The input value.</param>
  procedure Run(Value:Integer);
 end;
 /// <summary>Base documentation source.</summary>
 TDocumentedBase=class(TInterfacedObject)
 protected
  FCount:Integer;
 public
  /// <summary>Processes a numeric value.</summary>
  /// <remarks>Inherited numeric processing remarks.</remarks>
  /// <param name="Value">The input value.</param>
  procedure Run(Value:Integer);virtual;
  /// <summary>Gets the processed count.</summary>
  /// <value>The count.</value>
  property Count:Integer read FCount;
 end;
implementation
procedure TDocumentedBase.Run(Value:Integer);
begin FCount:=Value;end;
end.
