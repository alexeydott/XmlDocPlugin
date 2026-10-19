# class `TDocCodeGenerator`

Renders documentation comments and applies them to source text.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `ApplyToSourceText` | method | public | Returns source text with the declaration's documentation replaced or inserted. |
| `BuildIndent` | method | private |  |
| `ModelToCommentBlock` | method | public | Renders a model as an indented triple-slash comment block. |
| `WrapLine` | method | private |  |

### ApplyToSourceText

Returns source text with the declaration's documentation replaced or inserted.

**Parameters:**

- **ASource** — Complete original source text.
- **AElement** — Target declaration and source location.
- **AModel** — Documentation model to apply.

**Returns:** Source text with the documentation change applied.

### BuildIndent

### ModelToCommentBlock

Renders a model as an indented triple-slash comment block.

**Parameters:**

- **AModel** — Documentation model to render.
- **AIndent** — Number of indentation spaces; defaults to 2.

**Returns:** Comment lines prefixed with triple slashes.

### WrapLine
