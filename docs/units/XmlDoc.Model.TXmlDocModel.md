# class `TXmlDocModel`

Structured documentation model with XML-preserving serialization.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `FExamples` | field | private |  |
| `FExceptions` | field | private |  |
| `FInheritedFrom` | field | private |  |
| `FIsModified` | field | private |  |
| `FOnChanged` | field | private |  |
| `FOriginalCanonical` | field | private |  |
| `FParams` | field | private |  |
| `FParseError` | field | private |  |
| `FParseErrorColumn` | field | private |  |
| `FParseErrorLine` | field | private |  |
| `FRemarks` | field | private |  |
| `FReturns` | field | private |  |
| `FSeeAlso` | field | private |  |
| `FSourceXml` | field | private |  |
| `FSummary` | field | private |  |
| `FTypeParams` | field | private |  |
| `FValue` | field | private |  |
| `Assign` | method | public | Copies documentation and XML metadata from another model. |
| `Clear` | method | public | Clears documentation fields and source XML metadata. |
| `ClearContent` | method | private |  |
| `DoChanged` | method | private |  |
| `EscapeXml` | method | private |  |
| `ExtractInlineContent` | method | private |  |
| `ExtractNodeText` | method | private |  |
| `FromJson` | method | public | Loads documentation received from the embedded editor as JSON. |
| `GetIsEmpty` | method | private |  |
| `LoadFromXml` | method | public | Loads documentation from an XML fragment. |
| `MergeMissing` | method | public |  |
| `ParseChildNodes` | method | private |  |
| `SerializeKnownXml` | method | private |  |
| `SetRemarks` | method | private |  |
| `SetReturns` | method | private |  |
| `SetSummary` | method | private |  |
| `SetValue` | method | private |  |
| `ToJson` | method | public | Serializes documentation for the embedded editor. |
| `ToXml` | method | public | Serializes documentation while preserving supported original XML metadata. |
| `TrimDocText` | method | private |  |
| `UnescapeXml` | method | private |  |
| `WrapParaTags` | method | private |  |
| `Examples` | property | public |  |
| `Exceptions` | property | public |  |
| `InheritedFrom` | property | public |  |
| `IsEmpty` | property | public |  |
| `IsModified` | property | public |  |
| `OnChanged` | property | public |  |
| `Params` | property | public |  |
| `ParseError` | property | public |  |
| `ParseErrorColumn` | property | public |  |
| `ParseErrorLine` | property | public |  |
| `Remarks` | property | public |  |
| `Returns` | property | public |  |
| `SeeAlso` | property | public |  |
| `SourceXml` | property | public |  |
| `Summary` | property | public |  |
| `TypeParams` | property | public |  |
| `Value` | property | public |  |

### Create

### Destroy

### FExamples

### FExceptions

### FInheritedFrom

### FIsModified

### FOnChanged

### FOriginalCanonical

### FParams

### FParseError

### FParseErrorColumn

### FParseErrorLine

### FRemarks

### FReturns

### FSeeAlso

### FSourceXml

### FSummary

### FTypeParams

### FValue

### Assign

Copies documentation and XML metadata from another model.

**Parameters:**

- **ASource** — Model to copy.

### Clear

Clears documentation fields and source XML metadata.

### ClearContent

### DoChanged

### EscapeXml

### ExtractInlineContent

### ExtractNodeText

### FromJson

Loads documentation received from the embedded editor as JSON.

**Parameters:**

- **AJson** — JSON payload to parse.

### GetIsEmpty

### LoadFromXml

Loads documentation from an XML fragment.

**Parameters:**

- **AXml** — XML with a doc root or individual documentation tags.

### MergeMissing

### ParseChildNodes

### SerializeKnownXml

### SetRemarks

### SetReturns

### SetSummary

### SetValue

### ToJson

Serializes documentation for the embedded editor.

**Returns:** JSON representation of the model.

### ToXml

Serializes documentation while preserving supported original XML metadata.

**Returns:** Documentation XML fragment.

### TrimDocText

### UnescapeXml

### WrapParaTags

### Examples

### Exceptions

### InheritedFrom

### IsEmpty

### IsModified

### OnChanged

### Params

### ParseError

### ParseErrorColumn

### ParseErrorLine

### Remarks

### Returns

### SeeAlso

### SourceXml

### Summary

### TypeParams

### Value
