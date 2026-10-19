# class `TDocCoverageReport`

Analyzes documentation coverage and renders reports.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `FSymbols` | field | private |  |
| `Analyze` | method | public | Computes documentation coverage for the supplied units. |
| `AnalyzeElement` | method | private |  |
| `AnalyzeType` | method | private |  |
| `AnalyzeUnit` | method | private |  |
| `CollectSymbols` | method | private |  |
| `CoverageLevelToString` | method | private |  |
| `GetUndocumented` | method | public | Returns declarations that need documentation. |
| `RenderConsoleReport` | method | public | Writes a coverage report to the console. |
| `RenderHTMLReport` | method | public | Writes an HTML coverage report. |

### FSymbols

### Analyze

Computes documentation coverage for the supplied units.

**Parameters:**

- **AUnits** — Units to analyze.

**Returns:** Documentation coverage statistics.

### AnalyzeElement

### AnalyzeType

### AnalyzeUnit

### CollectSymbols

### CoverageLevelToString

### GetUndocumented

Returns declarations that need documentation.

**Parameters:**

- **AUnits** — Units to process.
- **AMinVisibility** — Minimum visibility to include; defaults to public.

**Returns:** Declarations that need documentation.

### RenderConsoleReport

Writes a coverage report to the console.

**Parameters:**

- **AStats** — Documentation coverage statistics.

### RenderHTMLReport

Writes an HTML coverage report.

**Parameters:**

- **AStats** — Documentation coverage statistics.
- **AItems** — Coverage entries to include.
- **AOutputPath** — Destination file path.
