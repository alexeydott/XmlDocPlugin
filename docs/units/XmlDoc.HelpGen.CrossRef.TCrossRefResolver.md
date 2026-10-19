# class `TCrossRefResolver`

Resolves documentation cref attributes against the parsed symbol catalog.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `FSymbolIndex` | field | private |  |
| `FUnresolved` | field | private |  |
| `ResolveAllRefs` | method | public | Resolves references across the supplied units. |
| `ResolveCref` | method | public |  |
| `ResolveReference` | method | public | Resolves a reference in the context of its containing declaration. |
| `TryResolve` | method | private |  |
| `Unresolved` | property | public |  |

### Create

### Destroy

### FSymbolIndex

### FUnresolved

### ResolveAllRefs

Resolves references across the supplied units.

**Parameters:**

- **AUnits** — Units to process.

### ResolveCref

### ResolveReference

Resolves a reference in the context of its containing declaration.

**Parameters:**

- **ACref** — Original cref attribute value.
- **AContext** — Declaration containing the reference.

**Returns:** Resolved full name, or the original reference if resolution fails.

### TryResolve

### Unresolved
