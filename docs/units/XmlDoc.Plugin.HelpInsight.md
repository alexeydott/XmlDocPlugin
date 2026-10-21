# XmlDoc.Plugin.HelpInsight

Theme-aware XSLT and reversible stylesheet preferences for native IDE Help Insight.

## Types

| Type | Kind | Description |
|------|------|-------------|
| [`THelpInsightPalette`](XmlDoc.Plugin.HelpInsight.THelpInsightPalette.md) | record | CSS colours captured from the active IDE theme, with light and dark fallback palettes. |
| [`THelpInsightSettings`](XmlDoc.Plugin.HelpInsight.THelpInsightSettings.md) | record | Native hint layout and opt-in extended presentation preferences. |

## Functions & Procedures

### ApplyHelpInsightCss

Updates only the plugin block; preserves the first file backup and unrelated CSS.

### ApplyHelpInsightCssWithShell

Uses Windows Shell copy, allowing the user to approve UAC for a protected IDE folder.

### ApplyHelpInsightPresentation

Updates root and IDE-language templates with the current plugin language, preserving backups and rolling back failed writes.

## Remarks

The IDE language selects the destination folder; the plugin language selects section headings. Independent tooltip renderers do not necessarily use these templates.

### BuildEnhancedHelpInsightCss

Builds viewer-compatible styles with bounded layout dimensions.

### BuildEnhancedHelpInsightXslt

Builds the bundled XSLT 1.0 template with section headings in the active plugin UI language.

## Remarks

Supports English, Russian, Chinese, Korean and Japanese. Declaration identifiers, documentation text and link targets are preserved. Reapply presentation and restart the IDE after changing language because the native viewer can cache XSLT.

### BuildHelpInsightCss

### ExportHelpInsightCss

Exports a complete stylesheet for a separate administrator-assisted copy.

### ExportHelpInsightTemplates

Exports a matching HelpInsight.css and HelpInsight.xsl pair to a separate directory.

### HelpInsightCssPath

### RenderHelpInsightPreview

Transforms a sample without modifying IDE files; external XML entities are disabled.

**Returns:** Rendered HTML, or an empty string when the IDE provides no displayable hint data.

### RestoreHelpInsightTemplates

Restores the first saved stylesheet and root/localized templates byte for byte.

### UpdateHelpInsightCss
