# class `TDocOTAWriter`

Applies documentation through an undoable IDE source writer.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `ApplyToEditor` | method | public | Replaces or inserts the selected declaration's comment through an undoable writer. |
| `GetCurrentSourceEditor` | method | public | Returns the source editor in the active IDE view. |
| `GetEditorPosition` | method | private |  |

### ApplyToEditor

Replaces or inserts the selected declaration's comment through an undoable writer.

**Parameters:**

- **AEditor** — Source editor to modify.
- **AElement** — Target declaration and source location.
- **AModel** — Documentation model to apply.

**Returns:** True if the operation succeeds.

### GetCurrentSourceEditor

Returns the source editor in the active IDE view.

**Returns:** The source editor, or nil if no source view is active.

### GetEditorPosition
