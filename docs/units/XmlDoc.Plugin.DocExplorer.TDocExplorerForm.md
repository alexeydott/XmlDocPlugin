# class `TDocExplorerForm`

Inherits from `TDockableForm`

Dockable unit documentation browser and editor with project tools.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `FBrowser` | field | private |  |
| `FBrowserError` | field | private |  |
| `FBrowserReady` | field | private |  |
| `FCurrentFileName` | field | private |  |
| `FDocParser` | field | private |  |
| `FEditSessionId` | field | private |  |
| `FElements` | field | private |  |
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
| `HandleDocUpdated` | method | private |  |
| `HandleFileChanged` | method | public | Updates the view after a source file or editor snapshot changes. |
| `HandleJumpToLine` | method | private |  |
| `InitTimerFired` | method | private |  |
| `KeyDown` | method | protected |  |
| `LoadBounds` | method | private |  |
| `ParseEditorSource` | method | private |  |
| `ReadEditorSource` | method | private |  |
| `RefreshFromCurrentEditor` | method | public | Refreshes from the active source editor. |
| `SaveBounds` | method | private |  |
| `SendTreeToEditor` | method | private |  |
| `UpdateErrorDisplay` | method | private |  |
| `Documentation` | property | public |  |

### Create

### Destroy

### FBrowser

### FBrowserError

### FBrowserReady

### FCurrentFileName

### FDocParser

### FEditSessionId

### FElements

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

### SaveBounds

### SendTreeToEditor

### UpdateErrorDisplay

### Documentation
