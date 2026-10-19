# class `TThemeEngine`

Provides built-in and custom CSS themes for generated HTML documentation.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `FCustomThemesDir` | field | private |  |
| `FInstance` | field | private |  |
| `FThemes` | field | private |  |
| `GetAvailableThemes` | method | public | Lists available themes. |
| `GetCSS` | method | public | Returns CSS for the requested theme. |
| `Instance` | method | public |  |
| `LoadBuiltInThemes` | method | private |  |
| `LoadCustomThemes` | method | private |  |
| `ReleaseInstance` | method | public |  |
| `SetCustomThemesDir` | method | public | Sets the directory used to discover custom themes. |

### Create

### Destroy

### FCustomThemesDir

### FInstance

### FThemes

### GetAvailableThemes

Lists available themes.

**Returns:** Available theme names.

### GetCSS

Returns CSS for the requested theme.

**Parameters:**

- **AThemeName** — Theme name.

**Returns:** CSS text.

### Instance

### LoadBuiltInThemes

### LoadCustomThemes

### ReleaseInstance

### SetCustomThemesDir

Sets the directory used to discover custom themes.

**Parameters:**

- **ADir** — Directory path.
