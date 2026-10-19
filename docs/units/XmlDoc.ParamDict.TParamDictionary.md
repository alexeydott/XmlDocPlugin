# class `TParamDictionary`

Persistent parameter-description dictionary used by stub generation.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `Destroy` | method | private |  |
| `FDirty` | field | private |  |
| `FFilePath` | field | private |  |
| `FInstance` | field | private |  |
| `FItems` | field | private |  |
| `GetInstance` | method | private |  |
| `LoadFromFile` | method | public | Selects a dictionary file and loads its existing entries. |
| `Register` | method | public | Adds or updates a parameter description. |
| `SaveToFile` | method | public | Saves modified dictionary entries. |
| `TryGet` | method | public | Looks up a parameter description. |
| `Instance` | property | public | Returns the shared dictionary instance. |

### Create

### Destroy

### Destroy

### FDirty

### FFilePath

### FInstance

### FItems

### GetInstance

### LoadFromFile

Selects a dictionary file and loads its existing entries.

**Parameters:**

- **APath** — JSON file path.

### Register

Adds or updates a parameter description.

**Parameters:**

- **AName** — Parameter name.
- **ADescription** — Parameter description.

### SaveToFile

Saves modified dictionary entries.

### TryGet

Looks up a parameter description.

**Parameters:**

- **AName** — Parameter name.
- **ADescription** — Description returned when an entry exists.

**Returns:** True if a description was found.

### Instance

Returns the shared dictionary instance.
