# Delphi 12 tests

Run `build-delphi12.ps1`, then `test-delphi12.ps1` from the repository root.
Both scripts accept `-Bds` for the Delphi installation directory. Test binaries
and DCUs are written below `%LOCALAPPDATA%\XmlDocPlugin\Tests`.

The settings smoke test changes persisted settings temporarily and restores
their original values in `finally`; close the IDE before running it.
The browser smoke test uses the actual embedded editor and WebView2 Runtime.
It checks document rendering, light/dark/system themes, and saved section state
through three HWND recreations on both Win32 and Win64.

The HMXP renderer tests cover complete and empty projects, nested types,
overloads, stable IDs, private-symbol filtering, Unicode, code examples and
cross-references. Each generated project is independently checked against the
bundled XSD, including its expanded TOC, followed by local-reference and style
checks and an XSL transform of every topic.

The full core suite runs on both Win32 and Win64, alongside the settings and
browser smoke tests. The script returns a failure status if any test fails.

For IDE integration, open Doc Inspector, dock it in an IDE tab group, and check
that its content and selected documentation remain visible. Save the desktop
layout, close the IDE, and reopen that layout. Verify that Inspector is recreated
in the same tab group and its section choices and editor theme are preserved.

## Workbench regression and E2E suite

`e2e/DocumentationWorkbench/XmlDocE2E.dproj` is the permanent acceptance project.
Use it instead of external Skia projects. It contains interfaces, inheritance,
overloads, renamed and undocumented parameters, malformed and extension XML,
Unicode examples, mixed markup and a project image.

Run the complete suite from the repository root:

```powershell
.\tests\Test-Improvements.ps1
```

Use `-SkipIDE` for core/browser/fuzz/export checks only. The runner tests Delphi
12 and 13 on Win32/Win64, the TypeScript bridge and real ProseMirror serializer,
all eight export formats, local references, HMXP XSD/resources, unchanged
baselines and changed public signatures. The fuzz suites use reproducible seeds:
2,000 XML mutations, 3,000 rich-text trees and 5,000 navigation/debounce sequences.

The IDE runner builds the fixture and plugin, then launches RAD 12 x86 and RAD 13
x86/x64 with generated `XmlDocE2E...` registry profiles. It copies the fixture and
writes binaries, drafts and evidence outside Git. User IDE instances and source
files are not used. The stock Welcome Page is excluded from these profiles to avoid its online
components and asynchronous shutdown activity. Test profiles are retained
for diagnosis; no installed plugin or user IDE profile is replaced.

E2E exercises the production Inspector/Explorer WebView callbacks and actual OTA
buffers: delayed A-to-B/file switches, simultaneous editors, stale revisions,
Unicode, unknown markup/metadata, native source Undo/Redo, malformed XML,
explicit parameter renaming, project search, selected member-summary edits,
project image loading and narrow controls. It requires a normal IDE exit code 0.
Before editing the fixture, the probe opens the production **Generate API
Documentation** dialog, selects all eight formats, coverage and numeric topic
filenames, and invokes its Generate button. It requires the successful completion
phase, validates all output links and resources, and checks unit/type/member
grouping in HTML, CHM, Markdown, JSON, HMXP and each site's navigation.

To test an installation, including its standalone x64 CLI:

```powershell
.\tests\e2e\Test-E2E.ps1 -Installed
# Or include native, browser, fuzz and baseline checks:
.\tests\Test-Improvements.ps1 -Installed
```

Installed mode loads BPLs from `%LOCALAPPDATA%\Programs\XmlDocPlugin`, verifies
their registration and installed manifest hashes, and never rebuilds or replaces
them. It runs the installed x64 CLI with `--numeric-file-names`, validates all
eight formats and compares the IDE/CLI topic maps. `-InstallRoot` supports a
custom installation. Compiling the probe requires the matching package DCPs
from `build-installer.ps1`, normally retained under
`%LOCALAPPDATA%\XmlDocPlugin\Installer\intermediate`; use `-InstalledDcpRoot` to
select an archived matching build. Missing artifacts cause an explicit failure.
Evidence goes into a fresh directory outside Git. Settings and Explorer bounds
are preserved. The test-owned completion dialogs are acknowledged automatically;
an error or incomplete generation fails the test.

A browser PASS marker alone is insufficient. Closing forms is deferred until the WebView callback has returned. The runner
then invokes the actual IDE File > Exit menu command from the deferred callback, rather than terminating
a message loop or closing an unrelated hidden VCL form.

Quick Documentation is deliberately conservative. Full Delphi overload binding,
arbitrary MSBuild target execution and compilation of free-form example snippets
are not substitutes for the Delphi compiler and are not claimed by this suite.
