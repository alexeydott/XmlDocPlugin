# XmlDoc.Plugin.Shortcuts

IDE menu commands, keyboard bindings and callback registration.

## Types

| Type | Kind | Description |
|------|------|-------------|
| [`TXmlDocKeyBinding`](XmlDoc.Plugin.Shortcuts.TXmlDocKeyBinding.md) | class | Registers plugin keyboard commands through IOTAKeyboardBinding. |
| [`TXmlDocMenuIntegration`](XmlDoc.Plugin.Shortcuts.TXmlDocMenuIntegration.md) | class | Owns the plugin's IDE menu commands. |

## Functions & Procedures

### SetCoverageReportCallback

Registers the coverage report callback.

**Parameters:**

- **ACallback** — Callback invoked to open the report.

### SetDocumentationCommandCallback

Registers the Inspector toggle callback.

**Parameters:**

- **ACallback** — Callback returning visibility after toggling the view.

### SetGenerateHelpCallback

Registers the documentation generation dialog callback.

**Parameters:**

- **ACallback** — Callback invoked to open the dialog.

### SetGenerateStubCallback

Registers the stub-generation callback.

**Parameters:**

- **ACallback** — Callback invoked to generate a documentation stub.

### SetIsDocExplorerVisibleFunc

Registers the Explorer visibility callback.

**Parameters:**

- **ACallback** — Callback returning the view's current visibility.

### SetIsInspectorVisibleFunc

Registers the Inspector visibility callback.

**Parameters:**

- **ACallback** — Callback returning the view's current visibility.

### SetNextUndocumentedCallback

Registers navigation to the next undocumented declaration.

**Parameters:**

- **ACallback** — Callback invoked to navigate to a declaration.

### SetPreviousUndocumentedCallback

Registers navigation to the previous undocumented declaration.

**Parameters:**

- **ACallback** — Callback invoked to navigate to a declaration.

### SetSettingsCallback

Registers the settings dialog callback.

**Parameters:**

- **ACallback** — Callback invoked to open the dialog.

### SetToggleDocExplorerCallback

Registers the Documentation Explorer toggle callback.

**Parameters:**

- **ACallback** — Callback returning visibility after toggling the view.

### SetToggleInspectorCallback
