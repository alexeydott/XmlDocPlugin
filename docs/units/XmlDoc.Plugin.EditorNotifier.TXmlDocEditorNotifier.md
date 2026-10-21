# class `TXmlDocEditorNotifier`

Inherits from `TNotifierObject`

Observes editor events and debounces source and cursor notifications.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `FDebounceTimer` | field | private |  |
| `FLastNotifiedFileName` | field | private |  |
| `FLastNotifiedLine` | field | private |  |
| `FLastNotifiedSource` | field | private |  |
| `FOnCursorChanged` | field | private |  |
| `FPendingFileName` | field | private |  |
| `FPendingLine` | field | private |  |
| `FPendingSource` | field | private |  |
| `DebounceTimerFired` | method | private |  |
| `DockFormRefresh` | method | public | INTAEditServicesNotifier |
| `DockFormUpdated` | method | public |  |
| `DockFormVisibleChanged` | method | public |  |
| `EditorViewActivated` | method | public |  |
| `EditorViewModified` | method | public |  |
| `GetCurrentSource` | method | private |  |
| `ScheduleNotify` | method | private |  |
| `WindowActivated` | method | public |  |
| `WindowCommand` | method | public |  |
| `WindowNotification` | method | public |  |
| `WindowShow` | method | public |  |

### Create

### Destroy

### FDebounceTimer

### FLastNotifiedFileName

### FLastNotifiedLine

### FLastNotifiedSource

### FOnCursorChanged

### FPendingFileName

### FPendingLine

### FPendingSource

### DebounceTimerFired

### DockFormRefresh

INTAEditServicesNotifier

### DockFormUpdated

### DockFormVisibleChanged

### EditorViewActivated

### EditorViewModified

### GetCurrentSource

### ScheduleNotify

### WindowActivated

### WindowCommand

### WindowNotification

### WindowShow
