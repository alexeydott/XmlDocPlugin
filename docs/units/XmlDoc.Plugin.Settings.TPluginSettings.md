# class `TPluginSettings`

Loads and saves global registry preferences and per-project JSON defaults.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public | Loads preferences from the supplied current-user registry root. |
| `FGlobal` | field | private |  |
| `FInstance` | field | private |  |
| `FProject` | field | private |  |
| `FProjectDir` | field | private |  |
| `FRegistryRoot` | field | private |  |
| `Instance` | method | public |  |
| `Load` | method | public | Loads global preferences and applies runtime logging options. |
| `LoadDefaults` | method | public | Resets global and project preferences to their defaults. |
| `LoadFromRegistry` | method | private |  |
| `LoadProject` | method | public | Loads preferences for the selected project, resetting previous project defaults. |
| `LoadProjectDefaults` | method | private |  |
| `LoadProjectSettings` | method | private |  |
| `ReleaseInstance` | method | public |  |
| `Save` | method | public | Saves global preferences and applies runtime logging options. |
| `SaveProject` | method | public | Saves project preferences while preserving unrelated configuration keys. |
| `SaveToRegistry` | method | private |  |
| `Global` | property | public |  |
| `Project` | property | public |  |
| `ProjectDir` | property | public |  |

### Create

Loads preferences from the supplied current-user registry root.

### FGlobal

### FInstance

### FProject

### FProjectDir

### FRegistryRoot

### Instance

### Load

Loads global preferences and applies runtime logging options.

### LoadDefaults

Resets global and project preferences to their defaults.

### LoadFromRegistry

### LoadProject

Loads preferences for the selected project, resetting previous project defaults.

**Parameters:**

- **AProjectDir** — Project root directory.

### LoadProjectDefaults

### LoadProjectSettings

### ReleaseInstance

### Save

Saves global preferences and applies runtime logging options.

### SaveProject

Saves project preferences while preserving unrelated configuration keys.

### SaveToRegistry

### Global

### Project

### ProjectDir
