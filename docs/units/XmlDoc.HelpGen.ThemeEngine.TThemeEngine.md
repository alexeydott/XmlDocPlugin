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
| `CreateCustomTheme` | method | public | Creates a new UTF-8 CSS theme from an existing palette, rejects invalid or duplicate names, and reloads the catalog. |
| `GetAvailableThemes` | method | public | Lists available themes. |
| `GetCSS` | method | public | Returns CSS for a built-in theme without string-name conversion by the caller. |
| `GetCSS` | method | public | Returns theme CSS; empty or unknown names fall back to default. Names ignore case and surrounding whitespace. |
| `Instance` | method | public |  |
| `LoadBuiltInThemes` | method | private |  |
| `LoadCustomThemes` | method | private |  |
| `ReleaseInstance` | method | public |  |
| `Reload` | method | public | Reloads built-in and custom themes from disk. |
| `SetCustomThemesDir` | method | public | Reloads custom CSS from a directory, discarding the previous custom catalog and restoring built-ins first. |
| `ThemeName` | method | public | Returns the stable configuration name of a built-in theme. |
| `CustomThemesDir` | property | public |  |

### Create

### Destroy

### FCustomThemesDir

### FInstance

### FThemes

### CreateCustomTheme

Creates a new UTF-8 CSS theme from an existing palette, rejects invalid or duplicate names, and reloads the catalog.

### GetAvailableThemes

Lists available themes.

**Returns:** Available theme names.

<a id="m17298e995d6f7048ae1d"></a>
### GetCSS

Returns CSS for a built-in theme without string-name conversion by the caller.

<a id="mf2ab16fb6565ff978e09"></a>
### GetCSS

Returns theme CSS; empty or unknown names fall back to default. Names ignore case and surrounding whitespace.

**Parameters:**

- **AThemeName** — Theme name.

**Returns:** CSS text.

### Instance

### LoadBuiltInThemes

### LoadCustomThemes

### ReleaseInstance

### Reload

Reloads built-in and custom themes from disk.

### SetCustomThemesDir

Reloads custom CSS from a directory, discarding the previous custom catalog and restoring built-ins first.

**Parameters:**

- **ADir** — Directory path.

### ThemeName

Returns the stable configuration name of a built-in theme.

### CustomThemesDir
