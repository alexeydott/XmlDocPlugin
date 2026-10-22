# Importing PasDoc documentation

XmlDocPlugin reads ordinary comments and PasDoc comments before declarations. Reading does not modify source files. Generate Doc Stub converts an imported comment to XML; normal editor Apply uses the same undoable source writer and read-only checks.

A same-name `.pas`/`.txt` pair is recognized automatically. Text sections use fully qualified names, for example `# Sample.TWorker.Run`. Parameter names match the actual signature without case sensitivity. Local descriptions take precedence over the sidecar; unknown parameters are ignored.

## Source and text file example

In `Sample.pas`, place the description immediately before the declaration:

```pascal
unit Sample;
interface
type
  // # @abstract Converts values using a scale factor.
  TConverter = class
  public
    // # @abstract Returns the scaled input value.
    function Convert(Value: Double; Factor: Integer = 1): Double;
  end;
implementation
function TConverter.Convert(Value: Double; Factor: Integer): Double;
begin
  Result := Value * Factor;
end;
end.
```

Put additional descriptions in `Sample.txt`, beside the source:

```text
# Sample.TConverter.Convert
  @param Value The input value.
  @param Factor The scale factor.
  @param RemovedParameter Ignored because it is not in the signature.
  @returns The input multiplied by the scale factor.
```

Opening **Convert** shows the existing short description, the two valid parameter descriptions and the return description. Matching is case-insensitive, but XML output keeps the parameter spelling from the declaration. A section applies to its qualified unit/class/member name; it is not matched by the method name alone.

Review the imported fields in Inspector or Explorer. Choose **Generate Doc Stub**, or edit the fields and wait for **Applied**, to convert the source comment to `///` XML. Use the IDE's **Undo** to restore the preceding source comment. Opening, previewing or exporting the documentation does not perform this conversion.

Once a declaration has an XML comment, the plugin reads that comment directly. It does not merge later sidecar edits over authored XML or write changes back to the text file.

## Include descriptions and code

The member section can also contain:

```text
  @include(descriptions/convert.txt)
  @includeCode(examples/convert.pas)
```

For example, `descriptions/convert.txt` can contain `@note(The scale factor is applied once.)`; `examples/convert.pas` can contain `Result := Converter.Convert(2, 3);`. The first directive expands description tags, while the second inserts literal code without interpreting its `@` characters as tags.

Resolve both paths from the folder containing `Sample.pas`. A nested include inside `descriptions/convert.txt` still uses that source folder as its base. Save an edited include, then choose **Reload source** while viewing the legacy comment. Reading dependencies participates in cache validation; applying documentation changes only the Pascal comment.

## Multiline code and older markers

Both forms import as a code block:

```text
@longCode(Result := Converter.Convert(2, 3);)

@longCode(#
  Result := Converter.Convert(2, 3);
#)
```

The historical paired markers are removed from the code. A closing `#)` is not a new sidecar section. As in [PasDoc's longCode syntax](https://pasdoc.github.io/LongcodeTag), tags inside the code remain literal.

## Tag mappings

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
