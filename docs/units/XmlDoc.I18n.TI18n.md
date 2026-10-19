# class `TI18n`

Loads native UI translations from JSON locale resources or files.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `FCurrentLanguage` | field | private |  |
| `FInstance` | field | private |  |
| `FLanguageLoaded` | field | private |  |
| `FLocalesDir` | field | private |  |
| `FReverse` | field | private |  |
| `FStrings` | field | private |  |
| `Instance` | method | public |  |
| `LoadDefaults` | method | private |  |
| `LoadLanguage` | method | private |  |
| `NormalizeLanguage` | method | public |  |
| `ParseJsonObject` | method | private |  |
| `ReleaseInstance` | method | public |  |
| `SetLanguage` | method | public | Selects a UI language; auto detects the user's locale. |
| `SetLocalesDir` | method | public | Sets the directory used for external locale files. |
| `T` | method | public | Looks up a translation, returning the key when no translation exists. |
| `T` | method | public | Formats a translated message using the supplied arguments. |
| `TranslateComponent` | method | public |  |
| `TranslateText` | method | public |  |
| `CurrentLanguage` | property | public |  |

### Create

### Destroy

### FCurrentLanguage

### FInstance

### FLanguageLoaded

### FLocalesDir

### FReverse

### FStrings

### Instance

### LoadDefaults

### LoadLanguage

### NormalizeLanguage

### ParseJsonObject

### ReleaseInstance

### SetLanguage

Selects a UI language; auto detects the user's locale.

**Parameters:**

- **ALang** — Language code: en, ko, ja, ru, zh or auto.

### SetLocalesDir

Sets the directory used for external locale files.

**Parameters:**

- **ADir** — Directory path.

<a id="m47f29ebfa417fedf7eff"></a>
### T

Looks up a translation, returning the key when no translation exists.

**Parameters:**

- **AKey** — Dot-separated translation key, for example menu.generate\_help.

**Returns:** Translated text.

<a id="m70e6eff22f5cc0060f23"></a>
### T

Formats a translated message using the supplied arguments.

**Parameters:**

- **AKey** — Dot-separated translation key.
- **AArgs** — Formatting arguments.

**Returns:** Formatted translated text.

### TranslateComponent

### TranslateText

### CurrentLanguage
