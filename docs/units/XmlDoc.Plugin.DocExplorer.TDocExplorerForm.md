# class `TDocExplorerForm`

Inherits from `TDockableForm`

Dockable unit documentation browser and editor with project tools.

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
| `FCurrentFileName` | field | private |  |
| `FDiagnostic` | field | private |  |
| `FDocParser` | field | private |  |
| `FEditSessionId` | field | private |  |
| `FElements` | field | private |  |
| `FErrorActions` | field | private |  |
| `FErrorViewSent` | field | private |  |
| `FFilePollTimer` | field | private |  |
| `FInitTimer` | field | private |  |
| `FLastSource` | field | private |  |
| `FParseError` | field | private |  |
| `FPendingLoad` | field | private |  |
| `FPinned` | field | private |  |
| `FPreferredLocation` | field | private |  |
| `FProjectDocs` | field | private |  |
| `FUpdatingSource` | field | private |  |
| `FWebViewError` | field | private |  |
| `ApplyIDETheme` | method | protected |  |
| `BrowserCreateWebViewCompleted` | method | private |  |
| `BrowserNavigationCompleted` | method | private |  |
| `BrowserWebMessageReceived` | method | private |  |
| `BuildDocJson` | method | private |  |
| `BuildElementJson` | method | private |  |
| `BuildLoadTreeScript` | method | private |  |
| `CMStyleChanged` | method | protected |  |
| `FilePollTimerFired` | method | private |  |
| `FindElementByFullName` | method | private |  |
| `GoToError` | method | private |  |
| `HandleDocUpdated` | method | private |  |
| `HandleFileChanged` | method | public | Updates the view after a source file or editor snapshot changes. |
| `HandleJumpToLine` | method | private |  |
| `InitTimerFired` | method | private |  |
| `KeyDown` | method | protected |  |
| `LoadBounds` | method | private |  |
| `ParseEditorSource` | method | private |  |
| `ReadEditorSource` | method | private |  |
| `RefreshFromCurrentEditor` | method | public | Refreshes from the active source editor. |
| `RetryParsing` | method | private |  |
| `SaveBounds` | method | private |  |
| `SendTreeToEditor` | method | private |  |
| `ShowParseFailure` | method | private |  |
| `UpdateErrorDisplay` | method | private |  |
| `Documentation` | property | public |  |

### Create

### Destroy

### FAI

### FBrowser

### FBrowserError

### FBrowserReady

### FClosing

### FCurrentFileName

### FDiagnostic

### FDocParser

### FEditSessionId

### FElements

### FErrorActions

### FErrorViewSent

### FFilePollTimer

### FInitTimer

### FLastSource

### FParseError

### FPendingLoad

### FPinned

### FPreferredLocation

### FProjectDocs

### FUpdatingSource

### FWebViewError

### ApplyIDETheme

### BrowserCreateWebViewCompleted

### BrowserNavigationCompleted

### BrowserWebMessageReceived

### BuildDocJson

### BuildElementJson

### BuildLoadTreeScript

### CMStyleChanged

### FilePollTimerFired

### FindElementByFullName

### GoToError

### HandleDocUpdated

### HandleFileChanged

Updates the view after a source file or editor snapshot changes.

**Parameters:**

- **AFileName** — Current source file path.
- **ASource** — Complete editor source snapshot.

### HandleJumpToLine

### InitTimerFired

### KeyDown

### LoadBounds

### ParseEditorSource

### ReadEditorSource

### RefreshFromCurrentEditor

Refreshes from the active source editor.

### RetryParsing

### SaveBounds

### SendTreeToEditor

### ShowParseFailure

### UpdateErrorDisplay

### Documentation
