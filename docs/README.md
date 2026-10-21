# XmlDocPlugin API Reference

## Units

| Unit | Description |
|------|-------------|
| [XmlDoc.AI.Context](units/XmlDoc.AI.Context.md) | Captures the exact method implementation and project dependencies used by an AI request. |
| [XmlDoc.AI.Contracts](units/XmlDoc.AI.Contracts.md) | Shared request, context, transport and reviewable proposal contracts for AI documentation. |
| [XmlDoc.AI.OpenAI](units/XmlDoc.AI.OpenAI.md) | Validates profiles, builds OpenAI-compatible requests and checks JSON proposal responses. |
| [XmlDoc.AI.ProfileStore](units/XmlDoc.AI.ProfileStore.md) | Reads AI profiles and scoped credentials without IDE or form dependencies. |
| [XmlDoc.AI.Prompts](units/XmlDoc.AI.Prompts.md) | Built-in description and rephrasing prompts, variable expansion and protected XML tokens. |
| [XmlDoc.AI.Text](units/XmlDoc.AI.Text.md) | Removes provider HTML from AI prose and emits safe XML paragraphs without executing markup. |
| [XmlDoc.AI.Toon](units/XmlDoc.AI.Toon.md) | Lossless TOON encoding of the string, object and array shapes used by AI method context. |
| [XmlDoc.AI.Transport](units/XmlDoc.AI.Transport.md) | Cancellable HTTPS transport with UTF-8 request bodies, timeouts and bounded response storage. |
| [XmlDoc.CLI.Main](units/XmlDoc.CLI.Main.md) | Command-line documentation generation, project analysis and coverage checks. |
| [XmlDoc.CodeGen](units/XmlDoc.CodeGen.md) | Documentation comment rendering and source-text replacement. |
| [XmlDoc.CodeGen.OTA](units/XmlDoc.CodeGen.OTA.md) | Undoable documentation writes through the IDE source editor. |
| [XmlDoc.Consts](units/XmlDoc.Consts.md) | Shared declaration metadata and structured documentation records. |
| [XmlDoc.Documentation](units/XmlDoc.Documentation.md) | Documentation validation, stable identities, authoring configuration and public API comparison. |
| [XmlDoc.ErrorHandler](units/XmlDoc.ErrorHandler.md) | Plugin diagnostics, exception logging and IDE message callbacks. |
| [XmlDoc.Expressions](units/XmlDoc.Expressions.md) | Context-sensitive expression and overload resolution for Quick Documentation. |
| [XmlDoc.HelpGen.BatchParser](units/XmlDoc.HelpGen.BatchParser.md) | Batch parsing of source files into documentation units, types and members. |
| [XmlDoc.HelpGen.Coverage](units/XmlDoc.HelpGen.Coverage.md) | Documentation coverage analysis and HTML or console reports. |
| [XmlDoc.HelpGen.CrossRef](units/XmlDoc.HelpGen.CrossRef.md) | Documentation cross-reference resolution across units and declarations. |
| [XmlDoc.HelpGen.Diagnostics](units/XmlDoc.HelpGen.Diagnostics.md) | Project documentation checks, diagnostic reports and baseline comparison. |
| [XmlDoc.HelpGen.Inheritance](units/XmlDoc.HelpGen.Inheritance.md) | Effective documentation inherited from base types, members and explicit references. |
| [XmlDoc.HelpGen.Navigation](units/XmlDoc.HelpGen.Navigation.md) | Hierarchical navigation and stable topic filename mapping shared by output formats. |
| [XmlDoc.HelpGen.Renderer](units/XmlDoc.HelpGen.Renderer.md) | Common rendering interface and output options. |
| [XmlDoc.HelpGen.Renderer.CHM](units/XmlDoc.HelpGen.Renderer.CHM.md) | CHM project generation, short-path staging and HTML Help compiler validation. |
| [XmlDoc.HelpGen.Renderer.HMXP](units/XmlDoc.HelpGen.Renderer.HMXP.md) | Help and Manual project generation with topic hierarchy and bundled resources. |
| [XmlDoc.HelpGen.Renderer.HTML](units/XmlDoc.HelpGen.Renderer.HTML.md) | Static HTML reference pages, navigation, cross-links and search resources. |
| [XmlDoc.HelpGen.Renderer.JSON](units/XmlDoc.HelpGen.Renderer.JSON.md) | Machine-readable documentation hierarchy export. |
| [XmlDoc.HelpGen.Renderer.MD](units/XmlDoc.HelpGen.Renderer.MD.md) | Markdown reference pages and navigation for units, types and members. |
| [XmlDoc.HelpGen.Resources](units/XmlDoc.HelpGen.Resources.md) | Validated copying of documentation images and example source resources. |
| [XmlDoc.HelpGen.Scanner](units/XmlDoc.HelpGen.Scanner.md) | Project and directory discovery of Pascal source files. |
| [XmlDoc.HelpGen.SitePublisher](units/XmlDoc.HelpGen.SitePublisher.md) | MkDocs, Docusaurus and VitePress project generation. |
| [XmlDoc.HelpGen.ThemeEngine](units/XmlDoc.HelpGen.ThemeEngine.md) | Built-in and custom CSS themes for generated HTML documentation. |
| [XmlDoc.HelpGen.Types](units/XmlDoc.HelpGen.Types.md) | Owned documentation hierarchies for units, types and declarations. |
| [XmlDoc.I18n](units/XmlDoc.I18n.md) | Native interface localization with embedded and external JSON translations. |
| [XmlDoc.Logger](units/XmlDoc.Logger.md) | Severity-filtered file logging with rotation and configurable destinations. |
| [XmlDoc.Markup](units/XmlDoc.Markup.md) | Documentation markup conversion and safe rendering helpers. |
| [XmlDoc.Model](units/XmlDoc.Model.md) | Structured XML documentation with JSON transport and preservation of original XML. |
| [XmlDoc.ParamDict](units/XmlDoc.ParamDict.md) | Persistent parameter-description hints used by documentation stub generation. |
| [XmlDoc.Parser](units/XmlDoc.Parser.md) | DelphiAST integration, project-aware conditional parsing and declaration lookup. |
| [XmlDoc.Plugin.AboutDialog](units/XmlDoc.Plugin.AboutDialog.md) | Plugin information and version display. |
| [XmlDoc.Plugin.AIAssistant](units/XmlDoc.Plugin.AIAssistant.md) | Coordinates AI requests, source freshness checks and explicit proposal application inside the IDE. |
| [XmlDoc.Plugin.AISettings](units/XmlDoc.Plugin.AISettings.md) | Persists connection profiles and prompt overrides while keeping API keys in Windows Credential Manager. |
| [XmlDoc.Plugin.BatchGenDialog](units/XmlDoc.Plugin.BatchGenDialog.md) | IDE documentation generation dialog and output orchestration. |
| [XmlDoc.Plugin.Browser](units/XmlDoc.Plugin.Browser.md) | WebView2 resource hosting, editor settings and persistent section state. |
| [XmlDoc.Plugin.CoverageDialog](units/XmlDoc.Plugin.CoverageDialog.md) | IDE coverage analysis dialog with source navigation. |
| [XmlDoc.Plugin.DeclarationContext](units/XmlDoc.Plugin.DeclarationContext.md) | Project-aware declaration context for IDE documentation commands. |
| [XmlDoc.Plugin.DocExplorer](units/XmlDoc.Plugin.DocExplorer.md) | Dockable unit documentation browser and editing host. |
| [XmlDoc.Plugin.DocInspector](units/XmlDoc.Plugin.DocInspector.md) | Dockable declaration documentation editor and source synchronization. |
| [XmlDoc.Plugin.EditorNotifier](units/XmlDoc.Plugin.EditorNotifier.md) | Debounced IDE editor, cursor and source change notifications. |
| [XmlDoc.Plugin.EditSession](units/XmlDoc.Plugin.EditSession.md) | Documentation write authorization, source revisions and edit acknowledgement state. |
| [XmlDoc.Plugin.HelpInsight](units/XmlDoc.Plugin.HelpInsight.md) | Theme-aware XSLT and reversible stylesheet preferences for native IDE Help Insight. |
| [XmlDoc.Plugin.Localization](units/XmlDoc.Plugin.Localization.md) | Localization of native plugin controls and menu text. |
| [XmlDoc.Plugin.Main](units/XmlDoc.Plugin.Main.md) | IDE wizard registration, command wiring and plugin lifetime management. |
| [XmlDoc.Plugin.OptionsPage](units/XmlDoc.Plugin.OptionsPage.md) | Embeds the shared plugin preferences in Tools Options under Third Party. |
| [XmlDoc.Plugin.ProjectDocumentation](units/XmlDoc.Plugin.ProjectDocumentation.md) | Project documentation catalog, background analysis and source update coordination. |
| [XmlDoc.Plugin.QuickDocPreview](units/XmlDoc.Plugin.QuickDocPreview.md) | Popup display of quick documentation near the source cursor. |
| [XmlDoc.Plugin.Settings](units/XmlDoc.Plugin.Settings.md) | Global registry preferences and per-project JSON generation defaults. |
| [XmlDoc.Plugin.SettingsDialog](units/XmlDoc.Plugin.SettingsDialog.md) | Supported global editor preferences, stub options and command shortcuts. |
| [XmlDoc.Plugin.Shortcuts](units/XmlDoc.Plugin.Shortcuts.md) | IDE menu commands, keyboard bindings and callback registration. |
| [XmlDoc.Plugin.Splash](units/XmlDoc.Plugin.Splash.md) | IDE startup branding with the package's shared file version. |
| [XmlDoc.Plugin.UndocNavigator](units/XmlDoc.Plugin.UndocNavigator.md) | Source navigation between undocumented declarations. |
| [XmlDoc.Plugin.UpdateChecker](units/XmlDoc.Plugin.UpdateChecker.md) | Legacy update-service helper; automatic checking is not enabled by the plugin. |
| [XmlDoc.Plugin.Utils](units/XmlDoc.Plugin.Utils.md) | IDE theme detection, readable diagnostic colors and UI utilities. |
| [XmlDoc.ProjectContext](units/XmlDoc.ProjectContext.md) | Project configuration, search paths and conditional declaration resolution. |
| [XmlDoc.ProjectIndex](units/XmlDoc.ProjectIndex.md) | Incremental declaration indexing with source and dependency validation. |
| [XmlDoc.ShortcutValidation](units/XmlDoc.ShortcutValidation.md) | Detection of conflicts between documentation shortcuts and IDE commands. |
| [XmlDoc.SourceAccess](units/XmlDoc.SourceAccess.md) | Read-only and protected-source checks for documentation editing. |
| [XmlDoc.SourceText](units/XmlDoc.SourceText.md) | Source encoding detection, file reading and example-resource resolution. |
| [XmlDoc.StubGen](units/XmlDoc.StubGen.md) | Documentation stub generation from signatures, parameter hints and placeholder options. |
| [XmlDoc.XmlFragments](units/XmlDoc.XmlFragments.md) | Validated XML fragment loading and serialization helpers. |
