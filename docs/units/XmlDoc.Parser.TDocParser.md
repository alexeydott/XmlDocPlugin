# class `TDocParser`

Parses Delphi source and locates documentable declarations at a source line.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `Create` | method | public |  |
| `Destroy` | method | public |  |
| `FBuilder` | field | private |  |
| `FCachedHash` | field | private |  |
| `FCachedSource` | field | private |  |
| `FDefines` | field | private |  |
| `FDependencyFiles` | field | private |  |
| `FDependencyProbes` | field | private |  |
| `FDependencySnapshots` | field | private |  |
| `FFlatIndex` | field | private |  |
| `FHasDeclared` | field | private |  |
| `FLastCommentStart` | field | private |  |
| `FOnCheck` | field | private |  |
| `FOnResolveDeclaration` | field | private |  |
| `FPlatform` | field | private |  |
| `FRootNode` | field | private |  |
| `FSearchPaths` | field | private |  |
| `FSnapshots` | field | private |  |
| `FSourceFileName` | field | private |  |
| `FSourceFiles` | field | private |  |
| `FSourceLines` | field | private |  |
| `BindingType` | method | public |  |
| `BuildFlatIndex` | method | private |  |
| `BuildParentPath` | method | private |  |
| `CollectDocTargets` | method | private |  |
| `ExtractDocComment` | method | private |  |
| `ExtractGenericParams` | method | private |  |
| `ExtractParams` | method | private |  |
| `ExtractReturnType` | method | private |  |
| `FindNearestDocTarget` | method | private |  |
| `FindNextElementAtOrBelow` | method | private |  |
| `GetAllElements` | method | public | Returns all documentable declarations in the parsed source. |
| `GetElementAtLine` | method | public | Finds the declaration at the supplied source line. |
| `HashSource` | method | private |  |
| `IsDocTargetNode` | method | private |  |
| `IsUpToDate` | method | public | Checks whether the supplied source matches the parsed snapshot. |
| `NodeToElementInfo` | method | private |  |
| `ParseSource` | method | public | Builds the syntax tree for the supplied source and project context. |
| `SetDefines` | method | private |  |
| `SetPlatform` | method | private |  |
| `SetResolveDeclaration` | method | private |  |
| `SetSearchPaths` | method | private |  |
| `SetSnapshots` | method | private |  |
| `SetSourceFiles` | method | private |  |
| `Defines` | property | public |  |
| `DependencyFiles` | property | public |  |
| `DependencyProbes` | property | public |  |
| `DependencySnapshots` | property | public |  |
| `OnCheck` | property | public |  |
| `OnResolveDeclaration` | property | public | Returns known visibility, or False when external scope information is unavailable. |
| `Platform` | property | public |  |
| `RootNode` | property | public |  |
| `SearchPaths` | property | public |  |
| `SourceFileName` | property | public |  |
| `SourceFiles` | property | public |  |
| `SourceSnapshots` | property | public |  |
| `SourceText` | property | public | Most recently parsed source snapshot. |

### Create

### Destroy

### FBuilder

### FCachedHash

### FCachedSource

### FDefines

### FDependencyFiles

### FDependencyProbes

### FDependencySnapshots

### FFlatIndex

### FHasDeclared

### FLastCommentStart

### FOnCheck

### FOnResolveDeclaration

### FPlatform

### FRootNode

### FSearchPaths

### FSnapshots

### FSourceFileName

### FSourceFiles

### FSourceLines

### BindingType

### BuildFlatIndex

### BuildParentPath

### CollectDocTargets

### ExtractDocComment

### ExtractGenericParams

### ExtractParams

### ExtractReturnType

### FindNearestDocTarget

### FindNextElementAtOrBelow

### GetAllElements

Returns all documentable declarations in the parsed source.

**Returns:** Parsed declaration metadata.

### GetElementAtLine

Finds the declaration at the supplied source line.

**Parameters:**

- **ALine** — One-based cursor line number.

**Returns:** Declaration metadata; Name is empty when no declaration is found.

### HashSource

### IsDocTargetNode

### IsUpToDate

Checks whether the supplied source matches the parsed snapshot.

**Parameters:**

- **ASource** — Source text to compare.

**Returns:** True if the source has not changed.

### NodeToElementInfo

### ParseSource

Builds the syntax tree for the supplied source and project context.

**Parameters:**

- **ASource** — Complete source text to parse.

### SetDefines

### SetPlatform

### SetResolveDeclaration

### SetSearchPaths

### SetSnapshots

### SetSourceFiles

### Defines

### DependencyFiles

### DependencyProbes

### DependencySnapshots

### OnCheck

### OnResolveDeclaration

Returns known visibility, or False when external scope information is unavailable.

### Platform

### RootNode

### SearchPaths

### SourceFileName

### SourceFiles

### SourceSnapshots

### SourceText

Most recently parsed source snapshot.
