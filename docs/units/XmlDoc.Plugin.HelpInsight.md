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

Updates root and localized templates, preserving backups and rolling back failed writes.

### BuildEnhancedHelpInsightCss

Builds viewer-compatible styles with bounded layout dimensions.

### BuildEnhancedHelpInsightXslt

Builds the bundled XSLT 1.0 template with localized section headings.

### BuildHelpInsightCss

### ExportHelpInsightCss

Exports a complete stylesheet for a separate administrator-assisted copy.

### ExportHelpInsightTemplates

Exports a matching HelpInsight.css and HelpInsight.xsl pair to a separate directory.

### HelpInsightCssPath

### RenderHelpInsightPreview

Transforms a sample without modifying IDE files; external XML entities are disabled.

### RestoreHelpInsightTemplates

Restores the first saved stylesheet and root/localized templates byte for byte.

### UpdateHelpInsightCss
