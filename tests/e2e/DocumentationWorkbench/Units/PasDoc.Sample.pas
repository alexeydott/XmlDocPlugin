unit PasDoc.Sample;
interface
type
  // # @abstract Sample class for legacy documentation import
  TPasDocSample = class(TObject)
  public
    // # @abstract Convert a value using a scale factor
    function ConvertValue(Value: Double; Scale: Integer = 1): Double;
  end;
implementation
function TPasDocSample.ConvertValue(Value: Double; Scale: Integer): Double;
begin
  Result := Value * Scale;
end;
end.
