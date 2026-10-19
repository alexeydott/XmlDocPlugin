# class `TLogger`

Thread-safe file logger with rotation and configurable severity filtering.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `FInstance` | field | private |  |
| `FLevel` | field | private |  |
| `FLock` | field | private |  |
| `FLogPath` | field | private |  |
| `FMaxFiles` | field | private |  |
| `FMaxFileSize` | field | private |  |
| `FWriter` | field | private |  |
| `Configure` | method | public | Applies the log threshold and closes the writer when the destination changes. |
| `Debug` | method | public |  |
| `EnsureWriter` | method | private |  |
| `Error` | method | public |  |
| `Error` | method | public |  |
| `Fatal` | method | public |  |
| `FormatEntry` | method | private |  |
| `Info` | method | public |  |
| `Instance` | method | public |  |
| `LevelToString` | method | private |  |
| `ReleaseInstance` | method | public |  |
| `RotateIfNeeded` | method | private |  |
| `SetLogPath` | method | private |  |
| `Warn` | method | public |  |
| `WriteEntry` | method | private |  |
| `Level` | property | public |  |
| `LogPath` | property | public |  |

### Create

### Destroy

### FInstance

### FLevel

### FLock

### FLogPath

### FMaxFiles

### FMaxFileSize

### FWriter

### Configure

Applies the log threshold and closes the writer when the destination changes.

### Debug

### EnsureWriter

<a id="mfa6e58a54dee5c70c080"></a>
### Error

<a id="mf2422da3b458a3eb1e0f"></a>
### Error

### Fatal

### FormatEntry

### Info

### Instance

### LevelToString

### ReleaseInstance

### RotateIfNeeded

### SetLogPath

### Warn

### WriteEntry

### Level

### LogPath
