# class `TErrorHandler`

Collects plugin diagnostics and supports an IDE message callback.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `FErrors` | field | private |  |
| `FInstance` | field | private |  |
| `FOnError` | field | private |  |
| `AddError` | method | public | Adds a diagnostic without an exception object. |
| `ClearErrors` | method | public | Clears collected diagnostics. |
| `HandleException` | method | public | Records an exception as a diagnostic and writes it to the log. |
| `Instance` | method | public |  |
| `ReleaseInstance` | method | public |  |
| `ReportToIDE` | method | public | Sends a message to the registered IDE message callback. |
| `Errors` | property | public |  |
| `OnError` | property | public |  |

### Create

### Destroy

### FErrors

### FInstance

### FOnError

### AddError

Adds a diagnostic without an exception object.

**Parameters:**

- **ASeverity** — Diagnostic severity.
- **AMessage** — Diagnostic message.
- **AContext** — Diagnostic context.

### ClearErrors

Clears collected diagnostics.

### HandleException

Records an exception as a diagnostic and writes it to the log.

**Parameters:**

- **E** — Exception being reported.
- **ASeverity** — Diagnostic severity.
- **AContext** — Module or operation that produced the diagnostic.

### Instance

### ReleaseInstance

### ReportToIDE

Sends a message to the registered IDE message callback.

**Parameters:**

- **AMsg** — Message to report.
- **AFileName** — Optional source file path.
- **ALine** — Optional source line number.

### Errors

### OnError
