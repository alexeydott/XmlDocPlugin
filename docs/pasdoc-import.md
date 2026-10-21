# Importing PasDoc documentation

XmlDocPlugin reads ordinary comments and PasDoc comments before declarations. Reading does not modify source files. Generate Doc Stub converts an imported comment to XML; normal editor Apply uses the same undoable source writer and read-only checks.

A same-name `.pas`/`.txt` pair is recognized automatically. Text sections use fully qualified names, for example `# Sample.TWorker.Run`. Parameter names match the actual signature without case sensitivity. Local descriptions take precedence over the sidecar; unknown parameters are ignored.

| PasDoc tags | Imported representation |
| --- | --- |
| `@abstract` | Summary; surrounding prose becomes Remarks |
| `@param` | Parameters in signature spelling |
| `@return`, `@returns` | Returns |
| `@raises` | Exception and description |
| `@seealso` | See Also reference and optional label |
| `@include` | Expanded description, including nested tags |
| `@includeCode` | Literal code from one or more files |
| `@bold`, `@italic`, `@code`, `@br` | Bold, italic, inline code and line break |
| `@longCode`, `@preformatted` | Literal code; inner tags remain literal |
| `@html` | Supported HTML converted to XML; scripts, event handlers and other active content are removed |
| `@latex` | Literal code containing the original LaTeX; no formula typesetting |
| `@link`, `@url` | Symbol or URL reference, preserving the optional label |
| `@image` | Image resource reference |
| `@name`, `@className`, `@inheritedClass`, `@inherited` | Declaration, owner and ancestor names |
| `@orderedList`, `@unorderedList`, `@definitionList` | Numbered, bulleted and definition lists |
| `@item`, `@itemLabel` | List description and its preceding label |
| `@itemSetNumber`, `@itemSpacing` | Explicit numbering and spacing preference; spacing may vary by renderer |
| `@table`, `@row`, `@rowHead`, `@cell` | Table with header cells and any number of columns |
| `@title`, `@shortTitle`, `@section`, `@anchor`, `@tableOfContents` | Headings, anchors and local contents links |
| `@member`, `@value` | Named member/value descriptions, also displayed on the owner; available member declarations inherit the description |
| `@author`, `@created`, `@lastmod`, `@cvs`, `@deprecated`, `@note`, `@warning` | Labelled descriptive information |
| `@exclude` | Declaration omitted from catalog/export, while cursor access remains available |
| `@noAutoLink`, `@noAutoLinkHere` | Prose stays unlinked; the plugin links explicit references only |
| `@@`, `@(`, `@)`, `@-` | Literal at sign, parentheses and hyphen |

Arguments can use balanced parentheses. Arguments without parentheses end at the line boundary; a trailing backslash continues them onto the next line. Parenthesized arguments can contain nested tags. Code, preformatted, HTML, LaTeX and link arguments retain their raw contents until their own handler processes them.

Include paths are relative to the Pascal source, including includes within another text file. Parent directory references are allowed. Included text uses the same encoding detection as Pascal files. Includes are read as snapshots, so changing or removing a dependency rejects cached results. Cycles, missing files, nesting deeper than 32 levels and more than 4 MiB of expanded file text report an error instead of silently truncating the documentation.

Complex imported tables, numbered items and other XML which Design cannot round-trip remain protected XML blocks. Preview and exports render their contents; use XML mode to change their structure.

The [PasDoc reference](https://pasdoc.github.io/SupportedTags) describes the original syntax. This is an import into XmlDocPlugin's XML model, rather than a PasDoc command-line build: LaTeX remains literal and website-level introduction/conclusion options are not added to the plugin.
