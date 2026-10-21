# class `TDocInspectorForm`

Inherits from `TDockableForm`

Dockable declaration documentation editor hosted in WebView2.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `FAI` | field | private |  |
| `FBrowser` | field | private |  |
| `FBrowserError` | field | private |  |
| `FBrowserReady` | field | private |  |
| `FClosing` | field | private |  |
| `FContextProjectFile` | field | private |  |
| `FContextSourceFile` | field | private |  |
| `FCurrentElement` | field | private |  |
| `FCursorPollTimer` | field | private |  |
| `FDiagnostic` | field | private |  |
| `FDocModel` | field | private |  |
| `FDocParser` | field | private |  |
| `FEditSessionId` | field | private |  |
| `FErrorActions` | field | private |  |
| `FErrorViewSent` | field | private |  |
| `FInitTimer` | field | private |  |
| `FLastElementLine` | field | private |  |
| `FLastElementName` | field | private |  |
| `FLastFileName` | field | private |  |
| `FLastPolledLine` | field | private |  |
| `FLastPolledRevision` | field | private |  |
| `FParamDictLoaded` | field | private |  |
| `FParseError` | field | private |  |
| `FPendingCommand` | field | private |  |
| `FPendingLoad` | field | private |  |
| `FPinned` | field | private |  |
| `FProjectDocs` | field | private |  |
| `FUpdatingSource` | field | private |  |
| `FWebViewError` | field | private |  |
| `ApplyIDETheme` | method | protected |  |
| `BrowserCreateWebViewCompleted` | method | private |  |
| `BrowserNavigationCompleted` | method | private |  |
| `BrowserWebMessageReceived` | method | private |  |
| `BuildElementJson` | method | private |  |
| `BuildLoadDocScript` | method | private |  |
| `CaptureParamDescriptions` | method | private |  |
| `CMStyleChanged` | method | protected |  |
| `CursorPollTimerFired` | method | private |  |
| `EnsureParamDictLoaded` | method | private |  |
| `ExecuteCommand` | method | public |  |
| `GetParamDictPath` | method | private |  |
| `GoToError` | method | private |  |
| `HandleCursorChanged` | method | public | Updates the selected declaration after the cursor changes. |
| `HandleDocUpdated` | method | private |  |
| `HandleJumpToLine` | method | private |  |
| `InitTimerFired` | method | private |  |
| `IsSameElement` | method | private |  |
| `KeyDown` | method | protected |  |
| `ParseEditorSource` | method | private |  |
| `RefreshFromCurrentEditor` | method | public | Refreshes the declaration at the active editor's cursor. |
| `RetryParsing` | method | private |  |
| `SendToEditor` | method | private |  |
| `ShowParseFailure` | method | private |  |
| `UpdateErrorDisplay` | method | private |  |
| `UpdateFromCursor` | method | private |  |
| `Documentation` | property | public |  |

### Create

### Destroy

### FAI

### FBrowser

### FBrowserError

### FBrowserReady

### FClosing

### FContextProjectFile

### FContextSourceFile

### FCurrentElement

### FCursorPollTimer

### FDiagnostic

### FDocModel

### FDocParser

### FEditSessionId

### FErrorActions

### FErrorViewSent

### FInitTimer

### FLastElementLine

### FLastElementName

### FLastFileName

### FLastPolledLine

### FLastPolledRevision

### FParamDictLoaded

### FParseError

### FPendingCommand

### FPendingLoad

### FPinned

### FProjectDocs

### FUpdatingSource

### FWebViewError

### ApplyIDETheme

### BrowserCreateWebViewCompleted

### BrowserNavigationCompleted

### BrowserWebMessageReceived

### BuildElementJson

### BuildLoadDocScript

### CaptureParamDescriptions

### CMStyleChanged

### CursorPollTimerFired

### EnsureParamDictLoaded

### ExecuteCommand

### GetParamDictPath

### GoToError

### HandleCursorChanged

Updates the selected declaration after the cursor changes.

**Parameters:**

- **ALine** — One-based current cursor line.
- **ASource** — Complete editor source snapshot.
- **AFileName** — Current source file path.

### HandleDocUpdated

### HandleJumpToLine

### InitTimerFired

### IsSameElement

### KeyDown

### ParseEditorSource

### RefreshFromCurrentEditor

Refreshes the declaration at the active editor's cursor.

### RetryParsing

### SendToEditor

### ShowParseFailure

### UpdateErrorDisplay

### UpdateFromCursor

### Documentation
