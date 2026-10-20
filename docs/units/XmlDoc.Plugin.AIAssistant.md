# XmlDoc.Plugin.AIAssistant

Coordinates AI requests, source freshness checks and explicit proposal application inside the IDE.

## Types

| Type | Kind | Description |
|------|------|-------------|
| [`TAIAssistant`](XmlDoc.Plugin.AIAssistant.TAIAssistant.md) | class | Owns request preparation, worker cancellation and source-checked application for an Inspector or Explorer view. |
| [`TAIWorker`](XmlDoc.Plugin.AIAssistant.TAIWorker.md) | class | Executes a prepared request outside the UI thread and exposes its proposal or error after completion. |
