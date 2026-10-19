# class `TCLIMain`

Parses command-line options and runs documentation generation and checks.

## Members

| Name | Kind | Visibility | Description |
|------|------|------------|-------------|
| `FOptions` | field | private |  |
| `ParseArgs` | method | private |  |
| `PrintHelp` | method | private |  |
| `PrintProgress` | method | private |  |
| `RenderSite` | method | private |  |
| `Run` | method | public | Runs the command and returns its exit code. |

### FOptions

### ParseArgs

### PrintHelp

### PrintProgress

### RenderSite

### Run

Runs the command and returns its exit code.

**Returns:** 0 on success, 1 for a coverage/readiness threshold failure, 2 on error, 3 for new documentation problems.
